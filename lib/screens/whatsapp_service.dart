// lib/services/whatsapp_service.dart
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  /// Normaliza número de WhatsApp mexicano al formato correcto
  /// Formatos válidos de entrada:
  /// +522217076014, 522217076014, 2217076014, 12217076014
  /// Salida esperada: 5212217076014 (13 dígitos)
  static String normalizarNumero(String numero) {
    // Quitar todo excepto dígitos
    var n = numero.replaceAll(RegExp(r'[^0-9]'), '');

    if (n.isEmpty) return '';

    // Si tiene 10 dígitos (número local sin código) → agregar 521
    if (n.length == 10) return '521$n';

    // Si tiene 11 dígitos empezando con 1 → agregar 52
    if (n.length == 11 && n.startsWith('1')) return '52$n';

    // Si tiene 12 dígitos empezando con 52 → agregar 1
    if (n.length == 12 && n.startsWith('52')) return '521${n.substring(2)}';

    // Si tiene 13 dígitos empezando con 521 → ya está correcto
    if (n.length == 13 && n.startsWith('521')) return n;

    // Fallback: devolver como está
    return n;
  }

  /// Abre WhatsApp con un mensaje prellenado
  static Future<bool> abrirChat({
    required String numero,
    required String mensaje,
  }) async {
    final n = normalizarNumero(numero);
    if (n.isEmpty) return false;

    final url = 'https://wa.me/$n?text=${Uri.encodeComponent(mensaje)}';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      // Intentar con scheme directo
      final urlDirecto = Uri.parse(
          'whatsapp://send?phone=$n&text=${Uri.encodeComponent(mensaje)}');
      if (await canLaunchUrl(urlDirecto)) {
        await launchUrl(urlDirecto, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Mensaje de cotización para enviar por WA
  static String mensajeCotizacion({
    required String nombreCliente,
    required List<String> items,
    required double subtotal,
    required double total,
    required double ivaPct,
    required double montoIva,
    required String metodoPago,
    required String tiempoEntrega,
    bool aplicaIva = true,
  }) {
    final fmt = _fmt;
    final itemsTexto = items.join('\n');
    final ivaLinea = aplicaIva ? '\nIVA ${ivaPct.toInt()}%: ${fmt(montoIva)}' : '';
    return '¡Hola $nombreCliente! 👋\n\n'
        'Te compartimos tu cotización de *HETNA CNC*:\n\n'
        '$itemsTexto\n\n'
        'Subtotal: ${fmt(subtotal)}$ivaLinea\n'
        '*TOTAL: ${fmt(total)}*\n\n'
        'Tiempo de entrega: $tiempoEntrega\n'
        'Método de pago: $metodoPago\n\n'
        '¿Te parece bien? Estamos para cualquier ajuste. 😊\n\n'
        '_HETNA CNC — Router CNC · Láser CO₂ · Fibra · Plasma_';
  }

  /// Mensaje de avance de pedido
  static String mensajeAvance({
    required String nombreCliente,
    required String folio,
    required String etapa,
    double? total,
  }) {
    final montoTexto = total != null ? ' por ${_fmt(total)}' : '';
    switch (etapa) {
      case 'Pago':
        return '¡Hola $nombreCliente! ✅ Confirmamos tu pago del pedido *$folio*$montoTexto. Ya empezamos a trabajar. — *HETNA CNC*';
      case 'Produccion':
        return '¡Hola $nombreCliente! 🔧 Tu pedido *$folio* está en producción. Te avisamos cuando esté listo. — *HETNA CNC*';
      case 'Pruebas':
        return '¡Hola $nombreCliente! 🔍 Tu pedido *$folio* está en control de calidad. ¡Casi listo! — *HETNA CNC*';
      case 'Entrega':
        return '¡Hola $nombreCliente! 📦 Tu pedido *$folio* está *LISTO*. ¿Cuándo coordinamos la entrega? — *HETNA CNC*';
      case 'Entregado':
        return '¡Hola $nombreCliente! 🎉 Tu pedido *$folio* fue entregado. ¡Gracias por confiar en *HETNA CNC*!\n\nSi necesitas algo más, con gusto te atendemos. 😊';
      default:
        return '¡Hola $nombreCliente! Tu pedido *$folio* está en proceso. — *HETNA CNC*';
    }
  }

  /// Mensaje de seguimiento de alerta
  static String mensajeSeguimiento({
    required String nombreCliente,
    required String tipo,
    String? folio,
    double? total,
  }) {
    final folioTexto = folio != null ? 'cotización *$folio*' : 'tu cotización';
    switch (tipo) {
      case 'seguimiento_dia3':
        return '¡Hola $nombreCliente! 😊 Te escribo de *HETNA CNC* para saber si pudiste revisar la $folioTexto. ¿Tienes alguna duda? Estamos para ayudarte.';
      case 'seguimiento_dia5':
        return '¡Hola $nombreCliente! Te contacto de *HETNA CNC* sobre la $folioTexto. ¿Podemos platicar para ver si hay algo que ajustar?';
      case 'seguimiento_dia7':
        return '¡Hola $nombreCliente! La $folioTexto vence pronto. Si te interesa, podemos hacer un ajuste especial esta semana. 🎯 — *HETNA CNC*';
      case 'post_entrega':
        return '¡Hola $nombreCliente! Esperamos que estés disfrutando tu pedido de *HETNA CNC*. ¿Cómo te fue? 😊\n\nSíguenos en @hetna_cnc para ver proyectos y promociones.';
      default:
        return '¡Hola $nombreCliente! Te escribo de *HETNA CNC*. ¿Podemos ayudarte con algo?';
    }
  }

  static String _fmt(double monto) {
    final partes = monto.toStringAsFixed(0).split('.');
    final entero = partes[0];
    final resultado = StringBuffer();
    for (int i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) resultado.write(',');
      resultado.write(entero[i]);
    }
    return '\$$resultado';
  }
}
