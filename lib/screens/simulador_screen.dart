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

  factory SimTipoTrabajo.fromJson(Map<String, dynamic> j) {
    final nombre = (j['nombre'] as String? ?? '').toLowerCase();
    // Inferir fórmula del nombre si no está en BD
    String formula = j['formula'] as String? ?? _inferirFormula(nombre);
    return SimTipoTrabajo(
      id: j['id'], nombre: j['nombre'],
      formula: formula,
      factor: (j['factor_complejidad'] as num? ?? j['factor'] as num?)?.toDouble() ?? 1.0,
      necesitaLargo: j['necesita_largo'] ?? _necesitaLargo(formula),
      necesitaAncho: j['necesita_ancho'] ?? _necesitaAncho(formula),
      necesitaAlto: j['necesita_alto'] ?? _necesitaAlto(formula, nombre),
      necesitaPeso: j['necesita_peso'] ?? (formula == 'por_kg'),
      necesitaMetros: j['necesita_metros'] ?? (formula == 'por_metro'),
      necesitaHoras: j['necesita_horas'] ?? (formula == 'por_hora'),
      necesitaMinutos: j['necesita_minutos'] ?? (formula == 'por_minuto'),
      descripcionFormula: j['descripcion_formula'] ?? _descFormula(formula));
  }

  static String _inferirFormula(String nombre) {
    if (nombre.contains('diseño') || nombre.contains('diseno') || nombre.contains('design')) return 'por_diseno';
    if (nombre.contains('hora') || nombre.contains('hr ') || nombre.contains('impresion') || nombre.contains('impresión')) return 'por_hora';
    if (nombre.contains('minuto') || nombre.contains('min ') || nombre.contains('laser') || nombre.contains('láser')) return 'por_minuto';
    if (nombre.contains('metro') || nombre.contains('lineal') || nombre.contains('herrer')) return 'por_metro';
    if (nombre.contains('kg') || nombre.contains('kilo') || nombre.contains('peso')) return 'por_kg';
    if (nombre.contains('pieza') || nombre.contains('pza') || nombre.contains('fijo')) return 'por_pieza';
    if (nombre.contains('3d') || nombre.contains('relieve') || nombre.contains('talla') ||
        nombre.contains('escultura') || nombre.contains('rotativo') || nombre.contains('torneado')) return 'por_volumen';
    return 'por_area'; // default
  }

  static bool _necesitaLargo(String f) => f != 'por_diseno' && f != 'precio_fijo';
  static bool _necesitaAncho(String f) => f == 'por_area' || f == 'por_volumen';
  static bool _necesitaAlto(String f, String nombre) =>
    f == 'por_volumen' || nombre.contains('3d') || nombre.contains('relieve') ||
    nombre.contains('talla') || nombre.contains('escultura');

  static String _descFormula(String f) {
    switch (f) {
      case 'por_area':    return 'Largo × Ancho → m² × Tarifa';
      case 'por_volumen': return 'L × A × Alto × Factor → Tabla rangos';
      case 'por_hora':    return 'Horas × Tarifa/hora';
      case 'por_minuto':  return 'Minutos × Tarifa/minuto';
      case 'por_metro':   return 'Metros × Tarifa/metro';
      case 'por_kg':      return 'Peso × Tarifa/kg';
      case 'por_pieza':   return 'Cantidad × Precio/pieza';
      case 'por_diseno':  return 'Simple / Media / Alta / Premium';
      case 'precio_fijo': return 'Precio fijo negociado';
      default:            return 'Largo × Ancho → m² × Tarifa';
    }
  }
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
  // Análisis financiero (Capa 5)
  final double costoTotal;
  final double pvMinimo;
  final double pvRecomendado;
  final double utilidad;
  final double margenReal;
  final double gananciaHora;
  final double tiempoHoras;

  ResultadoSimulador({
    required this.servicio, required this.emoji, required this.descripcion,
    required this.maquila, this.extras = 0, this.acabado = 0,
    this.costoMaterial = 0, required this.subtotal,
    this.iva = 0, required this.total, required this.desglose,
    this.incluyeIva = false, this.materialNombre,
    this.costoTotal = 0, this.pvMinimo = 0, this.pvRecomendado = 0,
    this.utilidad = 0, this.margenReal = 0, this.gananciaHora = 0,
    this.tiempoHoras = 0});
}

// ══════════════════════════════════════════════════════
// DATA SERVICE
// ══════════════════════════════════════════════════════
// ── MODELO COSTOS DEL TALLER ─────────────────────────────
class CostosTaller {
  final double costoHoraTaller;   // CI: costo indirecto por hora
  final double costoHoraMaquina;  // CMaq por hora
  final double costoHoraOperador; // CMO por hora
  final double margenRecomendado; // % margen
  final double margenMinimo;
  final double ivaPct;
  final String maquinaId;
  final String operadorId;

  CostosTaller({
    this.costoHoraTaller = 0,
    this.costoHoraMaquina = 0,
    this.costoHoraOperador = 0,
    this.margenRecomendado = 35,
    this.margenMinimo = 20,
    this.ivaPct = 16,
    this.maquinaId = '',
    this.operadorId = '',
  });

  // Costo total por hora de producción
  double get costoHoraTotal => costoHoraTaller + costoHoraMaquina + costoHoraOperador;
  double get costoMinutoTotal => costoHoraTotal / 60;
}

class SimuladorDataService {
  static final _sb = Supabase.instance.client;

  // Cargar costos del taller para el cálculo
  static Future<CostosTaller> getCostosTaller({
    String? maquinaId, String? operadorId}) async {
    try {
      const negId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

      // Config empresa
      final cfg = await _sb.from('empresa_config')
        .select().eq('negocio_id', negId).maybeSingle();

      final horasDia = (cfg?['horas_dia'] as num?)?.toDouble() ?? 8;
      final costoFijo = (cfg?['costo_fijo_mensual'] as num?)?.toDouble() ?? 0;
      final costoHoraTaller = costoFijo / (30 * horasDia);
      final margenRec = (cfg?['margen_recomendado'] as num?)?.toDouble() ?? 35;
      final margenMin = (cfg?['margen_minimo'] as num?)?.toDouble() ?? 20;
      final ivaPct = (cfg?['iva_pct'] as num?)?.toDouble() ?? 16;

      // Costo hora máquina
      double costoHoraMaq = 0;
      String maqId = maquinaId ?? '';
      if (maquinaId != null && maquinaId.isNotEmpty) {
        final maq = await _sb.from('maquinaria')
          .select().eq('id', maquinaId).maybeSingle();
        if (maq != null) {
          final valor = (maq['valor_adquisicion'] as num?)?.toDouble() ?? 0;
          final vida = (maq['vida_util_años'] as num?)?.toDouble() ?? 5;
          final horas = (maq['horas_mes'] as num?)?.toDouble() ?? 160;
          final kwh = (maq['consumo_kwh'] as num?)?.toDouble() ?? 0;
          final cKwh = (maq['costo_kwh'] as num?)?.toDouble() ?? 2.5;
          final mant = (maq['mantenimiento_mes'] as num?)?.toDouble() ?? 0;
          final cons = (maq['consumibles_hora'] as num?)?.toDouble() ?? 0;
          costoHoraMaq = (vida > 0 && horas > 0 ? valor / (vida * 12 * horas) : 0)
            + (kwh * cKwh)
            + (horas > 0 ? mant / horas : 0)
            + cons;
        }
      } else {
        // Tomar primera máquina activa
        final maqList = await _sb.from('maquinaria')
          .select().eq('negocio_id', negId).eq('activo', true).limit(1);
        if ((maqList as List).isNotEmpty) {
          final maq = maqList.first as Map<String, dynamic>;
          maqId = maq['id'] as String? ?? '';
          final valor = (maq['valor_adquisicion'] as num?)?.toDouble() ?? 0;
          final vida = (maq['vida_util_años'] as num?)?.toDouble() ?? 5;
          final horas = (maq['horas_mes'] as num?)?.toDouble() ?? 160;
          final kwh = (maq['consumo_kwh'] as num?)?.toDouble() ?? 0;
          final cKwh = (maq['costo_kwh'] as num?)?.toDouble() ?? 2.5;
          final mant = (maq['mantenimiento_mes'] as num?)?.toDouble() ?? 0;
          final cons = (maq['consumibles_hora'] as num?)?.toDouble() ?? 0;
          costoHoraMaq = (vida > 0 && horas > 0 ? valor / (vida * 12 * horas) : 0)
            + (kwh * cKwh)
            + (horas > 0 ? mant / horas : 0)
            + cons;
        }
      }

      // Costo hora operador
      double costoHoraOp = 0;
      String opId = operadorId ?? '';
      if (operadorId != null && operadorId.isNotEmpty) {
        final op = await _sb.from('mano_obra')
          .select().eq('id', operadorId).maybeSingle();
        if (op != null) {
          final sal = (op['salario_mes'] as num?)?.toDouble() ?? 0;
          final prest = (op['prestaciones_pct'] as num?)?.toDouble() ?? 35;
          final horas = (op['horas_mes'] as num?)?.toDouble() ?? 192;
          costoHoraOp = horas > 0 ? sal * (1 + prest / 100) / horas : 0;
        }
      } else {
        final opList = await _sb.from('mano_obra')
          .select().eq('negocio_id', negId).eq('activo', true).limit(1);
        if ((opList as List).isNotEmpty) {
          final op = opList.first as Map<String, dynamic>;
          opId = op['id'] as String? ?? '';
          final sal = (op['salario_mes'] as num?)?.toDouble() ?? 0;
          final prest = (op['prestaciones_pct'] as num?)?.toDouble() ?? 35;
          final horas = (op['horas_mes'] as num?)?.toDouble() ?? 192;
          costoHoraOp = horas > 0 ? sal * (1 + prest / 100) / horas : 0;
        }
      }

      return CostosTaller(
        costoHoraTaller: costoHoraTaller,
        costoHoraMaquina: costoHoraMaq,
        costoHoraOperador: costoHoraOp,
        margenRecomendado: margenRec,
        margenMinimo: margenMin,
        ivaPct: ivaPct,
        maquinaId: maqId,
        operadorId: opId,
      );
    } catch (_) {
      return CostosTaller();
    }
  }

  static Future<List<SimServicio>> getServicios() async {
    final data = await _sb.from('sim_servicios').select()
      .eq('activo', true).order('orden');
    return (data as List).map((j) => SimServicio.fromJson(j)).toList();
  }

  static Future<SimConfig> getConfig(String servicioId) async {
    // Cargar servicio
    final svcData = await _sb.from('sim_servicios')
      .select().eq('id', servicioId).maybeSingle();
    if (svcData == null) throw Exception('Servicio no encontrado');
    final servicio = SimServicio.fromJson(svcData);

    // Cargar tipos de trabajo
    List tiposData = [];
    try { tiposData = await _sb.from('sim_tipos_trabajo')
      .select().eq('servicio_id', servicioId)
      .eq('activo', true).order('orden'); } catch (_) {}
    if (tiposData.isEmpty) {
      try { tiposData = await _sb.from('sim_tipos_trabajo')
        .select().eq('servicio_id', servicioId).order('nombre'); } catch (_) {}
    }

    // Cargar tarifas
    List tarifasData = [];
    try { tarifasData = await _sb.from('sim_tarifas')
      .select().eq('servicio_id', servicioId).eq('activo', true); } catch (_) {}
    if (tarifasData.isEmpty) {
      try { tarifasData = await _sb.from('sim_tarifas')
        .select().eq('servicio_id', servicioId); } catch (_) {}
    }

    // Cargar rangos, extras, acabados (opcionales)
    List rangosData = [], extrasData = [], acabadosData = [];
    try { rangosData = await _sb.from('sim_rangos')
      .select().eq('servicio_id', servicioId).order('desde'); } catch (_) {}
    try { extrasData = await _sb.from('sim_extras')
      .select().eq('servicio_id', servicioId); } catch (_) {}
    try { acabadosData = await _sb.from('sim_acabados')
      .select().eq('servicio_id', servicioId); } catch (_) {}

    final tipos = tiposData.map((j) => SimTipoTrabajo.fromJson(j as Map<String,dynamic>)).toList();
    final tarifasMap = <String, SimTarifa>{};
    for (final j in tarifasData) {
      final t = SimTarifa.fromJson(j as Map<String,dynamic>);
      tarifasMap[t.clave] = t;
    }
    final rangos = rangosData.map((j) => SimRango.fromJson(j as Map<String,dynamic>)).toList();
    final extras = extrasData.map((j) => SimExtra.fromJson(j as Map<String,dynamic>)).toList();
    final acabados = acabadosData.map((j) => SimAcabado.fromJson(j as Map<String,dynamic>)).toList();

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
                      'negocio_id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
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
  CostosTaller? _costosTaller;
  bool _cargando = true;
  ResultadoSimulador? _resultado;
  String? _maquinaSelId;
  String? _operadorSelId;
  List<Map<String,dynamic>> _maquinas = [];
  List<Map<String,dynamic>> _operadores = [];

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
      final sb = Supabase.instance.client;
      const negId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
      final results = await Future.wait([
        SimuladorDataService.getConfig(widget.servicio.id),
        SimuladorDataService.getMaterialesInventario(),
        SimuladorDataService.getCostosTaller(),
        sb.from('maquinaria').select('id,nombre,emoji').eq('negocio_id',negId).eq('activo',true),
        sb.from('mano_obra').select('id,nombre,emoji,tipo').eq('negocio_id',negId).eq('activo',true),
      ]);
      final cfg = results[0] as SimConfig;
      final inv = results[1] as List<Map<String, dynamic>>;
      final costos = results[2] as CostosTaller;
      final maquinas = (results[3] as List).cast<Map<String,dynamic>>();
      final operadores = (results[4] as List).cast<Map<String,dynamic>>();
      if (mounted) setState(() {
        _config = cfg;
        _costosTaller = costos;
        _materialesInv = inv;
        _maquinas = maquinas;
        _operadores = operadores;
        _maquinaSelId = costos.maquinaId.isNotEmpty ? costos.maquinaId : null;
        _operadorSelId = costos.operadorId.isNotEmpty ? costos.operadorId : null;
        _cargando = false;
        if (cfg.tipos.isNotEmpty) _tipoSel = cfg.tipos.first;
        if (cfg.acabados.isNotEmpty) _acabadoSel = cfg.acabados.first;
        for (final t in cfg.tarifas.values) {
          _tarifasCtrls[t.id] = TextEditingController(
            text: t.valor.toStringAsFixed(2));
        }
      });
    } catch (e) { if (mounted) setState(() => _cargando = false); }
  }

  // ── MOTOR DE CÁLCULO — FÓRMULA MAESTRA ────────────────
  // PV = (CM + CMO + CMaq + CC + CA + CI) ÷ (1 - Margen)
  void _calcular() {
    final cfg = _config;
    final costos = _costosTaller ?? CostosTaller();
    if (cfg == null || _tipoSel == null) return;

    final tipo = _tipoSel!;
    final formula = tipo.formula;
    final desglose = <String, String>{};

    // ── 1. TIEMPO ESTIMADO DE MÁQUINA ─────────────
    double tiempoHoras = 0; // horas de trabajo

    switch (formula) {
      case 'por_area':
        final areaM2 = (_largo / 100) * (_ancho / 100);
        // Factor por material y espesor (configurable)
        final factorMat = cfg.getTarifa('factor_material') > 0
          ? cfg.getTarifa('factor_material') : 1.0;
        final factorEsp = _alto > 0
          ? (1 + (_alto / 25) * 0.5) : 1.0; // más grueso = más tiempo
        tiempoHoras = areaM2 * factorMat * factorEsp;
        desglose['Área'] = '${_largo}×${_ancho} cm = ${areaM2.toStringAsFixed(4)} m²';
        if (_alto > 0) desglose['Espesor/Alto'] = '${_alto} mm • Factor: ×${factorEsp.toStringAsFixed(2)}';
        break;

      case 'por_volumen':
        final volumen = _largo * _ancho * _alto;
        final factor = tipo.factor > 0 ? tipo.factor : 1.0;
        tiempoHoras = volumen * factor / 1000000; // cm³ → m³ equivalente de tiempo
        // Mínimo 0.5 horas para trabajos 3D
        if (tiempoHoras < 0.5 && volumen > 0) tiempoHoras = 0.5;
        desglose['Volumen'] = '${_largo}×${_ancho}×${_alto} cm = ${volumen.toStringAsFixed(0)} cm³';
        desglose['Factor complejidad'] = '×${factor.toStringAsFixed(2)}';
        break;

      case 'por_hora':
        tiempoHoras = _horas > 0 ? _horas : 1.0;
        desglose['Tiempo'] = '${tiempoHoras.toStringAsFixed(1)} horas';
        break;

      case 'por_minuto':
        // Estimar minutos por área y densidad
        final areaM2 = (_largo / 100) * (_ancho / 100);
        final factorGrab = cfg.getTarifa('factor_grabado') > 0
          ? cfg.getTarifa('factor_grabado') : 2.0;
        final minutos = _minutos > 0 ? _minutos : areaM2 * factorGrab * 60;
        tiempoHoras = minutos / 60;
        desglose['Tiempo'] = '${minutos.toStringAsFixed(1)} min';
        break;

      case 'por_metro':
        tiempoHoras = _metros * 0.1; // 6 min por metro lineal default
        desglose['Metros'] = '${_metros.toStringAsFixed(2)} m';
        break;

      case 'por_kg':
        tiempoHoras = _peso * 0.05; // 3 min por kg default
        desglose['Peso'] = '${_peso.toStringAsFixed(2)} kg';
        break;

      case 'precio_fijo':
        tiempoHoras = 1.0;
        desglose['Modo'] = 'Precio fijo';
        break;

      case 'por_diseno':
        final horasBase = {
          'simple': cfg.getTarifa('horas_simple') > 0 ? cfg.getTarifa('horas_simple') : 1.0,
          'media':  cfg.getTarifa('horas_medio')  > 0 ? cfg.getTarifa('horas_medio')  : 3.0,
          'alta':   cfg.getTarifa('horas_alto')   > 0 ? cfg.getTarifa('horas_alto')   : 8.0,
          'premium':cfg.getTarifa('horas_premium')> 0 ? cfg.getTarifa('horas_premium'): 20.0,
        };
        tiempoHoras = (horasBase[_complejidad] ?? 3.0) * tipo.factor;
        desglose['Complejidad'] = _complejidad.toUpperCase();
        desglose['Horas estimadas'] = '${tiempoHoras.toStringAsFixed(1)} hrs';
        break;
    }

    desglose['Tiempo total'] = '${tiempoHoras.toStringAsFixed(2)} horas';

    // ── 2. COSTOS DIRECTOS ─────────────────────────
    // CM - Costo de Material
    double cm = 0;
    String? materialNombre;
    if (!_clienteTreMaterial) {
      if (_usarInventario && _materialInvSel != null) {
        cm = ((_materialInvSel!['costo_unitario'] as num?)?.toDouble() ?? 0) * _cantidad;
        materialNombre = _materialInvSel!['nombre'] as String?;
      } else if (!_usarInventario && _materialLibrePrecio > 0) {
        cm = _materialLibrePrecio * _cantidad;
        materialNombre = _materialLibreNombre.isNotEmpty ? _materialLibreNombre : 'Material';
      }
      if (cm > 0) desglose['CM Material ($materialNombre)'] = _fmt.format(cm);
    } else {
      desglose['Material'] = 'Cliente trae el material';
    }

    // CMaq - Costo de Máquina
    double cmaq = costos.costoHoraMaquina * tiempoHoras * _cantidad;
    if (cmaq > 0) desglose['CMaq Máquina'] = '${tiempoHoras.toStringAsFixed(2)}h × ${_fmt.format(costos.costoHoraMaquina)}/h = ${_fmt.format(cmaq)}';

    // CMO - Costo Mano de Obra
    double cmo = costos.costoHoraOperador * tiempoHoras * _cantidad;
    if (cmo > 0) desglose['CMO Operador'] = '${tiempoHoras.toStringAsFixed(2)}h × ${_fmt.format(costos.costoHoraOperador)}/h = ${_fmt.format(cmo)}';

    // CC - Consumibles (de tarifa configurada o % del tiempo)
    double cc = 0;
    final tarifaConsumibles = cfg.getTarifa('consumibles_hora');
    if (tarifaConsumibles > 0) {
      cc = tarifaConsumibles * tiempoHoras * _cantidad;
      desglose['CC Consumibles'] = _fmt.format(cc);
    }

    // CA - Acabados
    double ca = (_acabadoSel?.precio ?? 0) * _cantidad;
    if (ca > 0) desglose['CA Acabado (${_acabadoSel?.nombre})'] = _fmt.format(ca);

    // CI - Costo Indirecto asignado (proporción del costo fijo del taller)
    double ci = costos.costoHoraTaller * tiempoHoras * _cantidad;
    if (ci > 0) desglose['CI Costo taller'] = '${tiempoHoras.toStringAsFixed(2)}h × ${_fmt.format(costos.costoHoraTaller)}/h = ${_fmt.format(ci)}';

    // Extras seleccionados
    double extrasTotal = 0;
    for (final e in (cfg.extras).where((e) => e.seleccionado)) {
      extrasTotal += e.precio * _cantidad;
      desglose['Extra: ${e.nombre}'] = _fmt.format(e.precio * _cantidad);
    }

    // ── 3. COSTO TOTAL ─────────────────────────────
    final costoTotal = cm + cmaq + cmo + cc + ca + ci + extrasTotal;
    desglose['─────────────────'] = '───────────────';
    desglose['Costo Total'] = _fmt.format(costoTotal);

    // ── 4. PRECIO DE VENTA CON MARGEN ──────────────
    // PV = Costo ÷ (1 - Margen)
    final margenRec = costos.margenRecomendado / 100;
    final margenMin = costos.margenMinimo / 100;

    // Si el servicio tiene precio fijo en tarifas, usar ese
    double pvRecomendado, pvMinimo;
    if (formula == 'precio_fijo' && cfg.getTarifa('precio_fijo') > 0) {
      pvRecomendado = cfg.getTarifa('precio_fijo') * _cantidad;
      pvMinimo = pvRecomendado * 0.85;
    } else if (formula == 'por_volumen' && cfg.rangos.isNotEmpty) {
      // Para Router 3D usar tabla de rangos como precio base
      double indice = 0;
      if (formula == 'por_volumen') {
        indice = _largo * _ancho * _alto * tipo.factor;
      }
      final precioRango = cfg.calcularPrecioRango(indice);
      pvRecomendado = precioRango > costoTotal / (1 - margenRec)
        ? precioRango * _cantidad
        : costoTotal / (1 - margenRec) * _cantidad;
      pvMinimo = costoTotal / (1 - margenMin) * _cantidad;
      desglose['Rango aplicado'] = _fmt.format(precioRango);
    } else {
      pvRecomendado = costoTotal > 0
        ? (costoTotal / (1 - margenRec)) * _cantidad
        : 0;
      pvMinimo = costoTotal > 0
        ? (costoTotal / (1 - margenMin)) * _cantidad
        : 0;
    }

    // Pedido mínimo
    final pedMin = cfg.getTarifa('pedido_minimo');
    if (pedMin > 0 && pvRecomendado < pedMin) {
      desglose['Pedido mínimo aplicado'] = _fmt.format(pedMin);
      pvRecomendado = pedMin;
      pvMinimo = pedMin;
    }

    // IVA
    final iva = _aplicarIva ? pvRecomendado * (costos.ivaPct / 100) : 0.0;
    final pvConIva = pvRecomendado + iva;
    if (_aplicarIva) desglose['IVA ${costos.ivaPct.toStringAsFixed(0)}%'] = _fmt.format(iva);

    // ── 5. ANÁLISIS FINANCIERO ─────────────────────
    final utilidad = pvRecomendado - costoTotal * _cantidad;
    final margenReal = pvRecomendado > 0 ? (utilidad / pvRecomendado) * 100 : 0;
    final gananciaHora = tiempoHoras > 0 ? utilidad / (tiempoHoras * _cantidad) : 0;

    // Descripción automática
    final descParts = <String>[tipo.nombre];
    if (_tipoSel?.necesitaLargo == true && _largo > 0 && _ancho > 0) {
      descParts.add('Medidas: ${_largo}×${_ancho}${_alto > 0 ? "×${_alto}" : ""} cm');
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
      _descripcionEditable = descParts.join('
');
      _resultado = ResultadoSimulador(
        servicio: widget.servicio.nombre,
        emoji: widget.servicio.emoji,
        descripcion: _descripcionEditable,
        maquila: pvRecomendado,
        extras: extrasTotal,
        acabado: ca,
        costoMaterial: cm,
        subtotal: pvRecomendado,
        iva: iva,
        total: pvConIva,
        desglose: desglose,
        incluyeIva: _aplicarIva,
        materialNombre: materialNombre,
        // Análisis financiero
        costoTotal: costoTotal * _cantidad,
        pvMinimo: pvMinimo,
        pvRecomendado: pvRecomendado,
        utilidad: utilidad,
        margenReal: margenReal,
        gananciaHora: gananciaHora,
        tiempoHoras: tiempoHoras * _cantidad,
      );
    });
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
      // Selector de máquina
      if (_maquinas.isNotEmpty) ...[
        const Text('Máquina:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _maquinaSelId,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
          items: _maquinas.map((m) => DropdownMenuItem<String>(
            value: m['id'] as String,
            child: Row(children: [
              Text(m['emoji'] ?? '⚙️'),
              const SizedBox(width: 8),
              Text(m['nombre'] ?? '', style: const TextStyle(fontSize: 13)),
            ]))).toList(),
          onChanged: (v) => setState(() { _maquinaSelId = v; _resultado = null; })),
        const SizedBox(height: 10),
      ],
      // Selector de operador
      if (_operadores.isNotEmpty) ...[
        const Text('Operador:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _operadorSelId,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
          items: _operadores.map((o) => DropdownMenuItem<String>(
            value: o['id'] as String,
            child: Row(children: [
              Text(o['emoji'] ?? '👷'),
              const SizedBox(width: 8),
              Text(o['nombre'] ?? '', style: const TextStyle(fontSize: 13)),
            ]))).toList(),
          onChanged: (v) => setState(() { _operadorSelId = v; _resultado = null; })),
        const SizedBox(height: 10),
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
      // Header azul con precio recomendado
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: AppColors.azul,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PRECIO RECOMENDADO', style: TextStyle(
                fontSize: 10, color: Colors.white70, letterSpacing: 1)),
              if (r.pvMinimo > 0 && r.pvMinimo < r.pvRecomendado)
                Text('Mínimo: ${_fmt.format(r.pvMinimo)}',
                  style: const TextStyle(fontSize: 11, color: Colors.white60)),
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
          ]),
          // Análisis financiero rápido
          if (r.costoTotal > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _kpiResultado('Costo total', _fmt.format(r.costoTotal), Colors.white70),
                _kpiResultado('Utilidad', _fmt.format(r.utilidad),
                  r.utilidad > 0 ? const Color(0xFF4ade80) : Colors.redAccent),
                _kpiResultado('Margen real', '${r.margenReal.toStringAsFixed(1)}%',
                  r.margenReal >= 30 ? const Color(0xFF4ade80) :
                  r.margenReal >= 20 ? Colors.amber : Colors.redAccent),
                _kpiResultado('Gan/hora', _fmt.format(r.gananciaHora), Colors.white70),
              ])),
          ],
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
  Widget _kpiResultado(String label, String val, Color color) =>
    Column(children: [
      Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.white60)),
    ]);

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
                      'negocio_id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
                      'servicio_id': widget.servicio.id,
                      'nombre': nombreCtrl.text.trim(),
                      'formula': formula,
                      'factor_complejidad': 1.0,
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
