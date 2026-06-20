import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
            Tab(text: '📋 Cotizaciones'),
            Tab(text: '🏭 Producción'),
            Tab(text: '📦 Inventario'),
          ],
        ),
      ),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            _tabGeneral(),
            _tabFinanzas(),
            _tabCotizaciones(),
            _tabProduccion(),
            _tabInventario(),
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
  // TAB 3 — COTIZACIONES
  // ══════════════════════════════════════
  Widget _tabCotizaciones() {
    final estados = ['Todos', 'Borrador', 'Enviada', 'Aprobada', 'Pedido', 'Vencida'];
    return StatefulBuilder(builder: (ctx, setS) {
      String filtro = 'Todos';
      return Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.all(10),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:
            estados.map((e) {
              final color = _coloresEstado[e] ?? AppColors.azul;
              final count = e == 'Todos' ? _cotizaciones.length : _cotizaciones.where((c) => c.estado == e).length;
              return GestureDetector(
                onTap: () => setS(() => filtro = e),
                child: Container(margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: filtro == e ? (e == 'Todos' ? AppColors.azul : color) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: filtro == e ? (e == 'Todos' ? AppColors.azul : color) : AppColors.grisBorde)),
                  child: Text('$e ($count)', style: TextStyle(fontSize: 10,
                    color: filtro == e ? Colors.white : AppColors.textoSecundario))));
            }).toList()))),
        Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
          // Resumen
          Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
            child: Row(children: estados.where((e) => e != 'Todos').map((e) {
              final color = _coloresEstado[e] ?? Colors.grey;
              final count = _cotizaciones.where((c) => c.estado == e).length;
              return Expanded(child: Column(children: [
                Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: count > 0 ? color : AppColors.textoSecundario)),
                Text(e, style: const TextStyle(fontSize: 8, color: AppColors.textoSecundario), textAlign: TextAlign.center),
              ]));
            }).toList()),
          ),
          // Lista
          ...(filtro == 'Todos' ? _cotizaciones : _cotizaciones.where((c) => c.estado == filtro).toList())
            .map((c) => _itemCotizacion(c)),
        ])),
      ]);
    });
  }

  // ══════════════════════════════════════
  // TAB 4 — PRODUCCIÓN
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
  // TAB 5 — INVENTARIO
  // ══════════════════════════════════════
  Widget _tabInventario() {
    final bajos = _materiales.where((m) => (m['stock_actual'] as int? ?? 0) <= (m['stock_minimo'] as int? ?? 1)).toList();
    final categorias = _materiales.map((m) => m['categoria'] as String? ?? '').toSet().toList()..sort();

    final valorTotal = _materiales.fold(0.0, (s, m) =>
      s + ((m['stock_actual'] as int? ?? 0) * ((m['costo_unitario'] as num?)?.toDouble() ?? 0)));

    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [

      // Resumen
      Row(children: [
        Expanded(child: _statCard('Total materiales', '${_materiales.length}', AppColors.azul, Icons.inventory_2_outlined)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('Stock bajo', '${bajos.length}', bajos.isEmpty ? AppColors.verde : AppColors.rojo, Icons.warning_amber_outlined)),
      ]),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Valor total en bodega:', style: TextStyle(fontSize: 13)),
          Text(_fmt.format(valorTotal), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.azul)),
        ])),

      if (bajos.isNotEmpty) ...[
        const SizedBox(height: 12),
        _seccion('⚠️ STOCK BAJO — REQUIEREN REABASTECIMIENTO'),
        ...bajos.map((m) => Container(
          margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.rojo.withOpacity(0.3))),
          child: Row(children: [
            const Icon(Icons.warning_amber, color: AppColors.rojo, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m['nombre'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text('Stock: ${m['stock_actual']} / Mínimo: ${m['stock_minimo']} ${m['unidad']}',
                style: const TextStyle(fontSize: 11, color: AppColors.rojo)),
            ])),
          ]))),
      ],

      const SizedBox(height: 12),
      _seccion('INVENTARIO POR CATEGORÍA'),
      ...categorias.map((cat) {
        final items = _materiales.where((m) => m['categoria'] == cat).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(cat.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.azul, letterSpacing: 1, fontWeight: FontWeight.w600))),
          ...items.map((m) {
            final stockBajo = (m['stock_actual'] as int? ?? 0) <= (m['stock_minimo'] as int? ?? 1);
            return Container(margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: stockBajo ? AppColors.rojo.withOpacity(0.3) : AppColors.grisBorde, width: 0.5)),
              child: Row(children: [
                Expanded(child: Text(m['nombre'] ?? '', style: const TextStyle(fontSize: 12))),
                Text('${m['stock_actual']} ${m['unidad']}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: stockBajo ? AppColors.rojo : AppColors.verde)),
              ]));
          }),
        ]);
      }),
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

  Widget _seccion(String t) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(t, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario, letterSpacing: 1)));
}
