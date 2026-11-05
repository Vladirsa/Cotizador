// lib/screens/orden_qr_screen.dart
// HETNA CNC — Orden de trabajo con QR (ver lib/services/orden_service.dart)
//
//   QrOrdenScreen     el QR de un pedido y su hoja de orden para imprimir
//   LectorOrdenScreen la cámara: lee el QR de la hoja (o el folio a mano)
//   OrdenScreen       cómo va el pedido y los botones de tu rol
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/orden_service.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_service.dart';
import '../i18n/tr.dart';

const _ordenEtapas = ['Pedido', 'Pago50', 'Produccion', 'Pruebas', 'PagoCompleto', 'Entrega', 'Entregado'];
const _colores = {
  'Pedido': AppColors.azul,
  'Pago': AppColors.ambar,
  'Pago50': AppColors.ambar,
  'Produccion': Color(0xFF7c3aed),
  'Pruebas': AppColors.rojo,
  'PagoCompleto': Color(0xFF059669),
  'Entrega': AppColors.verde,
  'Entregado': AppColors.verde,
  'Cancelado': Color(0xFF6b7280),
};
Color _color(String e) => _colores[e] ?? AppColors.azul;

// ══════════════════════════════════════════════════════
// QR DE LA ORDEN + HOJA PARA IMPRIMIR
// ══════════════════════════════════════════════════════
class QrOrdenScreen extends StatefulWidget {
  final String pedidoId;
  final String folio;
  const QrOrdenScreen({super.key, required this.pedidoId, required this.folio});
  @override
  State<QrOrdenScreen> createState() => _QrOrdenScreenState();
}

class _QrOrdenScreenState extends State<QrOrdenScreen> {
  bool _trabajando = false;

  Future<void> _hoja({required bool compartir}) async {
    setState(() => _trabajando = true);
    try {
      final d = await OrdenService.cargar(widget.pedidoId);
      if (d == null) throw Exception(tr('No se encontró el pedido'));
      final bytes = await hojaOrdenPdf(d);
      if (compartir) {
        await Printing.sharePdf(bytes: bytes, filename: 'orden-${widget.folio}.pdf');
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'orden-${widget.folio}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(trf('No se pudo hacer la hoja: {0}', [e])), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: Text(trf('QR de la orden {0}', [widget.folio]))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.grisBorde)),
          child: Column(children: [
            QrImageView(data: OrdenService.contenidoQr(widget.pedidoId), size: 240, version: QrVersions.auto),
            const SizedBox(height: 8),
            Text(widget.folio, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.azul)),
            const SizedBox(height: 6),
            Text(tr('Imprime la hoja y que viaje con la pieza. Quien la tenga la escanea con la app y avanza la orden según su rol.'),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario)),
          ])),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _trabajando ? null : () => _hoja(compartir: false),
          icon: const Icon(Icons.print_outlined, color: Colors.white, size: 18),
          label: Text(tr('Imprimir hoja de orden'), style: const TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul, minimumSize: const Size(0, 48)))),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: _trabajando ? null : () => _hoja(compartir: true),
          icon: const Icon(Icons.share_outlined, size: 18),
          label: Text(tr('Compartir PDF')),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)))),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrdenScreen(pedidoId: widget.pedidoId))),
          icon: const Icon(Icons.assignment_outlined, size: 18),
          label: Text(tr('Ver la orden')),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)))),
        if (_trabajando) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
      ]));
  }
}

/// Hoja de orden (carta): sin precios, con el QR, las partidas y casillas
/// para firmar cada etapa.
Future<Uint8List> hojaOrdenPdf(OrdenDetalle d) async {
  final p = d.pedido;
  final doc = pw.Document();
  final azul = PdfColor.fromInt(0xFF1a3a5c);
  final gris = PdfColor.fromInt(0xFF6B7280);
  final fecha = DateFormat('dd/MM/yyyy');
  final taller = AuthService.marcaTaller;
  pw.Widget casilla(String t) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(children: [
      pw.Container(width: 12, height: 12, decoration: pw.BoxDecoration(border: pw.Border.all(color: azul, width: 1))),
      pw.SizedBox(width: 8),
      pw.SizedBox(width: 170, child: pw.Text(t, style: const pw.TextStyle(fontSize: 10))),
      pw.Text(_tPdf('Firma: ______________   Fecha: ________'), style: pw.TextStyle(fontSize: 9, color: gris)),
    ]));
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.letter,
    margin: const pw.EdgeInsets.all(32),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(taller, style: pw.TextStyle(fontSize: 12, color: gris)),
          pw.SizedBox(height: 4),
          pw.Text(_tPdf('ORDEN DE TRABAJO'), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: azul)),
          pw.Text(p.folio, style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (p.cliente != null)
            pw.Text('${_tPdf('Cliente')}: ${p.cliente!.nombre}${(p.cliente!.empresa ?? '').isNotEmpty ? ' (${p.cliente!.empresa})' : ''}', style: const pw.TextStyle(fontSize: 11)),
          if (p.createdAt != null) pw.Text('${_tPdf('Fecha del pedido')}: ${fecha.format(p.createdAt!)}', style: const pw.TextStyle(fontSize: 11)),
          if (p.fechaEntregaEstimada != null)
            pw.Text('${_tPdf('Entrega estimada')}: ${fecha.format(p.fechaEntregaEstimada!)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ])),
        pw.Column(children: [
          pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: OrdenService.contenidoQr(p.id!), width: 130, height: 130),
          pw.SizedBox(height: 4),
          pw.Text(_tPdf('Escanéala con la app'), style: pw.TextStyle(fontSize: 8, color: gris)),
        ]),
      ]),
      pw.SizedBox(height: 18),
      pw.Text(_tPdf('QUÉ SE FABRICA'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
      pw.SizedBox(height: 4),
      if (d.partidas.isEmpty)
        pw.Text(_tPdf('Ver la cotización del pedido.'), style: pw.TextStyle(fontSize: 10, color: gris))
      else
        pw.Table(
          border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
          columnWidths: {0: const pw.FixedColumnWidth(50), 1: const pw.FlexColumnWidth()},
          children: [
            pw.TableRow(decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFe6f1fb)), children: [
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(_tPdf('Cant.'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(_tPdf('Pieza o trabajo'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
            ]),
            ...d.partidas.map((it) => pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${it.cantidad}', style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(it.nombre, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                if ((it.descripcion ?? '').trim().isNotEmpty) pw.Text(it.descripcion!.trim(), style: pw.TextStyle(fontSize: 9, color: gris)),
              ])),
            ])),
          ]),
      if ((p.notasInternas ?? '').trim().isNotEmpty) ...[
        pw.SizedBox(height: 12),
        pw.Text(_tPdf('NOTAS DEL TALLER'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
        pw.SizedBox(height: 4),
        pw.Text(p.notasInternas!.trim(), style: const pw.TextStyle(fontSize: 10)),
      ],
      pw.SizedBox(height: 18),
      pw.Text(_tPdf('AVANCE'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: azul)),
      pw.SizedBox(height: 6),
      casilla(_tPdf('Maquinado terminado')),
      casilla(_tPdf('Control de calidad')),
      casilla(_tPdf('Empacado / guía de envío')),
      casilla(_tPdf('Entregado al cliente')),
      pw.Spacer(),
      pw.Text(_tPdf('Al escanear el QR con la app del Cotizador HETNA la orden se actualiza y el cliente ve el avance en su liga.'),
        style: pw.TextStyle(fontSize: 8, color: gris)),
    ])));
  return doc.save();
}

// Los textos del PDF también salen en inglés si la app está en inglés
String _tPdf(String s) => tr(s);

// ══════════════════════════════════════════════════════
// LECTOR
// ══════════════════════════════════════════════════════
class LectorOrdenScreen extends StatefulWidget {
  const LectorOrdenScreen({super.key});
  @override
  State<LectorOrdenScreen> createState() => _LectorOrdenScreenState();
}

class _LectorOrdenScreenState extends State<LectorOrdenScreen> {
  bool _listo = false;
  String? _ultimoMalo;

  void _leido(String? valor) {
    if (_listo || valor == null) return;
    final id = OrdenService.pedidoIdDe(valor);
    if (id == null) {
      if (_ultimoMalo != valor) {
        _ultimoMalo = valor;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Ese QR no es de una orden. Escanea el QR de la hoja de orden.'))));
      }
      return;
    }
    _listo = true;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrdenScreen(pedidoId: id)));
  }

  Future<void> _porFolio() async {
    final ctrl = TextEditingController();
    final folio = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('Buscar por folio')),
      content: TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(hintText: tr('Ej. PED-0012'))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancelar'))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(tr('Buscar'))),
      ]));
    if (folio == null || folio.isEmpty) return;
    try {
      final r = await Supabase.instance.client.from('pedidos').select('id').ilike('folio', folio).limit(1).maybeSingle();
      final id = r?['id'] as String?;
      if (id == null) throw Exception();
      if (!mounted) return;
      _listo = true;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrdenScreen(pedidoId: id)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('No encontré un pedido con ese folio.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white,
        title: Text(tr('Escanear orden')),
        actions: [TextButton.icon(onPressed: _porFolio,
          icon: const Icon(Icons.keyboard_outlined, color: Colors.white, size: 18),
          label: Text(tr('Folio'), style: const TextStyle(color: Colors.white)))]),
      body: Stack(children: [
        MobileScanner(onDetect: (capture) {
          for (final b in capture.barcodes) {
            if (b.rawValue != null) { _leido(b.rawValue); break; }
          }
        }),
        Center(child: Container(width: 250, height: 250,
          decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(16)))),
        Positioned(bottom: 40, left: 24, right: 24, child: Text(
          tr('Apunta al QR de la hoja de orden. ¿No tienes la hoja? Toca "Folio".'),
          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14))),
      ]));
  }
}

// ══════════════════════════════════════════════════════
// LA ORDEN
// ══════════════════════════════════════════════════════
class OrdenScreen extends StatefulWidget {
  final String pedidoId;
  const OrdenScreen({super.key, required this.pedidoId});
  @override
  State<OrdenScreen> createState() => _OrdenScreenState();
}

class _OrdenScreenState extends State<OrdenScreen> {
  OrdenDetalle? _d;
  bool _cargando = true;
  bool _sinSesion = false;
  bool _trabajando = false;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    // Abierta desde la cámara del teléfono (liga del QR): primero la sesión
    if (Supabase.instance.client.auth.currentSession == null) {
      if (mounted) setState(() { _sinSesion = true; _cargando = false; });
      return;
    }
    if (AuthService.negocioId == null) await AuthService.refrescarPerfil();
    OrdenDetalle? d;
    try { d = await OrdenService.cargar(widget.pedidoId); } catch (_) {}
    if (mounted) setState(() { _d = d; _cargando = false; });
  }

  Future<void> _accion(AccionOrden a) async {
    final p = _d!.pedido;
    String? nota;
    if (a.pideGuia) {
      final ok = await _capturarGuia();
      if (ok != true) return;
    } else {
      final notaCtrl = TextEditingController();
      final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(a.etiqueta), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(trf('La orden {0} pasa a "{1}".', [p.folio, tr(OrdenService.etiqueta(a.etapa!))]),
              style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
            const SizedBox(height: 12),
            TextField(controller: notaCtrl, maxLines: 2, decoration: InputDecoration(
              labelText: tr('Nota (opcional)'), hintText: tr('Ej. faltó una pieza, se cambió la fresa…'),
              isDense: true, border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: a.advertencia ? AppColors.rojo : AppColors.verde, minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('Confirmar'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
          ])));
      if (ok != true) return;
      nota = notaCtrl.text;
    }
    setState(() => _trabajando = true);
    try {
      if (a.etapa != null) {
        await OrdenService.mover(p.id!, a.etapa!, nota: nota);
      } else if (a.pideGuia) {
        await OrdenService.registrar(p.id!, p.estado, tr('Guía de envío actualizada'));
      }
      await _cargar();
      if (!mounted) return;
      final puedeAvisar = AuthService.esVendedor && (_d?.pedido.cliente?.whatsappNumero ?? '').isNotEmpty;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('Listo. La liga del cliente ya muestra el avance.')),
        backgroundColor: AppColors.verde,
        action: puedeAvisar ? SnackBarAction(label: tr('Avisar por WhatsApp'), textColor: Colors.white, onPressed: _avisar) : null));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(trf('No se pudo guardar: {0}', [e])), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  static const _paqueterias = ['DHL', 'Estafeta', 'FedEx', 'Paquetexpress', 'UPS', '99 Minutos', 'J&T Express', 'Redpack', 'Castores', 'Tres Guerras', 'Otra'];

  Future<bool?> _capturarGuia() async {
    final p = _d!.pedido;
    String paq = _paqueterias.contains(p.paqueteria) ? p.paqueteria! : ((p.paqueteria ?? '').isEmpty ? 'DHL' : 'Otra');
    final otraCtrl = TextEditingController(text: _paqueterias.contains(p.paqueteria) ? '' : (p.paqueteria ?? ''));
    final guiaCtrl = TextEditingController(text: p.guia ?? '');
    final urlCtrl = TextEditingController(text: p.rastreoUrl ?? '');
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Guía de envío'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('El cliente la ve y la rastrea desde su liga.'), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: paq, isExpanded: true,
            decoration: InputDecoration(labelText: tr('Paquetería'), isDense: true, border: const OutlineInputBorder()),
            items: _paqueterias.map((x) => DropdownMenuItem(value: x, child: Text(x == 'Otra' ? tr('Otra') : x))).toList(),
            onChanged: (v) => setM(() => paq = v ?? 'DHL')),
          if (paq == 'Otra') ...[
            const SizedBox(height: 8),
            TextField(controller: otraCtrl, decoration: InputDecoration(labelText: tr('¿Cuál paquetería?'), isDense: true, border: const OutlineInputBorder())),
          ],
          const SizedBox(height: 8),
          TextField(controller: guiaCtrl, decoration: InputDecoration(labelText: tr('Número de guía'), isDense: true, border: const OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: urlCtrl, keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: tr('Liga de rastreo (opcional)'),
              helperText: tr('Para DHL, FedEx y UPS se arma sola.'), isDense: true, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul, minimumSize: const Size(0, 48)),
            onPressed: () {
              if (guiaCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: Text(tr('Guardar guía'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
        ]))));
    if (ok != true) return false;
    final url = urlCtrl.text.trim();
    if (url.isNotEmpty && !url.startsWith('https://')) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('La liga de rastreo debe empezar con https://'))));
      return false;
    }
    await SupabaseService.guardarGuiaPedido(p.id!,
      paqueteria: paq == 'Otra' ? otraCtrl.text.trim() : paq, guia: guiaCtrl.text, rastreoUrl: url);
    return true;
  }

  Future<void> _avisar() async {
    final p = _d?.pedido;
    if (p == null || p.cliente == null) return;
    var msg = await WhatsAppService.getPlantillaAvance(
      etapa: p.estado, nombreCliente: p.cliente!.nombre, folio: p.folio, montoTotal: p.total, pedidoId: p.id);
    if ((p.guia ?? '').isNotEmpty) msg += trf('\n\n📦 Guía {0}: {1}', [p.paqueteria ?? '', p.guia!]);
    if (p.cotizacionId != null) {
      final liga = await SupabaseService.ligaSeguimiento(p.cotizacionId!);
      if (liga != null) msg += trf('\n\nSigue tu pedido aquí: {0}', [liga]);
    }
    if (mounted) await WhatsAppService.abrirChatConSelector(context, numero: p.cliente!.whatsappNumero, mensaje: msg);
  }

  @override
  Widget build(BuildContext context) {
    final p = _d?.pedido;
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: Text(p == null ? tr('Orden') : trf('Orden {0}', [p.folio])),
        actions: [
          if (p != null) IconButton(tooltip: tr('QR de la orden'), icon: const Icon(Icons.qr_code_2),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QrOrdenScreen(pedidoId: p.id!, folio: p.folio)))),
          IconButton(tooltip: tr('Escanear otra'), icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LectorOrdenScreen()))),
        ]),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : _sinSesion
          ? _mensaje(Icons.lock_outline, tr('Entra con tu cuenta del taller'),
              tr('Esta orden sólo la ve el equipo del taller. Entra a la app y vuelve a escanear el QR.'),
              boton: tr('Entrar'), alTocar: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false))
          : _d == null
            ? _mensaje(Icons.search_off, tr('No encontré esta orden'),
                tr('Puede ser de otro taller o ya no existe. Revisa que hayas entrado con la cuenta del taller correcto.'))
            : RefreshIndicator(onRefresh: _cargar, child: _contenido(_d!)));
  }

  Widget _mensaje(IconData icono, String titulo, String texto, {String? boton, VoidCallback? alTocar}) => Center(
    child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icono, size: 48, color: AppColors.textoSecundario),
      const SizedBox(height: 12),
      Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
      if (boton != null) ...[
        const SizedBox(height: 16),
        ElevatedButton(onPressed: alTocar, child: Text(boton)),
      ],
    ])));

  Widget _tarjeta(String titulo, List<Widget> hijos) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grisBorde)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textoSecundario, letterSpacing: 0.6)),
      const SizedBox(height: 8),
      ...hijos,
    ]));

  Widget _contenido(OrdenDetalle d) {
    final p = d.pedido;
    final fecha = DateFormat('dd/MM/yyyy');
    final hora = DateFormat('dd/MM HH:mm');
    final acciones = OrdenService.accionesPara(p);
    final idx = _ordenEtapas.indexOf(p.estado == 'Pago' ? 'Pago50' : p.estado);
    final verCliente = AuthService.esVendedor || AuthService.esContador || AuthService.esAlmacenista;
    return ListView(padding: const EdgeInsets.all(14), children: [
      // Encabezado
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _color(p.estado), width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(p.folio, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.azul))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _color(p.estado), borderRadius: BorderRadius.circular(20)),
              child: Text(tr(OrdenService.etiqueta(p.estado)), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          ]),
          if (p.cliente != null) ...[
            const SizedBox(height: 4),
            Text([p.cliente!.nombre, if ((p.cliente!.empresa ?? '').isNotEmpty) p.cliente!.empresa!].join(' · '),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
          if (p.fechaEntregaEstimada != null) ...[
            const SizedBox(height: 4),
            Text(trf('Entrega estimada: {0}', [fecha.format(p.fechaEntregaEstimada!)]),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: p.fechaEntregaEstimada!.isBefore(DateTime.now()) && p.estado != 'Entregado' ? AppColors.rojo : AppColors.textoSecundario)),
          ],
          const SizedBox(height: 12),
          // Línea de etapas
          if (p.estado != 'Cancelado') Row(children: List.generate(_ordenEtapas.length, (i) => Expanded(child: Container(
            height: 6, margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(color: i <= idx ? _color(p.estado) : AppColors.grisBorde, borderRadius: BorderRadius.circular(3)))))),
        ])),
      // Lo que puedo hacer
      _tarjeta(trf('Lo que puedes hacer ({0})', [tr(OrdenService.rolLegible(AuthService.rol))]), [
        if (acciones.isEmpty)
          Text(p.estado == 'Entregado' ? tr('Esta orden ya se entregó.') : p.estado == 'Cancelado' ? tr('Esta orden está cancelada.')
            : tr('En esta etapa tu rol sólo puede ver la orden.'), style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
        ...acciones.map((a) => Padding(padding: const EdgeInsets.only(bottom: 8), child: SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _trabajando ? null : () => _accion(a),
            icon: Icon(a.pideGuia ? Icons.local_shipping_outlined : a.advertencia ? Icons.undo : Icons.check_circle_outline, color: Colors.white, size: 18),
            label: Text(tr(a.etiqueta), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52),
              backgroundColor: a.advertencia ? AppColors.rojo : a.pideGuia ? AppColors.azul : AppColors.verde))))),
      ]),
      // Qué se fabrica
      _tarjeta(tr('Qué se fabrica'), [
        if (d.partidas.isEmpty) Text(tr('Este pedido no tiene partidas guardadas.'), style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
        ...d.partidas.map((it) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 34, padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(6)),
            child: Text('${it.cantidad}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.azul))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(it.nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            if ((it.descripcion ?? '').trim().isNotEmpty)
              Text(it.descripcion!.trim(), style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario)),
          ])),
        ]))),
        if ((p.notasInternas ?? '').trim().isNotEmpty) ...[
          const Divider(),
          Text(tr('Notas del taller'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          Text(p.notasInternas!.trim(), style: const TextStyle(fontSize: 13)),
        ],
      ]),
      // Envío
      if ((p.guia ?? '').isNotEmpty || verCliente) _tarjeta(tr('Envío'), [
        if ((p.guia ?? '').isEmpty) Text(tr('Todavía sin guía.'), style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario))
        else Text([if ((p.paqueteria ?? '').isNotEmpty) p.paqueteria!, trf('Guía {0}', [p.guia!])].join(' · '),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        if (AuthService.esVendedor && (p.cliente?.whatsappNumero ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _avisar,
            icon: const Icon(Icons.chat, size: 16, color: AppColors.whatsapp),
            label: Text(tr('Avisar al cliente por WhatsApp'))),
        ],
      ]),
      // Historial
      _tarjeta(tr('Historial'), [
        if (d.avances.isEmpty) Text(tr('Sin movimientos todavía.'), style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
        ...d.avances.map((a) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: _color(a.etapa), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(OrdenService.etiqueta(a.etapa)), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            Text([
              if (a.fecha != null) hora.format(a.fecha!),
              if ((a.quien ?? '').isNotEmpty) a.quien!,
              if ((a.rol ?? '').isNotEmpty) tr(OrdenService.rolLegible(a.rol)),
            ].join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            if ((a.descripcion ?? '').isNotEmpty) Text(a.descripcion!, style: const TextStyle(fontSize: 12.5)),
          ])),
        ]))),
      ]),
    ]);
  }
}
