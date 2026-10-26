import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/supabase_service.dart';
import '../services/barcode_service.dart';
import '../i18n/tr.dart';

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
    final cats = _materiales.map((m) => m['categoria'] as String? ?? tr('Otro')).toSet().toList()..sort();
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
        title: Text(tr('Inventario Bodega')),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)],
        bottom: TabBar(controller: _tabs,
          labelColor: AppColors.azul, unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          tabs: [
            Tab(text: trf('Materiales ({0})', [(_filtrados.length)])),
            Tab(text: tr('Movimientos')),
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
          _miniStat('${_filtrados.length}', tr('Materiales'), AppColors.azul),
          _miniStat('${_bajos.length}', 'Stock bajo', _bajos.isEmpty ? AppColors.verde : AppColors.rojo),
          _miniStat(_fmt.format(_valorTotal), tr('Valor bodega'), AppColors.azul),
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
                  Text('${tr(cat)} ($count)', style: TextStyle(fontSize: 10,
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
            Expanded(child: Text(trf('{0} material{1} con stock bajo', [(_bajos.length), (_bajos.length > 1 ? "es" : "")]),
              style: const TextStyle(fontSize: 11, color: AppColors.rojo, fontWeight: FontWeight.w600))),
          ])),

      // Lista
      Expanded(child: RefreshIndicator(onRefresh: _cargar, child: _filtrados.isEmpty
        ? Center(child: Text(tr('No hay materiales'), style: TextStyle(color: AppColors.textoSecundario)))
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
      Text(tr('Historial de movimientos'), style: TextStyle(color: AppColors.textoSecundario)),
      const SizedBox(height: 4),
      Text(tr('Entradas y salidas de materiales'), style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: _registrarMovimiento,
        icon: const Icon(Icons.add), label: Text(tr('Registrar movimiento'))),
    ]));
  }

  Widget _miniStat(String valor, String label, Color color) => Expanded(child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 3),
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(tr(valor), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
        overflow: TextOverflow.ellipsis),
      Text(tr(label), style: const TextStyle(fontSize: 9, color: AppColors.textoSecundario), textAlign: TextAlign.center),
    ])));

  Future<void> _agregarMaterial() async {
    final n = TextEditingController(), unidad = TextEditingController(text: 'pieza');
    final minimo = TextEditingController(text: '1'), costo = TextEditingController();
    final stock = TextEditingController(text: '0');
    String categoria = tr('Madera');
    final categoriasList = ['Madera', 'MDF', 'Acrílico', 'Consumibles', 'Acabados', 'Metal', 'Otro'];

    await showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setS) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(tr('Agregar material'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final codigo = await BarcodeService.escanear(ctx);
                  if (codigo == null) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(tr('Buscando...')), duration: Duration(seconds: 2)));
                  final resultado = await BarcodeService.buscarProducto(codigo);
                  setS(() {
                    if (resultado?.nombre != null && resultado!.nombre!.isNotEmpty) {
                      n.text = resultado.nombre!;
                    }
                  });
                  if (resultado == null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(tr('No se encontró — llena el nombre a mano')),
                      backgroundColor: AppColors.ambar));
                  }
                },
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: Text(tr('Escanear código')))),
            const SizedBox(height: 2),
            TextField(controller: n, decoration: InputDecoration(labelText: tr('Nombre *'), isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8))),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: categoria, isDense: true,
                decoration: InputDecoration(labelText: tr('Categoría'),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                items: categoriasList.map((c) => DropdownMenuItem(value: c, child: Text(tr(c)))).toList(),
                onChanged: (v) => setS(() => categoria = v!))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: unidad, decoration: InputDecoration(
                labelText: tr('Unidad'), isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: TextField(controller: stock, keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('Stock inicial'), isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: minimo, keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('Stock mínimo'), isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: costo, keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('Costo unit.'), prefixText: '\$', isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
            ]),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () async {
              if (n.text.isEmpty) return;
              await SupabaseService.agregarMaterial({
                'nombre': n.text.trim(), 'categoria': categoria,
                'unidad': unidad.text.trim(), 'stock_actual': int.tryParse(stock.text) ?? 0,
                'stock_minimo': int.tryParse(minimo.text) ?? 1,
                'costo_unitario': double.tryParse(costo.text) ?? 0,
              });
              if (mounted) { Navigator.pop(context); _cargar(); }
            }, child: Text(tr('Guardar material'))),
          ])))));
  }

  Future<void> _registrarMovimiento() async {
    if (_materiales.isEmpty) return;
    String? materialId = _materiales.first['id'];
    String tipo = 'entrada';
    final cant = TextEditingController(text: '1');
    final motivo = TextEditingController();

    await showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) => Container(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2))),
          Text(tr('Registrar movimiento'),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: materialId, isDense: true,
              decoration: InputDecoration(labelText: tr('Material'),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              items: _filtrados.map((m) => DropdownMenuItem(value: m['id'] as String,
                child: Text(tr(m['nombre'] ?? ''), style: const TextStyle(fontSize: 13)))).toList(),
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
                  child: Center(child: Text(tr('↑ Entrada'), style: TextStyle(
                    color: tipo == 'entrada' ? AppColors.verde : Colors.grey, fontWeight: FontWeight.w600))))),),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(
                onTap: () => setS(() => tipo = 'salida'),
                child: Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tipo == 'salida' ? AppColors.rojoClaro : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tipo == 'salida' ? AppColors.rojo : AppColors.grisBorde)),
                  child: Center(child: Text(tr('↓ Salida'), style: TextStyle(
                    color: tipo == 'salida' ? AppColors.rojo : Colors.grey, fontWeight: FontWeight.w600)))))),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: TextField(controller: cant, keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('Cantidad'), isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: motivo,
                decoration: InputDecoration(labelText: tr('Motivo'), isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
            ]),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (materialId == null) return;
                  final error = await SupabaseService.registrarMovimiento(
                    materialId: materialId!, tipo: tipo,
                    cantidad: int.tryParse(cant.text) ?? 1,
                    motivo: motivo.text.trim());
                  if (error != null) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr(error)), backgroundColor: AppColors.rojo));
                    return;
                  }
                  if (mounted) { Navigator.pop(context); _cargar(); }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul,
                  minimumSize: const Size(double.infinity, 44)),
                child: Text(tr('Registrar'),
                  style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600)))),
          const SizedBox(height: 8),
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
    final fmt = NumberFormat(r'$#,##0', 'es_MX');

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
        title: Text(tr(material['nombre'] ?? ''), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        subtitle: Row(children: [
          Text(tr('${material['categoria']}'), style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
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

  // ── Menú principal: Movimiento / Editar / Eliminar ──────
  void _mostrarOpciones(BuildContext context) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.swap_vert, color: AppColors.azul),
          title: Text(tr('Registrar movimiento (entrada/salida)')),
          onTap: () { Navigator.pop(ctx); _mostrarMovimiento(context); }),
        ListTile(
          leading: const Icon(Icons.edit_outlined, color: AppColors.azul),
          title: Text(tr('Editar producto')),
          onTap: () { Navigator.pop(ctx); _mostrarEditar(context); }),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: AppColors.rojo),
          title: Text(tr('Eliminar producto'), style: TextStyle(color: AppColors.rojo)),
          onTap: () { Navigator.pop(ctx); _confirmarEliminar(context); }),
      ])));
  }

  // ── Registrar entrada/salida (lo que ya existía) ────────
  void _mostrarMovimiento(BuildContext context) {
    final stockActual = material['stock_actual'] as int? ?? 0;
    final cant = TextEditingController(text: '1');
    String tipo = 'entrada';

    showModalBottomSheet(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, setS) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr(material['nombre'] ?? ''), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(trf('Stock actual: {0} {1}', [stockActual, (material['unidad'])]),
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
                child: Center(child: Text(tr('↑ Entrada'), style: TextStyle(
                  color: tipo == 'entrada' ? AppColors.verde : Colors.grey, fontWeight: FontWeight.w600)))))),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () => setS(() => tipo = 'salida'),
              child: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tipo == 'salida' ? AppColors.rojoClaro : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tipo == 'salida' ? AppColors.rojo : AppColors.grisBorde)),
                child: Center(child: Text(tr('↓ Salida'), style: TextStyle(
                  color: tipo == 'salida' ? AppColors.rojo : Colors.grey, fontWeight: FontWeight.w600)))))),
          ]),
          const SizedBox(height: 8),
          TextField(controller: cant, keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(labelText: tr('Cantidad'), isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8))),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () async {
            final error = await SupabaseService.registrarMovimiento(
              materialId: material['id'], tipo: tipo,
              cantidad: int.tryParse(cant.text) ?? 1);
            if (error != null) {
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text(tr(error)), backgroundColor: AppColors.rojo));
              return;
            }
            if (ctx.mounted) { Navigator.pop(ctx); onMovimiento(); }
          }, child: Text(tr('Registrar movimiento'))),
        ]))));
  }

  // ── Editar producto (nombre, categoría, costo, stock mínimo, unidad) ──
  void _mostrarEditar(BuildContext context) {
    final nombreCtrl = TextEditingController(text: material['nombre'] ?? '');
    final categoriaCtrl = TextEditingController(text: material['categoria'] ?? '');
    final costoCtrl = TextEditingController(
      text: ((material['costo_unitario'] as num?)?.toDouble() ?? 0).toStringAsFixed(2));
    final stockMinCtrl = TextEditingController(
      text: (material['stock_minimo'] as int? ?? 1).toString());
    final unidadCtrl = TextEditingController(text: material['unidad'] ?? 'pieza');

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16, right: 16, top: 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('Editar producto'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(controller: nombreCtrl,
            decoration: InputDecoration(labelText: tr('Nombre'), isDense: true,
              border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: categoriaCtrl,
            decoration: InputDecoration(labelText: tr('Categoría'), isDense: true,
              border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: costoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: tr('Costo unitario'), isDense: true,
                prefixText: r'$', border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: stockMinCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('Stock mínimo'), isDense: true,
                border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: unidadCtrl,
            decoration: InputDecoration(labelText: tr('Unidad (pieza, m², kg...)'), isDense: true,
              border: OutlineInputBorder())),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              final error = await SupabaseService.actualizarMaterial(material['id'], {
                'nombre': nombreCtrl.text.trim(),
                'categoria': categoriaCtrl.text.trim(),
                'costo_unitario': double.tryParse(costoCtrl.text) ?? 0,
                'stock_minimo': int.tryParse(stockMinCtrl.text) ?? 1,
                'unidad': unidadCtrl.text.trim(),
              });
              if (error != null) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(tr(error)), backgroundColor: AppColors.rojo));
                return;
              }
              if (ctx.mounted) { Navigator.pop(ctx); onMovimiento(); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul,
              padding: const EdgeInsets.symmetric(vertical: 13)),
            child: Text(tr('Guardar cambios'), style: TextStyle(color: Colors.white,
              fontWeight: FontWeight.w700)))),
          const SizedBox(height: 20),
        ]))));
  }

  // ── Confirmar y eliminar producto ────────────────────────
  void _confirmarEliminar(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('¿Eliminar producto?')),
      content: Text(trf('Se eliminará "{0}" permanentemente del inventario. Esta acción no se puede deshacer.', [(material['nombre'])])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancelar'))),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final error = await SupabaseService.eliminarMaterial(material['id']);
            if (error != null) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr(error)), backgroundColor: AppColors.rojo));
              return;
            }
            onMovimiento();
          },
          child: Text(tr('Eliminar'), style: TextStyle(color: AppColors.rojo, fontWeight: FontWeight.w700))),
      ]));
  }
}
