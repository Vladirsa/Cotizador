import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});
  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Producto> _productos = [];
  List<CategoriaProducto> _categorias = [];
  String _categoriaFiltro = 'Todos';
  String _busqueda = '';
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() { if (_tabs.index == 0) _cargar(); });
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final prods = await SupabaseService.getProductos();
      final cats = await SupabaseService.getCategorias();
      if (mounted) setState(() {
        _productos = prods;
        _categorias = cats;
        _cargando = false;
      });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  List<Producto> get _filtrados {
    return _productos.where((p) {
      final matchCat = _categoriaFiltro == 'Todos' || p.categoriaNombre == _categoriaFiltro;
      final matchBusq = _busqueda.isEmpty ||
          p.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
          (p.sku?.toLowerCase().contains(_busqueda.toLowerCase()) ?? false);
      return matchCat && matchBusq;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: const Text('Productos y Catálogo'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          tabs: const [Tab(text: 'Catálogo'), Tab(text: 'Nuevo producto')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _listaCatalogo(),
        _FormProducto(categorias: _categorias, onGuardado: () { _cargar(); _tabs.animateTo(0); }),
      ]),
    );
  }

  Widget _listaCatalogo() => Column(children: [
    Container(color: Colors.white, padding: const EdgeInsets.all(12), child: Column(children: [
      TextField(
        decoration: InputDecoration(
          hintText: 'Buscar producto o SKU...',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true, fillColor: AppColors.gris,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12)),
        onChanged: (v) => setState(() => _busqueda = v),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        _chipCategoria('Todos'),
        ..._categorias.map((c) => _chipCategoria(c.nombre)),
      ])),
    ])),
    Expanded(child: _cargando
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(onRefresh: _cargar, child: _filtrados.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textoSecundario),
              const SizedBox(height: 8),
              const Text('No hay productos', style: TextStyle(color: AppColors.textoSecundario)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => _tabs.animateTo(1), child: const Text('Agregar primer producto')),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filtrados.length,
              itemBuilder: (_, i) => _TarjetaProducto(
                producto: _filtrados[i],
                onEditar: () => _editarProducto(_filtrados[i]),
                onEliminar: () => _confirmarEliminar(_filtrados[i]),
              )))),
  ]);

  Widget _chipCategoria(String nombre) => GestureDetector(
    onTap: () => setState(() => _categoriaFiltro = nombre),
    child: Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _categoriaFiltro == nombre ? AppColors.azul : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _categoriaFiltro == nombre ? AppColors.azul : AppColors.grisBorde)),
      child: Text(nombre, style: TextStyle(fontSize: 11,
        color: _categoriaFiltro == nombre ? Colors.white : AppColors.textoSecundario)),
    ),
  );

  void _editarProducto(Producto producto) {
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: _FormProducto(producto: producto, categorias: _categorias,
          onGuardado: () { Navigator.pop(context); _cargar(); }),
      ));
  }

  void _confirmarEliminar(Producto producto) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('¿Eliminar producto?'),
      content: Text('Se eliminará "${producto.nombre}" del catálogo. '
        'No aparecerá más en cotizaciones ni en el catálogo público.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            try {
              await SupabaseService.eliminarProducto(producto.id!);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('✅ "${producto.nombre}" eliminado'), backgroundColor: AppColors.verde));
                _cargar();
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Error al eliminar: $e'), backgroundColor: AppColors.rojo));
            }
          },
          child: const Text('Eliminar', style: TextStyle(color: AppColors.rojo, fontWeight: FontWeight.w700))),
      ]));
  }
}

class _TarjetaProducto extends StatelessWidget {
  final Producto producto;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  const _TarjetaProducto({required this.producto, required this.onEditar, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: producto.stockBajo ? AppColors.rojo.withOpacity(0.3) : AppColors.grisBorde, width: 0.5)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.inventory_2_outlined, color: AppColors.azul, size: 20)),
        title: Text(producto.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (producto.sku != null) Text('SKU: ${producto.sku}', style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          Row(children: [
            if (producto.categoriaNombre != null) Container(
              margin: const EdgeInsets.only(top: 4, right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(4)),
              child: Text(producto.categoriaNombre!, style: const TextStyle(fontSize: 10, color: AppColors.azul))),
            if (producto.stockBajo) Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.rojoClaro, borderRadius: BorderRadius.circular(4)),
              child: const Text('Stock bajo', style: TextStyle(fontSize: 10, color: AppColors.rojo))),
          ]),
        ]),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('\$${producto.precioVenta.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.azul)),
          Text('Stock: ${producto.stockDisponible}', style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(onTap: onEditar,
              child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textoSecundario)),
            const SizedBox(width: 10),
            GestureDetector(onTap: onEliminar,
              child: const Icon(Icons.delete_outline, size: 16, color: AppColors.rojo)),
          ]),
        ]),
      ),
    );
  }
}

class _FormProducto extends StatefulWidget {
  final Producto? producto;
  final List<CategoriaProducto> categorias;
  final VoidCallback onGuardado;
  const _FormProducto({this.producto, required this.categorias, required this.onGuardado});
  @override
  State<_FormProducto> createState() => _FormProductoState();
}

class _FormProductoState extends State<_FormProducto> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.producto?.nombre);
  late final _sku = TextEditingController(text: widget.producto?.sku);
  late final _descripcion = TextEditingController(text: widget.producto?.descripcion);
  late final _marca = TextEditingController(text: widget.producto?.marca);
  late final _costo = TextEditingController(text: widget.producto?.costo.toString() ?? '0');
  late final _precio = TextEditingController(text: widget.producto?.precioVenta.toString() ?? '0');
  late final _stock = TextEditingController(text: widget.producto?.stockDisponible.toString() ?? '0');
  late final _stockMin = TextEditingController(text: widget.producto?.stockMinimo.toString() ?? '1');
  late final _ubicacion = TextEditingController(text: widget.producto?.ubicacionFisica ?? '');
  String? _categoriaId;
  String _unidad = 'Pieza';
  bool _aplicaIva = true;
  bool _guardando = false;
  String? _imagenUrl;
  Uint8List? _imagenPreview;
  bool _subiendoImagen = false;

  final _unidades = ['Pieza', 'Metro', 'Lámina', 'Litro', 'Kilogramo', 'Servicio', 'Diseño'];

  @override
  void initState() {
    super.initState();
    _imagenUrl = widget.producto?.imagenUrl;
    _categoriaId = widget.producto?.categoriaId;
    _unidad = widget.producto?.unidadMedida ?? 'Pieza';
    _aplicaIva = widget.producto?.aplicaIva ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.producto == null ? 'Nuevo producto' : 'Editar producto'),
        leading: widget.producto != null ? IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)) : null,
        actions: [TextButton(onPressed: _guardar, child: _guardando
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w600)))],
      ),
      body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(14), children: [
        _seccion('Foto del producto'),
        Center(child: GestureDetector(
          onTap: _subiendoImagen ? null : _elegirImagen,
          child: Container(width: 140, height: 140,
            decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grisBorde)),
            child: _subiendoImagen
              ? const Center(child: CircularProgressIndicator())
              : _imagenPreview != null
                ? ClipRRect(borderRadius: BorderRadius.circular(11),
                    child: Image.memory(_imagenPreview!, fit: BoxFit.cover, width: 140, height: 140))
                : (_imagenUrl != null && _imagenUrl!.isNotEmpty)
                  ? ClipRRect(borderRadius: BorderRadius.circular(11),
                      child: Image.network(_imagenUrl!, fit: BoxFit.cover, width: 140, height: 140,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined,
                          color: AppColors.textoSecundario, size: 32)))
                  : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_a_photo_outlined, color: AppColors.textoSecundario, size: 28),
                      SizedBox(height: 6),
                      Text('Agregar foto', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                    ])))),
        const SizedBox(height: 16),
        _seccion('Información básica'),
        _campo('Nombre del producto *', _nombre, obligatorio: true),
        Row(children: [
          Expanded(child: _campo('SKU / Código', _sku)),
          const SizedBox(width: 8),
          Expanded(child: _campo('Marca', _marca)),
        ]),
        _campo('Descripción', _descripcion, lineas: 2),
        _seccion('Categoría y clasificación'),
        _dropCampo('Categoría', _categoriaId,
          widget.categorias.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre, style: const TextStyle(fontSize: 13)))).toList(),
          (v) => setState(() => _categoriaId = v)),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Unidad de medida', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(value: _unidad,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: _unidades.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _unidad = v!)),
          ])),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Aplica IVA', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            Switch(value: _aplicaIva, onChanged: (v) => setState(() => _aplicaIva = v), activeColor: AppColors.verde),
          ])),
        ]),
        _seccion('Precios'),
        Row(children: [
          Expanded(child: _campo('Costo \$', _costo, tipo: TextInputType.number)),
          const SizedBox(width: 8),
          Expanded(child: _campo('Precio venta \$', _precio, tipo: TextInputType.number, obligatorio: true)),
        ]),
        _seccion('Inventario'),
        Row(children: [
          Expanded(child: _campo('Stock disponible', _stock, tipo: TextInputType.number)),
          const SizedBox(width: 8),
          Expanded(child: _campo('Stock mínimo', _stockMin, tipo: TextInputType.number)),
        ]),
        _campo('Ubicación física', _ubicacion),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: _guardar,
          child: Text(widget.producto == null ? 'Guardar producto' : 'Actualizar producto')),
        const SizedBox(height: 20),
      ])),
    );
  }

  Widget _seccion(String t) => Padding(padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.azul, letterSpacing: 1, fontWeight: FontWeight.w600)));

  Widget _campo(String label, TextEditingController ctrl, {bool obligatorio = false, TextInputType tipo = TextInputType.text, int lineas = 1}) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      const SizedBox(height: 4),
      TextFormField(controller: ctrl, keyboardType: tipo, maxLines: lineas,
        validator: obligatorio ? (v) => v?.isEmpty == true ? 'Requerido' : null : null,
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        style: const TextStyle(fontSize: 13)),
    ]));

  Widget _dropCampo(String label, String? value, List<DropdownMenuItem<String>> items, ValueChanged<String?> onChanged) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      const SizedBox(height: 4),
      DropdownButtonFormField<String>(value: value,
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        hint: const Text('Seleccionar', style: TextStyle(fontSize: 13)),
        items: items, onChanged: onChanged),
    ]));

  Future<void> _elegirImagen() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      setState(() { _imagenPreview = bytes; _subiendoImagen = true; });

      final negId = AuthService.negocioId ?? 'default';
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final path = '$negId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage.from('productos')
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
      final url = Supabase.instance.client.storage.from('productos').getPublicUrl(path);

      setState(() { _imagenUrl = url; _subiendoImagen = false; });
    } catch (e) {
      setState(() => _subiendoImagen = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al subir foto: $e'), backgroundColor: AppColors.rojo));
    }
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final producto = Producto(
        id: widget.producto?.id,
        sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
        nombre: _nombre.text.trim(),
        descripcion: _descripcion.text.trim().isEmpty ? null : _descripcion.text.trim(),
        categoriaId: _categoriaId,
        marca: _marca.text.trim().isEmpty ? null : _marca.text.trim(),
        costo: double.tryParse(_costo.text) ?? 0,
        precioVenta: double.tryParse(_precio.text) ?? 0,
        aplicaIva: _aplicaIva,
        unidadMedida: _unidad,
        stockDisponible: int.tryParse(_stock.text) ?? 0,
        stockMinimo: int.tryParse(_stockMin.text) ?? 1,
        ubicacionFisica: null,
        imagenUrl: _imagenUrl,
      );
      if (widget.producto == null) {
        await SupabaseService.crearProducto(producto);
      } else {
        await SupabaseService.actualizarProducto(producto);
      }
      widget.onGuardado();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}
