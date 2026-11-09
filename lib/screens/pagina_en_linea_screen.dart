// lib/screens/pagina_en_linea_screen.dart
// Cotizador 2.0 · Fase 3 — "Tu cotizador en línea": la página pública del
// taller en hetnacnc.com/t/<liga>. El cliente sube su archivo, ve un precio
// estimado con las tarifas del simulador y manda su solicitud, que llega a
// Cotizar como borrador con su archivo.
// Aquí el administrador la prende, elige la liga, los servicios y si muestra
// precio; la comparte (WhatsApp, copiar, QR, cartel para imprimir) y ve las
// solicitudes que le han llegado.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/hetna_api.dart';
import '../services/pdf_service.dart';
import '../services/supabase_service.dart';
import '../i18n/tr.dart';

class PaginaEnLineaScreen extends StatefulWidget {
  const PaginaEnLineaScreen({super.key});
  @override
  State<PaginaEnLineaScreen> createState() => _PaginaEnLineaScreenState();
}

class _PaginaEnLineaScreenState extends State<PaginaEnLineaScreen> {
  Map<String, dynamic>? _datos;
  List<Map<String, dynamic>> _solicitudes = [];
  String? _error;
  bool _cargando = true;
  bool _guardando = false;

  final _slug = TextEditingController();
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _ciudad = TextEditingController();
  bool _activa = false;
  bool _mostrarPrecio = true;
  bool _enDirectorio = true;
  Set<String> _servicios = {};

  String? get _token => AuthService.sesion?.accessToken;
  String? get _url => _datos?['url'] as String?;

  @override
  void initState() { super.initState(); _cargar(); }

  @override
  void dispose() {
    _slug.dispose(); _titulo.dispose(); _descripcion.dispose(); _ciudad.dispose();
    super.dispose();
  }

  void _llenar(Map<String, dynamic> d) {
    final p = Map<String, dynamic>.from((d['pagina'] as Map?) ?? {});
    _slug.text = d['slug'] as String? ?? '';
    _titulo.text = p['titulo'] as String? ?? '';
    _descripcion.text = p['descripcion'] as String? ?? '';
    _ciudad.text = p['ciudad'] as String? ?? '';
    _activa = p['activa'] == true;
    _mostrarPrecio = p['mostrar_precio'] != false;
    _enDirectorio = p['en_directorio'] != false;
    _servicios = ((p['servicios'] as List?) ?? []).map((e) => e.toString()).toSet();
  }

  Future<void> _cargar() async {
    final token = _token;
    if (token == null) return;
    setState(() { _cargando = true; _error = null; });
    try {
      final r = await Future.wait([PaginaApi.leer(token), SupabaseService.getSolicitudesEnLinea()]);
      if (!mounted) return;
      setState(() {
        _datos = r[0] as Map<String, dynamic>;
        _solicitudes = r[1] as List<Map<String, dynamic>>;
        _llenar(_datos!);
        _cargando = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  Future<void> _guardar({bool? activa}) async {
    final token = _token;
    if (token == null) return;
    setState(() => _guardando = true);
    try {
      final d = await PaginaApi.guardar(token, {
        if (activa != null) 'activa': activa else 'activa': _activa,
        'slug': _slug.text.trim(),
        'titulo': _titulo.text.trim(),
        'descripcion': _descripcion.text.trim(),
        'ciudad': _ciudad.text.trim(),
        'servicios': _servicios.toList(),
        'mostrar_precio': _mostrarPrecio,
        'en_directorio': _enDirectorio,
      });
      if (!mounted) return;
      setState(() { _datos = d; _llenar(d); });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_activa ? tr('✅ Tu cotizador en línea está activo') : tr('✅ Guardado')),
        backgroundColor: AppColors.verde));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String _mensajeCompartir() => trf(
    'Cotiza tu trabajo con *{0}* en línea: sube tu archivo (DXF, SVG o STL) y ve el precio al momento 👉 {1}',
    [AuthService.marcaTaller, _url ?? '']);

  Future<void> _imprimirCartel() async {
    final url = _url;
    if (url == null) return;
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.letter,
      build: (_) => pw.Center(child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.Text(AuthService.marcaTaller, style: pw.TextStyle(fontSize: 34, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text(tr('Cotiza en línea'), style: const pw.TextStyle(fontSize: 22)),
        pw.SizedBox(height: 6),
        pw.Text(tr('Escanea, sube tu archivo y ve el precio al momento'), style: const pw.TextStyle(fontSize: 14)),
        pw.SizedBox(height: 24),
        pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: url, width: 260, height: 260),
        pw.SizedBox(height: 18),
        pw.Text(url.replaceFirst('https://', ''), style: const pw.TextStyle(fontSize: 14)),
      ]))));
    await PdfService.verPdf(await doc.save());
  }

  Future<void> _abrirArchivo(Map<String, dynamic> s) async {
    final ruta = s['archivo_ruta'] as String?;
    if (ruta == null) return;
    final url = await SupabaseService.urlArchivoSolicitud(ruta);
    if (url == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('No se pudo abrir el archivo.'))));
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Solicitudes que no se volvieron cotización (sin cupo en su momento)
  Future<void> _convertir(Map<String, dynamic> s) async {
    try {
      final cot = await SupabaseService.cotizacionDesdeSolicitud(s);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(trf('✅ Cotización {0} creada: búscala en Cotizar.', [cot.folio ?? ''])),
        backgroundColor: AppColors.verde));
      _cargar();
    } catch (e) {
      if (!mounted) return;
      if (SupabaseService.esErrorSinCupo(e)) {
        await AuthService.exigirModulo(context, 'cotizaciones_ilimitadas', funcion: tr('más cotizaciones al mes'));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: Text(tr('Tu cotizador en línea'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white, elevation: 0),
      body: !AuthService.esAdmin
        ? _centro(tr('Solo el administrador del taller puede configurar la página.'))
        : _cargando && _datos == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _datos == null
            ? _centro(_error!, accion: TextButton(onPressed: _cargar, child: Text(tr('Reintentar'))))
            : RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [
                _encabezado(),
                const SizedBox(height: 12),
                if (_datos?['tabla_lista'] == false)
                  _aviso(tr('Falta activar esta función en el servidor (supabase/cotizador_en_linea.sql). Avísale a HETNA.')),
                if (_activa && _url != null) ...[_compartir(), const SizedBox(height: 12)],
                _ajustes(),
                const SizedBox(height: 12),
                _listaSolicitudes(),
                const SizedBox(height: 30),
              ])));
  }

  Widget _encabezado() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF1a3a5c), Color(0xFF185fa5)]),
      borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.public, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(tr('Que te lleguen clientes solos'),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
        Switch(value: _activa, activeColor: Colors.white, activeTrackColor: AppColors.verde,
          onChanged: _guardando ? null : (v) { setState(() => _activa = v); _guardar(activa: v); }),
      ]),
      const SizedBox(height: 4),
      Text(tr('Tu página en hetnacnc.com: el cliente sube su archivo, ve un precio estimado con tus tarifas del simulador y te manda la solicitud. Te llega aquí como cotización en borrador, con el archivo, y te avisa.'),
        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, height: 1.35)),
    ]));

  Widget _compartir() {
    final url = _url!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Comparte tu página'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(color: Colors.white, padding: const EdgeInsets.all(4),
            child: QrImageView(data: url, size: 112, padding: EdgeInsets.zero)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SelectableText(url, style: const TextStyle(fontSize: 12, color: AppColors.azul)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _botonChico(Icons.copy, tr('Copiar'), () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Liga copiada'))));
              }),
              _botonChico(Icons.chat, tr('WhatsApp'), () => launchUrl(
                Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_mensajeCompartir())}'), mode: LaunchMode.externalApplication)),
              _botonChico(Icons.open_in_new, tr('Ver'), () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)),
              _botonChico(Icons.print_outlined, tr('Cartel con QR'), _imprimirCartel),
            ]),
          ])),
        ]),
        const SizedBox(height: 8),
        Text(tr('Ponla en tu estado y perfil de WhatsApp, Instagram, Facebook, Google Maps y en tu tarjeta. El cartel con QR es para tu mostrador.'),
          style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      ]));
  }

  Widget _botonChico(IconData icono, String texto, VoidCallback alTocar) => OutlinedButton.icon(
    onPressed: alTocar,
    icon: Icon(icono, size: 14),
    label: Text(texto, style: const TextStyle(fontSize: 11.5)),
    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 10),
      foregroundColor: AppColors.azul, side: const BorderSide(color: AppColors.grisBorde)));

  Widget _ajustes() {
    final servicios = ((_datos?['servicios'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    InputDecoration dec(String l, {String? h, String? pre}) => InputDecoration(labelText: l, helperText: h, helperMaxLines: 3,
      prefixText: pre, isDense: true, filled: true, fillColor: Colors.white, border: const OutlineInputBorder());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Cómo se ve tu página'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        TextField(controller: _slug, decoration: dec(tr('Tu liga'), pre: 'hetnacnc.com/t/',
          h: tr('Corta y fácil de recordar: solo letras, números y guiones.'))),
        const SizedBox(height: 10),
        TextField(controller: _titulo, maxLength: 80, decoration: dec(tr('Nombre que verán tus clientes'), h: tr('Vacío = el nombre de tu taller.'))),
        const SizedBox(height: 4),
        TextField(controller: _descripcion, maxLength: 400, maxLines: 3, minLines: 2,
          decoration: dec(tr('Qué haces (2 o 3 renglones)'), h: tr('Ej.: Corte láser y router en MDF y acrílico. Entregas en 48 h. Envíos a todo México.'))),
        const SizedBox(height: 4),
        TextField(controller: _ciudad, maxLength: 60, decoration: dec(tr('Ciudad'))),
        const SizedBox(height: 6),
        Text(tr('Servicios que cotizas en línea'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        Text(tr('Salen de tu simulador. Si no marcas ninguno, se muestran todos.'),
          style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        const SizedBox(height: 4),
        if (servicios.isEmpty)
          Text(tr('Todavía no tienes servicios en el simulador. Configúralos en Simular para que tus clientes vean precio.'),
            style: const TextStyle(fontSize: 12, color: AppColors.ambar))
        else
          Wrap(spacing: 6, runSpacing: 4, children: servicios.map((s) {
            final id = s['id'] as String;
            final sel = _servicios.contains(id);
            return FilterChip(
              selected: sel,
              label: Text('${s['emoji'] ?? ''} ${s['nombre'] ?? ''}', style: const TextStyle(fontSize: 12)),
              onSelected: (v) => setState(() => v ? _servicios.add(id) : _servicios.remove(id)));
          }).toList()),
        const SizedBox(height: 8),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: _mostrarPrecio, onChanged: (v) => setState(() => _mostrarPrecio = v),
          title: Text(tr('Mostrar precio estimado'), style: const TextStyle(fontSize: 13)),
          subtitle: Text(tr('Con tus tarifas y costos del simulador. Apágalo si prefieres mandar tú el precio.'),
            style: const TextStyle(fontSize: 11))),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: _enDirectorio, onChanged: (v) => setState(() => _enDirectorio = v),
          title: Text(tr('Aparecer en el directorio de talleres de HETNA'), style: const TextStyle(fontSize: 13)),
          subtitle: Text('hetnacnc.com/t', style: const TextStyle(fontSize: 11))),
        const SizedBox(height: 6),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _guardando ? null : () => _guardar(),
          child: _guardando
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(tr('Guardar')))),
      ]));
  }

  Widget _listaSolicitudes() {
    final fmt = DateFormat(enIngles ? 'MM/dd HH:mm' : 'dd/MM HH:mm');
    final dinero = NumberFormat('\$#,##0', 'es_MX');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('SOLICITUDES RECIBIDAS'), style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario,
        letterSpacing: 1, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (_solicitudes.isEmpty)
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Text(tr('Todavía no llegan solicitudes. Comparte tu liga y aparecerán aquí y en Cotizar.'),
            style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)))
      else
        ..._solicitudes.map((s) {
          final estado = s['estado'] as String? ?? 'nueva';
          final sinCot = s['cotizacion_id'] == null;
          final creado = DateTime.tryParse(s['creado'] as String? ?? '')?.toLocal();
          final estimado = (s['estimado'] as num?)?.toDouble();
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: estado == 'sin_cupo' ? AppColors.ambar : AppColors.grisBorde, width: estado == 'sin_cupo' ? 1 : 0.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(s['nombre'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                if (creado != null) Text(fmt.format(creado), style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
              ]),
              Text([
                if ((s['servicio'] as String?)?.isNotEmpty == true) '${s['servicio']} · ${s['tipo'] ?? ''}',
                trf('{0} pza', [s['cantidad'] ?? 1]),
                if (estimado != null && estimado > 0) trf('estimado {0}', [dinero.format(estimado)]),
              ].join(' · '), style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario)),
              if ((s['telefono'] as String?)?.isNotEmpty == true || (s['correo'] as String?)?.isNotEmpty == true)
                Text([s['telefono'], s['correo']].where((x) => (x as String?)?.isNotEmpty == true).join(' · '),
                  style: const TextStyle(fontSize: 11.5)),
              if (estado == 'sin_cupo' && sinCot)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('Llegó cuando ya no tenías cotizaciones en tu plan.'),
                  style: const TextStyle(fontSize: 11, color: AppColors.ambar, fontWeight: FontWeight.w600))),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (s['archivo_ruta'] != null) _botonChico(Icons.attach_file, tr('Archivo'), () => _abrirArchivo(s)),
                if (sinCot) _botonChico(Icons.note_add_outlined, tr('Crear cotización'), () => _convertir(s))
                else Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.verdeClaro, borderRadius: BorderRadius.circular(20)),
                  child: Text(tr('Ya está en Cotizar'), style: const TextStyle(fontSize: 11, color: AppColors.verde, fontWeight: FontWeight.w700))),
              ]),
            ]));
        }),
    ]);
  }

  Widget _aviso(String t) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(10)),
    child: Text(t, style: const TextStyle(fontSize: 12)));

  Widget _centro(String t, {Widget? accion}) => Center(child: Padding(padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(t, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textoSecundario)),
      if (accion != null) accion,
    ])));
}
