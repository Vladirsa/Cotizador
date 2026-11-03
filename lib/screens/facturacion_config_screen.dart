// ============================================
// lib/screens/facturacion_config_screen.dart
// Cotizador 2.0 · Fase 4 — Factura electrónica CFDI 4.0
//
// El taller captura sus datos fiscales y sube su CSD (.cer, .key y
// contraseña). HETNA lo da de alta en Facturapi como una "organización"
// suya; la app nunca guarda llaves. Facturas incluidas por plan: Taller 30
// al mes, Pro 150, Industrial sin límite (las extra se cobran a fin de mes).
// ============================================
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../i18n/tr.dart';
import '../services/auth_service.dart';
import '../services/hetna_api.dart';
import '../services/pdf_service.dart';
import '../services/supabase_service.dart';

class FacturacionConfigScreen extends StatefulWidget {
  const FacturacionConfigScreen({super.key});

  @override
  State<FacturacionConfigScreen> createState() => _FacturacionConfigScreenState();
}

class _FacturacionConfigScreenState extends State<FacturacionConfigScreen> {
  bool _cargando = true;
  bool _guardando = false;
  bool _subiendo = false;
  String? _error;
  Map<String, dynamic> _estado = {};
  List<Map<String, dynamic>> _facturas = [];

  final _razonCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();
  final _serieCtrl = TextEditingController(text: 'A');
  final _claveProdCtrl = TextEditingController(text: '01010101');
  final _claveUnidadCtrl = TextEditingController(text: 'E48');
  final _passCtrl = TextEditingController();
  String? _regimen;
  bool _verPass = false;

  Uint8List? _cer;
  String? _nombreCer;
  Uint8List? _key;
  String? _nombreKey;

  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);

  String? get _token => AuthService.sesion?.accessToken;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _razonCtrl.dispose(); _cpCtrl.dispose(); _serieCtrl.dispose();
    _claveProdCtrl.dispose(); _claveUnidadCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final token = _token;
    if (token == null) {
      setState(() { _cargando = false; _error = tr('Vuelve a iniciar sesión.'); });
      return;
    }
    setState(() { _cargando = true; _error = null; });
    try {
      final r = await Future.wait([FacturaApi.estado(token), SupabaseService.getCfdiEmitidos(limite: 30)]);
      final e = r[0] as Map<String, dynamic>;
      final datos = (e['datos'] as Map?)?.cast<String, dynamic>() ?? {};
      _razonCtrl.text = (datos['razon_social'] ?? _razonCtrl.text).toString();
      _cpCtrl.text = (datos['cp'] ?? _cpCtrl.text).toString();
      _serieCtrl.text = (datos['serie'] ?? 'A').toString();
      _claveProdCtrl.text = (datos['clave_producto'] ?? '01010101').toString();
      _claveUnidadCtrl.text = (datos['clave_unidad'] ?? 'E48').toString();
      final reg = (datos['regimen'] ?? '').toString();
      if (reg.isNotEmpty) _regimen = reg;
      setState(() { _estado = e; _facturas = r[1] as List<Map<String, dynamic>>; _cargando = false; });
    } catch (e) {
      setState(() { _cargando = false; _error = e.toString(); });
    }
  }

  void _aviso(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: error ? AppColors.rojo : AppColors.verde));
  }

  Future<void> _guardarDatos() async {
    final token = _token;
    if (token == null) return;
    if (_razonCtrl.text.trim().isEmpty || _regimen == null || _cpCtrl.text.trim().length != 5) {
      _aviso(tr('Llena razón social, régimen y código postal (5 dígitos).'), error: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      final e = await FacturaApi.guardarDatos(token, {
        'razon_social': _razonCtrl.text.trim(),
        'regimen': _regimen,
        'cp': _cpCtrl.text.trim(),
        'serie': _serieCtrl.text.trim().toUpperCase(),
        'clave_producto': _claveProdCtrl.text.trim(),
        'clave_unidad': _claveUnidadCtrl.text.trim().toUpperCase(),
      });
      setState(() => _estado = e);
      _aviso(tr('✅ Datos fiscales guardados'));
    } catch (e) {
      _aviso(e.toString(), error: true);
    }
    if (mounted) setState(() => _guardando = false);
  }

  Future<void> _elegir(String ext) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    final f = r?.files.single;
    if (f == null || f.bytes == null) return;
    if (!f.name.toLowerCase().endsWith('.$ext')) {
      _aviso(trf('Ese archivo no termina en .{0}', [ext]), error: true);
      return;
    }
    setState(() {
      if (ext == 'cer') { _cer = f.bytes; _nombreCer = f.name; } else { _key = f.bytes; _nombreKey = f.name; }
    });
  }

  Future<void> _subirCsd() async {
    final token = _token;
    if (token == null) return;
    if (_cer == null || _key == null || _passCtrl.text.isEmpty) {
      _aviso(tr('Elige el .cer, el .key y escribe la contraseña del CSD.'), error: true);
      return;
    }
    setState(() => _subiendo = true);
    try {
      final e = await FacturaApi.subirCsd(token,
        cer: _cer!, nombreCer: _nombreCer!, key: _key!, nombreKey: _nombreKey!, password: _passCtrl.text);
      _passCtrl.clear();
      setState(() { _estado = e; _cer = null; _key = null; _nombreCer = null; _nombreKey = null; });
      _aviso(tr('✅ CSD cargado. Ya puedes facturar.'));
    } catch (e) {
      _aviso(e.toString(), error: true);
    }
    if (mounted) setState(() => _subiendo = false);
  }

  Future<void> _verFactura(Map<String, dynamic> f) async {
    final token = _token;
    if (token == null) return;
    try {
      final bytes = await FacturaApi.archivo(token, f['id'].toString(), 'pdf');
      await PdfService.verPdf(bytes);
    } catch (e) {
      _aviso(e.toString(), error: true);
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: Text(tr('Factura electrónica'))),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _cargar, child: ListView(
            padding: const EdgeInsets.all(16),
            children: _error != null
              ? [_caja(color: AppColors.rojoClaro, child: Text(_error!, style: const TextStyle(color: AppColors.rojo)))]
              : [
                  _resumen(),
                  const SizedBox(height: 14),
                  if (_estado['plan_permite'] == true && _estado['disponible'] == true) ...[
                    _titulo(tr('1. Tus datos fiscales')),
                    _datosFiscales(),
                    const SizedBox(height: 14),
                    _titulo(tr('2. Tu CSD (sello digital)')),
                    _csd(),
                    const SizedBox(height: 14),
                  ],
                  _guiaSat(),
                  const SizedBox(height: 14),
                  if (_facturas.isNotEmpty) ...[
                    _titulo(tr('Facturas recientes')),
                    ..._facturas.map(_filaFactura),
                  ],
                  const SizedBox(height: 30),
                ])));
  }

  Widget _titulo(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)));

  Widget _caja({required Widget child, Color color = Colors.white}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: child);

  Widget _resumen() {
    final disponible = _estado['disponible'] == true;
    final permite = _estado['plan_permite'] == true;
    final listo = _estado['listo'] == true;
    final prueba = _estado['modo'] != 'real';
    final cupo = (_estado['cupo'] as Map?)?.cast<String, dynamic>() ?? {};
    final incluidas = cupo['incluidas'];
    final usadas = (cupo['usadas'] ?? 0) as num;
    final extra = (cupo['precio_extra'] ?? 2) as num;
    final pendientes = ((_estado['pendientes'] as List?) ?? []).map((e) => e.toString()).toList();

    return _caja(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(listo ? Icons.verified_outlined : Icons.receipt_long_outlined,
          color: listo ? AppColors.verde : AppColors.azul, size: 22),
        const SizedBox(width: 8),
        Expanded(child: Text(
          !permite ? tr('Disponible desde el plan Taller')
            : listo ? tr('Listo para facturar') : tr('Falta configurar'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        if (disponible && prueba) Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(20)),
          child: Text(tr('Modo prueba'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.naranja))),
      ]),
      const SizedBox(height: 8),
      if (!permite) ...[
        Text(tr('Timbra tus facturas CFDI 4.0 desde cada pedido: Taller 30 al mes, Pro 150, Industrial sin límite.'),
          style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: () => AuthService.exigirModulo(context, 'facturacion', funcion: tr('Facturación (CFDI)')),
          child: Text(tr('Ver planes'))),
      ] else ...[
        Text(incluidas == null
            ? trf('Este mes: {0} facturas (sin límite en tu plan)', [usadas.toInt()])
            : trf('Este mes: {0} de {1} facturas incluidas', [usadas.toInt(), incluidas]),
          style: const TextStyle(fontSize: 12)),
        if (incluidas != null) Padding(padding: const EdgeInsets.only(top: 2),
          child: Text(trf('Después de esas, cada factura cuesta {0} y se suma a tu cargo del día 1.', [_fmt.format(extra)]),
            style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
        if (disponible && prueba) Padding(padding: const EdgeInsets.only(top: 6),
          child: Text(tr('En modo prueba las facturas no tienen validez ante el SAT ni cuentan para tu cupo. Sirven para que veas cómo quedan.'),
            style: const TextStyle(fontSize: 11, color: AppColors.naranja))),
        if (pendientes.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...pendientes.map((p) => Padding(padding: const EdgeInsets.only(top: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('•  ', style: TextStyle(fontSize: 12)),
              Expanded(child: Text(tr(p), style: const TextStyle(fontSize: 12))),
            ]))),
        ],
      ],
    ]));
  }

  Widget _campo(TextEditingController c, String etiqueta, {String? hint, TextInputType? tipo, bool mayus = false, int? max}) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(
      controller: c, keyboardType: tipo, maxLength: max,
      textCapitalization: mayus ? TextCapitalization.characters : TextCapitalization.none,
      decoration: InputDecoration(labelText: etiqueta, hintText: hint, isDense: true, counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))));

  Widget _datosFiscales() {
    final regimenes = ((_estado['regimenes'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), v.toString()));
    if (_regimen != null && !regimenes.containsKey(_regimen)) _regimen = null;
    final datos = (_estado['datos'] as Map?) ?? {};
    final rfc = (datos['rfc'] ?? '').toString();
    return _caja(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('Cópialos tal cual de tu Constancia de Situación Fiscal (la descargas en sat.gob.mx).'),
        style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      const SizedBox(height: 10),
      _campo(_razonCtrl, tr('Razón social o nombre'), hint: tr('Sin "S.A. de C.V." al final'), mayus: true),
      Padding(padding: const EdgeInsets.only(bottom: 10), child: DropdownButtonFormField<String>(
        value: _regimen, isExpanded: true,
        decoration: InputDecoration(labelText: tr('Régimen fiscal'), isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        items: regimenes.entries.map((e) => DropdownMenuItem(value: e.key,
          child: Text('${e.key} · ${tr(e.value)}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => _regimen = v))),
      _campo(_cpCtrl, tr('Código postal fiscal'), hint: '90300', tipo: TextInputType.number, max: 5),
      if (rfc.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10),
        child: Text(trf('RFC: {0} (lo toma del CSD)', [rfc]), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
      Theme(data: Theme.of(context).copyWith(dividerColor: Colors.transparent), child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(tr('Opciones avanzadas'), style: const TextStyle(fontSize: 12)),
        children: [
          _campo(_serieCtrl, tr('Serie de tus facturas'), hint: 'A', mayus: true, max: 10),
          _campo(_claveProdCtrl, tr('Clave de producto SAT'), hint: '01010101', tipo: TextInputType.number, max: 8),
          _campo(_claveUnidadCtrl, tr('Clave de unidad SAT'), hint: 'E48 = servicio, H87 = pieza', mayus: true, max: 3),
          Text(tr('Si no sabes cuáles usar, déjalas así: 01010101 y E48 sirven para servicios de maquinado.'),
            style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          const SizedBox(height: 8),
        ])),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _guardando ? null : _guardarDatos,
        icon: _guardando
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.save_outlined, size: 16),
        label: Text(tr('Guardar datos fiscales')))),
    ]));
  }

  Widget _botonArchivo(String ext, String? nombre) => Expanded(child: OutlinedButton.icon(
    onPressed: () => _elegir(ext),
    icon: Icon(nombre == null ? Icons.upload_file : Icons.check_circle, size: 16,
      color: nombre == null ? AppColors.azul : AppColors.verde),
    label: Text(nombre ?? trf('Elegir .{0}', [ext]), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))));

  Widget _csd() {
    final configurado = _estado['configurado'] == true;
    final vence = DateTime.tryParse('${((_estado['datos'] as Map?) ?? {})['csd_vence'] ?? ''}');
    return _caja(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (vence != null) Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.verdeClaro, borderRadius: BorderRadius.circular(8)),
        child: Text(trf('✅ CSD cargado. Vence el {0}.', [DateFormat('dd/MM/yyyy').format(vence.toLocal())]),
          style: const TextStyle(fontSize: 12, color: AppColors.verde, fontWeight: FontWeight.w600))),
      if (!configurado) Text(tr('Primero guarda tus datos fiscales.'), style: const TextStyle(fontSize: 12, color: AppColors.naranja))
      else ...[
        Text(vence == null
            ? tr('Sube los dos archivos de tu Certificado de Sello Digital y su contraseña.')
            : tr('Si renovaste tu CSD, sube los archivos nuevos aquí.'),
          style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        const SizedBox(height: 10),
        Row(children: [_botonArchivo('cer', _nombreCer), const SizedBox(width: 8), _botonArchivo('key', _nombreKey)]),
        const SizedBox(height: 10),
        TextField(controller: _passCtrl, obscureText: !_verPass,
          decoration: InputDecoration(labelText: tr('Contraseña del CSD'), isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility, size: 18),
              onPressed: () => setState(() => _verPass = !_verPass)))),
        const SizedBox(height: 6),
        Text(tr('Tus archivos viajan cifrados directo al timbrado; HETNA no guarda la contraseña.'),
          style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _subiendo ? null : _subirCsd,
          icon: _subiendo
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.lock_outline, size: 16),
          label: Text(tr('Subir CSD')))),
      ],
    ]));
  }

  Widget _guiaSat() {
    final pasos = [
      tr('Necesitas tu e.firma vigente (la que usas en el SAT). El CSD es otro certificado, sólo para facturar.'),
      tr('Descarga el programa Certifica del SAT y ábrelo. Elige "Solicitud de Certificado de Sello Digital".'),
      tr('Llénalo con tu e.firma y pon una contraseña nueva: ésa será la contraseña del CSD. Te genera un .key y un .sdg.'),
      tr('Entra a CertiSAT Web con tu e.firma, envía el archivo .sdg y descarga tu certificado (.cer).'),
      tr('Aquí sube el .cer, el .key y la contraseña que pusiste en Certifica. No uses los archivos de tu e.firma.'),
    ];
    return _caja(child: Theme(data: Theme.of(context).copyWith(dividerColor: Colors.transparent), child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.help_outline, color: AppColors.azul),
      title: Text(tr('¿Cómo saco mi CSD en el SAT?'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      children: [
        for (var i = 0; i < pasos.length; i++) Padding(padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 10, backgroundColor: AppColors.azul,
              child: Text('${i + 1}', style: const TextStyle(fontSize: 10, color: Colors.white))),
            const SizedBox(width: 8),
            Expanded(child: Text(pasos[i], style: const TextStyle(fontSize: 12))),
          ])),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: () => launchUrl(Uri.parse('https://www.sat.gob.mx/portal/public/tramites/certificado-de-sello-digital'),
            mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_new, size: 14),
          label: Text(tr('Abrir el trámite en el SAT')))),
      ])));
  }

  Widget _filaFactura(Map<String, dynamic> f) {
    final cancelada = f['estado'] == 'cancelada';
    final pendiente = f['estado'] == 'cancelacion_pendiente';
    final fecha = DateTime.tryParse('${f['creado'] ?? ''}');
    final folio = '${f['serie'] ?? ''}${f['folio'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: ListTile(
        dense: true,
        onTap: () => _verFactura(f),
        leading: Icon(Icons.description_outlined, color: cancelada ? AppColors.textoSecundario : AppColors.azul),
        title: Text('${folio.isEmpty ? tr('Factura') : folio} · ${f['receptor_nombre'] ?? ''}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            decoration: cancelada ? TextDecoration.lineThrough : null)),
        subtitle: Text([
          if (fecha != null) DateFormat('dd/MM/yyyy').format(fecha.toLocal()),
          if (f['modo'] == 'prueba') tr('prueba'),
          if (cancelada) tr('cancelada'),
          if (pendiente) tr('cancelación pendiente'),
          if (f['extra'] == true) tr('extra'),
        ].join(' · '), style: const TextStyle(fontSize: 11)),
        trailing: Text(_fmt.format((f['total'] ?? 0) as num), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ));
  }
}
