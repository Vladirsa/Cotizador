// lib/screens/simulador_screen.dart
// HETNA CNC — Simulador de costos v2
// Tarifas reales por tipo de máquina, multi-servicio, con/sin material
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'cotizar_screen.dart';

// ══════════════════════════════════════════════════════
// MODELOS
// ══════════════════════════════════════════════════════
class ServicioSimulado {
  final String maquina;
  final String trabajo;
  final String emoji;
  final String descripcion;
  final double precio;
  final Map<String, String> especificaciones;

  ServicioSimulado({
    required this.maquina,
    required this.trabajo,
    required this.emoji,
    required this.descripcion,
    required this.precio,
    required this.especificaciones,
  });
}

// ══════════════════════════════════════════════════════
// SERVICIO DE TARIFAS
// ══════════════════════════════════════════════════════
class TarifasService {
  static final _sb = Supabase.instance.client;
  static Map<String, Map<String, double>> _cache = {};

  static Future<Map<String, double>> getTarifas(String maquina) async {
    if (_cache.containsKey(maquina)) return _cache[maquina]!;
    try {
      final data = await _sb
        .from('tarifas_simulador')
        .select('clave, valor')
        .eq('tipo_maquina', maquina)
        .eq('activo', true);
      final map = <String, double>{};
      for (final row in data) {
        map[row['clave'] as String] = (row['valor'] as num).toDouble();
      }
      _cache[maquina] = map;
      return map;
    } catch (_) {
      return _defaultsTarifas[maquina] ?? {};
    }
  }

  static Future<void> guardarTarifa(String maquina, String clave, double valor) async {
    try {
      await _sb.from('tarifas_simulador').upsert({
        'tipo_maquina': maquina,
        'clave': clave,
        'valor': valor,
        'activo': true,
      }, onConflict: 'negocio_id,tipo_maquina,clave');
      _cache.remove(maquina);
    } catch (_) {}
  }

  static void limpiarCache() => _cache.clear();

  // Defaults si Supabase falla
  static final Map<String, Map<String, double>> _defaultsTarifas = {
    'plasma': {
      'tarifa_m2_cal12': 480, 'tarifa_m2_cal10': 580,
      'tarifa_pieza_limpia': 350,
      'costo_lamina_cal8': 980, 'costo_lamina_cal10': 750,
      'costo_lamina_cal12': 580, 'costo_lamina_cal14': 480,
      'costo_lamina_cal16': 380,
    },
    'laser_co2': {'tarifa_min': 8},
    'laser_fibra': {'tarifa_min': 10},
    'router': {
      'tarifa_min': 35, 'tarifa_hoja_normal': 720,
      'tarifa_hoja_saturada': 980,
      'costo_mdf_3mm': 180, 'costo_mdf_9mm': 280,
      'costo_mdf_15mm': 380, 'costo_mdf_18mm': 450,
      'costo_acrilico_3mm': 320, 'costo_acrilico_6mm': 580,
    },
    'diseno': {
      'tarifa_2d_min': 150, 'tarifa_2d_max': 700,
      'tarifa_3d_min': 1500, 'tarifa_3d_max': 3000,
      'tarifa_hr': 200,
    },
    'impresion_3d': {
      'costo_pla_g': 0.25, 'costo_abs_g': 0.30,
      'costo_petg_g': 0.35, 'costo_tpu_g': 0.50,
      'tarifa_hr': 15, 'tarifa_min_cobro': 80,
    },
    'carpinteria': {
      'tarifa_hr': 180, 'factor_material': 1.5,
      'tarifa_instalacion': 200,
    },
    'herreria': {
      'tarifa_hr': 250, 'costo_kg_acero': 28,
      'costo_kg_inox': 95, 'tarifa_soldadura_hr': 300,
    },
  };
}

// ══════════════════════════════════════════════════════
// PANTALLA PRINCIPAL
// ══════════════════════════════════════════════════════
class SimuladorScreen extends StatefulWidget {
  const SimuladorScreen({super.key});
  @override
  State<SimuladorScreen> createState() => _SimuladorScreenState();
}

class _SimuladorScreenState extends State<SimuladorScreen> {
  final _fmt = NumberFormat('\$#,##0.00', 'es_MX');
  // Carrito de servicios simulados
  final List<ServicioSimulado> _carrito = [];
  String? _maquinaActual;

  double get _totalCarrito => _carrito.fold(0, (s, sv) => s + sv.precio);

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
          if (_carrito.isNotEmpty)
            TextButton.icon(
              onPressed: _enviarACotizacion,
              icon: const Icon(Icons.description_outlined, color: Colors.white, size: 16),
              label: Text('${_carrito.length} → Cotizar',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.azul,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4))),
          const SizedBox(width: 8),
        ]),
      body: _maquinaActual == null
        ? _pantallaInicio()
        : _pantallaMaquina(_maquinaActual!),
    );
  }

  // ── PANTALLA INICIO ─────────────────────────────────
  Widget _pantallaInicio() {
    final maquinas = [
      {'id': 'plasma',       'nombre': 'Plasma CNC',      'emoji': '🔥', 'desc': 'Corte en acero, celosías, figuras', 'color': const Color(0xFF7c3aed)},
      {'id': 'laser_co2',   'nombre': 'Láser CO2',        'emoji': '🔴', 'desc': 'Corte y grabado MDF, acrílico, cuero', 'color': const Color(0xFFe24b4a)},
      {'id': 'laser_fibra', 'nombre': 'Láser Fibra',      'emoji': '⚡', 'desc': 'Grabado en metal, acero, joyería', 'color': const Color(0xFFef9f27)},
      {'id': 'router',      'nombre': 'Router CNC',       'emoji': '🔧', 'desc': 'Corte y talla 3D en madera, MDF', 'color': const Color(0xFF185fa5)},
      {'id': 'diseno',      'nombre': 'Diseño Digital',   'emoji': '✏️', 'desc': 'Archivos 2D/3D, vectorización', 'color': const Color(0xFF185fa5)},
      {'id': 'impresion_3d','nombre': 'Impresión 3D',     'emoji': '🖨️', 'desc': 'FDM (PLA, ABS, PETG, TPU)', 'color': const Color(0xFF1d9e75)},
      {'id': 'carpinteria', 'nombre': 'Carpintería',      'emoji': '🪵', 'desc': 'Muebles, instalaciones, madera', 'color': const Color(0xFF92400e)},
      {'id': 'herreria',    'nombre': 'Herrería',         'emoji': '🔩', 'desc': 'Estructuras metálicas, soldadura', 'color': const Color(0xFF374151)},
    ];

    return ListView(padding: const EdgeInsets.all(14), children: [
      // Carrito si hay servicios
      if (_carrito.isNotEmpty) ...[
        _widgetCarrito(),
        const SizedBox(height: 14),
      ],

      // Banner
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.azul, Color(0xFF2d5a8e)]),
          borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('¿Qué tipo de trabajo vas a cotizar?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Selecciona la máquina o servicio. Puedes agregar varios a la misma cotización.',
            style: TextStyle(fontSize: 11, color: Colors.white70)),
          if (_carrito.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20)),
              child: Text('${_carrito.length} servicio${_carrito.length > 1 ? "s" : ""} en carrito — ${_fmt.format(_totalCarrito)}',
                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600))),
          ],
        ])),

      const SizedBox(height: 12),

      // Grid de máquinas
      ...maquinas.map((m) {
        final color = m['color'] as Color;
        return GestureDetector(
          onTap: () => setState(() => _maquinaActual = m['id'] as String),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grisBorde, width: 0.5)),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(m['emoji'] as String,
                  style: const TextStyle(fontSize: 22)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m['nombre'] as String,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                Text(m['desc'] as String,
                  style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
              ])),
              Icon(Icons.arrow_forward_ios, size: 14, color: color),
            ])));
      }),

      const SizedBox(height: 8),
      // Botón configurar tarifas
      OutlinedButton.icon(
        onPressed: _configurarTarifas,
        icon: const Icon(Icons.tune_outlined, size: 16, color: AppColors.azul),
        label: const Text('Configurar mis tarifas',
          style: TextStyle(fontSize: 13, color: AppColors.azul)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.azul),
          padding: const EdgeInsets.symmetric(vertical: 10))),
    ]);
  }

  // ── CARRITO ─────────────────────────────────────────
  Widget _widgetCarrito() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.verde.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppColors.verde.withOpacity(0.05), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Carrito de servicios (${_carrito.length})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.verde)),
          TextButton(
            onPressed: () => setState(() => _carrito.clear()),
            child: const Text('Limpiar', style: TextStyle(fontSize: 11, color: AppColors.rojo))),
        ]),
        ..._carrito.asMap().entries.map((e) {
          final sv = e.value;
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Text(sv.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sv.trabajo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(sv.descripcion, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              Text(_fmt.format(sv.precio),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.azul)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _carrito.removeAt(e.key)),
                child: const Icon(Icons.close, size: 16, color: AppColors.textoSecundario)),
            ]));
        }),
        const Divider(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('TOTAL ESTIMADO',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textoPrincipal)),
          Text(_fmt.format(_totalCarrito),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.azul)),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _enviarACotizacion,
            icon: const Icon(Icons.description_outlined, color: Colors.white, size: 16),
            label: const Text('Crear cotización con estos servicios',
              style: TextStyle(color: Colors.white, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.verde,
              padding: const EdgeInsets.symmetric(vertical: 10)))),
      ]));
  }

  // ── PANTALLA MÁQUINA ─────────────────────────────────
  Widget _pantallaMaquina(String maquina) {
    return FutureBuilder<Map<String, double>>(
      future: TarifasService.getTarifas(maquina),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final tarifas = snap.data!;
        switch (maquina) {
          case 'plasma':       return _PantallaPlasma(tarifas: tarifas, fmt: _fmt, onAgregar: _agregarServicio, onVolver: () => setState(() => _maquinaActual = null));
          case 'laser_co2':   return _PantallaLaser(maquina: 'laser_co2', nombre: 'Láser CO2', emoji: '🔴', color: const Color(0xFFe24b4a), tarifas: tarifas, fmt: _fmt, onAgregar: _agregarServicio, onVolver: () => setState(() => _maquinaActual = null));
          case 'laser_fibra': return _PantallaLaser(maquina: 'laser_fibra', nombre: 'Láser Fibra', emoji: '⚡', color: const Color(0xFFef9f27), tarifas: tarifas, fmt: _fmt, onAgregar: _agregarServicio, onVolver: () => setState(() => _maquinaActual = null));
          case 'router':      return _PantallaRouter(tarifas: tarifas, fmt: _fmt, onAgregar: _agregarServicio, onVolver: () => setState(() => _maquinaActual = null));
          case 'diseno':      return _PantallaDiseno(tarifas: tarifas, fmt: _fmt, onAgregar: _agregarServicio, onVolver: () => setState(() => _maquinaActual = null));
          case 'impresion_3d':return _PantallaImpresion3D(tarifas: tarifas, fmt: _fmt, onAgregar: _agregarServicio, onVolver: () => setState(() => _maquinaActual = null));
          case 'carpinteria': return _PantallaCarpinteria(tarifas: tarifas, fmt: _fmt, onAgregar: _agregarServicio, onVolver: () => setState(() => _maquinaActual = null));
          case 'herreria':    return _PantallaHerreria(tarifas: tarifas, fmt: _fmt, onAgregar: _agregarServicio, onVolver: () => setState(() => _maquinaActual = null));
          default: return const SizedBox();
        }
      });
  }

  void _agregarServicio(ServicioSimulado sv) {
    setState(() {
      _carrito.add(sv);
      _maquinaActual = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ ${sv.trabajo} agregado al carrito'),
      backgroundColor: AppColors.verde,
      duration: const Duration(seconds: 2),
      action: SnackBarAction(
        label: '+ Otro servicio',
        textColor: Colors.white,
        onPressed: () {})));
  }

  void _enviarACotizacion() {
    if (_carrito.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CotizarScreen(
        carritoSimulador: List.from(_carrito))));
  }

  void _configurarTarifas() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const _ConfigTarifasScreen()));
  }
}

// ══════════════════════════════════════════════════════
// PLASMA CNC
// ══════════════════════════════════════════════════════
class _PantallaPlasma extends StatefulWidget {
  final Map<String, double> tarifas;
  final NumberFormat fmt;
  final void Function(ServicioSimulado) onAgregar;
  final VoidCallback onVolver;
  const _PantallaPlasma({required this.tarifas, required this.fmt, required this.onAgregar, required this.onVolver});
  @override State<_PantallaPlasma> createState() => _PantallaPlasmaState();
}
class _PantallaPlasmaState extends State<_PantallaPlasma> {
  // Modo de cobro
  String _modo = 'm2';              // m2 | pieza
  // Parámetros m²
  double _ancho = 60;               // cm
  double _alto = 60;                // cm
  String _calibre = 'cal12';        // cal8/10/12/14/16
  bool _clienteTreMaterial = false;
  bool _trabajoLimpio = false;
  double _cantidad = 1;
  // Resultado
  double? _total;
  Map<String, String> _specs = {};

  final _colores = const Color(0xFF7c3aed);

  double get _areaM2 => (_ancho / 100) * (_alto / 100);
  double get _tarifaM2 => _calibre == 'cal12' || _calibre == 'cal14' || _calibre == 'cal16'
    ? (widget.tarifas['tarifa_m2_cal12'] ?? 480)
    : (widget.tarifas['tarifa_m2_cal10'] ?? 580);

  void _calcular() {
    double precio = 0;
    final specs = <String, String>{};

    if (_modo == 'm2') {
      final maquila = _tarifaM2 * _areaM2 * _cantidad;
      double materialCosto = 0;
      if (!_clienteTreMaterial) {
        final key = 'costo_lamina_$_calibre';
        final costoPorHoja = widget.tarifas[key] ?? 480;
        final m2PorHoja = 2.44 * 1.22;
        materialCosto = (costoPorHoja / m2PorHoja) * _areaM2 * _cantidad;
      }
      final limpieza = _trabajoLimpio ? (widget.tarifas['tarifa_pieza_limpia'] ?? 350) * _cantidad : 0;
      precio = maquila + materialCosto + limpieza;
      specs['Área'] = '${_ancho}x${_alto} cm = ${_areaM2.toStringAsFixed(3)} m²';
      specs['Calibre'] = _calibre.toUpperCase();
      specs['Tarifa maquila'] = '${widget.fmt.format(_tarifaM2)}/m²';
      specs['Maquila'] = widget.fmt.format(maquila);
      if (!_clienteTreMaterial) specs['Material'] = widget.fmt.format(materialCosto);
      if (_trabajoLimpio) specs['Trabajo limpio'] = widget.fmt.format(limpieza);
      if (_cantidad > 1) specs['Cantidad'] = '${_cantidad.toInt()} piezas';
    } else {
      // Por pieza
      final tarifaPieza = widget.tarifas['tarifa_pieza_limpia'] ?? 350;
      precio = tarifaPieza * _cantidad;
      specs['Modo'] = 'Por pieza con acabado';
      specs['Precio unitario'] = widget.fmt.format(tarifaPieza);
      specs['Cantidad'] = '${_cantidad.toInt()} piezas';
    }

    setState(() { _total = precio; _specs = specs; });
  }

  @override
  Widget build(BuildContext context) {
    return _PantallaBase(
      nombre: 'Plasma CNC', emoji: '🔥', color: _colores,
      onVolver: widget.onVolver,
      total: _total,
      specs: _specs,
      fmt: widget.fmt,
      onAgregar: _total == null ? null : () => widget.onAgregar(ServicioSimulado(
        maquina: 'plasma', trabajo: 'Corte Plasma CNC',
        emoji: '🔥', precio: _total!,
        descripcion: _specs.entries.map((e) => '${e.key}: ${e.value}').join(' | '),
        especificaciones: _specs)),
      children: [
        // Modo de cobro
        _SeccionParam('Modo de cobro'),
        Row(children: [
          _ChipSel('Por m² (celosías)', _modo == 'm2', () => setState(() => _modo = 'm2'), _colores),
          const SizedBox(width: 8),
          _ChipSel('Por pieza limpia', _modo == 'pieza', () => setState(() => _modo = 'pieza'), _colores),
        ]),
        const SizedBox(height: 12),

        if (_modo == 'm2') ...[
          // Calibre
          _SeccionParam('Calibre de lámina'),
          Wrap(spacing: 6, runSpacing: 6, children: ['cal16','cal14','cal12','cal10','cal8'].map((c) =>
            _ChipSel(c.toUpperCase(), _calibre == c, () => setState(() => _calibre = c), _colores)).toList()),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _colores.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
            child: Text(
              _calibre == 'cal12' || _calibre == 'cal14' || _calibre == 'cal16'
                ? '💡 Cal 12 y menores → ${widget.fmt.format(widget.tarifas['tarifa_m2_cal12'] ?? 480)}/m²'
                : '💡 Cal 10 y mayores → ${widget.fmt.format(widget.tarifas['tarifa_m2_cal10'] ?? 580)}/m²',
              style: TextStyle(fontSize: 11, color: _colores))),
          const SizedBox(height: 12),

          // Dimensiones
          _SeccionParam('Dimensiones de la pieza'),
          Row(children: [
            Expanded(child: _CampoNumero('Ancho (cm)', _ancho, (v) => setState(() => _ancho = v))),
            const SizedBox(width: 10),
            Expanded(child: _CampoNumero('Alto (cm)', _alto, (v) => setState(() => _alto = v))),
          ]),
          const SizedBox(height: 4),
          Text('Área: ${_areaM2.toStringAsFixed(3)} m²',
            style: TextStyle(fontSize: 11, color: _colores, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          // Material
          _SeccionParam('Material'),
          _Toggle('Cliente trae el material (solo maquila)',
            _clienteTreMaterial, (v) => setState(() => _clienteTreMaterial = v), _colores),
          if (!_clienteTreMaterial)
            Padding(padding: const EdgeInsets.only(top: 6),
              child: Text('Costo lámina ${_calibre.toUpperCase()}: ${widget.fmt.format(widget.tarifas['costo_lamina_$_calibre'] ?? 480)}/hoja',
                style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
          const SizedBox(height: 8),
          _Toggle('Trabajo limpio (+${widget.fmt.format(widget.tarifas['tarifa_pieza_limpia'] ?? 350)}/pza)',
            _trabajoLimpio, (v) => setState(() => _trabajoLimpio = v), _colores),
        ],

        // Cantidad
        const SizedBox(height: 12),
        _SeccionParam('Cantidad de piezas'),
        _CampoNumero('Cantidad', _cantidad, (v) => setState(() => _cantidad = v)),
        const SizedBox(height: 16),

        // Calcular
        _BtnCalcular(_calcular, _colores),
      ]);
  }
}

// ══════════════════════════════════════════════════════
// LÁSER CO2 / FIBRA (unificado por minuto)
// ══════════════════════════════════════════════════════
class _PantallaLaser extends StatefulWidget {
  final String maquina, nombre, emoji;
  final Color color;
  final Map<String, double> tarifas;
  final NumberFormat fmt;
  final void Function(ServicioSimulado) onAgregar;
  final VoidCallback onVolver;
  const _PantallaLaser({required this.maquina, required this.nombre, required this.emoji, required this.color, required this.tarifas, required this.fmt, required this.onAgregar, required this.onVolver});
  @override State<_PantallaLaser> createState() => _PantallaLaserState();
}
class _PantallaLaserState extends State<_PantallaLaser> {
  double _minutos = 10;
  String _tipoTrabajo = 'corte';   // corte | grabado | ambos
  bool _clienteTreMaterial = true;
  String _material = 'MDF';
  double _costoPieza = 0;
  double _cantidad = 1;
  double? _total;
  Map<String, String> _specs = {};

  final _materiales = ['MDF', 'Acrílico', 'Madera', 'Cuero', 'Vidrio', 'Metal', 'Otro'];

  // Factor por tipo de trabajo (grabado tarda más que corte simple)
  double get _factorTipo => _tipoTrabajo == 'corte' ? 1.0 : _tipoTrabajo == 'grabado' ? 1.3 : 1.6;

  void _calcular() {
    final tarifaMin = widget.tarifas['tarifa_min'] ?? (widget.maquina == 'laser_co2' ? 8.0 : 10.0);
    final maquila = tarifaMin * _minutos * _factorTipo * _cantidad;
    final material = _clienteTreMaterial ? 0 : _costoPieza * _cantidad;
    final total = maquila + material;
    setState(() {
      _total = total;
      _specs = {
        'Tipo': _tipoTrabajo,
        'Minutos estimados': '${_minutos.toStringAsFixed(0)} min${_cantidad > 1 ? " × ${_cantidad.toInt()} pzas" : ""}',
        'Tarifa': '${widget.fmt.format(tarifaMin)}/min',
        'Maquila': widget.fmt.format(maquila),
        if (!_clienteTreMaterial) 'Material': widget.fmt.format(material),
        'Material tipo': _material,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final tarifaMin = widget.tarifas['tarifa_min'] ?? (widget.maquina == 'laser_co2' ? 8.0 : 10.0);
    return _PantallaBase(
      nombre: widget.nombre, emoji: widget.emoji, color: widget.color,
      onVolver: widget.onVolver, total: _total, specs: _specs, fmt: widget.fmt,
      onAgregar: _total == null ? null : () => widget.onAgregar(ServicioSimulado(
        maquina: widget.maquina, trabajo: '${widget.nombre} — $_tipoTrabajo',
        emoji: widget.emoji, precio: _total!,
        descripcion: _specs.entries.map((e) => '${e.key}: ${e.value}').join(' | '),
        especificaciones: _specs)),
      children: [
        _InfoBox('Tarifa: ${widget.fmt.format(tarifaMin)}/minuto', widget.color),
        const SizedBox(height: 12),

        _SeccionParam('Tipo de trabajo'),
        Wrap(spacing: 6, children: [
          _ChipSel('Corte', _tipoTrabajo == 'corte', () => setState(() => _tipoTrabajo = 'corte'), widget.color),
          _ChipSel('Grabado', _tipoTrabajo == 'grabado', () => setState(() => _tipoTrabajo = 'grabado'), widget.color),
          _ChipSel('Corte + Grabado', _tipoTrabajo == 'ambos', () => setState(() => _tipoTrabajo = 'ambos'), widget.color),
        ]),
        const SizedBox(height: 12),

        _SeccionParam('Material'),
        Wrap(spacing: 6, runSpacing: 6, children: _materiales.map((m) =>
          _ChipSel(m, _material == m, () => setState(() => _material = m), widget.color)).toList()),
        const SizedBox(height: 12),

        _SeccionParam('Minutos estimados de uso'),
        _CampoNumero('Minutos de máquina', _minutos, (v) => setState(() => _minutos = v)),
        const SizedBox(height: 6),
        Text('💡 Referencia: texto simple ~5 min, logo ~10-20 min, foto detallada ~30-60 min',
          style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
        const SizedBox(height: 12),

        _Toggle('Cliente trae el material', _clienteTreMaterial, (v) => setState(() => _clienteTreMaterial = v), widget.color),
        if (!_clienteTreMaterial) ...[
          const SizedBox(height: 8),
          _CampoNumero('Costo del material/pieza (\$)', _costoPieza, (v) => setState(() => _costoPieza = v)),
        ],
        const SizedBox(height: 12),

        _SeccionParam('Cantidad de piezas'),
        _CampoNumero('Cantidad', _cantidad, (v) => setState(() => _cantidad = v)),
        const SizedBox(height: 16),
        _BtnCalcular(_calcular, widget.color),
      ]);
  }
}

// ══════════════════════════════════════════════════════
// ROUTER CNC
// ══════════════════════════════════════════════════════
class _PantallaRouter extends StatefulWidget {
  final Map<String, double> tarifas;
  final NumberFormat fmt;
  final void Function(ServicioSimulado) onAgregar;
  final VoidCallback onVolver;
  const _PantallaRouter({required this.tarifas, required this.fmt, required this.onAgregar, required this.onVolver});
  @override State<_PantallaRouter> createState() => _PantallaRouterState();
}
class _PantallaRouterState extends State<_PantallaRouter> {
  String _modo = 'min';             // min | hoja
  String _tipoTrabajo = 'corte';    // corte | talla3d
  double _minutos = 20;
  String _satHoja = 'normal';       // normal | saturada
  int _numHojas = 1;
  String _material = 'mdf_9mm';
  bool _clienteTreMaterial = false;
  double _cantidad = 1;
  double? _total;
  Map<String, String> _specs = {};

  final _color = const Color(0xFF185fa5);
  final _materiales = {
    'mdf_3mm': 'MDF 3mm', 'mdf_9mm': 'MDF 9mm',
    'mdf_15mm': 'MDF 15mm', 'mdf_18mm': 'MDF 18mm',
    'acrilico_3mm': 'Acrílico 3mm', 'acrilico_6mm': 'Acrílico 6mm',
  };

  void _calcular() {
    double maquila = 0;
    double materialCosto = 0;
    final specs = <String, String>{};

    if (_modo == 'min') {
      final tarifaMin = widget.tarifas['tarifa_min'] ?? 35;
      final factorTipo = _tipoTrabajo == 'talla3d' ? 1.4 : 1.0;
      maquila = tarifaMin * _minutos * factorTipo * _cantidad;
      specs['Tipo'] = _tipoTrabajo == 'talla3d' ? 'Talla 3D / relieve' : 'Corte 2D';
      specs['Minutos'] = '${_minutos.toStringAsFixed(0)} min';
      specs['Tarifa'] = '${widget.fmt.format(tarifaMin)}/min';
    } else {
      final keyHoja = _satHoja == 'saturada' ? 'tarifa_hoja_saturada' : 'tarifa_hoja_normal';
      final tarifaHoja = widget.tarifas[keyHoja] ?? (_satHoja == 'saturada' ? 980.0 : 720.0);
      maquila = tarifaHoja * _numHojas;
      specs['Tipo'] = 'Hoja completa ${_satHoja}';
      specs['Hojas'] = '$_numHojas × ${widget.fmt.format(tarifaHoja)}';
    }

    if (!_clienteTreMaterial) {
      final keyCosto = 'costo_$_material';
      final costoHoja = widget.tarifas[keyCosto] ?? 280;
      final hojas = _modo == 'hoja' ? _numHojas.toDouble() : _cantidad;
      materialCosto = costoHoja * hojas;
      specs['Material'] = '${_materiales[_material]} — ${widget.fmt.format(materialCosto)}';
    }

    final total = (maquila + materialCosto);
    setState(() {
      _total = total;
      _specs = specs;
      if (_cantidad > 1 && _modo == 'min') _specs['Cantidad'] = '${_cantidad.toInt()} piezas';
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PantallaBase(
      nombre: 'Router CNC', emoji: '🔧', color: _color,
      onVolver: widget.onVolver, total: _total, specs: _specs, fmt: widget.fmt,
      onAgregar: _total == null ? null : () => widget.onAgregar(ServicioSimulado(
        maquina: 'router', trabajo: 'Router CNC — $_tipoTrabajo',
        emoji: '🔧', precio: _total!,
        descripcion: _specs.entries.map((e) => '${e.key}: ${e.value}').join(' | '),
        especificaciones: _specs)),
      children: [
        _SeccionParam('Modo de cobro'),
        Row(children: [
          _ChipSel('Por minuto', _modo == 'min', () => setState(() => _modo = 'min'), _color),
          const SizedBox(width: 8),
          _ChipSel('Por hoja completa', _modo == 'hoja', () => setState(() => _modo = 'hoja'), _color),
        ]),
        const SizedBox(height: 12),

        if (_modo == 'min') ...[
          _SeccionParam('Tipo de trabajo'),
          Row(children: [
            _ChipSel('Corte 2D', _tipoTrabajo == 'corte', () => setState(() => _tipoTrabajo = 'corte'), _color),
            const SizedBox(width: 8),
            _ChipSel('Talla 3D / Relieve', _tipoTrabajo == 'talla3d', () => setState(() => _tipoTrabajo = 'talla3d'), _color),
          ]),
          const SizedBox(height: 12),
          _SeccionParam('Minutos estimados'),
          _CampoNumero('Minutos', _minutos, (v) => setState(() => _minutos = v)),
          Text('Tarifa: ${widget.fmt.format(widget.tarifas['tarifa_min'] ?? 35)}/min${_tipoTrabajo == "talla3d" ? " (×1.4 talla 3D)" : ""}',
            style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          const SizedBox(height: 12),
          _SeccionParam('Cantidad de piezas'),
          _CampoNumero('Cantidad', _cantidad, (v) => setState(() => _cantidad = v)),
        ] else ...[
          _SeccionParam('Saturación del diseño'),
          Row(children: [
            _ChipSel('Normal — ${widget.fmt.format(widget.tarifas['tarifa_hoja_normal'] ?? 720)}',
              _satHoja == 'normal', () => setState(() => _satHoja = 'normal'), _color),
            const SizedBox(width: 8),
            _ChipSel('Saturada — ${widget.fmt.format(widget.tarifas['tarifa_hoja_saturada'] ?? 980)}',
              _satHoja == 'saturada', () => setState(() => _satHoja = 'saturada'), _color),
          ]),
          const SizedBox(height: 6),
          Text('💡 Saturada: diseño cubre >70% de la hoja / muy denso',
            style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          const SizedBox(height: 12),
          _SeccionParam('Número de hojas 4×8'),
          _CampoNumeroInt('Hojas', _numHojas, (v) => setState(() => _numHojas = v)),
        ],

        const SizedBox(height: 12),
        _SeccionParam('Material'),
        Wrap(spacing: 6, runSpacing: 6, children: _materiales.entries.map((e) =>
          _ChipSel(e.value, _material == e.key, () => setState(() => _material = e.key), _color)).toList()),
        const SizedBox(height: 8),
        _Toggle('Cliente trae el material (solo maquila)', _clienteTreMaterial, (v) => setState(() => _clienteTreMaterial = v), _color),
        const SizedBox(height: 16),
        _BtnCalcular(_calcular, _color),
      ]);
  }
}

// ══════════════════════════════════════════════════════
// DISEÑO DIGITAL
// ══════════════════════════════════════════════════════
class _PantallaDiseno extends StatefulWidget {
  final Map<String, double> tarifas;
  final NumberFormat fmt;
  final void Function(ServicioSimulado) onAgregar;
  final VoidCallback onVolver;
  const _PantallaDiseno({required this.tarifas, required this.fmt, required this.onAgregar, required this.onVolver});
  @override State<_PantallaDiseno> createState() => _PantallaDisenoState();
}
class _PantallaDisenoState extends State<_PantallaDiseno> {
  String _tipo = '2d';              // 2d | 3d
  String _complejidad = 'medio';    // simple | medio | complejo
  bool _incluyeMaquila = false;     // si incluye maquila, diseño es gratis
  double? _total;
  Map<String, String> _specs = {};
  final _color = const Color(0xFF185fa5);

  void _calcular() {
    if (_incluyeMaquila && _tipo == '3d') {
      setState(() {
        _total = 0;
        _specs = {'Diseño 3D': 'GRATIS (incluye maquila)', 'Nota': 'El costo del diseño va en la maquila'};
      });
      return;
    }
    double precio = 0;
    final specs = <String, String>{};
    if (_tipo == '2d') {
      final min = widget.tarifas['tarifa_2d_min'] ?? 150;
      final max = widget.tarifas['tarifa_2d_max'] ?? 700;
      precio = _complejidad == 'simple' ? min : _complejidad == 'medio' ? (min + max) / 2 : max;
      specs['Tipo'] = 'Diseño 2D / Vectorización';
      specs['Complejidad'] = _complejidad;
      specs['Rango'] = '${widget.fmt.format(min)} – ${widget.fmt.format(max)}';
    } else {
      final min = widget.tarifas['tarifa_3d_min'] ?? 1500;
      final max = widget.tarifas['tarifa_3d_max'] ?? 3000;
      precio = _complejidad == 'simple' ? min : _complejidad == 'medio' ? (min + max) / 2 : max;
      specs['Tipo'] = 'Modelado 3D';
      specs['Complejidad'] = _complejidad;
    }
    setState(() { _total = precio; _specs = specs; });
  }

  @override
  Widget build(BuildContext context) {
    return _PantallaBase(
      nombre: 'Diseño Digital', emoji: '✏️', color: _color,
      onVolver: widget.onVolver, total: _total, specs: _specs, fmt: widget.fmt,
      onAgregar: (_total == null || _total == 0) ? null : () => widget.onAgregar(ServicioSimulado(
        maquina: 'diseno', trabajo: 'Diseño ${_tipo.toUpperCase()} $_complejidad',
        emoji: '✏️', precio: _total!,
        descripcion: _specs.entries.map((e) => '${e.key}: ${e.value}').join(' | '),
        especificaciones: _specs)),
      children: [
        _SeccionParam('Tipo de diseño'),
        Row(children: [
          _ChipSel('2D / Vectorización', _tipo == '2d', () => setState(() => _tipo = '2d'), _color),
          const SizedBox(width: 8),
          _ChipSel('Modelado 3D', _tipo == '3d', () => setState(() => _tipo = '3d'), _color),
        ]),
        const SizedBox(height: 12),
        _SeccionParam('Complejidad'),
        Wrap(spacing: 6, children: [
          _ChipSel('Simple', _complejidad == 'simple', () => setState(() => _complejidad = 'simple'), _color),
          _ChipSel('Medio', _complejidad == 'medio', () => setState(() => _complejidad = 'medio'), _color),
          _ChipSel('Complejo', _complejidad == 'complejo', () => setState(() => _complejidad = 'complejo'), _color),
        ]),
        if (_tipo == '3d') ...[
          const SizedBox(height: 12),
          _Toggle('Diseño incluido en maquila (gratis)', _incluyeMaquila, (v) => setState(() => _incluyeMaquila = v), _color),
          if (_incluyeMaquila)
            const Padding(padding: EdgeInsets.only(top: 6),
              child: Text('El diseño se cobra dentro del costo de producción',
                style: TextStyle(fontSize: 11, color: AppColors.verde))),
        ],
        if (_tipo == '2d')
          Padding(padding: const EdgeInsets.only(top: 8),
            child: Text('Rango: ${widget.fmt.format(widget.tarifas["tarifa_2d_min"] ?? 150)} – ${widget.fmt.format(widget.tarifas["tarifa_2d_max"] ?? 700)}',
              style: TextStyle(fontSize: 11, color: _color))),
        if (_tipo == '3d' && !_incluyeMaquila)
          Padding(padding: const EdgeInsets.only(top: 8),
            child: Text('Rango: ${widget.fmt.format(widget.tarifas["tarifa_3d_min"] ?? 1500)} – ${widget.fmt.format(widget.tarifas["tarifa_3d_max"] ?? 3000)}',
              style: TextStyle(fontSize: 11, color: _color))),
        const SizedBox(height: 16),
        _BtnCalcular(_calcular, _color),
      ]);
  }
}

// ══════════════════════════════════════════════════════
// IMPRESIÓN 3D
// ══════════════════════════════════════════════════════
class _PantallaImpresion3D extends StatefulWidget {
  final Map<String, double> tarifas;
  final NumberFormat fmt;
  final void Function(ServicioSimulado) onAgregar;
  final VoidCallback onVolver;
  const _PantallaImpresion3D({required this.tarifas, required this.fmt, required this.onAgregar, required this.onVolver});
  @override State<_PantallaImpresion3D> createState() => _PantallaImpresion3DState();
}
class _PantallaImpresion3DState extends State<_PantallaImpresion3D> {
  String _material = 'pla';
  double _gramos = 50;
  double _horas = 3;
  double _cantidad = 1;
  double? _total;
  Map<String, String> _specs = {};
  final _color = const Color(0xFF1d9e75);
  final _materiales = {'pla': 'PLA', 'abs': 'ABS', 'petg': 'PETG', 'tpu': 'TPU (flex)'};

  void _calcular() {
    final costoG = widget.tarifas['costo_${_material}_g'] ?? 0.25;
    final tarifaHr = widget.tarifas['tarifa_hr'] ?? 15;
    final minCobro = widget.tarifas['tarifa_min_cobro'] ?? 80;
    final costoMaterial = costoG * _gramos * _cantidad;
    final costoTiempo = tarifaHr * _horas * _cantidad;
    final subtotal = costoMaterial + costoTiempo;
    final total = subtotal < minCobro ? minCobro : subtotal;
    setState(() {
      _total = total;
      _specs = {
        'Material': '${_materiales[_material]} — ${_gramos.toStringAsFixed(0)}g × ${widget.fmt.format(costoG)}/g = ${widget.fmt.format(costoMaterial)}',
        'Tiempo impresión': '${_horas.toStringAsFixed(1)} hrs × ${widget.fmt.format(tarifaHr)}/hr = ${widget.fmt.format(costoTiempo)}',
        if (subtotal < minCobro) 'Mínimo aplicado': widget.fmt.format(minCobro),
        if (_cantidad > 1) 'Cantidad': '${_cantidad.toInt()} piezas',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PantallaBase(
      nombre: 'Impresión 3D', emoji: '🖨️', color: _color,
      onVolver: widget.onVolver, total: _total, specs: _specs, fmt: widget.fmt,
      onAgregar: _total == null ? null : () => widget.onAgregar(ServicioSimulado(
        maquina: 'impresion_3d', trabajo: 'Impresión 3D ${_materiales[_material]}',
        emoji: '🖨️', precio: _total!,
        descripcion: _specs.entries.map((e) => '${e.key}: ${e.value}').join(' | '),
        especificaciones: _specs)),
      children: [
        _SeccionParam('Material de filamento'),
        Wrap(spacing: 6, runSpacing: 6, children: _materiales.entries.map((e) =>
          _ChipSel(e.value, _material == e.key, () => setState(() => _material = e.key), _color)).toList()),
        Text('Costo: ${widget.fmt.format(widget.tarifas["costo_${_material}_g"] ?? 0.25)}/gramo',
          style: TextStyle(fontSize: 10, color: _color)),
        const SizedBox(height: 12),
        _SeccionParam('Peso estimado de la pieza'),
        _CampoNumero('Gramos (g)', _gramos, (v) => setState(() => _gramos = v)),
        Text('💡 Pieza pequeña ~20g, mediana ~50-100g, grande ~200g+',
          style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
        const SizedBox(height: 12),
        _SeccionParam('Horas de impresión estimadas'),
        _CampoNumero('Horas', _horas, (v) => setState(() => _horas = v)),
        Text('Tarifa: ${widget.fmt.format(widget.tarifas["tarifa_hr"] ?? 15)}/hr — Mínimo: ${widget.fmt.format(widget.tarifas["tarifa_min_cobro"] ?? 80)}',
          style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
        const SizedBox(height: 12),
        _SeccionParam('Cantidad'),
        _CampoNumero('Piezas', _cantidad, (v) => setState(() => _cantidad = v)),
        const SizedBox(height: 16),
        _BtnCalcular(_calcular, _color),
      ]);
  }
}

// ══════════════════════════════════════════════════════
// CARPINTERÍA
// ══════════════════════════════════════════════════════
class _PantallaCarpinteria extends StatefulWidget {
  final Map<String, double> tarifas;
  final NumberFormat fmt;
  final void Function(ServicioSimulado) onAgregar;
  final VoidCallback onVolver;
  const _PantallaCarpinteria({required this.tarifas, required this.fmt, required this.onAgregar, required this.onVolver});
  @override State<_PantallaCarpinteria> createState() => _PantallaCarpinteriaState();
}
class _PantallaCarpinteriaState extends State<_PantallaCarpinteria> {
  double _costoMaterial = 0;
  double _horas = 4;
  bool _incluyeInstalacion = false;
  double _horasInstalacion = 2;
  double? _total;
  Map<String, String> _specs = {};
  final _color = const Color(0xFF92400e);

  void _calcular() {
    final factor = widget.tarifas['factor_material'] ?? 1.5;
    final tarifaHr = widget.tarifas['tarifa_hr'] ?? 180;
    final tarifaInst = widget.tarifas['tarifa_instalacion'] ?? 200;
    final costoConFactor = _costoMaterial * factor;
    final manoObra = tarifaHr * _horas;
    final instalacion = _incluyeInstalacion ? tarifaInst * _horasInstalacion : 0;
    final total = costoConFactor + manoObra + instalacion;
    setState(() {
      _total = total;
      _specs = {
        'Material': '${widget.fmt.format(_costoMaterial)} × ${factor}x = ${widget.fmt.format(costoConFactor)}',
        'Mano de obra': '${_horas.toStringAsFixed(0)} hrs × ${widget.fmt.format(tarifaHr)} = ${widget.fmt.format(manoObra)}',
        if (_incluyeInstalacion) 'Instalación': '${_horasInstalacion.toStringAsFixed(0)} hrs × ${widget.fmt.format(tarifaInst)} = ${widget.fmt.format(instalacion)}',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PantallaBase(
      nombre: 'Carpintería', emoji: '🪵', color: _color,
      onVolver: widget.onVolver, total: _total, specs: _specs, fmt: widget.fmt,
      onAgregar: _total == null ? null : () => widget.onAgregar(ServicioSimulado(
        maquina: 'carpinteria', trabajo: 'Carpintería${_incluyeInstalacion ? " + Instalación" : ""}',
        emoji: '🪵', precio: _total!,
        descripcion: _specs.entries.map((e) => '${e.key}: ${e.value}').join(' | '),
        especificaciones: _specs)),
      children: [
        _InfoBox('Regla: costo material × ${widget.tarifas["factor_material"] ?? 1.5}x = precio base', _color),
        const SizedBox(height: 12),
        _SeccionParam('Costo total de materiales (\$)'),
        _CampoNumero('Costo materiales', _costoMaterial, (v) => setState(() => _costoMaterial = v)),
        const SizedBox(height: 12),
        _SeccionParam('Horas de mano de obra'),
        _CampoNumero('Horas', _horas, (v) => setState(() => _horas = v)),
        Text('Tarifa: ${widget.fmt.format(widget.tarifas["tarifa_hr"] ?? 180)}/hr',
          style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
        const SizedBox(height: 12),
        _Toggle('Incluye instalación en sitio', _incluyeInstalacion, (v) => setState(() => _incluyeInstalacion = v), _color),
        if (_incluyeInstalacion) ...[
          const SizedBox(height: 8),
          _CampoNumero('Horas de instalación', _horasInstalacion, (v) => setState(() => _horasInstalacion = v)),
        ],
        const SizedBox(height: 16),
        _BtnCalcular(_calcular, _color),
      ]);
  }
}

// ══════════════════════════════════════════════════════
// HERRERÍA
// ══════════════════════════════════════════════════════
class _PantallaHerreria extends StatefulWidget {
  final Map<String, double> tarifas;
  final NumberFormat fmt;
  final void Function(ServicioSimulado) onAgregar;
  final VoidCallback onVolver;
  const _PantallaHerreria({required this.tarifas, required this.fmt, required this.onAgregar, required this.onVolver});
  @override State<_PantallaHerreria> createState() => _PantallaHerreriaState();
}
class _PantallaHerreriaState extends State<_PantallaHerreria> {
  String _tipoAcero = 'acero';      // acero | inox
  double _kg = 10;
  double _horas = 3;
  bool _incluyeSoldadura = false;
  double _horasSoldadura = 1;
  bool _clienteTreMaterial = false;
  double? _total;
  Map<String, String> _specs = {};
  final _color = const Color(0xFF374151);

  void _calcular() {
    final costoKg = _tipoAcero == 'inox' ? (widget.tarifas['costo_kg_inox'] ?? 95) : (widget.tarifas['costo_kg_acero'] ?? 28);
    final tarifaHr = widget.tarifas['tarifa_hr'] ?? 250;
    final tarifaSold = widget.tarifas['tarifa_soldadura_hr'] ?? 300;
    final material = _clienteTreMaterial ? 0 : costoKg * _kg;
    final manoObra = tarifaHr * _horas;
    final soldadura = _incluyeSoldadura ? tarifaSold * _horasSoldadura : 0;
    final total = material + manoObra + soldadura;
    setState(() {
      _total = total;
      _specs = {
        'Material': _clienteTreMaterial ? 'Cliente trae material' : '${_kg}kg × ${widget.fmt.format(costoKg)}/kg = ${widget.fmt.format(material)}',
        'Mano de obra': '${_horas.toStringAsFixed(0)} hrs × ${widget.fmt.format(tarifaHr)} = ${widget.fmt.format(manoObra)}',
        if (_incluyeSoldadura) 'Soldadura': '${_horasSoldadura.toStringAsFixed(0)} hrs × ${widget.fmt.format(tarifaSold)} = ${widget.fmt.format(soldadura)}',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PantallaBase(
      nombre: 'Herrería', emoji: '🔩', color: _color,
      onVolver: widget.onVolver, total: _total, specs: _specs, fmt: widget.fmt,
      onAgregar: _total == null ? null : () => widget.onAgregar(ServicioSimulado(
        maquina: 'herreria', trabajo: 'Herrería — ${_tipoAcero == "inox" ? "Acero Inox" : "Acero"}',
        emoji: '🔩', precio: _total!,
        descripcion: _specs.entries.map((e) => '${e.key}: ${e.value}').join(' | '),
        especificaciones: _specs)),
      children: [
        _SeccionParam('Tipo de acero'),
        Row(children: [
          _ChipSel('Acero negro — ${widget.fmt.format(widget.tarifas["costo_kg_acero"] ?? 28)}/kg',
            _tipoAcero == 'acero', () => setState(() => _tipoAcero = 'acero'), _color),
          const SizedBox(width: 8),
          _ChipSel('Inoxidable — ${widget.fmt.format(widget.tarifas["costo_kg_inox"] ?? 95)}/kg',
            _tipoAcero == 'inox', () => setState(() => _tipoAcero = 'inox'), _color),
        ]),
        const SizedBox(height: 12),
        _Toggle('Cliente trae el material', _clienteTreMaterial, (v) => setState(() => _clienteTreMaterial = v), _color),
        if (!_clienteTreMaterial) ...[
          const SizedBox(height: 8),
          _CampoNumero('Kg de material', _kg, (v) => setState(() => _kg = v)),
        ],
        const SizedBox(height: 12),
        _SeccionParam('Horas de mano de obra'),
        _CampoNumero('Horas', _horas, (v) => setState(() => _horas = v)),
        const SizedBox(height: 12),
        _Toggle('Incluye soldadura especializada', _incluyeSoldadura, (v) => setState(() => _incluyeSoldadura = v), _color),
        if (_incluyeSoldadura) ...[
          const SizedBox(height: 8),
          _CampoNumero('Horas de soldadura', _horasSoldadura, (v) => setState(() => _horasSoldadura = v)),
        ],
        const SizedBox(height: 16),
        _BtnCalcular(_calcular, _color),
      ]);
  }
}

// ══════════════════════════════════════════════════════
// PANTALLA BASE REUTILIZABLE
// ══════════════════════════════════════════════════════
class _PantallaBase extends StatelessWidget {
  final String nombre, emoji;
  final Color color;
  final VoidCallback onVolver;
  final double? total;
  final Map<String, String> specs;
  final NumberFormat fmt;
  final VoidCallback? onAgregar;
  final List<Widget> children;

  const _PantallaBase({
    required this.nombre, required this.emoji, required this.color,
    required this.onVolver, required this.total, required this.specs,
    required this.fmt, required this.onAgregar, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: [
          GestureDetector(
            onTap: onVolver,
            child: const Icon(Icons.arrow_back_ios, size: 18, color: AppColors.azul)),
          const SizedBox(width: 8),
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Text(nombre, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ])),
      Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
        ...children,
        // Resultado
        if (total != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              const Text('PRECIO ESTIMADO AL CLIENTE',
                style: TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 1)),
              Text(fmt.format(total),
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 10),
              ...specs.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(e.key, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  Text(e.value, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                ]))),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: const Text('⚠️ Precio estimado. Confirma antes de enviar al cliente.',
                  style: TextStyle(fontSize: 10, color: Colors.white70), textAlign: TextAlign.center)),
              const SizedBox(height: 12),
              if (onAgregar != null)
                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onAgregar,
                    icon: const Icon(Icons.add_shopping_cart_outlined, color: Colors.white, size: 16),
                    label: const Text('Agregar al carrito',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(vertical: 10)))),
            ])),
        ],
        const SizedBox(height: 40),
      ])),
    ]);
  }
}

// ══════════════════════════════════════════════════════
// CONFIGURAR TARIFAS
// ══════════════════════════════════════════════════════
class _ConfigTarifasScreen extends StatefulWidget {
  const _ConfigTarifasScreen();
  @override State<_ConfigTarifasScreen> createState() => _ConfigTarifasScreenState();
}
class _ConfigTarifasScreenState extends State<_ConfigTarifasScreen> {
  bool _guardando = false;
  final _ctrls = <String, TextEditingController>{};

  final _campos = [
    {'maquina': 'plasma',       'clave': 'tarifa_m2_cal12',   'label': '🔥 Plasma celosía cal 12+  (\$/m²)'},
    {'maquina': 'plasma',       'clave': 'tarifa_m2_cal10',   'label': '🔥 Plasma celosía cal 10-8 (\$/m²)'},
    {'maquina': 'plasma',       'clave': 'tarifa_pieza_limpia','label': '🔥 Plasma pieza limpia (\$/pza)'},
    {'maquina': 'laser_co2',   'clave': 'tarifa_min',         'label': '🔴 Láser CO2 (\$/min)'},
    {'maquina': 'laser_fibra', 'clave': 'tarifa_min',         'label': '⚡ Láser Fibra (\$/min)'},
    {'maquina': 'router',       'clave': 'tarifa_min',         'label': '🔧 Router CNC (\$/min)'},
    {'maquina': 'router',       'clave': 'tarifa_hoja_normal', 'label': '🔧 Router hoja normal (\$/hoja)'},
    {'maquina': 'router',       'clave': 'tarifa_hoja_saturada','label': '🔧 Router hoja saturada (\$/hoja)'},
    {'maquina': 'diseno',       'clave': 'tarifa_2d_min',      'label': '✏️ Diseño 2D mínimo (\$)'},
    {'maquina': 'diseno',       'clave': 'tarifa_2d_max',      'label': '✏️ Diseño 2D máximo (\$)'},
    {'maquina': 'diseno',       'clave': 'tarifa_3d_min',      'label': '✏️ Diseño 3D mínimo (\$)'},
    {'maquina': 'diseno',       'clave': 'tarifa_3d_max',      'label': '✏️ Diseño 3D máximo (\$)'},
    {'maquina': 'impresion_3d', 'clave': 'tarifa_hr',          'label': '🖨️ Impresión 3D (\$/hr)'},
    {'maquina': 'impresion_3d', 'clave': 'tarifa_min_cobro',   'label': '🖨️ Cobro mínimo impresión (\$)'},
    {'maquina': 'carpinteria',  'clave': 'tarifa_hr',          'label': '🪵 Carpintería mano obra (\$/hr)'},
    {'maquina': 'herreria',     'clave': 'tarifa_hr',          'label': '🔩 Herrería mano obra (\$/hr)'},
  ];

  @override
  void initState() {
    super.initState();
    for (final c in _campos) {
      _ctrls['${c["maquina"]}_${c["clave"]}'] = TextEditingController();
    }
    _cargarTarifas();
  }

  Future<void> _cargarTarifas() async {
    final maquinas = _campos.map((c) => c['maquina']!).toSet();
    for (final m in maquinas) {
      final tarifas = await TarifasService.getTarifas(m);
      for (final c in _campos.where((c) => c['maquina'] == m)) {
        final key = '${c["maquina"]}_${c["clave"]}';
        final val = tarifas[c['clave']!];
        if (val != null && mounted) {
          setState(() => _ctrls[key]!.text = val % 1 == 0 ? val.toInt().toString() : val.toString());
        }
      }
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    for (final c in _campos) {
      final key = '${c["maquina"]}_${c["clave"]}';
      final val = double.tryParse(_ctrls[key]!.text);
      if (val != null) {
        await TarifasService.guardarTarifa(c['maquina']!, c['clave']!, val);
      }
    }
    TarifasService.limpiarCache();
    if (mounted) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Tarifas guardadas'), backgroundColor: AppColors.verde));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: const Text('Configurar tarifas',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: Text(_guardando ? 'Guardando...' : 'Guardar',
              style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700))),
        ]),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(10)),
          child: const Text('Estas tarifas se guardan en Supabase y se aplican en todos los cálculos del simulador.',
            style: TextStyle(fontSize: 12, color: AppColors.azul))),
        const SizedBox(height: 14),
        ..._campos.map((c) {
          final key = '${c["maquina"]}_${c["clave"]}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _ctrls[key],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: c['label'],
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true)));
        }),
      ]));
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }
}

// ══════════════════════════════════════════════════════
// WIDGETS UTILITARIOS
// ══════════════════════════════════════════════════════
Widget _SeccionParam(String label) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textoPrincipal)));

Widget _InfoBox(String texto, Color color) => Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
  child: Text(texto, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)));

Widget _ChipSel(String label, bool sel, VoidCallback onTap, Color color) => GestureDetector(
  onTap: onTap,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: sel ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: sel ? color : AppColors.grisBorde)),
    child: Text(label, style: TextStyle(
      fontSize: 11, color: sel ? Colors.white : AppColors.textoSecundario,
      fontWeight: sel ? FontWeight.w600 : FontWeight.normal))));

Widget _Toggle(String label, bool val, void Function(bool) onChanged, Color color) => Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
    Switch(value: val, onChanged: onChanged, activeColor: color),
  ]);

Widget _BtnCalcular(VoidCallback onTap, Color color) => SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.calculate_outlined, color: Colors.white, size: 18),
    label: const Text('Calcular precio estimado',
      style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700)),
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))));

class _CampoNumero extends StatelessWidget {
  final String label;
  final double valor;
  final void Function(double) onChange;
  const _CampoNumero(this.label, this.valor, this.onChange);
  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: valor % 1 == 0 ? valor.toInt().toString() : valor.toString(),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
    decoration: InputDecoration(
      labelText: label, isDense: true, filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
    onChanged: (v) { final d = double.tryParse(v); if (d != null) onChange(d); });
}

class _CampoNumeroInt extends StatelessWidget {
  final String label;
  final int valor;
  final void Function(int) onChange;
  const _CampoNumeroInt(this.label, this.valor, this.onChange);
  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: valor.toString(),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label, isDense: true, filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
    onChanged: (v) { final i = int.tryParse(v); if (i != null) onChange(i); });
}
