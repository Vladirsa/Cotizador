// ============================================
// lib/services/pdf_service.dart
// Generador de PDF profesional HETNA CNC
// ============================================

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class PdfService {
  static final _fmt = NumberFormat('#,##0.00', 'es_MX');
  static final _fmtFecha = DateFormat('dd/MM/yyyy', 'es_MX');

  // ─── GENERAR PDF DE COTIZACIÓN ──────────────
  static Future<Uint8List> generarCotizacion({
    required Cotizacion cotizacion,
    required Map<String, dynamic> empresa,
  }) async {
    final pdf = pw.Document();
    final logoUrl = empresa['logo_url'] as String?;
    pw.MemoryImage? logoImage;

    if (logoUrl != null) {
      try {
        final bytes = await networkImage(logoUrl);
        logoImage = pw.MemoryImage(bytes as Uint8List);
      } catch (_) {}
    }

    // Colores HETNA
    const azul = PdfColor.fromInt(0xFF1a3a5c);
    const grisClaro = PdfColor.fromInt(0xFFf5f6fa);
    const grisTexto = PdfColor.fromInt(0xFF666666);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [

          // ─── ENCABEZADO ─────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Logo y datos empresa
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoImage != null)
                    pw.Image(logoImage, width: 120, height: 50)
                  else
                    pw.Text(
                      empresa['nombre_comercial'] ?? 'HETNA CNC',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: azul,
                      ),
                    ),
                  pw.SizedBox(height: 8),
                  pw.Text(empresa['direccion'] ?? '',
                      style: pw.TextStyle(fontSize: 9, color: grisTexto)),
                  pw.Text(
                      'Tel: ${empresa['telefono1'] ?? ''}'
                      '${empresa['telefono2'] != null ? " / ${empresa['telefono2']}" : ""}',
                      style: pw.TextStyle(fontSize: 9, color: grisTexto)),
                  pw.Text(empresa['correo'] ?? '',
                      style: pw.TextStyle(fontSize: 9, color: grisTexto)),
                  pw.Text(empresa['sitio_web'] ?? '',
                      style: pw.TextStyle(fontSize: 9, color: azul)),
                ],
              ),
              // Datos cotización
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: azul,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('COTIZACIÓN',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('No. ${cotizacion.folio ?? ""}',
                        style: pw.TextStyle(
                            color: PdfColors.white, fontSize: 11)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                        'Fecha: ${_fmtFecha.format(cotizacion.createdAt ?? DateTime.now())}',
                        style: pw.TextStyle(
                            color: const PdfColor(1, 1, 1, 0.7), fontSize: 9)),
                    pw.Text(
                        'Vigencia: ${cotizacion.vigenciaDias} días hábiles',
                        style: pw.TextStyle(
                            color: const PdfColor(1, 1, 1, 0.7), fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),
          pw.Divider(color: grisClaro, thickness: 1),
          pw.SizedBox(height: 12),

          // ─── DATOS CLIENTE ──────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: grisClaro,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CLIENTE',
                          style: pw.TextStyle(
                              fontSize: 8,
                              color: grisTexto,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                          cotizacion.cliente?.empresa ??
                              cotizacion.cliente?.nombre ??
                              '',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: azul)),
                      pw.Text(cotizacion.cliente?.nombre ?? '',
                          style: pw.TextStyle(fontSize: 10)),
                      if (cotizacion.cliente?.rfc != null)
                        pw.Text('RFC: ${cotizacion.cliente!.rfc!}',
                            style: pw.TextStyle(fontSize: 9, color: grisTexto)),
                      if (cotizacion.cliente?.domicilio != null)
                        pw.Text(cotizacion.cliente!.domicilio!,
                            style: pw.TextStyle(fontSize: 9, color: grisTexto)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (cotizacion.metodoPago != null) ...[
                      pw.Text('FORMA DE PAGO',
                          style: pw.TextStyle(fontSize: 8, color: grisTexto, fontWeight: pw.FontWeight.bold)),
                      pw.Text(cotizacion.metodoPago!,
                          style: pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 6),
                    ],
                    if (cotizacion.condicionEntrega != null) ...[
                      pw.Text('ENTREGA',
                          style: pw.TextStyle(fontSize: 8, color: grisTexto, fontWeight: pw.FontWeight.bold)),
                      pw.Text(cotizacion.condicionEntrega!,
                          style: pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 6),
                    ],
                    if (cotizacion.fechaEntrega != null) ...[
                      pw.Text('FECHA ESTIMADA',
                          style: pw.TextStyle(fontSize: 8, color: grisTexto, fontWeight: pw.FontWeight.bold)),
                      pw.Text(_fmtFecha.format(cotizacion.fechaEntrega!),
                          style: pw.TextStyle(fontSize: 9)),
                    ],
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // ─── TABLA DE PRODUCTOS ─────────────
          pw.Table(
            border: pw.TableBorder.all(
                color: const PdfColor.fromInt(0xFFe0e0e0), width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.6),
              1: const pw.FlexColumnWidth(3.5),
              2: const pw.FlexColumnWidth(0.8),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.3),
            },
            children: [
              // Encabezado
              pw.TableRow(
                decoration: pw.BoxDecoration(color: azul),
                children: [
                  _celdaHeader('#'),
                  _celdaHeader('Descripción'),
                  _celdaHeader('Cant.'),
                  _celdaHeader('Precio Unit.'),
                  _celdaHeader('Subtotal'),
                ],
              ),
              // Filas
              ...cotizacion.items.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i.isEven
                        ? PdfColors.white
                        : const PdfColor.fromInt(0xFFfafafa),
                  ),
                  children: [
                    _celda('${i + 1}', center: true),
                    _celdaLeft(
                        '${item.nombreProducto}${item.sku != null ? "\nSKU: ${item.sku}" : ""}'),
                    _celda('${item.cantidad}', center: true),
                    _celda('\$${_fmt.format(item.precioUnitario)}'),
                    _celda('\$${_fmt.format(item.subtotal)}'),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 16),

          // ─── TOTALES ────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 220,
                child: pw.Column(
                  children: [
                    _filaTotal('Subtotal:', '\$${_fmt.format(cotizacion.subtotal)}'),
                    if (cotizacion.descuentoPct > 0 || cotizacion.descuentoFijo > 0)
                      _filaTotal(
                          'Descuento${cotizacion.descuentoPct > 0 ? " ${cotizacion.descuentoPct.toInt()}%" : ""}:',
                          '-\$${_fmt.format(cotizacion.montoDescuento)}',
                          color: const PdfColor.fromInt(0xFF1d9e75)),
                    if (cotizacion.costoEnvio > 0)
                      _filaTotal('Envío:', '\$${_fmt.format(cotizacion.costoEnvio)}'),
                    _filaTotal(
                        'IVA ${cotizacion.ivaPct.toInt()}%:', '\$${_fmt.format(cotizacion.montoIva)}'),
                    pw.Divider(thickness: 1, color: azul),
                    _filaTotal(
                      'TOTAL MXN:',
                      '\$${_fmt.format(cotizacion.total)}',
                      bold: true,
                      fontSize: 13,
                      color: azul,
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 16),

          // ─── NOTAS ──────────────────────────
          if (cotizacion.notas != null && cotizacion.notas!.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                    color: const PdfColor.fromInt(0xFFe0e0e0), width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Notas y observaciones:',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: grisTexto)),
                  pw.SizedBox(height: 4),
                  pw.Text(cotizacion.notas!,
                      style: pw.TextStyle(fontSize: 9, color: grisTexto)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // ─── PIE DE PÁGINA ──────────────────
          pw.Divider(color: grisClaro),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              '${empresa['nombre_comercial'] ?? "HETNA CNC"} · ${empresa['telefono1'] ?? ""} · ${empresa['correo'] ?? ""} · ${empresa['sitio_web'] ?? ""}',
              style: pw.TextStyle(fontSize: 8, color: grisTexto),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ─── HELPERS ────────────────────────────────
  static pw.Widget _celdaHeader(String texto) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(texto,
            style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _celda(String texto, {bool center = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(texto,
            style: pw.TextStyle(fontSize: 9),
            textAlign: center ? pw.TextAlign.center : pw.TextAlign.right),
      );

  static pw.Widget _celdaLeft(String texto) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(texto, style: pw.TextStyle(fontSize: 9)),
      );

  static pw.Widget _filaTotal(
    String label,
    String valor, {
    bool bold = false,
    double fontSize = 10,
    PdfColor? color,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: fontSize,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: color ?? const PdfColor.fromInt(0xFF444444))),
            pw.Text(valor,
                style: pw.TextStyle(
                    fontSize: fontSize,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: color ?? const PdfColor.fromInt(0xFF444444))),
          ],
        ),
      );

  // ─── VER / COMPARTIR PDF ────────────────────
  static Future<void> verPdf(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  static Future<void> compartirPdf(
      Uint8List bytes, String nombreArchivo) async {
    await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
  }
}
