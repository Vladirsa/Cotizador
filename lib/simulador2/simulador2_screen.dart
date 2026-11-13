// lib/simulador2/simulador2_screen.dart
// HETNA CNC — Simulador 2.0: se llena en 5 campos (pieza, máquina, material,
// cantidad, acabado) y todo lo demás sale de los datos del taller. Un solo
// precio con deslizador de margen; el desglose, el anidado, el precio por
// volumen y "ya cotizaste algo parecido" van abajo, plegados.
// Fórmula y anidado: motor.dart. Datos: simulador2_data.dart.
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../i18n/tr.dart';
import '../services/archivo_cad_service.dart';
import '../screens/cotizar_screen.dart';
import '../services/puente_cotizacion.dart';
import '../screens/simulador_screen.dart' show SimuladorScreen;
import 'motor.dart';
import 'simulador2_data.dart';
import 'velocidades_hetna.dart';
import 'visor_pieza.dart';
import 'config_maquina_sheet.dart';
import 'capacidad.dart';
import 'recetas.dart';
import 'receta_widget.dart';
import '../services/pais.dart';

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
  NumberFormat get _fmt => Pais.fmt(centavos: false);
  NumberFormat get _fmt2 => Pais.fmt();
  bool _cargando = true;

  // Datos del taller
  List<Maquina2> _maquinas = [];
  List<Material2> _materiales = [];
  String? _grupoMat; // filtro de familia del material (null = todas)
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
  // HETNA ($/h típico en México, convertido a la moneda del taller) para que
  // todos los servicios estén siempre.
  static const _costoRef = {'router': 350.0, 'laser_co2': 320.0, 'plasma': 480.0, 'laser_fibra': 950.0, 'router_3d': 350.0, 'impresora_3d': 60.0, 'torno': 450.0, 'otro': 350.0};
  static bool esReferencia(Maquina2 m) => m.id.startsWith('ref_');
  Maquina2 _referencia(String tipo) => Maquina2(id: 'ref_$tipo', nombre: tr('Máquina de referencia HETNA'), tipo: tipo,
    emoji: emojiTipoMaquina[tipo] ?? '⚙️', costoHora: Pais.refHora(_costoRef[tipo] ?? 350), preparacionMin: tipo == 'impresora_3d' ? 5 : tipo.startsWith('laser') ? 8 : 15,
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
  bool _verDesglose = true, _verVolumen = false, _verHoja = false, _verComparar = false;
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
      Simulador2Data.cargarRecetas(),
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
    final propios = _materiales.where((m) => grupos.contains(m.tipo)).toList();
    // Después de los del inventario van los de referencia HETNA que no tenga
    // (mismo tipo y espesor), para que todo servicio tenga con qué cotizar
    final refs = Simulador2Data.materialesReferencia(_maq!.tipo)
      .where((r) => !propios.any((m) => m.tipo == r.tipo && (m.espesorMm - r.espesorMm).abs() < 0.6)).toList();
    return [...propios, ...refs];
  }

  // ── Receta técnica: de aquí sale el tiempo ──
  Receta? get _receta => (_maq == null || _mat == null) ? null : Simulador2Data.receta(_maq!, _mat!, _servicio.name, rellenoPct: _relleno);
  bool get _recetaDelTaller => _maq != null && _mat != null && !esReferencia(_maq!) &&
    Simulador2Data.ajustesReceta(_maq!, _mat!, Simulador2Data.operacionDe(_maq!.tipo, _servicio.name)).isNotEmpty;

  /// Velocidad para el motor: lo que el taller guardó (velocidad o tiempos
  /// reales) manda; si no, la que sale de la receta (HETNA o ajustada).
  Velocidad2 _velPara(Maquina2 maq, Material2 mat, Servicio2 servicio) {
    final guardada = Simulador2Data.velocidad(maq, mat);
    if (!guardada.sugerido) return guardada;
    final r = Simulador2Data.receta(maq, mat, servicio.name, rellenoPct: _relleno);
    final editada = !esReferencia(maq) && Simulador2Data.ajustesReceta(maq, mat, Simulador2Data.operacionDe(maq.tipo, servicio.name)).isNotEmpty;
    return Simulador2Data.velocidadDeReceta(r, tallerLaEdito: editada);
  }

  Maquina2 _conSegEntrada(Maquina2 m, double seg) => Maquina2(id: m.id, nombre: m.nombre, tipo: m.tipo, emoji: m.emoji, costoHora: m.costoHora,
    preparacionMin: m.preparacionMin, perforacionSeg: seg, mesaLargo: m.mesaLargo, mesaAncho: m.mesaAncho, mesaAlto: m.mesaAlto,
    remocionCm3Min: m.remocionCm3Min, impresionCm3H: m.impresionCm3H);

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
      // En celular el selector filtrado por .dxf/.stl deja los archivos en gris
      // (el teléfono no conoce esos tipos): se abre "cualquier archivo" y se
      // revisa la extensión aquí.
      final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '';
      if (!ArchivoCadService.extensiones.contains(ext)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trf('Ese archivo es .{0}; sube DXF, SVG, STL u OBJ.', [ext])), backgroundColor: AppColors.naranja));
        return;
      }
      if (f.bytes == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('El navegador no entregó el archivo. Intenta de nuevo o desde "Archivos" del teléfono.')), backgroundColor: AppColors.naranja));
        return;
      }
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
    final vel = _velPara(_maq!, _mat!, _servicio);
    final rec = _receta;
    final maqCalc = rec != null ? _conSegEntrada(_maq!, rec.segPorEntrada) : _maq!;
    final acs = _acabados.where((a) => _acabSel.contains(a.id)).toList();
    final r = calcular(servicio: _servicio, pieza: _pieza!, maquina: maqCalc, material: _mat!, vel: vel, taller: _taller,
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

  Velocidad2 get _vel => (_maq != null && _mat != null) ? _velPara(_maq!, _mat!, _servicio) : const Velocidad2();

  // ── Pasar a cotización ──
  // ── Juego de piezas (varias piezas distintas en la misma cotización) ──
  final List<_ItemJuego> _juego = [];
  final Map<String, ({AnidadoMulti an, Material2 mat, List<int> idx, double hojasSeparadas})> _anidadosJuego = {};
  bool _verJuego = true;

  String _medidasDe(Pieza2 pz, Material2 mat) {
    String mm(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return pz.es3D || pz.alto > 0
      ? '${mm(pz.largo)} × ${mm(pz.ancho)} × ${mm(pz.alto > 0 ? pz.alto : mat.espesorMm)} mm${pz.volumenCm3 > 0 ? ' · ${pz.volumenCm3.toStringAsFixed(1)} cm³' : ''}'
      : '${mm(pz.largo)} × ${mm(pz.ancho)}${mat.espesorMm > 0 ? ' × ${mm(mat.espesorMm)}' : ''} mm${pz.metrosCorte > 0 ? ' · ${pz.metrosCorte.toStringAsFixed(2)} m de corte' : ''}';
  }

  Partida2 _partidaDe(_ItemJuego it) {
    final r = it.resultado;
    return Partida2(
      emoji: it.maq.emoji, servicio: '${nombreServicio2(it.servicio)} · ${it.maq.nombre}',
      descripcion: '${it.pieza.nombre} · ${it.mat.nombre}${it.acabados.isNotEmpty ? ' · ${it.acabados.map((a) => a.nombre).join(', ')}' : ''}',
      cantidad: r.cantidad, precioUnitario: r.precioPieza, total: r.precioTotal, costoTotal: r.costoTotal,
      tiempoMin: r.tiempoMaquinaMinPieza, materialId: Simulador2Data.esReferenciaMaterial(it.mat) ? null : it.mat.id,
      maquinaId: esReferencia(it.maq) ? null : it.maq.id, tipoMaterial: it.mat.tipo,
      materialUnidades: r.unidadesMaterial, espesorMm: it.mat.espesorMm, geo: it.geo, imagenPng: it.png, medidas: _medidasDe(it.pieza, it.mat));
  }

  Future<_ItemJuego?> _itemActual() async {
    final r = _r;
    if (r == null || _maq == null || _mat == null || _pieza == null) return null;
    final png = _geo != null && !_aMano ? await renderPiezaPng(_geo!, ancho: 560, alto: 360) : null;
    final rec = _receta;
    return _ItemJuego(pieza: _pieza!, geo: _aMano ? null : _geo, maq: rec != null ? _conSegEntrada(_maq!, rec.segPorEntrada) : _maq!,
      servicio: _servicio, mat: _mat!, cantidad: _cantidad, acabados: _acabados.where((a) => _acabSel.contains(a.id)).toList(),
      margen: _margen, relleno: _relleno, tiempoManual: _tiempoManual, vel: _velPara(_maq!, _mat!, _servicio), resultado: r, png: png);
  }

  Future<void> _pasarACotizacion() async {
    try {
      final it = await _itemActual();
      if (!mounted) return;
      if (it == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Falta elegir máquina, material o la pieza para pasar el precio.')), backgroundColor: AppColors.naranja));
        return;
      }
      final partida = _partidaDe(it);
      _guardarHist(it);
      _entregar([partida]);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trf('No se pudo pasar a la cotización: {0}', [e])), backgroundColor: AppColors.rojo));
    }
  }

  // Abierto desde una cotización: regresa ahí. Desde la pestaña o el menú: va a la
  // cotización que está abierta en la pestaña Cotizar; si no hay, abre una nueva.
  void _entregar(List<Partida2> partidas) {
    if (widget.seleccionar) { Navigator.pop(context, partidas.length == 1 ? partidas.first : partidas); return; }
    if (PuenteCotizacion.enviar(partidas)) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => CotizarScreen(carritoSimulador: partidas)));
  }

  void _guardarHist(_ItemJuego it) {
    final aj = esReferencia(it.maq) ? const <String, double>{} : Simulador2Data.ajustesReceta(it.maq, it.mat, Simulador2Data.operacionDe(it.maq.tipo, it.servicio.name));
    Simulador2Data.guardarHistorial(r: it.resultado, pieza: it.pieza, maq: it.maq, mat: it.mat,
      ajustes: aj.isEmpty ? null : aj, acabados: it.acabados.isEmpty ? null : it.acabados.map((a) => a.nombre).join(', '));
  }

  /// Recotizar con el precio de aquella vez: mueve el margen para que el
  /// precio por pieza quede igual (si el costo lo permite).
  void _usarPrecioAnterior(Map<String, dynamic> h) {
    final r = _r; if (r == null) return;
    final precio = (h['precio_pieza'] as num?)?.toDouble() ?? 0;
    final costoPieza = r.costoTotal / r.cantidad;
    if (precio <= 0 || costoPieza <= 0) return;
    final mg = ((1 - costoPieza / precio) * 100).clamp(0, 80).toDouble();
    setState(() => _margen = mg);
    _recalcular();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trf('Margen ajustado a {0} % para quedar en {1} por pieza.', [mg.round(), _fmt2.format(precio)])), backgroundColor: AppColors.azul));
  }

  /// Recotizar con la receta de aquella vez (se guarda como tu receta).
  Future<void> _usarRecetaAnterior(Map<String, dynamic> h) async {
    if (_maq == null || _mat == null || esReferencia(_maq!)) return;
    final a = h['ajustes'];
    if (a is! Map || a.isEmpty) return;
    final ajustes = a.map((k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0));
    try {
      await Simulador2Data.guardarReceta(maq: _maq!, mat: _mat!, operacion: Simulador2Data.operacionDe(_maq!.tipo, _servicio.name), ajustes: ajustes, nota: 'De ${h['archivo'] ?? 'trabajo anterior'}');
      _recalcular();
    } catch (_) {}
  }

  Future<void> _agregarAlJuego() async {
    final it = await _itemActual();
    if (it == null || !mounted) return;
    setState(() { _juego.add(it); _verJuego = true; });
    _recalcularJuego();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trf('Agregada al juego ({0} piezas). Sube la siguiente o cotiza el juego.', [_juego.length])), backgroundColor: AppColors.azul, duration: const Duration(seconds: 2)));
  }

  /// Las piezas del juego que comparten hoja (mismo material) se anidan
  /// juntas: se compran las hojas justas y el costo del material se reparte
  /// por área entre las piezas.
  void _recalcularJuego() {
    _anidadosJuego.clear();
    final porMat = <String, List<int>>{};
    for (int i = 0; i < _juego.length; i++) {
      final it = _juego[i];
      final clave = it.mat.id ?? '${it.mat.tipo}_${it.mat.espesorMm}';
      if (it.mat.esHoja && !it.mat.porPeso && it.servicio != Servicio2.impresion3D) porMat.putIfAbsent(clave, () => []).add(i);
      else it.resultado = _calcItem(it, null);
    }
    porMat.forEach((clave, idx) {
      final mat = _juego[idx.first].mat;
      final an = anidarVarias(hojaLargo: mat.hojaLargo, hojaAncho: mat.hojaAncho,
        tipos: idx.map((i) => (largo: _juego[i].pieza.largo, ancho: _juego[i].pieza.ancho, cantidad: _juego[i].cantidad)).toList());
      final separadas = idx.fold(0.0, (s, i) => s + _calcItem(_juego[i], null).anidado.hojasUsadas);
      _anidadosJuego[clave] = (an: an, mat: mat, idx: idx, hojasSeparadas: separadas);
      final costoTotal = an.hojasCompra * mat.precio * (1 + mat.mermaPct / 100) * (1 + _taller.markupMaterialPct / 100);
      final areaTotal = idx.fold(0.0, (s, i) => s + _juego[i].pieza.largo * _juego[i].pieza.ancho * _juego[i].cantidad);
      for (final i in idx) {
        final it = _juego[i];
        final parte = areaTotal > 0 ? it.pieza.largo * it.pieza.ancho * it.cantidad / areaTotal : 1 / idx.length;
        it.resultado = _calcItem(it, an.hojasCompra > 0 ? costoTotal * parte : null);
      }
    });
    setState(() {});
  }

  Resultado2 _calcItem(_ItemJuego it, double? costoMaterialFijo) => calcular(servicio: it.servicio, pieza: it.pieza, maquina: it.maq,
    material: it.mat, vel: it.vel, taller: _taller, cantidad: it.cantidad, margenPct: it.margen, acabados: it.acabados,
    rellenoPct: it.relleno, tiempoMinManual: it.tiempoManual, costoMaterialFijo: costoMaterialFijo);

  double get _totalJuego => _juego.fold(0.0, (s, it) => s + it.resultado.precioTotal);

  Future<void> _cotizarJuego() async {
    if (_juego.isEmpty) return;
    final partidas = _juego.map(_partidaDe).toList();
    for (final it in _juego) { _guardarHist(it); }
    if (widget.seleccionar) { Navigator.pop(context, partidas); return; }
    _entregar(partidas);
  }

  Widget _tarjetaJuego() {
    final total = _totalJuego;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.azul, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(onTap: () => setState(() => _verJuego = !_verJuego), child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 8, 10), child: Row(children: [
          const Text('🧩', style: TextStyle(fontSize: 16)), const SizedBox(width: 6),
          Expanded(child: Text(trf('Juego de piezas · {0} partidas', [_juego.length]), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
          Text(_fmt.format(total), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.verde)),
          Icon(_verJuego ? Icons.expand_less : Icons.expand_more, size: 20, color: AppColors.textoSecundario),
        ]))),
        if (_verJuego) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (int i = 0; i < _juego.length; i++) Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
            Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: _colorJuego(i), borderRadius: BorderRadius.circular(2))),
            Expanded(child: Text('${_juego[i].pieza.nombre} · ${_juego[i].mat.nombre}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            Text('${_juego[i].cantidad} × ${_fmt2.format(_juego[i].resultado.precioPieza)}', style: const TextStyle(fontSize: 12)),
            IconButton(icon: const Icon(Icons.close, size: 16, color: AppColors.textoSecundario), visualDensity: VisualDensity.compact,
              onPressed: () { setState(() => _juego.removeAt(i)); _recalcularJuego(); }),
          ])),
          for (final e in _anidadosJuego.entries) ...[
            const Divider(height: 14),
            Text('${e.value.mat.nombre}: ${trf('{0} hoja(s) para todo el juego', [e.value.an.hojasCompra])}'
              '${e.value.hojasSeparadas > 0 ? ' · ${trf('por separado serían {0}', [e.value.hojasSeparadas.toStringAsFixed(1)])}' : ''}'
              ' · ${trf('aprovechamiento {0} %', [(e.value.an.aprovechamiento * 100).round()])}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            if (e.value.an.retazoLargo > 0) Text(trf('Sobra un retazo de {0}×{1} mm', [e.value.an.retazoLargo.round(), e.value.an.retazoAncho.round()]), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            if (e.value.an.noCaben.isNotEmpty) Text(tr('Alguna pieza no cabe en la hoja: se cobra aparte.'), style: const TextStyle(fontSize: 11, color: AppColors.naranja)),
            const SizedBox(height: 6),
            VisorHojas(anidado: e.value.an, hojaLargo: e.value.mat.hojaLargo, hojaAncho: e.value.mat.hojaAncho,
              nombres: e.value.idx.map((i) => '${_juego[i].pieza.nombre} ×${_juego[i].cantidad}').toList()),
          ],
          const SizedBox(height: 4),
          Text(tr('El material se cobra por las hojas completas del juego, repartido por área entre las piezas.'), style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario)),
        ])),
      ]));
  }

  Color _colorJuego(int i) {
    const cs = [Color(0xFF2563eb), Color(0xFF16a34a), Color(0xFFd97706), Color(0xFF9333ea), Color(0xFFdc2626), Color(0xFF0891b2), Color(0xFF65a30d), Color(0xFFdb2777)];
    // mismo color que en el dibujo de hojas: índice dentro de su material
    for (final e in _anidadosJuego.values) { final k = e.idx.indexOf(i); if (k >= 0) return cs[k % cs.length]; }
    return AppColors.textoSecundario;
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
          if (_juego.isNotEmpty) _tarjetaJuego(),
          if (_maquinas.isEmpty) _avisoSinMaquinas(),
          _tarjeta(n: 1, titulo: tr('Pieza'), child: _campoPieza()),
          _tarjeta(n: 2, titulo: tr('Máquina'), child: _campoMaquina()),
          _tarjeta(n: 3, titulo: tr('Material'), child: _campoMaterial()),
          if (_receta != null) RecetaCard(receta: _receta!, maquina: _maq!, material: _mat!, servicio: _servicio.name, tallerLaEdito: _recetaDelTaller,
            onCambio: () async { await Simulador2Data.cargarRecetas(); _recalcular(); }),
          _tarjeta(n: 4, titulo: tr('Cantidad'), child: _campoCantidad()),
          _tarjeta(n: 5, titulo: tr('Acabado'), child: _campoAcabado()),
          const SizedBox(height: 6),
          if (_r != null) _resultado(_r!),
          if (_r != null) ..._plegables(_r!),
        ]),
      bottomNavigationBar: (_r == null && _juego.isEmpty) ? null : SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(children: [
          if (_r != null) Expanded(flex: 2, child: SizedBox(height: 50, child: OutlinedButton.icon(
            onPressed: _r!.precioTotal > 0 ? _agregarAlJuego : null,
            icon: const Icon(Icons.add_box_outlined, size: 18),
            label: Text(_juego.isEmpty ? tr('Agregar al juego') : tr('Otra pieza'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.azul, side: const BorderSide(color: AppColors.azul), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
          if (_r != null) const SizedBox(width: 8),
          Expanded(flex: 3, child: SizedBox(height: 50, child: ElevatedButton.icon(
            onPressed: _juego.isNotEmpty ? _cotizarJuego : (_r != null && _r!.precioTotal > 0 ? _pasarACotizacion : null),
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            label: Text(_juego.isNotEmpty ? trf('Cotizar juego ({0}) · {1}', [_juego.length, _fmt.format(_totalJuego)]) : trf('Pasar a cotización · {0}', [_fmt.format(_r?.precioTotal ?? 0)]),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14), overflow: TextOverflow.ellipsis),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
        ]))),
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
    // Familias presentes para esta máquina; el filtro sólo muestra las que hay
    final grupos = <String>[for (final g in _ordenGrupos) if (lista.any((m) => _grupoDe(m) == g)) g];
    final grupoSel = grupos.contains(_grupoMat) ? _grupoMat : null;
    final visibles = (grupoSel == null ? lista : lista.where((m) => _grupoDe(m) == grupoSel).toList())
      ..sort((a, b) {
        final g = _ordenGrupos.indexOf(_grupoDe(a)).compareTo(_ordenGrupos.indexOf(_grupoDe(b)));
        if (g != 0) return g;
        // primero los de tu inventario, luego los de referencia; dentro, por tipo y espesor
        final r = (Simulador2Data.esReferenciaMaterial(a) ? 1 : 0).compareTo(Simulador2Data.esReferenciaMaterial(b) ? 1 : 0);
        if (r != 0) return r;
        final t = a.tipo.compareTo(b.tipo);
        return t != 0 ? t : a.espesorMm.compareTo(b.espesorMm);
      });
    // El material elegido siempre debe estar en la lista del menú
    if (_mat != null && !visibles.contains(_mat)) visibles.insert(0, _mat!);
    final items = <DropdownMenuItem<String>>[];
    String? grupoAnt;
    for (final m in visibles) {
      final g = _grupoDe(m);
      if (grupoSel == null && g != grupoAnt) {
        items.add(DropdownMenuItem<String>(value: '__grupo_$g', enabled: false,
          child: Text(_nombreGrupo(g).toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.textoSecundario, letterSpacing: 0.6))));
        grupoAnt = g;
      }
      items.add(DropdownMenuItem<String>(value: m.id, child: Row(children: [
        if (m.esRetazo) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.content_cut, size: 12, color: AppColors.ambar)),
        Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.nombre, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          Text(_caracteristicas(m), style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario), overflow: TextOverflow.ellipsis),
        ])),
        Text('${_fmt.format(m.precio)}/${m.unidad}', style: const TextStyle(fontSize: 11, color: AppColors.verde, fontWeight: FontWeight.w700)),
      ])));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (grupos.length > 1) Padding(padding: const EdgeInsets.only(bottom: 6), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        for (final g in [null, ...grupos]) Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
          label: Text(g == null ? tr('Todos') : _nombreGrupo(g), style: const TextStyle(fontSize: 11.5)),
          selected: grupoSel == g, visualDensity: VisualDensity.compact,
          onSelected: (_) => setState(() => _grupoMat = g))),
      ]))),
      DropdownButtonFormField<String>(
        value: _mat?.id, isExpanded: true, itemHeight: 52,
        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
        selectedItemBuilder: (_) => items.map((it) {
          final m = visibles.cast<Material2?>().firstWhere((x) => x!.id == it.value, orElse: () => null);
          return Align(alignment: Alignment.centerLeft, child: Text(m?.nombre ?? '', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis));
        }).toList(),
        items: items,
        onChanged: (id) { if (id == null || id.startsWith('__grupo_')) return; setState(() { _mat = lista.firstWhere((m) => m.id == id); _tiempoManual = null; }); _recalcular(); }),
      if (_mat != null) Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, runSpacing: 4, children: [
        _chip('${tipoMaterialPorClave(_mat!.tipo)?.nombre ?? _mat!.tipo}${_mat!.espesorMm > 0 ? ' ${_mat!.espesorMm % 1 == 0 ? _mat!.espesorMm.toInt() : _mat!.espesorMm} mm' : ''}', AppColors.azulClaro, AppColors.azul),
        if (_mat!.esHoja) _chip('${tr('hoja')} ${_mat!.hojaLargo.round()}×${_mat!.hojaAncho.round()}', AppColors.gris, AppColors.textoSecundario)
        else if (!_mat!.porPeso) _chip(tr('sin medida de hoja'), AppColors.ambarClaro, AppColors.naranja),
        if (velTxt.isNotEmpty) InkWell(onTap: _editarVelocidad, child: _chip('$velTxt${vel.sugerido ? ' · ${tr('sugerido')}' : vel.origen == 'tiempo_real' ? ' · ${tr('aprendido')}' : ''} ✎',
          vel.sugerido ? AppColors.ambarClaro : AppColors.verdeClaro, vel.sugerido ? AppColors.naranja : AppColors.verde)),
        if (_mat!.stock > 0) _chip('${tr('stock')}: ${_mat!.stock % 1 == 0 ? _mat!.stock.toInt() : _mat!.stock}', AppColors.gris, AppColors.textoSecundario),
        if (Simulador2Data.esReferenciaMaterial(_mat!)) InkWell(onTap: _agregarRefAlInventario, child: _chip('${tr('precio de referencia · agregar a mi inventario')} +', AppColors.ambarClaro, AppColors.naranja))
        else InkWell(onTap: _completarMaterial, child: _chip('${tr('datos del material')} ✎', AppColors.gris, AppColors.textoSecundario)),
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

  Future<void> _agregarRefAlInventario() async {
    final m = _mat; if (m == null) return;
    final id = await Simulador2Data.agregarMaterialAlInventario(m);
    if (id == null) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('No se pudo agregar al inventario.')), backgroundColor: AppColors.rojo)); return; }
    await _cargar();
    setState(() { _mat = _materiales.firstWhere((x) => x.id == id, orElse: () => _mat!); });
    _recalcular();
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Agregado a tu inventario con precio de referencia: corrígelo con "datos del material".')), backgroundColor: AppColors.verde)); }
  }

  Future<void> _completarMaterial() async {
    final m = _mat; if (m == null || m.id == null) return;
    if (Simulador2Data.esReferenciaMaterial(m)) { await _agregarRefAlInventario(); return; }
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
      _plegable(tr('Cómo se calculó el precio'), _verDesglose, () => setState(() => _verDesglose = !_verDesglose), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Primero el tiempo, que es de donde salen máquina, operador y gastos fijos
        if (r.explicacionTiempo.isNotEmpty) Container(
          width: double.infinity, margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trf('Tiempo de máquina: {0} min por pieza', [r.tiempoMaquinaMinPieza.toStringAsFixed(1)]), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            Text(r.explicacionTiempo, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            Text(_comoSaleTiempo(r.servicio), style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario)),
          ])),
        _fila(tr('Material'), _comoMaterial(r), d.material),
        _fila(tr('Máquina'), '${(r.tiempoMaquinaMinPieza * r.cantidad).toStringAsFixed(0)} min × ${_fmt.format(_maq?.costoHora ?? 0)}/h', d.maquina),
        _fila(tr('Operador'), '${(r.tiempoMaquinaMinPieza * r.cantidad + _taller.manejoMinPieza * r.cantidad).toStringAsFixed(0)} min × ${_fmt.format(_taller.costoHoraOperador)}/h', d.operador),
        _fila(tr('Preparación'), '${(_maq?.preparacionMin ?? 0).toStringAsFixed(0)} min · ${tr('una vez')}', d.preparacion),
        _fila(tr('Gastos fijos'), '${(r.tiempoTotalMin / 60).toStringAsFixed(2)} h × ${_fmt.format(_taller.gastosFijosHora)}/h', d.fijos),
        if (d.acabados > 0) _fila(tr('Acabados'), tr('precio por pieza o por m² de cada acabado'), d.acabados),
        const Divider(height: 10),
        _fila(tr('Costo real'), tr('suma de todo lo de arriba'), d.costo, negrita: true),
        _fila(trf('Precio con margen {0} %', [r.margenPct.round()]), trf('costo ÷ (1 − {0} %) = costo ÷ {1}', [r.margenPct.round(), (1 - r.margenPct / 100).toStringAsFixed(2)]), r.precioTotal, negrita: true, color: AppColors.verde),
        _fila(tr('Ganas'), tr('precio − costo real'), r.utilidad),
        if (_taller.ivaPct > 0) _fila(trf('Con IVA {0} %', [_taller.ivaPct.round()]), '', r.precioTotal * (1 + _taller.ivaPct / 100)),
      ])),
      if (an.cabe && _mat != null) _plegable(trf('Anidado en la hoja · {0} por hoja · {1} hoja(s)', [an.piezasPorHoja, an.hojasCompra]), _verHoja, () => setState(() => _verHoja = !_verHoja), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        VisorHoja(anidado: an, hojaLargo: _mat!.hojaLargo, hojaAncho: _mat!.hojaAncho, titulo: trf('Última hoja ({0}×{1} mm){2}', [_mat!.hojaLargo.round(), _mat!.hojaAncho.round(), an.rotada ? ' · ${tr('pieza girada 90°')}' : ''])),
        const SizedBox(height: 4),
        Text(trf('Usas {0} hojas; compras {1}. Sobra un retazo de {2}×{3} mm que puedes guardar en la bodega al terminar el trabajo.', [an.hojasUsadas.toStringAsFixed(2), an.hojasCompra, an.retazoLargo.round(), an.retazoAncho.round()]), style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario)),
      ])),
      if (_maquinas.length > 1) _plegable(tr('Comparar máquinas'), _verComparar, () => setState(() => _verComparar = !_verComparar), _tablaComparar()),
      _plegable(tr('Precio por volumen'), _verVolumen, () => setState(() => _verVolumen = !_verVolumen), _tablaVolumen()),
      if (_parecidos.isNotEmpty) _plegable(_parecidos.any((p) => p['igual'] == true) ? tr('Ya hiciste esta pieza antes') : trf('Ya cotizaste algo parecido ({0})', [_parecidos.length]), true, null, Column(children: [
        for (final p in _parecidos) Container(
          margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          decoration: BoxDecoration(color: p['igual'] == true ? AppColors.verdeClaro : AppColors.gris, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (p['igual'] == true) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.check_circle, size: 14, color: AppColors.verde)),
              Expanded(child: Text('${p['archivo'] ?? ''}${p['cliente_nombre'] != null ? ' · ${p['cliente_nombre']}' : ''}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              Text('${_fmt2.format((p['precio_pieza'] as num?) ?? 0)}/pza', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.azul)),
            ]),
            Text('${_fecha(p['created_at'])} · ${p['cantidad']} pzas · ${(p['largo_mm'] as num?)?.round()}×${(p['ancho_mm'] as num?)?.round()} mm'
              '${p['maquina_nombre'] != null ? ' · ${p['maquina_nombre']}' : ''}'
              '${p['tiempo_min'] != null ? ' · ${((p['tiempo_min'] as num).toDouble()).toStringAsFixed(1)} min/pza' : ''}'
              '${p['margen_pct'] != null ? ' · ${tr('margen')} ${(p['margen_pct'] as num).round()} %' : ''}'
              '${p['acabados'] != null ? ' · ${p['acabados']}' : ''}',
              style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario)),
            Row(children: [
              TextButton(onPressed: () => _usarPrecioAnterior(p), style: TextButton.styleFrom(visualDensity: VisualDensity.compact), child: Text(tr('Mismo precio'), style: const TextStyle(fontSize: 11.5))),
              if (p['ajustes'] is Map && (p['ajustes'] as Map).isNotEmpty && _maq != null && !esReferencia(_maq!))
                TextButton(onPressed: () => _usarRecetaAnterior(p), style: TextButton.styleFrom(visualDensity: VisualDensity.compact), child: Text(tr('Misma receta'), style: const TextStyle(fontSize: 11.5))),
            ]),
          ])),
      ])),
    ];
  }

  String _fechaLarga(DateTime d) { try { return DateFormat('EEE d MMM', localeFormato).format(d); } catch (_) { return '${d.day}/${d.month}'; } }

  String _fecha(dynamic iso) { try { return DateFormat('d MMM yy', localeFormato).format(DateTime.parse(iso.toString()).toLocal()); } catch (_) { return ''; } }

  // ── Familias de material para el filtro ──
  static const _ordenGrupos = ['madera', 'plastico', 'metal', 'filamento', 'otro'];
  String _grupoDe(Material2 m) => tipoMaterialPorClave(m.tipo)?.grupo ?? 'otro';
  String _nombreGrupo(String g) {
    switch (g) {
      case 'madera': return tr('Maderas y tableros');
      case 'plastico': return tr('Plásticos');
      case 'metal': return tr('Metales');
      case 'filamento': return tr('Filamentos y resinas');
      default: return tr('Otros');
    }
  }
  // Tipo, espesor, presentación y densidad en una línea
  String _caracteristicas(Material2 m) {
    final t = tipoMaterialPorClave(m.tipo);
    final esp = m.espesorMm > 0 ? '${m.espesorMm % 1 == 0 ? m.espesorMm.toInt() : m.espesorMm} mm' : '';
    final pres = m.esHoja ? '${m.hojaLargo.round()}×${m.hojaAncho.round()} mm' : m.porPeso ? tr('por kg') : '';
    final dens = (t?.densidad ?? 0) > 0 ? '${t!.densidad.toStringAsFixed(2)} g/cm³' : '';
    final ref = Simulador2Data.esReferenciaMaterial(m) ? tr('referencia') : tr('tu inventario');
    return [t?.nombre ?? m.tipo, esp, pres, dens, ref].where((x) => x.isNotEmpty).join(' · ');
  }

  // De dónde salen los datos del tiempo, en palabras
  String _comoSaleTiempo(Servicio2 s) {
    switch (s) {
      case Servicio2.corte2D: return tr('Los metros de corte son la suma de todas las líneas del archivo; la velocidad es la de esta máquina con este material y espesor (tuya, o la sugerida por HETNA hasta que la confirmes).');
      case Servicio2.grabado: return tr('El área a grabar sale del archivo; la velocidad de grabado es la de esta máquina con este material.');
      case Servicio2.relieve3D: return tr('El volumen a quitar es el bloque de material menos la pieza; la tasa de remoción es la de esta máquina con este material.');
      case Servicio2.impresion3D: return tr('El volumen sale del modelo; se imprime sólo el relleno y las paredes.');
      case Servicio2.torno: return tr('El volumen a quitar es el cilindro de material menos la pieza.');
    }
  }

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
      final vel = _velPara(m, _mat!, s);
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

/// Una pieza del juego con todo lo necesario para recalcularla.
class _ItemJuego {
  final Pieza2 pieza; final GeoCad? geo; final Maquina2 maq; final Servicio2 servicio; final Material2 mat;
  final int cantidad; final List<Acabado2> acabados; final double? margen; final double relleno; final double? tiempoManual;
  final Velocidad2 vel; final Uint8List? png;
  Resultado2 resultado;
  _ItemJuego({required this.pieza, this.geo, required this.maq, required this.servicio, required this.mat, required this.cantidad,
    required this.acabados, this.margen, required this.relleno, this.tiempoManual, required this.vel, required this.resultado, this.png});
}
