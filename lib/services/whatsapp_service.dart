// ============================================
// lib/services/whatsapp_service.dart
// Envío por WhatsApp (Opción B - enlace directo)
// ============================================

import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class WhatsAppService {
  static final _fmt = NumberFormat('#,##0.00', 'es_MX');

  // ─── ENVIAR COTIZACIÓN ──────────────────────
  static Future<void> enviarCotizacion({
    required Cotizacion cotizacion,
    required String nombreCliente,
    required String whatsapp,
    required String empresa,
  }) async {
    final folio = cotizacion.folio ?? 'S/N';
    final total = _fmt.format(cotizacion.total);

    final mensaje = '''¡Hola $nombreCliente! 👋

Le comparto la cotización *No. $folio* de HETNA CNC.

📋 *Detalle:*
${cotizacion.items.map((i) => '• ${i.nombreProducto} x${i.cantidad} — \$${_fmt.format(i.subtotal)}').join('\n')}

💰 *Subtotal:* \$${_fmt.format(cotizacion.subtotal)}
${cotizacion.descuentoPct > 0 ? '🏷 *Descuento ${cotizacion.descuentoPct.toInt()}%:* -\$${_fmt.format(cotizacion.montoDescuento)}\n' : ''}💵 *IVA 16%:* \$${_fmt.format(cotizacion.montoIva)}
✅ *TOTAL: \$${total} MXN*

${cotizacion.metodoPago != null ? '💳 *Pago:* ${cotizacion.metodoPago}\n' : ''}${cotizacion.fechaEntrega != null ? '📅 *Entrega:* ${DateFormat('dd/MM/yyyy').format(cotizacion.fechaEntrega!)}\n' : ''}
⏳ Cotización vigente por *${cotizacion.vigenciaDias} días*.

Quedo a sus órdenes para cualquier duda o ajuste.

*HETNA CNC*
📱 hetnacnc.com''';

    await _abrirWhatsApp(whatsapp, mensaje);
  }

  // ─── SEGUIMIENTO DÍA 3 ─────────────────────
  static Future<void> enviarSeguimientoDia3({
    required String whatsapp,
    required String nombreCliente,
    required String folio,
    required double total,
  }) async {
    final mensaje = '''¡Hola $nombreCliente! 😊

Le escribo de *HETNA CNC* para darle seguimiento a la cotización *No. $folio* por \$${_fmt.format(total)} MXN.

¿Tuvo oportunidad de revisarla? Estamos disponibles para cualquier ajuste o información adicional que necesite.

Quedo a sus órdenes 🤝

*HETNA CNC*
📱 hetnacnc.com''';

    await _abrirWhatsApp(whatsapp, mensaje);
  }

  // ─── SEGUIMIENTO DÍA 5 ─────────────────────
  static Future<void> enviarSeguimientoDia5({
    required String whatsapp,
    required String nombreCliente,
    required String folio,
    required double total,
    required DateTime vencimiento,
  }) async {
    final fechaVence = DateFormat('dd \'de\' MMMM', 'es_MX').format(vencimiento);
    final mensaje = '''¡Hola $nombreCliente! 👋

Le recuerdo que la cotización *No. $folio* por \$${_fmt.format(total)} MXN vence el *$fechaVence*.

¿Hay algo que podamos ajustar en precio, condiciones o tiempos de entrega para que se adapte mejor a sus necesidades?

Estamos para servirle 💪

*HETNA CNC*
📱 hetnacnc.com''';

    await _abrirWhatsApp(whatsapp, mensaje);
  }

  // ─── CUPÓN DÍA 7 ───────────────────────────
  static Future<void> enviarCuponCierre({
    required String whatsapp,
    required String nombreCliente,
    required String folio,
    required String codigoCupon,
    int descuentoPct = 5,
  }) async {
    final mensaje = '''🎁 *Oferta especial para usted, $nombreCliente*

En HETNA CNC queremos ayudarle a tomar la mejor decisión, por eso le ofrecemos un *descuento adicional del $descuentoPct%* en su cotización *No. $folio*.

🏷 *Código:* `$codigoCupon`
⏰ *Válido hasta el viernes de esta semana*

Solo compártame este código al confirmar y aplicamos el descuento de inmediato.

¡No deje pasar esta oportunidad! 🚀

*HETNA CNC*
📱 hetnacnc.com''';

    await _abrirWhatsApp(whatsapp, mensaje);
  }

  // ─── POST-ENTREGA: REDES SOCIALES ──────────
  static Future<void> enviarRedesSociales({
    required String whatsapp,
    required String nombreCliente,
    required String instagram,
    required String facebook,
    String? tiktok,
  }) async {
    final mensaje = '''🎉 *¡Muchas gracias $nombreCliente!*

Fue un placer trabajar con usted. Esperamos que su equipo HETNA CNC supere todas sus expectativas.

Para mantenerse al tanto de nuestras *novedades, promociones y proyectos*, le invitamos a seguirnos en redes:

📸 *Instagram:* $instagram
👍 *Facebook:* $facebook
${tiktok != null ? '🎵 *TikTok:* $tiktok\n' : ''}
🎁 *¡Al seguirnos le enviamos un cupón del 3% de descuento para su próxima compra!*

Solo avíseme cuando nos haya seguido 😊

*HETNA CNC*
📱 hetnacnc.com''';

    await _abrirWhatsApp(whatsapp, mensaje);
  }

  // ─── CUPÓN POR SEGUIR EN REDES ─────────────
  static Future<void> enviarCuponSeguidor({
    required String whatsapp,
    required String nombreCliente,
    required String codigoCupon,
  }) async {
    final mensaje = '''🎁 *¡Gracias por seguirnos, $nombreCliente!*

Como prometimos, aquí está su cupón de *3% de descuento* para su próxima compra:

🏷 *Código:* `$codigoCupon`
✅ *Sin fecha de vencimiento*

¡Nos da mucho gusto tenerle en nuestra comunidad!

*HETNA CNC*
📱 hetnacnc.com''';

    await _abrirWhatsApp(whatsapp, mensaje);
  }

  // ─── NOTIFICACIÓN DE AVANCE DE PEDIDO ──────
  static Future<void> enviarAvancePedido({
    required String whatsapp,
    required String nombreCliente,
    required String folio,
    required String etapa,
    String? descripcion,
    DateTime? fechaEstimada,
  }) async {
    final etapasEmoji = {
      'Pedido': '✅',
      'Pago': '💳',
      'Produccion': '⚙️',
      'Pruebas': '🔬',
      'Entrega': '🚚',
      'Entregado': '🎉',
    };
    final emoji = etapasEmoji[etapa] ?? '📋';
    final fechaTxt = fechaEstimada != null
        ? '\n📅 *Fecha estimada de entrega:* ${DateFormat('dd/MM/yyyy').format(fechaEstimada)}'
        : '';

    final mensaje = '''$emoji *Actualización de su pedido $folio*

¡Hola $nombreCliente! Le informamos que su pedido ha avanzado a la etapa:

🔷 *$etapa*
${descripcion != null ? '\n$descripcion\n' : ''}$fechaTxt

Cualquier duda estamos a sus órdenes.

*HETNA CNC*
📱 hetnacnc.com''';

    await _abrirWhatsApp(whatsapp, mensaje);
  }

  // ─── ENVIAR CATÁLOGO (con link PDF) ────────
  static Future<void> enviarCatalogo({
    required String whatsapp,
    required String nombreCliente,
    required String urlPdf,
    String nombrePdf = 'Catálogo General HETNA CNC',
  }) async {
    final mensaje = '''¡Hola $nombreCliente! 😊

Con gusto le comparto nuestro *$nombrePdf*:

📄 $urlPdf

Encontrará toda nuestra línea de maquinaria CNC, refacciones, herramientas, consumibles y servicios con precios y especificaciones técnicas.

Si algún producto le interesa, con gusto le elaboramos una cotización personalizada 🤝

*HETNA CNC*
📱 hetnacnc.com''';

    await _abrirWhatsApp(whatsapp, mensaje);
  }
// ─── ABRIR CHAT DIRECTO ─────────────────────
  static Future<void> abrirChat({
    required String numero,
    required String nombre,
  }) async {
    final mensaje = 'Hola $nombre, te contacto de HETNA CNC.';
    await _abrirWhatsApp(numero, mensaje);
  }
  // ─── FUNCIÓN BASE ───────────────────────────
  static Future<void> _abrirWhatsApp(
      String numero, String mensaje) async {
    final num = numero.replaceAll(RegExp(r'[^0-9]'), '');
    final numConPais = num.startsWith('52') ? num : '52$num';
    final encoded = Uri.encodeComponent(mensaje);
    final uri = Uri.parse('https://wa.me/$numConPais?text=$encoded');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('No se pudo abrir WhatsApp');
    }
  }

  // ─── GENERAR CÓDIGO DE CUPÓN ────────────────
  static String generarCodigoCupon(String folio) {
    final fecha = DateTime.now();
    return 'HETNA-${folio.replaceAll(RegExp(r'[^0-9]'), '')}-${fecha.month}${fecha.year.toString().substring(2)}';
  }
}
