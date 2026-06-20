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

  final _estadosCot = ['Todos', 'Borrador', 'Enviada', 'Aprobada', 'Pedido', 'Vencida'];
  final _coloresEstado = {
    'Borrador': Colors.grey, 'Enviada': Color(0xFF185fa5),
    'Aprobada': Color(0xFF1d9e75), 'Pedido': Color(0xFF7c3aed),
    'Vencida': Color(0xFFef9f27), 'Rechazada': Color(0xFFe24b4a),
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
          tabs: const [Tab(text: 'Resumen'), Tab(text: 'Reportes')],
        ),
      ),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            _tabResumen(),
            _tabReportes(),
          ]),
    );
  }

  // ══════════════════════════════════════
  // TAB RESUMEN
  // ══════════════════════════════════════
  Widget _tabResumen() {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final cotsFiltradas = _filtroCot == 'Todos'
      ? _cotizaciones
      : _cotizaciones.where((c) => c.estado == _filtroCot).toList();

    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [

      // ─── Stats del mes ───
      _label('Resumen del mes'),
      GridView.count(crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.6,
        children: [
          _statCard('Cotizaciones', '${_stats['solicitudes_elaboradas'] ?? 0}', AppColors.ambar, Icons.description_outlined),
          _statCard('Entregados', '${_stats['pedidos_entregados'] ?? 0}', AppColors.verde, Icons.check_circle_outline),
          _statCard('Alertas', '${_stats['alertas_pendientes'] ?? 0}', AppColors.rojo, Icons.notifications_outlined),
          _statCard('Ventas del mes', fmt.format((_stats['ventas_mes'] as num?)?.toDouble() ?? 0), AppColors.azul, Icons.trending_up),
        ]),

      const SizedBox(height: 16),

      // ─── Pedidos activos ───
      if (_pedidos.where((p) => p.estado != 'Entregado').isNotEmpty) ...[
        _label('Pedidos en proceso'),
        ..._pedidos.where((p) => p.estado != 'Entregado').take(3).map((p) => _miniPedido(p, fmt)),
        const SizedBox(height: 16),
      ],

      // ─── Cotizaciones con filtros ───
      _label('Cotizaciones'),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:
        _estadosCot.map((e) {
          final color = _coloresEstado[e] ?? AppColors.azul;
          final count = e == 'Todos' ? _cotizaciones.length
            : _cotizaciones.where((c) => c.estado == e).length;
          return GestureDetector(
            onTap: () => setState(() => _filtroCot = e),
            child: Container(margin: const EdgeInsets.only(right: 6, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _filtroCot == e ? (e == 'Todos' ? AppColors.azul : color) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _filtroCot == e ? (e == 'Todos' ? AppColors.azul : color) : AppColors.grisBorde)),
              child: Text('$e ($count)', style: TextStyle(fontSize: 10,
                color: _filtroCot == e ? Colors.white : AppColors.textoSecundario))));
        }).toList())),

      if (cotsFiltradas.isEmpty)
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Center(child: Text(
            _filtroCot == 'Todos' ? 'No hay cotizaciones aún' : 'No hay cotizaciones en "$_filtroCot"',
            style: const TextStyle(color: AppColors.textoSecundario))))
      else
        ...cotsFiltradas.take(10).map((c) => _itemCotizacion(c, fmt)),
    ]));
  }

  Widget _miniPedido(Pedido p, NumberFormat fmt) {
    final etapas = ['Pedido', 'Pago', 'Produccion', 'Pruebas', 'Entrega', 'Entregado'];
    final idx = etapas.indexOf(p.estado).clamp(0, etapas.length - 1);
    final pct = (idx + 1) / etapas.length;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.cliente?.nombre ?? 'Sin cliente', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(p.folio, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (p.total != null) Text(fmt.format(p.total!),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(20)),
              child: Text(p.estado == 'Produccion' ? 'Producción' : p.estado,
                style: const TextStyle(fontSize: 10, color: AppColors.azul))),
          ]),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
          value: pct, backgroundColor: AppColors.gris, minHeight: 4,
          valueColor: const AlwaysStoppedAnimation(AppColors.azul))),
      ]));
  }

  Widget _itemCotizacion(Cotizacion c, NumberFormat fmt) {
    final color = _coloresEstado[c.estado] ?? Colors.grey;
    // Obtener nombre del cliente
    final nombreCliente = c.cliente?.nombre ?? c.cliente?.empresa ?? 'Sin cliente';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3),
          right: BorderSide(color: AppColors.grisBorde, width: 0.5),
          top: BorderSide(color: AppColors.grisBorde, width: 0.5),
          bottom: BorderSide(color: AppColors.grisBorde, width: 0.5))),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombreCliente, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
          Text(fmt.format(c.total > 0 ? c.total : 0),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.azul)),
          if (c.items.isNotEmpty)
            Text('${c.items.length} producto${c.items.length > 1 ? "s" : ""}',
              style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
        ]),
      ]));
  }

  // ══════════════════════════════════════
  // TAB REPORTES
  // ══════════════════════════════════════
  Widget _tabReportes() {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final totalVentas = _cotizaciones
      .where((c) => c.estado == 'Aprobada' || c.estado == 'Pedido')
      .fold(0.0, (s, c) => s + c.total);
    final totalPedidos = _pedidos.length;
    final pedidosActivos = _pedidos.where((p) => p.estado != 'Entregado').length;
    final pedidosEntregados = _pedidos.where((p) => p.estado == 'Entregado').length;

    // Ventas por estado de cotización
    final ventasPorEstado = <String, double>{};
    for (final c in _cotizaciones) {
      ventasPorEstado[c.estado] = (ventasPorEstado[c.estado] ?? 0) + c.total;
    }

    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [

      // ─── Tarjeta principal ───
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.azul, AppColors.azul.withOpacity(0.8)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          const Text('VENTAS TOTALES', style: TextStyle(fontSize: 11, color: Colors.white70, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(fmt.format(totalVentas), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 12),
          Row(children: [
            _statBlanco('Cotizaciones', '${_cotizaciones.length}'),
            _statBlanco('Pedidos activos', '$pedidosActivos'),
            _statBlanco('Entregados', '$pedidosEntregados'),
          ]),
        ])),

      const SizedBox(height: 16),

      // ─── Pipeline de ventas ───
      _label('Pipeline de ventas'),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(children: _estadosCot.where((e) => e != 'Todos').map((e) {
          final monto = ventasPorEstado[e] ?? 0;
          final color = _coloresEstado[e] ?? Colors.grey;
          final count = _cotizaciones.where((c) => c.estado == e).length;
          final maxMonto = ventasPorEstado.values.fold(0.0, (a, b) => a > b ? a : b);
          final pct = maxMonto > 0 ? monto / maxMonto : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(e, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
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

      const SizedBox(height: 16),

      // ─── Pedidos por etapa ───
      _label('Estado de producción'),
      GridView.count(crossAxisCount: 3, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.4,
        children: ['Pedido', 'Pago', 'Produccion', 'Pruebas', 'Entrega', 'Entregado'].map((e) {
          final count = _pedidos.where((p) => p.estado == e).length;
          final colores = {'Pedido': AppColors.azul, 'Pago': AppColors.ambar,
            'Produccion': const Color(0xFF7c3aed), 'Pruebas': AppColors.rojo,
            'Entrega': AppColors.verde, 'Entregado': AppColors.verde};
          final color = colores[e] ?? AppColors.azul;
          return Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: count > 0 ? color.withOpacity(0.3) : AppColors.grisBorde, width: 0.5)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: count > 0 ? color : AppColors.textoSecundario)),
              Text(e == 'Produccion' ? 'Producción' : e,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, color: AppColors.textoSecundario)),
            ]));
        }).toList()),

      const SizedBox(height: 20),
    ]));
  }

  Widget _statCard(String label, String valor, Color color, IconData icon) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Icon(icon, color: color, size: 20),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
      ]),
    ]));

  Widget _statBlanco(String label, String valor) => Expanded(child: Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70), textAlign: TextAlign.center),
    ])));

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario, letterSpacing: 1)));
}
