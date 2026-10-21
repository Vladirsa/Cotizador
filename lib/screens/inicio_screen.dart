import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/hetna_api.dart';
import 'calculadora_cnc_screen.dart';
import 'envios_screen.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});
  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic> _stats = {};
  List<Cotizacion> _cotizaciones = [];
  List<Pedido> _pedidos = [];
  List<Map<String, dynamic>> _gastos = [];
  List<Map<String, dynamic>> _materiales = [];
  bool _cargando = true;
  double _costoFijoMensual = 0;
  String _periodoDash = 'mes'; // 'dia' | 'semana' | 'mes'
  String _filtroProduccion = 'Todos'; // filtro clickeable en tab Producción
  String _busquedaProductos = ''; // búsqueda en tab Productos
  String _catFiltroProductos = 'Todas'; // filtro de categoría en tab Productos
  List<Producto> _catalogoProductos = []; // catálogo real, para saber categorías
  // Filtros inventario
  String _filtroCategoria = 'Todas';
  String _filtroStock = 'Todos';

  final _fmt = NumberFormat('\$#,##0', 'es_MX');

  final _coloresEstado = {
    'Borrador': Colors.grey,
    'Enviada': Color(0xFF185fa5),
    'Aprobada': Color(0xFF1d9e75),
    'Pedido': Color(0xFF7c3aed),
    'Vencida': Color(0xFFef9f27),
    'Rechazada': Color(0xFFe24b4a),
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _cargar();
  }

  // Trae gastos de los últimos 90 días (sin restringir a "Este mes")
  // para poder filtrar localmente por Día / Semana / Mes sin ir al servidor
  Future<List<Map<String, dynamic>>> _getGastosAmplio() async {
    try {
      final desde = DateTime.now().subtract(const Duration(days: 90));
      final res = await Supabase.instance.client
        .from('gastos')
        .select()
        .gte('fecha', desde.toIso8601String())
        .order('fecha', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
  }

  // Rango de fecha "desde" según el filtro Día/Semana/Mes seleccionado
  DateTime get _desdePeriodo {
    final ahora = DateTime.now();
    switch (_periodoDash) {
      case 'dia':
        return DateTime(ahora.year, ahora.month, ahora.day);
      case 'semana':
        final inicioSemana = ahora.subtract(Duration(days: ahora.weekday - 1));
        return DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);
      default: // mes
        return DateTime(ahora.year, ahora.month, 1);
    }
  }

  // Pedidos y gastos filtrados por el periodo seleccionado
  List<Pedido> get _pedidosPeriodo => _pedidos.where((p) =>
    p.createdAt != null && !p.createdAt!.isBefore(_desdePeriodo)).toList();

  List<Map<String, dynamic>> get _gastosPeriodo => _gastos.where((g) {
    final f = g['fecha'] != null ? DateTime.tryParse(g['fecha']) : null;
    return f != null && !f.isBefore(_desdePeriodo);
  }).toList();

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final results = await Future.wait([
        SupabaseService.getEstadisticasMes(),
        SupabaseService.getCotizaciones(),
        SupabaseService.getPedidos(),
        _getGastosAmplio(), // últimos 90 días, para filtrar día/semana/mes localmente
        SupabaseService.getMateriales(),
        SupabaseService.getProductos(), // catálogo real, para categorías en tab Productos
      ]);
      // Costo fijo mensual configurado en "Costos del taller" -> meta de punto de equilibrio
      double costoFijo = 0;
      try {
        final cfg = await Supabase.instance.client
          .from('empresa_config')
          .select('costo_fijo_mensual')
          .limit(1).maybeSingle();
        costoFijo = (cfg?['costo_fijo_mensual'] as num?)?.toDouble() ?? 0;
      } catch (_) {}

      if (mounted) setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _cotizaciones = results[1] as List<Cotizacion>;
        _pedidos = results[2] as List<Pedido>;
        _gastos = results[3] as List<Map<String, dynamic>>;
        _materiales = results[4] as List<Map<String, dynamic>>;
        _catalogoProductos = results[5] as List<Producto>;
        _costoFijoMensual = costoFijo;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: Row(children: [
          Container(width: 28, height: 28,
            decoration: BoxDecoration(color: AppColors.azul, borderRadius: BorderRadius.circular(6)),
            child: const Center(child: Text('H', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
          const SizedBox(width: 8),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HETNA CNC', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.azul)),
            Text('Panel de control', style: TextStyle(fontSize: 10, color: AppColors.textoSecundario, height: 1)),
          ]),
        ]),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          isScrollable: true,
          tabs: const [
            Tab(text: '📊 Dashboard'),
            Tab(text: '📋 Cotizaciones'),
            Tab(text: '🏭 Producción'),
            Tab(text: '📦 Inventario'),
            Tab(text: '🛒 Productos'),
          ],
        ),
      ),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            _tabDashboard(),
            _tabCotizaciones(),
            _tabProduccion(),
            _tabInventario(),
            _tabProductos(),
          ]),
    );
  }

  // ══════════════════════════════════════
  // TAB 1 — GENERAL (portada)
  // ══════════════════════════════════════
  // ══════════════════════════════════════
  // DASHBOARD UNIFICADO — General + Finanzas + Ventas
  // con filtro dinámico por Día / Semana / Mes
  // ══════════════════════════════════════

  // ── META DE PUNTO DE EQUILIBRIO (siempre mensual) ────
  Widget _cardMetaEquilibrio({required double totalVentas}) {
    final meta = _costoFijoMensual;
    final progreso = meta > 0 ? (totalVentas / meta).clamp(0.0, 1.0) : 0.0;
    final cubierto = totalVentas >= meta;
    final faltante = (meta - totalVentas).clamp(0, double.infinity);

    final hoy = DateTime.now();
    final diasEnMes = DateTime(hoy.year, hoy.month + 1, 0).day;
    final diasRestantes = (diasEnMes - hoy.day).clamp(1, diasEnMes);
    final promedioDiarioNecesario = faltante / diasRestantes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: cubierto
          ? [AppColors.verde, const Color(0xFF15803d)]
          : [const Color(0xFF334155), const Color(0xFF1e293b)]),
        borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(cubierto ? Icons.check_circle : Icons.flag_outlined,
            color: Colors.white, size: 18),
          const SizedBox(width: 6),
          const Text('META: CUBRIR COSTOS FIJOS DEL MES',
            style: TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 1)),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_fmt.format(totalVentas),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(width: 6),
          Padding(padding: const EdgeInsets.only(bottom: 4),
            child: Text('de ${_fmt.format(meta)}',
              style: const TextStyle(fontSize: 13, color: Colors.white60))),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progreso, minHeight: 10,
            backgroundColor: Colors.white.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(
              cubierto ? Colors.white : AppColors.ambar))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(progreso * 100).toStringAsFixed(0)}% cubierto',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(cubierto
            ? '✅ Meta alcanzada este mes'
            : 'Faltan ${_fmt.format(faltante)}',
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        if (!cubierto) ...[
          const SizedBox(height: 4),
          Text('Necesitas vender ~${_fmt.format(promedioDiarioNecesario)}/día '
            'los próximos $diasRestantes días para cubrir renta, luz y demás gastos fijos.',
            style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ],
      ]));
  }

  Widget _cardConfigurarCostos() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.ambarClaro,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.ambar.withOpacity(0.4))),
    child: Row(children: [
      const Icon(Icons.flag_outlined, color: AppColors.ambar, size: 22),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Configura tus costos fijos',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ambar)),
        const Text('Ve a "Costos del taller" (renta, luz, etc.) para ver aquí tu meta mensual de punto de equilibrio.',
          style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      ])),
    ]));

  // ── Selector de periodo Día / Semana / Mes ────────────
  Widget _selectorPeriodo() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Row(children: [
      _chipPeriodo('dia', 'Día'),
      _chipPeriodo('semana', 'Semana'),
      _chipPeriodo('mes', 'Mes'),
    ]));

  Widget _chipPeriodo(String val, String label) {
    final sel = _periodoDash == val;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _periodoDash = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.azul : Colors.transparent,
          borderRadius: BorderRadius.circular(8)),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: sel ? Colors.white : AppColors.textoSecundario)))));
  }

  Widget _tabDashboard() {
    // Datos filtrados por el periodo seleccionado (Día/Semana/Mes)
    final pedidosPeriodo = _pedidosPeriodo;
    final gastosPeriodo = _gastosPeriodo;

    final ventas = pedidosPeriodo.where((p) =>
      p.estado == 'Entregado' || p.estado == 'PagoCompleto' || p.estado == 'Entrega').toList();
    final totalVentas = ventas.fold(0.0, (s, p) => s + (p.total ?? 0));
    final totalGastosDirect = gastosPeriodo.where((g) => g['tipo'] == 'directo')
      .fold(0.0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0));
    final totalGastosIndir = gastosPeriodo.where((g) => g['tipo'] == 'indirecto')
      .fold(0.0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0));
    final totalGastos = totalGastosDirect + totalGastosIndir;
    final utilidadNeta = totalVentas - totalGastos;
    final margen = totalVentas > 0 ? (utilidadNeta / totalVentas * 100) : 0.0;

    final pedidosActivos = _pedidos.where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado').length;
    final alertas = _stats['alertas_pendientes'] ?? 0;
    final materialesBajos = _materiales.where((m) =>
      (m['stock_actual'] as int? ?? 0) <= (m['stock_minimo'] as int? ?? 1)).length;

    final enProceso = _pedidos.where((p) =>
      p.estado == 'Pago50' || p.estado == 'Produccion' || p.estado == 'Pruebas').toList();
    final porCobrar = enProceso.fold(0.0, (s, p) => s + ((p.total ?? 0) / 2));

    // Gastos por categoría (del periodo seleccionado)
    final porCategoria = <String, double>{};
    for (final g in gastosPeriodo) {
      final cat = g['categoria'] as String? ?? 'Otro';
      porCategoria[cat] = (porCategoria[cat] ?? 0) + ((g['monto'] as num?)?.toDouble() ?? 0);
    }
    final sortedCategorias = porCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Ventas por día de la semana (siempre sobre el periodo seleccionado)
    final Map<int, double> ventasPorDia = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    for (final p in ventas) {
      if (p.createdAt != null) {
        final dia = p.createdAt!.weekday % 7;
        ventasPorDia[dia] = (ventasPorDia[dia] ?? 0) + (p.total ?? 0);
      }
    }
    final maxDia = ventasPorDia.values.fold(0.0, (a, b) => a > b ? a : b);

    // Distribución de cotizaciones (histórico completo, no depende del periodo)
    final estadosCot = <String, int>{};
    for (final c in _cotizaciones) {
      estadosCot[c.estado] = (estadosCot[c.estado] ?? 0) + 1;
    }
    final coloresCot = [
      const Color(0xFF185fa5), const Color(0xFF1d9e75), const Color(0xFF7c3aed),
      const Color(0xFFef9f27), const Color(0xFFe24b4a), Colors.grey,
    ];
    final totalCots = _cotizaciones.length;
    final aprobadas = _cotizaciones.where((c) => c.estado == 'Aprobada' || c.estado == 'Pedido').length;
    final tasaConversion = totalCots > 0 ? (aprobadas / totalCots * 100) : 0.0;

    final etiquetaPeriodo = {'dia': 'HOY', 'semana': 'ESTA SEMANA', 'mes': 'ESTE MES'}[_periodoDash] ?? 'ESTE MES';

    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [

      // ── Selector de periodo ──
      _selectorPeriodo(),
      const SizedBox(height: 14),

      // ── Meta de punto de equilibrio (siempre mensual) ──
      if (_costoFijoMensual > 0) _cardMetaEquilibrio(totalVentas: (_stats['ventas_mes'] as num?)?.toDouble() ?? 0),
      if (_costoFijoMensual > 0) const SizedBox(height: 14),
      if (_costoFijoMensual == 0) _cardConfigurarCostos(),
      if (_costoFijoMensual == 0) const SizedBox(height: 14),

      // ── Hero financiero del periodo seleccionado ──
      Container(padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.azul, Color(0xFF2d5a8e)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('UTILIDAD NETA — $etiquetaPeriodo',
            style: const TextStyle(fontSize: 10, color: Colors.white60, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(_fmt.format(utilidadNeta),
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
              color: utilidadNeta >= 0 ? Colors.greenAccent : Colors.redAccent)),
          Text('Margen: ${margen.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 14),
          Row(children: [
            _heroStat('Ventas', _fmt.format(totalVentas), Colors.greenAccent),
            _heroDivider(),
            _heroStat('Gastos', _fmt.format(totalGastos), Colors.orangeAccent),
            _heroDivider(),
            _heroStat('Por cobrar', _fmt.format(porCobrar), Colors.yellow.shade200),
          ]),
        ])),

      const SizedBox(height: 14),

      // ── Herramientas y ecosistema HETNA ──
      _accesosHetna(),
      const SizedBox(height: 14),

      // ── Alertas rápidas (siempre actuales, no dependen del periodo) ──
      if (alertas > 0 || materialesBajos > 0) ...[
        Row(children: [
          if (alertas > 0) Expanded(child: _alertaCard(
            '⚠️ $alertas seguimientos\npendientes', AppColors.ambar)),
          if (alertas > 0 && materialesBajos > 0) const SizedBox(width: 8),
          if (materialesBajos > 0) Expanded(child: _alertaCard(
            '📦 $materialesBajos materiales\ncon stock bajo', AppColors.rojo)),
        ]),
        const SizedBox(height: 14),
      ],

      // ── KPIs rápidos ──
      Row(children: [
        Expanded(child: _kpiCard2('Ventas cerradas', '${ventas.length}', AppColors.verde, Icons.check_circle_outline)),
        const SizedBox(width: 8),
        Expanded(child: _kpiCard2('En proceso', '${enProceso.length}', AppColors.ambar, Icons.pending_outlined)),
        const SizedBox(width: 8),
        Expanded(child: _kpiCard2('Ticket prom.', ventas.isEmpty ? '\$0' : _fmt.format(totalVentas / ventas.length), AppColors.azul, Icons.receipt_outlined)),
      ]),
      const SizedBox(height: 8),
      GridView.count(crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.6,
        children: [
          _statCard('Cotizaciones', '${_cotizaciones.length}', AppColors.azul, Icons.description_outlined),
          _statCard('Pedidos activos', '$pedidosActivos', const Color(0xFF7c3aed), Icons.local_shipping_outlined),
          _statCard('Entregados', '${_pedidos.where((p) => p.estado == "Entregado").length}', AppColors.verde, Icons.check_circle_outline),
          _statCard('Alertas', '$alertas', alertas > 0 ? AppColors.rojo : AppColors.verde, Icons.notifications_outlined),
        ]),

      const SizedBox(height: 16),

      // ── Gastos por categoría (del periodo) ──
      _seccionInicio('GASTOS POR CATEGORÍA — $etiquetaPeriodo'),
      if (sortedCategorias.isEmpty)
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: const Center(child: Text('Sin gastos en este periodo', style: TextStyle(color: AppColors.textoSecundario))))
      else Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(children: sortedCategorias.map((e) {
          final pct = totalGastos > 0 ? e.value / totalGastos : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(e.key, style: const TextStyle(fontSize: 12)),
              Text(_fmt.format(e.value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.azul)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
              value: pct, backgroundColor: AppColors.gris, minHeight: 5,
              valueColor: const AlwaysStoppedAnimation(AppColors.ambar))),
            Text('${(pct * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 9, color: AppColors.textoSecundario)),
          ]));
        }).toList())),

      const SizedBox(height: 16),

      // ── Gráfica: ventas por día de la semana ──
      _seccionInicio('VENTAS POR DÍA DE LA SEMANA'),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: ventas.isEmpty
          ? const SizedBox(height: 120, child: Center(
              child: Text('Sin datos de ventas en este periodo', style: TextStyle(color: AppColors.textoSecundario, fontSize: 13))))
          : SizedBox(height: 180,
              child: BarChart(BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxDia > 0 ? maxDia * 1.25 : 100,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => AppColors.azul.withOpacity(0.85),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final dias = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
                      return BarTooltipItem(
                        '${dias[group.x]}\n${_fmt.format(rod.toY)}',
                        const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600));
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const dias = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];
                      final i = value.toInt();
                      if (i < 0 || i > 6) return const SizedBox();
                      return Padding(padding: const EdgeInsets.only(top: 4),
                        child: Text(dias[i], style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)));
                    },
                    reservedSize: 22,
                  )),
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const Text('', style: TextStyle(fontSize: 9));
                      return Text('\$${(value / 1000).toStringAsFixed(0)}k',
                        style: const TextStyle(fontSize: 9, color: AppColors.textoSecundario));
                    },
                  )),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxDia > 0 ? maxDia / 4 : 25,
                  getDrawingHorizontalLine: (v) => FlLine(color: AppColors.grisBorde, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                barGroups: ventasPorDia.entries.map((e) => BarChartGroupData(
                  x: e.key,
                  barRods: [BarChartRodData(
                    toY: e.value,
                    color: e.value > 0 ? AppColors.azul : AppColors.grisBorde,
                    width: 28,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  )],
                )).toList(),
              ))),
      ),

      const SizedBox(height: 16),

      // ── Gráfica: distribución de cotizaciones (histórico) ──
      _seccionInicio('DISTRIBUCIÓN DE COTIZACIONES'),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: _cotizaciones.isEmpty
          ? const SizedBox(height: 120, child: Center(
              child: Text('Sin cotizaciones', style: TextStyle(color: AppColors.textoSecundario, fontSize: 13))))
          : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              SizedBox(width: 130, height: 130,
                child: PieChart(PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 32,
                  sections: estadosCot.entries.mapIndexed((idx, e) {
                    final color = coloresCot[idx % coloresCot.length];
                    final pct = _cotizaciones.isNotEmpty ? e.value / _cotizaciones.length * 100 : 0.0;
                    return PieChartSectionData(
                      value: e.value.toDouble(),
                      color: color,
                      title: '${pct.toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                      radius: 40,
                    );
                  }).toList(),
                ))),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: estadosCot.entries.mapIndexed((idx, e) {
                  final color = coloresCot[idx % coloresCot.length];
                  return Padding(padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(e.key, style: const TextStyle(fontSize: 11))),
                      Text('${e.value}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                    ]));
                }).toList(),
              )),
            ]),
      ),

      const SizedBox(height: 16),

      // ── Tasa de conversión (histórico) ──
      _seccionInicio('TASA DE CONVERSIÓN'),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${tasaConversion.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                  color: tasaConversion >= 50 ? AppColors.verde : AppColors.ambar)),
              const Text('cotizaciones convertidas', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$aprobadas / $totalCots', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
              const Text('aprobadas / total', style: TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
            ]),
          ]),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: tasaConversion / 100,
              backgroundColor: AppColors.gris,
              minHeight: 12,
              valueColor: AlwaysStoppedAnimation(
                tasaConversion >= 70 ? AppColors.verde
                : tasaConversion >= 40 ? AppColors.ambar
                : AppColors.rojo),
            )),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Meta: 70%', style: TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: (tasaConversion >= 70 ? AppColors.verde : tasaConversion >= 40 ? AppColors.ambar : AppColors.rojo).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
              child: Text(
                tasaConversion >= 70 ? '🎯 Excelente' : tasaConversion >= 40 ? '📈 En progreso' : '⚠️ Mejorar',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: tasaConversion >= 70 ? AppColors.verde : tasaConversion >= 40 ? AppColors.ambar : AppColors.rojo))),
          ]),
        ])),

      const SizedBox(height: 16),

      // ── Pedidos en proceso (siempre actuales) ──
      if (_pedidos.where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado').isNotEmpty) ...[
        _seccionInicio('PEDIDOS EN PROCESO'),
        ..._pedidos.where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado').take(3).map((p) => _miniPedido(p)),
        const SizedBox(height: 16),
      ],

      // ── Ventas del periodo ──
      _seccionInicio('VENTAS — $etiquetaPeriodo'),
      if (ventas.isEmpty)
        Container(padding: const EdgeInsets.all(24), alignment: Alignment.center,
          child: const Text('Sin ventas en este periodo', style: TextStyle(color: AppColors.textoSecundario)))
      else
        ...ventas.take(10).map((p) => Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.cliente?.nombre ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(p.folio, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
              const SizedBox(height: 3),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.verde.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(p.estado, style: const TextStyle(fontSize: 10, color: AppColors.verde, fontWeight: FontWeight.w500))),
            ])),
            Text(_fmt.format(p.total ?? 0),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.azul)),
          ]))),

      const SizedBox(height: 14),

      // ── Gastos del periodo ──
      _seccionInicio('GASTOS — $etiquetaPeriodo'),
      if (gastosPeriodo.isEmpty)
        Container(padding: const EdgeInsets.all(16), alignment: Alignment.center,
          child: const Text('Sin gastos registrados en este periodo', style: TextStyle(color: AppColors.textoSecundario)))
      else
        ...gastosPeriodo.take(8).map((g) => Container(
          margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g['concepto'] ?? g['descripcion'] ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text(g['categoria'] ?? g['tipo'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
            ])),
            Text(_fmt.format((g['monto'] as num?)?.toDouble() ?? 0),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.rojo)),
          ]))),
      const SizedBox(height: 20),
    ]));
  }

  // ══════════════════════════════════════
  // TAB 4 — COTIZACIONES
  // ══════════════════════════════════════
  Widget _tabCotizaciones() {
    final estados = ['Todos', 'Borrador', 'Enviada', 'Aprobada', 'Pedido', 'Vencida'];
    String _filtro = 'Todos';

    return StatefulBuilder(builder: (ctx, setS) {
      final hoy = DateTime.now();
      bool esVencida(Cotizacion cot) {
        if (cot.estado != 'Enviada') return false;
        if (cot.createdAt == null) return false;
        final vence = cot.createdAt!.add(Duration(days: cot.vigenciaDias));
        return hoy.isAfter(vence);
      }
      final filtradas = _filtro == 'Todos'
        ? _cotizaciones
        : _filtro == 'Vencida'
          ? _cotizaciones.where(esVencida).toList()
          : _cotizaciones.where((c) => c.estado == _filtro && !esVencida(c)).toList();

      return Column(children: [
        // ─── Cabecera con refresh ───
        Container(color: Colors.white,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: estados.map((e) {
              final activo = _filtro == e;
              final color = _coloresEstado[e] ?? AppColors.azul;
              final hoy2 = DateTime.now();
              bool esVen(Cotizacion cot) {
                if (cot.estado != 'Enviada' || cot.createdAt == null) return false;
                return hoy2.isAfter(cot.createdAt!.add(Duration(days: cot.vigenciaDias)));
              }
              final count = e == 'Todos'
                ? _cotizaciones.length
                : e == 'Vencida'
                  ? _cotizaciones.where(esVen).length
                  : _cotizaciones.where((c) => c.estado == e && !esVen(c)).length;
              return GestureDetector(
                onTap: () => setS(() => _filtro = e),
                child: Container(
                  margin: const EdgeInsets.only(right: 6, bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: activo ? (e == 'Todos' ? AppColors.azul : color) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: activo ? (e == 'Todos' ? AppColors.azul : color) : AppColors.grisBorde)),
                  child: Text('$e ($count)', style: TextStyle(fontSize: 11,
                    color: activo ? Colors.white : AppColors.textoSecundario,
                    fontWeight: activo ? FontWeight.w600 : FontWeight.normal))));
            }).toList()))),

        // ─── Resumen por estado ───
        Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Row(children: estados.where((e) => e != 'Todos').map((e) {
            final color = _coloresEstado[e] ?? Colors.grey;
            final hoy3 = DateTime.now();
            bool esVen(Cotizacion cot) {
              if (cot.estado != 'Enviada' || cot.createdAt == null) return false;
              return hoy3.isAfter(cot.createdAt!.add(Duration(days: cot.vigenciaDias)));
            }
            final count = e == 'Vencida'
              ? _cotizaciones.where(esVen).length
              : _cotizaciones.where((c) => c.estado == e && !esVen(c)).length;
            final monto = e == 'Vencida'
              ? _cotizaciones.where(esVen).fold(0.0, (s, c) => s + c.total)
              : _cotizaciones.where((c) => c.estado == e && !esVen(c)).fold(0.0, (s, c) => s + c.total);
            return Expanded(child: GestureDetector(
              onTap: () => setS(() => _filtro = e),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _filtro == e ? color.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: count > 0 ? color : AppColors.textoSecundario)),
                  Text(e, style: const TextStyle(fontSize: 7, color: AppColors.textoSecundario), textAlign: TextAlign.center),
                  if (monto > 0) Text(_fmt.format(monto), style: TextStyle(fontSize: 7, color: color), textAlign: TextAlign.center),
                ]))));
          }).toList())),

        // ─── Lista ───
        Expanded(child: RefreshIndicator(onRefresh: _cargar, child: filtradas.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.description_outlined, size: 48, color: AppColors.textoSecundario),
              const SizedBox(height: 8),
              Text('No hay cotizaciones en "$_filtro"',
                style: const TextStyle(color: AppColors.textoSecundario)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtradas.length,
              itemBuilder: (_, i) => _itemCotizacion(filtradas[i])))),
      ]);
    });
  }

  // ══════════════════════════════════════
  // TAB 5 — PRODUCCIÓN
  // ══════════════════════════════════════
  Widget _tabProduccion() {
    // Etapas reales que usa el sistema (coinciden con avances_screen.dart)
    final etapas = ['Pedido', 'Pago50', 'Produccion', 'Pruebas', 'PagoCompleto', 'Entrega', 'Entregado'];
    final etiquetas = {
      'Pedido': 'Pedido', 'Pago50': 'Pago 50%',
      'Produccion': 'Producción', 'Pruebas': 'Pruebas',
      'PagoCompleto': 'Pago 100%', 'Entrega': 'Entrega', 'Entregado': 'Entregado',
    };
    final coloresEtapa = {
      'Pedido': AppColors.azul, 'Pago50': AppColors.ambar,
      'Produccion': const Color(0xFF7c3aed), 'Pruebas': AppColors.rojo,
      'PagoCompleto': const Color(0xFF059669),
      'Entrega': AppColors.verde, 'Entregado': AppColors.verde,
    };

    // Lista filtrada según la tarjeta de estado seleccionada
    final pedidosMostrados = _filtroProduccion == 'Todos'
      ? _pedidos.where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado').toList()
      : _pedidos.where((p) => p.estado == _filtroProduccion).toList();

    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _seccion('ESTADO DE PRODUCCIÓN'),
        if (_filtroProduccion != 'Todos')
          GestureDetector(
            onTap: () => setState(() => _filtroProduccion = 'Todos'),
            child: const Text('Ver todos ✕',
              style: TextStyle(fontSize: 11, color: AppColors.azul, fontWeight: FontWeight.w600))),
      ]),
      // Tarjetas de estado — ahora funcionan como FILTRO al tocarlas
      GridView.count(crossAxisCount: 3, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.4,
        children: etapas.map((e) {
          final count = _pedidos.where((p) => p.estado == e).length;
          final color = coloresEtapa[e] ?? AppColors.azul;
          final monto = _pedidos.where((p) => p.estado == e).fold(0.0, (s, p) => s + (p.total ?? 0));
          final seleccionado = _filtroProduccion == e;
          return GestureDetector(
            onTap: () => setState(() => _filtroProduccion = seleccionado ? 'Todos' : e),
            child: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: seleccionado ? color.withOpacity(0.12) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: seleccionado ? color : (count > 0 ? color.withOpacity(0.4) : AppColors.grisBorde),
                  width: seleccionado ? 1.5 : 0.5)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: count > 0 ? color : AppColors.textoSecundario)),
                Text(etiquetas[e] ?? e, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: AppColors.textoSecundario)),
                if (monto > 0) Text(_fmt.format(monto), style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600)),
              ])));
        }).toList()),

      const SizedBox(height: 14),
      _seccion(_filtroProduccion == 'Todos'
        ? 'PEDIDOS ACTIVOS'
        : 'PEDIDOS EN "${etiquetas[_filtroProduccion] ?? _filtroProduccion}"'),
      ...pedidosMostrados.map((p) => _miniPedido(p)),
      if (pedidosMostrados.isEmpty)
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(
            _filtroProduccion == 'Todos' ? 'No hay pedidos activos' : 'No hay pedidos en esta etapa',
            style: const TextStyle(color: AppColors.textoSecundario)))),
    ]));
  }

  // ══════════════════════════════════════
  // TAB 6 — INVENTARIO
  // ══════════════════════════════════════
  Widget _tabInventario() {
    final seen = <String>{};
    final todosLosMateriales = _materiales.where((m) {
      final id = m['id']?.toString() ?? m['nombre']?.toString() ?? '';
      return seen.add(id);
    }).toList();

    final categorias = todosLosMateriales.map((m) => m['categoria'] as String? ?? '').toSet().toList()..sort();

    var materiales = todosLosMateriales.where((m) {
      final cat = m['categoria'] as String? ?? '';
      final stock = m['stock_actual'] as int? ?? 0;
      final minimo = m['stock_minimo'] as int? ?? 1;
      final pasaCat = _filtroCategoria == 'Todas' || cat == _filtroCategoria;
      final pasaStock = _filtroStock == 'Todos'
        || (_filtroStock == 'Stock bajo' && stock <= minimo)
        || (_filtroStock == 'Normal' && stock > minimo);
      return pasaCat && pasaStock;
    }).toList();

    final bajos = todosLosMateriales.where((m) =>
      (m['stock_actual'] as int? ?? 0) <= (m['stock_minimo'] as int? ?? 1)).toList();
    final categoriasFiltradas = materiales.map((m) => m['categoria'] as String? ?? '').toSet().toList()..sort();

    final valorTotal = todosLosMateriales.fold(0.0, (s, m) =>
      s + ((m['stock_actual'] as int? ?? 0) * ((m['costo_unitario'] as num?)?.toDouble() ?? 0)));

    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [

      Row(children: [
        Expanded(child: _statCard('Total materiales', '${todosLosMateriales.length}', AppColors.azul, Icons.inventory_2_outlined)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('Stock bajo', '${bajos.length}', bajos.isEmpty ? AppColors.verde : AppColors.rojo, Icons.warning_amber_outlined)),
      ]),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Valor total en bodega:', style: TextStyle(fontSize: 13)),
          Text(_fmt.format(valorTotal), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.azul)),
        ])),

      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('FILTRAR', style: TextStyle(fontSize: 9, color: AppColors.textoSecundario, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.filter_list, size: 14, color: AppColors.textoSecundario),
            const SizedBox(width: 6),
            const Text('Stock:', style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            const SizedBox(width: 8),
            ...['Todos', 'Stock bajo', 'Normal'].map((op) {
              final activo = _filtroStock == op;
              final color = op == 'Stock bajo' ? AppColors.rojo : op == 'Normal' ? AppColors.verde : AppColors.azul;
              return GestureDetector(
                onTap: () => setState(() => _filtroStock = op),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: activo ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: activo ? color : AppColors.grisBorde)),
                  child: Text(op, style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: activo ? Colors.white : AppColors.textoSecundario))));
            }),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.category_outlined, size: 14, color: AppColors.textoSecundario),
            const SizedBox(width: 6),
            const Text('Cat:', style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            const SizedBox(width: 8),
            Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: Row(children: ['Todas', ...categorias].map((cat) {
                final activo = _filtroCategoria == cat;
                return GestureDetector(
                  onTap: () => setState(() => _filtroCategoria = cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: activo ? AppColors.azul : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: activo ? AppColors.azul : AppColors.grisBorde)),
                    child: Text(cat, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: activo ? Colors.white : AppColors.textoSecundario))));
              }).toList()))),
          ]),
        ])),

      const SizedBox(height: 12),
      if (materiales.isEmpty)
        Container(padding: const EdgeInsets.all(24), alignment: Alignment.center,
          child: const Text('Sin materiales con estos filtros',
            style: TextStyle(color: AppColors.textoSecundario, fontSize: 13)))
      else ...[
        Text('${materiales.length} resultado${materiales.length != 1 ? "s" : ""}',
          style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
        const SizedBox(height: 6),
        ...categoriasFiltradas.map((cat) {
          final items = materiales.where((m) => m['categoria'] == cat).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Text(cat.toUpperCase(),
                style: const TextStyle(fontSize: 10, color: AppColors.azul, letterSpacing: 1, fontWeight: FontWeight.w600))),
            ...items.map((m) {
              final stockActual = m['stock_actual'] as int? ?? 0;
              final stockMinimo = m['stock_minimo'] as int? ?? 1;
              final stockBajo = stockActual <= stockMinimo;
              return Container(margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: stockBajo ? AppColors.rojo.withOpacity(0.35) : AppColors.grisBorde, width: 0.5)),
                child: Row(children: [
                  if (stockBajo) const Padding(padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.warning_amber, color: AppColors.rojo, size: 14)),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m['nombre'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    if (stockBajo)
                      Text('Mínimo: $stockMinimo ${m['unidad']}',
                        style: const TextStyle(fontSize: 10, color: AppColors.rojo)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$stockActual ${m['unidad']}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: stockBajo ? AppColors.rojo : AppColors.verde)),
                    if ((m['costo_unitario'] as num?)?.toDouble() != null)
                      Text(_fmt.format(stockActual * ((m['costo_unitario'] as num?)?.toDouble() ?? 0)),
                        style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
                  ]),
                ]));
            }),
          ]);
        }),
      ],
      const SizedBox(height: 20),
    ]));
  }

  // ══════════════════════════════════════
  // TAB 7 — PRODUCTOS top ventas
  // ══════════════════════════════════════
  Widget _tabProductos() {
    // Contar ventas por producto (histórico de cotizaciones)
    final conteo = <String, Map<String, dynamic>>{};
    for (final cot in _cotizaciones.where((c) => c.estado == 'Pedido' || c.estado == 'Entregado')) {
      for (final item in cot.items) {
        final key = item.nombreProducto;
        if (!conteo.containsKey(key)) {
          conteo[key] = {'nombre': key, 'cantidad': 0, 'total': 0.0};
        }
        conteo[key]!['cantidad'] = (conteo[key]!['cantidad'] as int) + item.cantidad;
        conteo[key]!['total'] = (conteo[key]!['total'] as double) + item.subtotal;
      }
    }

    // Cruzar con el catálogo real para saber la categoría de cada producto
    final categoriaPorNombre = <String, String>{};
    for (final p in _catalogoProductos) {
      categoriaPorNombre[p.nombre] = p.categoriaNombre ?? 'Sin categoría';
    }
    final categoriasDisponibles = <String>{'Todas'};
    for (final key in conteo.keys) {
      categoriasDisponibles.add(categoriaPorNombre[key] ?? 'Sin categoría');
    }

    var lista = conteo.values.toList();

    // Filtro por categoría
    if (_catFiltroProductos != 'Todas') {
      lista = lista.where((p) =>
        (categoriaPorNombre[p['nombre']] ?? 'Sin categoría') == _catFiltroProductos).toList();
    }
    // Búsqueda por nombre
    if (_busquedaProductos.trim().isNotEmpty) {
      final q = _busquedaProductos.trim().toLowerCase();
      lista = lista.where((p) => (p['nombre'] as String).toLowerCase().contains(q)).toList();
    }

    lista.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    final maxTotalGlobal = conteo.values.isEmpty ? 0.0
      : conteo.values.map((p) => p['total'] as double).reduce((a, b) => a > b ? a : b);

    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [
      // Búsqueda
      TextField(
        onChanged: (v) => setState(() => _busquedaProductos = v),
        decoration: InputDecoration(
          hintText: 'Buscar producto...',
          hintStyle: const TextStyle(fontSize: 12),
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _busquedaProductos.isNotEmpty
            ? IconButton(icon: const Icon(Icons.close, size: 16),
                onPressed: () => setState(() => _busquedaProductos = ''))
            : null,
          isDense: true, filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.grisBorde))),
        style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 10),
      // Filtro por categoría
      SizedBox(height: 32,
        child: ListView(scrollDirection: Axis.horizontal,
          children: categoriasDisponibles.toList().map((cat) {
            final activo = _catFiltroProductos == cat;
            return GestureDetector(
              onTap: () => setState(() => _catFiltroProductos = cat),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: activo ? AppColors.azul : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: activo ? AppColors.azul : AppColors.grisBorde)),
                child: Text(cat, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: activo ? Colors.white : AppColors.textoSecundario))));
          }).toList())),
      const SizedBox(height: 14),

      if (lista.isEmpty)
        Container(padding: const EdgeInsets.all(32), alignment: Alignment.center,
          child: Column(children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.grisBorde),
            const SizedBox(height: 8),
            Text(conteo.isEmpty
              ? 'Sin datos de productos vendidos'
              : 'Sin resultados con este filtro',
              style: const TextStyle(color: AppColors.textoSecundario)),
          ]))
      else ...[
        _seccionInicio('TOP PRODUCTOS POR VENTAS (${lista.length})'),
        ...lista.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          final pct = maxTotalGlobal > 0 ? (p['total'] as double) / maxTotalGlobal : 0.0;
          return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.grisBorde, width: 0.5)),
            child: Row(children: [
              Container(width: 30, height: 30,
                decoration: BoxDecoration(color: AppColors.azul, borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('${i+1}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['nombre'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(categoriaPorNombre[p['nombre']] ?? 'Sin categoría',
                  style: const TextStyle(fontSize: 9, color: AppColors.textoSecundario)),
                const SizedBox(height: 4),
                ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
                  value: pct, backgroundColor: AppColors.gris, minHeight: 5,
                  valueColor: const AlwaysStoppedAnimation(AppColors.azul))),
                Text('${p['cantidad']} unidades', style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
              ])),
              const SizedBox(width: 10),
              Text(_fmt.format(p['total']),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
            ]));
        }),
      ],
      const SizedBox(height: 20),
    ]));
  }

  // ═══════════════ WIDGETS COMPARTIDOS ═══════════════

  Widget _accesosHetna() {
    Widget chip(IconData i, String t, VoidCallback onTap, {bool web = false}) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(
        width: 84, padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(children: [
          Icon(i, color: web ? AppColors.azul : AppColors.naranja, size: 22),
          const SizedBox(height: 4),
          Text(t, textAlign: TextAlign.center, maxLines: 2,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        ]))));
    void abrir(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    void abrirWeb(String u) => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    return SizedBox(height: 74, child: ListView(scrollDirection: Axis.horizontal, children: [
      chip(Icons.precision_manufacturing_outlined, 'Calculadora CNC', () => abrir(const CalculadoraCncScreen())),
      chip(Icons.local_shipping_outlined, 'Envíos HETNA', () => abrir(const EnviosScreen())),
      chip(Icons.storefront_outlined, 'Tienda', () => abrirWeb(HetnaApi.urlTienda), web: true),
      chip(Icons.forum_outlined, 'Foro CNC', () => abrirWeb(HetnaApi.urlForo), web: true),
      chip(Icons.science_outlined, 'Laboratorio CAM', () => abrirWeb(HetnaApi.urlLaboratorio), web: true),
      chip(Icons.gavel_outlined, 'Licitaciones', () => abrirWeb(HetnaApi.urlLicitaciones), web: true),
    ]));
  }

  Widget _heroStat(String label, String valor, Color color) => Expanded(
    child: Column(children: [
      Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center),
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.white60), textAlign: TextAlign.center),
    ]));

  Widget _heroDivider() => Container(width: 1, height: 36, color: Colors.white.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 4));

  Widget _finStat(String label, String valor, Color color) => Expanded(
    child: Container(padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(valor, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70), textAlign: TextAlign.center),
      ])));

  Widget _alertaCard(String texto, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Text(texto, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)));

  Widget _statCard(String label, String valor, Color color, IconData icon) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(children: [
      Container(width: 38, height: 38,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]));

  Widget _miniPedido(Pedido p) {
    final etapas = ['Pedido', 'Pago', 'Produccion', 'Pruebas', 'Entrega', 'Entregado'];
    final idx = etapas.indexOf(p.estado).clamp(0, etapas.length - 1);
    final nombre = p.cliente?.nombre ?? p.cliente?.empresa ?? 'Sin cliente';
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text(p.folio, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmt.format(p.total ?? 0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(20)),
              child: Text(p.estado == 'Produccion' ? 'Producción' : p.estado,
                style: const TextStyle(fontSize: 9, color: AppColors.azul))),
          ]),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
          value: (idx + 1) / etapas.length, backgroundColor: AppColors.gris, minHeight: 4,
          valueColor: const AlwaysStoppedAnimation(AppColors.azul))),
      ]));
  }

  Widget _itemCotizacion(Cotizacion c) {
    final color = _coloresEstado[c.estado] ?? Colors.grey;
    final nombre = c.cliente?.nombre ?? c.cliente?.empresa ?? 'Sin cliente';
    return Container(margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4),
          top: BorderSide(color: AppColors.grisBorde, width: 0.5),
          right: BorderSide(color: AppColors.grisBorde, width: 0.5),
          bottom: BorderSide(color: AppColors.grisBorde, width: 0.5))),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(c.folio ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          if (c.createdAt != null) Text(DateFormat('dd/MM/yyyy').format(c.createdAt!),
            style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(c.estado, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_fmt.format(c.total > 0 ? c.total : 0),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.azul)),
          if (c.items.isNotEmpty)
            Text('${c.items.length} item${c.items.length > 1 ? "s" : ""}',
              style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
        ]),
      ]));
  }

  Widget _miniStat(String label, String valor, Color color) => Expanded(
    child: Container(padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(valor, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70)),
      ])));

  Widget _kpiCard2(String label, String valor, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 8),
      Text(valor, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario),
        maxLines: 1, overflow: TextOverflow.ellipsis),
    ]));

  Widget _seccionInicio(String t) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(t, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario,
      letterSpacing: 1, fontWeight: FontWeight.w600)));

  Widget _seccion(String t) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(t, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario, letterSpacing: 1)));
}

// ── Extensión helper para mapIndexed ──
extension IndexedIterable<E> on Iterable<E> {
  Iterable<T> mapIndexed<T>(T Function(int index, E element) f) sync* {
    var index = 0;
    for (final element in this) {
      yield f(index++, element);
    }
  }
}
