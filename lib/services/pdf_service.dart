import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class PdfService {
  static final _fmt = NumberFormat('#,##0.00', 'es_MX');
  static final _fmtFecha = DateFormat('dd/MM/yyyy', 'es_MX');

  static const String _logoB64 = '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';

  static Uint8List get _logoBytes {
    try { return base64Decode(_logoB64); } catch (_) { return Uint8List(0); }
  }

  static Future<void> verPdf(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> compartirPdf(Uint8List bytes, String nombre) async {
    await Printing.sharePdf(bytes: bytes, filename: nombre);
  }

  static Future<Uint8List> generarCotizacion({
    required Cotizacion cotizacion,
    required Map<String, dynamic> empresa,
  }) async {
    final pdf = pw.Document();
    pw.MemoryImage? logoImage;
    try {
      final bytes = _logoBytes;
      if (bytes.isNotEmpty) logoImage = pw.MemoryImage(bytes);
    } catch (_) {}

    const azul = PdfColor.fromInt(0xFF1a3a5c);
    const azulClaro = PdfColor.fromInt(0xFFe6f1fb);
    const grisClaro = PdfColor.fromInt(0xFFf5f6fa);
    const grisTexto = PdfColor.fromInt(0xFF6B7280);
    const verde = PdfColor.fromInt(0xFF1d9e75);
    const blanco70 = PdfColor.fromInt(0xB3FFFFFF);

    final nombreEmpresa = empresa['nombre_comercial'] ?? 'HETNA CNC';
    final rfcEmpresa = empresa['rfc'] ?? '';
    final direccion = empresa['direccion'] ?? '';
    final tel1 = empresa['telefono1'] ?? '';
    final tel2 = empresa['telefono2'] ?? '';
    final correoEmpresa = empresa['correo'] ?? '';
    final web = empresa['sitio_web'] ?? 'hetnacnc.com';
    final cliente = cotizacion.cliente;
    final folio = cotizacion.folio ?? 'COT-${DateTime.now().millisecondsSinceEpoch}';
    final fecha = _fmtFecha.format(cotizacion.createdAt ?? DateTime.now());
    final vigenciaDias = cotizacion.vigenciaDias;
    final fechaVigencia = _fmtFecha.format(
      (cotizacion.createdAt ?? DateTime.now()).add(Duration(days: vigenciaDias)));

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        // ─── ENCABEZADO ─────────────────────
        pw.Container(
          decoration: pw.BoxDecoration(color: azul, borderRadius: pw.BorderRadius.circular(8)),
          padding: const pw.EdgeInsets.all(16),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                if (logoImage != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Image(logoImage, width: 100, height: 28, fit: pw.BoxFit.contain))
                else
                  pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.SizedBox(height: 8),
                if (rfcEmpresa.isNotEmpty)
                  pw.Text('RFC: $rfcEmpresa', style: pw.TextStyle(fontSize: 8, color: blanco70)),
                if (direccion.isNotEmpty)
                  pw.Text(direccion, style: pw.TextStyle(fontSize: 8, color: blanco70)),
                pw.Text('Tel: $tel1${tel2.isNotEmpty ? " / $tel2" : ""}', style: pw.TextStyle(fontSize: 8, color: blanco70)),
                if (correoEmpresa.isNotEmpty)
                  pw.Text(correoEmpresa, style: pw.TextStyle(fontSize: 8, color: blanco70)),
                pw.Text(web, style: pw.TextStyle(fontSize: 8, color: PdfColors.white)),
              ]),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('COTIZACIÓN', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: azul)),
                  pw.SizedBox(height: 4),
                  pw.Text(folio, style: pw.TextStyle(fontSize: 10, color: azul)),
                  pw.SizedBox(height: 6),
                  pw.Row(children: [pw.Text('Fecha: ', style: pw.TextStyle(fontSize: 9, color: grisTexto)), pw.Text(fecha, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: grisTexto))]),
                  pw.Row(children: [pw.Text('Vigencia: ', style: pw.TextStyle(fontSize: 9, color: grisTexto)), pw.Text(fechaVigencia, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: grisTexto))]),
                ])),
            ])),
        pw.SizedBox(height: 14),
        // ─── CLIENTE ────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: grisClaro, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: PdfColors.grey300)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('CLIENTE', style: pw.TextStyle(fontSize: 9, color: grisTexto, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(cliente?.nombreCompleto ?? 'Sin cliente', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: azul)),
            if (cliente?.rfc != null) pw.Text('RFC: ${cliente!.rfc}', style: pw.TextStyle(fontSize: 9, color: grisTexto)),
            if (cliente?.correo != null) pw.Text(cliente!.correo!, style: pw.TextStyle(fontSize: 9, color: grisTexto)),
            if (cliente?.telefono != null) pw.Text('Tel: ${cliente!.telefono}', style: pw.TextStyle(fontSize: 9, color: grisTexto)),
          ])),
        pw.SizedBox(height: 14),
        // ─── TABLA PRODUCTOS ────────────────
        pw.Text('DETALLE DE LA COTIZACIÓN', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3.5),
            1: const pw.FixedColumnWidth(40),
            2: const pw.FixedColumnWidth(70),
            3: const pw.FixedColumnWidth(70),
          },
          children: [
            pw.TableRow(decoration: pw.BoxDecoration(color: azul), children: [
              _cH('TÍTULO / DESCRIPCIÓN'), _cH('CANT.'), _cH('PRECIO'), _cH('SUBTOTAL'),
            ]),
            ...List.generate(cotizacion.items.length, (i) {
              final item = cotizacion.items[i];
              final nombreLimpio = _limpiarTexto(item.nombreProducto);
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : grisClaro),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(7),
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(nombreLimpio,
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
                      if (item.sku != null && item.sku!.isNotEmpty)
                        pw.Text('SKU: ${item.sku}',
                          style: pw.TextStyle(fontSize: 7, color: grisTexto)),
                    ])),
                  _cD('${item.cantidad}', center: true),
                  _cD('\$${_fmt.format(item.precioUnitario)}', right: true),
                  _cD('\$${_fmt.format(item.subtotal)}', right: true),
                ]);
            }),
          ]),
        pw.SizedBox(height: 12),
        // ─── TOTALES ────────────────────────
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(width: 220, child: pw.Column(children: [
            if (cotizacion.descuentoPct > 0) _tR('Subtotal', '\$${_fmt.format(cotizacion.subtotal)}', grisTexto),
            if (cotizacion.descuentoPct > 0) _tR('Descuento ${cotizacion.descuentoPct.toInt()}%', '-\$${_fmt.format(cotizacion.montoDescuento)}', verde),
            if (cotizacion.ivaPct > 0) _tR('IVA ${cotizacion.ivaPct.toInt()}%', '\$${_fmt.format(cotizacion.montoIva)}', grisTexto),
            if (cotizacion.costoEnvio > 0) _tR('Envío', '\$${_fmt.format(cotizacion.costoEnvio)}', grisTexto),
            pw.Divider(color: azul),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOTAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: azul)),
              pw.Text('\$${_fmt.format(cotizacion.total)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: azul)),
            ]),
          ])),
        ]),
        pw.SizedBox(height: 14),
        // ─── CONDICIONES ────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: azulClaro, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('CONDICIONES', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: azul)),
            pw.SizedBox(height: 6),
            if (cotizacion.metodoPago != null) _cond('Pago:', cotizacion.metodoPago!, grisTexto),
            if (cotizacion.condicionEntrega != null) _cond('Entrega:', cotizacion.condicionEntrega!, grisTexto),
            _cond('Vigencia:', '$vigenciaDias días hábiles', grisTexto),
            if (cotizacion.notas != null && cotizacion.notas!.isNotEmpty) _cond('Notas:', cotizacion.notas!, grisTexto),
          ])),
        pw.SizedBox(height: 12),
        // ─── PIE ────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: azul, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('¡Gracias por su preferencia!', style: pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              pw.Text('Estamos para servirle — $nombreEmpresa', style: pw.TextStyle(fontSize: 9, color: blanco70)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(web, style: pw.TextStyle(fontSize: 9, color: PdfColors.white)),
              pw.Text(tel1, style: pw.TextStyle(fontSize: 9, color: blanco70)),
            ]),
          ])),
      ],
    ));
    return pdf.save();
  }

  static pw.Widget _cH(String t) => pw.Padding(padding: const pw.EdgeInsets.all(7),
    child: pw.Text(t, style: pw.TextStyle(fontSize: 9, color: PdfColors.white, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center));

  static pw.Widget _cD(String t, {bool center = false, bool right = false}) =>
    pw.Padding(padding: const pw.EdgeInsets.all(7),
      child: pw.Text(t, style: const pw.TextStyle(fontSize: 10),
        textAlign: right ? pw.TextAlign.right : (center ? pw.TextAlign.center : pw.TextAlign.left)));

  static pw.Widget _tR(String label, String valor, PdfColor color) =>
    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: color)),
        pw.Text(valor, style: pw.TextStyle(fontSize: 10, color: color, fontWeight: pw.FontWeight.bold)),
      ]));

  static pw.Widget _cond(String label, String valor, PdfColor color) =>
    pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1a3a5c))),
        pw.SizedBox(width: 4),
        pw.Expanded(child: pw.Text(valor, style: pw.TextStyle(fontSize: 9, color: color))),
      ]));

  // Fix 3: Limpiar caracteres especiales que aparecen como "tachas" en el PDF
  static String _limpiarTexto(String texto) {
    return texto
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('‘', "'")
      .replaceAll('’', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('•', '*')
      .replaceAll('×', 'x')
      .replaceAll('✕', 'x')
      .replaceAll('❌', '')
      .replaceAll('→', '->')
      .replaceAll('←', '<-')
      .replaceAll('✓', 'OK')
      .replaceAll('✗', 'x')
      .replaceAll('✘', 'x')
      .replaceAll('©', '(c)')
      .replaceAll('®', '(R)')
      .replaceAll('™', 'TM')
      .replaceAll('°', ' grados');
  }

  // ══════════════════════════════════════════
  // Generar PDF de lista de productos (catálogo)
  // ══════════════════════════════════════════
  static Future<Uint8List> generarListadoProductos({
    required String nombreLista,
    required List<Producto> productos,
    required Map<String, dynamic> empresa,
  }) async {
    final pdf = pw.Document();
    pw.MemoryImage? logoImage;
    try {
      final bytes = _logoBytes;
      if (bytes.isNotEmpty) logoImage = pw.MemoryImage(bytes);
    } catch (_) {}

    const azul = PdfColor.fromInt(0xFF1a3a5c);
    const azulClaro = PdfColor.fromInt(0xFFe6f1fb);
    const grisClaro = PdfColor.fromInt(0xFFf5f6fa);
    const grisTexto = PdfColor.fromInt(0xFF6B7280);
    const verde = PdfColor.fromInt(0xFF1d9e75);

    final nombreEmpresa = empresa['nombre_comercial'] ?? 'HETNA CNC';
    final tel = empresa['telefono'] ?? '';
    final correo = empresa['correo'] ?? '';
    final web = empresa['sitio_web'] ?? 'hetnacnc.com';
    final fecha = _fmtFecha.format(DateTime.now());

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Column(children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: const pw.BoxDecoration(color: azul),
          child: pw.Row(children: [
            logoImage != null
              ? pw.Container(
                  width: 50, height: 50,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(8)),
                  padding: const pw.EdgeInsets.all(4),
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain))
              : pw.SizedBox(width: 0),
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(nombreEmpresa,
                style: pw.TextStyle(color: PdfColors.white,
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Lista de Precios — $nombreLista',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
              pw.Text('Fecha: $fecha',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
            ])),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              if (tel.isNotEmpty) pw.Text(tel,
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
              if (correo.isNotEmpty) pw.Text(correo,
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
              pw.Text(web, style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
            ]),
          ])),
        pw.SizedBox(height: 8),
      ]),
      build: (ctx) => [
        // Tabla de productos
        pw.Table(
          border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3.5),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: azul),
              children: [
                _celdaHeader('PRODUCTO / DESCRIPCIÓN'),
                _celdaHeader('CATEGORÍA'),
                _celdaHeader('UNIDAD'),
                _celdaHeader('PRECIO'),
              ]),
            // Filas de productos
            ...List.generate(productos.length, (i) {
              final p = productos[i];
              final bgColor = i % 2 == 0 ? PdfColors.white : grisClaro;
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bgColor),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(_limpiarTexto(p.nombre),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
                      if (p.descripcion != null && p.descripcion!.isNotEmpty)
                        pw.Text(_limpiarTexto(p.descripcion!),
                          style: const pw.TextStyle(fontSize: 8, color: grisTexto)),
                    ])),
                  pw.Padding(padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(p.categoriaNombre ?? '—',
                      style: const pw.TextStyle(fontSize: 9, color: grisTexto))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(p.unidadMedida,
                      style: const pw.TextStyle(fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('\$${_fmt.format(p.precioVenta)}',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: verde))),
                ]);
            }),
          ]),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: azulClaro, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Total de productos: ${productos.length}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
            pw.Text('Los precios no incluyen IVA',
              style: const pw.TextStyle(fontSize: 9, color: grisTexto)),
          ])),
        pw.SizedBox(height: 8),
        pw.Text('Para pedidos o más información: $tel • $correo • $web',
          style: const pw.TextStyle(fontSize: 9, color: grisTexto),
          textAlign: pw.TextAlign.center),
      ]));

    return pdf.save();
  }

  static pw.Widget _celdaHeader(String texto) => pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(texto,
      style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)));
  // ══════════════════════════════════════════════════════
  // NOTA DE COMPRA
  // ══════════════════════════════════════════════════════
  static Future<Uint8List> generarNotaCompra({
    required Cotizacion cotizacion,
    required Map<String, dynamic> empresa,
    String? folioPedido,
  }) async {
    final pdf = pw.Document();
    pw.MemoryImage? logoImage;
    try {
      final bytes = _logoBytes;
      if (bytes.isNotEmpty) logoImage = pw.MemoryImage(bytes);
    } catch (_) {}

    const azul       = PdfColor.fromInt(0xFF1a3a5c);
    const azulClaro  = PdfColor.fromInt(0xFFe6f1fb);
    const grisClaro  = PdfColor.fromInt(0xFFf5f6fa);
    const grisTexto  = PdfColor.fromInt(0xFF6B7280);
    const verde      = PdfColor.fromInt(0xFF1d9e75);
    const verdeClaro = PdfColor.fromInt(0xFFe6f7f0);

    final nombreEmpresa    = empresa['nombre_comercial'] ?? 'HETNA CNC';
    final telEmpresa       = empresa['telefono'] ?? empresa['telefono2'] ?? '';
    final direccionEmpresa = empresa['direccion'] ?? '';
    final correo           = empresa['correo']   ?? '';
    final web              = empresa['sitio_web'] ?? 'hetnacnc.com';
    final fecha            = _fmtFecha.format(DateTime.now());
    final clienteNombre    = _limpiarTexto(cotizacion.cliente?.nombreCompleto ?? cotizacion.cliente?.nombre ?? 'Cliente');
    final folio            = folioPedido ?? cotizacion.folio ?? 'N/A';

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // Header
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(color: azul, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(children: [
            logoImage != null
              ? pw.Container(
                  width: 48, height: 48,
                  decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(6)),
                  padding: const pw.EdgeInsets.all(4),
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain))
              : pw.SizedBox(width: 0),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.Text('NOTA DE COMPRA', style: pw.TextStyle(fontSize: 11, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              pw.Text('Fecha: $fecha', style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
            ])),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(color: verde, borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Text('ENTREGADO', style: pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 4),
              pw.Text('Folio: $folio', style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
            ]),
          ])),
        pw.SizedBox(height: 14),
        // Cliente
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: azulClaro, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('CLIENTE', style: pw.TextStyle(fontSize: 8, color: grisTexto, fontWeight: pw.FontWeight.bold)),
              pw.Text(clienteNombre, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: azul)),
            ]),
            pw.Text('Nota de entrega', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
          ])),
        pw.SizedBox(height: 12),
        // Tabla
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3.5),
            1: const pw.FixedColumnWidth(40),
            2: const pw.FixedColumnWidth(75),
            3: const pw.FixedColumnWidth(75),
          },
          children: [
            pw.TableRow(decoration: pw.BoxDecoration(color: azul), children: [
              _cH('TÍTULO / DESCRIPCIÓN'), _cH('CANT.'), _cH('PRECIO'), _cH('SUBTOTAL'),
            ]),
            ...List.generate(cotizacion.items.length, (i) {
              final item = cotizacion.items[i];
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : grisClaro),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(7),
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(_limpiarTexto(item.nombreProducto),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
                      if (item.sku != null && item.sku!.isNotEmpty)
                        pw.Text('SKU: ${item.sku}',
                          style: pw.TextStyle(fontSize: 7, color: grisTexto)),
                    ])),
                  _cD('${item.cantidad}', center: true),
                  _cD('\$${_fmt.format(item.precioUnitario)}', right: true),
                  _cD('\$${_fmt.format(item.subtotal)}', right: true),
                ]);
            }),
          ]),
        pw.SizedBox(height: 10),
        // Total
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(width: 230,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: verdeClaro, borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: verde, width: 1)),
            child: pw.Column(children: [
              if (cotizacion.descuentoPct > 0) _tR('Descuento', '-\$${_fmt.format(cotizacion.montoDescuento)}', verde),
              if (cotizacion.ivaPct > 0) _tR('IVA ${cotizacion.ivaPct.toInt()}%', '\$${_fmt.format(cotizacion.montoIva)}', grisTexto),
              pw.Divider(color: verde),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TOTAL PAGADO', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: verde)),
                pw.Text('\$${_fmt.format(cotizacion.total)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: verde)),
              ]),
            ])),
        ]),
        pw.SizedBox(height: 16),
        // Firmas
        pw.Row(children: [
          pw.Expanded(child: pw.Column(children: [
            pw.Container(height: 40, decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)))),
            pw.SizedBox(height: 4),
            pw.Text('Firma del cliente', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
            pw.Text(clienteNombre, style: pw.TextStyle(fontSize: 9, color: grisTexto)),
          ])),
          pw.SizedBox(width: 40),
          pw.Expanded(child: pw.Column(children: [
            pw.Container(height: 40, decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)))),
            pw.SizedBox(height: 4),
            pw.Text('Firma de entrega', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
            pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 9, color: grisTexto)),
          ])),
        ]),
        pw.SizedBox(height: 12),
        // Pie
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: azul, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Gracias por su preferencia', style: pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              pw.Text('$tel1  $correo', style: const pw.TextStyle(fontSize: 8, color: PdfColors.white)),
            ]),
            pw.Text(web, style: pw.TextStyle(fontSize: 9, color: PdfColors.white)),
          ])),
      ])));

    return pdf.save();
  }

}
