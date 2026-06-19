import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_service.dart';
import '../services/pdf_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CotizarScreen extends StatefulWidget {
  const CotizarScreen({super.key});
  @override
  State<CotizarScreen> createState() => _CotizarScreenState();
}

class _CotizarScreenState extends State<CotizarScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: const Text('Cotizador'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          tabs: const [Tab(text: 'Nueva cotización'), Tab(text: 'Catálogo / PDFs')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        const _NuevaCotizacion(),
        const _CatalogoPDFs(),
      ]),
    );
  }
}

class _NuevaCotizacion extends StatefulWidget {
  const _NuevaCotizacion();
  @override
  State<_NuevaCotizacion> createState() => _NuevaCotizacionState();
}

class _NuevaCotizacionState extends State<_NuevaCotizacion> {
  Cliente? _clienteSeleccionado;
  List<CotizacionItem> _items = [];
  double _descuentoPct = 0;
  double _ivaPct = 16;
  double _costoEnvio = 0;
  String _metodoPago = '50% anticipo / 50% entrega';
  String _condicionEntrega = 'LAB — En planta HETNA';
  DateTime? _fechaEntrega;
  int? _diasHabiles;
  String _notas = '';
  bool _generando = false;

  final _metodosPago = ['50% anticipo / 50% entrega', 'Pago total anticipado', 'Crédito 30 días', 'Crédito 60 días', 'Transferencia bancaria'];
  final _condiciones = ['LAB — En planta HETNA', 'Entrega en domicilio cliente', 'Flete por cuenta del cliente', 'Instalación incluida'];

  double get _subtotal => _items.fold(0, (s, i) => s + i.subtotal);
  double get _montoDescuento => _subtotal * _descuentoPct / 100;
  double get _baseIva => _subtotal - _montoDescuento;
  double get _montoIva => _baseIva * _ivaPct / 100;
  double get _total => _baseIva + _montoIva + _costoEnvio;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('\$#,##0.00', 'es_MX');
    return ListView(padding: const EdgeInsets.all(14), children: [
      // Cliente
      _bloque('Cliente', Icons.person_outline, _clienteSeleccionado == null
        ? ElevatedButton.icon(onPressed: _seleccionarCliente, icon: const Icon(Icons.person_search), label: const Text('Seleccionar cliente'))
        : ListTile(contentPadding: EdgeInsets.zero,
            title: Text(_clienteSeleccionado!.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('${_clienteSeleccionado!.rfc ?? ""} · ${_clienteSeleccionado!.ciudad ?? ""}', style: const TextStyle(fontSize: 11)),
            trailing: TextButton(onPressed: _seleccionarCliente, child: const Text('Cambiar')))),

      // Productos
      _bloque('Productos', Icons.inventory_2_outlined, Column(children: [
        ..._items.map((item) => _ItemRow(item: item, onEliminar: () => setState(() => _items.remove(item)),
          onCantidadChanged: (v) => setState(() => item.cantidad = v))),
        OutlinedButton.icon(onPressed: _agregarProducto, icon: const Icon(Icons.add), label: const Text('Agregar producto')),
      ])),

      // Condiciones
      _bloque('Condiciones de entrega', Icons.local_shipping_outlined, Column(children: [
        Row(children: [
          Expanded(child: _campo('Fecha entrega', child: GestureDetector(
            onTap: _seleccionarFecha,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.grisBorde)),
              child: Text(_fechaEntrega != null ? DateFormat('dd/MM/yyyy').format(_fechaEntrega!) : 'Seleccionar',
                style: TextStyle(fontSize: 13, color: _fechaEntrega != null ? Colors.black : AppColors.textoSecundario))),
          ))),
          const SizedBox(width: 8),
          Expanded(child: _campo('Días hábiles', child: TextField(
            decoration: const InputDecoration(hintText: '15 días', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13),
            onChanged: (v) => _diasHabiles = int.tryParse(v),
          ))),
        ]),
        const SizedBox(height: 8),
        _campo('Condición de entrega', child: DropdownButtonFormField<String>(
          value: _condicionEntrega,
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          items: _condiciones.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => _condicionEntrega = v!),
        )),
        const SizedBox(height: 8),
        _campo('Método de pago', child: DropdownButtonFormField<String>(
          value: _metodoPago,
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          items: _metodosPago.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _metodoPago = v!),
        )),
        const SizedBox(height: 8),
        _campo('Notas y observaciones', child: TextField(
          decoration: const InputDecoration(hintText: 'Garantías, accesorios, condiciones especiales...', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          maxLines: 3, style: const TextStyle(fontSize: 13),
          onChanged: (v) => setState(() => _notas = v),
        )),
      ])),

      // Resumen financiero
      _bloque('Resumen financiero', Icons.calculate_outlined, Column(children: [
        Row(children: [
          Expanded(child: _campo('Descuento %', child: TextField(
            decoration: const InputDecoration(hintText: '0', suffixText: '%', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13),
            onChanged: (v) => setState(() => _descuentoPct = double.tryParse(v) ?? 0),
          ))),
          const SizedBox(width: 8),
          Expanded(child: _campo('Costo envío', child: TextField(
            decoration: const InputDecoration(hintText: '0', prefixText: '\$', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13),
            onChanged: (v) => setState(() => _costoEnvio = double.tryParse(v) ?? 0),
          ))),
        ]),
        const SizedBox(height: 8),
        _filaTotal('Subtotal', fmt.format(_subtotal)),
        if (_descuentoPct > 0) _filaTotal('Descuento ${_descuentoPct.toInt()}%', '-${fmt.format(_montoDescuento)}', color: AppColors.verde),
        if (_costoEnvio > 0) _filaTotal('Envío', fmt.format(_costoEnvio)),
        _filaTotal('IVA ${_ivaPct.toInt()}%', fmt.format(_montoIva)),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
          Text(fmt.format(_total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
        ]),
      ])),

      // Botones de acción
      const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: _items.isEmpty || _clienteSeleccionado == null ? null : _generarPDF,
        icon: _generando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.picture_as_pdf),
        label: const Text('Generar PDF profesional'),
      ),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: _items.isEmpty || _clienteSeleccionado == null ? null : _enviarWA,
        icon: const Icon(Icons.chat),
        label: const Text('Enviar cotización por WhatsApp'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
      ),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: _items.isEmpty || _clienteSeleccionado == null ? null : _convertirPedido,
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Convertir en PEDIDO'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF185fa5)),
      ),
      const SizedBox(height: 20),
    ]);
  }

  Widget _bloque(String titulo, IconData icon, Widget contenido) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: AppColors.azul),
        const SizedBox(width: 6),
        Text(titulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.azul)),
      ]),
      const SizedBox(height: 10),
      contenido,
    ]),
  );

  Widget _campo(String label, {required Widget child}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
    const SizedBox(height: 4),
    child,
  ]);

  Widget _filaTotal(String label, String valor, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
      Text(valor, style: TextStyle(fontSize: 12, color: color ?? Colors.black, fontWeight: FontWeight.w500)),
    ]),
  );

  Future<void> _seleccionarCliente() async {
    final clientes = await SupabaseService.getClientes();
    if (!mounted) return;
    showModalBottomSheet(context: context, isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(initialChildSize: 0.7, builder: (_, ctrl) =>
        Container(color: Colors.white, child: Column(children: [
          const Padding(padding: EdgeInsets.all(12), child: Text('Seleccionar cliente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          Expanded(child: ListView.builder(controller: ctrl, itemCount: clientes.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(clientes[i].nombreCompleto),
              subtitle: Text(clientes[i].tipoCliente),
              onTap: () { setState(() => _clienteSeleccionado = clientes[i]); Navigator.pop(context); },
            ))),
        ]))));
  }

  Future<void> _agregarProducto() async {
    final productos = await SupabaseService.getProductos();
    if (!mounted) return;
    showModalBottomSheet(context: context, isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(initialChildSize: 0.7, builder: (_, ctrl) =>
        Container(color: Colors.white, child: Column(children: [
          const Padding(padding: EdgeInsets.all(12), child: Text('Agregar producto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          Expanded(child: ListView.builder(controller: ctrl, itemCount: productos.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(productos[i].nombre),
              subtitle: Text('\$${productos[i].precioVenta.toStringAsFixed(0)}'),
              onTap: () {
                setState(() => _items.add(CotizacionItem.fromProducto(productos[i])));
                Navigator.pop(context);
              },
            ))),
        ]))));
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 15)),
      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (fecha != null) setState(() => _fechaEntrega = fecha);
  }

  Future<void> _generarPDF() async {
    setState(() => _generando = true);
    try {
      final cfg = await SupabaseService.getConfiguracion();
      final cot = Cotizacion(
        folio: 'COT-${DateTime.now().millisecondsSinceEpoch}',
        cliente: _clienteSeleccionado,
        items: _items,
        descuentoPct: _descuentoPct,
        ivaPct: _ivaPct,
        costoEnvio: _costoEnvio,
        metodoPago: _metodoPago,
        condicionEntrega: _condicionEntrega,
        fechaEntrega: _fechaEntrega,
        notas: _notas,
        createdAt: DateTime.now(),
      );
      final bytes = await PdfService.generarCotizacion(cotizacion: cot, empresa: cfg);
      await PdfService.compartirPdf(bytes, 'Cotizacion_HETNA_${cot.folio}.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _enviarWA() async {
    if (_clienteSeleccionado == null || _items.isEmpty) return;
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final itemsTexto = _items.map((i) => '• ${i.nombreProducto} x${i.cantidad} = ${fmt.format(i.subtotal)}').join('\n');
    final mensaje = '¡Hola ${_clienteSeleccionado!.nombre}! 👋\n\nTe comparto tu cotización de *HETNA CNC*:\n\n$itemsTexto\n\nSubtotal: ${fmt.format(_subtotal)}\nIVA 16%: ${fmt.format(_montoIva)}\n*TOTAL: ${fmt.format(_total)}*\n\nMétodo de pago: $_metodoPago\n\n¿Te parece bien? Quedamos a tus órdenes 😊';
    final numero = _clienteSeleccionado!.whatsappNumero.replaceAll(RegExp(r'[^0-9]'), '');
    final url = 'https://wa.me/52$numero?text=${Uri.encodeComponent(mensaje)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _convertirPedido() async {
    if (_clienteSeleccionado == null || _items.isEmpty) return;
    try {
      final cot = Cotizacion(
        folio: 'COT-${DateTime.now().millisecondsSinceEpoch}',
        cliente: _clienteSeleccionado,
        clienteId: _clienteSeleccionado!.id,
        items: _items,
        descuentoPct: _descuentoPct,
        ivaPct: _ivaPct,
        costoEnvio: _costoEnvio,
        metodoPago: _metodoPago,
        condicionEntrega: _condicionEntrega,
        fechaEntrega: _fechaEntrega,
        notas: _notas,
        estado: 'Pedido',
        createdAt: DateTime.now(),
      );
      final cotGuardada = await SupabaseService.crearCotizacion(cot, _items);
      await SupabaseService.convertirEnPedido(cotGuardada);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Pedido creado correctamente'), backgroundColor: Color(0xFF1d9e75)));
        setState(() { _items = []; _clienteSeleccionado = null; });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

class _CatalogoPDFs extends StatefulWidget {
  const _CatalogoPDFs();
  @override
  State<_CatalogoPDFs> createState() => _CatalogoPDFsState();
}

class _CatalogoPDFsState extends State<_CatalogoPDFs> {
  List<Producto> _productos = [];
  List<PdfCatalogo> _pdfs = [];
  String _categoria = 'Todos';
  bool _cargando = true;

  final _categorias = ['Todos', 'Maquinaria CNC', 'Refacciones', 'Herramientas', 'Consumibles', 'Servicios', 'Diseños CNC'];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final prods = await SupabaseService.getProductos();
      final pdfs = await SupabaseService.getPdfs();
      if (mounted) setState(() { _productos = prods; _pdfs = pdfs; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _categoria == 'Todos' ? _productos : _productos.where((p) => p.categoriaNombre == _categoria).toList();

    return _cargando
      ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.all(14), children: [
          // Filtros categoría
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _categorias.map((c) =>
            GestureDetector(onTap: () => setState(() => _categoria = c),
              child: Container(margin: const EdgeInsets.only(right: 6, bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: _categoria == c ? AppColors.azul : Colors.white, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _categoria == c ? AppColors.azul : AppColors.grisBorde)),
                child: Text(c, style: TextStyle(fontSize: 11, color: _categoria == c ? Colors.white : AppColors.textoSecundario))))).toList())),

          // Productos
          ...filtrados.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
            child: ListTile(
              title: Text(p.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text('SKU: ${p.sku ?? "—"} · Stock: ${p.stockDisponible}', style: const TextStyle(fontSize: 11)),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('\$${p.precioVenta.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.azul)),
                Text(p.categoriaNombre ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
              ]),
            ))),

          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.chat), label: const Text('Enviar catálogo por WhatsApp'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366))),
          const Divider(height: 20),

          // PDFs almacenados
          Text('PDFs almacenados'.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario, letterSpacing: 1)),
          const SizedBox(height: 8),
          ..._pdfs.map((pdf) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
            child: ListTile(
              leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.rojoClaro, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.picture_as_pdf, color: AppColors.rojo, size: 18)),
              title: Text(pdf.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text(pdf.tamanoTexto, style: const TextStyle(fontSize: 11)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 20), onPressed: () {}),
                IconButton(icon: const Icon(Icons.open_in_new, size: 18), onPressed: () {}),
              ]),
            ))),
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.upload_file), label: const Text('Subir nuevo PDF')),
          const SizedBox(height: 20),
        ]);
  }
}
