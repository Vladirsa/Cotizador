import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../main.dart';

class PdfService {
  static final _fmt = NumberFormat('#,##0.00', 'es_MX');

  // Idioma del documento que se está generando. Cada cotización puede salir en
  // español o en inglés sin importar el idioma de la app (ver elegirIdioma).
  static bool _en = false;
  static String _t(String es) => trIdioma(es, _en);
  static String _tf(String es, List<Object?> valores) => trfIdioma(es, _en, valores);
  static DateFormat get _fmtFecha =>
      _en ? DateFormat('MM/dd/yyyy', 'en_US') : DateFormat('dd/MM/yyyy', 'es_MX');

  /// Moneda del documento: la de la cotización si la trae; si no, la de
  /// Configuración (MXN o USD).
  static String _moneda(Map<String, dynamic> empresa) {
    final m = (empresa['moneda'] ?? '').toString().trim().toUpperCase();
    return m.isEmpty ? 'MXN' : m;
  }

  /// Pregunta en qué idioma sale el PDF. Devuelve null si el usuario cierra
  /// el diálogo sin elegir.
  static Future<bool?> elegirIdioma(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('¿En qué idioma sale el PDF?')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Español', style: TextStyle(fontSize: 15))),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('English', style: TextStyle(fontSize: 15))),
          ),
        ],
      ),
    );
  }

  // Convierte un color hex ('#1a3a5c') a PdfColor. Si no hay valor
  // configurado o falla, usa el color por defecto (azul HETNA).
  static PdfColor _colorFromHex(dynamic hex, PdfColor fallback) {
    if (hex == null || (hex is String && hex.trim().isEmpty)) return fallback;
    try {
      final limpio = (hex as String).replaceFirst('#', '');
      final valor = int.parse('FF$limpio', radix: 16);
      return PdfColor.fromInt(valor);
    } catch (_) {
      return fallback;
    }
  }

  // Descarga el logo configurado por el taller (logo_url). Si no hay
  // logo propio o falla la descarga, usa el logo genérico por defecto.
  static Future<Uint8List> _obtenerLogoBytes(Map<String, dynamic> empresa) async {
    final logoUrl = empresa['logo_url'] as String?;
    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(logoUrl))
          .timeout(const Duration(seconds: 6));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          return res.bodyBytes;
        }
      } catch (_) {}
    }
    return _logoBytes;
  }

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

  static const _channelWA = MethodChannel('com.hetnacnc.app/whatsapp_share');

  // Envía el PDF DIRECTO a WhatsApp Business (sin pasar por el menú
  // genérico de Android) — usa un canal nativo (MainActivity.kt) que
  // arma el Intent con el paquete forzado. Si WhatsApp Business no
  // está instalado, regresa false y se puede caer al menú normal.
  static Future<bool> compartirPdfWhatsAppBusiness(Uint8List bytes, String nombre) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$nombre');
      await file.writeAsBytes(bytes);
      final ok = await _channelWA.invokeMethod('compartirWhatsAppBusiness', {
        'filePath': file.path,
        'paquete': 'com.whatsapp.w4b',
      });
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  // Muestra un selector simple: "WhatsApp Business" (directo, forzado)
  // u "Otra app" (el menú normal de Android, para cualquier otra cosa
  // — correo, Drive, la otra app de WhatsApp, etc.)
  static Future<void> mostrarOpcionesEnvio(
      BuildContext context, Uint8List bytes, String nombre) async {
    await showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(tr('¿Cómo quieres enviarlo?'),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await compartirPdfWhatsAppBusiness(bytes, nombre);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(tr('No se encontró WhatsApp Business instalado — usa "Otra app"')),
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
              await compartirPdf(bytes, nombre);
            },
            icon: const Icon(Icons.share_outlined),
            label: Text(tr('Otra app')),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)))),
          const SizedBox(height: 8),
        ])));
  }

  static Future<Uint8List> generarCotizacion({
    required Cotizacion cotizacion,
    required Map<String, dynamic> empresa,
    bool? ingles,
  }) async {
    _en = ingles ?? enIngles;
    // La profesional tiene su propio formato; todas las pantallas que generan
    // el PDF de una cotización pasan por aquí, así que no hay que tocarlas.
    if (cotizacion.esProfesional) {
      return generarCotizacionProfesional(cotizacion: cotizacion, empresa: empresa, ingles: _en);
    }
    final pdf = pw.Document();
    pw.MemoryImage? logoImage;
    try {
      final bytes = await _obtenerLogoBytes(empresa);
      if (bytes.isNotEmpty) logoImage = pw.MemoryImage(bytes);
    } catch (_) {}

    final azul = _colorFromHex(empresa['color_primario'], const PdfColor.fromInt(0xFF1a3a5c));
    const azulClaro = PdfColor.fromInt(0xFFe6f1fb);
    const grisClaro = PdfColor.fromInt(0xFFf5f6fa);
    const grisTexto = PdfColor.fromInt(0xFF6B7280);
    const verde = PdfColor.fromInt(0xFF1d9e75);
    const blanco70 = PdfColor.fromInt(0xB3FFFFFF);

    final nombreEmpresa = empresa['nombre_comercial'] ?? _t('HETNA CNC');
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
                  pw.Text(_tf('RFC: {0}', [rfcEmpresa]), style: pw.TextStyle(fontSize: 8, color: blanco70)),
                if (direccion.isNotEmpty)
                  pw.Text(direccion, style: pw.TextStyle(fontSize: 8, color: blanco70)),
                pw.Text(_tf('Tel: {0}', ['$tel1${tel2.isNotEmpty ? " / $tel2" : ""}']), style: pw.TextStyle(fontSize: 8, color: blanco70)),
                if (correoEmpresa.isNotEmpty)
                  pw.Text(correoEmpresa, style: pw.TextStyle(fontSize: 8, color: blanco70)),
                pw.Text(web, style: pw.TextStyle(fontSize: 8, color: PdfColors.white)),
              ]),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text(_t('COTIZACIÓN'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: azul)),
                  pw.SizedBox(height: 4),
                  pw.Text(folio, style: pw.TextStyle(fontSize: 10, color: azul)),
                  pw.SizedBox(height: 6),
                  pw.Row(children: [pw.Text(_t('Fecha: '), style: pw.TextStyle(fontSize: 9, color: grisTexto)), pw.Text(fecha, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: grisTexto))]),
                  pw.Row(children: [pw.Text(_t('Vigencia: '), style: pw.TextStyle(fontSize: 9, color: grisTexto)), pw.Text(fechaVigencia, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: grisTexto))]),
                ])),
            ])),
        pw.SizedBox(height: 14),
        // ─── CLIENTE ────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: grisClaro, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: PdfColors.grey300)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(_t('CLIENTE'), style: pw.TextStyle(fontSize: 9, color: grisTexto, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(cliente?.nombreCompleto ?? _t('Sin cliente'), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: azul)),
            if (cliente?.rfc != null) pw.Text(_tf('RFC: {0}', [cliente!.rfc]), style: pw.TextStyle(fontSize: 9, color: grisTexto)),
            if (cliente?.correo != null) pw.Text(cliente!.correo!, style: pw.TextStyle(fontSize: 9, color: grisTexto)),
            if (cliente?.telefono != null) pw.Text(_tf('Tel: {0}', [cliente!.telefono]), style: pw.TextStyle(fontSize: 9, color: grisTexto)),
          ])),
        pw.SizedBox(height: 14),
        // ─── TABLA PRODUCTOS ────────────────
        pw.Text(_t('DETALLE DE LA COTIZACIÓN'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
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
              _cH(_t('TÍTULO / DESCRIPCIÓN')), _cH(_t('CANT.')), _cH(_t('PRECIO')), _cH(_t('SUBTOTAL')),
            ]),
            ...List.generate(cotizacion.items.length, (i) {
              final item = cotizacion.items[i];
              final nombreLimpio = _limpiarTexto(item.nombreProducto);
              final descLimpia = (item.descripcion != null && item.descripcion!.isNotEmpty)
                ? _limpiarTexto(item.descripcion!) : null;
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : grisClaro),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(7),
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(nombreLimpio,
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
                      if (descLimpia != null)
                        pw.Padding(padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(descLimpia,
                            style: pw.TextStyle(fontSize: 8, color: grisTexto))),
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
            if (cotizacion.descuentoPct > 0) _tR(_t('Subtotal'), '\$${_fmt.format(cotizacion.subtotal)}', grisTexto),
            if (cotizacion.descuentoPct > 0) _tR(_tf('Descuento {0}%', [(cotizacion.descuentoPct.toInt())]), '-\$${_fmt.format(cotizacion.montoDescuento)}', verde),
            if (cotizacion.ivaPct > 0) _tR(_tf('IVA {0}%', [pctTexto(cotizacion.ivaPct)]), '\$${_fmt.format(cotizacion.montoIva)}', grisTexto),
            if (cotizacion.costoEnvio > 0) _tR(_t('Envío'), '\$${_fmt.format(cotizacion.costoEnvio)}', grisTexto),
            pw.Divider(color: azul),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOTAL ${_moneda(empresa)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: azul)),
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
            pw.Text(_t('CONDICIONES'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: azul)),
            pw.SizedBox(height: 6),
            if (cotizacion.metodoPago != null) _cond(_t('Pago:'), _t(cotizacion.metodoPago!), grisTexto),
            if (cotizacion.condicionEntrega != null) _cond(_t('Entrega:'), _limpiarTexto(_t(cotizacion.condicionEntrega!)), grisTexto),
            _cond(_t('Vigencia:'), _tf('{0} días hábiles', [vigenciaDias]), grisTexto),
            if (cotizacion.notas != null && cotizacion.notas!.isNotEmpty) _cond(_t('Notas:'), cotizacion.notas!, grisTexto),
            if ((empresa['leyenda_pdf'] as String?)?.isNotEmpty == true)
              pw.Padding(padding: const pw.EdgeInsets.only(top: 6),
                child: pw.Text(_limpiarTexto(empresa['leyenda_pdf']),
                  style: pw.TextStyle(fontSize: 8, color: grisTexto, fontStyle: pw.FontStyle.italic))),
          ])),
        pw.SizedBox(height: 12),
        // ─── PIE ────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: azul, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(_t('¡Gracias por su preferencia!'), style: pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              pw.Text(_limpiarTexto(_tf('Estamos para servirle — {0}', [nombreEmpresa])), style: pw.TextStyle(fontSize: 9, color: blanco70)),
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

  // ══════════════════════════════════════════
  // COTIZACIÓN PROFESIONAL — formato internacional
  // Estructura: encabezado (folio, revisión, vigencia, moneda) · cliente y
  // proyecto · 1 resumen · 2 alcance (incluye / no incluye) · 3 detalle
  // técnico · 4 fabricación · 5 propuesta económica · 6 condiciones
  // comerciales · 7 calidad · 8 aprobación del cliente.
  // Las secciones sin datos no se imprimen.
  // ══════════════════════════════════════════
  static Future<Uint8List> generarCotizacionProfesional({
    required Cotizacion cotizacion,
    required Map<String, dynamic> empresa,
    bool? ingles,
  }) async {
    _en = ingles ?? enIngles;
    final pdf = pw.Document();
    pw.MemoryImage? logoImage;
    try {
      final bytes = await _obtenerLogoBytes(empresa);
      if (bytes.isNotEmpty) logoImage = pw.MemoryImage(bytes);
    } catch (_) {}

    final azul = _colorFromHex(empresa['color_primario'], const PdfColor.fromInt(0xFF1a3a5c));
    const azulClaro = PdfColor.fromInt(0xFFe6f1fb);
    const grisClaro = PdfColor.fromInt(0xFFf5f6fa);
    const grisTexto = PdfColor.fromInt(0xFF6B7280);
    const grisLinea = PdfColor.fromInt(0xFFD1D5DB);
    const verde = PdfColor.fromInt(0xFF1d9e75);
    const rojo = PdfColor.fromInt(0xFFB42318);

    final d = cotizacion.datosPro;
    String v(String k) => _limpiarTexto(((d[k] ?? '') as Object).toString().trim());
    List<String> lineas(String k) => v(k).split('\n')
      .map((l) => l.trim().replaceFirst(RegExp(r'^[-*]\s*'), ''))
      .where((l) => l.isNotEmpty).toList();

    final nombreEmpresa = _limpiarTexto(empresa['nombre_comercial'] ?? _t('HETNA CNC'));
    final rfcEmpresa = empresa['rfc'] ?? '';
    final direccion = _limpiarTexto(empresa['direccion'] ?? '');
    final tel1 = empresa['telefono1'] ?? '';
    final correoEmpresa = empresa['correo'] ?? '';
    final web = empresa['sitio_web'] ?? 'hetnacnc.com';
    final cliente = cotizacion.cliente;
    final folio = cotizacion.folio ?? 'COT-${DateTime.now().millisecondsSinceEpoch}';
    final revision = v('revision').isEmpty ? 'A' : v('revision');
    final moneda = v('moneda').isEmpty ? _moneda(empresa) : v('moneda');
    final fecha = _fmtFecha.format(cotizacion.createdAt ?? DateTime.now());
    final vigenciaDias = cotizacion.vigenciaDias;
    final fechaVigencia = _fmtFecha.format(
      (cotizacion.createdAt ?? DateTime.now()).add(Duration(days: vigenciaDias)));
    final esMuestra = d['muestra'] == true;

    pw.Widget titulo(String n, String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
      child: pw.Row(children: [
        pw.Container(width: 18, height: 18, alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(color: azul, borderRadius: pw.BorderRadius.circular(3)),
          child: pw.Text(n, style: pw.TextStyle(fontSize: 9, color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(width: 6),
        pw.Text(t, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: azul)),
      ]));

    // Tabla etiqueta / valor con solo los campos llenos
    pw.Widget datos(List<(String, String)> filas) {
      final llenas = filas.where((f) => f.$2.isNotEmpty).toList();
      return pw.Table(
        border: pw.TableBorder.all(color: grisLinea, width: 0.5),
        columnWidths: {0: const pw.FixedColumnWidth(150), 1: const pw.FlexColumnWidth()},
        children: llenas.map((f) => pw.TableRow(children: [
          pw.Container(color: grisClaro, padding: const pw.EdgeInsets.all(6),
            child: pw.Text(f.$1, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: azul))),
          pw.Padding(padding: const pw.EdgeInsets.all(6),
            child: pw.Text(f.$2, style: const pw.TextStyle(fontSize: 9))),
        ])).toList());
    }

    pw.Widget lista(String encabezado, List<String> items, PdfColor color) => pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: grisLinea, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(encabezado, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
        pw.SizedBox(height: 4),
        if (items.isEmpty) pw.Text('-', style: const pw.TextStyle(fontSize: 9, color: grisTexto)),
        ...items.map((t) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('-  ', style: pw.TextStyle(fontSize: 9, color: color)),
            pw.Expanded(child: pw.Text(t, style: const pw.TextStyle(fontSize: 9))),
          ]))),
      ]));

    final incluye = lineas('incluye');
    final noIncluye = lineas('no_incluye');
    final tecnicos = <(String, String)>[
      (_t('Material'), v('material')), (_t('Medidas / espesor'), v('medidas')),
      (_t('Tolerancia general'), v('tolerancia')), (_t('Acabado'), v('acabado')),
      (_t('Archivo recibido'), v('archivo')), (_t('Norma / especificación'), v('norma')),
    ];
    final fabricacion = <(String, String)>[
      (_t('Proceso'), v('proceso')), (_t('Máquina'), v('maquina')),
      (_t('Operaciones'), v('operaciones')), (_t('Setups'), v('setups')),
      (_t('Inspección'), v('inspeccion')),
    ];
    final hay = (List<(String, String)> l) => l.any((f) => f.$2.isNotEmpty);
    final comerciales = <(String, String)>[
      (_t('Forma de pago'), _limpiarTexto(_t(cotizacion.metodoPago ?? ''))),
      (_t('Tiempo de entrega'), _t(v('tiempo_entrega'))),
      (_t('Lugar de entrega'), _limpiarTexto(_t(cotizacion.condicionEntrega ?? ''))),
      (_t('Vigencia de la oferta'), _tf('{0} días (hasta {1})', [vigenciaDias, fechaVigencia])),
      (_t('Moneda'), moneda),
      (_t('Impuestos'), cotizacion.ivaPct > 0 ? _tf('IVA {0}% incluido en el total', [pctTexto(cotizacion.ivaPct)]) : _t('Precios sin IVA')),
      (_t('Cambios y cancelaciones'), _t(v('cambios'))),
      (_t('Notas'), _limpiarTexto(cotizacion.notas ?? '')),
    ];

    int n = 0;
    String sig() => '${++n}';

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
      footer: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: grisLinea, width: 0.5))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(_tf('{0}  ·  Rev {1}  ·  {2}', [folio, revision, nombreEmpresa]),
            style: const pw.TextStyle(fontSize: 7, color: grisTexto)),
          if (esMuestra)
            pw.Text(_t('Cotización profesional de muestra · HETNA Taller · hetnacnc.com'),
              style: pw.TextStyle(fontSize: 7, color: azul, fontWeight: pw.FontWeight.bold)),
          pw.Text(_tf('Página {0} de {1}', [(ctx.pageNumber), (ctx.pagesCount)]),
            style: const pw.TextStyle(fontSize: 7, color: grisTexto)),
        ])),
      build: (ctx) => [
        // ─── ENCABEZADO ─────────────────────
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (logoImage != null)
              pw.Image(logoImage, width: 130, height: 38, fit: pw.BoxFit.contain)
            else
              pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: azul)),
            pw.SizedBox(height: 6),
            pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            if (rfcEmpresa.isNotEmpty) pw.Text(_tf('RFC: {0}', [rfcEmpresa]), style: const pw.TextStyle(fontSize: 8, color: grisTexto)),
            if (direccion.isNotEmpty) pw.Text(direccion, style: const pw.TextStyle(fontSize: 8, color: grisTexto)),
            pw.Text([if (tel1.isNotEmpty) _tf('Tel: {0}', [tel1]), if (correoEmpresa.isNotEmpty) correoEmpresa, web].join('  ·  '),
              style: const pw.TextStyle(fontSize: 8, color: grisTexto)),
          ])),
          pw.Container(
            width: 190,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: azul, width: 1),
              borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(children: [
              pw.Container(width: double.infinity, color: azul, padding: const pw.EdgeInsets.all(6),
                child: pw.Text(_t('COTIZACIÓN'), textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 13, color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Column(children: [
                _filaEnc(_t('Folio'), folio, azul), _filaEnc(_t('Revisión'), revision, azul),
                _filaEnc(_t('Fecha'), fecha, azul), _filaEnc(_t('Vigente hasta'), fechaVigencia, azul),
                _filaEnc(_t('Moneda'), moneda, azul),
              ])),
            ])),
        ]),
        pw.SizedBox(height: 12),

        // ─── CLIENTE Y PROYECTO ─────────────
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(color: grisClaro, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(_t('CLIENTE'), style: pw.TextStyle(fontSize: 8, color: grisTexto, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text(_limpiarTexto(cliente?.nombreCompleto ?? _t('Sin cliente')),
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: azul)),
              if (cliente?.rfc != null) pw.Text(_tf('RFC: {0}', [cliente!.rfc]), style: const pw.TextStyle(fontSize: 8, color: grisTexto)),
              if (cliente?.correo != null) pw.Text(cliente!.correo!, style: const pw.TextStyle(fontSize: 8, color: grisTexto)),
              if (cliente?.telefono != null) pw.Text(_tf('Tel: {0}', [cliente!.telefono]), style: const pw.TextStyle(fontSize: 8, color: grisTexto)),
            ]))),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(color: grisClaro, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(_t('PROYECTO'), style: pw.TextStyle(fontSize: 8, color: grisTexto, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text(v('proyecto').isEmpty ? '-' : v('proyecto'),
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: azul)),
            ]))),
        ]),

        // ─── 1. RESUMEN ─────────────────────
        if (v('resumen').isNotEmpty) ...[
          titulo(sig(), _t('RESUMEN')),
          pw.Text(v('resumen'), style: const pw.TextStyle(fontSize: 9, lineSpacing: 2)),
        ],

        // ─── 2. ALCANCE ─────────────────────
        if (incluye.isNotEmpty || noIncluye.isNotEmpty) ...[
          titulo(sig(), _t('ALCANCE DEL TRABAJO')),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: lista(_t('INCLUYE'), incluye, verde)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: lista(_t('NO INCLUYE'), noIncluye, rojo)),
          ]),
        ],

        // ─── 3. DETALLE TÉCNICO ─────────────
        if (hay(tecnicos)) ...[titulo(sig(), _t('DETALLE TÉCNICO')), datos(tecnicos)],

        // ─── 4. FABRICACIÓN ─────────────────
        if (hay(fabricacion)) ...[titulo(sig(), _t('ESPECIFICACIONES DE FABRICACIÓN')), datos(fabricacion)],

        // ─── 5. PROPUESTA ECONÓMICA ─────────
        titulo(sig(), _tf('PROPUESTA ECONÓMICA ({0})', [moneda])),
        pw.Table(
          border: pw.TableBorder.all(color: grisLinea, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(26),
            1: const pw.FlexColumnWidth(3.5),
            2: const pw.FixedColumnWidth(40),
            3: const pw.FixedColumnWidth(72),
            4: const pw.FixedColumnWidth(76),
          },
          children: [
            pw.TableRow(decoration: pw.BoxDecoration(color: azul), children: [
              _cH('#'), _cH(_t('CONCEPTO')), _cH(_t('CANT.')), _cH(_t('P. UNITARIO')), _cH(_t('IMPORTE')),
            ]),
            ...List.generate(cotizacion.items.length, (i) {
              final item = cotizacion.items[i];
              final desc = (item.descripcion ?? '').trim();
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : grisClaro),
                children: [
                  _cD('${i + 1}', center: true),
                  pw.Padding(padding: const pw.EdgeInsets.all(6),
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(_limpiarTexto(item.nombreProducto),
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: azul)),
                      if (desc.isNotEmpty) pw.Text(_limpiarTexto(desc), style: const pw.TextStyle(fontSize: 8, color: grisTexto)),
                      if (item.sku != null && item.sku!.isNotEmpty)
                        pw.Text(_tf('No. de parte: {0}', [(item.sku)]), style: const pw.TextStyle(fontSize: 7, color: grisTexto)),
                    ])),
                  _cD('${item.cantidad}', center: true),
                  _cD('\$${_fmt.format(item.precioUnitario)}', right: true),
                  _cD('\$${_fmt.format(item.subtotal)}', right: true),
                ]);
            }),
          ]),
        pw.SizedBox(height: 8),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(width: 230, child: pw.Column(children: [
            _tR(_t('Subtotal'), '\$${_fmt.format(cotizacion.subtotal)}', grisTexto),
            if (cotizacion.montoDescuento > 0)
              _tR(_tf('Descuento{0}', [(cotizacion.descuentoPct > 0 ? " ${cotizacion.descuentoPct.toInt()}%" : "")]),
                '-\$${_fmt.format(cotizacion.montoDescuento)}', verde),
            if (cotizacion.ivaPct > 0) _tR(_tf('IVA {0}%', [pctTexto(cotizacion.ivaPct)]), '\$${_fmt.format(cotizacion.montoIva)}', grisTexto),
            if (cotizacion.costoEnvio > 0) _tR(_t('Envío'), '\$${_fmt.format(cotizacion.costoEnvio)}', grisTexto),
            pw.Divider(color: azul),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOTAL $moneda', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: azul)),
              pw.Text('\$${_fmt.format(cotizacion.total)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: azul)),
            ]),
          ])),
        ]),

        // ─── 6. CONDICIONES COMERCIALES ─────
        titulo(sig(), _t('CONDICIONES COMERCIALES')),
        datos(comerciales),

        // ─── 7. CALIDAD ─────────────────────
        if (v('calidad').isNotEmpty || v('tolerancia').isNotEmpty) ...[
          titulo(sig(), _t('CONDICIONES TÉCNICAS Y DE CALIDAD')),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(color: azulClaro, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (v('calidad').isNotEmpty) pw.Text(_t(v('calidad')), style: const pw.TextStyle(fontSize: 9)),
              if (v('tolerancia').isNotEmpty)
                pw.Text(_tf('Tolerancia general: {0}', [(v('tolerancia'))]), style: const pw.TextStyle(fontSize: 9)),
              if ((empresa['leyenda_pdf'] as String?)?.isNotEmpty == true)
                pw.Padding(padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(_limpiarTexto(empresa['leyenda_pdf']),
                    style: pw.TextStyle(fontSize: 8, color: grisTexto, fontStyle: pw.FontStyle.italic))),
            ])),
        ],

        // ─── 8. APROBACIÓN ──────────────────
        titulo(sig(), _t('APROBACIÓN DEL CLIENTE')),
        pw.Text(_tf('Al firmar, el cliente acepta el alcance, el precio y las condiciones de esta cotización (folio {0}, revisión {1}).', [folio, revision]),
          style: const pw.TextStyle(fontSize: 8, color: grisTexto)),
        pw.SizedBox(height: 26),
        pw.Row(children: [
          pw.Expanded(child: _lineaFirma(_t('Nombre y cargo'))),
          pw.SizedBox(width: 14),
          pw.Expanded(child: _lineaFirma(_t('Firma'))),
          pw.SizedBox(width: 14),
          pw.Expanded(child: _lineaFirma(_t('Fecha'))),
        ]),
      ],
    ));
    return pdf.save();
  }

  static pw.Widget _filaEnc(String label, String valor, PdfColor color) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF6B7280))),
      pw.Text(valor, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: color)),
    ]));

  static pw.Widget _lineaFirma(String etiqueta) => pw.Column(children: [
    pw.Container(height: 0.8, color: const PdfColor.fromInt(0xFF9CA3AF)),
    pw.SizedBox(height: 3),
    pw.Text(etiqueta, style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF6B7280))),
  ]);

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
    bool? ingles,
  }) async {
    _en = ingles ?? enIngles;
    final pdf = pw.Document();
    pw.MemoryImage? logoImage;
    try {
      final bytes = await _obtenerLogoBytes(empresa);
      if (bytes.isNotEmpty) logoImage = pw.MemoryImage(bytes);
    } catch (_) {}

    final azul = _colorFromHex(empresa['color_primario'], const PdfColor.fromInt(0xFF1a3a5c));
    const azulClaro = PdfColor.fromInt(0xFFe6f1fb);
    const grisClaro = PdfColor.fromInt(0xFFf5f6fa);
    const grisTexto = PdfColor.fromInt(0xFF6B7280);
    const verde = PdfColor.fromInt(0xFF1d9e75);

    final nombreEmpresa = empresa['nombre_comercial'] ?? _t('HETNA CNC');
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
          decoration: pw.BoxDecoration(color: azul),
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
              pw.Text(_limpiarTexto(_tf('Lista de Precios — {0}', [nombreLista])),
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
              pw.Text(_tf('Fecha: {0}', [fecha]),
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
              decoration: pw.BoxDecoration(color: azul),
              children: [
                _celdaHeader(_t('PRODUCTO / DESCRIPCIÓN')),
                _celdaHeader(_t('CATEGORÍA')),
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
                    child: pw.Text(p.categoriaNombre ?? '-',
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
            pw.Text(_tf('Total de productos: {0}', [(productos.length)]),
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
            pw.Text(_t('Los precios no incluyen IVA'),
              style: const pw.TextStyle(fontSize: 9, color: grisTexto)),
          ])),
        pw.SizedBox(height: 8),
        pw.Text(_tf('Para pedidos o más información: {0} • {1} • {2}', [tel, correo, web]),
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
    bool? ingles,
  }) async {
    _en = ingles ?? enIngles;
    final pdf = pw.Document();
    pw.MemoryImage? logoImage;
    try {
      final bytes = await _obtenerLogoBytes(empresa);
      if (bytes.isNotEmpty) logoImage = pw.MemoryImage(bytes);
    } catch (_) {}

    final azul = _colorFromHex(empresa['color_primario'], const PdfColor.fromInt(0xFF1a3a5c));
    const azulClaro  = PdfColor.fromInt(0xFFe6f1fb);
    const grisClaro  = PdfColor.fromInt(0xFFf5f6fa);
    const grisTexto  = PdfColor.fromInt(0xFF6B7280);
    const verde      = PdfColor.fromInt(0xFF1d9e75);
    const verdeClaro = PdfColor.fromInt(0xFFe6f7f0);

    final nombreEmpresa    = empresa['nombre_comercial'] ?? _t('HETNA CNC');
    final telEmpresa       = empresa['telefono'] ?? empresa['telefono2'] ?? '';
    final direccionEmpresa = empresa['direccion'] ?? '';
    final correo           = empresa['correo']   ?? '';
    final web              = empresa['sitio_web'] ?? 'hetnacnc.com';
    final fecha            = _fmtFecha.format(cotizacion.createdAt ?? DateTime.now());
    final clienteNombre    = _limpiarTexto(cotizacion.cliente?.nombreCompleto ?? cotizacion.cliente?.nombre ?? _t('Cliente'));
    final folio            = folioPedido ?? cotizacion.folio ?? 'N/A';

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // Header
        // Header idéntico a la cotización
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(color: azul, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
            // IZQUIERDA: logo + datos empresa
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (logoImage != null)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Image(logoImage, width: 100, height: 28, fit: pw.BoxFit.contain))
              else
                pw.Text(nombreEmpresa,
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.SizedBox(height: 6),
              if (telEmpresa.isNotEmpty)
                pw.Text(telEmpresa, style: const pw.TextStyle(fontSize: 8, color: const PdfColor(1, 1, 1, 0.7))),
              if (correo.isNotEmpty)
                pw.Text(correo, style: const pw.TextStyle(fontSize: 8, color: const PdfColor(1, 1, 1, 0.7))),
              if (web.isNotEmpty)
                pw.Text(web, style: const pw.TextStyle(fontSize: 8, color: const PdfColor(1, 1, 1, 0.7))),
            ]),
            // DERECHA: tipo doc + folio + fecha + sello
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(_t('NOTA DE COMPRA'),
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: azul)),
                pw.SizedBox(height: 4),
                pw.Text('Folio: $folio',
                  style: pw.TextStyle(fontSize: 10, color: azul)),
                pw.SizedBox(height: 4),
                pw.Text(_tf('Fecha: {0}', [fecha]),
                  style: pw.TextStyle(fontSize: 9, color: grisTexto)),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: verde,
                    borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Text(_t('ENTREGADO'),
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold))),
              ])),
          ])),
        pw.SizedBox(height: 14),
        // Cliente
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: azulClaro, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(_t('CLIENTE'), style: pw.TextStyle(fontSize: 8, color: grisTexto, fontWeight: pw.FontWeight.bold)),
              pw.Text(clienteNombre, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: azul)),
            ]),
            pw.Text(_t('Nota de entrega'), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
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
              _cH(_t('TÍTULO / DESCRIPCIÓN')), _cH(_t('CANT.')), _cH(_t('PRECIO')), _cH(_t('SUBTOTAL')),
            ]),
            ...List.generate(cotizacion.items.length, (i) {
              final item = cotizacion.items[i];
              final descLimpia = (item.descripcion != null && item.descripcion!.isNotEmpty)
                ? _limpiarTexto(item.descripcion!) : null;
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : grisClaro),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(7),
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(_limpiarTexto(item.nombreProducto),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
                      if (descLimpia != null)
                        pw.Padding(padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(descLimpia,
                            style: pw.TextStyle(fontSize: 8, color: grisTexto))),
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
              if (cotizacion.descuentoPct > 0) _tR(_t('Descuento'), '-\$${_fmt.format(cotizacion.montoDescuento)}', verde),
              if (cotizacion.ivaPct > 0) _tR(_tf('IVA {0}%', [pctTexto(cotizacion.ivaPct)]), '\$${_fmt.format(cotizacion.montoIva)}', grisTexto),
              pw.Divider(color: verde),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text(_t('TOTAL PAGADO'), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: verde)),
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
            pw.Text(_t('Firma del cliente'), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
            pw.Text(clienteNombre, style: pw.TextStyle(fontSize: 9, color: grisTexto)),
          ])),
          pw.SizedBox(width: 40),
          pw.Expanded(child: pw.Column(children: [
            pw.Container(height: 40, decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)))),
            pw.SizedBox(height: 4),
            pw.Text(_t('Firma de entrega'), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
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
              pw.Text(_t('Gracias por su preferencia'), style: pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              pw.Text('$telEmpresa  $correo', style: const pw.TextStyle(fontSize: 8, color: PdfColors.white)),
            ]),
            pw.Text(web, style: pw.TextStyle(fontSize: 9, color: PdfColors.white)),
          ])),
      ])));

    return pdf.save();
  }

}
