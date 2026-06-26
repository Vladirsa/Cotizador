// lib/screens/simulador_screen.dart v3
// HETNA CNC — Simulador de costos
// Filosofía: vendedor experto — el usuario solo captura medidas, material, cantidad
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'cotizar_screen.dart';

// ══════════════════════════════════════════════════════
// MODELOS DE CONFIGURACIÓN
// ══════════════════════════════════════════════════════
class SimServicio {
  final String id, clave, nombre, emoji;
  final bool activo;
  final int orden;
  SimServicio({required this.id, required this.clave, required this.nombre,
    required this.emoji, required this.activo, required this.orden});
  factory SimServicio.fromJson(Map<String, dynamic> j) => SimServicio(
    id: j['id'], clave: j['clave'], nombre: j['nombre'],
    emoji: j['emoji'] ?? '⚙️', activo: j['activo'] ?? true, orden: j['orden'] ?? 0);
}

class SimMaterial {
  final String id, nombre;
  SimMaterial({required this.id, required this.nombre});
  factory SimMaterial.fromJson(Map<String, dynamic> j) =>
    SimMaterial(id: j['id'], nombre: j['nombre']);
}

class SimEspesor {
  final String id, nombre;
  final double? valorMm;
  SimEspesor({required this.id, required this.nombre, this.valorMm});
  factory SimEspesor.fromJson(Map<String, dynamic> j) => SimEspesor(
    id: j['id'], nombre: j['nombre'],
    valorMm: (j['valor_mm'] as num?)?.toDouble());
}

class SimTipoTrabajo {
  final String id, nombre;
  final double factor;
  SimTipoTrabajo({required this.id, required this.nombre, required this.factor});
  factory SimTipoTrabajo.fromJson(Map<String, dynamic> j) => SimTipoTrabajo(
    id: j['id'], nombre: j['nombre'],
    factor: (j['factor_complejidad'] as num?)?.toDouble() ?? 1.0);
}

class SimTarifa {
  final String id, clave, nombre;
  double valor;
  final String? unidad;
  SimTarifa({required this.id, required this.clave, required this.nombre,
    required this.valor, this.unidad});
  factory SimTarifa.fromJson(Map<String, dynamic> j) => SimTarifa(
    id: j['id'], clave: j['clave'], nombre: j['nombre'],
    valor: (j['valor'] as num?)?.toDouble() ?? 0, unidad: j['unidad']);
}

class SimRango {
  final String id;
  final double desde, hasta, precio;
  final String? descripcion;
  SimRango({required this.id, required this.desde, required this.hasta,
    required this.precio, this.descripcion});
  factory SimRango.fromJson(Map<String, dynamic> j) => SimRango(
    id: j['id'],
    desde: (j['indice_desde'] as num).toDouble(),
    hasta: (j['indice_hasta'] as num).toDouble(),
    precio: (j['precio'] as num).toDouble(),
    descripcion: j['descripcion']);
}

class SimExtra {
  final String id, nombre;
  double precio;
  final String tipoPrecio;
  bool seleccionado = false;
  SimExtra({required this.id, required this.nombre,
    required this.precio, required this.tipoPrecio});
  factory SimExtra.fromJson(Map<String, dynamic> j) => SimExtra(
    id: j['id'], nombre: j['nombre'],
    precio: (j['precio'] as num?)?.toDouble() ?? 0,
    tipoPrecio: j['tipo_precio'] ?? 'fijo');
}

class SimAcabado {
  final String id, nombre;
  double precio;
  final String tipoPrecio;
  SimAcabado({required this.id, required this.nombre,
    required this.precio, required this.tipoPrecio});
  factory SimAcabado.fromJson(Map<String, dynamic> j) => SimAcabado(
    id: j['id'], nombre: j['nombre'],
    precio: (j['precio'] as num?)?.toDouble() ?? 0,
    tipoPrecio: j['tipo_precio'] ?? 'fijo');
}

class SimConfig {
  final SimServicio servicio;
  final List<SimMaterial> materiales;
  final List<SimEspesor> espesores;
  final List<SimTipoTrabajo> tipos;
  final Map<String, SimTarifa> tarifas;
  final List<SimRango> rangos;
  final List<SimExtra> extras;
  final List<SimAcabado> acabados;
  SimConfig({required this.servicio, required this.materiales,
    required this.espesores, required this.tipos, required this.tarifas,
    required this.rangos, required this.extras, required this.acabados});

  double getTarifa(String clave) => tarifas[clave]?.valor ?? 0;

  double calcularPrecioRango(double indice) {
    for (final r in rangos) {
      if (indice >= r.desde && indice <= r.hasta) return r.precio;
    }
    return rangos.isNotEmpty ? rangos.last.precio : 0;
  }
}

// ══════════════════════════════════════════════════════
// SERVICIO DE DATOS
// ══════════════════════════════════════════════════════
class SimuladorDataService {
  static final _sb = Supabase.instance.client;

  static Future<List<SimServicio>> getServicios() async {
    final data = await _sb.from('sim_servicios').select()
      .eq('activo', true).order('orden');
    return (data as List).map((j) => SimServicio.fromJson(j)).toList();
  }

  // Obtener materiales del inventario para vincular precios
  static Future<List<Map<String, dynamic>>> getMaterialesInventario() async {
    try {
      final data = await _sb
        .from('inventario_bodega')
        .select('id, nombre, costo_unitario, unidad, categoria, stock_actual')
        .eq('activo', true)
        .order('nombre');
      return (data as List).cast<Map<String, dynamic>>();
    } catch (_) { return []; }
  }

  static Future<SimConfig> getConfig(String servicioId) async {
    final results = await Future.wait([
      _sb.from('sim_servicios').select().eq('id', servicioId).single(),
      _sb.from('sim_materiales').select().eq('servicio_id', servicioId).eq('activo', true).order('orden'),
      _sb.from('sim_espesores').select().eq('servicio_id', servicioId).eq('activo', true).order('orden'),
      _sb.from('sim_tipos_trabajo').select().eq('servicio_id', servicioId).eq('activo', true).order('orden'),
      _sb.from('sim_tarifas').select().eq('servicio_id', servicioId).eq('activo', true),
      _sb.from('sim_rangos').select().eq('servicio_id', servicioId).eq('activo', true).order('orden'),
      _sb.from('sim_extras').select().eq('servicio_id', servicioId).eq('activo', true).order('orden'),
      _sb.from('sim_acabados').select().eq('servicio_id', servicioId).eq('activo', true).order('orden'),
    ]);

    final tarifasMap = <String, SimTarifa>{};
    for (final j in (results[4] as List)) {
      final t = SimTarifa.fromJson(j);
      tarifasMap[t.clave] = t;
    }

    return SimConfig(
      servicio: SimServicio.fromJson(results[0] as Map<String, dynamic>),
      materiales: (results[1] as List).map((j) => SimMaterial.fromJson(j)).toList(),
      espesores: (results[2] as List).map((j) => SimEspesor.fromJson(j)).toList(),
      tipos: (results[3] as List).map((j) => SimTipoTrabajo.fromJson(j)).toList(),
      tarifas: tarifasMap,
      rangos: (results[5] as List).map((j) => SimRango.fromJson(j)).toList(),
      extras: (results[6] as List).map((j) => SimExtra.fromJson(j)).toList(),
      acabados: (results[7] as List).map((j) => SimAcabado.fromJson(j)).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════
// MODELO RESULTADO
// ══════════════════════════════════════════════════════
class ResultadoSimulador {
  final String servicio;
  final String emoji;
  final double maquila;
  final double extras;
  final double acabado;
  final double subtotal;
  final double iva;
  final double total;
  final String descripcion;
  final Map<String, String> desglose;
  final bool incluyeIva;

  ResultadoSimulador({
    required this.servicio, required this.emoji,
    required this.maquila, required this.extras,
    required this.acabado, required this.subtotal,
    this.iva = 0, required this.total,
    required this.descripcion, required this.desglose,
    this.incluyeIva = false,
  });

  double get totalConIva => incluyeIva ? subtotal + iva : subtotal;
}

// ══════════════════════════════════════════════════════
// PANTALLA PRINCIPAL
// ══════════════════════════════════════════════════════
class SimuladorScreen extends StatefulWidget {
  const SimuladorScreen({super.key});
  @override State<SimuladorScreen> createState() => _SimuladorScreenState();
}

class _SimuladorScreenState extends State<SimuladorScreen> {
  List<SimServicio> _servicios = [];
  bool _cargando = true;
  final List<ResultadoSimulador> _carrito = [];
  final _fmt = NumberFormat('\$#,##0', 'es_MX');

  double get _totalCarrito => _carrito.fold(0, (s, r) => s + r.total);

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final svcs = await SimuladorDataService.getServicios();
      if (mounted) setState(() { _servicios = svcs; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0.5,
        title: const Text('Simulador de costos',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
        actions: [
          if (_carrito.isNotEmpty)
            Padding(padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _enviarACotizacion,
                icon: const Icon(Icons.description_outlined, color: Colors.white, size: 16),
                label: Text('${_carrito.length} → Cotizar',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.azul,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)))),
        ]),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : _pantallaServicios(),
    );
  }

  Widget _pantallaServicios() => ListView(padding: const EdgeInsets.all(14), children: [
    // Carrito
    if (_carrito.isNotEmpty) ...[_widgetCarrito(), const SizedBox(height: 14)],

    // Banner
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.azul, Color(0xFF2d5a8e)]),
        borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Calcula el precio de tu trabajo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 4),
        const Text('Selecciona el tipo de servicio. Puedes combinar varios en una cotizacion.',
          style: TextStyle(fontSize: 12, color: Colors.white70)),
        if (_carrito.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Text('${_carrito.length} servicio${_carrito.length > 1 ? "s" : ""} — ${_fmt.format(_totalCarrito)}',
              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600))),
        ],
      ])),

    const SizedBox(height: 14),

    // Lista de servicios
    ..._servicios.map((s) => GestureDetector(
      onTap: () => _abrirServicio(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
            blurRadius: 6, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.azulClaro, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(s.emoji,
              style: const TextStyle(fontSize: 24)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.nombre, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.azul)),
            if (s.clave == 'router')
              const Text('Corte 2D, grabado, talla 3D en madera/MDF',
                style: TextStyle(fontSize: 11, color: AppColors.textoSecundario))
            else if (s.clave == 'plasma')
              const Text('Corte en acero, celosias, figuras en lamina',
                style: TextStyle(fontSize: 11, color: AppColors.textoSecundario))
            else if (s.clave == 'laser_co2')
              const Text('Corte y grabado en MDF, acrilico, cuero',
                style: TextStyle(fontSize: 11, color: AppColors.textoSecundario))
            else
              Text(s.clave, style: const TextStyle(
                fontSize: 11, color: AppColors.textoSecundario)),
          ])),
          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textoSecundario),
        ]))))
  ]);

  // ── CARRITO ─────────────────────────────────────────
  Widget _widgetCarrito() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.verde.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Carrito (${_carrito.length})',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.verde)),
        TextButton(
          onPressed: () => setState(() => _carrito.clear()),
          child: const Text('Limpiar', style: TextStyle(fontSize: 11, color: AppColors.rojo))),
      ]),
      ..._carrito.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Text(e.value.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.value.servicio,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(e.value.descripcion,
              style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Text(_fmt.format(e.value.total),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.azul)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _carrito.removeAt(e.key)),
            child: const Icon(Icons.close, size: 16, color: AppColors.textoSecundario)),
        ]))),
      const Divider(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('TOTAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        Text(_fmt.format(_totalCarrito),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.azul)),
      ]),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _enviarACotizacion,
          icon: const Icon(Icons.description_outlined, color: Colors.white, size: 16),
          label: const Text('Crear cotizacion con estos servicios',
            style: TextStyle(color: Colors.white, fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.verde,
            padding: const EdgeInsets.symmetric(vertical: 10)))),
    ]));

  void _abrirServicio(SimServicio s) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _PantallaServicio(
        servicio: s,
        onAgregar: (resultado) {
          setState(() => _carrito.add(resultado));
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ ${resultado.servicio} agregado al carrito'),
            backgroundColor: AppColors.verde,
            duration: const Duration(seconds: 2)));
        })));
  }

  void _enviarACotizacion() {
    if (_carrito.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CotizarScreen(carritoSimulador: _carrito)));
  }
}

// ══════════════════════════════════════════════════════
// PANTALLA DE SERVICIO (calculadora)
// ══════════════════════════════════════════════════════
class _PantallaServicio extends StatefulWidget {
  final SimServicio servicio;
  final void Function(ResultadoSimulador) onAgregar;
  const _PantallaServicio({required this.servicio, required this.onAgregar});
  @override State<_PantallaServicio> createState() => _PantallaServicioState();
}

class _PantallaServicioState extends State<_PantallaServicio> {
  SimConfig? _config;
  bool _cargando = true;
  ResultadoSimulador? _resultado;
  bool _aplicarIva = true;
  static const double _ivaPct = 16.0;
  List<Map<String, dynamic>> _materialesInv = [];
  Map<String, dynamic>? _materialInvSel; // material del inventario seleccionado

  // Campos del formulario
  SimMaterial? _matSel;
  SimEspesor? _espSel;
  SimTipoTrabajo? _tipoSel;
  SimAcabado? _acabadoSel;
  double _largo = 60, _ancho = 60, _alto = 6;
  double _cantidad = 1;
  double _peso = 50, _horas = 3;
  bool _clienteTreMaterial = false;
  double _costoMaterialCliente = 0;

  final _fmt = NumberFormat('\$#,##0', 'es_MX');

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
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
        if (cfg.materiales.isNotEmpty) _matSel = cfg.materiales.first;
        if (cfg.espesores.isNotEmpty) _espSel = cfg.espesores.first;
        if (cfg.tipos.isNotEmpty) _tipoSel = cfg.tipos.first;
        if (cfg.acabados.isNotEmpty) _acabadoSel = cfg.acabados.first;
      });
    } catch (e) { if (mounted) setState(() => _cargando = false); }
  }

  // ── CALCULAR ────────────────────────────────────────
  void _calcular() {
    final cfg = _config!;
    final clave = widget.servicio.clave;
    double maquila = 0;
    double extrasTotal = 0;
    double acabadoTotal = 0;
    final desglose = <String, String>{};

    if (clave == 'plasma') {
      final area = (_largo / 100) * (_ancho / 100);
      final areaMin = cfg.getTarifa('area_minima_m2');
      final pedMin = cfg.getTarifa('pedido_minimo');

      // Determinar tarifa según material + calibre
      String claveTarifa = 'tarifa_m2_acero';
      if (_matSel?.nombre.toLowerCase().contains('inox') == true) {
        claveTarifa = 'tarifa_m2_inox';
      } else if (_matSel?.nombre.toLowerCase().contains('aluminio') == true) {
        claveTarifa = 'tarifa_m2_aluminio';
      }
      // Calibres gruesos (8, 10) cobran más
      if (_espSel != null) {
        final esp = _espSel!.nombre.toLowerCase();
        if (esp.contains('cal 8') || esp.contains('cal 10')) {
          // Calibre grueso: usar tarifa mayor
          final tarifaGruesa = cfg.getTarifa('tarifa_m2_cal10');
          if (tarifaGruesa > 0) claveTarifa = 'tarifa_m2_cal10';
        } else if (esp.contains('cal 12') || esp.contains('cal 14') || esp.contains('cal 16')) {
          final tarifaDelgada = cfg.getTarifa('tarifa_m2_cal12');
          if (tarifaDelgada > 0) claveTarifa = 'tarifa_m2_cal12';
        }
      }

      final tarifaM2 = cfg.getTarifa(claveTarifa);
      final tarifaPieza = cfg.getTarifa('tarifa_pieza');

      if (area >= areaMin) {
        maquila = tarifaM2 * area * _cantidad;
        desglose['Area'] = '${_largo}×${_ancho}cm = ${area.toStringAsFixed(3)} m²';
        desglose['Tarifa'] = '${_fmt.format(tarifaM2)}/m²';
      } else {
        maquila = tarifaPieza * _cantidad;
        desglose['Modo'] = 'Por pieza (area < ${areaMin}m²)';
        desglose['Tarifa'] = '${_fmt.format(tarifaPieza)}/pza';
      }
      if (maquila < pedMin) {
        desglose['Pedido minimo aplicado'] = _fmt.format(pedMin);
        maquila = pedMin;
      }

    } else if (clave == 'laser_co2') {
      final tarMin = cfg.getTarifa('tarifa_minuto');
      final pedMin = cfg.getTarifa('pedido_minimo');
      final factor = _tipoSel?.factor ?? 1.0;
      // Estimamos minutos por área (10 min/dm²)
      final area = (_largo / 10) * (_ancho / 10); // en dm²
      final minutos = area * factor * 2;
      maquila = tarMin * minutos * _cantidad;
      if (maquila < pedMin) maquila = pedMin;
      desglose['Area'] = '${_largo}×${_ancho} cm';
      desglose['Tipo'] = _tipoSel?.nombre ?? '';
      desglose['Tiempo estimado'] = '${minutos.toStringAsFixed(0)} min';
      desglose['Tarifa'] = '${_fmt.format(tarMin)}/min';

    } else if (clave == 'router') {
      final factor = _tipoSel?.factor ?? 1.0;
      final pedMin = cfg.getTarifa('pedido_minimo');
      final esCorte2D = _tipoSel?.nombre.contains('Corte 2D') == true;

      if (esCorte2D) {
        // Corte 2D: cobrar por área (m²) como plasma
        final areaM2 = (_largo / 100) * (_ancho / 100);
        final tarifaM2 = cfg.getTarifa('tarifa_m2_corte') > 0
          ? cfg.getTarifa('tarifa_m2_corte')
          : (cfg.getTarifa('tarifa_hoja_normal') / (1.22 * 2.44));
        maquila = tarifaM2 * areaM2 * _cantidad;
        desglose['Área'] = '${_largo}×${_ancho} cm = ${areaM2.toStringAsFixed(3)} m²';
        desglose['Tarifa corte'] = '${_fmt.format(tarifaM2)}/m²';
      } else {
        // Talla 3D / Relieve: cobrar por índice de volumen
        final volumen = _largo * _ancho * _alto;
        final indice = volumen * factor;
        maquila = cfg.calcularPrecioRango(indice) * _cantidad;
        desglose['Pieza'] = '${_largo}×${_ancho}×${_alto} cm';
        desglose['Tipo'] = _tipoSel?.nombre ?? '';
        desglose['Factor complejidad'] = '×${factor}';
        desglose['Índice'] = '${indice.toStringAsFixed(0)}';
        desglose['Rango aplicado'] = _fmt.format(cfg.calcularPrecioRango(indice));
      }

      if (maquila < pedMin) {
        desglose['Pedido mínimo aplicado'] = _fmt.format(pedMin);
        maquila = pedMin;
      }

    } else if (clave == 'impresion_3d') {
      final tarGramo = cfg.getTarifa('tarifa_gramo');
      final tarHora = cfg.getTarifa('tarifa_hora');
      final pedMin = cfg.getTarifa('pedido_minimo');
      maquila = ((tarGramo * _peso) + (tarHora * _horas)) * _cantidad;
      if (maquila < pedMin) maquila = pedMin;
      desglose['Material'] = '${_matSel?.nombre ?? ""} ${_peso.toStringAsFixed(0)}g';
      desglose['Horas'] = '${_horas.toStringAsFixed(1)} hrs';

    } else if (clave == 'carpinteria') {
      final tarHora = cfg.getTarifa('tarifa_hora');
      final factor = cfg.getTarifa('factor_material');
      final costoMat = _clienteTreMaterial ? 0 : (_costoMaterialCliente * factor);
      final horas = (_largo * _ancho / 3600) * (_tipoSel?.factor ?? 1.0) * 4;
      maquila = (tarHora * horas) + costoMat;
      desglose['Medida'] = '${_largo}×${_ancho} cm';
      desglose['Tipo'] = _tipoSel?.nombre ?? '';
      if (!_clienteTreMaterial && _costoMaterialCliente > 0) {
        desglose['Material ×${factor}'] = _fmt.format(costoMat);
      }

    } else if (clave == 'herreria') {
      final tarML = cfg.getTarifa('tarifa_m_lineal');
      final pedMin = cfg.getTarifa('pedido_minimo');
      final perimetro = 2 * (_largo + _ancho) / 100; // metros
      maquila = tarML * perimetro * _cantidad;
      if (maquila < pedMin) maquila = pedMin;
      desglose['Medida'] = '${_largo}×${_ancho} cm';
      desglose['Perimetro'] = '${perimetro.toStringAsFixed(2)} ml';

    } else if (clave == 'diseno') {
      final min2d = cfg.getTarifa('tarifa_2d_min');
      final max2d = cfg.getTarifa('tarifa_2d_max');
      final min3d = cfg.getTarifa('tarifa_3d_min');
      final max3d = cfg.getTarifa('tarifa_3d_max');
      final es3d = _tipoSel?.nombre.contains('3D') == true;
      final factor = _tipoSel?.factor ?? 1.0;
      if (es3d) {
        maquila = min3d + ((max3d - min3d) * (factor - 1) / 5);
      } else {
        maquila = min2d + ((max2d - min2d) * (factor - 1) / 3);
      }
      desglose['Tipo'] = _tipoSel?.nombre ?? '';
    }

    // Extras seleccionados
    for (final e in cfg.extras.where((ex) => ex.seleccionado)) {
      double precioExtra = e.precio;
      if (e.tipoPrecio == 'por_pieza') precioExtra *= _cantidad;
      if (e.tipoPrecio == 'porcentaje') precioExtra = maquila * e.precio / 100;
      extrasTotal += precioExtra;
      desglose['Extra: ${e.nombre}'] = _fmt.format(precioExtra);
    }

    // Acabado
    if (_acabadoSel != null && _acabadoSel!.precio > 0) {
      acabadoTotal = _acabadoSel!.tipoPrecio == 'por_pieza'
        ? _acabadoSel!.precio * _cantidad : _acabadoSel!.precio;
      desglose['Acabado: ${_acabadoSel!.nombre}'] = _fmt.format(acabadoTotal);
    }

    if (_cantidad > 1) desglose['Cantidad'] = '${_cantidad.toInt()} piezas';

    // Agregar costo de material del inventario si está seleccionado
    double costoMaterialInv = 0;
    if (_materialInvSel != null && !_clienteTreMaterial) {
      costoMaterialInv = ((_materialInvSel!['costo_unitario'] as num?)?.toDouble() ?? 0) * _cantidad;
      if (costoMaterialInv > 0) {
        desglose['Material (${_materialInvSel!['nombre']})'] = _fmt.format(costoMaterialInv);
      }
    }

    final subtotal = maquila + extrasTotal + acabadoTotal + costoMaterialInv;
    final iva = _aplicarIva ? subtotal * _ivaPct / 100 : 0.0;
    final total = subtotal + iva;

    // Descripción para cotización
    final desc = '${_matSel?.nombre ?? ""} ${_largo}×${_ancho}cm'
      '${_tipoSel != null ? " — ${_tipoSel!.nombre}" : ""}';

    if (_aplicarIva) {
      desglose['IVA 16%'] = _fmt.format(iva);
    }

    setState(() => _resultado = ResultadoSimulador(
      servicio: widget.servicio.nombre,
      emoji: widget.servicio.emoji,
      maquila: maquila,
      extras: extrasTotal,
      acabado: acabadoTotal,
      subtotal: subtotal,
      iva: iva,
      total: total,
      descripcion: desc,
      desglose: desglose,
      incluyeIva: _aplicarIva,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0.5,
        title: Text('${widget.servicio.emoji} ${widget.servicio.nombre}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.azul))),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : _config == null
          ? const Center(child: Text('Error al cargar configuracion'))
          : ListView(padding: const EdgeInsets.all(14), children: [
              ..._buildCampos(),
              const SizedBox(height: 16),
              _btnCalcular(),
              if (_resultado != null) ...[
                const SizedBox(height: 16),
                _widgetResultado(_resultado!),
              ],
              const SizedBox(height: 40),
            ]));
  }

  // ── CAMPOS SEGÚN TIPO ───────────────────────────────
  List<Widget> _buildCampos() {
    final cfg = _config!;
    final clave = widget.servicio.clave;
    final campos = <Widget>[];

    // ── Material ──
    if (cfg.materiales.isNotEmpty) {
      campos.add(_seccion('Tipo de material'));
      campos.add(_chipSelector<SimMaterial>(
        cfg.materiales, _matSel, (m) => m.nombre,
        (m) => setState(() => _matSel = m)));
      campos.add(const SizedBox(height: 8));
    }

    // ── Material del inventario (con precio real) ──
    if (_materialesInv.isNotEmpty) {
      campos.add(Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Material del inventario',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text(_materialInvSel != null
          ? '${_fmt.format((_materialInvSel!['costo_unitario'] as num?)?.toDouble() ?? 0)}'
          : 'Sin vincular',
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: _materialInvSel != null ? AppColors.verde : AppColors.textoSecundario)),
      ]));
      campos.add(const SizedBox(height: 6));
      campos.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.grisBorde),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white),
        child: DropdownButton<String>(
          value: _materialInvSel?['id'] as String?,
          isExpanded: true,
          underline: const SizedBox(),
          hint: const Text('Seleccionar material del inventario (opcional)',
            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          items: [
            const DropdownMenuItem<String>(value: null,
              child: Text('Sin vincular', style: TextStyle(fontSize: 12))),
            ..._materialesInv.map((m) => DropdownMenuItem<String>(
              value: m['id'] as String,
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(m['nombre'] ?? '',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis)),
                Text(_fmt.format((m['costo_unitario'] as num?)?.toDouble() ?? 0),
                  style: const TextStyle(fontSize: 11, color: AppColors.verde,
                    fontWeight: FontWeight.w600)),
              ]))),
          ],
          onChanged: (id) => setState(() {
            _materialInvSel = id == null ? null
              : _materialesInv.firstWhere((m) => m['id'] == id);
          }))));
      // Mostrar stock disponible
      if (_materialInvSel != null) {
        final stock = _materialInvSel!['stock_actual'] ?? 0;
        campos.add(Padding(padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(stock > 0 ? Icons.check_circle_outline : Icons.warning_amber_outlined,
              size: 14,
              color: stock > 0 ? AppColors.verde : AppColors.rojo),
            const SizedBox(width: 4),
            Text('Stock disponible: $stock ${_materialInvSel!['unidad'] ?? 'pzas'}',
              style: TextStyle(fontSize: 11,
                color: stock > 0 ? AppColors.verde : AppColors.rojo)),
          ])));
      }
      campos.add(const SizedBox(height: 12));
    }

    // ── Espesor / Calibre ──
    if (cfg.espesores.isNotEmpty) {
      campos.add(_seccion('Calibre / Espesor'));
      campos.add(_chipSelector<SimEspesor>(
        cfg.espesores, _espSel, (e) => e.nombre,
        (e) => setState(() => _espSel = e)));
      campos.add(const SizedBox(height: 12));
    }

    // ── Tipo de trabajo ──
    if (cfg.tipos.isNotEmpty) {
      campos.add(_seccion(clave == 'carpinteria' || clave == 'herreria'
        ? 'Tipo de proyecto' : 'Tipo de trabajo'));
      campos.add(_chipSelector<SimTipoTrabajo>(
        cfg.tipos, _tipoSel, (t) => t.nombre,
        (t) => setState(() => _tipoSel = t)));
      campos.add(const SizedBox(height: 12));
    }

    // ── Dimensiones ──
    if (clave != 'diseno') {
      campos.add(_seccion(clave == 'impresion_3d' ? 'Dimensiones de la pieza' : 'Medidas (cm)'));

      if (clave == 'impresion_3d') {
        campos.add(Row(children: [
          Expanded(child: _campo('Largo (cm)', _largo, (v) => setState(() => _largo = v))),
          const SizedBox(width: 8),
          Expanded(child: _campo('Ancho (cm)', _ancho, (v) => setState(() => _ancho = v))),
          const SizedBox(width: 8),
          Expanded(child: _campo('Alto (cm)', _alto, (v) => setState(() => _alto = v))),
        ]));
        campos.add(const SizedBox(height: 10));
        campos.add(Row(children: [
          Expanded(child: _campo('Peso aprox (g)', _peso, (v) => setState(() => _peso = v))),
          const SizedBox(width: 8),
          Expanded(child: _campo('Horas impresion', _horas, (v) => setState(() => _horas = v))),
        ]));
      } else if (clave == 'router') {
        campos.add(Row(children: [
          Expanded(child: _campo('Largo (cm)', _largo, (v) => setState(() => _largo = v))),
          const SizedBox(width: 8),
          Expanded(child: _campo('Ancho (cm)', _ancho, (v) => setState(() => _ancho = v))),
          const SizedBox(width: 8),
          Expanded(child: _campo('Espesor (cm)', _alto, (v) => setState(() => _alto = v))),
        ]));
        if (_tipoSel != null) {
          final vol = _largo * _ancho * _alto;
          final idx = vol * _tipoSel!.factor;
          final precio = _config!.calcularPrecioRango(idx);
          campos.add(Padding(padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.azulClaro, borderRadius: BorderRadius.circular(8)),
              child: Text(
                'Volumen: ${vol.toStringAsFixed(0)} cm³ × ${_tipoSel!.factor} = indice ${idx.toStringAsFixed(0)} → ${_fmt.format(precio)}',
                style: const TextStyle(fontSize: 11, color: AppColors.azul)))));
        }
      } else {
        campos.add(Row(children: [
          Expanded(child: _campo('Largo (cm)', _largo, (v) => setState(() => _largo = v))),
          const SizedBox(width: 8),
          Expanded(child: _campo('Ancho (cm)', _ancho, (v) => setState(() => _ancho = v))),
        ]));
      }
      campos.add(const SizedBox(height: 12));
    }

    // ── Material del cliente / maquila ──
    if (['plasma','laser_co2','router'].contains(clave)) {
      campos.add(_seccion('Material'));
      campos.add(_toggle('Cliente trae el material (solo maquila)',
        _clienteTreMaterial, (v) => setState(() => _clienteTreMaterial = v)));
      if (!_clienteTreMaterial && clave == 'carpinteria') {
        campos.add(const SizedBox(height: 8));
        campos.add(_campo('Costo del material (\$)', _costoMaterialCliente,
          (v) => setState(() => _costoMaterialCliente = v)));
      }
      campos.add(const SizedBox(height: 12));
    }

    // ── Acabados ──
    if (cfg.acabados.isNotEmpty) {
      campos.add(_seccion('Acabado'));
      campos.add(_chipSelector<SimAcabado>(
        cfg.acabados, _acabadoSel, (a) => a.nombre,
        (a) => setState(() => _acabadoSel = a)));
      campos.add(const SizedBox(height: 12));
    }

    // ── Extras ──
    if (cfg.extras.isNotEmpty) {
      campos.add(_seccion('Extras (opcional)'));
      campos.add(Wrap(spacing: 6, runSpacing: 6,
        children: cfg.extras.map((ex) {
          return GestureDetector(
            onTap: () => setState(() => ex.seleccionado = !ex.seleccionado),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: ex.seleccionado ? AppColors.azul : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ex.seleccionado ? AppColors.azul : AppColors.grisBorde)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (ex.seleccionado)
                  const Icon(Icons.check, size: 12, color: Colors.white),
                if (ex.seleccionado) const SizedBox(width: 4),
                Text(ex.precio > 0
                  ? '${ex.nombre} (${_fmt.format(ex.precio)})'
                  : ex.nombre,
                  style: TextStyle(fontSize: 11,
                    color: ex.seleccionado ? Colors.white : AppColors.textoSecundario,
                    fontWeight: ex.seleccionado ? FontWeight.w600 : FontWeight.normal)),
              ])));
        }).toList()));
      campos.add(const SizedBox(height: 12));
    }

    // ── Cantidad ──
    campos.add(_seccion('Cantidad'));
    campos.add(_campo('Piezas', _cantidad, (v) => setState(() => _cantidad = v)));
    campos.add(const SizedBox(height: 4));

    // ── IVA ──
    campos.add(Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('Incluir IVA 16% en el precio',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      Switch(
        value: _aplicarIva,
        onChanged: (v) => setState(() => _aplicarIva = v),
        activeColor: AppColors.azul),
    ]));

    return campos;
  }

  // ── RESULTADO ───────────────────────────────────────
  Widget _widgetResultado(ResultadoSimulador r) => Container(
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.azul.withOpacity(0.3), width: 1.5)),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.azul,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PRECIO ESTIMADO',
              style: TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 1)),
            if (r.incluyeIva)
              Text('Sin IVA: ${_fmt.format(r.subtotal)}',
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmt.format(r.total),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
            if (r.incluyeIva)
              Text('IVA 16%: +${_fmt.format(r.iva)}',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
            if (_cantidad > 1)
              Text('${_fmt.format(r.total / _cantidad)} por pieza',
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ]),
        ])),

      Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        // Desglose
        if (r.maquila > 0) _lineaDesglose('Maquila', r.maquila),
        if (r.acabado > 0) _lineaDesglose('Acabado', r.acabado),
        if (r.extras > 0) _lineaDesglose('Extras', r.extras),
        const Divider(height: 16),
        ...r.desglose.entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(e.key, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            Text(e.value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ]))),
      ])),

      // Aviso
      Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(8)),
          child: const Text(
            'Precio estimado. Confirma con el cliente antes de cerrar la venta.',
            style: TextStyle(fontSize: 10, color: AppColors.ambar)))),

      // Botón agregar
      Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => widget.onAgregar(r),
            icon: const Icon(Icons.add_shopping_cart_outlined, color: Colors.white, size: 16),
            label: const Text('Agregar al carrito',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.verde,
              padding: const EdgeInsets.symmetric(vertical: 12))))),
    ]));

  Widget _lineaDesglose(String label, double valor) =>
    Padding(padding: const EdgeInsets.only(bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(_fmt.format(valor),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.azul)),
      ]));

  Widget _btnCalcular() => SizedBox(width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: _calcular,
      icon: const Icon(Icons.calculate_outlined, color: Colors.white, size: 18),
      label: const Text('Calcular precio estimado',
        style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.azul,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))));

  // ── WIDGETS REUTILIZABLES ───────────────────────────
  Widget _chipSelector<T>(List<T> items, T? sel, String Function(T) label,
      void Function(T) onTap) =>
    Wrap(spacing: 6, runSpacing: 6,
      children: items.map((item) {
        final active = sel == item;
        return GestureDetector(
          onTap: () => onTap(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active ? AppColors.azul : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? AppColors.azul : AppColors.grisBorde)),
            child: Text(label(item), style: TextStyle(
              fontSize: 11,
              color: active ? Colors.white : AppColors.textoSecundario,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal))));
      }).toList());

  Widget _campo(String label, double valor, void Function(double) onChange) =>
    TextFormField(
      initialValue: valor % 1 == 0 ? valor.toInt().toString() : valor.toString(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(
        labelText: label, isDense: true,
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      onChanged: (v) { final d = double.tryParse(v); if (d != null) onChange(d); });

  Widget _toggle(String label, bool val, void Function(bool) onChanged) =>
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(child: Text(label,
        style: const TextStyle(fontSize: 12, color: AppColors.textoPrincipal))),
      Switch(value: val, onChanged: onChanged, activeColor: AppColors.azul),
    ]);

  Widget _seccion(String t) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(
      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textoPrincipal)));
}
