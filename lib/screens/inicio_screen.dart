import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

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
    _tabs = TabController(length: 7, vsync: this);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final results = await Future.wait([
        SupabaseService.getEstadisticasMes(),
        SupabaseService.getCotizaciones(),
        SupabaseService.getPedidos(),
        SupabaseService.getGastos(periodo: 'Este mes'),
        SupabaseService.getMateriales(),
      ]);
      if (mounted) setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _cotizaciones = results[1] as List<Cotizacion>;
        _pedidos = results[2] as List<Pedido>;
        _gastos = results[3] as List<Map<String, dynamic>>;
        _materiales = results[4] as List<Map<String, dynamic>>;
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
            Tab(text: '📊 General'),
            Tab(text: '💰 Finanzas'),
            Tab(text: '📈 Ventas'),
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
            _tabGeneral(),
            _tabFinanzas(),
            _tabVentas(),
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
  Widget _tabGeneral() {
    final totalVentas = (_stats['ventas_mes'] as num?)?.toDouble() ?? 0;
    final totalGastos = _gastos.fold(0.0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0));
    final utilidad = totalVentas - totalGastos;
    final pedidosActivos = _pedidos.where((p) => p.estado != 'Entregado').length;
    final alertas = _stats['alertas_pendientes'] ?? 0;
    final materialesBajos = _materiales.where((m) => (m['stock_actual'] as int? ?? 0) <= (m['stock_minimo'] as int? ?? 1)).length;

    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [

      // ─── Hero financiero ───
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.azul, Color(0xFF2d5a8e)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('RESUMEN DEL MES', style: TextStyle(fontSize: 10, color: Colors.white60, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(_fmt.format(totalVentas), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
          const Text('en ventas', style: TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 14),
          Row(children: [
            _heroStat('Gastos', _fmt.format(totalGastos), AppColors.rojo.withOpacity(0.8)),
            _heroDivider(),
            _heroStat('Utilidad', _fmt.format(utilidad), utilidad >= 0 ? Colors.greenAccent : Colors.redAccent),
            _heroDivider(),
            _heroStat('En proceso', '$pedidosActivos pedidos', Colors.white70),
          ]),
        ])),

      const SizedBox(height: 14),

      // ─── Alertas rápidas ───
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

      // ─── Stats rápidos ───
      _seccion('RESUMEN OPERATIVO'),
      GridView.count(crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.6,
        children: [
          _statCard('Cotizaciones', '${_cotizaciones.length}', AppColors.azul, Icons.description_outlined),
          _statCard('Pedidos activos', '$pedidosActivos', const Color(0xFF7c3aed), Icons.local_shipping_outlined),
          _statCard('Entregados', '${_pedidos.where((p) => p.estado == "Entregado").length}', AppColors.verde, Icons.check_circle_outline),
          _statCard('Alertas', '$alertas', alertas > 0 ? AppColors.rojo : AppColors.verde, Icons.notifications_outlined),
        ]),

      const SizedBox(height: 14),

      // ─── Pedidos activos ───
      if (_pedidos.where((p) => p.estado != 'Entregado').isNotEmpty) ...[
        _seccion('PEDIDOS EN PROCESO'),
        ..._pedidos.where((p) => p.estado != 'Entregado').take(3).map((p) => _miniPedido(p)),
      ],
    ]));
  }

  // ══════════════════════════════════════
  // TAB 2 — FINANZAS
  // ══════════════════════════════════════
  Widget _tabFinanzas() {
    final totalVentas = (_stats['ventas_mes'] as num?)?.toDouble() ?? 0;
    final totalGastosDirect = _gastos.where((g) => g['tipo'] == 'directo').fold(0.0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0));
    final totalGastosIndir = _gastos.where((g) => g['tipo'] == 'indirecto').fold(0.0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0));
    final totalGastos = totalGastosDirect + totalGastosIndir;
    final utilidadBruta = totalVentas - totalGastosDirect;
    final utilidadNeta = totalVentas - totalGastos;
    final margen = totalVentas > 0 ? (utilidadNeta / totalVentas * 100) : 0.0;

    final porCategoria = <String, double>{};
    for (final g in _gastos) {
      final cat = g['categoria'] as String? ?? 'Otro';
      porCategoria[cat] = (porCategoria[cat] ?? 0) + ((g['monto'] as num?)?.toDouble() ?? 0);
    }
    final sorted = porCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [

      // Tarjeta principal
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.azul, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          const Text('UTILIDAD NETA DEL MES', style: TextStyle(fontSize: 10, color: Colors.white60, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(_fmt.format(utilidadNeta),
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
              color: utilidadNeta >= 0 ? Colors.greenAccent : Colors.redAccent)),
          Text('Margen: ${margen.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 12),
          Row(children: [
            _finStat('Ventas', _fmt.format(totalVentas), Colors.greenAccent),
            _finStat('G. Directos', _fmt.format(totalGastosDirect), Colors.orangeAccent),
            _finStat('G. Indirectos', _fmt.format(totalGastosIndir), Colors.redAccent),
          ]),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Utilidad bruta:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(_fmt.format(utilidadBruta), style: TextStyle(color: utilidadBruta >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w700)),
            ])),
        ])),

      const SizedBox(height: 14),
      _seccion('GASTOS POR CATEGORÍA'),

      if (sorted.isEmpty)
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: const Center(child: Text('No hay gastos registrados este mes', style: TextStyle(color: AppColors.textoSecundario))))
      else Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(children: sorted.map((e) {
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

      const SizedBox(height: 14),
      _seccion('ÚLTIMOS GASTOS'),
      ..._gastos.take(5).map((g) {
        final esDir = g['tipo'] == 'directo';
        return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Row(children: [
            CircleAvatar(radius: 16, backgroundColor: esDir ? AppColors.rojoClaro : AppColors.ambarClaro,
              child: Icon(esDir ? Icons.build_outlined : Icons.receipt_outlined, size: 14,
                color: esDir ? AppColors.rojo : AppColors.ambar)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g['concepto'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text(g['categoria'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
            ])),
            Text(_fmt.format((g['monto'] as num?)?.toDouble() ?? 0),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
          ]));
      }),
    ]));
  }

  // ══════════════════════════════════════
  // TAB 3 — VENTAS con GRÁFICAS fl_chart
  // ══════════════════════════════════════
  Widget _tabVentas() {
    final ventas = _pedidos.where((p) =>
      p.estado == 'Entregado' || p.estado == 'PagoCompleto' || p.estado == 'Entrega').toList();
    final totalVentas = ventas.fold(0.0, (s, p) => s + (p.total ?? 0));
    final totalGastos = _gastos.fold(0.0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0));
    final utilidad = totalVentas - totalGastos;
    final margen = totalVentas > 0 ? (utilidad / totalVentas * 100) : 0.0;

    final enProceso = _pedidos.where((p) =>
      p.estado == 'Pago50' || p.estado == 'Produccion' || p.estado == 'Pruebas').toList();
    final porCobrar = enProceso.fold(0.0, (s, p) => s + ((p.total ?? 0) / 2));

    // ── Datos para gráfica de barras: ventas por día de la semana ──
    final Map<int, double> ventasPorDia = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    for (final p in ventas) {
      if (p.createdAt != null) {
        final dia = p.createdAt!.weekday % 7; // 0=Dom ... 6=Sab
        ventasPorDia[dia] = (ventasPorDia[dia] ?? 0) + (p.total ?? 0);
      }
    }
    final maxDia = ventasPorDia.values.fold(0.0, (a, b) => a > b ? a : b);

    // ── Datos para gráfica de dona: estados de cotizaciones ──
    final estadosCot = <String, int>{};
    for (final c in _cotizaciones) {
      final e = c.estado;
      estadosCot[e] = (estadosCot[e] ?? 0) + 1;
    }
    final coloresCot = [
      const Color(0xFF185fa5), // Enviada
      const Color(0xFF1d9e75), // Aprobada
      const Color(0xFF7c3aed), // Pedido
      const Color(0xFFef9f27), // Vencida
      const Color(0xFFe24b4a), // Rechazada
      Colors.grey,             // Borrador
    ];

    // ── Tasa de conversión ──
    final totalCots = _cotizaciones.length;
    final aprobadas = _cotizaciones.where((c) => c.estado == 'Aprobada' || c.estado == 'Pedido').length;
    final tasaConversion = totalCots > 0 ? (aprobadas / totalCots * 100) : 0.0;

    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [

      // ── Tarjeta resumen ──
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.azul, Color(0xFF2a5298)]),
          borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          const Text('VENTAS DEL PERIODO', style: TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(_fmt.format(totalVentas), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('Margen: ${margen.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 12),
          Row(children: [
            _miniStat('Utilidad', _fmt.format(utilidad), utilidad >= 0 ? Colors.greenAccent : Colors.redAccent),
            const SizedBox(width: 8),
            _miniStat('Gastos', _fmt.format(totalGastos), Colors.orange.shade200),
            const SizedBox(width: 8),
            _miniStat('Por cobrar', _fmt.format(porCobrar), Colors.yellow.shade200),
          ]),
        ])),

      const SizedBox(height: 12),

      // ── KPIs ──
      Row(children: [
        Expanded(child: _kpiCard2('Ventas cerradas', '${ventas.length}', AppColors.verde, Icons.check_circle_outline)),
        const SizedBox(width: 8),
        Expanded(child: _kpiCard2('En proceso', '${enProceso.length}', AppColors.ambar, Icons.pending_outlined)),
        const SizedBox(width: 8),
        Expanded(child: _kpiCard2('Ticket promedio', ventas.isEmpty ? '\$0' : _fmt.format(totalVentas / ventas.length), AppColors.azul, Icons.receipt_outlined)),
      ]),

      const SizedBox(height: 16),

      // ════════════════════════════════════
      // GRÁFICA 1 — Barras: ventas por día
      // ════════════════════════════════════
      _seccionInicio('VENTAS POR DÍA DE LA SEMANA'),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: ventas.isEmpty
          ? const SizedBox(height: 120, child: Center(
              child: Text('Sin datos de ventas', style: TextStyle(color: AppColors.textoSecundario, fontSize: 13))))
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

      // ════════════════════════════════════
      // GRÁFICA 2 — Dona: estados cotizaciones
      // ════════════════════════════════════
      _seccionInicio('DISTRIBUCIÓN DE COTIZACIONES'),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: _cotizaciones.isEmpty
          ? const SizedBox(height: 120, child: Center(
              child: Text('Sin cotizaciones', style: TextStyle(color: AppColors.textoSecundario, fontSize: 13))))
          : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Dona
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
              // Leyenda
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

      // ════════════════════════════════════
      // GRÁFICA 3 — Línea: tasa de conversión
      // ════════════════════════════════════
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
          // Barra de progreso visual
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
            Text('Meta: 70%', style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
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

      // ── Ventas recientes ──
      _seccionInicio('VENTAS RECIENTES'),
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
      _seccionInicio('GASTOS DEL PERIODO'),
      if (_gastos.isEmpty)
        Container(padding: const EdgeInsets.all(16), alignment: Alignment.center,
          child: const Text('Sin gastos registrados', style: TextStyle(color: AppColors.textoSecundario)))
      else
        ..._gastos.take(8).map((g) => Container(
          margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g['concepto'] ?? g['descripcion'] ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text(g['tipo'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
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
    final etapas = ['Pedido', 'Pago', 'Produccion', 'Pruebas', 'Entrega', 'Entregado'];
    final coloresEtapa = {
      'Pedido': AppColors.azul, 'Pago': AppColors.ambar,
      'Produccion': const Color(0xFF7c3aed), 'Pruebas': AppColors.rojo,
      'Entrega': AppColors.verde, 'Entregado': AppColors.verde,
    };

    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [
      _seccion('ESTADO DE PRODUCCIÓN'),
      GridView.count(crossAxisCount: 3, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.4,
        children: etapas.map((e) {
          final count = _pedidos.where((p) => p.estado == e).length;
          final color = coloresEtapa[e] ?? AppColors.azul;
          final monto = _pedidos.where((p) => p.estado == e).fold(0.0, (s, p) => s + (p.total ?? 0));
          return Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: count > 0 ? color.withOpacity(0.4) : AppColors.grisBorde, width: 0.5)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: count > 0 ? color : AppColors.textoSecundario)),
              Text(e == 'Produccion' ? 'Producción' : e, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: AppColors.textoSecundario)),
              if (monto > 0) Text(_fmt.format(monto), style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600)),
            ]));
        }).toList()),

      const SizedBox(height: 14),
      _seccion('PEDIDOS ACTIVOS'),
      ..._pedidos.where((p) => p.estado != 'Entregado').map((p) => _miniPedido(p)),
      if (_pedidos.where((p) => p.estado != 'Entregado').isEmpty)
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: const Center(child: Text('No hay pedidos activos', style: TextStyle(color: AppColors.textoSecundario)))),
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
    final lista = conteo.values.toList()
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [
      if (lista.isEmpty)
        Container(padding: const EdgeInsets.all(32), alignment: Alignment.center,
          child: const Column(children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.grisBorde),
            SizedBox(height: 8),
            Text('Sin datos de productos vendidos', style: TextStyle(color: AppColors.textoSecundario)),
          ]))
      else ...[
        _seccionInicio('TOP PRODUCTOS POR VENTAS'),
        ...lista.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          final maxTotal = (lista.first['total'] as double);
          final pct = maxTotal > 0 ? (p['total'] as double) / maxTotal : 0.0;
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
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 8),
      Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
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
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 6),
      Text(valor, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
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
