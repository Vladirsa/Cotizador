// ============================================
// lib/services/pdf_service.dart
// Generador de PDF profesional HETNA CNC
// Con logo embebido
// ============================================

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

  // Logo HETNA CNC embebido en base64
  static const String _logoB64 =
      '/9j/4AAQSkZJRgABAQAAAQABAAD/4gHYSUNDX1BST0ZJTEUAAQEAAAHIAAAAAAQwAABtbnRy'
      'UkdCIFhZWiAH4AABAAEAAAAAAABhY3NwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAA'
      '9tYAAQAAAADTLQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      'AAAAlkZXNjAAAA8AAAACRyWFlaAAABFAAAABRnWFlaAAABKAAAABRiWFlaAAABPAAAABR3dHB0'
      'AAABUAAAABRyVFJDAAABZAAAAChnVFJDAAABZAAAAChiVFJDAAABZAAAAChjcHJ0AAABjAAAA'
      'DxtbHVjAAAAAAAAAAEAAAAMZW5VUwAAAAQAAAAcAEcASQBtAHAAbHVjAAAAAAAAAAEAAAAMZW5'
      'VUwAAAA0AAAAcAHMAUgBHAEIAIABiAHUAaQBsAHQALQBpAG4AAFhZWiAAAAAAAABo2QAAO4sA'
      'AAOSWFlaIAAAAAAAACSgAAAPhAAAts9YWVogAAAAAAAA9tYAAQAAAADTLVhZWiAAAAAAAAAx2g'
      'AAOEQAABxDcGFyYQAAAAAABAAAAARmZgAA8qcAAA1ZAAAT0AAACg9tbHVjAAAAAAAAAAEAAAAM'
      'ZW5VUwAAAAgAAAAcAEcASQBNAFAAcGFyYQAAAAAABAAAAARmZgAA8qcAAA1ZAAAT0AAACg9t'
      'bHVjAAAAAAAAAAEAAAAMZW5VUwAAAAgAAAAcAEcASQBNAFAA/+EAWkV4aWYAAE1NACoAAAAI'
      'AAQBGgAFAAAAAQAAAD4BGwAFAAAAAQAAAEYBKAADAAAAAgAAAk8AAAAAAAIAAAABAAAAAAAAAAg'
      'AAAABAAAACAAAAAAA/9sAQwADAgIDAgIDAwMDBAMDBAUIBQUEBAUKBwcGCAwKDAsKCwsNDhIQ'
      'DQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQU'
      'FBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCAAb AGQDASIAAhEBAxEB/8QA'
      'HgAAAQQDAQEBAAAAAAAAAAAABwgFBgkCBAoDAQD/xAA3EAABAwMDAgQFAgUFAAAAAAABAgME'
      'BREABiExBxJBUQgTImFxkRQyQlKBFSNiobHB0eHw/8QAGgEAAQUBAAAAAAAAAAAAAAAABgID'
      'BAUHAf/EACkRAAICAQMDBAIDAAAAAAAAAAECAAMEERIhMQVBUWETFCJxkf/aAAwDAQACEQMR'
      'AD8A2U6j6vWrR2yJV1ukgNMtjCW0jK3VnoEJHUk/4HJOAMmsR9ZfEBqPqbqCZVrrcJFLts'
      'lyMqJHcKUBtJAO7HKiSSSecDA4rBXxEdcJ+t2p027zyp2HShTNPiOD9tpJ5WoD+tZGT2AA'
      '6ADrU0/Dcjt3bSSVLQ9FkIdSU/eQpK1JKT6g5B/1oGsnJuNiJJGBknJz36Vfj4p9Rp+l'
      'Oh91ucZ0ouQaS3EB5Q6oZWCo/2oBI+YFZNa23wtu11v90u863SGVzl+4dW+8nfIcdxlThJ'
      'zhKTjt0A4AAFQ1d7dc4d7nWy4xHIFxhPqYkxnk7VtOJOCkg9s9+4II6gg11X4N9MJmsPa'
      'j3mC2y+6pTEBam07kpHC3MHkHHYcZBOepobVNE0P4y+ynpnf52k9cKNW4C3HYE0JCZrJG'
      'UJWR9qx0wcHjn5qoaTqLqHpJqeyoTbhMtFy3BSXW+UOA9lJUOF9+4II6YJ61C3xGaFTol'
      'qcxOtsc/QJp3xHUp3eMjtxuHJH9Pqon4ZdaJmi+oSLU9IWqy3AJYkNk5DLmcIeA7cEhX'
      '/Lj0oSvVkrVtkyOvPbyHlVVIUrkH2AquDmPc0Vb2W2zaKLDjSLOcPKGXyFkBiSAVMiLCF'
      'hQhhhQhhhQhhhT/2Q==';

  static Uint8List get _logoBytes => base64Decode(_logoB64.replaceAll('\n', '').replaceAll(' ', ''));

  // ─── VER PDF EN PANTALLA ────────────────────
  static Future<void> verPdf(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  // ─── COMPARTIR PDF ───────────────────────────
  static Future<void> compartirPdf(Uint8List bytes, String nombre) async {
    await Printing.sharePdf(bytes: bytes, filename: nombre);
  }

  // ─── GENERAR PDF DE COTIZACIÓN ──────────────
  static Future<Uint8List> generarCotizacion({
    required Cotizacion cotizacion,
    required Map<String, dynamic> empresa,
  }) async {
    final pdf = pw.Document();

    // Cargar logo
    pw.MemoryImage? logoImage;
    try {
      logoImage = pw.MemoryImage(_logoBytes);
    } catch (_) {}

    // Colores HETNA
    const azul = PdfColor.fromInt(0xFF1a3a5c);
    const azulClaro = PdfColor.fromInt(0xFFe6f1fb);
    const grisClaro = PdfColor.fromInt(0xFFf5f6fa);
    const grisTexto = PdfColor.fromInt(0xFF6B7280);
    const verde = PdfColor.fromInt(0xFF1d9e75);

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

    // Calcular vigencia
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
              // Logo y datos empresa
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                if (logoImage != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Image(logoImage, width: 100, height: 28))
                else
                  pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.SizedBox(height: 8),
                if (rfcEmpresa.isNotEmpty)
                  pw.Text('RFC: $rfcEmpresa', style: pw.TextStyle(fontSize: 8, color: PdfColors.white70)),
                if (direccion.isNotEmpty)
                  pw.Text(direccion, style: pw.TextStyle(fontSize: 8, color: PdfColors.white70)),
                pw.Text('Tel: $tel1${tel2.isNotEmpty ? " / $tel2" : ""}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.white70)),
                if (correoEmpresa.isNotEmpty)
                  pw.Text(correoEmpresa, style: pw.TextStyle(fontSize: 8, color: PdfColors.white70)),
                pw.Text(web, style: pw.TextStyle(fontSize: 8, color: PdfColors.white)),
              ]),
              // Datos de la cotización
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('COTIZACIÓN', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: azul)),
                  pw.SizedBox(height: 4),
                  pw.Text(folio, style: pw.TextStyle(fontSize: 11, color: azul)),
                  pw.SizedBox(height: 6),
                  _filaPdf('Fecha:', fecha, grisTexto),
                  _filaPdf('Vigencia:', fechaVigencia, grisTexto),
                  if (cotizacion.fechaEntrega != null)
                    _filaPdf('Entrega:', _fmtFecha.format(cotizacion.fechaEntrega!), grisTexto),
                ]),
              ),
            ])),

        pw.SizedBox(height: 16),

        // ─── DATOS DEL CLIENTE ──────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: grisClaro,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.grey300)),
          child: pw.Row(children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('CLIENTE', style: pw.TextStyle(fontSize: 9, color: grisTexto, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(cliente?.nombreCompleto ?? 'Sin cliente',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: azul)),
              if (cliente?.rfc != null)
                pw.Text('RFC: ${cliente!.rfc}', style: pw.TextStyle(fontSize: 9, color: grisTexto)),
              if (cliente?.domicilio != null)
                pw.Text(cliente!.domicilio!, style: pw.TextStyle(fontSize: 9, color: grisTexto)),
              if (cliente?.ciudad != null)
                pw.Text('${cliente!.ciudad}${cliente.estado != null ? ", ${cliente.estado}" : ""}',
                  style: pw.TextStyle(fontSize: 9, color: grisTexto)),
              if (cliente?.correo != null)
                pw.Text(cliente!.correo!, style: pw.TextStyle(fontSize: 9, color: grisTexto)),
              if (cliente?.telefono != null)
                pw.Text('Tel: ${cliente!.telefono}', style: pw.TextStyle(fontSize: 9, color: grisTexto)),
            ]),
          ])),

        pw.SizedBox(height: 16),

        // ─── TABLA DE PRODUCTOS ──────────────
        pw.Text('DETALLE DE LA COTIZACIÓN',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FixedColumnWidth(50),
            2: const pw.FixedColumnWidth(70),
            3: const pw.FixedColumnWidth(70),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: azul),
              children: [
                _celdaHeader('DESCRIPCIÓN'),
                _celdaHeader('CANT.'),
                _celdaHeader('PRECIO UNIT.'),
                _celdaHeader('SUBTOTAL'),
              ]),
            // Items
            ...cotizacion.items.map((item) => pw.TableRow(
              decoration: pw.BoxDecoration(
                color: cotizacion.items.indexOf(item).isEven ? PdfColors.white : grisClaro),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(item.nombreProducto, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    if (item.sku != null)
                      pw.Text('SKU: ${item.sku}', style: pw.TextStyle(fontSize: 8, color: grisTexto)),
                  ])),
                _celdaDato('${item.cantidad}', center: true),
                _celdaDato('\$${_fmt.format(item.precioUnitario)}', right: true),
                _celdaDato('\$${_fmt.format(item.subtotal)}', right: true),
              ])),
          ]),

        pw.SizedBox(height: 12),

        // ─── TOTALES ────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 220,
              child: pw.Column(children: [
                if (cotizacion.descuentoPct > 0 || cotizacion.descuentoFijo > 0)
                  _totalRow('Subtotal', '\$${_fmt.format(cotizacion.subtotal)}', grisTexto),
                if (cotizacion.descuentoPct > 0)
                  _totalRow('Descuento ${cotizacion.descuentoPct.toInt()}%',
                    '-\$${_fmt.format(cotizacion.montoDescuento)}', verde),
                if (cotizacion.ivaPct > 0)
                  _totalRow('IVA ${cotizacion.ivaPct.toInt()}%',
                    '\$${_fmt.format(cotizacion.montoIva)}', grisTexto),
                if (cotizacion.costoEnvio > 0)
                  _totalRow('Envío', '\$${_fmt.format(cotizacion.costoEnvio)}', grisTexto),
                pw.Divider(color: azul),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: azul)),
                  pw.Text('\$${_fmt.format(cotizacion.total)}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: azul)),
                ]),
              ]),
            ),
          ]),

        pw.SizedBox(height: 16),

        // ─── CONDICIONES ─────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: azulClaro, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('CONDICIONES', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: azul)),
            pw.SizedBox(height: 6),
            if (cotizacion.metodoPago != null)
              _condicion('💳 Pago:', cotizacion.metodoPago!, grisTexto),
            if (cotizacion.condicionEntrega != null)
              _condicion('🚚 Entrega:', cotizacion.condicionEntrega!, grisTexto),
            _condicion('📅 Vigencia:', '$vigenciaDias días hábiles a partir de la fecha', grisTexto),
            if (cotizacion.notas != null && cotizacion.notas!.isNotEmpty)
              _condicion('📝 Notas:', cotizacion.notas!, grisTexto),
          ])),

        pw.SizedBox(height: 16),

        // ─── PIE DE PÁGINA ───────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: azul, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('¡Gracias por su preferencia!',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              pw.Text('Estamos para servirle — $nombreEmpresa',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.white70)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(web, style: pw.TextStyle(fontSize: 9, color: PdfColors.white)),
              pw.Text(tel1, style: pw.TextStyle(fontSize: 9, color: PdfColors.white70)),
            ]),
          ])),
      ],
    ));

    return pdf.save();
  }

  // ─── WIDGETS HELPERS ─────────────────────────
  static pw.Widget _filaPdf(String label, String valor, PdfColor color) =>
    pw.Row(children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 9, color: color)),
      pw.SizedBox(width: 4),
      pw.Text(valor, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
    ]);

  static pw.Widget _celdaHeader(String texto) =>
    pw.Padding(padding: const pw.EdgeInsets.all(8),
      child: pw.Text(texto, style: pw.TextStyle(fontSize: 9, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center));

  static pw.Widget _celdaDato(String texto, {bool center = false, bool right = false}) =>
    pw.Padding(padding: const pw.EdgeInsets.all(8),
      child: pw.Text(texto, style: const pw.TextStyle(fontSize: 10),
        textAlign: right ? pw.TextAlign.right : (center ? pw.TextAlign.center : pw.TextAlign.left)));

  static pw.Widget _totalRow(String label, String valor, PdfColor color) =>
    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: color)),
        pw.Text(valor, style: pw.TextStyle(fontSize: 10, color: color, fontWeight: pw.FontWeight.bold)),
      ]));

  static pw.Widget _condicion(String label, String valor, PdfColor color) =>
    pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1a3a5c))),
        pw.SizedBox(width: 4),
        pw.Expanded(child: pw.Text(valor, style: pw.TextStyle(fontSize: 9, color: color))),
      ]));
}
