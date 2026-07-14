// lib/services/whatsapp_service.dart
// HETNA CNC — Servicio WhatsApp
// Usa WhatsApp Business API para enviar desde el número correcto
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class WhatsAppService {

  // ── Número Business HETNA CNC ───────────────────────
  // Solo este número está vinculado con Meta Business API
  static const String _phoneNumberId = '110027521820458';
  static const String _businessNumero = '522461217072';

  // ── Normalizar número del CLIENTE ───────────────────
  static String normalizarNumero(String numero) {
    var n = numero.replaceAll(RegExp(r'[^0-9]'), '');
    if (n.isEmpty) return '';
    if (n.length == 10) return '521$n';
    if (n.length == 11 && n.startsWith('1')) return '52$n';
    if (n.length == 12 && n.startsWith('52')) return '521${n.substring(2)}';
    if (n.length == 13 && n.startsWith('521')) return n;
    return n;
  }

  // ── ABRIR CHAT (abre WhatsApp del cliente) ───────────
  // Esto siempre abre la app de WhatsApp en el celular
  // El usuario debe seleccionar manualmente el número Business
  static Future<bool> abrirChat({
    required String numero,
    required String mensaje,
  }) async {
    final n = normalizarNumero(numero);
    if (n.isEmpty) return false;
    try {
      final uri = Uri.parse(
        'https://wa.me/$n?text=${Uri.encodeComponent(mensaje)}');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    } catch (_) {
      try {
        final uri2 = Uri.parse(
          'intent://send/$n#Intent;scheme=whatsapp;package=com.whatsapp.w4b;end');
        await launchUrl(uri2, mode: LaunchMode.externalApplication);
        return true;
      } catch (_) { return false; }
    }
  }

  // ── ENVIAR VÍA API (siempre del número Business) ────
  // Usa WhatsApp Business API de Meta
  // Token se guarda en Supabase en configuracion_empresa, POR TALLER
  static Future<bool> enviarViaApi({
    required String numeroDestino,
    required String mensaje,
  }) async {
    try {
      final n = normalizarNumero(numeroDestino);
      if (n.isEmpty) return false;

      // Obtener token de Supabase — filtrado por el negocio del usuario
      // actual. Sin este filtro, con más de un taller configurado, la
      // consulta puede traer el token de OTRO negocio (o tronar por
      // duplicados) en vez del propio.
      final negocioId = AuthService.negocioId;
      if (negocioId == null) {
        return abrirChat(numero: numeroDestino, mensaje: mensaje);
      }

      final rows = await Supabase.instance.client
        .from('configuracion_empresa')
        .select('whatsapp_token')
        .eq('negocio_id', negocioId)
        .limit(1);

      final list = rows as List;
      final token = list.isNotEmpty
        ? list.first['whatsapp_token'] as String?
        : null;

      if (token == null || token.isEmpty) {
        // Si no hay token, abrir app normalmente
        return abrirChat(numero: numeroDestino, mensaje: mensaje);
      }

      final res = await http.post(
        Uri.parse('https://graph.facebook.com/v17.0/$_phoneNumberId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messaging_product': 'whatsapp',
          'to': n,
          'type': 'text',
          'text': {'body': mensaje},
        }));

      return res.statusCode == 200;
    } catch (_) {
      // Fallback: abrir app
      return abrirChat(numero: numeroDestino, mensaje: mensaje);
    }
  }

  // ══════════════════════════════════════════════════════
  // MENSAJES DE SEGUIMIENTO
  // Editables desde la app en: Más → Config → Plantillas WA
  // ══════════════════════════════════════════════════════

  // ── LEER PLANTILLA DESDE SUPABASE ──────────────────
  // Lee el mensaje personalizado del taller desde la BD
  // Si no hay plantilla, usa el mensaje por defecto del código
  //
  // NOTA: plantillas_wa no se tocó en este fix porque no estaba en el
  // reporte del punto 9 (whatsapp_service.dart no filtraba SOLO en
  // configuracion_empresa). Si plantillas_wa también necesita filtro
  // por negocio_id, avísame y lo corregimos aparte.
  static Future<String> getPlantilla({
    required String tipo,
    required String nombreCliente,
    String? folio,
    double? monto,
    String? empresa,
    String? telefono,
  }) async {
    try {
      final data = await Supabase.instance.client
        .from('plantillas_wa')
        .select('mensaje, cuerpo, tipo, categoria')
        .eq('activo', true)
        .or('tipo.eq.$tipo,categoria.eq.$tipo')
        .maybeSingle();

      if (data != null) {
        // usar mensaje (nuevo) o cuerpo (columna original)
        final rawMsg = data['mensaje'] as String?
          ?? data['cuerpo'] as String? ?? '';
        if (rawMsg.isEmpty) throw Exception('sin plantilla');
        var msg = rawMsg;
        msg = msg.replaceAll('*NOMBRE*', nombreCliente);
        msg = msg.replaceAll('*FOLIO*', folio ?? '');
        msg = msg.replaceAll('*MONTO*', monto != null
          ? '\$${monto.toStringAsFixed(2)}' : '');
        msg = msg.replaceAll('*EMPRESA*', empresa ?? 'HETNA CNC');
        msg = msg.replaceAll('*TELEFONO*', telefono ?? '2461217072');
        msg = msg.replaceAll('*FECHA*',
          DateTime.now().toString().substring(0, 10));
        return msg;
      }
    } catch (_) {}

    // Fallback: mensaje por defecto
    return mensajeSeguimiento(
      nombreCliente: nombreCliente,
      tipo: tipo,
      folio: folio,
      empresa: empresa,
      telefono: telefono,
    );
  }

  // ── LEER NÚMERO DEL TALLER DESDE SUPABASE ───────────
  static Future<String> getNumeroTaller() async {
    try {
      final negocioId = AuthService.negocioId;
      if (negocioId == null) return '2461217072';

      final rows = await Supabase.instance.client
        .from('configuracion_empresa')
        .select('whatsapp_numero, whatsapp_modo')
        .eq('negocio_id', negocioId)
        .limit(1);

      final list = rows as List;
      if (list.isNotEmpty && list.first['whatsapp_numero'] != null) {
        return list.first['whatsapp_numero'] as String;
      }
    } catch (_) {}
    return '2461217072'; // default HETNA CNC
  }

  static Future<String> getModoEnvio() async {
    try {
      final negocioId = AuthService.negocioId;
      if (negocioId == null) return 'app';

      final rows = await Supabase.instance.client
        .from('configuracion_empresa')
        .select('whatsapp_modo')
        .eq('negocio_id', negocioId)
        .limit(1);

      final list = rows as List;
      return list.isNotEmpty
        ? (list.first['whatsapp_modo'] as String? ?? 'app')
        : 'app';
    } catch (_) { return 'app'; }
  }

  static String mensajeSeguimiento({
    required String nombreCliente,
    required String tipo,
    String? folio,
    double? total,
    String? empresa,    // nombre del negocio (configurable)
    String? telefono,   // teléfono del negocio
  }) {
    final biz = empresa ?? 'HETNA CNC';
    final tel = telefono ?? '2461217072';
    final folioTexto = folio != null && folio.isNotEmpty
      ? 'cotización *$folio*' : 'tu cotización';

    switch (tipo) {
      // ── Día 3: recordatorio suave ──
      case 'seguimiento_dia3':
        return '''¡Hola *$nombreCliente*! 😊

Te escribo de *$biz* para saber si pudiste revisar la $folioTexto que te enviamos.

¿Tienes alguna duda sobre los materiales, tiempos de entrega o el precio? Estamos aquí para resolverlas.

Escríbeme cuando quieras 👇
📱 *$tel*''';

      // ── Día 5: seguimiento con propuesta ──
      case 'seguimiento_dia5':
        return '''¡Hola *$nombreCliente*! 👋

Te contacto de nuevo de *$biz* sobre la $folioTexto.

Entiendo que a veces hay dudas antes de tomar una decisión. Si quieres podemos:

✅ Ajustar el diseño
✅ Modificar materiales
✅ Revisar los tiempos de entrega

¿Cuándo tienes 5 minutos para platicar?
📱 *$tel*''';

      // ── Día 7: urgencia + oferta ──
      case 'seguimiento_dia7':
        return '''¡Hola *$nombreCliente*! ⏰

La $folioTexto está por vencer. No quiero que pierdas la oportunidad.

Esta semana puedo hacer un ajuste especial si te decides. ¿Le entramos? 🎯

Escríbeme hoy mismo:
📱 *$tel* — *$biz*''';

      // ── Post entrega: reseña y seguidor ──
      case 'post_entrega':
        return '''¡Hola *$nombreCliente*! 🎉

Esperamos que estés disfrutando tu pedido de *$biz*. 

Nos encantaría saber cómo te fue y si quedaste satisfecho/a con el resultado.

Si tienes un momento, comparte tu experiencia. ¡Tu opinión nos ayuda a mejorar! 🙏

Síguenos en redes para ver más trabajos:
📲 @hetna_cnc

¡Gracias por confiar en nosotros! 💙''';

      // ── Recordatorio de pago ──
      case 'pago_anticipo_pendiente':
        return '''¡Hola *$nombreCliente*! 💰

Te recuerdo que el anticipo del pedido *${folio ?? ''}* está pendiente para poder iniciar la producción.

Una vez recibido el anticipo, comenzamos de inmediato. 🔧

¿Tienes alguna duda sobre la forma de pago?
📱 *$tel* — *$biz*''';

      // ── Recordatorio pago final ──
      case 'pago_final_pendiente':
        return '''¡Hola *$nombreCliente*! 📦

Tu pedido *${folio ?? ''}* está *LISTO* para entrega.

Para coordinar la entrega necesitamos el pago final.

📱 *$tel* — *$biz*

¡Ya casi es tuyo! 🎉''';

      // ── Cliente interesado ──
      case 'cliente_interesado':
        return '''¡Hola *$nombreCliente*! 😊

Vi que estás interesado/a en nuestros productos. En *$biz* hacemos trabajos a medida en:

🔧 Router CNC (madera, MDF)
🔥 Plasma CNC (acero)
🔴 Láser (grabado y corte)
✏️ Diseño digital

¿Tienes algún proyecto en mente? Con gusto te hago una cotización sin compromiso.

📱 *$tel*''';

      // ── Producción sin avance ──
      case 'produccion_sin_avance':
        return '''¡Hola *$nombreCliente*! 🔧

Tu pedido *${folio ?? ''}* sigue en producción en *$biz*.

Queremos asegurarnos de que todo va según lo acordado. Si tienes alguna pregunta, estamos disponibles.

📱 *$tel*''';

      default:
        return '¡Hola *$nombreCliente*! Te escribo de *$biz*. ¿Podemos ayudarte con algo?\n📱 $tel';
    }
  }

  // ── Mensajes de avance de pedido ─────────────────────
  static String mensajeAvance({
    required String nombreCliente,
    required String folio,
    required String etapa,
    double? total,
    String? empresa,
  }) {
    final biz = empresa ?? 'HETNA CNC';
    switch (etapa) {
      case 'Pago':
        return '¡Hola *$nombreCliente*! ✅ Confirmamos tu pago del pedido *$folio*. Ya estamos listos para comenzar. 🔧 — *$biz*';
      case 'Produccion':
        return '¡Hola *$nombreCliente*! 🔧 Tu pedido *$folio* ya está en producción. Te avisamos cuando esté listo. — *$biz*';
      case 'Pruebas':
        return '¡Hola *$nombreCliente*! 🔍 Tu pedido *$folio* está en control de calidad. ¡Ya casi está listo! — *$biz*';
      case 'Entrega':
        return '¡Hola *$nombreCliente*! 📦 Tu pedido *$folio* está *LISTO*. ¿Cuándo coordinamos la entrega? — *$biz*';
      case 'Entregado':
        return '¡Hola *$nombreCliente*! 🎉 Tu pedido *$folio* fue entregado exitosamente. ¡Gracias por confiar en *$biz*! Esperamos verte pronto.';
      default:
        return '¡Hola *$nombreCliente*! Tu pedido *$folio* sigue en proceso. — *$biz*';
    }
  }

  // ── Enviar cotización por WhatsApp ───────────────────
  static Future<void> enviarCotizacion({
    required dynamic cotizacion,
    required String nombreCliente,
    required String whatsapp,
    required String empresa,
  }) async {
    final folio = cotizacion?.folio ?? '';
    final msg = '''¡Hola *$nombreCliente*! 😊

Te comparto la cotización *$folio* de *HETNA CNC*.

Incluye todos los detalles del trabajo solicitado. Cualquier ajuste con gusto lo hacemos.

¡Quedamos a tus órdenes! 💙
📱 2461217072''';
    await abrirChat(numero: whatsapp, mensaje: msg);
  }

  // ── Enviar avance de pedido ──────────────────────────
  static Future<void> enviarAvancePedido({
    required String whatsapp,
    required String nombreCliente,
    required String folio,
    required String etapa,
    DateTime? fechaEstimada,
  }) async {
    final msg = mensajeAvance(
      nombreCliente: nombreCliente,
      folio: folio,
      etapa: etapa);
    await abrirChat(numero: whatsapp, mensaje: msg);
  }

  // ══════════════════════════════════════════════════════
  // DÓNDE EDITAR LOS MENSAJES
  // ══════════════════════════════════════════════════════
  // Los mensajes se pueden personalizar de 3 formas:
  //
  // 1. DESDE LA APP:
  //    Más → Marketing → Plantillas WA
  //    (si tienes plantillas guardadas en Supabase,
  //     se usan en lugar de los mensajes de aquí)
  //
  // 2. DIRECTAMENTE EN SUPABASE:
  //    Tabla: plantillas_wa
  //    Columnas: tipo, mensaje, activo
  //
  // 3. EN ESTE ARCHIVO (cambio permanente):
  //    Editar los textos en mensajeSeguimiento()
  //    y volver a compilar la app
  // ══════════════════════════════════════════════════════
}
