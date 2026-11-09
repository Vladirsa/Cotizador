// lib/simulador2/simulador2_screen.dart
// HETNA CNC — Simulador 2.0: se llena en 5 campos (pieza, máquina, material,
// cantidad, acabado) y todo lo demás sale de los datos del taller. Un solo
// precio con deslizador de margen; el desglose, el anidado, el precio por
// volumen y "ya cotizaste algo parecido" van abajo, plegados.
// Fórmula y anidado: motor.dart. Datos: simulador2_data.dart.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../i18n/tr.dart';
import '../services/archivo_cad_service.dart';
import '../screens/cotizar_screen.dart';
import '../screens/simulador_screen.dart' show SimuladorScreen;
import 'motor.dart';
import 'simulador2_data.dart';
import 'velocidades_hetna.dart';
import 'visor_pieza.dart';
import 'config_maquina_sheet.dart';
import 'capacidad.dart';

class Simulador2Screen extends StatefulWidget {
  // geoInicial: pieza ya leída (desde la cotización). seleccionar: al pasar a
  // cotización se regresa la Partida2 a quien abrió la pantalla.
  final GeoCad? geoInicial;
  final bool seleccionar;
  const Simulador2Screen({super.key, this.geoInicial, this.seleccionar = false});
  @override
  State<Simulador2Screen> createState() => _Simulador2ScreenState();
}

class _Simulador2ScreenState extends State<Simulador2Screen> {
  final _fmt = NumberFormat(r'$#,##0', 'es_MX');
  final _fmt2 = NumberFormat(r'$#,##0.00', 'es_MX');
  bool _cargando = true;

  // Datos del taller
  List<Maquina2> _maquinas = [];
  List<Material2> _materiales = [];
  List<Acabado2> _acabados = [];
  Taller2 _taller = const Taller2();

  // Los 5 campos
  GeoCad? _geo;
  Pieza2? _pieza;
  bool _aMano = false;
  final _largoC = TextEditingController(), _anchoC = TextEditingController(), _altoC = TextEditingController();
  String _complejidad = 'normal';
  String _tipo = 'router'; // tipo de máquina/servicio elegido (chips)
  Maquina2? _maq;
  Servicio2 _servicio = Servicio2.corte2D;

  // Si el taller no tiene máquina de ese tipo, se cotiza con una de referencia
  // HETNA ($/h típico en México) para que todos los servicios estén siempre.
  static const _costoRef = {'router': 350.0, 'laser_co2': 320.0, 'plasma': 480.0, 'laser_fibra': 950.0, 'router_3d': 350.0, 'impresora_3d': 60.0, 'torno': 450.0, 'otro': 350.0};
  static bool esReferencia(Maquina2 m) => m.id.startsWith('ref_');
  Maquina2 _referencia(String tipo) => Maquina2(id: 'ref_$tipo', nombre: tr('Máquina de referencia HETNA'), tipo: tipo,
    emoji: emojiTipoMaquina[tipo] ?? '⚙️', costoHora: _costoRef[tipo] ?? 350, preparacionMin: tipo == 'impresora_3d' ? 5 : tipo.startsWith('laser') ? 8 : 15,
    perforacionSeg: tipo == 'router' ? 2 : tipo.startsWith('laser') ? 0.5 : 1.5, remocionCm3Min: 15, impresionCm3H: 12);
  List<Maquina2> _maquinasDeTipo(String tipo) {
    final l = _maquinas.where((m) => m.tipo == tipo).toList();
    return l.isEmpty ? [_referencia(tipo)] : l;
  }
  Material2? _mat;
  int _cantidad = 1;
  final _cantC = TextEditingController(text: '1');
  final Set<String> _acabSel = {};
  double _relleno = 20;

  // Precio
  double? _margen; // null = el del taller
  double? _tiempoManual;
  Resultado2? _r;
  bool _verDesglose = false, _verVolumen = false, _verHoja = false, _verComparar = false;
  List<Map<String, dynamic>> _parecidos = [];
  Entrega? _entrega;

  @override
  void initState() {
    super.initState();
    _geo = widget.geoInicial;
    if (_geo != null) _pieza = _piezaDeGeo(_geo!);
    _cargar();
  }

  @override
  void dispose() { _largoC.dispose(); _anchoC.dispose(); _altoC.dispose(); _cantC.dispose(); super.dispose(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final t = await Simulador2Data.taller();
    final res = await Future.wait([
      Simulador2Data.maquinas(), Simulador2Data.materiales(mermaDefault: 15), Simulador2Data.acabados(),
      Simulador2Data.cargarVelocidades(),
    ]);
    if (!mounted) return;
    setState(() {
      _taller = t;
      _maquinas = res[0] as List<Maquina2>;
      _materiales = res[1] as List<Material2>;
      _acabados = res[2] as List<Acabado2>;
      _margen ??= t.margenPct;
      if (_maq == null) { if (_maquinas.isNotEmpty) _tipo = _maquinas.first.tipo; _elegirMaquina(_maquinasDeTipo(_tipo).first); }
      else if (!esReferencia(_maq!)) { final id = _maq!.id; _maq = _maquinas.firstWhere((m) => m.id == id, orElse: () => _maq!); }
      _cargando = false;
    });
    _recalcular();
  }

  void _elegirMaquina(Maquina2 m) {
    _maq = m;
    _tipo = m.tipo;
    final svs = serviciosDeMaquina(m.tipo);
    if (!svs.contains(_servicio)) _servicio = svs.first;
    if (_pieza?.es3D == true && svs.contains(Servicio2.relieve3D) && m.tipo != 'impresora_3d') _servicio = Servicio2.relieve3D;
    if (m.tipo == 'impresora_3d') _servicio = Servicio2.impresion3D;
    // Material que sirva para esa máquina
    final okMat = _materialesParaMaq();
    if (_mat == null || !okMat.contains(_mat)) _mat = okMat.isNotEmpty ? okMat.first : null;
  }

  List<Material2> _materialesParaMaq() {
    if (_maq == null) return _materiales;
    final grupos = materialesParaMaquina(_maq!.tipo).map((t) => t.clave).toSet();
    final l = _materiales.where((m) => grupos.contains(m.tipo)).toList();
    return l.isEmpty ? _materiales : l;
  }

  Pieza2 _piezaDeGeo(GeoCad g) => Pieza2(
    nombre: g.nombre, largo: g.largo, ancho: g.ancho, alto: g.alto,
    metrosCorte: g.longitudCorte / 1000, perforaciones: math.max(1, g.contornos + g.barrenos),
    areaMm2: g.areaPieza > 0 ? g.areaPieza : g.largo * g.ancho, volumenCm3: g.volumenCm3, es3D: g.es3D);

  void _piezaAMano() {
    final l = double.tryParse(_largoC.text.replaceAll(',', '.')) ?? 0;
    final a = double.tryParse(_anchoC.text.replaceAll(',', '.')) ?? 0;
    final h = double.tryParse(_altoC.text.replaceAll(',', '.')) ?? 0;
    if (l <= 0 || a <= 0) { _pieza = null; return; }
    final es3D = _servicio == Servicio2.relieve3D || _servicio == Servicio2.impresion3D || _servicio == Servicio2.torno;
    _pieza = Pieza2.aMano(largo: l, ancho: a, alto: h, complejidad: _complejidad, es3D: es3D);
  }

  Future<void> _subirArchivo() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ArchivoCadService.extensiones, withData: true);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      if (f.bytes == null) return;
      final g = ArchivoCadService.leer(f.name, f.bytes!);
      setState(() {
        _geo = g; _pieza = _piezaDeGeo(g); _aMano = false; _tiempoManual = null;
        if (g.es3D && _maq != null) {
          final svs = serviciosDeMaquina(_maq!.tipo);
          if (_maq!.tipo == 'impresora_3d') _servicio = Servicio2.impresion3D;
          else if (svs.contains(Servicio2.relieve3D)) _servicio = Servicio2.relieve3D;
        }
      });
      _recalcular();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trf('No se pudo leer el archivo: {0}', [e])), backgroundColor: AppColors.rojo));
    }
  }

  void _recalcular() {
    if (_aMano) _piezaAMano();
    if (_pieza == null || _maq == null || _mat == null) { setState(() => _r = null); return; }
    final vel = Simulador2Data.velocidad(_maq!, _mat!);
    final acs = _acabados.where((a) => _acabSel.contains(a.id)).toList();
    final r = calcular(servicio: _servicio, pieza: _pieza!, maquina: _maq!, material: _mat!, vel: vel, taller: _taller,
      cantidad: _cantidad, margenPct: _margen, acabados: acs, rellenoPct: _relleno, tiempoMinManual: _tiempoManual);
    setState(() => _r = r);
    _buscarParecidos();
    _calcularEntrega(r);
  }

  int _entregaSeq = 0;
  Future<void> _calcularEntrega(Resultado2 r) async {
    final seq = ++_entregaSeq;
    final e = await Capacidad.fechaEntrega(horasEste: r.tiempoTotalMin / 60, maquinaId: _maq == null || esReferencia(_maq!) ? null : _maq!.id);
    if (mounted && seq == _entregaSeq) setState(() => _entrega = e);
  }

  Future<void> _buscarParecidos() async {
    if (_pieza == null || _mat == null) return;
    final p = await Simulador2Data.parecidos(_pieza!, _mat!);
    if (mounted) setState(() => _parecidos = p);
  }

  Velocidad2 get _vel => (_maq != null && _mat != null) ? Simulador2Data.velocidad(_maq!, _mat!) : const Velocidad2();

  // ── Pasar a cotización ──
  Future<void> _pasarACotizacion() async {
    final r = _r;
    if (r == null || _maq == null || _mat == null || _pieza == null) return;
    final partida = Partida2(
      emoji: _maq!.emoji, servicio: '${nombreServicio2(_servicio)} · ${_maq!.nombre}',
      descripcion: '${_pieza!.nombre} · ${_mat!.nombre}${_acabSel.isNotEmpty ? ' · ${_acabados.where((a) => _acabSel.contains(a.id)).map((a) => a.nombre).join(', ')}' : ''}',
      cantidad: r.cantidad, precioUnitario: r.precioPieza, total: r.precioTotal, costoTotal: r.costoTotal,
      tiempoMin: r.tiempoMaquinaMinPieza, materialId: _mat!.id, maquinaId: esReferencia(_maq!) ? null : _maq!.id, tipoMaterial: _mat!.tipo,
      materialUnidades: r.unidadesMaterial, espesorMm: _mat!.espesorMm);
    Simulador2Data.guardarHistorial(r: r, pieza: _pieza!, maq: _maq!, mat: _mat!);
    if (widget.seleccionar) { Navigator.pop(context, partida); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => CotizarScreen(carritoSimulador: [partida])));
  }

  // ═══════════════════════════ UI ═══════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: Text(tr('Simulador'), style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: tr('Costos del taller'), icon: const Icon(Icons.tune), onPressed: _configTaller),
          PopupMenuButton<String>(onSelected: (v) {
            if (v == 'clasico') Navigator.push(context, MaterialPageRoute(builder: (_) => const SimuladorScreen()));
            if (v == 'recargar') _cargar();
          }, itemBuilder: (_) => [
            PopupMenuItem(value: 'recargar', child: Text(tr('Volver a cargar datos'))),
            PopupMenuItem(value: 'clasico', child: Text(tr('Simulador clásico (se irá pronto)'))),
          ]),
        ]),
      body: _cargando ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 120),
        children: [
          if (_maquinas.isEmpty) _avisoSinMaquinas(),
          _tarjeta(n: 1, titulo: tr('Pieza'), child: _campoPieza()),
          _tarjeta(n: 2, titulo: tr('Máquina'), child: _campoMaquina()),
          _tarjeta(n: 3, titulo: tr('Material'), child: _campoMaterial()),
          _tarjeta(n: 4, titulo: tr('Cantidad'), child: _campoCantidad()),
          _tarjeta(n: 5, titulo: tr('Acabado'), child: _campoAcabado()),
          const SizedBox(height: 6),
          if (_r != null) _resultado(_r!),
          if (_r != null) ..._plegables(_r!),
        ]),
      bottomNavigationBar: _r == null ? null : SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: SizedBox(height: 50, child: ElevatedButton.icon(
          onPressed: _r!.precioTotal > 0 ? _pasarACotizacion : null,
          icon: const Icon(Icons.receipt_long, color: Colors.white),
          label: Text(trf('Pasar a cotización · {0}', [_fmt.format(_r!.precioTotal)]), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))))),
    );
  }

  Widget _tarjeta({required int n, required String titulo, required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grisBorde)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 22, height: 22, alignment: Alignment.center, decoration: const BoxDecoration(color: AppColors.azul, shape: BoxShape.circle),
          child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
        const SizedBox(width: 8),
        Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 8),
      child,
    ]));

  Widget _avisoSinMaquinas() => Container(
    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      const Icon(Icons.precision_manufacturing, color: AppColors.naranja),
      const SizedBox(width: 10),
      Expanded(child: Text(tr('Primero registra tus máquinas en Costos del taller (valor, kWh, mantenimiento) para que el simulador sepa cuánto cuesta cada hora.'), style: const TextStyle(fontSize: 12.5))),
      TextButton(onPressed: _configTaller, child: Text(tr('Ir'))),
    ]));

  // ── 1. Pieza ──
  Widget _campoPieza() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: _subirArchivo, icon: const Icon(Icons.upload_file, size: 18),
          label: Text(_geo == null ? tr('Subir DXF / SVG / STL / OBJ') : _geo!.nombre, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.azul, side: const BorderSide(color: AppColors.azul)))),
        const SizedBox(width: 8),
        ChoiceChip(label: Text(tr('A mano')), selected: _aMano, onSelected: (v) { setState(() { _aMano = v; if (v) { _geo = null; _piezaAMano(); } }); _recalcular(); }),
      ]),
      if (_geo != null && !_aMano) ...[
        const SizedBox(height: 8),
        VisorPieza(geo: _geo!),
        if (_geo!.avisos.isNotEmpty) ..._geo!.avisos.map((a) => Padding(padding: const EdgeInsets.only(top: 4),
          child: Text('⚠ $a', style: const TextStyle(fontSize: 11, color: AppColors.naranja)))),
      ],
      if (_aMano) ...[
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _num(_largoC, tr('Largo'), 'mm')), const SizedBox(width: 6),
          Expanded(child: _num(_anchoC, tr('Ancho'), 'mm')), const SizedBox(width: 6),
          Expanded(child: _num(_altoC, tr('Alto'), 'mm')),
        ]),
        const SizedBox(height: 6),
        Text(tr('¿Qué tanto corte lleva?'), style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario)),
        Wrap(spacing: 6, children: [
          for (final c in const [('sencillo', 'Sencillo (sólo contorno)'), ('normal', 'Normal'), ('calado', 'Calado o celosía')])
            ChoiceChip(label: Text(tr(c.$2), style: const TextStyle(fontSize: 12)), selected: _complejidad == c.$1,
              onSelected: (_) { setState(() => _complejidad = c.$1); _recalcular(); }),
        ]),
      ],
      if (_pieza == null) Padding(padding: const EdgeInsets.only(top: 6),
        child: Text(tr('Sube el archivo de la pieza o escribe sus medidas.'), style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario))),
    ]);
  }

  Widget _num(TextEditingController c, String label, String suf) => TextField(controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, suffixText: suf, isDense: true, border: const OutlineInputBorder()),
    onChanged: (_) => _recalcular());

  // ── 2. Servicio y máquina ──
  Widget _campoMaquina() {
    final svs = _maq == null ? <Servicio2>[] : serviciosDeMaquina(_maq!.tipo);
    final deTipo = _maquinasDeTipo(_tipo);
    final virtual = _maq != null && esReferencia(_maq!);
    const tipos = ['router', 'laser_co2', 'plasma', 'laser_fibra', 'router_3d', 'impresora_3d', 'torno'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 4, children: [
        for (final t in tipos) ChoiceChip(
          label: Text('${emojiTipoMaquina[t]} ${tr(nombresTipoMaquina[t]!)}', style: const TextStyle(fontSize: 12)),
          selected: _tipo == t,
          onSelected: (_) { setState(() { _tipo = t; _elegirMaquina(_maquinasDeTipo(t).first); _tiempoManual = null; if (_aMano) _piezaAMano(); }); _recalcular(); }),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          value: _maq?.id, isExpanded: true,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
          items: deTipo.map((m) => DropdownMenuItem(value: m.id, child: Text('${m.emoji} ${m.nombre} · ${_fmt.format(m.costoHora)}/h', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (id) { setState(() => _elegirMaquina(deTipo.firstWhere((m) => m.id == id))); _recalcular(); })),
        IconButton(tooltip: virtual ? tr('Registra tu máquina en Costos del taller') : tr('Mesa, preparación y velocidades'),
          icon: Icon(Icons.settings_outlined, color: virtual ? AppColors.textoSecundario : AppColors.azul),
          onPressed: _maq == null ? null : virtual ? _configTaller : () async {
            await configMaquinaSheet(context, maquina: _maq!, materiales: _materiales);
            await _cargar();
          }),
      ]),
      if (virtual) Padding(padding: const EdgeInsets.only(top: 4), child: Text(
        tr('No tienes una máquina de este tipo registrada: se usa un costo por hora de referencia. Regístrala en Costos del taller para cotizar con tu costo real.'),
        style: const TextStyle(fontSize: 11, color: AppColors.naranja))),
      if (svs.length > 1) Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, children: [
        for (final s in svs) ChoiceChip(label: Text(tr(nombreServicio2(s)), style: const TextStyle(fontSize: 12)), selected: _servicio == s,
          onSelected: (_) { setState(() { _servicio = s; _tiempoManual = null; if (_aMano) _piezaAMano(); }); _recalcular(); }),
      ])),
      if (_servicio == Servicio2.impresion3D) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
        Text(trf('Relleno {0} %', [_relleno.round()]), style: const TextStyle(fontSize: 12)),
        Expanded(child: Slider(value: _relleno, min: 5, max: 100, divisions: 19, onChanged: (v) { setState(() => _relleno = v); _recalcular(); })),
      ])),
    ]);
  }

  // ── 3. Material ──
  Widget _campoMaterial() {
    final lista = _materialesParaMaq();
    if (lista.isEmpty) {
      return Row(children: [
        Expanded(child: Text(tr('No hay materiales en tu inventario. Agrégalos en Inventario con su precio, espesor y medida de hoja.'), style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario))),
      ]);
    }
    final vel = _vel;
    String velTxt = '';
    switch (_servicio) {
      case Servicio2.corte2D: velTxt = vel.corteMMin > 0 ? '${vel.corteMMin.toStringAsFixed(2)} m/min' : ''; break;
      case Servicio2.grabado: velTxt = vel.grabadoCm2Min > 0 ? '${vel.grabadoCm2Min.toStringAsFixed(0)} cm²/min' : ''; break;
      case Servicio2.relieve3D: case Servicio2.torno:
        final rem = vel.remocionCm3Min > 0 ? vel.remocionCm3Min : (_maq?.remocionCm3Min ?? 0);
        velTxt = rem > 0 ? '${rem.toStringAsFixed(1)} cm³/min' : ''; break;
      case Servicio2.impresion3D:
        final imp = vel.impresionCm3H > 0 ? vel.impresionCm3H : (_maq?.impresionCm3H ?? 0);
        velTxt = imp > 0 ? '${imp.toStringAsFixed(0)} cm³/h' : ''; break;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DropdownButtonFormField<String>(
        value: _mat?.id, isExpanded: true,
        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
        items: lista.map((m) => DropdownMenuItem(value: m.id, child: Row(children: [
          if (m.esRetazo) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.content_cut, size: 12, color: AppColors.ambar)),
          Expanded(child: Text(m.nombre, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          Text(_fmt.format(m.precio), style: const TextStyle(fontSize: 11, color: AppColors.verde, fontWeight: FontWeight.w700)),
        ]))).toList(),
        onChanged: (id) { setState(() { _mat = lista.firstWhere((m) => m.id == id); _tiempoManual = null; }); _recalcular(); }),
      if (_mat != null) Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, runSpacing: 4, children: [
        _chip('${tipoMaterialPorClave(_mat!.tipo)?.nombre ?? _mat!.tipo}${_mat!.espesorMm > 0 ? ' ${_mat!.espesorMm % 1 == 0 ? _mat!.espesorMm.toInt() : _mat!.espesorMm} mm' : ''}', AppColors.azulClaro, AppColors.azul),
        if (_mat!.esHoja) _chip('${tr('hoja')} ${_mat!.hojaLargo.round()}×${_mat!.hojaAncho.round()}', AppColors.gris, AppColors.textoSecundario)
        else if (!_mat!.porPeso) _chip(tr('sin medida de hoja'), AppColors.ambarClaro, AppColors.naranja),
        if (velTxt.isNotEmpty) InkWell(onTap: _editarVelocidad, child: _chip('$velTxt${vel.sugerido ? ' · ${tr('sugerido')}' : vel.origen == 'tiempo_real' ? ' · ${tr('aprendido')}' : ''} ✎',
          vel.sugerido ? AppColors.ambarClaro : AppColors.verdeClaro, vel.sugerido ? AppColors.naranja : AppColors.verde)),
        if (_mat!.stock > 0) _chip('${tr('stock')}: ${_mat!.stock % 1 == 0 ? _mat!.stock.toInt() : _mat!.stock}', AppColors.gris, AppColors.textoSecundario),
        InkWell(onTap: _completarMaterial, child: _chip('${tr('datos del material')} ✎', AppColors.gris, AppColors.textoSecundario)),
      ])),
    ]);
  }

  Widget _chip(String t, Color fondo, Color texto) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: TextStyle(fontSize: 11, color: texto, fontWeight: FontWeight.w600)));

  Future<void> _editarVelocidad() async {
    if (_maq == null || _mat == null) return;
    if (esReferencia(_maq!)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Para guardar velocidades primero registra tu máquina en Costos del taller.')), backgroundColor: AppColors.naranja));
      return;
    }
    final v = await editarVelocidadSheet(context, maquina: _maq!, material: _mat!, servicio: _servicio, actual: _vel);
    if (v == true) { await Simulador2Data.cargarVelocidades(); _recalcular(); }
  }

  Future<void> _completarMaterial() async {
    final m = _mat; if (m == null || m.id == null) return;
    final tipoC = ValueNotifier<String>(m.tipo);
    final esp = TextEditingController(text: m.espesorMm > 0 ? '${m.espesorMm}' : '');
    final hl = TextEditingController(text: m.hojaLargo > 0 ? '${m.hojaLargo.round()}' : '');
    final ha = TextEditingController(text: m.hojaAncho > 0 ? '${m.hojaAncho.round()}' : '');
    final merma = TextEditingController(text: '${m.mermaPct}');
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text(tr('Estos datos se guardan en el inventario y el simulador los usa siempre.'), style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario)),
          const SizedBox(height: 10),
          ValueListenableBuilder<String>(valueListenable: tipoC, builder: (_, t, __) => DropdownButtonFormField<String>(
            value: t, isExpanded: true, decoration: InputDecoration(labelText: tr('Tipo de material'), isDense: true, border: const OutlineInputBorder()),
            items: tiposMaterial.map((x) => DropdownMenuItem(value: x.clave, child: Text(x.nombre, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => tipoC.value = v ?? t)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: esp, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('Espesor'), suffixText: 'mm', isDense: true, border: const OutlineInputBorder()))),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: merma, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('Merma'), suffixText: '%', isDense: true, border: const OutlineInputBorder()))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: hl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Hoja: largo'), suffixText: 'mm', isDense: true, border: const OutlineInputBorder()))),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: ha, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Hoja: ancho'), suffixText: 'mm', isDense: true, border: const OutlineInputBorder()))),
          ]),
          const SizedBox(height: 4),
          Text(tr('Hojas comunes: 1220×2440 (4×8 pies), 1830×2440, 1220×1830. Deja vacío si se vende por kg o por pieza.'), style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario)),
          const SizedBox(height: 12),
          Row(children: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancelar'))), const Spacer(),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Guardar'))),
          ]),
        ])));
    if (ok != true) return;
    await Simulador2Data.completarMaterial(m.id!, {
      'tipo_material': tipoC.value,
      'espesor_mm': double.tryParse(esp.text.replaceAll(',', '.')),
      'largo_mm': double.tryParse(hl.text), 'ancho_mm': double.tryParse(ha.text),
      'merma_pct': double.tryParse(merma.text.replaceAll(',', '.')),
    });
    final id = m.id;
    await _cargar();
    setState(() { _mat = _materiales.firstWhere((x) => x.id == id, orElse: () => _mat!); });
    _recalcular();
  }

  // ── 4. Cantidad ──
  Widget _campoCantidad() => Row(children: [
    IconButton(onPressed: () => _setCant(_cantidad - 1), icon: const Icon(Icons.remove_circle_outline, color: AppColors.azul)),
    SizedBox(width: 80, child: TextField(controller: _cantC, textAlign: TextAlign.center, keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
      onChanged: (v) { final n = int.tryParse(v); if (n != null && n > 0) { _cantidad = n; _recalcular(); } })),
    IconButton(onPressed: () => _setCant(_cantidad + 1), icon: const Icon(Icons.add_circle_outline, color: AppColors.azul)),
    const SizedBox(width: 6),
    Wrap(spacing: 4, children: [for (final n in const [1, 10, 50, 100]) ActionChip(label: Text('$n', style: const TextStyle(fontSize: 11)), onPressed: () => _setCant(n), visualDensity: VisualDensity.compact)]),
  ]);

  void _setCant(int n) { if (n < 1) return; setState(() { _cantidad = n; _cantC.text = '$n'; }); _recalcular(); }

  // ── 5. Acabado ──
  Widget _campoAcabado() => Wrap(spacing: 6, runSpacing: 4, children: [
    ChoiceChip(label: Text(tr('Ninguno'), style: const TextStyle(fontSize: 12)), selected: _acabSel.isEmpty, onSelected: (_) { setState(() => _acabSel.clear()); _recalcular(); }),
    for (final a in _acabados) FilterChip(
      label: Text('${a.nombre}${a.precioPieza > 0 ? ' ${_fmt.format(a.precioPieza)}/pza' : a.precioM2 > 0 ? ' ${_fmt.format(a.precioM2)}/m²' : ''}', style: const TextStyle(fontSize: 12)),
      selected: _acabSel.contains(a.id),
      onSelected: (v) { setState(() { v ? _acabSel.add(a.id) : _acabSel.remove(a.id); }); _recalcular(); }),
    ActionChip(avatar: const Icon(Icons.add, size: 14), label: Text(tr('Acabado'), style: const TextStyle(fontSize: 12)), onPressed: _nuevoAcabado),
  ]);

  Future<void> _nuevoAcabado() async {
    final n = TextEditingController(), pp = TextEditingController(text: '0'), pm = TextEditingController(text: '0'), mi = TextEditingController(text: '0');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('Nuevo acabado')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: n, decoration: InputDecoration(labelText: tr('Nombre (lijado, barniz, pintura…)'), isDense: true, border: const OutlineInputBorder())),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: pp, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('\$ por pieza'), isDense: true, border: const OutlineInputBorder()))),
          const SizedBox(width: 6),
          Expanded(child: TextField(controller: pm, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('\$ por m²'), isDense: true, border: const OutlineInputBorder()))),
        ]),
        const SizedBox(height: 8),
        TextField(controller: mi, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Minutos de operador por pieza'), isDense: true, border: const OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancelar'))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Guardar'))),
      ]));
    if (ok != true || n.text.trim().isEmpty) return;
    try {
      await Simulador2Data.guardarAcabado(nombre: n.text.trim(), precioPieza: double.tryParse(pp.text) ?? 0, precioM2: double.tryParse(pm.text) ?? 0, minutosPieza: double.tryParse(mi.text) ?? 0);
      _acabados = await Simulador2Data.acabados();
      setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trf('No se guardó: {0}. ¿Ya corriste simulador2.sql?', [e])), backgroundColor: AppColors.rojo));
    }
  }

  // ── Resultado ──
  Widget _resultado(Resultado2 r) {
    final bajoMin = r.margenPct < _taller.margenMinPct;
    final colorPrecio = r.faltantes.isNotEmpty ? AppColors.textoSecundario : bajoMin ? AppColors.rojo : AppColors.verde;
    final h = r.tiempoTotalMin ~/ 60, m = (r.tiempoTotalMin % 60).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: colorPrecio.withOpacity(0.5), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (r.faltantes.isNotEmpty) ...[
          for (final f in r.faltantes) Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
            const Icon(Icons.error_outline, size: 16, color: AppColors.naranja), const SizedBox(width: 6),
            Expanded(child: Text('${tr('Falta')}: $f', style: const TextStyle(fontSize: 12.5, color: AppColors.naranja, fontWeight: FontWeight.w600))),
            TextButton(onPressed: f.startsWith('Velocidad') || f.startsWith('Tasa') ? _editarVelocidad : f.startsWith('Precio') ? _completarMaterial : _configTaller,
              child: Text(tr('Capturar'), style: const TextStyle(fontSize: 12))),
          ])),
          const Divider(height: 10),
        ],
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Precio por pieza'), style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario)),
            Text(_fmt2.format(r.precioPieza), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: colorPrecio, height: 1.1)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(trf('Total {0} pzas (sin IVA)', [r.cantidad]), style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario)),
            Text(_fmt.format(r.precioTotal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text(trf('Margen {0} %', [r.margenPct.round()]), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: bajoMin ? AppColors.rojo : AppColors.textoPrincipal)),
          Expanded(child: Slider(value: r.margenPct.clamp(0, 80).toDouble(), min: 0, max: 80, divisions: 80,
            activeColor: bajoMin ? AppColors.rojo : AppColors.verde,
            onChanged: (v) { setState(() => _margen = v); _recalcular(); })),
          InkWell(onTap: () { setState(() => _margen = _taller.margenPct); _recalcular(); }, child: Text(tr('normal'), style: const TextStyle(fontSize: 11, color: AppColors.azul))),
        ]),
        Row(children: [
          Text('${tr('Ganas')} ', style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario)),
          Text(_fmt.format(r.utilidad), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: bajoMin ? AppColors.rojo : AppColors.verde)),
          Text('  ·  ${tr('Costo')} ${_fmt.format(r.costoTotal)}', style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const Spacer(),
          const Icon(Icons.schedule, size: 14, color: AppColors.textoSecundario), const SizedBox(width: 3),
          Text(h > 0 ? '$h h ${m.toString().padLeft(2, '0')} min' : '$m min', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
        if (_entrega != null) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
          const Icon(Icons.event_available, size: 14, color: AppColors.textoSecundario), const SizedBox(width: 4),
          Expanded(child: Text(
            _entrega!.horasAdelante > 0.5
              ? trf('Entrega: {0} (hay {1} h por delante en {2})', [_fechaLarga(_entrega!.fecha), _entrega!.horasAdelante.toStringAsFixed(0), _maq?.nombre ?? ''])
              : trf('Entrega: {0} (la máquina está libre)', [_fechaLarga(_entrega!.fecha)]),
            style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario))),
        ])),
        if (bajoMin) Padding(padding: const EdgeInsets.only(top: 4), child: Text(trf('Abajo de tu margen mínimo ({0} %)', [_taller.margenMinPct.round()]), style: const TextStyle(fontSize: 11.5, color: AppColors.rojo, fontWeight: FontWeight.w600))),
        if (r.mercadoTotal > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
          const Icon(Icons.storefront_outlined, size: 14, color: AppColors.textoSecundario), const SizedBox(width: 4),
          Text('${tr('Mercado')}: ${_fmt.format(r.mercadoTotal)}', style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const SizedBox(width: 6),
          Text(r.precioTotal < r.mercadoTotal ? trf('(estás {0} % abajo)', [((1 - r.precioTotal / r.mercadoTotal) * 100).round()]) : trf('(estás {0} % arriba)', [((r.precioTotal / r.mercadoTotal - 1) * 100).round()]),
            style: TextStyle(fontSize: 11.5, color: r.precioTotal < r.mercadoTotal ? AppColors.azul : AppColors.naranja, fontWeight: FontWeight.w600)),
          if (r.precioTotal < r.mercadoTotal) TextButton(onPressed: () {
            // margen que iguala al mercado: 1 − costo/mercado
            final mg = (1 - r.costoTotal / r.mercadoTotal) * 100;
            setState(() => _margen = mg.clamp(0, 80).toDouble()); _recalcular();
          }, child: Text(tr('igualar'), style: const TextStyle(fontSize: 11))),
        ])),
        for (final a in r.avisos) Padding(padding: const EdgeInsets.only(top: 3), child: Text('⚠ $a', style: const TextStyle(fontSize: 11, color: AppColors.naranja))),
        if (r.explicacionTiempo.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
          Expanded(child: Text('${tr('Tiempo por pieza')}: ${r.tiempoMaquinaMinPieza.toStringAsFixed(1)} min = ${r.explicacionTiempo}', style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
          TextButton(onPressed: _ajustarTiempo, child: Text(tr('Ajustar'), style: const TextStyle(fontSize: 11))),
        ])),
      ]));
  }

  Future<void> _ajustarTiempo() async {
    final r = _r; if (r == null || _maq == null || _mat == null) return;
    final c = TextEditingController(text: r.tiempoMaquinaMinPieza.toStringAsFixed(1));
    bool guardar = true;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      title: Text(tr('Ajustar tiempo de máquina')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Si sabes que esta pieza tarda más o menos (muchas entradas, material difícil), escribe los minutos reales por pieza.'), style: const TextStyle(fontSize: 12.5)),
        const SizedBox(height: 10),
        TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), autofocus: true,
          decoration: InputDecoration(labelText: tr('Minutos por pieza'), isDense: true, border: const OutlineInputBorder())),
        if (_tiempoManual == null && _servicio == Servicio2.corte2D) CheckboxListTile(value: guardar, contentPadding: EdgeInsets.zero, dense: true,
          title: Text(tr('Guardar la velocidad de este material para la próxima'), style: const TextStyle(fontSize: 12)),
          onChanged: (v) => setD(() => guardar = v ?? true)),
      ]),
      actions: [
        TextButton(onPressed: () { Navigator.pop(ctx, false); }, child: Text(tr('Cancelar'))),
        if (_tiempoManual != null) TextButton(onPressed: () { setState(() => _tiempoManual = null); _recalcular(); Navigator.pop(ctx, false); }, child: Text(tr('Quitar ajuste'))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Aplicar'))),
      ])));
    if (ok != true) return;
    final min = double.tryParse(c.text.replaceAll(',', '.'));
    if (min == null || min <= 0) return;
    // Si se guarda, la velocidad se recalcula para que dé ese tiempo y el
    // ajuste manual ya no hace falta
    if (guardar && _servicio == Servicio2.corte2D && _pieza != null && !esReferencia(_maq!)) {
      final perf = _pieza!.perforaciones * _maq!.perforacionSeg / 60;
      final corteMin = min - perf;
      if (corteMin > 0 && _pieza!.metrosCorte > 0) {
        final v = _vel;
        await Simulador2Data.guardarVelocidad(maq: _maq!, mat: _mat!, vel: Velocidad2(
          corteMMin: _pieza!.metrosCorte / corteMin, grabadoCm2Min: v.grabadoCm2Min, remocionCm3Min: v.remocionCm3Min, impresionCm3H: v.impresionCm3H));
        setState(() => _tiempoManual = null);
        _recalcular();
        return;
      }
    }
    setState(() => _tiempoManual = min);
    _recalcular();
  }

  Future<void> _configTaller() async {
    await configTallerSheet(context, taller: _taller);
    await _cargar();
  }

  // ── Plegables ──
  List<Widget> _plegables(Resultado2 r) {
    final d = r.desglose;
    final an = r.anidado;
    return [
      _plegable(tr('Ver desglose'), _verDesglose, () => setState(() => _verDesglose = !_verDesglose), Column(children: [
        _fila(tr('Material'), _comoMaterial(r), d.material),
        _fila(tr('Máquina'), '${(r.tiempoMaquinaMinPieza * r.cantidad).toStringAsFixed(0)} min × ${_fmt.format(_maq?.costoHora ?? 0)}/h', d.maquina),
        _fila(tr('Operador'), '${(r.tiempoMaquinaMinPieza * r.cantidad + _taller.manejoMinPieza * r.cantidad).toStringAsFixed(0)} min × ${_fmt.format(_taller.costoHoraOperador)}/h', d.operador),
        _fila(tr('Preparación'), '${(_maq?.preparacionMin ?? 0).toStringAsFixed(0)} min · ${tr('una vez')}', d.preparacion),
        _fila(tr('Gastos fijos'), '${(r.tiempoTotalMin / 60).toStringAsFixed(2)} h × ${_fmt.format(_taller.gastosFijosHora)}/h', d.fijos),
        if (d.acabados > 0) _fila(tr('Acabados'), '', d.acabados),
        const Divider(height: 10),
        _fila(tr('Costo real'), '', d.costo, negrita: true),
        _fila(trf('Precio con margen {0} %', [r.margenPct.round()]), '÷ ${(1 - r.margenPct / 100).toStringAsFixed(2)}', r.precioTotal, negrita: true, color: AppColors.verde),
        if (_taller.ivaPct > 0) _fila(trf('Con IVA {0} %', [_taller.ivaPct.round()]), '', r.precioTotal * (1 + _taller.ivaPct / 100)),
      ])),
      if (an.cabe && _mat != null) _plegable(trf('Anidado en la hoja · {0} por hoja · {1} hoja(s)', [an.piezasPorHoja, an.hojasCompra]), _verHoja, () => setState(() => _verHoja = !_verHoja), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        VisorHoja(anidado: an, hojaLargo: _mat!.hojaLargo, hojaAncho: _mat!.hojaAncho, titulo: trf('Última hoja ({0}×{1} mm){2}', [_mat!.hojaLargo.round(), _mat!.hojaAncho.round(), an.rotada ? ' · ${tr('pieza girada 90°')}' : ''])),
        const SizedBox(height: 4),
        Text(trf('Usas {0} hojas; compras {1}. Sobra un retazo de {2}×{3} mm que puedes guardar en la bodega al terminar el trabajo.', [an.hojasUsadas.toStringAsFixed(2), an.hojasCompra, an.retazoLargo.round(), an.retazoAncho.round()]), style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario)),
      ])),
      if (_maquinas.length > 1) _plegable(tr('Comparar máquinas'), _verComparar, () => setState(() => _verComparar = !_verComparar), _tablaComparar()),
      _plegable(tr('Precio por volumen'), _verVolumen, () => setState(() => _verVolumen = !_verVolumen), _tablaVolumen()),
      if (_parecidos.isNotEmpty) _plegable(trf('Ya cotizaste algo parecido ({0})', [_parecidos.length]), true, null, Column(children: [
        for (final p in _parecidos) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p['archivo'] ?? ''}${p['cliente_nombre'] != null ? ' · ${p['cliente_nombre']}' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            Text('${(p['largo_mm'] as num?)?.round()}×${(p['ancho_mm'] as num?)?.round()} mm · ${p['cantidad']} pzas · ${_fecha(p['created_at'])}', style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario)),
          ])),
          Text('${_fmt.format((p['precio_pieza'] as num?) ?? 0)}/pza', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.azul)),
        ])),
      ])),
    ];
  }

  String _fechaLarga(DateTime d) { try { return DateFormat('EEE d MMM', localeFormato).format(d); } catch (_) { return '${d.day}/${d.month}'; } }

  String _fecha(dynamic iso) { try { return DateFormat('d MMM yy', localeFormato).format(DateTime.parse(iso.toString()).toLocal()); } catch (_) { return ''; } }

  String _comoMaterial(Resultado2 r) {
    final m = _mat; if (m == null) return '';
    final merma = (1 + m.mermaPct / 100).toStringAsFixed(2);
    if (r.servicio == Servicio2.impresion3D) return '${r.gramos.toStringAsFixed(0)} g × ${_fmt2.format(m.precio)}/${m.unidad}';
    if (m.porPeso) return '${r.unidadesMaterial.toStringAsFixed(2)} ${m.unidad} × ${_fmt.format(m.precio)} × $merma';
    if (m.esHoja) return '${r.unidadesMaterial.toStringAsFixed(2)} ${tr('hojas')} × ${_fmt.format(m.precio)} × $merma ${tr('merma')}';
    return '${r.unidadesMaterial.toStringAsFixed(0)} × ${_fmt.format(m.precio)}';
  }

  /// La misma pieza y material en cada máquina del taller que pueda hacerla.
  Widget _tablaComparar() {
    if (_pieza == null || _mat == null) return const SizedBox.shrink();
    final acs = _acabados.where((a) => _acabSel.contains(a.id)).toList();
    final filas = <(Maquina2, Servicio2, Resultado2)>[];
    for (final m in _maquinas) {
      final svs = serviciosDeMaquina(m.tipo);
      final s = svs.contains(_servicio) ? _servicio : (svs.first);
      // Sólo tiene sentido comparar el mismo tipo de trabajo
      if (s != _servicio && !(_servicio == Servicio2.corte2D && s == Servicio2.corte2D)) continue;
      final vel = Simulador2Data.velocidad(m, _mat!);
      final r = calcular(servicio: s, pieza: _pieza!, maquina: m, material: _mat!, vel: vel, taller: _taller,
        cantidad: _cantidad, margenPct: _margen, acabados: acs, rellenoPct: _relleno);
      filas.add((m, s, r));
    }
    if (filas.length < 2) return Text(tr('Sólo una de tus máquinas puede hacer este trabajo con este material.'), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario));
    filas.sort((a, b) => a.$3.precioTotal.compareTo(b.$3.precioTotal));
    return Column(children: [
      for (final f in filas) InkWell(onTap: () { setState(() { _elegirMaquina(f.$1); _servicio = f.$2; }); _recalcular(); },
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
          Text(f.$1.emoji, style: const TextStyle(fontSize: 16)), const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.$1.nombre, style: TextStyle(fontSize: 12.5, fontWeight: f.$1.id == _maq?.id ? FontWeight.w800 : FontWeight.w600)),
            Text(f.$3.faltantes.isNotEmpty ? '${tr('Falta')}: ${f.$3.faltantes.first}' : '${(f.$3.tiempoTotalMin / 60).toStringAsFixed(1)} h · ${tr('ganas')} ${_fmt.format(f.$3.utilidad)}',
              style: TextStyle(fontSize: 10.5, color: f.$3.faltantes.isNotEmpty ? AppColors.naranja : AppColors.textoSecundario)),
          ])),
          Text(f.$3.faltantes.isNotEmpty ? '—' : _fmt.format(f.$3.precioTotal), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: f.$1.id == _maq?.id ? AppColors.azul : AppColors.textoPrincipal)),
        ]))),
      Text(tr('Toca una máquina para cotizar con ella.'), style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario)),
    ]);
  }

  Widget _tablaVolumen() {
    if (_pieza == null || _maq == null || _mat == null) return const SizedBox.shrink();
    final acs = _acabados.where((a) => _acabSel.contains(a.id)).toList();
    final filas = tablaVolumen(servicio: _servicio, pieza: _pieza!, maquina: _maq!, material: _mat!, vel: _vel, taller: _taller,
      cantidad: _cantidad, margenPct: _margen, acabados: acs, rellenoPct: _relleno, tiempoMinManual: _tiempoManual);
    return Column(children: [
      Row(children: [
        Expanded(child: Text(tr('Piezas'), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
        Expanded(child: Text(tr('Por pieza'), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
        Expanded(child: Text(tr('Total'), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
        Expanded(child: Text(tr('Tiempo'), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
      ]),
      for (final f in filas) InkWell(onTap: () => _setCant(f.cantidad), child: Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
        Expanded(child: Text('${f.cantidad}', style: TextStyle(fontSize: 12.5, fontWeight: f.cantidad == _cantidad ? FontWeight.w800 : FontWeight.w500))),
        Expanded(child: Text(_fmt2.format(f.precioPieza), textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, fontWeight: f.cantidad == _cantidad ? FontWeight.w800 : FontWeight.w500, color: AppColors.verde))),
        Expanded(child: Text(_fmt.format(f.precioTotal), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5))),
        Expanded(child: Text('${(f.tiempoTotalMin / 60).toStringAsFixed(1)} h', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario))),
      ]))),
      const SizedBox(height: 4),
      Text(tr('La preparación se cobra una vez: entre más piezas, menos cuesta cada una.'), style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario)),
    ]);
  }

  Widget _plegable(String titulo, bool abierto, VoidCallback? onTap, Widget hijo) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.grisBorde)),
    child: Column(children: [
      InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 8, 10), child: Row(children: [
        Expanded(child: Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        if (onTap != null) Icon(abierto ? Icons.expand_less : Icons.expand_more, size: 20, color: AppColors.textoSecundario),
      ]))),
      if (abierto) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: hijo),
    ]));

  Widget _fila(String c, String como, double v, {bool negrita = false, Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
    Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(c, style: TextStyle(fontSize: 12.5, fontWeight: negrita ? FontWeight.w800 : FontWeight.w600)),
      if (como.isNotEmpty) Text(como, style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario)),
    ])),
    Text(_fmt.format(v), style: TextStyle(fontSize: 13, fontWeight: negrita ? FontWeight.w800 : FontWeight.w600, color: color)),
  ]));
}
