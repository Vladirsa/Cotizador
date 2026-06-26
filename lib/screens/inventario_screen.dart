import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/supabase_service.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});
  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _materiales = [];
  bool _cargando = true;
  String _filtroCategoria = 'Todas';
  final _fmt = NumberFormat('\$#,##0', 'es_MX');

  List<String> get _categorias {
    final cats = _materiales.map((m) => m['categoria'] as String? ?? 'Otro').toSet().toList()..sort();
    return ['Todas', ...cats];
  }

  List<Map<String, dynamic>> get _filtrados => _filtroCategoria == 'Todas'
    ? _materiales
    : _materiales.where((m) => m['categoria'] == _filtroCategoria).toList();

  List<Map<String, dynamic>> get _bajos => _filtrados.where((m) =>
    (m['stock_actual'] as int? ?? 0) <= (m['stock_minimo'] as int? ?? 1)).toList();

  double get _valorTotal => _filtrados.fold(0.0, (s, m) =>
    s + ((m['stock_actual'] as int? ?? 0) * ((m['costo_unitario'] as num?)?.toDouble() ?? 0)));

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final mats = await SupabaseService.getMateriales();
      if (mounted) setState(() { _materiales = mats; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: const Text('Inventario Bodega'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)],
        bottom: TabBar(controller: _tabs,
          labelColor: AppColors.azul, unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          tabs: [
            Tab(text: 'Materiales (${_filtrados.length})'),
            Tab(text: 'Movimientos'),
          ]),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _agregarMaterial,
        backgroundColor: AppColors.azul,
        child: const Icon(Icons.add, color: Colors.white)),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            _tabMateriales(),
            _tabMovimientos(),
          ]),
    );
  }

  Widget _tabMateriales() {
    return Column(children: [
      // Stats rápidos
      Container(color: Colors.white, padding: const EdgeInsets.all(10),
        child: Row(children: [
          _miniStat('${_filtrados.length}', 'Materiales', AppColors.azul),
          _miniStat('${_bajos.length}', 'Stock bajo', _bajos.isEmpty ? AppColors.verde : AppColors.rojo),
          _miniStat(_fmt.format(_valorTotal), 'Valor bodega', AppColors.azul),
        ])),

      // Filtros por categoría
      Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:
          _categorias.map((cat) {
            final activo = _filtroCategoria == cat;
            final count = cat == 'Todas' ? _materiales.length
              : _materiales.where((m) => m['categoria'] == cat).length;
            final hayBajos = cat != 'Todas' && _materiales
              .where((m) => m['categoria'] == cat)
              .any((m) => (m['stock_actual'] as int? ?? 0) <= (m['stock_minimo'] as int? ?? 1));
            return GestureDetector(
              onTap: () => setState(() => _filtroCategoria = cat),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: activo ? AppColors.azul : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: activo ? AppColors.azul : AppColors.grisBorde)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (hayBajos) const Padding(padding: EdgeInsets.only(right: 3),
                    child: Icon(Icons.warning_amber, size: 11, color: AppColors.rojo)),
                  Text('$cat ($count)', style: TextStyle(fontSize: 10,
                    color: activo ? Colors.white : AppColors.textoSecundario)),
                ])));
          }).toList()))),

      // Stock bajo warning
      if (_bajos.isNotEmpty)
        Container(margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.rojoClaro, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.warning_amber, size: 16, color: AppColors.rojo),
            const SizedBox(width: 6),
            Expanded(child: Text('${_bajos.length} material${_bajos.length > 1 ? "es" : ""} con stock bajo',
              style: const TextStyle(fontSize: 11, color: AppColors.rojo, fontWeight: FontWeight.w600))),
          ])),

      // Lista
      Expanded(child: RefreshIndicator(onRefresh: _cargar, child: _filtrados.isEmpty
        ? const Center(child: Text('No hay materiales', style: TextStyle(color: AppColors.textoSecundario)))
        : ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: _filtrados.length,
            itemBuilder: (_, i) => _TarjetaMaterial(
              material: _filtrados[i],
              onMovimiento: _cargar)))),
    ]);
  }

  Widget _tabMovimientos() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.swap_vert, size: 48, color: AppColors.textoSecundario),
      const SizedBox(height: 8),
      const Text('Historial de movimientos', style: TextStyle(color: AppColors.textoSecundario)),
      const SizedBox(height: 4),
      const Text('Entradas y salidas de materiales', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: _registrarMovimiento,
        icon: const Icon(Icons.add), label: const Text('Registrar movimiento')),
    ]));
  }

  Widget _miniStat(String valor, String label, Color color) => Expanded(child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 3),
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
        overflow: TextOverflow.ellipsis),
      Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textoSecundario), textAlign: TextAlign.center),
    ])));

  Future<void> _agregarMaterial() async {
    final n = TextEditingController(), unidad = TextEditingController(text: 'pieza');
    final minimo = TextEditingController(text: '1'), costo = TextEditingController();
    final stock = TextEditingController(text: '0');
    String categoria = 'Madera';
    final categoriasList = ['Madera', 'MDF', 'Acrílico', 'Consumibles', 'Acabados', 'Metal', 'Otro'];

    await showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: StatefulBuilder(builder: (ctx2, setS) => SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Text('Agregar material', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            TextField(controller: n, decoration: const InputDecoration(labelText: 'Nombre *', isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8))),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: categoria, isDense: true,
                decoration: const InputDecoration(labelText: 'Categoría',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                items: categoriasList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setS(() => categoria = v!))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: unidad, decoration: const InputDecoration(
                labelText: 'Unidad', isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: TextField(controller: stock, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock inicial', isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: minimo, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock mínimo', isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: costo, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Costo unit.', prefixText: '\$', isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
            ]),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azul,
                minimumSize: const Size(double.infinity, 44)),
              onPressed: () async {
                if (n.text.isEmpty) return;
                await SupabaseService.agregarMaterial({
                  'nombre': n.text.trim(), 'categoria': categoria,
                  'unidad': unidad.text.trim(), 'stock_actual': int.tryParse(stock.text) ?? 0,
                  'stock_minimo': int.tryParse(minimo.text) ?? 1,
                  'costo_unitario': double.tryParse(costo.text) ?? 0,
                });
                if (mounted) { Navigator.pop(context); _cargar(); }
              },
              child: const Text('Guardar material',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
            const SizedBox(height: 8),
          ]))))));
  }

  Future<void> _registrarMovimiento() async {
    if (_materiales.isEmpty) return;
    String? materialId = _materiales.first['id'];
    String tipo = 'entrada';
    final cant = TextEditingController(text: '1');
    final motivo = TextEditingController();

    await showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setS) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Registrar movimiento', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: materialId, isDense: true,
              decoration: const InputDecoration(labelText: 'Material',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              items: _filtrados.map((m) => DropdownMenuItem(value: m['id'] as String,
                child: Text(m['nombre'] ?? '', style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setS(() => materialId = v)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setS(() => tipo = 'entrada'),
                child: Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tipo == 'entrada' ? AppColors.verdeClaro : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tipo == 'entrada' ? AppColors.verde : AppColors.grisBorde)),
                  child: Center(child: Text('↑ Entrada', style: TextStyle(
                    color: tipo == 'entrada' ? AppColors.verde : Colors.grey, fontWeight: FontWeight.w600))))),),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(
                onTap: () => setS(() => tipo = 'salida'),
                child: Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tipo == 'salida' ? AppColors.rojoClaro : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tipo == 'salida' ? AppColors.rojo : AppColors.grisBorde)),
                  child: Center(child: Text('↓ Salida', style: TextStyle(
                    color: tipo == 'salida' ? AppColors.rojo : Colors.grey, fontWeight: FontWeight.w600)))))),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: TextField(controller: cant, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad', isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: motivo,
                decoration: const InputDecoration(labelText: 'Motivo', isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
            ]),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () async {
              if (materialId == null) return;
              await SupabaseService.registrarMovimiento(
                materialId: materialId!, tipo: tipo,
                cantidad: int.tryParse(cant.text) ?? 1, motivo: motivo.text.trim());
              if (mounted) { Navigator.pop(context); _cargar(); }
            }, child: const Text('Registrar')),
          ])))));
  }
}

class _TarjetaMaterial extends StatelessWidget {
  final Map<String, dynamic> material;
  final VoidCallback onMovimiento;
  const _TarjetaMaterial({required this.material, required this.onMovimiento});

  @override
  Widget build(BuildContext context) {
    final stockActual = material['stock_actual'] as int? ?? 0;
    final stockMinimo = material['stock_minimo'] as int? ?? 1;
    final unidad = material['unidad'] as String? ?? 'pieza';
    final bajStock = stockActual <= stockMinimo;
    final costo = (material['costo_unitario'] as num?)?.toDouble() ?? 0;
    final fmt = NumberFormat('\$#,##0', 'es_MX');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bajStock ? AppColors.rojo.withOpacity(0.3) : AppColors.grisBorde, width: 0.5)),
      child: ListTile(
        dense: true,
        leading: Container(width: 36, height: 36,
          decoration: BoxDecoration(
            color: bajStock ? AppColors.rojoClaro : AppColors.azulClaro,
            borderRadius: BorderRadius.circular(8)),
          child: Center(child: Icon(
            bajStock ? Icons.warning_amber : Icons.inventory_2_outlined,
            size: 18, color: bajStock ? AppColors.rojo : AppColors.azul))),
        title: Text(material['nombre'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        subtitle: Row(children: [
          Text('${material['categoria']}', style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          if (costo > 0) ...[
            const Text(' · ', style: TextStyle(color: AppColors.textoSecundario)),
            Text(fmt.format(costo), style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          ],
        ]),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$stockActual $unidad', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
            color: bajStock ? AppColors.rojo : AppColors.verde)),
          Text('min: $stockMinimo', style: const TextStyle(fontSize: 9, color: AppColors.textoSecundario)),
        ]),
        onTap: () => _mostrarOpciones(context),
      ));
  }

  void _mostrarOpciones(BuildContext context) {
    final stockActual = material['stock_actual'] as int? ?? 0;
    final cant = TextEditingController(text: '1');
    String tipo = 'entrada';

    showModalBottomSheet(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, setS) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(material['nombre'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Stock actual: $stockActual ${material['unidad']}',
            style: const TextStyle(color: AppColors.textoSecundario)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => setS(() => tipo = 'entrada'),
              child: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tipo == 'entrada' ? AppColors.verdeClaro : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tipo == 'entrada' ? AppColors.verde : AppColors.grisBorde)),
                child: Center(child: Text('↑ Entrada', style: TextStyle(
                  color: tipo == 'entrada' ? AppColors.verde : Colors.grey, fontWeight: FontWeight.w600)))))),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () => setS(() => tipo = 'salida'),
              child: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tipo == 'salida' ? AppColors.rojoClaro : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tipo == 'salida' ? AppColors.rojo : AppColors.grisBorde)),
                child: Center(child: Text('↓ Salida', style: TextStyle(
                  color: tipo == 'salida' ? AppColors.rojo : Colors.grey, fontWeight: FontWeight.w600)))))),
          ]),
          const SizedBox(height: 8),
          TextField(controller: cant, keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(labelText: 'Cantidad', isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8))),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () async {
            await SupabaseService.registrarMovimiento(
              materialId: material['id'], tipo: tipo,
              cantidad: int.tryParse(cant.text) ?? 1);
            if (ctx.mounted) { Navigator.pop(ctx); onMovimiento(); }
          }, child: const Text('Registrar movimiento')),
        ]))));
  }
}
