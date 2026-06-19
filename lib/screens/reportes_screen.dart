import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});
  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _periodo = 'Este mes';
  final _periodos = ['Esta semana', 'Este mes', 'Mes anterior', '3 meses', 'Este año'];

  // Datos simulados del negocio
  final double _ingresos = 28500;
  final double _gastosDirect = 8200;
  final double _gastosIndir = 3100;
  final double _pedidosPendCobro = 12000;

  double get _totalGastos => _gastosDirect + _gastosIndir;
  double get _utilidadBruta => _ingresos - _gastosDirect;
  double get _utilidadNeta => _ingresos - _totalGastos;
  double get _margenUtilidad => _ingresos > 0 ? (_utilidadNeta / _ingresos) * 100 : 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: const Text('Reportes Financieros'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          tabs: const [Tab(text: 'General'), Tab(text: 'Ventas'), Tab(text: 'Productos')],
        ),
      ),
      body: Column(children: [
        // Selector periodo
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:
            _periodos.map((p) => GestureDetector(
              onTap: () => setState(() => _periodo = p),
              child: Container(margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _periodo == p ? AppColors.azul : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _periodo == p ? AppColors.azul : AppColors.grisBorde)),
                child: Text(p, style: TextStyle(fontSize: 11,
                  color: _periodo == p ? Colors.white : AppColors.textoSecundario))),
            )).toList()))),
        Expanded(child: TabBarView(controller: _tabs, children: [
          _tabGeneral(),
          _tabVentas(),
          _tabProductos(),
        ])),
      ]),
    );
  }

  Widget _tabGeneral() {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    return ListView(padding: const EdgeInsets.all(14), children: [
      // Tarjeta principal utilidad
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.azul, AppColors.azul.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(12)), child: Column(children: [
        Text(_periodo.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 1)),
        const SizedBox(height: 4),
        const Text('UTILIDAD NETA', style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 4),
        Text(fmt.format(_utilidadNeta), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
        Text('Margen: ${_margenUtilidad.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 16),
        Row(children: [
          _statBlanco('Ingresos', fmt.format(_ingresos), AppColors.verde),
          const SizedBox(width: 8),
          _statBlanco('Gastos', fmt.format(_totalGastos), AppColors.rojo),
          const SizedBox(width: 8),
          _statBlanco('Por cobrar', fmt.format(_pedidosPendCobro), AppColors.ambar),
        ]),
      ])),
      const SizedBox(height: 16),

      // Barras de resumen
      _seccion('Desglose de gastos'),
      _barraReporte('Gastos directos', _gastosDirect, _totalGastos, AppColors.rojo),
      _barraReporte('Gastos indirectos', _gastosIndir, _totalGastos, AppColors.ambar),
      const SizedBox(height: 16),

      // Indicadores clave
      _seccion('Indicadores clave'),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.5,
        children: [
          _kpiCard('Utilidad bruta', fmt.format(_utilidadBruta), AppColors.verde, Icons.trending_up),
          _kpiCard('Utilidad neta', fmt.format(_utilidadNeta), AppColors.azul, Icons.account_balance_outlined),
          _kpiCard('Gasto/Ingreso', '${(_totalGastos / _ingresos * 100).toStringAsFixed(1)}%', AppColors.ambar, Icons.pie_chart_outline),
          _kpiCard('Por cobrar', fmt.format(_pedidosPendCobro), AppColors.rojo, Icons.pending_actions),
        ]),
      const SizedBox(height: 16),

      // Ventas por semana
      _seccion('Ventas de la semana'),
      ...[
        {'dia': 'Lunes', 'monto': 3200.0},
        {'dia': 'Martes', 'monto': 4800.0},
        {'dia': 'Miércoles', 'monto': 2100.0},
        {'dia': 'Jueves', 'monto': 5600.0},
        {'dia': 'Viernes', 'monto': 7200.0},
        {'dia': 'Sábado', 'monto': 3900.0},
        {'dia': 'Domingo', 'monto': 1700.0},
      ].map((d) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
        SizedBox(width: 80, child: Text(d['dia'] as String, style: const TextStyle(fontSize: 12))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: (d['monto'] as double) / 7200,
          backgroundColor: AppColors.gris, minHeight: 8,
          valueColor: AlwaysStoppedAnimation((d['monto'] as double) >= 5000 ? AppColors.verde : AppColors.azul)))),
        const SizedBox(width: 8),
        SizedBox(width: 70, child: Text(fmt.format(d['monto']), textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.azul))),
      ]))),
    ]);
  }

  Widget _tabVentas() {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final ventas = [
      {'cliente': 'María García', 'producto': 'Tabla cocina pino 30x20', 'monto': 450.0, 'estado': 'Pagado', 'fecha': 'Hoy'},
      {'cliente': 'Juan López', 'producto': 'Llaveros MDF x10', 'monto': 350.0, 'estado': 'Pagado', 'fecha': 'Hoy'},
      {'cliente': 'Ana Martínez', 'producto': 'Servilletero personalizado', 'monto': 280.0, 'estado': 'Pendiente', 'fecha': 'Ayer'},
      {'cliente': 'Carlos Ruiz', 'producto': 'Router CNC 4x8', 'monto': 18500.0, 'estado': 'Anticipo', 'fecha': 'Ayer'},
      {'cliente': 'Laura Pérez', 'producto': 'Grabado metal placa', 'monto': 650.0, 'estado': 'Pagado', 'fecha': 'Lun'},
      {'cliente': 'Pedro Silva', 'producto': 'Tabla cocina cedro 25x25', 'monto': 680.0, 'estado': 'Pagado', 'fecha': 'Lun'},
    ];
    return ListView(padding: const EdgeInsets.all(14), children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.verdeClaro,
        borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.verde.withOpacity(0.3))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Total ventas del periodo', style: TextStyle(fontSize: 12, color: AppColors.verde)),
            Text(fmt.format(ventas.fold(0.0, (s, v) => s + (v['monto'] as double))),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.verde)),
          ]),
          Text('${ventas.length} ventas', style: const TextStyle(fontSize: 13, color: AppColors.verde, fontWeight: FontWeight.w500)),
        ])),
      const SizedBox(height: 12),
      ...ventas.map((v) {
        final colores = {'Pagado': AppColors.verde, 'Pendiente': AppColors.ambar, 'Anticipo': AppColors.azul};
        final color = colores[v['estado']] ?? Colors.grey;
        return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v['cliente'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(v['producto'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
              const SizedBox(height: 4),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(v['estado'] as String, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500))),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt.format(v['monto']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.azul)),
              Text(v['fecha'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            ]),
          ]));
      }),
    ]);
  }

  Widget _tabProductos() {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final productos = [
      {'nombre': 'Tablas para cocina', 'vendidos': 24, 'total': 9600.0, 'categoria': 'Madera'},
      {'nombre': 'Llaveros MDF', 'vendidos': 45, 'total': 3150.0, 'categoria': 'MDF'},
      {'nombre': 'Servilleteros', 'vendidos': 18, 'total': 3240.0, 'categoria': 'MDF'},
      {'nombre': 'Grabados metal', 'vendidos': 8, 'total': 4800.0, 'categoria': 'Fibra'},
      {'nombre': 'Corte acrílico', 'vendidos': 12, 'total': 2400.0, 'categoria': 'Láser'},
      {'nombre': 'Maquinaria CNC', 'vendidos': 2, 'total': 37000.0, 'categoria': 'Industrial'},
    ];
    return ListView(padding: const EdgeInsets.all(14), children: [
      _seccion('Productos más vendidos'),
      ...productos.asMap().entries.map((e) {
        final i = e.key;
        final p = e.value;
        return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Row(children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.azul, borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text('${i+1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['nombre'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text('${p['vendidos']} unidades · ${p['categoria']}', style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            ])),
            Text(fmt.format(p['total']), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
          ]));
      }),
    ]);
  }

  Widget _statBlanco(String label, String valor, Color color) => Expanded(
    child: Container(padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color == AppColors.verde ? Colors.greenAccent : Colors.white)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70)),
      ])));

  Widget _barraReporte(String label, double valor, double total, Color color) {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final pct = total > 0 ? valor / total : 0.0;
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Container(
      padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(fmt.format(valor), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: pct, backgroundColor: AppColors.gris, minHeight: 6,
          valueColor: AlwaysStoppedAnimation(color))),
        Text('${(pct * 100).toStringAsFixed(1)}% del total gastos',
          style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
      ])));
  }

  Widget _kpiCard(String label, String valor, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Icon(icon, color: color, size: 20),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(valor, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
      ]),
    ]));

  Widget _seccion(String t) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario, letterSpacing: 1)));
}
