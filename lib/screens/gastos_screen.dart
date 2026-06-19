import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class GastosScreen extends StatefulWidget {
  const GastosScreen({super.key});
  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _periodoFiltro = 'Esta semana';
  final List<Map<String, dynamic>> _gastos = [
    {'tipo': 'directo', 'concepto': 'MDF 3mm x5 láminas', 'monto': 900.0, 'categoria': 'Materiales', 'fecha': DateTime.now().subtract(const Duration(days: 1)), 'proveedor': 'Maderera López'},
    {'tipo': 'directo', 'concepto': 'Brocas CNC x10', 'monto': 450.0, 'categoria': 'Consumibles', 'fecha': DateTime.now().subtract(const Duration(days: 2)), 'proveedor': 'HETNA CNC'},
    {'tipo': 'indirecto', 'concepto': 'Luz eléctrica', 'monto': 1200.0, 'categoria': 'Servicios', 'fecha': DateTime.now().subtract(const Duration(days: 3)), 'proveedor': 'CFE'},
    {'tipo': 'directo', 'concepto': 'Madera Pino 15cm x3m', 'monto': 195.0, 'categoria': 'Materiales', 'fecha': DateTime.now().subtract(const Duration(days: 4)), 'proveedor': 'Maderera López'},
    {'tipo': 'indirecto', 'concepto': 'Internet', 'monto': 550.0, 'categoria': 'Servicios', 'fecha': DateTime.now().subtract(const Duration(days: 5)), 'proveedor': 'Telmex'},
    {'tipo': 'indirecto', 'concepto': 'Gasolina reparto', 'monto': 400.0, 'categoria': 'Transporte', 'fecha': DateTime.now().subtract(const Duration(days: 6)), 'proveedor': 'Pemex'},
  ];

  final _periodos = ['Hoy', 'Esta semana', 'Este mes', 'Mes anterior'];
  final _categorias = ['Materiales', 'Consumibles', 'Servicios', 'Transporte', 'Herramientas', 'Publicidad', 'Otro'];

  double get _totalDirectos => _gastos.where((g) => g['tipo'] == 'directo').fold(0, (s, g) => s + (g['monto'] as double));
  double get _totalIndirectos => _gastos.where((g) => g['tipo'] == 'indirecto').fold(0, (s, g) => s + (g['monto'] as double));
  double get _totalGeneral => _totalDirectos + _totalIndirectos;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: const Text('Gastos y Compras'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          tabs: const [Tab(text: 'Gastos'), Tab(text: 'Nuevo gasto'), Tab(text: 'Resumen')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _tabGastos(),
        _tabNuevoGasto(),
        _tabResumen(),
      ]),
    );
  }

  Widget _tabGastos() {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    return Column(children: [
      // Resumen rápido
      Container(color: Colors.white, padding: const EdgeInsets.all(12), child: Column(children: [
        Row(children: [
          Expanded(child: _miniStat('Directos', fmt.format(_totalDirectos), AppColors.rojo)),
          const SizedBox(width: 8),
          Expanded(child: _miniStat('Indirectos', fmt.format(_totalIndirectos), AppColors.ambar)),
          const SizedBox(width: 8),
          Expanded(child: _miniStat('Total', fmt.format(_totalGeneral), AppColors.azul)),
        ]),
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:
          _periodos.map((p) => GestureDetector(
            onTap: () => setState(() => _periodoFiltro = p),
            child: Container(margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _periodoFiltro == p ? AppColors.azul : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _periodoFiltro == p ? AppColors.azul : AppColors.grisBorde)),
              child: Text(p, style: TextStyle(fontSize: 11,
                color: _periodoFiltro == p ? Colors.white : AppColors.textoSecundario))),
          )).toList())),
      ])),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _gastos.length,
        itemBuilder: (_, i) => _TarjetaGasto(gasto: _gastos[i], onEliminar: () => setState(() => _gastos.removeAt(i))),
      )),
    ]);
  }

  Widget _miniStat(String label, String valor, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(valor, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
    ]));

  Widget _tabNuevoGasto() {
    final concepto = TextEditingController();
    final monto = TextEditingController();
    final proveedor = TextEditingController();
    String tipo = 'directo';
    String categoria = 'Materiales';

    return StatefulBuilder(builder: (context, setS) => ListView(padding: const EdgeInsets.all(14), children: [
      // Tipo
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('TIPO DE GASTO', style: TextStyle(fontSize: 10, color: AppColors.azul, letterSpacing: 1, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => setS(() => tipo = 'directo'),
              child: Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tipo == 'directo' ? AppColors.rojo : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tipo == 'directo' ? AppColors.rojo : AppColors.grisBorde)),
                child: Column(children: [
                  Icon(Icons.build_outlined, color: tipo == 'directo' ? Colors.white : AppColors.textoSecundario),
                  const SizedBox(height: 4),
                  Text('Gasto directo', style: TextStyle(fontSize: 12, color: tipo == 'directo' ? Colors.white : Colors.black, fontWeight: FontWeight.w500)),
                  Text('Materiales, consumibles', style: TextStyle(fontSize: 10, color: tipo == 'directo' ? Colors.white70 : AppColors.textoSecundario)),
                ])))),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () => setS(() => tipo = 'indirecto'),
              child: Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tipo == 'indirecto' ? AppColors.ambar : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tipo == 'indirecto' ? AppColors.ambar : AppColors.grisBorde)),
                child: Column(children: [
                  Icon(Icons.receipt_outlined, color: tipo == 'indirecto' ? Colors.white : AppColors.textoSecundario),
                  const SizedBox(height: 4),
                  Text('Gasto indirecto', style: TextStyle(fontSize: 12, color: tipo == 'indirecto' ? Colors.white : Colors.black, fontWeight: FontWeight.w500)),
                  Text('Luz, internet, gasolina', style: TextStyle(fontSize: 10, color: tipo == 'indirecto' ? Colors.white70 : AppColors.textoSecundario)),
                ])))),
          ]),
        ])),
      const SizedBox(height: 10),
      _campoForm('Concepto / Descripción *', concepto),
      Row(children: [
        Expanded(child: _campoForm('Monto \$', monto, tipo: TextInputType.number)),
        const SizedBox(width: 8),
        Expanded(child: _campoForm('Proveedor', proveedor)),
      ]),
      const SizedBox(height: 4),
      const Text('Categoría', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      const SizedBox(height: 4),
      DropdownButtonFormField<String>(
        value: categoria,
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: (v) => setS(() => categoria = v!)),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        onPressed: () {
          if (concepto.text.isNotEmpty && monto.text.isNotEmpty) {
            setState(() => _gastos.insert(0, {
              'tipo': tipo, 'concepto': concepto.text.trim(),
              'monto': double.tryParse(monto.text) ?? 0,
              'categoria': categoria, 'fecha': DateTime.now(),
              'proveedor': proveedor.text.trim(),
            }));
            concepto.clear(); monto.clear(); proveedor.clear();
            _tabs.animateTo(0);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Gasto registrado'), backgroundColor: AppColors.verde));
          }
        },
        icon: const Icon(Icons.save_outlined),
        label: const Text('Registrar gasto'),
      ),
    ]));
  }

  Widget _campoForm(String label, TextEditingController ctrl, {TextInputType tipo = TextInputType.text}) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      const SizedBox(height: 4),
      TextField(controller: ctrl, keyboardType: tipo, style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
    ]));

  Widget _tabResumen() {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final porCategoria = <String, double>{};
    for (final g in _gastos) {
      final cat = g['categoria'] as String;
      porCategoria[cat] = (porCategoria[cat] ?? 0) + (g['monto'] as double);
    }
    final sorted = porCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView(padding: const EdgeInsets.all(14), children: [
      // Resumen general
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.azul,
        borderRadius: BorderRadius.circular(12)), child: Column(children: [
        const Text('TOTAL GASTOS', style: TextStyle(fontSize: 11, color: Colors.white70, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(fmt.format(_totalGeneral), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              Text(fmt.format(_totalDirectos), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              const Text('Directos', style: TextStyle(fontSize: 10, color: Colors.white70)),
            ]))),
          const SizedBox(width: 8),
          Expanded(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              Text(fmt.format(_totalIndirectos), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              const Text('Indirectos', style: TextStyle(fontSize: 10, color: Colors.white70)),
            ]))),
        ]),
      ])),
      const SizedBox(height: 16),
      const Text('POR CATEGORÍA', style: TextStyle(fontSize: 10, color: AppColors.textoSecundario, letterSpacing: 1)),
      const SizedBox(height: 8),
      ...sorted.map((e) {
        final pct = e.value / _totalGeneral;
        return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(fmt.format(e.value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.azul)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
              value: pct, backgroundColor: AppColors.gris, minHeight: 5,
              valueColor: const AlwaysStoppedAnimation(AppColors.azul))),
            const SizedBox(height: 2),
            Text('${(pct * 100).toStringAsFixed(1)}% del total',
              style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          ]));
      }),
    ]);
  }
}

class _TarjetaGasto extends StatelessWidget {
  final Map<String, dynamic> gasto;
  final VoidCallback onEliminar;
  const _TarjetaGasto({required this.gasto, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final fmtFecha = DateFormat('dd/MM', 'es_MX');
    final esDirecto = gasto['tipo'] == 'directo';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: esDirecto ? AppColors.rojoClaro : AppColors.ambarClaro,
          child: Icon(esDirecto ? Icons.build_outlined : Icons.receipt_outlined,
            color: esDirecto ? AppColors.rojo : AppColors.ambar, size: 18)),
        title: Text(gasto['concepto'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${gasto['categoria']} · ${gasto['proveedor'] ?? ''}', style: const TextStyle(fontSize: 11)),
          Container(margin: const EdgeInsets.only(top: 3), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: esDirecto ? AppColors.rojoClaro : AppColors.ambarClaro,
              borderRadius: BorderRadius.circular(4)),
            child: Text(esDirecto ? 'Directo' : 'Indirecto',
              style: TextStyle(fontSize: 9, color: esDirecto ? AppColors.rojo : AppColors.ambar))),
        ]),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmt.format(gasto['monto']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.azul)),
          Text(fmtFecha.format(gasto['fecha'] as DateTime), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          GestureDetector(onTap: onEliminar, child: const Icon(Icons.delete_outline, size: 16, color: AppColors.rojo)),
        ]),
      ),
    );
  }
}
