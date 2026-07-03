// lib/screens/simulador_screen.dart
// HETNA CNC — Simulador v4: Genérico, dinámico, cualquier negocio
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'cotizar_screen.dart';

// ══════════════════════════════════════════════════════
// MODELOS
// ══════════════════════════════════════════════════════

class SimServicio {
  final String id, nombre, emoji;
  final String? descripcion;
  final bool activo;
  final int orden;
  SimServicio({required this.id, required this.nombre, required this.emoji,
    this.descripcion, this.activo = true, this.orden = 0});
  factory SimServicio.fromJson(Map<String, dynamic> j) => SimServicio(
    id: j['id'], nombre: j['nombre'], emoji: j['emoji'] ?? '🔧',
    descripcion: j['descripcion'], activo: j['activo'] ?? true,
    orden: j['orden'] ?? 0);
}

class SimTipoTrabajo {
  final String id, nombre;
  final String formula; // por_area, por_volumen, por_hora, por_pieza, etc.
  final double factor;
  final bool necesitaLargo, necesitaAncho, necesitaAlto;
  final bool necesitaPeso, necesitaMetros, necesitaHoras, necesitaMinutos;
  final String? descripcionFormula;

  SimTipoTrabajo({required this.id, required this.nombre,
    this.formula = 'por_area', this.factor = 1.0,
    this.necesitaLargo = true, this.necesitaAncho = true,
    this.necesitaAlto = false, this.necesitaPeso = false,
    this.necesitaMetros = false, this.necesitaHoras = false,
    this.necesitaMinutos = false, this.descripcionFormula});

  factory SimTipoTrabajo.fromJson(Map<String, dynamic> j) => SimTipoTrabajo(
    id: j['id'], nombre: j['nombre'],
    formula: j['formula'] ?? 'por_area',
    factor: (j['factor'] as num?)?.toDouble() ?? 1.0,
    necesitaLargo: j['necesita_largo'] ?? true,
    necesitaAncho: j['necesita_ancho'] ?? true,
    necesitaAlto: j['necesita_alto'] ?? false,
    necesitaPeso: j['necesita_peso'] ?? false,
    necesitaMetros: j['necesita_metros'] ?? false,
    necesitaHoras: j['necesita_horas'] ?? false,
    necesitaMinutos: j['necesita_minutos'] ?? false,
    descripcionFormula: j['descripcion_formula']);
}

class SimTarifa {
  final String id, clave, nombre;
  double valor;
  final String? unidad;
  SimTarifa({required this.id, required this.clave, required this.nombre,
    required this.valor, this.unidad});
  factory SimTarifa.fromJson(Map<String, dynamic> j) => SimTarifa(
    id: j['id'], clave: j['clave'], nombre: j['nombre'],
    valor: (j['valor'] as num?)?.toDouble() ?? 0,
    unidad: j['unidad']);
}

class SimRango {
  final String id;
  final double desde, hasta, precio;
  SimRango({required this.id, required this.desde,
    required this.hasta, required this.precio});
  factory SimRango.fromJson(Map<String, dynamic> j) => SimRango(
    id: j['id'],
    desde: (j['desde'] as num?)?.toDouble() ?? 0,
    hasta: (j['hasta'] as num?)?.toDouble() ?? 999999,
    precio: (j['precio'] as num?)?.toDouble() ?? 0);
}

class SimExtra {
  final String id, nombre;
  final double precio;
  bool seleccionado;
  SimExtra({required this.id, required this.nombre,
    required this.precio, this.seleccionado = false});
  factory SimExtra.fromJson(Map<String, dynamic> j) => SimExtra(
    id: j['id'], nombre: j['nombre'],
    precio: (j['precio'] as num?)?.toDouble() ?? 0);
}

class SimAcabado {
  final String id, nombre;
  final double precio;
  SimAcabado({required this.id, required this.nombre, required this.precio});
  factory SimAcabado.fromJson(Map<String, dynamic> j) => SimAcabado(
    id: j['id'], nombre: j['nombre'],
    precio: (j['precio'] as num?)?.toDouble() ?? 0);
}

class SimConfig {
  final SimServicio servicio;
  final List<SimTipoTrabajo> tipos;
  final Map<String, SimTarifa> tarifas;
  final List<SimRango> rangos;
  final List<SimExtra> extras;
  final List<SimAcabado> acabados;

  SimConfig({required this.servicio, required this.tipos,
    required this.tarifas, required this.rangos,
    required this.extras, required this.acabados});

  double getTarifa(String clave) => tarifas[clave]?.valor ?? 0;

  double calcularPrecioRango(double indice) {
    for (final r in rangos) {
      if (indice >= r.desde && indice <= r.hasta) return r.precio;
    }
    return rangos.isNotEmpty ? rangos.last.precio : 0;
  }
}

class ResultadoSimulador {
  final String servicio, emoji, descripcion;
  final double maquila, extras, acabado, costoMaterial, subtotal, iva, total;
  final Map<String, String> desglose;
  final bool incluyeIva;
  final String? materialNombre;

  ResultadoSimulador({
    required this.servicio, required this.emoji, required this.descripcion,
    required this.maquila, this.extras = 0, this.acabado = 0,
    this.costoMaterial = 0, required this.subtotal,
    this.iva = 0, required this.total, required this.desglose,
    this.incluyeIva = false, this.materialNombre});
}

// ══════════════════════════════════════════════════════
// DATA SERVICE
// ══════════════════════════════════════════════════════
class SimuladorDataService {
  static final _sb = Supabase.instance.client;

  static Future<List<SimServicio>> getServicios() async {
    final data = await _sb.from('sim_servicios').select()
      .eq('activo', true).order('orden');
    return (data as List).map((j) => SimServicio.fromJson(j)).toList();
  }

  static Future<SimConfig> getConfig(String servicioId) async {
    final results = await Future.wait([
      _sb.from('sim_tipos_trabajo').select().eq('servicio_id', servicioId).order('nombre'),
      _sb.from('sim_tarifas').select().eq('servicio_id', servicioId),
      _sb.from('sim_rangos').select().eq('servicio_id', servicioId).order('desde'),
      _sb.from('sim_extras').select().eq('servicio_id', servicioId).eq('activo', true),
      _sb.from('sim_acabados').select().eq('servicio_id', servicioId),
      _sb.from('sim_servicios').select().eq('id', servicioId).single(),
    ]);

    final servicio = SimServicio.fromJson(results[5] as Map<String, dynamic>);
    final tipos = (results[0] as List).map((j) => SimTipoTrabajo.fromJson(j)).toList();
    final tarifasMap = <String, SimTarifa>{};
    for (final j in (results[1] as List)) {
      final t = SimTarifa.fromJson(j);
      tarifasMap[t.clave] = t;
    }
    final rangos = (results[2] as List).map((j) => SimRango.fromJson(j)).toList();
    final extras = (results[3] as List).map((j) => SimExtra.fromJson(j)).toList();
    final acabados = (results[4] as List).map((j) => SimAcabado.fromJson(j)).toList();

    return SimConfig(servicio: servicio, tipos: tipos, tarifas: tarifasMap,
      rangos: rangos, extras: extras, acabados: acabados);
  }

  static Future<List<Map<String, dynamic>>> getMaterialesInventario() async {
    try {
      final data = await _sb.from('inventario_bodega')
        .select('id, nombre, costo_unitario, unidad, categoria, stock_actual')
        .eq('activo', true).order('nombre');
      return (data as List).cast<Map<String, dynamic>>();
    } catch (_) { return []; }
  }

  // Guardar tarifa editada
  static Future<void> actualizarTarifa(String id, double valor) async {
    await _sb.from('sim_tarifas').update({'valor': valor}).eq('id', id);
  }

  // Guardar nuevo tipo de trabajo
  static Future<void> crearTipoTrabajo(Map<String, dynamic> datos) async {
    await _sb.from('sim_tipos_trabajo').insert(datos);
  }

  // Crear nuevo servicio
  static Future<void> crearServicio(Map<String, dynamic> datos) async {
    await _sb.from('sim_servicios').insert(datos);
  }
}

// ══════════════════════════════════════════════════════
// PANTALLA PRINCIPAL DEL SIMULADOR
// ══════════════════════════════════════════════════════
class SimuladorScreen extends StatefulWidget {
  const SimuladorScreen({super.key});
  @override
  State<SimuladorScreen> createState() => _SimuladorScreenState();
}

class _SimuladorScreenState extends State<SimuladorScreen> {
  List<SimServicio> _servicios = [];
  bool _cargando = true;
  final List<ResultadoSimulador> _carrito = [];
  final _fmt = NumberFormat(r'$#,##0', 'es_MX');

  double get _totalCarrito => _carrito.fold(0, (s, r) => s + r.total);

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final servicios = await SimuladorDataService.getServicios();
      if (mounted) setState(() { _servicios = servicios; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  void _agregarAlCarrito(ResultadoSimulador r) {
    setState(() => _carrito.add(r));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ ${r.servicio} agregado al carrito'),
      backgroundColor: AppColors.verde,
      duration: const Duration(seconds: 2)));
  }

  void _enviarACotizacion() {
    if (_carrito.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CotizarScreen(carritoSimulador: _carrito)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Simulador de costos',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.azul), onPressed: _cargar),
          IconButton(icon: const Icon(Icons.add, color: AppColors.azul),
            onPressed: _nuevoServicio),
        ]),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            // Banner carrito
            if (_carrito.isNotEmpty) _bannerCarrito(),
            // Lista de servicios
            Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.azul, Color(0xFF2d5a8e)]),
                  borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Calcula el costo de cualquier trabajo',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text('Selecciona el tipo de trabajo, llena las variables y agrega al carrito.',
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
                  if (_carrito.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _enviarACotizacion,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.naranja, borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.description_outlined, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text('Cotizar ${_carrito.length} servicio${_carrito.length > 1 ? "s" : ""} — ${_fmt.format(_totalCarrito)}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ]))),
                  ],
                ])),
              const SizedBox(height: 14),
              // Grid de servicios
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: 1.4, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: _servicios.length + 1, // +1 para el botón agregar
                itemBuilder: (_, i) {
                  if (i == _servicios.length) return _cardAgregar();
                  return _cardServicio(_servicios[i]);
                }),
              const SizedBox(height: 20),
              // Lista del carrito
              if (_carrito.isNotEmpty) ...[
                const Text('CARRITO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textoSecundario, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                ..._carrito.asMap().entries.map((e) => _cardCarrito(e.key, e.value)),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _enviarACotizacion,
                    icon: const Icon(Icons.description_outlined, color: Colors.white),
                    label: Text('Crear cotización — ${_fmt.format(_totalCarrito)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.naranja, padding: const EdgeInsets.symmetric(vertical: 14)))),
              ],
            ])),
          ]));
  }

  Widget _bannerCarrito() => Container(
    color: AppColors.naranja,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text('${_carrito.length} servicio${_carrito.length > 1 ? "s" : ""} — ${_fmt.format(_totalCarrito)}',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      GestureDetector(onTap: _enviarACotizacion,
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: const Text('Cotizar', style: TextStyle(color: AppColors.naranja,
            fontWeight: FontWeight.w700, fontSize: 12)))),
    ]));

  Widget _cardServicio(SimServicio s) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => _PantallaServicio(
        servicio: s,
        onAgregar: _agregarAlCarrito))),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
          blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(s.emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text(s.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: AppColors.azul), textAlign: TextAlign.center),
        if (s.descripcion != null) ...[
          const SizedBox(height: 4),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(s.descripcion!, style: const TextStyle(
              fontSize: 10, color: AppColors.textoSecundario), textAlign: TextAlign.center,
              maxLines: 2, overflow: TextOverflow.ellipsis)),
        ],
      ])));

  Widget _cardAgregar() => GestureDetector(
    onTap: _nuevoServicio,
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.azulClaro,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.azul.withOpacity(0.3)),
        ),
      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add_circle_outline, size: 32, color: AppColors.azul),
        SizedBox(height: 8),
        Text('Nuevo servicio', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: AppColors.azul)),
        SizedBox(height: 4),
        Text('Para tu negocio', style: TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
      ])));

  Widget _cardCarrito(int idx, ResultadoSimulador r) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Row(children: [
      Text(r.emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r.servicio, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        Text(r.descripcion, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario),
          maxLines: 2, overflow: TextOverflow.ellipsis),
      ])),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(_fmt.format(r.total), style: const TextStyle(fontSize: 14,
          fontWeight: FontWeight.w800, color: AppColors.azul)),
        GestureDetector(onTap: () => setState(() => _carrito.removeAt(idx)),
          child: const Text('Quitar', style: TextStyle(fontSize: 10, color: AppColors.rojo))),
      ]),
    ]));

  void _nuevoServicio() {
    final nombreCtrl = TextEditingController();
    String emojiSel = '🔧';
    final emojis = ['🔧','🪵','⚙️','🔴','🖨️','✏️','🔩','🪛','🏭','🛠️',
      '📐','📏','🎨','🪚','⚡','🔥','❄️','🌊','🎯','💡','🍞','🌽',
      '🍕','🥖','🪟','🪞','🔲','🏗️','📦','🎁','💎','🌿'];

    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(children: [
          Container(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Nuevo tipo de servicio',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              GestureDetector(onTap: () => Navigator.pop(ctx),
                child: const Icon(Icons.close)),
            ])),
          const Divider(height: 1),
          Expanded(child: SingleChildScrollView(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Emoji selector
              const Text('Ícono del servicio',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8,
                children: emojis.map((e) => GestureDetector(
                  onTap: () => setS(() => emojiSel = e),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: emojiSel == e ? AppColors.azulClaro : AppColors.gris,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: emojiSel == e ? AppColors.azul : AppColors.grisBorde)),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 22)))))).toList()),
              const SizedBox(height: 16),
              // Nombre
              TextFormField(controller: nombreCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del servicio *',
                  hintText: 'Ej: Corte de aluminio, Panadería, Carpintería...',
                  border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (nombreCtrl.text.trim().isEmpty) return;
                    await SimuladorDataService.crearServicio({
                      'nombre': nombreCtrl.text.trim(),
                      'emoji': emojiSel,
                      'activo': true,
                      'orden': _servicios.length + 1,
                    });
                    if (mounted) { Navigator.pop(ctx); _cargar(); }
                  },
                  icon: const Icon(Icons.save_outlined, color: Colors.white),
                  label: const Text('Crear servicio',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azul,
                    padding: const EdgeInsets.symmetric(vertical: 13)))),
            ]))),
        ]))));
  }
}

// ══════════════════════════════════════════════════════
// PANTALLA DE CÁLCULO POR SERVICIO
// ══════════════════════════════════════════════════════
class _PantallaServicio extends StatefulWidget {
  final SimServicio servicio;
  final void Function(ResultadoSimulador) onAgregar;
  const _PantallaServicio({required this.servicio, required this.onAgregar});
  @override
  State<_PantallaServicio> createState() => _PantallaServicioState();
}

class _PantallaServicioState extends State<_PantallaServicio> {
  SimConfig? _config;
  bool _cargando = true;
  ResultadoSimulador? _resultado;

  // Variables de entrada
  SimTipoTrabajo? _tipoSel;
  SimAcabado? _acabadoSel;
  bool _aplicarIva = false;
  bool _clienteTreMaterial = false;
  bool _mostrarTarifas = false;

  // Material
  Map<String, dynamic>? _materialInvSel; // del inventario
  String _materialLibreNombre = ''; // escrito manualmente
  double _materialLibrePrecio = 0;
  bool _usarInventario = true;
  List<Map<String, dynamic>> _materialesInv = [];

  // Medidas
  double _largo = 0, _ancho = 0, _alto = 0;
  double _peso = 0, _metros = 0, _horas = 0, _minutos = 0;
  int _cantidad = 1;
  String _complejidad = 'media'; // para por_diseno

  // Tarifas editables
  final Map<String, TextEditingController> _tarifasCtrls = {};

  // Descripción editable antes de cotizar
  String _descripcionEditable = '';

  static const double _ivaPct = 16.0;
  final _fmt = NumberFormat(r'$#,##0.00', 'es_MX');

  @override
  void initState() { super.initState(); _cargar(); }

  @override
  void dispose() {
    for (final c in _tarifasCtrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final results = await Future.wait([
        SimuladorDataService.getConfig(widget.servicio.id),
        SimuladorDataService.getMaterialesInventario(),
      ]);
      final cfg = results[0] as SimConfig;
      final inv = results[1] as List<Map<String, dynamic>>;
      if (mounted) setState(() {
        _config = cfg;
        _materialesInv = inv;
        _cargando = false;
        if (cfg.tipos.isNotEmpty) _tipoSel = cfg.tipos.first;
        if (cfg.acabados.isNotEmpty) _acabadoSel = cfg.acabados.first;
        // Inicializar controladores de tarifas
        for (final t in cfg.tarifas.values) {
          _tarifasCtrls[t.id] = TextEditingController(
            text: t.valor.toStringAsFixed(2));
        }
      });
    } catch (e) { if (mounted) setState(() => _cargando = false); }
  }

  // ── CALCULAR PRECIO ─────────────────────────────────
  void _calcular() {
    final cfg = _config;
    if (cfg == null || _tipoSel == null) return;

    final tipo = _tipoSel!;
    final formula = tipo.formula;
    double maquila = 0;
    final desglose = <String, String>{};

    switch (formula) {
      case 'por_area':
        final areaM2 = (_largo / 100) * (_ancho / 100);
        final tarifa = cfg.getTarifa('tarifa_m2') > 0
          ? cfg.getTarifa('tarifa_m2')
          : cfg.getTarifa('tarifa_m2_acero') > 0
            ? cfg.getTarifa('tarifa_m2_acero') : 100;
        final areaMin = cfg.getTarifa('area_minima_m2');
        if (areaM2 >= areaMin && areaMin > 0) {
          maquila = tarifa * areaM2 * _cantidad;
          desglose['Área'] = '${_largo}×${_ancho} cm = ${areaM2.toStringAsFixed(3)} m²';
          desglose['Tarifa'] = '${_fmt.format(tarifa)}/m²';
        } else {
          final tarifaPieza = cfg.getTarifa('tarifa_pieza') > 0
            ? cfg.getTarifa('tarifa_pieza') : tarifa * areaM2;
          maquila = tarifaPieza * _cantidad;
          desglose['Modo'] = 'Por pieza';
          desglose['Tarifa'] = _fmt.format(tarifaPieza);
        }
        break;

      case 'por_volumen':
        final volumen = _largo * _ancho * _alto;
        final indice = volumen * tipo.factor;
        maquila = cfg.calcularPrecioRango(indice) * _cantidad;
        desglose['Pieza'] = '${_largo}×${_ancho}×${_alto} cm';
        desglose['Volumen'] = '${volumen.toStringAsFixed(0)} cm³';
        desglose['Factor ${tipo.nombre}'] = '×${tipo.factor}';
        desglose['Índice'] = '${indice.toStringAsFixed(0)}';
        if (cfg.rangos.isNotEmpty) {
          desglose['Rango'] = _fmt.format(cfg.calcularPrecioRango(indice));
        }
        break;

      case 'por_hora':
        final tarifa = cfg.getTarifa('tarifa_hora') > 0
          ? cfg.getTarifa('tarifa_hora') : cfg.getTarifa('tarifa_hr') > 0
          ? cfg.getTarifa('tarifa_hr') : 200;
        maquila = tarifa * _horas * _cantidad;
        desglose['Horas'] = '${_horas.toStringAsFixed(1)} hrs';
        desglose['Tarifa'] = '${_fmt.format(tarifa)}/hr';
        break;

      case 'por_pieza':
        final tarifa = cfg.getTarifa('tarifa_pieza') > 0
          ? cfg.getTarifa('tarifa_pieza') : 100;
        maquila = tarifa * _cantidad.toDouble();
        desglose['Precio/pieza'] = _fmt.format(tarifa);
        break;

      case 'por_minuto':
        final tarifa = cfg.getTarifa('tarifa_minuto') > 0
          ? cfg.getTarifa('tarifa_minuto') : cfg.getTarifa('tarifa_min') > 0
          ? cfg.getTarifa('tarifa_min') : 5;
        maquila = tarifa * _minutos * _cantidad;
        desglose['Minutos'] = '${_minutos.toStringAsFixed(0)} min';
        desglose['Tarifa'] = '${_fmt.format(tarifa)}/min';
        break;

      case 'por_metro':
        final tarifa = cfg.getTarifa('tarifa_metro') > 0
          ? cfg.getTarifa('tarifa_metro') : cfg.getTarifa('tarifa_metro_lineal') > 0
          ? cfg.getTarifa('tarifa_metro_lineal') : 100;
        maquila = tarifa * _metros * _cantidad;
        desglose['Metros'] = '${_metros.toStringAsFixed(2)} m';
        desglose['Tarifa'] = '${_fmt.format(tarifa)}/m';
        break;

      case 'precio_fijo':
        maquila = cfg.getTarifa('precio_fijo') * _cantidad;
        desglose['Precio fijo'] = _fmt.format(cfg.getTarifa('precio_fijo'));
        break;

      case 'por_kg':
        final tarifa = cfg.getTarifa('tarifa_kg') > 0
          ? cfg.getTarifa('tarifa_kg') : 50;
        maquila = tarifa * _peso * _cantidad;
        desglose['Peso'] = '${_peso.toStringAsFixed(2)} kg';
        desglose['Tarifa'] = '${_fmt.format(tarifa)}/kg';
        break;

      case 'por_diseno':
        final precios = {
          'simple': cfg.getTarifa('precio_simple') > 0
            ? cfg.getTarifa('precio_simple') : 200,
          'media': cfg.getTarifa('precio_medio') > 0
            ? cfg.getTarifa('precio_medio') : 500,
          'alta': cfg.getTarifa('precio_alto') > 0
            ? cfg.getTarifa('precio_alto') : 1200,
          'premium': cfg.getTarifa('precio_premium') > 0
            ? cfg.getTarifa('precio_premium') : 2500,
        };
        maquila = ((precios[_complejidad] ?? 500) * _cantidad).toDouble();
        desglose['Complejidad'] = _complejidad.toUpperCase();
        desglose['Precio'] = _fmt.format(precios[_complejidad] ?? 500);
        break;
    }

    // Pedido mínimo
    final pedMin = cfg.getTarifa('pedido_minimo');
    if (pedMin > 0 && maquila < pedMin) {
      desglose['Pedido mínimo'] = _fmt.format(pedMin);
      maquila = pedMin;
    }

    // Acabado
    double acabadoTotal = _acabadoSel?.precio ?? 0;
    if (acabadoTotal > 0) desglose['Acabado ${_acabadoSel?.nombre}'] = _fmt.format(acabadoTotal);

    // Extras
    double extrasTotal = 0;
    for (final e in cfg.extras.where((e) => e.seleccionado)) {
      extrasTotal += e.precio;
      desglose['Extra: ${e.nombre}'] = _fmt.format(e.precio);
    }

    // Material
    double costoMaterial = 0;
    String? materialNombre;
    if (!_clienteTreMaterial) {
      if (_usarInventario && _materialInvSel != null) {
        costoMaterial = ((_materialInvSel!['costo_unitario'] as num?)?.toDouble() ?? 0) * _cantidad;
        materialNombre = _materialInvSel!['nombre'] as String?;
        if (costoMaterial > 0) desglose['Material ($materialNombre)'] = _fmt.format(costoMaterial);
      } else if (!_usarInventario && _materialLibrePrecio > 0) {
        costoMaterial = _materialLibrePrecio * _cantidad;
        materialNombre = _materialLibreNombre.isNotEmpty ? _materialLibreNombre : 'Material';
        desglose['Material ($materialNombre)'] = _fmt.format(costoMaterial);
      }
    } else {
      desglose['Material'] = 'Cliente trae el material';
    }

    final subtotal = maquila + extrasTotal + acabadoTotal + costoMaterial;
    final iva = _aplicarIva ? subtotal * _ivaPct / 100 : 0.0;
    final total = subtotal + iva;
    if (_aplicarIva) desglose['IVA 16%'] = _fmt.format(iva);

    // Generar descripción automática
    final descParts = <String>[];
    descParts.add(tipo.nombre);
    if (_tipoSel?.necesitaLargo == true && _largo > 0 && _ancho > 0) {
      final medidas = _alto > 0 ? '${_largo}×${_ancho}×${_alto} cm' : '${_largo}×${_ancho} cm';
      descParts.add('Medidas: $medidas');
    }
    if (_peso > 0) descParts.add('Peso: ${_peso} kg');
    if (_metros > 0) descParts.add('${_metros} metros lineales');
    if (materialNombre != null) descParts.add('Material: $materialNombre');
    if (_clienteTreMaterial) descParts.add('Cliente trae el material');
    if (_acabadoSel != null && _acabadoSel!.nombre != 'Sin acabado') {
      descParts.add('Acabado: ${_acabadoSel!.nombre}');
    }
    if (_cantidad > 1) descParts.add('Cantidad: $_cantidad piezas');

    setState(() {
      _descripcionEditable = descParts.join('\n');
      _resultado = ResultadoSimulador(
        servicio: widget.servicio.nombre,
        emoji: widget.servicio.emoji,
        descripcion: _descripcionEditable,
        maquila: maquila,
        extras: extrasTotal,
        acabado: acabadoTotal,
        costoMaterial: costoMaterial,
        subtotal: subtotal,
        iva: iva,
        total: total,
        desglose: desglose,
        incluyeIva: _aplicarIva,
        materialNombre: materialNombre);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(children: [
          Text(widget.servicio.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(widget.servicio.nombre,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
        ])),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : _config == null
          ? const Center(child: Text('Error cargando configuración'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                // 1. TIPO DE TRABAJO
                _seccionCard('Tipo de trabajo', _buildTiposTrabajo()),
                const SizedBox(height: 10),
                // 2. TARIFAS DEL MODO (colapsables)
                if (_tipoSel != null) _seccionTarifas(),
                const SizedBox(height: 10),
                // 3. MEDIDAS / VARIABLES
                if (_tipoSel != null) _seccionCard('Variables del trabajo', _buildVariables()),
                const SizedBox(height: 10),
                // 4. MATERIAL
                _seccionCard('Material', _buildMaterial()),
                const SizedBox(height: 10),
                // 5. CANTIDAD
                _seccionCard('Cantidad y extras', _buildCantidadExtras()),
                const SizedBox(height: 14),
                // 6. BOTÓN CALCULAR
                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _calcular,
                    icon: const Icon(Icons.calculate_outlined, color: Colors.white),
                    label: const Text('Calcular precio',
                      style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.azul,
                      padding: const EdgeInsets.symmetric(vertical: 14)))),
                // 7. RESULTADO
                if (_resultado != null) ...[
                  const SizedBox(height: 14),
                  _widgetResultado(_resultado!),
                ],
                const SizedBox(height: 40),
              ])));
  }

  // ── SECCIÓN: TIPOS DE TRABAJO ─────────────────────
  Widget _buildTiposTrabajo() {
    final cfg = _config!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8,
        children: cfg.tipos.map((t) {
          final sel = _tipoSel?.id == t.id;
          return GestureDetector(
            onTap: () => setState(() { _tipoSel = t; _resultado = null; }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppColors.azul : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.nombre, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppColors.textoPrincipal)),
                if (t.descripcionFormula != null) Text(t.descripcionFormula!,
                  style: TextStyle(fontSize: 9,
                    color: sel ? Colors.white70 : AppColors.textoSecundario)),
              ])));
        }).toList()),
      const SizedBox(height: 8),
      // Botón agregar nuevo modo
      GestureDetector(
        onTap: _nuevoTipoTrabajo,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.azulClaro,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.azul.withOpacity(0.3))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add, size: 14, color: AppColors.azul),
            SizedBox(width: 4),
            Text('Agregar modo', style: TextStyle(fontSize: 11, color: AppColors.azul,
              fontWeight: FontWeight.w600)),
          ]))),
    ]);
  }

  // ── SECCIÓN: TARIFAS EDITABLES ────────────────────
  Widget _seccionTarifas() {
    final cfg = _config!;
    if (cfg.tarifas.isEmpty) return const SizedBox();
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(children: [
        // Header colapsable
        GestureDetector(
          onTap: () => setState(() => _mostrarTarifas = !_mostrarTarifas),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.tune_outlined, size: 18, color: AppColors.azul),
              const SizedBox(width: 8),
              Expanded(child: Text('Tarifas de ${_tipoSel?.nombre ?? "este servicio"}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.azul))),
              Icon(_mostrarTarifas ? Icons.expand_less : Icons.expand_more, color: AppColors.azul),
            ]))),
        if (_mostrarTarifas) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              ...cfg.tarifas.values.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.nombre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    if (t.unidad != null) Text(t.unidad!,
                      style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
                  ])),
                  const SizedBox(width: 10),
                  SizedBox(width: 100, child: TextFormField(
                    controller: _tarifasCtrls[t.id],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      isDense: true, filled: true, fillColor: AppColors.gris,
                      prefixText: r'$',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                ]))),
              // Rangos
              if (cfg.rangos.isNotEmpty) ...[
                const Divider(height: 16),
                const Align(alignment: Alignment.centerLeft,
                  child: Text('Tabla de rangos', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: AppColors.azul))),
                const SizedBox(height: 8),
                ...cfg.rangos.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Expanded(child: Text(
                      '${r.desde.toStringAsFixed(0)} – ${r.hasta.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
                    Text(_fmt.format(r.precio), style: const TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: AppColors.azul)),
                  ]))),
              ],
              const SizedBox(height: 8),
              SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _guardarTarifas,
                  icon: const Icon(Icons.save_outlined, size: 16, color: AppColors.verde),
                  label: const Text('Guardar tarifas',
                    style: TextStyle(color: AppColors.verde, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.verde)))),
            ])),
        ],
      ]));
  }

  Future<void> _guardarTarifas() async {
    final cfg = _config!;
    for (final t in cfg.tarifas.values) {
      final val = double.tryParse(_tarifasCtrls[t.id]?.text ?? '');
      if (val != null && val != t.valor) {
        await SimuladorDataService.actualizarTarifa(t.id, val);
        t.valor = val;
      }
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('✅ Tarifas guardadas'), backgroundColor: AppColors.verde));
  }

  // ── SECCIÓN: VARIABLES SEGÚN FÓRMULA ─────────────
  Widget _buildVariables() {
    final tipo = _tipoSel!;
    final formula = tipo.formula;
    final campos = <Widget>[];

    if (formula == 'por_diseno') {
      campos.add(const Text('Complejidad del diseño',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)));
      campos.add(const SizedBox(height: 8));
      final niveles = [
        {'v': 'simple', 'l': 'Simple', 'd': 'Logo o figura básica'},
        {'v': 'media', 'l': 'Media', 'd': 'Ilustración con detalle'},
        {'v': 'alta', 'l': 'Alta', 'd': 'Diseño complejo o 3D'},
        {'v': 'premium', 'l': 'Premium', 'd': 'Proyecto completo'},
      ];
      campos.add(Wrap(spacing: 8, runSpacing: 8,
        children: niveles.map((n) {
          final sel = _complejidad == n['v'];
          return GestureDetector(
            onTap: () => setState(() { _complejidad = n['v']!; _resultado = null; }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppColors.azul : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde)),
              child: Column(children: [
                Text(n['l']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : AppColors.textoPrincipal)),
                Text(n['d']!, style: TextStyle(fontSize: 10,
                  color: sel ? Colors.white70 : AppColors.textoSecundario)),
              ])));
        }).toList()));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: campos);
    }

    if (formula == 'precio_fijo') {
      campos.add(Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(8)),
        child: const Text('Precio fijo negociado. Edita la tarifa en la sección de tarifas arriba.',
          style: TextStyle(fontSize: 12, color: AppColors.azul))));
      return Column(children: campos);
    }

    // Medidas según fórmula
    if (tipo.necesitaLargo) {
      campos.add(_campoMedida('Largo (cm)', _largo, (v) => setState(() { _largo = v; _resultado = null; })));
      campos.add(const SizedBox(height: 10));
    }
    if (tipo.necesitaAncho) {
      campos.add(_campoMedida('Ancho (cm)', _ancho, (v) => setState(() { _ancho = v; _resultado = null; })));
      campos.add(const SizedBox(height: 10));
    }
    if (tipo.necesitaAlto || formula == 'por_volumen') {
      campos.add(_campoMedida('Alto / Grosor (cm)', _alto, (v) => setState(() { _alto = v; _resultado = null; })));
      campos.add(const SizedBox(height: 10));
    }
    if (tipo.necesitaPeso || formula == 'por_kg') {
      campos.add(_campoMedida('Peso (kg)', _peso, (v) => setState(() { _peso = v; _resultado = null; })));
      campos.add(const SizedBox(height: 10));
    }
    if (tipo.necesitaMetros || formula == 'por_metro') {
      campos.add(_campoMedida('Metros lineales', _metros, (v) => setState(() { _metros = v; _resultado = null; })));
      campos.add(const SizedBox(height: 10));
    }
    if (tipo.necesitaHoras || formula == 'por_hora') {
      campos.add(_campoMedida('Horas de trabajo', _horas, (v) => setState(() { _horas = v; _resultado = null; })));
      campos.add(const SizedBox(height: 10));
    }
    if (tipo.necesitaMinutos || formula == 'por_minuto') {
      campos.add(_campoMedida('Minutos', _minutos, (v) => setState(() { _minutos = v; _resultado = null; })));
      campos.add(const SizedBox(height: 10));
    }

    return Column(children: campos);
  }

  // ── SECCIÓN: MATERIAL ─────────────────────────────
  Widget _buildMaterial() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Toggle: cliente trae material
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Cliente trae el material', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text('No suma costo de material', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      ]),
      Switch(value: _clienteTreMaterial,
        onChanged: (v) => setState(() { _clienteTreMaterial = v; _resultado = null; }),
        activeColor: AppColors.verde),
    ]),

    if (!_clienteTreMaterial) ...[
      const SizedBox(height: 12),
      const Divider(height: 1),
      const SizedBox(height: 12),

      // Toggle: inventario o manual
      Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => setState(() => _usarInventario = true),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _usarInventario ? AppColors.azul : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _usarInventario ? AppColors.azul : AppColors.grisBorde)),
            child: Column(children: [
              Icon(Icons.warehouse_outlined, size: 16,
                color: _usarInventario ? Colors.white : AppColors.textoSecundario),
              Text('Del inventario', style: TextStyle(fontSize: 11,
                color: _usarInventario ? Colors.white : AppColors.textoSecundario,
                fontWeight: FontWeight.w600)),
            ])))),
        const SizedBox(width: 8),
        Expanded(child: GestureDetector(
          onTap: () => setState(() => _usarInventario = false),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: !_usarInventario ? AppColors.azul : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: !_usarInventario ? AppColors.azul : AppColors.grisBorde)),
            child: Column(children: [
              Icon(Icons.edit_outlined, size: 16,
                color: !_usarInventario ? Colors.white : AppColors.textoSecundario),
              Text('Captura manual', style: TextStyle(fontSize: 11,
                color: !_usarInventario ? Colors.white : AppColors.textoSecundario,
                fontWeight: FontWeight.w600)),
            ])))),
      ]),
      const SizedBox(height: 12),

      if (_usarInventario) ...[
        // Dropdown de inventario
        if (_materialesInv.isEmpty)
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(8)),
            child: const Text('No hay materiales en inventario. Usa captura manual.',
              style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)))
        else
          DropdownButtonFormField<String>(
            value: _materialInvSel?['id'] as String?,
            decoration: const InputDecoration(
              labelText: 'Seleccionar del inventario',
              border: OutlineInputBorder(), isDense: true,
              prefixIcon: Icon(Icons.search, size: 18)),
            items: [
              const DropdownMenuItem<String>(value: null,
                child: Text('Sin material', style: TextStyle(fontSize: 13))),
              ..._materialesInv.map((m) => DropdownMenuItem<String>(
                value: m['id'] as String,
                child: Row(children: [
                  Expanded(child: Text(m['nombre'] ?? '',
                    style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Text('\$${((m['costo_unitario'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.verde,
                      fontWeight: FontWeight.w700)),
                ]))),
            ],
            onChanged: (id) => setState(() {
              _materialInvSel = id == null ? null
                : _materialesInv.firstWhere((m) => m['id'] == id);
              _resultado = null;
            })),
        if (_materialInvSel != null) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.verde.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon((_materialInvSel!['stock_actual'] as int? ?? 0) > 0
                ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                size: 16,
                color: (_materialInvSel!['stock_actual'] as int? ?? 0) > 0
                  ? AppColors.verde : AppColors.rojo),
              const SizedBox(width: 6),
              Text('Stock: ${_materialInvSel!['stock_actual']} ${_materialInvSel!['unidad'] ?? 'pzas'}  |  '
                'Costo: \$${((_materialInvSel!['costo_unitario'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}/pza',
                style: const TextStyle(fontSize: 11, color: AppColors.textoPrincipal)),
            ])),
        ],
      ] else ...[
        // Captura manual
        Row(children: [
          Expanded(child: TextFormField(
            initialValue: _materialLibreNombre,
            decoration: const InputDecoration(
              labelText: 'Nombre del material',
              hintText: 'Ej: Cedro, Aluminio 6061...',
              border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => setState(() { _materialLibreNombre = v; _resultado = null; }),
            style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: TextFormField(
            initialValue: _materialLibrePrecio > 0 ? _materialLibrePrecio.toStringAsFixed(2) : '',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: const InputDecoration(
              labelText: 'Precio',
              prefixText: r'$',
              border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => setState(() {
              _materialLibrePrecio = double.tryParse(v) ?? 0;
              _resultado = null;
            }),
            style: const TextStyle(fontSize: 13))),
        ]),
        const SizedBox(height: 6),
        const Text('El precio es por unidad/pieza del material.',
          style: TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
      ],
    ],
  ]);

  // ── SECCIÓN: CANTIDAD Y EXTRAS ────────────────────
  Widget _buildCantidadExtras() {
    final cfg = _config!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Cantidad
      Row(children: [
        const Text('Cantidad:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(
          onPressed: () => setState(() { if (_cantidad > 1) { _cantidad--; _resultado = null; } }),
          icon: const Icon(Icons.remove_circle_outline, color: AppColors.azul)),
        Text('$_cantidad', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        IconButton(
          onPressed: () => setState(() { _cantidad++; _resultado = null; }),
          icon: const Icon(Icons.add_circle_outline, color: AppColors.azul)),
      ]),

      if (cfg.acabados.isNotEmpty) ...[
        const Divider(height: 16),
        const Text('Acabado:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8,
          children: cfg.acabados.map((a) => GestureDetector(
            onTap: () => setState(() { _acabadoSel = a; _resultado = null; }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _acabadoSel?.id == a.id ? AppColors.azul : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _acabadoSel?.id == a.id ? AppColors.azul : AppColors.grisBorde)),
              child: Text('${a.nombre} ${a.precio > 0 ? "(+\$${a.precio.toStringAsFixed(0)})" : ""}',
                style: TextStyle(fontSize: 11,
                  color: _acabadoSel?.id == a.id ? Colors.white : AppColors.textoPrincipal,
                  fontWeight: FontWeight.w500))))).toList()),
      ],

      if (cfg.extras.isNotEmpty) ...[
        const Divider(height: 16),
        const Text('Extras:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...cfg.extras.map((e) => CheckboxListTile(
          value: e.seleccionado,
          onChanged: (v) => setState(() { e.seleccionado = v ?? false; _resultado = null; }),
          title: Text(e.nombre, style: const TextStyle(fontSize: 13)),
          subtitle: Text('+${_fmt.format(e.precio)}',
            style: const TextStyle(fontSize: 11, color: AppColors.verde)),
          activeColor: AppColors.azul, dense: true,
          contentPadding: EdgeInsets.zero)),
      ],

      const Divider(height: 16),
      // IVA toggle
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Incluir IVA 16%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('Para clientes con factura', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ]),
        Switch(value: _aplicarIva,
          onChanged: (v) => setState(() { _aplicarIva = v; _resultado = null; }),
          activeColor: AppColors.azul),
      ]),
    ]);
  }

  // ── RESULTADO ─────────────────────────────────────
  Widget _widgetResultado(ResultadoSimulador r) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.azul.withOpacity(0.3), width: 1.5)),
    child: Column(children: [
      // Header azul
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: AppColors.azul,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PRECIO ESTIMADO', style: TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 1)),
            if (r.incluyeIva) Text('Sin IVA: ${_fmt.format(r.subtotal)}',
              style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmt.format(r.total), style: const TextStyle(fontSize: 28,
              fontWeight: FontWeight.w800, color: Colors.white)),
            if (r.incluyeIva) Text('IVA: +${_fmt.format(r.iva)}',
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
            if (_cantidad > 1) Text('${_fmt.format(r.total / _cantidad)}/pieza',
              style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ]),
        ])),

      // Desglose
      Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Desglose:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textoSecundario)),
        const SizedBox(height: 8),
        ...r.desglose.entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(e.key, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            Text(e.value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: AppColors.textoPrincipal)),
          ]))),
      ])),

      // Descripción editable
      Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(height: 1),
        const SizedBox(height: 10),
        const Text('Descripción para cotización:',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textoSecundario)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _descripcionEditable,
          maxLines: 4, minLines: 2,
          onChanged: (v) => setState(() => _descripcionEditable = v),
          decoration: InputDecoration(
            hintText: 'Descripción del trabajo...',
            filled: true, fillColor: AppColors.gris,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          style: const TextStyle(fontSize: 12)),
      ])),

      // Botones
      Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: Column(children: [
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              final rFinal = ResultadoSimulador(
                servicio: r.servicio, emoji: r.emoji,
                descripcion: _descripcionEditable,
                maquila: r.maquila, extras: r.extras, acabado: r.acabado,
                costoMaterial: r.costoMaterial, subtotal: r.subtotal,
                iva: r.iva, total: r.total, desglose: r.desglose,
                incluyeIva: r.incluyeIva, materialNombre: r.materialNombre);
              widget.onAgregar(rFinal);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.add_shopping_cart_outlined, color: Colors.white, size: 16),
            label: const Text('Agregar al carrito',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.verde,
              padding: const EdgeInsets.symmetric(vertical: 12)))),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              final rFinal = ResultadoSimulador(
                servicio: r.servicio, emoji: r.emoji,
                descripcion: _descripcionEditable,
                maquila: r.maquila, extras: r.extras, acabado: r.acabado,
                costoMaterial: r.costoMaterial, subtotal: r.subtotal,
                iva: r.iva, total: r.total, desglose: r.desglose,
                incluyeIva: r.incluyeIva, materialNombre: r.materialNombre);
              widget.onAgregar(rFinal);
              Navigator.pushReplacement(context, MaterialPageRoute(
                builder: (_) => CotizarScreen(carritoSimulador: [rFinal])));
            },
            icon: const Icon(Icons.description_outlined, color: Colors.white, size: 16),
            label: const Text('Cotizar ahora',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.naranja,
              padding: const EdgeInsets.symmetric(vertical: 12)))),
      ])),
    ]));

  // ── HELPERS ──────────────────────────────────────
  Widget _seccionCard(String titulo, Widget child) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: AppColors.azul))),
      const Divider(height: 1),
      Padding(padding: const EdgeInsets.all(14), child: child),
    ]));

  Widget _campoMedida(String label, double val, void Function(double) onChange) =>
    TextFormField(
      initialValue: val > 0 ? val.toStringAsFixed(val % 1 == 0 ? 0 : 2) : '',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(labelText: label,
        border: const OutlineInputBorder(), isDense: true),
      onChanged: (v) => onChange(double.tryParse(v) ?? 0),
      style: const TextStyle(fontSize: 13));

  void _nuevoTipoTrabajo() {
    final nombreCtrl = TextEditingController();
    String formula = 'por_area';
    bool necesitaAlto = false;

    final formulas = [
      {'v': 'por_area', 'l': 'Por m²', 'd': 'Largo × Ancho × Tarifa/m²'},
      {'v': 'por_volumen', 'l': 'Por volumen', 'd': 'L×A×Alto × Factor → Rangos'},
      {'v': 'por_hora', 'l': 'Por hora', 'd': 'Horas × Tarifa/hora'},
      {'v': 'por_pieza', 'l': 'Por pieza', 'd': 'Cantidad × Precio/pieza'},
      {'v': 'por_minuto', 'l': 'Por minuto', 'd': 'Minutos × Tarifa/minuto'},
      {'v': 'por_metro', 'l': 'Por metro', 'd': 'Metros lineales × Tarifa/m'},
      {'v': 'precio_fijo', 'l': 'Precio fijo', 'd': 'Monto fijo negociado'},
      {'v': 'por_kg', 'l': 'Por kg', 'd': 'Peso × Tarifa/kg'},
      {'v': 'por_diseno', 'l': 'Diseño', 'd': 'Simple / Media / Alta / Premium'},
    ];

    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) => Container(
        height: MediaQuery.of(ctx).size.height * 0.8,
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(children: [
          Container(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Nuevo modo de trabajo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              GestureDetector(onTap: () => Navigator.pop(ctx),
                child: const Icon(Icons.close)),
            ])),
          const Divider(height: 1),
          Expanded(child: SingleChildScrollView(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(controller: nombreCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del modo *',
                  hintText: 'Ej: Corte de aluminio, Fresado CNC...',
                  border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 16),
              const Text('¿Cómo se cobra?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...formulas.map((f) => GestureDetector(
                onTap: () => setS(() => formula = f['v']!),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: formula == f['v'] ? AppColors.azulClaro : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: formula == f['v'] ? AppColors.azul : AppColors.grisBorde)),
                  child: Row(children: [
                    Icon(formula == f['v']
                      ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: formula == f['v'] ? AppColors.azul : AppColors.grisBorde, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f['l']!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: formula == f['v'] ? AppColors.azul : AppColors.textoPrincipal)),
                      Text(f['d']!, style: const TextStyle(fontSize: 11,
                        color: AppColors.textoSecundario)),
                    ])),
                  ])))),
              if (formula == 'por_volumen') ...[
                const Divider(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Necesita medida de alto/grosor',
                    style: TextStyle(fontSize: 13)),
                  Switch(value: necesitaAlto, activeColor: AppColors.azul,
                    onChanged: (v) => setS(() => necesitaAlto = v)),
                ]),
              ],
              const SizedBox(height: 20),
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (nombreCtrl.text.trim().isEmpty) return;
                    await SimuladorDataService.crearTipoTrabajo({
                      'servicio_id': widget.servicio.id,
                      'nombre': nombreCtrl.text.trim(),
                      'formula': formula,
                      'factor': 1.0,
                      'necesita_largo': true,
                      'necesita_ancho': formula != 'por_hora' && formula != 'por_minuto' && formula != 'por_kg',
                      'necesita_alto': necesitaAlto || formula == 'por_volumen',
                      'necesita_horas': formula == 'por_hora',
                      'necesita_minutos': formula == 'por_minuto',
                      'necesita_metros': formula == 'por_metro',
                      'necesita_peso': formula == 'por_kg',
                      'descripcion_formula': formulas.firstWhere((f) => f['v'] == formula)['d'],
                    });
                    if (mounted) { Navigator.pop(ctx); _cargar(); }
                  },
                  icon: const Icon(Icons.save_outlined, color: Colors.white),
                  label: const Text('Crear modo de trabajo',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azul,
                    padding: const EdgeInsets.symmetric(vertical: 13)))),
            ]))),
        ]))));
  }
}
