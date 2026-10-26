// lib/services/whatsapp_service.dart
// HETNA CNC — Servicio WhatsApp
// Usa WhatsApp Business API para enviar desde el número correcto
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import '../main.dart';
import '../i18n/tr.dart';

class WhatsAppService {

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

  // ── Intentar SOLO WhatsApp Business (sin respaldo) ───
  // Canal nativo (MainActivity.kt) — evita el truco de armar una URL
  // "intent://...#Intent;...;end" y parsearla con Uri.parse(), que
  // Dart interpreta mal (no es una URI estándar) y por eso fallaba
  // en silencio, cayendo siempre al WhatsApp normal.
  static const _channelWA = MethodChannel('com.hetnacnc.app/whatsapp_share');

  static Future<bool> _abrirWhatsAppBusiness(String numero, String mensaje) async {
    final n = normalizarNumero(numero);
    if (n.isEmpty) return false;
    if (kIsWeb) return false; // el canal nativo solo existe en Android
    try {
      final ok = await _channelWA.invokeMethod('abrirWhatsAppTexto', {
        'numero': n, 'mensaje': mensaje, 'paquete': 'com.whatsapp.w4b',
      });
      return ok == true;
    } catch (_) { return false; }
  }

  // ── Enlace genérico (deja que el sistema decida cuál app) ──
  static Future<bool> _abrirWhatsAppGenerico(String numero, String mensaje) async {
    final n = normalizarNumero(numero);
    if (n.isEmpty) return false;
    try {
      final uri = Uri.parse(
        'https://wa.me/$n?text=${Uri.encodeComponent(mensaje)}');
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) { return false; }
  }

  // ── ABRIR CHAT (sin preguntar) ───────────────────────
  // Se usa internamente como respaldo automático (ej. cuando falla el
  // envío por API). Intenta WhatsApp Business primero, y si falla,
  // cae al enlace genérico.
  static Future<bool> abrirChat({
    required String numero,
    required String mensaje,
  }) async {
    if (!kIsWeb) {
      final ok = await _abrirWhatsAppBusiness(numero, mensaje);
      if (ok) return true;
    }
    return _abrirWhatsAppGenerico(numero, mensaje);
  }

  // ── ABRIR CHAT CON SELECTOR (deja elegir al usuario) ─
  // El número siempre es el del CLIENTE (a quién se le escribe) — la
  // elección de "WhatsApp Business" / "Otra app" solo decide CON QUÉ
  // app de tu celular se abre esa conversación, nunca cambia a quién
  // se le manda el mensaje.
  static Future<void> abrirChatConSelector(BuildContext context, {
    required String numero,
    required String mensaje,
  }) async {
    if (kIsWeb) {
      // En web no hay apps que elegir — usar el enlace normal directo
      await _abrirWhatsAppGenerico(numero, mensaje);
      return;
    }
    await showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(tr('¿Con cuál WhatsApp quieres escribirle?'),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await _abrirWhatsAppBusiness(numero, mensaje);
              if (!ok && ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(tr('No se encontró WhatsApp Business — usa "Otra app"')),
                  backgroundColor: AppColors.ambar));
              }
            },
            icon: const Icon(Icons.chat, color: Colors.white),
            label: Text(tr('WhatsApp Business'), style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(vertical: 12)))),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _abrirWhatsAppGenerico(numero, mensaje);
            },
            icon: const Icon(Icons.share_outlined),
            label: Text(tr('Otra app')),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)))),
          const SizedBox(height: 8),
        ])));
  }

  // ── ENVIAR VÍA API (siempre del número Business) ────
  // Usa WhatsApp Business API de Meta
  // Token se guarda en Supabase en configuracion_empresa, POR TALLER
  // Regresa un mapa: {'exito': bool, 'viaApi': bool, 'detalle': String?}
  // 'detalle' trae el motivo exacto cuando algo falla, para poder
  // mostrarlo en pantalla y diagnosticar sin necesitar logs del celular.
  static Future<Map<String, dynamic>> enviarViaApiDetallado({
    required String numeroDestino,
    required String mensaje,
  }) async {
    try {
      final n = normalizarNumero(numeroDestino);
      if (n.isEmpty) return {'exito': false, 'viaApi': false, 'detalle': 'Número de destino vacío o inválido'};

      final negocioId = AuthService.negocioId;
      if (negocioId == null) {
        final ok = await abrirChat(numero: numeroDestino, mensaje: mensaje);
        return {'exito': ok, 'viaApi': false, 'detalle': 'Sin negocio activo en sesión'};
      }

      final rows = await Supabase.instance.client
        .from('config_whatsapp')
        .select('phone_number_id, wa_token, activo')
        .eq('negocio_id', negocioId)
        .limit(1);

      final list = rows as List;
      if (list.isEmpty) {
        final ok = await abrirChat(numero: numeroDestino, mensaje: mensaje);
        return {'exito': ok, 'viaApi': false, 'detalle': 'No hay fila de configuración en config_whatsapp para este negocio'};
      }

      final config = list.first as Map<String, dynamic>;
      final activo = config['activo'] as bool? ?? false;
      final token = config['wa_token'] as String?;
      final phoneNumberId = config['phone_number_id'] as String?;

      if (!activo) {
        final ok = await abrirChat(numero: numeroDestino, mensaje: mensaje);
        return {'exito': ok, 'viaApi': false, 'detalle': 'El interruptor "Activo" está apagado en la base de datos'};
      }
      if (token == null || token.isEmpty) {
        final ok = await abrirChat(numero: numeroDestino, mensaje: mensaje);
        return {'exito': ok, 'viaApi': false, 'detalle': 'Falta el token'};
      }
      if (phoneNumberId == null || phoneNumberId.isEmpty) {
        final ok = await abrirChat(numero: numeroDestino, mensaje: mensaje);
        return {'exito': ok, 'viaApi': false, 'detalle': 'Falta el Phone Number ID'};
      }

      final res = await http.post(
        Uri.parse('https://graph.facebook.com/v17.0/$phoneNumberId/messages'),
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

      if (res.statusCode == 200) {
        return {'exito': true, 'viaApi': true, 'detalle': null};
      }
      // Meta regresa el motivo exacto en el cuerpo — lo mostramos tal cual
      return {'exito': false, 'viaApi': true, 'detalle': 'Meta respondió ${res.statusCode}: ${res.body}'};
    } catch (e) {
      final ok = await abrirChat(numero: numeroDestino, mensaje: mensaje);
      return {'exito': ok, 'viaApi': false, 'detalle': 'Excepción: $e'};
    }
  }

  static Future<bool> enviarViaApi({
    required String numeroDestino,
    required String mensaje,
  }) async {
    try {
      final n = normalizarNumero(numeroDestino);
      if (n.isEmpty) return false;

      // Obtener credenciales de Supabase — filtrado por el negocio del
      // usuario actual, de la tabla REAL donde Configuración las
      // guarda (config_whatsapp), no de configuracion_empresa. Antes
      // esto leía de un lugar que Configuración nunca escribía, por
      // eso guardar el token ahí nunca hacía nada.
      final negocioId = AuthService.negocioId;
      if (negocioId == null) {
        return abrirChat(numero: numeroDestino, mensaje: mensaje);
      }

      final rows = await Supabase.instance.client
        .from('config_whatsapp')
        .select('phone_number_id, wa_token, activo')
        .eq('negocio_id', negocioId)
        .limit(1);

      final list = rows as List;
      if (list.isEmpty) {
        return abrirChat(numero: numeroDestino, mensaje: mensaje);
      }

      final config = list.first as Map<String, dynamic>;
      final activo = config['activo'] as bool? ?? false;
      final token = config['wa_token'] as String?;
      final phoneNumberId = config['phone_number_id'] as String?;

      if (!activo || token == null || token.isEmpty ||
          phoneNumberId == null || phoneNumberId.isEmpty) {
        // Sin configurar (o desactivado) — abrir app normalmente
        return abrirChat(numero: numeroDestino, mensaje: mensaje);
      }

      final res = await http.post(
        Uri.parse('https://graph.facebook.com/v17.0/$phoneNumberId/messages'),
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
  // Filtrado por negocio_id: sin esto, con más de un taller usando
  // plantillas personalizadas, un taller podía recibir el mensaje
  // guardado por OTRO taller (o tronar si dos negocios usan el mismo
  // tipo/categoria y .maybeSingle() encuentra más de una fila).
  static Future<String> getPlantilla({
    required String tipo,
    required String nombreCliente,
    String? folio,
    double? monto,
    String? empresa,
    String? telefono,
  }) async {
    try {
      final negocioId = AuthService.negocioId;
      if (negocioId == null) throw Exception('sin negocio activo');

      final rows = await Supabase.instance.client
        .from('plantillas_wa')
        .select('mensaje, cuerpo, tipo, categoria')
        .eq('negocio_id', negocioId)
        .eq('activo', true)
        .or('tipo.eq.${tipo},categoria.eq.${tipo}')
        .limit(1);

      final list = rows as List;
      final data = list.isNotEmpty ? list.first as Map<String, dynamic> : null;

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

  // ── LEER PLANTILLA DE AVANCE DESDE SUPABASE ─────────
  // Mensajes de "tu pedido cambió de etapa". Ahora se pueden editar
  // desde Más → Marketing → Plantillas WA, guardando una plantilla con
  // tipo/categoría "avance_<etapa>" en minúsculas — las etapas reales
  // son: Pago50, Produccion, Pruebas, PagoCompleto, Entrega, Entregado,
  // Cancelado (ej. "avance_pago50", "avance_produccion"). Variables
  // disponibles además de las de siempre: *MONTO* (total), *ANTICIPO*
  // (50%), *RESTANTE* (lo que falta). Si no existe plantilla
  // personalizada, cae al mensaje por defecto de mensajeAvance().
  static Future<String> getPlantillaAvance({
    required String etapa,
    required String nombreCliente,
    required String folio,
    double? montoTotal,
    String? empresa,
    String? pedidoId,
  }) async {
    String msgFinal;
    try {
      final negocioId = AuthService.negocioId;
      if (negocioId == null) throw Exception('sin negocio activo');
      final claveEtapa = 'avance_${etapa.toLowerCase()}';

      final rows = await Supabase.instance.client
        .from('plantillas_wa')
        .select('mensaje, cuerpo, tipo, categoria')
        .eq('negocio_id', negocioId)
        .eq('activo', true)
        .or('tipo.eq.${claveEtapa},categoria.eq.${claveEtapa}')
        .limit(1);

      final list = rows as List;
      if (list.isNotEmpty) {
        final data = list.first as Map<String, dynamic>;
        final rawMsg = data['mensaje'] as String? ?? data['cuerpo'] as String? ?? '';
        if (rawMsg.isNotEmpty) {
          final total = montoTotal ?? 0;
          final anticipo = total / 2;
          final restante = total - anticipo;
          var msg = rawMsg;
          msg = msg.replaceAll('*NOMBRE*', nombreCliente);
          msg = msg.replaceAll('*FOLIO*', folio);
          msg = msg.replaceAll('*MONTO*', total > 0 ? '\$${total.toStringAsFixed(2)}' : '');
          msg = msg.replaceAll('*ANTICIPO*', total > 0 ? '\$${anticipo.toStringAsFixed(2)}' : '');
          msg = msg.replaceAll('*RESTANTE*', total > 0 ? '\$${restante.toStringAsFixed(2)}' : '');
          msg = msg.replaceAll('*EMPRESA*', empresa ?? 'HETNA CNC');
          msg = msg.replaceAll('*FECHA*', DateTime.now().toString().substring(0, 10));
          msgFinal = msg;
        } else {
          msgFinal = mensajeAvance(
            nombreCliente: nombreCliente, folio: folio, etapa: etapa,
            total: montoTotal, empresa: empresa);
        }
      } else {
        msgFinal = mensajeAvance(
          nombreCliente: nombreCliente, folio: folio, etapa: etapa,
          total: montoTotal, empresa: empresa);
      }
    } catch (_) {
      msgFinal = mensajeAvance(
        nombreCliente: nombreCliente, folio: folio, etapa: etapa,
        total: montoTotal, empresa: empresa);
    }
    return msgFinal;
  }

  static String mensajeSeguimiento({
    required String nombreCliente,
    required String tipo,
    String? folio,
    double? total,
    String? empresa,    // nombre del negocio (configurable)
    String? telefono,   // teléfono del negocio
  }) {
    final biz = empresa ?? tr('HETNA CNC');
    final tel = telefono ?? '2461217072';
    final folioTexto = folio != null && folio.isNotEmpty
      ? trf('cotización *{0}*', [folio]) : tr('tu cotización');

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
        return trf('¡Hola *{0}*! Te escribo de *{1}*. ¿Podemos ayudarte con algo?\n📱 {2}', [nombreCliente, biz, tel]);
    }
  }

  // ── Mensajes de avance de pedido ─────────────────────
  // Mensajes por defecto de avance de pedido. Etapas reales usadas en
  // la app: Pago50, Produccion, Pruebas, PagoCompleto, Entrega,
  // Entregado, Cancelado.
  static String mensajeAvance({
    required String nombreCliente,
    required String folio,
    required String etapa,
    double? total,
    String? empresa,
  }) {
    final biz = empresa ?? tr('HETNA CNC');
    final montoTotal = total ?? 0;
    final anticipo = montoTotal / 2;
    final restante = montoTotal - anticipo;
    final txtAnticipo = montoTotal > 0 ? ' (\$${anticipo.toStringAsFixed(2)})' : '';
    final txtRestante = montoTotal > 0 ? trf(' de \${0}', [(restante.toStringAsFixed(2))]) : '';
    switch (etapa) {
      case 'Pago50':
        return '¡Hola $nombreCliente! ✅ Recibimos tu anticipo del 50%$txtAnticipo del pedido *$folio*. ¡Empezamos a producir! 🔧\n\nRecuerda que el saldo restante$txtRestante se liquida antes de la entrega. — *$biz*';
      case 'Produccion':
        return '¡Hola $nombreCliente! 🔧 Tu pedido *$folio* está en producción. Te avisamos cuando esté listo. — *$biz*';
      case 'Pruebas':
        return '¡Hola $nombreCliente! 🔍 Tu pedido *$folio* está en control de calidad. ¡Casi listo! — *$biz*';
      case 'PagoCompleto':
        return '¡Hola $nombreCliente! 💳 Tu pedido *$folio* está listo. Para entregarlo necesitamos el pago del saldo restante$txtRestante. ¿Cuándo puedes realizarlo? — *$biz*';
      case 'Entrega':
        return '¡Hola $nombreCliente! 📦 Tu pedido *$folio* está *LISTO para entrega*. ¿Cuándo coordinamos? — *$biz*';
      case 'Entregado':
        return '¡Hola $nombreCliente! 🎉 Tu pedido *$folio* fue entregado. ¡Gracias por confiar en *$biz*! Si necesitas algo más, con gusto te atendemos. 😊';
      case 'Cancelado':
        return 'Hola $nombreCliente, te confirmamos que tu pedido *$folio* fue cancelado. Si tienes dudas o quieres retomarlo más adelante, contáctanos. — *$biz*';
      default:
        return trf('¡Hola {0}! Tu pedido *{1}* está en proceso. — *{2}*', [nombreCliente, folio, biz]);
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
    final msg = trf('¡Hola *{0}*! 😊\n\nTe comparto la cotización *{1}* de *HETNA CNC*.\n\nIncluye todos los detalles del trabajo solicitado. Cualquier ajuste con gusto lo hacemos.\n\n¡Quedamos a tus órdenes! 💙\n📱 2461217072', [nombreCliente, folio]);
    await abrirChat(numero: whatsapp, mensaje: msg);
  }

  // ── Enviar avance de pedido ──────────────────────────
  static Future<void> enviarAvancePedido({
    required String whatsapp,
    required String nombreCliente,
    required String folio,
    required String etapa,
    DateTime? fechaEstimada,
    String? empresa,
    String? pedidoId,
  }) async {
    final msg = await getPlantillaAvance(
      etapa: etapa, nombreCliente: nombreCliente, folio: folio,
      empresa: empresa, pedidoId: pedidoId);
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
