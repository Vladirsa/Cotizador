import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'categorias_concepto.dart';
import '../models/models.dart';
import 'archivo_cad_service.dart';
import 'cotas_service.dart';
import 'aprovechamiento.dart';
import 'auth_service.dart';
import 'whatsapp_service.dart';
import '../main.dart';
import 'pais.dart';

class PdfService {
  static NumberFormat get _fmt => Pais.fmtNumero();

  // Idioma del documento que se está generando. Cada cotización puede salir en
  // español o en inglés sin importar el idioma de la app (ver elegirIdioma).
  static bool _en = false;
  static String _t(String es) => trIdioma(es, _en);
  // Etiquetas fiscales según el país de facturación del taller
  // (MX: RFC/IVA · US: Tax ID/Sales tax · CO: NIT/IVA · PE: RUC/IGV · CL: RUT/IVA)
  static InfoPais _pais(Map<String, dynamic> e) => Pais.de(e['pais_factura']?.toString());
  static String _etqRfc(Map<String, dynamic> e) => _pais(e).etqId;
  static String _etqIva(Map<String, dynamic> e) => _pais(e).etqImpuesto;
  static String _leyendaEnvio([Map<String, dynamic>? e]) =>
      _tf('Envíos: por el momento solo dentro de {0}.', [_t((e == null ? Pais.actual : _pais(e)).nombre)]);
  static String _fmtN(double v, int dec) {
    final f = NumberFormat(dec == 0 ? '#,##0' : '#,##0.${'0' * dec}', 'es_MX');
    return f.format(v);
  }
  static String _tf(String es, List<Object?> valores) => trfIdioma(es, _en, valores);

  // Plan Gratis: las cotizaciones salen con "HETNA CNC" en diagonal, muy
  // tenue, y una línea al pie. Con el plan Taller salen limpias, sólo con el
  // logo del taller (Planes: 'pdf_sin_marca').
  static pw.PageTheme _tema(pw.EdgeInsets margen) {
    final marca = !AuthService.puede('pdf_sin_marca');
    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: margen,
      buildForeground: !marca ? null : (ctx) => pw.FullPage(ignoreMargins: true,
        child: pw.Stack(children: [
          pw.Center(child: pw.Transform.rotate(angle: 0.55,
            child: pw.Opacity(opacity: 0.07,
              child: pw.Text('HETNA CNC', style: pw.TextStyle(
                fontSize: 110, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800))))),
          pw.Positioned(left: 0, right: 0, bottom: 10,
            child: pw.Center(child: pw.Text(
              _t('Hecho con el Cotizador gratis de HETNA CNC · hetnacnc.com/cotizador'),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)))),
        ])),
    );
  }
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
  // El PDF sale en el idioma de la app (Configuración → Idioma); ya no se
  // pregunta cada vez. Para forzar otro idioma, generarCotizacion(ingles: …).
  static Future<bool?> elegirIdioma(BuildContext context) async => enIngles;

  static Future<bool?> elegirIdiomaDialogo(BuildContext context) {
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

  // Descarga el logo configurado por el taller (logo_url). Si no hay logo
  // propio o falla la descarga, no se pone ninguno: el encabezado muestra el
  // nombre del taller (nunca el logo de HETNA en documentos de otro taller).
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
    return Uint8List(0);
  }

  static bool _vacio(dynamic v) => v == null || v.toString().trim().isEmpty;



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
      BuildContext context, Uint8List bytes, String nombre,
      {String? whatsapp, String? mensaje}) async {
    // En la web (computadora) no hay apps de Android: se descarga el PDF y, si
    // hay número, se abre WhatsApp Web con el mensaje para adjuntar el archivo.
    if (kIsWeb) {
      await showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(tr('¿Cómo quieres enviarlo?'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(tr('Descarga el PDF y adjúntalo en WhatsApp Web; el mensaje ya va listo.'),
              style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: () async { Navigator.pop(ctx); await compartirPdf(bytes, nombre); },
              icon: const Icon(Icons.download_outlined, color: Colors.white),
              label: Text(tr('Descargar PDF'), style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul,
                padding: const EdgeInsets.symmetric(vertical: 12)))),
            if (whatsapp != null && whatsapp.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await compartirPdf(bytes, nombre);
                  await WhatsAppService.abrirChat(numero: whatsapp, mensaje: mensaje ?? '');
                },
                icon: const Icon(Icons.chat, color: Colors.white),
                label: Text(tr('Descargar y abrir WhatsApp Web'), style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 12)))),
            ],
            const SizedBox(height: 8),
          ])));
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

    final nombreEmpresa = (_vacio(empresa['nombre_comercial']) ? AuthService.marcaTaller : empresa['nombre_comercial']);
    final rfcEmpresa = empresa['rfc'] ?? '';
    final direccion = empresa['direccion'] ?? '';
    final tel1 = empresa['telefono1'] ?? '';
    final tel2 = empresa['telefono2'] ?? '';
    final correoEmpresa = empresa['correo'] ?? '';
    final web = empresa['sitio_web'] ?? '';
    final cliente = cotizacion.cliente;
    final folio = cotizacion.folio ?? 'COT-${DateTime.now().millisecondsSinceEpoch}';
    final fecha = _fmtFecha.format(cotizacion.createdAt ?? DateTime.now());
    final vigenciaDias = cotizacion.vigenciaDias;
    final fechaVigencia = _fmtFecha.format(
      (cotizacion.createdAt ?? DateTime.now()).add(Duration(days: vigenciaDias)));

    pdf.addPage(pw.MultiPage(
      pageTheme: _tema(const pw.EdgeInsets.all(28)),
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
                  // Sin caja blanca: el logo va directo sobre el encabezado
                  // (si el PNG tiene fondo transparente, se ve limpio)
                  pw.Image(logoImage, width: 110, height: 32, fit: pw.BoxFit.contain)
                else
                  pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.SizedBox(height: 8),
                if (rfcEmpresa.isNotEmpty)
                  pw.Text('${_etqRfc(empresa)}: $rfcEmpresa', style: pw.TextStyle(fontSize: 8, color: blanco70)),
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
                    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      if (_miniatura(item.imagenPng) != null)
                        pw.Container(width: 78, height: 50, margin: const pw.EdgeInsets.only(right: 6),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
                          child: pw.Image(_miniatura(item.imagenPng)!, fit: pw.BoxFit.contain)),
                      pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text(nombreLimpio,
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
                        if (descLimpia != null)
                          pw.Padding(padding: const pw.EdgeInsets.only(top: 2),
                            child: pw.Text(descLimpia,
                              style: pw.TextStyle(fontSize: 8, color: grisTexto))),
                        if (item.medidas != null && item.medidas!.isNotEmpty)
                          pw.Text('${_t('Medidas')}: ${_limpiarTexto(item.medidas!)}',
                            style: pw.TextStyle(fontSize: 7.5, color: grisTexto, fontWeight: pw.FontWeight.bold)),
                        if (item.sku != null && item.sku!.isNotEmpty)
                          pw.Text('SKU: ${item.sku}',
                            style: pw.TextStyle(fontSize: 7, color: grisTexto)),
                      ])),
                    ])),
                  _cD('${item.cantidad}', center: true),
                  _cD('${Pais.simbolo}${_fmt.format(item.precioUnitario)}', right: true),
                  _cD('${Pais.simbolo}${_fmt.format(item.subtotal)}', right: true),
                ]);
            }),
          ]),
        pw.SizedBox(height: 12),
        // ─── TOTALES ────────────────────────
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(width: 220, child: pw.Column(children: [
            if (cotizacion.descuentoPct > 0) _tR(_t('Subtotal'), '${Pais.simbolo}${_fmt.format(cotizacion.subtotal)}', grisTexto),
            if (cotizacion.descuentoPct > 0) _tR(_tf('Descuento {0}%', [(cotizacion.descuentoPct.toInt())]), '-\$${_fmt.format(cotizacion.montoDescuento)}', verde),
            if (cotizacion.ivaPct > 0) _tR('${_etqIva(empresa)} ${pctTexto(cotizacion.ivaPct)}%', '${Pais.simbolo}${_fmt.format(cotizacion.montoIva)}', grisTexto),
            if (cotizacion.costoEnvio > 0) _tR(_t('Envío'), '${Pais.simbolo}${_fmt.format(cotizacion.costoEnvio)}', grisTexto),
            pw.Divider(color: azul),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOTAL ${_moneda(empresa)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: azul)),
              pw.Text('${Pais.simbolo}${_fmt.format(cotizacion.total)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: azul)),
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
            _cond(_t('Envíos:'), _t('Por el momento solo dentro de México.'), grisTexto),
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
    final grupos = agruparPorCategoria(cotizacion.items);
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

    final nombreEmpresa = _limpiarTexto((_vacio(empresa['nombre_comercial']) ? AuthService.marcaTaller : empresa['nombre_comercial']));
    final rfcEmpresa = empresa['rfc'] ?? '';
    final direccion = _limpiarTexto(empresa['direccion'] ?? '');
    // El teléfono se guarda en "telefono" (antes se buscaba "telefono1" y nunca salía)
    final tel1 = _telInternacional('${empresa['telefono1'] ?? empresa['telefono'] ?? ''}');
    final correoEmpresa = empresa['correo'] ?? '';
    final web = '${empresa['sitio_web'] ?? ''}'.trim();
    final eslogan = _limpiarTexto('${empresa['eslogan'] ?? ''}'.trim());
    final contactoNombre = _limpiarTexto('${empresa['contacto_nombre'] ?? ''}'.trim());
    final contactoCargo = _limpiarTexto('${empresa['contacto_cargo'] ?? ''}'.trim());
    final cliente = cotizacion.cliente;
    final folio = cotizacion.folio ?? 'COT-${DateTime.now().millisecondsSinceEpoch}';
    // Identificador del cliente y número de proyecto (si no se escribe, el del cliente sale de la app)
    final clienteRef = v('cliente_ref').isNotEmpty ? v('cliente_ref')
      : (cotizacion.clienteId != null && cotizacion.clienteId!.replaceAll('-', '').length >= 6 ? 'CLI-${cotizacion.clienteId!.replaceAll('-', '').substring(0, 6).toUpperCase()}' : '');
    final proyectoNum = v('proyecto_num');
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
      final llenas = filas.where((f) => f.$2.isNotEmpty).map((f) => f.$1.isEmpty ? ('-', f.$2) : f).toList();
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

    // "Tema: texto" por renglón → filas de tabla (se traducen si existe la traducción)
    List<(String, String)> temas(String k) => lineas(k).map((l) {
      final t = _t(l);
      final i = t.indexOf(':');
      String may(String x) => x.isEmpty ? x : x[0].toUpperCase() + x.substring(1);
      return i > 0 && i < 40 ? (t.substring(0, i).trim(), may(t.substring(i + 1).trim())) : ('', t);
    }).toList();
    final condicionesLista = temas('condiciones_lista');
    final calidadLista = temas('calidad_lista');
    final confidencialidad = lineas('confidencialidad').map(_t).toList();
    // Términos internacionales: con moneda distinta al peso, PDF en inglés o Incoterm acordado
    final internacional = (moneda != 'MXN' || _en || v('incoterm').isNotEmpty) ? <(String, String)>[
      (_t('País de origen'), v('origen').isEmpty ? _t('México') : _t(v('origen'))),
      (_t('Tiempo de fabricación'), _t(v('tiempo_entrega'))),
      (_t('Términos de envío'), v('envio_terminos').isNotEmpty ? _t(v('envio_terminos')) : _limpiarTexto(_t(cotizacion.condicionEntrega ?? ''))),
      (_t('Empaque'), _t(v('empaque'))),
      (_t('Documentación de exportación'), _t('Cuando aplique, según el destino.')),
      if (v('incoterm').isNotEmpty) (_t('Incoterms 2020'), v('incoterm')),
      (_t('Impuestos y aranceles'), _t('Los impuestos y aranceles del país de destino corren por cuenta del importador, salvo acuerdo por escrito.')),
    ] : <(String, String)>[];
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
      (_t('Impuestos'), cotizacion.ivaPct > 0 ? _tf('{0} {1}% desglosado. Total con impuestos incluidos.', [_etqIva(empresa), pctTexto(cotizacion.ivaPct)]) : _tf('Precios sin {0}', [_etqIva(empresa)])),
      (_t('Envíos'), _leyendaEnvio(empresa)),
      if (v('condiciones_lista').isEmpty) (_t('Cambios y cancelaciones'), _t(v('cambios'))),
      (_t('Notas'), _limpiarTexto(cotizacion.notas ?? '')),
    ];

    double numPro(String k) => double.tryParse(v(k).replaceAll(',', '.')) ?? 0;
    final infoArch = d['archivo_info'] is Map ? Map<String, dynamic>.from(d['archivo_info'] as Map) : null;
    final trazosArch = GeoCad.geoDeJson(d['archivo_geo']);
    // Todas las cotas del archivo 2D: van sobre el croquis y en una tabla
    final es3DArch = infoArch != null && (infoArch['tipo'] == 'stl' || infoArch['tipo'] == 'obj');
    final cotasPdf = es3DArch ? <Cota>[] : cotasDe(trazosArch);
    // ── Piezas de la cotización: la principal y los demás diseños ──
    final matPrincipal = d['material_principal'] is Map ? Map<String, dynamic>.from(d['material_principal'] as Map) : <String, dynamic>{};
    final piezasPdf = <({Map<String, dynamic> info, Map<String, dynamic> mat, List<List<List<double>>> tz, bool es3D, List<Cota> cotas})>[];
    if (infoArch != null) piezasPdf.add((info: infoArch, mat: matPrincipal, tz: trazosArch, es3D: es3DArch, cotas: cotasPdf));
    if (d['otras_piezas'] is List) {
      for (final m in (d['otras_piezas'] as List).whereType<Map>()) {
        final info = Map<String, dynamic>.from((m['info'] as Map?) ?? const {});
        final tz = GeoCad.geoDeJson(m['geo']);
        final es3D = info['tipo'] == 'stl' || info['tipo'] == 'obj';
        final mat = m['material'] is Map ? Map<String, dynamic>.from(m['material'] as Map) : <String, dynamic>{};
        piezasPdf.add((info: info, mat: mat, tz: tz, es3D: es3D, cotas: es3D ? <Cota>[] : cotasDe(tz)));
      }
    }
    // Número de parte del taller y número de plano: prefijo + número del folio + consecutivo
    final gruposFolio = RegExp(r'\d+').allMatches(folio).map((x) => x.group(0)!).toList();
    final folioCorto = gruposFolio.isEmpty ? '0' : gruposFolio.last;
    final prefijoCfg = '${empresa['prefijo_parte'] ?? ''}'.trim().toUpperCase();
    final prefijo = prefijoCfg.isNotEmpty ? prefijoCfg : _iniciales(nombreEmpresa);
    String nn(int i) => (i + 1).toString().padLeft(2, '0');
    String parteTaller(int i) => '$prefijo-$folioCorto-${nn(i)}';
    String numPlano(int i) => 'PL-$folioCorto-${nn(i)}';
    final revisor = contactoNombre.isNotEmpty ? contactoNombre : nombreEmpresa;
    String tm(Map<String, dynamic> m, String k) => _limpiarTexto('${m[k] ?? ''}'.trim());
    Set<int> criticasDe(Map<String, dynamic> m) => RegExp(r'\d+').allMatches('${m['criticas'] ?? ''}').map((x) => int.parse(x.group(0)!)).toSet();
    String nombrePieza(int i) {
      final p = piezasPdf[i];
      final n = tm(p.mat, 'nombre');
      return n.isNotEmpty ? n : _limpiarTexto('${p.info['nombre'] ?? ''}'.replaceFirst(RegExp(r'\.[^.]+$'), ''));
    }
    String materialPieza(Map<String, dynamic> m) {
      final x = [tm(m, 'material'), tm(m, 'grado')].where((e) => e.isNotEmpty).join(' - ');
      return x.isNotEmpty ? x : (v('material').isNotEmpty ? v('material') : '-');
    }
    String espesorPieza(Map<String, dynamic> m, Map<String, dynamic> info, bool es3D) {
      final e = _numMat(m['espesor']) ?? (es3D ? ((info['alto'] as num?) ?? 0).toDouble() : null);
      return e != null && e > 0 ? '${_fmtN(e, e % 1 == 0 ? 0 : 1)} mm' : '-';
    }
    String toleranciaPieza(Map<String, dynamic> m) =>
      tm(m, 'tolerancia').isNotEmpty ? tm(m, 'tolerancia') : (v('tolerancia').isNotEmpty ? v('tolerancia') : _t('Según plano aprobado'));

    // Especificación técnica de cada pieza (Detalle técnico): PART NUMBER y sus datos de fabricación
    pw.Widget specPieza(int i) {
      final p = piezasPdf[i];
      final m = p.mat, info = p.info;
      String nf(dynamic x, [int dec = 1]) => _fmtN(((x as num?) ?? 0).toDouble(), dec);
      final piezas = (_numMat(m['piezas']) ?? 0).round();
      final celdas = <(String, String)>[
        (_t('N.º de parte del cliente'), tm(m, 'parte_cliente').isEmpty ? '-' : tm(m, 'parte_cliente')),
        (_t('Proceso'), tm(m, 'proceso').isNotEmpty ? tm(m, 'proceso') : (v('proceso').isNotEmpty ? v('proceso') : '-')),
        (_t('Material y grado'), materialPieza(m)),
        (_t('Espesor'), espesorPieza(m, info, p.es3D)),
        (_t('Dimensiones'), p.es3D ? '${nf(info['largo'])} x ${nf(info['ancho'])} x ${nf(info['alto'])} mm' : '${nf(info['largo'])} x ${nf(info['ancho'])} mm'),
        (_t('Cantidad'), piezas > 0 ? '$piezas ${piezas == 1 ? _t('pieza') : _t('piezas')}' : '-'),
        (_t('Archivo'), _limpiarTexto('${info['nombre'] ?? '-'}')),
        (_t('Revisión CAD'), 'Rev. ${tm(m, 'rev_cad').isEmpty ? 'A' : tm(m, 'rev_cad')}'),
        (_t('Plano'), '${numPlano(i)} (${_t('Anexo')} ${i + 1})'),
        (_t('Tolerancia'), toleranciaPieza(m)),
        (_t('Acabado superficial'), tm(m, 'acabado').isNotEmpty ? tm(m, 'acabado') : (v('acabado').isNotEmpty ? v('acabado') : '-')),
        p.es3D
          ? (_t('Volumen'), '${nf(info['volumen_cm3'], 1)} cm3')
          : (_t('Corte / barrenos'), '${nf(((info['longitud_corte'] as num?) ?? 0) / 1000, 2)} m / ${info['barrenos'] ?? 0}'),
      ];
      pw.Widget celda((String, String) c) => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(c.$1, style: const pw.TextStyle(fontSize: 6.5, color: grisTexto)),
          pw.Text(c.$2, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
        ]));
      return _entero(pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: azul, width: 0.6), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(color: azul, padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: pw.Row(children: [
              pw.Text('PART NUMBER  ${parteTaller(i)}', style: pw.TextStyle(fontSize: 9, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              pw.Spacer(),
              pw.Text(nombrePieza(i), style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white)),
            ])),
          pw.Table(
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: grisLinea, width: 0.4), verticalInside: pw.BorderSide(color: grisLinea, width: 0.4)),
            children: [
              for (int k = 0; k < celdas.length; k += 3)
                pw.TableRow(children: [for (int c = k; c < k + 3; c++) c < celdas.length ? celda(celdas[c]) : pw.SizedBox()]),
            ]),
        ])));
    }
    final specs = [for (int i = 0; i < piezasPdf.length; i++) specPieza(i)];

    // Dibujo de la pieza que mandó el Simulador 2.0 (3D sombreado)
    pw.Widget? imagenPieza;
    if (d['archivo_png'] is String) {
      try {
        final bytes = base64Decode(d['archivo_png'] as String);
        if (bytes.isNotEmpty) {
          imagenPieza = pw.Container(
            width: double.infinity, height: 200, padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: grisLinea, width: 0.5), borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain));
        }
      } catch (_) {}
    }

    // Planos del anexo: croquis con cotas y su cajetín (plano, pieza, revisión, escala…)
    final anexos = <pw.Widget>[];
    for (int i = 0; i < piezasPdf.length; i++) {
      final p = piezasPdf[i];
      final crit = criticasDe(p.mat);
      final titulo = _limpiarTexto('${_t('ANEXO')} ${i + 1} - ${_t('PLANO')} ${numPlano(i)}: ${nombrePieza(i)}');
      pw.Widget? dibujo;
      if (i == 0 && p.es3D && imagenPieza != null) {
        dibujo = pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(titulo, style: pw.TextStyle(fontSize: 8, color: grisTexto, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 3), imagenPieza]);
      } else {
        dibujo = _croquisPieza(
          largo: ((p.info['largo'] as num?) ?? 0).toDouble(), ancho: ((p.info['ancho'] as num?) ?? 0).toDouble(),
          espesor: _numMat(p.mat['espesor']) ?? (i == 0 ? numPro('croquis_espesor') : (p.es3D ? ((p.info['alto'] as num?) ?? 0).toDouble() : 0)),
          barrenoD: 0, barrenos: 0, azul: azul, gris: grisTexto,
          trazos: p.tz, es3D: p.es3D, cotas: p.cotas, criticas: crit, titulo: titulo, nota: _notaMaterial(p.mat, p.info));
      }
      if (dibujo == null) continue;
      anexos.add(pw.SizedBox(height: 10));
      anexos.add(_entero(pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        dibujo,
        _cajetin(azul: azul, gris: grisTexto, celdas: [
          (_t('Plano No.'), numPlano(i)), (_t('N.º de parte'), [parteTaller(i), if (tm(p.mat, 'parte_cliente').isNotEmpty) tm(p.mat, 'parte_cliente')].join(' / ')),
          (_t('Revisión'), tm(p.mat, 'rev_cad').isEmpty ? 'A' : tm(p.mat, 'rev_cad')), (_t('Unidades'), 'mm'),
          (_t('Escala'), _t('S/E (sin escala)')), (_t('Fecha'), fecha),
          (_t('Material'), materialPieza(p.mat)), (_t('Espesor'), espesorPieza(p.mat, p.info, p.es3D)),
          (_t('Tolerancias generales'), toleranciaPieza(p.mat)), (_t('Referencia'), _t('X0 Y0: esquina inferior izquierda')),
          (_t('Revisó'), revisor), (_t('Cotización'), '$folio Rev. $revision'),
        ]),
      ])));
      if (p.cotas.isNotEmpty) { anexos.add(pw.SizedBox(height: 4)); anexos.add(_tablaCotasPdf(p.cotas, grisTexto, criticas: crit)); }
    }
    // Cotizaciones viejas sin archivo: el croquis de rectángulo con largo y ancho escritos a mano
    if (piezasPdf.isEmpty) {
      final viejo = _croquisPieza(largo: numPro('croquis_largo'), ancho: numPro('croquis_ancho'), espesor: numPro('croquis_espesor'),
        barrenoD: numPro('croquis_barreno_d'), barrenos: numPro('croquis_barrenos').round(), azul: azul, gris: grisTexto);
      if (viejo != null) { anexos.add(pw.SizedBox(height: 10)); anexos.add(_entero(viejo)); }
    }
    final numAnexos = anexos.whereType<pw.Row>().length;
    final hayAnexos = numAnexos > 0;
    // Con archivos, las medidas y el archivo de cada pieza ya van en su especificación
    if (piezasPdf.isNotEmpty) tecnicos.removeWhere((f) => f.$1 == _t('Medidas / espesor') || f.$1 == _t('Archivo recibido'));

    int n = 0;
    String sig() => '${++n}';

    pdf.addPage(pw.MultiPage(
      pageTheme: _tema(const pw.EdgeInsets.fromLTRB(28, 28, 28, 36)),
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
              pw.Image(logoImage, width: 150, height: 46, fit: pw.BoxFit.contain)
            else
              pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: azul)),
            pw.SizedBox(height: 5),
            pw.Text(eslogan.isEmpty ? nombreEmpresa : '$nombreEmpresa - $eslogan', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: azul)),
            if (rfcEmpresa.isNotEmpty) pw.Text('${_etqRfc(empresa)}: $rfcEmpresa', style: const pw.TextStyle(fontSize: 8, color: grisTexto)),
            if (direccion.isNotEmpty) pw.Text(_tf('Domicilio fiscal: {0}', [direccion]), style: const pw.TextStyle(fontSize: 8, color: grisTexto)),
            if (contactoNombre.isNotEmpty) pw.Text(_tf('Contacto comercial: {0}', [contactoCargo.isEmpty ? contactoNombre : '$contactoNombre, $contactoCargo']),
              style: const pw.TextStyle(fontSize: 8, color: grisTexto)),
            pw.Text([if (tel1.isNotEmpty) _tf('Tel: {0}', [tel1]), if (correoEmpresa.isNotEmpty) correoEmpresa, if (web.isNotEmpty) web].join('  ·  '),
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
                if (proyectoNum.isNotEmpty) _filaEnc(_t('Proyecto No.'), proyectoNum, azul),
                if (clienteRef.isNotEmpty) _filaEnc(_t('ID de cliente'), clienteRef, azul),
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
        if (hay(tecnicos) || hayAnexos || specs.isNotEmpty) ...[
          titulo(sig(), _t('DETALLE TÉCNICO DE LAS PIEZAS')),
          ...specs,
          if (hay(tecnicos)) datos(tecnicos),
          if (hayAnexos) pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Text(
            _tf('Plano de cada pieza con sus cotas, material, espesor y tolerancias: ver anexos al final ({0}).', [numAnexos]),
            style: pw.TextStyle(fontSize: 8.5, color: grisTexto, fontStyle: pw.FontStyle.italic))),
        ],

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
            ...() {
              // Con más de una categoría: encabezado y subtotal por categoría
              pw.TableRow fila(CotizacionItem item, int n, int i) {
              final desc = (item.descripcion ?? '').trim();
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : grisClaro),
                children: [
                  _cD('$n', center: true),
                  pw.Padding(padding: const pw.EdgeInsets.all(6),
                    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      if (_miniatura(item.imagenPng) != null) ...[
                        pw.Container(width: 78, height: 50, margin: const pw.EdgeInsets.only(right: 6),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: grisLinea, width: 0.5)),
                          child: pw.Image(_miniatura(item.imagenPng)!, fit: pw.BoxFit.contain)),
                      ],
                      pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text(_limpiarTexto(item.nombreProducto),
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: azul)),
                        if (desc.isNotEmpty) pw.Text(_limpiarTexto(desc), style: const pw.TextStyle(fontSize: 8, color: grisTexto)),
                        if (item.medidas != null && item.medidas!.isNotEmpty)
                          pw.Text('${_t('Medidas')}: ${_limpiarTexto(item.medidas!)}', style: pw.TextStyle(fontSize: 7.5, color: grisTexto, fontWeight: pw.FontWeight.bold)),
                        if (item.sku != null && item.sku!.isNotEmpty)
                          pw.Text(_tf('No. de parte: {0}', [(item.sku)]), style: const pw.TextStyle(fontSize: 7, color: grisTexto)),
                      ])),
                    ])),
                  _cD('${item.cantidad}', center: true),
                  _cD('${Pais.simbolo}${_fmt.format(item.precioUnitario)}', right: true),
                  _cD('${Pais.simbolo}${_fmt.format(item.subtotal)}', right: true),
                ]);
              }
              if (grupos.length < 2) return [for (int i = 0; i < cotizacion.items.length; i++) fila(cotizacion.items[i], i + 1, i)];
              final filas = <pw.TableRow>[];
              int n = 0;
              for (final g in grupos) {
                filas.add(pw.TableRow(decoration: pw.BoxDecoration(color: azulClaro), children: [
                  pw.SizedBox(),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: pw.Text(_t(g.nombre).toUpperCase(), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: azul, letterSpacing: 0.5))),
                  pw.SizedBox(), pw.SizedBox(), pw.SizedBox(),
                ]));
                for (int j = 0; j < g.items.length; j++) { n++; filas.add(fila(g.items[j], n, j)); }
                if (g.items.length > 1) filas.add(pw.TableRow(verticalAlignment: pw.TableCellVerticalAlignment.middle, children: [
                  pw.SizedBox(), pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: pw.Text(_tf('Subtotal {0}', [_t(g.nombre)]), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, color: grisTexto, fontStyle: pw.FontStyle.italic))),
                  pw.SizedBox(), pw.SizedBox(),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: pw.Text('${Pais.simbolo}${_fmt.format(g.subtotal)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: azul))),
                ]));
              }
              return filas;
            }(),
          ]),
        pw.SizedBox(height: 8),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (grupos.length > 1) pw.Expanded(child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 16),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: grisLinea, width: 0.5), borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(_t('RESUMEN POR CATEGORÍA'), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: azul)),
              pw.SizedBox(height: 4),
              ...grupos.map((g) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 2), child: pw.Row(children: [
                pw.Expanded(child: pw.Text(_t(g.nombre), style: const pw.TextStyle(fontSize: 8))),
                pw.Text(cotizacion.subtotal > 0 ? '${(g.subtotal / cotizacion.subtotal * 100).round()}%' : '', style: const pw.TextStyle(fontSize: 7.5, color: grisTexto)),
                pw.SizedBox(width: 8),
                pw.SizedBox(width: 70, child: pw.Text('${Pais.simbolo}${_fmt.format(g.subtotal)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
              ]))),
            ]))),
          pw.Container(width: 230, child: pw.Column(children: [
            _tR(_t('Subtotal'), '${Pais.simbolo}${_fmt.format(cotizacion.subtotal)}', grisTexto),
            if (cotizacion.montoDescuento > 0)
              _tR(_tf('Descuento{0}', [(cotizacion.descuentoPct > 0 ? " ${cotizacion.descuentoPct.toInt()}%" : "")]),
                '-\$${_fmt.format(cotizacion.montoDescuento)}', verde),
            if (cotizacion.ivaPct > 0) _tR('${_etqIva(empresa)} ${pctTexto(cotizacion.ivaPct)}%', '${Pais.simbolo}${_fmt.format(cotizacion.montoIva)}', grisTexto),
            if (cotizacion.costoEnvio > 0) _tR(_t('Envío'), '${Pais.simbolo}${_fmt.format(cotizacion.costoEnvio)}', grisTexto),
            pw.Divider(color: azul),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOTAL $moneda', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: azul)),
              pw.Text('${Pais.simbolo}${_fmt.format(cotizacion.total)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: azul)),
            ]),
            if (cotizacion.ivaPct > 0) pw.Padding(padding: const pw.EdgeInsets.only(top: 2), child: pw.Text(
              _tf('{0} desglosado. Total con impuestos incluidos.', [_etqIva(empresa)]),
              textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7, color: grisTexto))),
          ])),
        ]),

        // ─── 6. CONDICIONES COMERCIALES ─────
        titulo(sig(), _t('CONDICIONES COMERCIALES')),
        datos(comerciales),
        if (condicionesLista.isNotEmpty) ...[pw.SizedBox(height: 4), datos(condicionesLista)],

        // ─── TÉRMINOS INTERNACIONALES ───────
        if (internacional.any((f) => f.$2.isNotEmpty)) ...[
          titulo(sig(), _t('TÉRMINOS INTERNACIONALES')),
          datos(internacional),
        ],

        // ─── 7. CALIDAD ─────────────────────
        if (calidadLista.isNotEmpty || v('calidad').isNotEmpty || v('tolerancia').isNotEmpty) ...[
          titulo(sig(), _t('CONDICIONES TÉCNICAS Y DE CALIDAD')),
          if (calidadLista.isNotEmpty) ...[datos(calidadLista), pw.SizedBox(height: 4)],
          if (v('calidad').isNotEmpty || v('tolerancia').isNotEmpty || (empresa['leyenda_pdf'] as String?)?.isNotEmpty == true) pw.Container(
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

        // ─── CONFIDENCIALIDAD ───────────────
        if (confidencialidad.isNotEmpty) ...[
          titulo(sig(), _t('CONFIDENCIALIDAD Y PROPIEDAD INTELECTUAL')),
          ...confidencialidad.map((l) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('-  ', style: const pw.TextStyle(fontSize: 8.5)),
              pw.Expanded(child: pw.Text(l, style: const pw.TextStyle(fontSize: 8.5))),
            ]))),
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

        // ─── ANEXOS: croquis de cada pieza con sus cotas, material y espesor ───
        if (hayAnexos) ...[
          pw.NewPage(),
          titulo('A', _t('ANEXOS: PLANOS DE LAS PIEZAS')),
          ...anexos,
        ],
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

  // ── Croquis acotado de la pieza (vista superior + lateral) ──
  // Dibuja un rectángulo de largo × ancho con sus cotas, barrenos opcionales
  // y, si hay espesor, una vista lateral. Ilustrativo, no a escala real.
  // Miniatura de la pieza guardada en la partida (PNG base64)
  static final Map<String, pw.MemoryImage> _cacheMini = {};
  static pw.MemoryImage? _miniatura(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return _cacheMini.putIfAbsent(b64.hashCode.toString(), () => pw.MemoryImage(base64Decode(b64)));
    } catch (_) { return null; }
  }

  static pw.Widget? _croquisPieza({
    required double largo, required double ancho, required double espesor,
    required double barrenoD, required int barrenos,
    required PdfColor azul, required PdfColor gris,
    List<List<List<double>>> trazos = const [], bool es3D = false,
    List<Cota> cotas = const [],
    String? titulo,
    String? nota,
    Set<int> criticas = const {},
  }) {
    // Con archivo: el dibujo es la pieza real y las medidas salen de él
    if (trazos.isNotEmpty) {
      double mx = 0, my = 0;
      for (final t in trazos) { for (final q in t) { if (q[0] > mx) mx = q[0]; if (q[1] > my) my = q[1]; } }
      if (mx > 0 && my > 0) { largo = mx; ancho = my; }
      barrenos = 0; // los barrenos ya vienen dibujados
    }
    if (largo <= 0 || ancho <= 0) return null;
    const double W = 480, H = 190;
    // Caja disponible para la vista superior
    const double boxW = 250, boxH = 120, ox = 50, oy = 40; // ox/oy: margen para cotas
    final esc = (boxW / largo) < (boxH / ancho) ? boxW / largo : boxH / ancho;
    final rw = largo * esc, rh = ancho * esc;
    final rx = ox + (boxW - rw) / 2;
    final ryTop = oy + (boxH - rh) / 2; // desde arriba (coordenadas de Stack)
    // Vista lateral a la derecha
    final tieneLado = espesor > 0;
    final lw = rw > 90 ? 90.0 : rw;
    // La vista lateral y su cota deben caber completas en el croquis (antes el espesor quedaba cortado a la derecha)
    final lx = math.min(ox + boxW + 50, W - lw - 70);
    double lh = espesor * (lw / largo);
    if (lh < 6) lh = 6;
    if (lh > 60) lh = 60;
    final lyTop = ryTop + (rh - lh) / 2;
    String mm(double x) => x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1);
    final estilo = pw.TextStyle(fontSize: 8, color: azul, fontWeight: pw.FontWeight.bold);
    final estiloGris = pw.TextStyle(fontSize: 7, color: gris);

    // Barrenos: hasta 4 en las esquinas (o 1 al centro)
    final nB = barrenos.clamp(0, 4).toInt();
    final holes = <(double, double)>[];
    final rB = barrenoD > 0 ? (barrenoD * esc / 2).clamp(2.0, 12.0).toDouble() : 0.0;
    if (barrenoD > 0 && nB > 0) {
      final ins = rB + 6;
      if (nB == 1) holes.add((rx + rw / 2, ryTop + rh / 2));
      else {
        final cands = [(rx + ins, ryTop + ins), (rx + rw - ins, ryTop + ins),
          (rx + ins, ryTop + rh - ins), (rx + rw - ins, ryTop + rh - ins)];
        holes.addAll(cands.take(nB));
      }
    }

    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor.fromInt(0xFFD1D5DB), width: 0.5),
        borderRadius: pw.BorderRadius.circular(4)),
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(titulo ?? _t('CROQUIS DE LA PIEZA'), style: pw.TextStyle(fontSize: 8, color: gris, fontWeight: pw.FontWeight.bold)),
        if (nota != null && nota.isNotEmpty) pw.Text(nota, style: pw.TextStyle(fontSize: 8, color: azul, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(
          width: W, height: H,
          child: pw.Stack(children: [
            pw.Positioned(left: 0, top: 0, child: pw.CustomPaint(
              size: const PdfPoint(W, H),
              painter: (PdfGraphics c, PdfPoint size) {
                // El lienzo del PDF tiene el origen abajo-izquierda
                double Y(double top) => H - top;
                void linea(double x1, double t1, double x2, double t2) {
                  c.drawLine(x1, Y(t1), x2, Y(t2));
                  c.strokePath();
                }
                void flecha(double x, double t, double dx, double dt) {
                  // punta de flecha en (x,t) apuntando en dirección (dx,dt)
                  const a = 4.0;
                  if (dt == 0) { linea(x, t, x - dx * a, t - 2); linea(x, t, x - dx * a, t + 2); }
                  else { linea(x, t, x - 2, t - dt * a); linea(x, t, x + 2, t - dt * a); }
                }
                void cotaH(double x1, double x2, double t) {
                  linea(x1, t, x2, t); flecha(x1, t, -1, 0); flecha(x2, t, 1, 0);
                }
                void cotaV(double x, double t1, double t2) {
                  linea(x, t1, x, t2); flecha(x, t1, 0, -1); flecha(x, t2, 0, 1);
                }
                // Pieza (vista superior): archivo real o rectángulo
                c.setStrokeColor(azul);
                if (trazos.isNotEmpty) {
                  c.setLineWidth(es3D ? 0.5 : 0.9);
                  for (final t in trazos) {
                    for (int i = 0; i < t.length; i++) {
                      final px = rx + t[i][0] * esc, py = Y(ryTop + rh - t[i][1] * esc);
                      if (i == 0) c.moveTo(px, py); else c.lineTo(px, py);
                    }
                    c.strokePath();
                  }
                } else {
                  c.setLineWidth(1.2);
                  c.drawRect(rx, Y(ryTop + rh), rw, rh);
                  c.strokePath();
                }
                // Barrenos
                c.setLineWidth(0.8);
                for (final h in holes) {
                  c.drawEllipse(h.$1, Y(h.$2), rB, rB);
                  c.strokePath();
                  c.setLineWidth(0.3);
                  linea(h.$1 - rB - 3, h.$2, h.$1 + rB + 3, h.$2);
                  linea(h.$1, h.$2 - rB - 3, h.$1, h.$2 + rB + 3);
                  c.setLineWidth(0.8);
                }
                // Ejes del origen (X0 Y0) en la esquina inferior izquierda de la pieza
                if (trazos.isNotEmpty && !es3D) {
                  c.setStrokeColor(const PdfColor.fromInt(0xFFB42318));
                  c.setLineWidth(0.6);
                  final ox0 = rx, oy0 = ryTop + rh;
                  linea(ox0, oy0, ox0 + 14, oy0); linea(ox0 + 14, oy0, ox0 + 11, oy0 - 1.5); linea(ox0 + 14, oy0, ox0 + 11, oy0 + 1.5);
                  linea(ox0, oy0, ox0, oy0 - 14); linea(ox0, oy0 - 14, ox0 - 1.5, oy0 - 11); linea(ox0, oy0 - 14, ox0 + 1.5, oy0 - 11);
                }
                // Distancia entre barrenos: línea punteada de centro a centro
                c.setStrokeColor(const PdfColor.fromInt(0xFF1F5FBF));
                c.setLineWidth(0.4);
                for (final ct in cotas.where((x) => x.tipo == TipoCota.distancia)) {
                  final ax = rx + ct.x1 * esc, at = ryTop + rh - ct.y1 * esc, bx = rx + ct.x2 * esc, bt = ryTop + rh - ct.y2 * esc;
                  final l = math.sqrt((bx - ax) * (bx - ax) + (bt - at) * (bt - at));
                  if (l < 2) continue;
                  final ux = (bx - ax) / l, ut = (bt - at) / l;
                  for (double t = 0; t < l; t += 4) {
                    final t2 = math.min(t + 2, l);
                    linea(ax + ux * t, at + ut * t, ax + ux * t2, at + ut * t2);
                  }
                }
                // Cotas
                c.setStrokeColor(gris);
                c.setLineWidth(0.5);
                // extensión y cota del largo (arriba)
                linea(rx, ryTop - 4, rx, ryTop - 24);
                linea(rx + rw, ryTop - 4, rx + rw, ryTop - 24);
                cotaH(rx, rx + rw, ryTop - 18);
                // extensión y cota del ancho (izquierda)
                linea(rx - 4, ryTop, rx - 28, ryTop);
                linea(rx - 4, ryTop + rh, rx - 28, ryTop + rh);
                cotaV(rx - 22, ryTop, ryTop + rh);
                // Vista lateral
                if (tieneLado) {
                  c.setStrokeColor(azul);
                  c.setLineWidth(1.2);
                  c.drawRect(lx, Y(lyTop + lh), lw, lh);
                  c.strokePath();
                  c.setStrokeColor(gris);
                  c.setLineWidth(0.5);
                  linea(lx + lw + 4, lyTop, lx + lw + 26, lyTop);
                  linea(lx + lw + 4, lyTop + lh, lx + lw + 26, lyTop + lh);
                  cotaV(lx + lw + 20, lyTop, lyTop + lh);
                }
              })),
            // Etiquetas de las cotas
            pw.Positioned(left: rx, top: ryTop - 31, child: pw.SizedBox(width: rw,
              child: pw.Text(mm(largo), style: estilo, textAlign: pw.TextAlign.center))),
            pw.Positioned(left: rx - 48, top: ryTop + rh / 2 - 5, child: pw.SizedBox(width: 22,
              child: pw.Text(mm(ancho), style: estilo, textAlign: pw.TextAlign.right))),
            pw.Positioned(left: rx, top: ryTop + rh + (cotas.isNotEmpty ? 12 : 6), child: pw.SizedBox(width: rw,
              child: pw.Text(es3D ? _t('Vista superior (malla)') : _t('Vista superior'), style: estiloGris, textAlign: pw.TextAlign.center))),
            // Cotas de cada tramo: la medida si cabe, si no su número (ver la tabla)
            ..._etiquetasCotas(cotas, rx: rx, ryTop: ryTop, rh: rh, esc: esc, maxX: largo, maxY: ancho, gris: gris, criticas: criticas),
            // Origen del sistema de referencia: X0 Y0 en la esquina inferior izquierda
            if (trazos.isNotEmpty && !es3D) ...[
              pw.Positioned(left: rx - 27, top: ryTop + rh + 2, child: pw.Text('X0 Y0', style: pw.TextStyle(fontSize: 5.5, color: gris, fontWeight: pw.FontWeight.bold))),
            ],
            if (holes.isNotEmpty)
              pw.Positioned(left: rx, top: ryTop + rh + (cotas.isNotEmpty ? 22 : 16), child: pw.SizedBox(width: rw,
                child: pw.Text('${holes.length} x Ø${mm(barrenoD)}', style: estilo, textAlign: pw.TextAlign.center))),
            if (tieneLado) ...[
              pw.Positioned(left: lx + lw + 28, top: lyTop + lh / 2 - 5,
                child: pw.Text('${mm(espesor)} mm', style: estilo)),
              pw.Positioned(left: lx - 10, top: lyTop + lh + 6, child: pw.SizedBox(width: lw + 20,
                child: pw.Column(children: [
                  pw.Text(_t('Vista lateral'), style: estiloGris, textAlign: pw.TextAlign.center),
                  pw.Text('${_t('Espesor')}: ${mm(espesor)} mm', style: estilo, textAlign: pw.TextAlign.center),
                ]))),
            ],
          ])),
        pw.Text(_t('Medidas en mm. Croquis ilustrativo, no a escala.'), style: estiloGris),
      ]));
  }

  /// 10 dígitos sin lada internacional → "+52 246 121 7072" (México). Lo demás se deja como venga.
  static String _telInternacional(String t) {
    final limpio = t.trim();
    final dig = limpio.replaceAll(RegExp(r'\D'), '');
    if (limpio.startsWith('+') || dig.length != 10) return limpio;
    return '+52 ${dig.substring(0, 3)} ${dig.substring(3, 6)} ${dig.substring(6)}';
  }

  /// "HetNa CNC" → "HC". Prefijo de los números de parte si el taller no puso uno.
  static String _iniciales(String nombre) {
    final l = nombre.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase()).join();
    return l.isEmpty ? 'PZ' : (l.length > 3 ? l.substring(0, 3) : l);
  }

  /// Cajetín del plano: 12 datos en 2 renglones de 6
  static pw.Widget _cajetin({required PdfColor azul, required PdfColor gris, required List<(String, String)> celdas}) {
    pw.Widget c((String, String) x) => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(x.$1, style: pw.TextStyle(fontSize: 5.8, color: gris)),
        pw.Text(_limpiarTexto(x.$2), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: azul)),
      ]));
    return pw.Table(
      border: pw.TableBorder.all(color: azul, width: 0.6),
      children: [
        for (int k = 0; k < celdas.length; k += 6)
          pw.TableRow(children: [for (int i = k; i < k + 6; i++) i < celdas.length ? c(celdas[i]) : pw.SizedBox()]),
      ]);
  }

  // Un bloque que no se parte entre páginas (si no cabe, pasa entero a la siguiente)
  static pw.Widget _entero(pw.Widget w) => pw.Row(children: [pw.Expanded(child: w)]);

  static double? _numMat(dynamic v) {
    final d = double.tryParse('${v ?? ''}'.replaceAll(',', '.').trim());
    return d != null && d > 0 ? d : null;
  }

  /// "Material: MDF · Espesor: 18 mm · 20 pz por hoja de 2440 × 1220 mm · 16 hojas para 320 pz"
  static String _notaMaterial(Map<String, dynamic> m, Map<String, dynamic>? info) {
    final partes = <String>[];
    final mat = '${m['material'] ?? ''}'.trim();
    final esp = _numMat(m['espesor']);
    if (mat.isNotEmpty) partes.add('${_t('Material')}: $mat');
    if (esp != null) partes.add('${_t('Espesor')}: ${_fmtN(esp, esp % 1 == 0 ? 0 : 1)} mm');
    final mL = _numMat(m['mat_l']), mA = _numMat(m['mat_a']);
    final pL = ((info?['largo'] as num?) ?? 0).toDouble(), pA = ((info?['ancho'] as num?) ?? 0).toDouble();
    if (mL != null && mA != null && pL > 0 && pA > 0) {
      final piezas = (_numMat(m['piezas']) ?? 1).round();
      final r = calcularMaterial(pzL: pL, pzA: pA, matL: mL, matA: mA, sep: _numMat(m['sep']) ?? 0, orilla: _numMat(m['orilla']) ?? 0, piezas: piezas);
      if (r.cabe) {
        final hoja = mA >= 600;
        final u = hoja ? _t('hoja') : _t('tablón'), us = r.unidades == 1 ? u : (hoja ? _t('hojas') : _t('tablones'));
        partes.add(_tf('{0} pz por {1} de {2} x {3} mm · {4} {5} para {6} pz', [r.porUnidad, u, mL.round(), mA.round(), r.unidades, us, r.piezas]));
      }
    }
    return _limpiarTexto(partes.join(' · '));
  }

  static List<pw.Widget> _etiquetasCotas(List<Cota> cotas, {required double rx, required double ryTop, required double rh,
      required double esc, required double maxX, required double maxY, required PdfColor gris, Set<int> criticas = const {}}) {
    if (cotas.isEmpty) return const [];
    const naranjaBase = PdfColor.fromInt(0xFFC2560A);
    const rojo = PdfColor.fromInt(0xFFB42318);
    final soloNumeros = cotas.length > 60;
    double px(double x) => rx + x * esc;
    double top(double y) => ryTop + rh - y * esc;
    final cx0 = px(maxX / 2), cy0 = top(maxY / 2);
    double anchoTxt(String t) => t.length * 3.1 + 2;
    pw.Widget tag(String t, double x, double y, PdfColor color, {bool critica = false}) {
      final w = anchoTxt(t) + (critica ? 4 : 0);
      return pw.Positioned(left: x - w / 2, top: y - 3.5, child: pw.Container(
        width: w,
        decoration: pw.BoxDecoration(color: PdfColors.white, border: critica ? pw.Border.all(color: rojo, width: 0.6) : null),
        child: pw.Text(t, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 5.5, color: critica ? rojo : color, fontWeight: pw.FontWeight.bold))));
    }
    // Una orilla recta del contorno que mide lo mismo que la medida total ya acotada afuera: no se repite
    bool repiteTotal(Cota c) {
      if (c.tipo != TipoCota.linea) return false;
      const t = 0.5;
      final horizontal = (c.y1 - c.y2).abs() < t && ((c.y1).abs() < t || (c.y1 - maxY).abs() < t);
      final vertical = (c.x1 - c.x2).abs() < t && ((c.x1).abs() < t || (c.x1 - maxX).abs() < t);
      return (horizontal && (c.valor - maxX).abs() < t) || (vertical && (c.valor - maxY).abs() < t);
    }
    final out = <pw.Widget>[];
    for (final c in cotas) {
      final critica = criticas.contains(c.n);
      final naranja = critica ? rojo : naranjaBase;
      if (!critica && repiteTotal(c)) continue;
      switch (c.tipo) {
        case TipoCota.linea:
          final ax = px(c.x1), ay = top(c.y1), bx = px(c.x2), by = top(c.y2);
          final dx = bx - ax, dy = by - ay, l = math.sqrt(dx * dx + dy * dy);
          if (l < 0.5) break;
          var nx = -dy / l, ny = dx / l;
          final mx = (ax + bx) / 2, my = (ay + by) / 2;
          if (math.pow(mx + nx - cx0, 2) + math.pow(my + ny - cy0, 2) < math.pow(mx - cx0, 2) + math.pow(my - cy0, 2)) { nx = -nx; ny = -ny; }
          final cabe = !soloNumeros && l >= anchoTxt(c.texto) + 4;
          out.add(tag(cabe ? c.texto : '${c.n}', mx + nx * 5, my + ny * 5, cabe ? naranja : gris, critica: critica));
          break;
        case TipoCota.arco:
          final cx = px(c.cx), cy = top(c.cy), ex = px(c.ex), ey = top(c.ey);
          final vx = ex - cx, vy = ey - cy, d = math.sqrt(vx * vx + vy * vy);
          out.add(tag(soloNumeros ? '${c.n}' : c.texto, d > 0 ? ex + vx / d * 6 : ex, d > 0 ? ey + vy / d * 6 : ey, naranja, critica: critica));
          break;
        case TipoCota.diametro:
          final rr = c.r * esc;
          out.add(tag(soloNumeros ? '${c.n}' : c.texto, px(c.cx) + (rr + 6) * 0.7071, top(c.cy) - (rr + 6) * 0.7071, naranja, critica: critica));
          break;
        case TipoCota.distancia:
          const azulCota = PdfColor.fromInt(0xFF1F5FBF);
          final ax = px(c.x1), ay = top(c.y1), bx = px(c.x2), by = top(c.y2);
          final dx = bx - ax, dy = by - ay, l = math.sqrt(dx * dx + dy * dy);
          if (l < 2) break;
          final cabe = !soloNumeros && l >= anchoTxt(c.texto) + 4;
          out.add(tag(cabe ? c.texto : '${c.n}', (ax + bx) / 2 - dy / l * 5, (ay + by) / 2 + dx / l * 5, critica ? rojo : azulCota, critica: critica));
          break;
      }
    }
    return out;
  }

  /// Tabla de cotas: las líneas y arcos de la misma medida van juntos ("2 x Línea 100 mm (1, 5)")
  /// y las cotas críticas se marcan. Los barrenos van uno por uno con su ubicación.
  static pw.Widget _tablaCotasPdf(List<Cota> cotas, PdfColor gris, {Set<int> criticas = const {}}) {
    const rojo = PdfColor.fromInt(0xFFB42318);
    final renglones = <({String texto, bool critica})>[];
    final grupos = <String, List<Cota>>{};
    for (final c in cotas) {
      if (c.tipo == TipoCota.linea || c.tipo == TipoCota.arco) {
        grupos.putIfAbsent('${c.tipo.name}|${c.texto}', () => []).add(c);
      }
    }
    final yaAgrupadas = <String>{};
    for (final c in cotas) {
      final crit = criticas.contains(c.n);
      if (c.tipo == TipoCota.linea || c.tipo == TipoCota.arco) {
        final clave = '${c.tipo.name}|${c.texto}';
        final g = grupos[clave]!;
        final algunaCritica = g.any((x) => criticas.contains(x.n));
        if (g.length > 1 && !algunaCritica) {
          if (!yaAgrupadas.add(clave)) continue;
          renglones.add((texto: '${g.length} x ${_t(c.nombreTipo)} ${c.texto} mm (${g.map((x) => x.n).join(', ')})', critica: false));
          continue;
        }
        renglones.add((texto: '${c.n}. ${_t(c.nombreTipo)} ${c.texto} mm${c.tipo == TipoCota.arco ? ' (arco ${fmtMm(c.largoArco)})' : ''}', critica: crit));
      } else {
        renglones.add((texto: '${c.n}. ${_t(c.nombreTipo)} ${c.texto} mm${c.tipo == TipoCota.diametro ? ' en ${c.ubicacion}' : ''}', critica: crit));
      }
    }
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('${_t('COTAS DE LA PIEZA')} · ${_limpiarTexto(resumenCotas(cotas))}', style: pw.TextStyle(fontSize: 7.5, color: gris, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      pw.Wrap(spacing: 8, runSpacing: 1, children: [
        for (final r in renglones) pw.SizedBox(width: r.texto.length > 30 ? 175 : 118, child: pw.Text(
          _limpiarTexto(r.critica ? '${r.texto}  * ${_t('CRÍTICA')}' : r.texto),
          style: pw.TextStyle(fontSize: 6.5, color: r.critica ? rojo : PdfColors.black, fontWeight: r.critica ? pw.FontWeight.bold : pw.FontWeight.normal))),
      ]),
      pw.Text(_t('Las orillas que miden lo mismo que la medida total sólo se acotan una vez. Ubicación de barrenos (X, Y) desde el origen X0 Y0 (esquina inferior izquierda); "Entre barrenos" es de centro a centro. Las cotas críticas van en rojo.'),
        style: pw.TextStyle(fontSize: 6, color: gris, fontStyle: pw.FontStyle.italic)),
    ]);
  }

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

    final nombreEmpresa = (_vacio(empresa['nombre_comercial']) ? AuthService.marcaTaller : empresa['nombre_comercial']);
    final tel = empresa['telefono'] ?? '';
    final correo = empresa['correo'] ?? '';
    final web = empresa['sitio_web'] ?? '';
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
                  width: 56, height: 50,
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
                    child: pw.Text('${Pais.simbolo}${_fmt.format(p.precioVenta)}',
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
            pw.Text(_tf('Los precios no incluyen {0}', [_t(Pais.actual.etqImpuesto)]),
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

    final nombreEmpresa    = (_vacio(empresa['nombre_comercial']) ? AuthService.marcaTaller : empresa['nombre_comercial']);
    final telEmpresa       = empresa['telefono'] ?? empresa['telefono2'] ?? '';
    final direccionEmpresa = empresa['direccion'] ?? '';
    final correo           = empresa['correo']   ?? '';
    final web              = empresa['sitio_web'] ?? '';
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
                pw.Image(logoImage, width: 110, height: 32, fit: pw.BoxFit.contain)
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
                  _cD('${Pais.simbolo}${_fmt.format(item.precioUnitario)}', right: true),
                  _cD('${Pais.simbolo}${_fmt.format(item.subtotal)}', right: true),
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
              if (cotizacion.ivaPct > 0) _tR('${_etqIva(empresa)} ${pctTexto(cotizacion.ivaPct)}%', '${Pais.simbolo}${_fmt.format(cotizacion.montoIva)}', grisTexto),
              pw.Divider(color: verde),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text(_t('TOTAL PAGADO'), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: verde)),
                pw.Text('${Pais.simbolo}${_fmt.format(cotizacion.total)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: verde)),
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
