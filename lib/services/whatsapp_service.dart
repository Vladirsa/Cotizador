import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static String normalizarNumero(String numero) {
    var n = numero.replaceAll(RegExp(r'[^0-9]'), '');
    if (n.isEmpty) return '';
    if (n.length == 10) return '521$n';
    if (n.length == 11 && n.startsWith('1')) return '52$n';
    if (n.length == 12 && n.startsWith('52')) return '521${n.substring(2)}';
    if (n.length == 13 && n.startsWith('521')) return n;
    return n;
  }

  static Future<bool> abrirChat({
    required String numero,
    required String mensaje,
  }) async {
    final n = normalizarNumero(numero);
    if (n.isEmpty) return false;
    try {
      // Intentar primero con wa.me
      final uri = Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(mensaje)}');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    } catch (_) {
      try {
        // Fallback con intent directo
        final uri2 = Uri.parse('intent://send/$n#Intent;scheme=whatsapp;package=com.whatsapp;end');
        await launchUrl(uri2, mode: LaunchMode.externalApplication);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  static String mensajeSeguimiento({
    required String nombreCliente,
    required String tipo,
    String? folio,
    double? total,
  }) {
    final folioTexto = folio != null && folio.isNotEmpty ? 'cotización *$folio*' : 'tu cotización';
    switch (tipo) {
      case 'seguimiento_dia3':
        return '¡Hola $nombreCliente! 😊 Te escribo de *HETNA CNC* para saber si pudiste revisar la $folioTexto. ¿Tienes alguna duda? Estamos para ayudarte.';
      case 'seguimiento_dia5':
        return '¡Hola $nombreCliente! Te contacto de *HETNA CNC* sobre la $folioTexto. ¿Podemos platicar para ver si hay algo que ajustar?';
      case 'seguimiento_dia7':
        return '¡Hola $nombreCliente! La $folioTexto vence pronto. Si te interesa, podemos hacer un ajuste especial esta semana. 🎯 — *HETNA CNC*';
      case 'post_entrega':
        return '¡Hola $nombreCliente! Esperamos que estés disfrutando tu pedido de *HETNA CNC*. ¿Cómo te fue? 😊\n\nSíguenos en @hetna_cnc.';
      default:
        return '¡Hola $nombreCliente! Te escribo de *HETNA CNC*. ¿Podemos ayudarte con algo?';
    }
  }

  static String mensajeAvance({
    required String nombreCliente,
    required String folio,
    required String etapa,
    double? total,
  }) {
    switch (etapa) {
      case 'Pago':
        return '¡Hola $nombreCliente! ✅ Confirmamos tu pago del pedido *$folio*. Ya empezamos. — *HETNA CNC*';
      case 'Produccion':
        return '¡Hola $nombreCliente! 🔧 Tu pedido *$folio* está en producción. — *HETNA CNC*';
      case 'Pruebas':
        return '¡Hola $nombreCliente! 🔍 Tu pedido *$folio* está en control de calidad. ¡Casi listo! — *HETNA CNC*';
      case 'Entrega':
        return '¡Hola $nombreCliente! 📦 Tu pedido *$folio* está *LISTO*. ¿Cuándo coordinamos? — *HETNA CNC*';
      case 'Entregado':
        return '¡Hola $nombreCliente! 🎉 Tu pedido *$folio* fue entregado. ¡Gracias por confiar en *HETNA CNC*!';
      default:
        return '¡Hola $nombreCliente! Tu pedido *$folio* está en proceso. — *HETNA CNC*';
    }
  }

  // Compatibilidad con código anterior
  static Future<void> enviarCotizacion({
    required dynamic cotizacion,
    required String nombreCliente,
    required String whatsapp,
    required String empresa,
  }) async {
    final mensaje = '¡Hola $nombreCliente! Te compartimos tu cotización de *HETNA CNC*. Quedamos a tus órdenes.';
    await abrirChat(numero: whatsapp, mensaje: mensaje);
  }

  static Future<void> enviarAvancePedido({
    required String whatsapp,
    required String nombreCliente,
    required String folio,
    required String etapa,
    DateTime? fechaEstimada,
  }) async {
    final msg = mensajeAvance(nombreCliente: nombreCliente, folio: folio, etapa: etapa);
    await abrirChat(numero: whatsapp, mensaje: msg);
  }
}
