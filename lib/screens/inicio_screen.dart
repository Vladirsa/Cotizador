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
  bool _cargando = true;
  String _filtroCot = 'Todos';

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
    _tabs = TabController(length: 2, vsync: this);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final stats = await SupabaseService.getEstadisticasMes();
      final cots = await SupabaseService.getCotizaciones();
      final peds = await SupabaseService.getPedidos();
      if (mounted) setState(() {
        _stats = stats;
        _cotizaciones = cots;
        _pedidos = peds;
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
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Reportes'),
            Tab(icon: Icon(Icons.description_outlined, size: 18), text: 'Cotizaciones'),
          ],
        ),
      ),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            _tabReportes(),
            _tabCotizaciones(),
          ]),
    );
  }

  // ══════════════════════════════════════
  // TAB REPORTES — PORTADA PRINCIPAL
  // ══════════════════════════════════════
  Widget _tabReportes() {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final totalVentas = (_stats['ventas_mes'] as num?)?.toDouble() ?? 0;
    final solicitudes = _stats['solicitudes_elaboradas'] ?? 0;
    final entregados = _stats['pedidos_entregados'] ?? 0;
    final alertas = _stats['alertas_pendientes'] ?? 0;

    final pedidosActivos = _pedidos.where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado').length;
    final pedidosEntregados = _pedidos.where((p) => p.estado == 'Entregado').length;

    final ventasPorEstado = <String, double>{};
    for (final c in _cotizaciones) {
      ventasPorEstado[c.estado] = (ventasPorEstado[c.estado] ?? 0) + c.total;
    }

    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [

      // ─── Hero financiero ───
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.azul, Color(0xFF2d5a8e)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('VENTAS DEL MES', style: TextStyle(fontSize: 11, color: Colors.white60, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(fmt.format(totalVentas), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 14),
          Row(children: [
            _heroStat('Cotizaciones', '$solicitudes', Icons.description_outlined),
            _heroDivider(),
            _heroStat('En proceso', '$pedidosActivos', Icons.local_shipping_outlined),
            _heroDivider(),
            _heroStat('Entregados', '$pedidosEntregados', Icons.check_circle_outline),
            _heroDivider(),
            _heroStat('Alertas', '$alertas', Icons.notifications_outlined, color: alertas > 0 ? Colors.orangeAccent : Colors.white70),
          ]),
        ])),

      const SizedBox(height: 16),

      // ─── Pedidos activos ───
      if (_pedidos.where((p) => p.estado != 'Entregado').isNotEmpty) ...[
        _seccion('PRODUCCIÓN ACTIVA'),
        ..._pedidos.where((p) => p.estado != 'Entregado').take(4).map((p) => _miniPedido(p, fmt)),
        const SizedBox(height: 12),
      ],

      // ─── Pipeline por estado ───
      _seccion('PIPELINE DE VENTAS'),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(children: ['Borrador', 'Enviada', 'Aprobada', 'Pedido', 'Vencida'].map((e) {
          final monto = ventasPorEstado[e] ?? 0;
          final count = _cotizaciones.where((c) => c.estado == e).length;
          final color = _coloresEstado[e] ?? Colors.grey;
          final maxMonto = ventasPorEstado.values.fold(0.0, (a, b) => a > b ? a : b);
          final pct = maxMonto > 0 ? monto / maxMonto : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(e, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text('($count)', style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
              ]),
              Text(fmt.format(monto), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
              value: pct, backgroundColor: AppColors.gris, minHeight: 5,
              valueColor: AlwaysStoppedAnimation(color))),
          ]));
        }).toList())),

      const SizedBox(height: 12),

      // ─── Estado de producción ───
      _seccion('ETAPAS DE PRODUCCIÓN'),
      GridView.count(
        crossAxisCount: 3, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.5,
        children: [
          _etapaCard('Pedido', AppColors.azul),
          _etapaCard('Pago', AppColors.ambar),
          _etapaCard('Producción', Color(0xFF7c3aed)),
          _etapaCard('Pruebas', AppColors.rojo),
          _etapaCard('Entrega', AppColors.verde),
          _etapaCard('Entregado', AppColors.verde),
        ]),

      const SizedBox(height: 20),
    ]));
  }

  Widget _heroStat(String label, String valor, IconData icon, {Color? color}) => Expanded(
    child: Column(children: [
      Icon(icon, color: color ?? Colors.white70, size: 16),
      const SizedBox(height: 2),
      Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color ?? Colors.white)),
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.white60), textAlign: TextAlign.center),
    ]));

  Widget _heroDivider() => Container(width: 1, height: 40, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 4));

  Widget _etapaCard(String etapa, Color color) {
    final key = etapa == 'Producción' ? 'Produccion' : etapa;
    final count = _pedidos.where((p) => p.estado == key).length;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: count > 0 ? color.withOpacity(0.4) : AppColors.grisBorde, width: 0.5)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
          color: count > 0 ? color : AppColors.textoSecundario)),
        Text(etapa, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9, color: AppColors.textoSecundario)),
      ]));
  }

  Widget _miniPedido(Pedido p, NumberFormat fmt) {
    final etapas = ['Pedido', 'Pago', 'Produccion', 'Pruebas', 'Entrega', 'Entregado'];
    final idx = etapas.indexOf(p.estado).clamp(0, etapas.length - 1);
    final pct = (idx + 1) / etapas.length;
    final nombre = p.cliente?.nombre ?? p.cliente?.empresa ?? 'Sin cliente';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text(p.folio, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmt.format(p.total ?? 0),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(20)),
              child: Text(p.estado == 'Produccion' ? 'En producción' : p.estado,
                style: const TextStyle(fontSize: 9, color: AppColors.azul))),
          ]),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
          value: pct, backgroundColor: AppColors.gris, minHeight: 4,
          valueColor: const AlwaysStoppedAnimation(AppColors.azul))),
      ]));
  }

  // ══════════════════════════════════════
  // TAB COTIZACIONES
  // ══════════════════════════════════════
  Widget _tabCotizaciones() {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final estados = ['Todos', 'Borrador', 'Enviada', 'Aprobada', 'Pedido', 'Vencida'];
    final filtradas = _filtroCot == 'Todos'
      ? _cotizaciones
      : _cotizaciones.where((c) => c.estado == _filtroCot).toList();

    return RefreshIndicator(onRefresh: _cargar, child: Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:
          estados.map((e) {
            final color = _coloresEstado[e] ?? AppColors.azul;
            final count = e == 'Todos' ? _cotizaciones.length
              : _cotizaciones.where((c) => c.estado == e).length;
            return GestureDetector(
              onTap: () => setState(() => _filtroCot = e),
              child: Container(margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _filtroCot == e ? (e == 'Todos' ? AppColors.azul : color) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _filtroCot == e ? (e == 'Todos' ? AppColors.azul : color) : AppColors.grisBorde)),
                child: Text('$e ($count)', style: TextStyle(fontSize: 10,
                  color: _filtroCot == e ? Colors.white : AppColors.textoSecundario))));
          }).toList()))),
      Expanded(child: filtradas.isEmpty
        ? Center(child: Text('No hay cotizaciones en "$_filtroCot"',
            style: const TextStyle(color: AppColors.textoSecundario)))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtradas.length,
            itemBuilder: (_, i) => _itemCotizacion(filtradas[i], fmt))),
    ]));
  }

  Widget _itemCotizacion(Cotizacion c, NumberFormat fmt) {
    final color = _coloresEstado[c.estado] ?? Colors.grey;
    final nombre = c.cliente?.nombre ?? c.cliente?.empresa ?? 'Sin cliente';
    final monto = c.total > 0 ? c.total : (c.subtotal > 0 ? c.subtotal * 1.16 : 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: color, width: 4),
          top: BorderSide(color: AppColors.grisBorde, width: 0.5),
          right: BorderSide(color: AppColors.grisBorde, width: 0.5),
          bottom: BorderSide(color: AppColors.grisBorde, width: 0.5))),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text(c.folio ?? 'Sin folio', style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          if (c.createdAt != null)
            Text(DateFormat('dd/MM/yyyy').format(c.createdAt!),
              style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(c.estado, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmt.format(monto),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.azul)),
          if (c.items.isNotEmpty)
            Text('${c.items.length} producto${c.items.length > 1 ? "s" : ""}',
              style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
        ]),
      ]));
  }

  Widget _seccion(String t) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(t, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario, letterSpacing: 1, fontWeight: FontWeight.w600)));
}
