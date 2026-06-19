import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});
  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _categoriaFiltro = 'Todos';

  // Materiales predefinidos para el negocio
  final List<Map<String, dynamic>> _materiales = [
    // Maderas
    {'id': '1', 'categoria': 'Madera', 'nombre': 'Tablón Pino', 'unidad': 'pieza', 'stock': 8, 'minimo': 5, 'costo': 180.0},
    {'id': '2', 'categoria': 'Madera', 'nombre': 'Tablón Cedro', 'unidad': 'pieza', 'stock': 3, 'minimo': 3, 'costo': 250.0},
    {'id': '3', 'categoria': 'Madera', 'nombre': 'Tablón Parota', 'unidad': 'pieza', 'stock': 2, 'minimo': 3, 'costo': 320.0},
    {'id': '4', 'categoria': 'Madera', 'nombre': 'Madera Pino 10cm', 'unidad': 'metro', 'stock': 12, 'minimo': 5, 'costo': 45.0},
    {'id': '5', 'categoria': 'Madera', 'nombre': 'Madera Pino 15cm', 'unidad': 'metro', 'stock': 8, 'minimo': 5, 'costo': 65.0},
    {'id': '6', 'categoria': 'Madera', 'nombre': 'Madera Pino 20cm', 'unidad': 'metro', 'stock': 6, 'minimo': 5, 'costo': 85.0},
    {'id': '7', 'categoria': 'Madera', 'nombre': 'Madera Pino 30cm', 'unidad': 'metro', 'stock': 4, 'minimo': 3, 'costo': 120.0},
    // MDF
    {'id': '8', 'categoria': 'MDF', 'nombre': 'MDF 3mm 1.22x2.44m', 'unidad': 'lámina', 'stock': 10, 'minimo': 5, 'costo': 180.0},
    {'id': '9', 'categoria': 'MDF', 'nombre': 'MDF 6mm 1.22x2.44m', 'unidad': 'lámina', 'stock': 7, 'minimo': 5, 'costo': 280.0},
    {'id': '10', 'categoria': 'MDF', 'nombre': 'MDF 9mm 1.22x2.44m', 'unidad': 'lámina', 'stock': 2, 'minimo': 3, 'costo': 380.0},
    {'id': '11', 'categoria': 'MDF', 'nombre': 'MDF 12mm 1.22x2.44m', 'unidad': 'lámina', 'stock': 4, 'minimo': 3, 'costo': 480.0},
    // Acrílico
    {'id': '12', 'categoria': 'Acrílico', 'nombre': 'Acrílico transparente 3mm', 'unidad': 'lámina', 'stock': 5, 'minimo': 3, 'costo': 220.0},
    {'id': '13', 'categoria': 'Acrílico', 'nombre': 'Acrílico blanco 3mm', 'unidad': 'lámina', 'stock': 3, 'minimo': 3, 'costo': 220.0},
    {'id': '14', 'categoria': 'Acrílico', 'nombre': 'Acrílico negro 3mm', 'unidad': 'lámina', 'stock': 2, 'minimo': 2, 'costo': 220.0},
    {'id': '15', 'categoria': 'Acrílico', 'nombre': 'Acrílico colores surtido', 'unidad': 'lámina', 'stock': 6, 'minimo': 2, 'costo': 220.0},
    // Consumibles
    {'id': '16', 'categoria': 'Consumibles', 'nombre': 'Brocas 3.175mm', 'unidad': 'pieza', 'stock': 15, 'minimo': 10, 'costo': 45.0},
    {'id': '17', 'categoria': 'Consumibles', 'nombre': 'Fresas MDF 6mm', 'unidad': 'pieza', 'stock': 4, 'minimo': 5, 'costo': 120.0},
    {'id': '18', 'categoria': 'Consumibles', 'nombre': 'Lente láser CO₂', 'unidad': 'pieza', 'stock': 2, 'minimo': 2, 'costo': 350.0},
    {'id': '19', 'categoria': 'Consumibles', 'nombre': 'Boquilla plasma', 'unidad': 'pieza', 'stock': 3, 'minimo': 5, 'costo': 85.0},
    // Acabados
    {'id': '20', 'categoria': 'Acabados', 'nombre': 'Aceite mineral', 'unidad': 'litro', 'stock': 2, 'minimo': 1, 'costo': 95.0},
    {'id': '21', 'categoria': 'Acabados', 'nombre': 'Barniz madera', 'unidad': 'litro', 'stock': 1, 'minimo': 1, 'costo': 120.0},
    {'id': '22', 'categoria': 'Acabados', 'nombre': 'Lija 120', 'unidad': 'pieza', 'stock': 20, 'minimo': 10, 'costo': 8.0},
    {'id': '23', 'categoria': 'Acabados', 'nombre': 'Lija 220', 'unidad': 'pieza', 'stock': 18, 'minimo': 10, 'costo': 8.0},
  ];

  final _categorias = ['Todos', 'Madera', 'MDF', 'Acrílico', 'Consumibles', 'Acabados'];

  List<Map<String, dynamic>> get _filtrados => _categoriaFiltro == 'Todos'
    ? _materiales
    : _materiales.where((m) => m['categoria'] == _categoriaFiltro).toList();

  List<Map<String, dynamic>> get _stockBajo =>
    _materiales.where((m) => (m['stock'] as int) <= (m['minimo'] as int)).toList();

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
        title: const Text('Inventario Bodega'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          isScrollable: true,
          tabs: [
            const Tab(text: 'Materiales'),
            Tab(text: 'Stock bajo (${_stockBajo.length})'),
            const Tab(text: 'Movimiento'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarMaterial,
        backgroundColor: AppColors.azul,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: TabBarView(controller: _tabs, children: [
        _tabMateriales(),
        _tabStockBajo(),
        _tabMovimiento(),
      ]),
    );
  }

  Widget _tabMateriales() => Column(children: [
    Container(color: Colors.white, padding: const EdgeInsets.all(12), child:
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:
        _categorias.map((c) => GestureDetector(
          onTap: () => setState(() => _categoriaFiltro = c),
          child: Container(margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _categoriaFiltro == c ? AppColors.azul : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _categoriaFiltro == c ? AppColors.azul : AppColors.grisBorde)),
            child: Text(c, style: TextStyle(fontSize: 11,
              color: _categoriaFiltro == c ? Colors.white : AppColors.textoSecundario))),
        )).toList()))),
    Expanded(child: ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filtrados.length,
      itemBuilder: (_, i) => _TarjetaMaterial(
        material: _filtrados[i],
        onEntrada: () => _registrarMovimiento(_filtrados[i], 'entrada'),
        onSalida: () => _registrarMovimiento(_filtrados[i], 'salida'),
      ))),
  ]);

  Widget _tabStockBajo() => _stockBajo.isEmpty
    ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, size: 48, color: AppColors.verde),
        SizedBox(height: 8),
        Text('¡Todo el inventario está bien!', style: TextStyle(color: AppColors.textoSecundario)),
      ]))
    : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _stockBajo.length,
        itemBuilder: (_, i) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.rojo.withOpacity(0.3))),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: AppColors.rojoClaro,
              child: Icon(Icons.warning_amber, color: AppColors.rojo, size: 20)),
            title: Text(_stockBajo[i]['nombre'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            subtitle: Text('Stock: ${_stockBajo[i]['stock']} / Mínimo: ${_stockBajo[i]['minimo']} ${_stockBajo[i]['unidad']}',
              style: const TextStyle(fontSize: 11, color: AppColors.rojo)),
            trailing: ElevatedButton(
              onPressed: () => _registrarMovimiento(_stockBajo[i], 'entrada'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
              child: const Text('Entrada', style: TextStyle(fontSize: 12)),
            ),
          )));

  Widget _tabMovimiento() => ListView(padding: const EdgeInsets.all(14), children: [
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('REGISTRAR MOVIMIENTO', style: TextStyle(fontSize: 10, color: AppColors.azul, letterSpacing: 1, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _registrarMovimientoGeneral('entrada'),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Entrada de material'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde),
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _registrarMovimientoGeneral('salida'),
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Salida de material'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.ambar),
          )),
        ]),
      ])),
    const SizedBox(height: 12),
    // Historial de movimientos (simulado)
    const Text('ÚLTIMOS MOVIMIENTOS', style: TextStyle(fontSize: 10, color: AppColors.textoSecundario, letterSpacing: 1)),
    const SizedBox(height: 8),
    ...[
      {'tipo': 'entrada', 'material': 'MDF 3mm', 'cantidad': 5, 'unidad': 'láminas', 'fecha': 'Hoy 10:30'},
      {'tipo': 'salida', 'material': 'Madera Pino 15cm', 'cantidad': 2, 'unidad': 'metros', 'fecha': 'Hoy 09:15'},
      {'tipo': 'entrada', 'material': 'Brocas 3.175mm', 'cantidad': 10, 'unidad': 'piezas', 'fecha': 'Ayer'},
      {'tipo': 'salida', 'material': 'Acrílico transparente', 'cantidad': 1, 'unidad': 'lámina', 'fecha': 'Ayer'},
    ].map((m) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: m['tipo'] == 'entrada' ? AppColors.verdeClaro : AppColors.ambarClaro,
          child: Icon(m['tipo'] == 'entrada' ? Icons.arrow_downward : Icons.arrow_upward,
            color: m['tipo'] == 'entrada' ? AppColors.verde : AppColors.ambar, size: 18)),
        title: Text(m['material'] as String, style: const TextStyle(fontSize: 13)),
        subtitle: Text('${m['cantidad']} ${m['unidad']}', style: const TextStyle(fontSize: 11)),
        trailing: Text(m['fecha'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      ))),
  ]);

  void _registrarMovimiento(Map<String, dynamic> material, String tipo) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text('${tipo == 'entrada' ? 'Entrada' : 'Salida'}: ${material['nombre']}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Stock actual: ${material['stock']} ${material['unidad']}',
          style: const TextStyle(color: AppColors.textoSecundario)),
        const SizedBox(height: 12),
        TextField(controller: ctrl, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Cantidad (${material['unidad']})',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () {
          final cant = int.tryParse(ctrl.text) ?? 0;
          if (cant > 0) {
            setState(() {
              final idx = _materiales.indexWhere((m) => m['id'] == material['id']);
              if (tipo == 'entrada') {
                _materiales[idx]['stock'] = (material['stock'] as int) + cant;
              } else {
                _materiales[idx]['stock'] = ((material['stock'] as int) - cant).clamp(0, 9999);
              }
            });
          }
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${tipo == 'entrada' ? 'Entrada' : 'Salida'} registrada: $cant ${material['unidad']}'),
            backgroundColor: tipo == 'entrada' ? AppColors.verde : AppColors.ambar,
          ));
        }, child: const Text('Registrar')),
      ],
    ));
  }

  void _registrarMovimientoGeneral(String tipo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Selecciona un material de la lista para registrar ${tipo == 'entrada' ? 'entrada' : 'salida'}')));
    _tabs.animateTo(0);
  }

  void _agregarMaterial() {
    final nombre = TextEditingController();
    final stock = TextEditingController(text: '0');
    final minimo = TextEditingController(text: '1');
    final costo = TextEditingController(text: '0');
    String categoria = 'Madera';
    String unidad = 'pieza';

    showModalBottomSheet(context: context, isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Nuevo material', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre del material',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: stock, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock inicial',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: minimo, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock mínimo',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)))),
          ]),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              if (nombre.text.isNotEmpty) {
                setState(() => _materiales.add({
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'categoria': categoria, 'nombre': nombre.text.trim(),
                  'unidad': unidad, 'stock': int.tryParse(stock.text) ?? 0,
                  'minimo': int.tryParse(minimo.text) ?? 1,
                  'costo': double.tryParse(costo.text) ?? 0,
                }));
                Navigator.pop(context);
              }
            },
            child: const Text('Agregar material')),
        ]))));
  }
}

class _TarjetaMaterial extends StatelessWidget {
  final Map<String, dynamic> material;
  final VoidCallback onEntrada;
  final VoidCallback onSalida;
  const _TarjetaMaterial({required this.material, required this.onEntrada, required this.onSalida});

  @override
  Widget build(BuildContext context) {
    final stockBajo = (material['stock'] as int) <= (material['minimo'] as int);
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: stockBajo ? AppColors.rojo.withOpacity(0.3) : AppColors.grisBorde, width: 0.5)),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(material['nombre'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(4)),
              child: Text(material['categoria'] as String, style: const TextStyle(fontSize: 10, color: AppColors.azul))),
            const SizedBox(width: 6),
            Text('Costo: ${fmt.format(material['costo'])}/${material['unidad']}',
              style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text('Stock: ', style: const TextStyle(fontSize: 12)),
            Text('${material['stock']} ${material['unidad']}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: stockBajo ? AppColors.rojo : AppColors.verde)),
            Text(' / mín: ${material['minimo']}', style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          ]),
        ])),
        Column(children: [
          SizedBox(width: 70, child: ElevatedButton(onPressed: onEntrada,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde, padding: const EdgeInsets.symmetric(vertical: 6)),
            child: const Text('+Entrada', style: TextStyle(fontSize: 10)))),
          const SizedBox(height: 4),
          SizedBox(width: 70, child: ElevatedButton(onPressed: onSalida,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.ambar, padding: const EdgeInsets.symmetric(vertical: 6)),
            child: const Text('-Salida', style: TextStyle(fontSize: 10)))),
        ]),
      ]),
    );
  }
}
