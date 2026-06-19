import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';

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
    _tabs = TabController(length: 3, vsync: this);
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
          tabs: const [
            Tab(text: 'Nueva'),
            Tab(text: 'Mis cotizaciones'),
            Tab(text: 'Catálogo'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        const _NuevaCotizacion(),
        const _ListaCotizaciones(),
        const _CatalogoPDFs(),
      ]),
    );
  }
}

// ═══════════════════════════════════════════
// NUEVA COTIZACIÓN
// ═══════════════════════════════════════════
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
  bool _aplicaIva = true;
  double _costoEnvio = 0;
  String _metodoPago = '50% anticipo / 50% entrega';
  String _condicionEntrega = 'LAB — En planta HETNA';
  String _tiempoEntrega = '15 días';
  String _notas = '';
  bool _generando = false;
  bool _guardando = false;

  final _metodosPago = ['50% anticipo / 50% entrega', 'Pago total anticipado', 'Crédito 30 días', 'Crédito 60 días', 'Transferencia bancaria'];
  final _condiciones = ['LAB — En planta HETNA', 'Entrega en domicilio cliente', 'Flete por cuenta del cliente', 'Instalación incluida'];
  final _tiemposEntrega = ['3 días', '5 días', '7 días', '10 días', '15 días', '20 días', '30 días', 'A convenir'];

  double get _subtotal => _items.fold(0, (s, i) => s + i.subtotal);
  double get _montoDescuento => _subtotal * _descuentoPct / 100;
  double get _baseIva => _subtotal - _montoDescuento;
  double get _montoIva => _aplicaIva ? _baseIva * _ivaPct / 100 : 0;
  double get _total => _baseIva + _montoIva + _costoEnvio;
  bool get _puedeAccionar => _items.isNotEmpty && _clienteSeleccionado != null;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('\$#,##0.00', 'es_MX');
    return ListView(padding: const EdgeInsets.all(14), children: [

      // ─── Cliente ───
      _bloque('Cliente', Icons.person_outline,
        _clienteSeleccionado == null
          ? Column(children: [
              ElevatedButton.icon(
                onPressed: _seleccionarCliente,
                icon: const Icon(Icons.person_search),
                label: const Text('Seleccionar cliente existente')),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _nuevoClienteRapido,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Agregar nuevo cliente')),
            ])
          : ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: AppColors.azulClaro,
                child: Text(_clienteSeleccionado!.nombre[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700))),
              title: Text(_clienteSeleccionado!.nombreCompleto,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_clienteSeleccionado!.tipoCliente,
                  style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                if (_clienteSeleccionado!.whatsappNumero.isNotEmpty)
                  Text('WA: ${_clienteSeleccionado!.whatsappNumero}',
                    style: const TextStyle(fontSize: 11, color: AppColors.verde)),
              ]),
              trailing: TextButton(onPressed: _seleccionarCliente, child: const Text('Cambiar')))),

      // ─── Productos ───
      _bloque('Productos', Icons.inventory_2_outlined, Column(children: [
        if (_items.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Agrega productos a la cotización',
              style: TextStyle(color: AppColors.textoSecundario, fontSize: 12))),
        ..._items.map((item) => _ItemRow(
          key: ValueKey(item.productoId ?? item.nombreProducto),
          item: item,
          onEliminar: () => setState(() => _items.remove(item)),
          onCantidadChanged: (v) => setState(() => item.cantidad = v),
          onPrecioChanged: (v) => setState(() => item.precioUnitario = v),
        )),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ElevatedButton.icon(
            onPressed: _agregarProducto,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar producto'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: _productoNuevoRapido,
            icon: const Icon(Icons.add_box_outlined, size: 18),
            label: const Text('Producto nuevo'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)))),
        ]),
      ])),

      // ─── Condiciones ───
      _bloque('Condiciones de entrega', Icons.local_shipping_outlined, Column(children: [
        Row(children: [
          Expanded(child: _campoLabel('Tiempo de entrega', child: DropdownButtonFormField<String>(
            value: _tiempoEntrega,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: _tiemposEntrega.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _tiempoEntrega = v!)))),
          const SizedBox(width: 8),
          Expanded(child: _campoLabel('Condición', child: DropdownButtonFormField<String>(
            value: _condicionEntrega,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: _condiciones.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11)))).toList(),
            onChanged: (v) => setState(() => _condicionEntrega = v!)))),
        ]),
        const SizedBox(height: 8),
        _campoLabel('Método de pago', child: DropdownButtonFormField<String>(
          value: _metodoPago,
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          items: _metodosPago.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _metodoPago = v!))),
        const SizedBox(height: 8),
        _campoLabel('Notas y observaciones', child: TextField(
          decoration: const InputDecoration(
            hintText: 'Garantías, accesorios, condiciones especiales...',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          maxLines: 3, style: const TextStyle(fontSize: 13),
          onChanged: (v) => setState(() => _notas = v))),
      ])),

      // ─── Resumen financiero ───
      _bloque('Resumen financiero', Icons.calculate_outlined, Column(children: [
        Row(children: [
          Expanded(child: _campoLabel('Descuento %', child: TextField(
            decoration: const InputDecoration(hintText: '0', suffixText: '%',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13),
            onChanged: (v) => setState(() => _descuentoPct = double.tryParse(v) ?? 0)))),
          const SizedBox(width: 8),
          Expanded(child: _campoLabel('Costo envío', child: TextField(
            decoration: const InputDecoration(hintText: '0', prefixText: '\$',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13),
            onChanged: (v) => setState(() => _costoEnvio = double.tryParse(v) ?? 0)))),
        ]),
        const SizedBox(height: 8),
        // Switch IVA
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: _aplicaIva ? AppColors.verdeClaro : AppColors.gris,
            borderRadius: BorderRadius.circular(8), border: Border.all(color: _aplicaIva ? AppColors.verde : AppColors.grisBorde)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('IVA ${_ivaPct.toInt()}%', style: TextStyle(fontWeight: FontWeight.w600,
                color: _aplicaIva ? AppColors.verde : AppColors.textoSecundario)),
              Text(_aplicaIva ? 'Incluido en el total' : 'No aplica IVA',
                style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            ]),
            Switch(value: _aplicaIva, onChanged: (v) => setState(() => _aplicaIva = v),
              activeColor: AppColors.verde),
          ])),
        const SizedBox(height: 10),
        _filaTotal('Subtotal', fmt.format(_subtotal)),
        if (_descuentoPct > 0) _filaTotal('Descuento ${_descuentoPct.toInt()}%',
          '-${fmt.format(_montoDescuento)}', color: AppColors.verde),
        if (_costoEnvio > 0) _filaTotal('Envío', fmt.format(_costoEnvio)),
        if (_aplicaIva) _filaTotal('IVA ${_ivaPct.toInt()}%', fmt.format(_montoIva)),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
          Text(fmt.format(_total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
        ]),
      ])),

      const SizedBox(height: 8),

      // ─── Botones ───
      ElevatedButton.icon(
        onPressed: _puedeAccionar ? _generarPDF : null,
        icon: _generando
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.picture_as_pdf),
        label: const Text('Generar y ver PDF')),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: _puedeAccionar ? _enviarWA : null,
        icon: const Icon(Icons.chat),
        label: const Text('Enviar cotización por WhatsApp'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366))),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: _puedeAccionar ? _guardarBorrador : null,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar borrador'))),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton.icon(
          onPressed: _puedeAccionar && !_guardando ? _convertirPedido : null,
          icon: _guardando
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_circle_outline),
          label: const Text('→ PEDIDO'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde))),
      ]),
      const SizedBox(height: 20),
    ]);
  }

  Widget _bloque(String titulo, IconData icon, Widget contenido) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: AppColors.azul),
        const SizedBox(width: 6),
        Text(titulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.azul)),
      ]),
      const SizedBox(height: 10),
      contenido,
    ]));

  Widget _campoLabel(String label, {required Widget child}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      const SizedBox(height: 4),
      child,
    ]);

  Widget _filaTotal(String label, String valor, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
      Text(valor, style: TextStyle(fontSize: 12, color: color ?? Colors.black, fontWeight: FontWeight.w500)),
    ]));

  Future<void> _seleccionarCliente() async {
    final clientes = await SupabaseService.getClientes();
    if (!mounted) return;
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelectorCliente(
        clientes: clientes,
        onSeleccionado: (c) => setState(() => _clienteSeleccionado = c),
        onNuevoCliente: _nuevoClienteRapido,
      ));
  }

  Future<void> _nuevoClienteRapido() async {
    final nombreCtrl = TextEditingController();
    final waCtrl = TextEditingController();
    String tipo = 'Cliente potencial';
    showModalBottomSheet(context: context, isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setS) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Nuevo cliente rápido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre completo *',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
            const SizedBox(height: 8),
            TextField(controller: waCtrl, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'WhatsApp',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(value: tipo,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: ['Cliente potencial', 'Cliente activo', 'Cliente frecuente', 'Distribuidor']
                .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setS(() => tipo = v!)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () async {
              if (nombreCtrl.text.isEmpty) return;
              final c = await SupabaseService.crearCliente(Cliente(
                nombre: nombreCtrl.text.trim(),
                whatsapp: waCtrl.text.trim().isEmpty ? null : waCtrl.text.trim(),
                tipoCliente: tipo));
              if (mounted) { setState(() => _clienteSeleccionado = c); Navigator.pop(context); }
            }, child: const Text('Guardar cliente')),
          ])))));
  }

  Future<void> _agregarProducto() async {
    final productos = await SupabaseService.getProductos();
    if (!mounted) return;
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelectorProducto(
        productos: productos,
        onSeleccionado: (p) => setState(() => _items.add(CotizacionItem.fromProducto(p))),
      ));
  }

  Future<void> _productoNuevoRapido() async {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Producto / Servicio rápido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre del producto/servicio *',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
            const SizedBox(height: 8),
            TextField(controller: precioCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Precio \$', prefixText: '\$',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () async {
              if (nombreCtrl.text.isEmpty) return;
              final precio = double.tryParse(precioCtrl.text) ?? 0;
              final prod = await SupabaseService.crearProducto(Producto(
                nombre: nombreCtrl.text.trim(), precioVenta: precio, costo: 0,
                unidadMedida: 'Pieza', stockDisponible: 0));
              if (mounted) {
                setState(() => _items.add(CotizacionItem.fromProducto(prod)));
                Navigator.pop(context);
              }
            }, child: const Text('Agregar a cotización')),
          ]))));
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
        ivaPct: _aplicaIva ? _ivaPct : 0,
        costoEnvio: _costoEnvio,
        metodoPago: _metodoPago,
        condicionEntrega: _condicionEntrega,
        notas: _notas,
        createdAt: DateTime.now(),
      );
      final bytes = await PdfService.generarCotizacion(cotizacion: cot, empresa: cfg);
      await PdfService.verPdf(bytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error PDF: $e')));
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _enviarWA() async {
    if (_clienteSeleccionado == null || _items.isEmpty) return;
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final itemsTexto = _items.map((i) => '• ${i.nombreProducto} x${i.cantidad} = ${fmt.format(i.subtotal)}').join('\n');
    final ivaTexto = _aplicaIva ? '\nIVA ${_ivaPct.toInt()}%: ${fmt.format(_montoIva)}' : '';
    final mensaje = '¡Hola ${_clienteSeleccionado!.nombre}! 👋\n\nTe comparto tu cotización de *HETNA CNC*:\n\n$itemsTexto\n\nSubtotal: ${fmt.format(_subtotal)}$ivaTexto\n*TOTAL: ${fmt.format(_total)}*\n\nTiempo de entrega: $_tiempoEntrega\nMétodo de pago: $_metodoPago\n\n¿Te parece bien? Quedamos a tus órdenes 😊\n\n_HETNA CNC_';
    final numero = _clienteSeleccionado!.whatsappNumero.replaceAll(RegExp(r'[^0-9]'), '');
    final url = 'https://wa.me/52$numero?text=${Uri.encodeComponent(mensaje)}';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _guardarBorrador() async {
    if (_clienteSeleccionado == null || _items.isEmpty) return;
    try {
      final cot = Cotizacion(
        folio: 'COT-${DateTime.now().millisecondsSinceEpoch}',
        cliente: _clienteSeleccionado,
        clienteId: _clienteSeleccionado!.id,
        items: _items,
        descuentoPct: _descuentoPct,
        ivaPct: _aplicaIva ? _ivaPct : 0,
        costoEnvio: _costoEnvio,
        metodoPago: _metodoPago,
        condicionEntrega: _condicionEntrega,
        notas: _notas,
        estado: 'Borrador',
        createdAt: DateTime.now(),
      );
      await SupabaseService.crearCotizacion(cot, _items);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Borrador guardado'), backgroundColor: AppColors.azul));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _convertirPedido() async {
    if (_clienteSeleccionado == null || _items.isEmpty) return;
    setState(() => _guardando = true);
    try {
      final cot = Cotizacion(
        folio: 'COT-${DateTime.now().millisecondsSinceEpoch}',
        cliente: _clienteSeleccionado,
        clienteId: _clienteSeleccionado!.id,
        items: _items,
        descuentoPct: _descuentoPct,
        ivaPct: _aplicaIva ? _ivaPct : 0,
        costoEnvio: _costoEnvio,
        metodoPago: _metodoPago,
        condicionEntrega: _condicionEntrega,
        notas: _notas,
        estado: 'Pedido',
        createdAt: DateTime.now(),
      );
      final cotGuardada = await SupabaseService.crearCotizacion(cot, _items);
      await SupabaseService.convertirEnPedido(cotGuardada);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ ¡Pedido creado! Visible en Avances'),
          backgroundColor: AppColors.verde));
        setState(() { _items = []; _clienteSeleccionado = null; _notas = ''; _descuentoPct = 0; _costoEnvio = 0; });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

// ═══════════════════════════════════════════
// SELECTOR DE CLIENTE CON BÚSQUEDA
// ═══════════════════════════════════════════
class _SelectorCliente extends StatefulWidget {
  final List<Cliente> clientes;
  final ValueChanged<Cliente> onSeleccionado;
  final VoidCallback onNuevoCliente;
  const _SelectorCliente({required this.clientes, required this.onSeleccionado, required this.onNuevoCliente});
  @override
  State<_SelectorCliente> createState() => _SelectorClienteState();
}

class _SelectorClienteState extends State<_SelectorCliente> {
  String _busqueda = '';
  String _filtroTipo = 'Todos';
  final _tipos = ['Todos', 'Cliente activo', 'Cliente frecuente', 'Cliente potencial', 'Distribuidor'];

  List<Cliente> get _filtrados => widget.clientes.where((c) {
    final b = _busqueda.toLowerCase();
    final matchBusq = _busqueda.isEmpty ||
      c.nombre.toLowerCase().contains(b) ||
      (c.empresa?.toLowerCase().contains(b) ?? false) ||
      (c.whatsapp?.contains(b) ?? false) ||
      (c.telefono?.contains(b) ?? false);
    final matchTipo = _filtroTipo == 'Todos' || c.tipoCliente == _filtroTipo;
    return matchBusq && matchTipo;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(12), child: Column(children: [
          const Text('Seleccionar cliente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, empresa, WhatsApp...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true, fillColor: AppColors.gris,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12)),
            onChanged: (v) => setState(() => _busqueda = v)),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:
            _tipos.map((t) => GestureDetector(
              onTap: () => setState(() => _filtroTipo = t),
              child: Container(margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _filtroTipo == t ? AppColors.azul : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _filtroTipo == t ? AppColors.azul : AppColors.grisBorde)),
                child: Text(t, style: TextStyle(fontSize: 10,
                  color: _filtroTipo == t ? Colors.white : AppColors.textoSecundario))))).toList())),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () { Navigator.pop(context); widget.onNuevoCliente(); },
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('Agregar nuevo cliente', style: TextStyle(fontSize: 13))),
        ])),
        Expanded(child: _filtrados.isEmpty
          ? const Center(child: Text('No se encontraron clientes', style: TextStyle(color: AppColors.textoSecundario)))
          : ListView.builder(
              itemCount: _filtrados.length,
              itemBuilder: (_, i) {
                final c = _filtrados[i];
                final colores = {'Cliente potencial': AppColors.ambar, 'Cliente activo': AppColors.verde,
                  'Cliente frecuente': AppColors.azul, 'Distribuidor': const Color(0xFF7c3aed)};
                final color = colores[c.tipoCliente] ?? Colors.grey;
                return ListTile(
                  leading: CircleAvatar(backgroundColor: color.withOpacity(0.1),
                    child: Text(c.nombre[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w700))),
                  title: Text(c.nombreCompleto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: Text('${c.tipoCliente}${c.ciudad != null ? " · ${c.ciudad}" : ""}',
                    style: const TextStyle(fontSize: 11)),
                  trailing: c.whatsappNumero.isNotEmpty
                    ? const Icon(Icons.chat, color: Color(0xFF25D366), size: 16) : null,
                  onTap: () { widget.onSeleccionado(c); Navigator.pop(context); });
              })),
      ]));
  }
}

// ═══════════════════════════════════════════
// SELECTOR DE PRODUCTO
// ═══════════════════════════════════════════
class _SelectorProducto extends StatefulWidget {
  final List<Producto> productos;
  final ValueChanged<Producto> onSeleccionado;
  const _SelectorProducto({required this.productos, required this.onSeleccionado});
  @override
  State<_SelectorProducto> createState() => _SelectorProductoState();
}

class _SelectorProductoState extends State<_SelectorProducto> {
  String _busqueda = '';

  List<Producto> get _filtrados => _busqueda.isEmpty ? widget.productos
    : widget.productos.where((p) => p.nombre.toLowerCase().contains(_busqueda.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          const Text('Seleccionar producto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true, fillColor: AppColors.gris,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
            onChanged: (v) => setState(() => _busqueda = v)),
        ])),
        Expanded(child: ListView.builder(
          itemCount: _filtrados.length,
          itemBuilder: (_, i) {
            final p = _filtrados[i];
            return ListTile(
              title: Text(p.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text(p.categoriaNombre ?? '', style: const TextStyle(fontSize: 11)),
              trailing: Text('\$${p.precioVenta.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.azul, fontSize: 14)),
              onTap: () { widget.onSeleccionado(p); Navigator.pop(context); });
          })),
      ]));
  }
}

// ═══════════════════════════════════════════
// ITEM ROW CON PRECIO EDITABLE
// ═══════════════════════════════════════════
class _ItemRow extends StatelessWidget {
  final CotizacionItem item;
  final VoidCallback onEliminar;
  final ValueChanged<int> onCantidadChanged;
  final ValueChanged<double> onPrecioChanged;
  const _ItemRow({super.key, required this.item, required this.onEliminar, required this.onCantidadChanged, required this.onPrecioChanged});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('\$#,##0.00', 'es_MX');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(item.nombreProducto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          IconButton(icon: const Icon(Icons.close, size: 16, color: AppColors.rojo), padding: EdgeInsets.zero, onPressed: onEliminar),
        ]),
        Row(children: [
          // Precio editable
          Expanded(child: TextFormField(
            initialValue: item.precioUnitario.toStringAsFixed(0),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(prefixText: '\$', labelText: 'Precio', isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => onPrecioChanged(double.tryParse(v) ?? item.precioUnitario))),
          const SizedBox(width: 12),
          // Cantidad
          Row(children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), padding: EdgeInsets.zero,
              onPressed: item.cantidad > 1 ? () => onCantidadChanged(item.cantidad - 1) : null),
            Text('${item.cantidad}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), padding: EdgeInsets.zero,
              onPressed: () => onCantidadChanged(item.cantidad + 1)),
          ]),
          const SizedBox(width: 8),
          Text(fmt.format(item.subtotal),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
        ]),
      ]));
  }
}

// ═══════════════════════════════════════════
// LISTA DE COTIZACIONES
// ═══════════════════════════════════════════
class _ListaCotizaciones extends StatefulWidget {
  const _ListaCotizaciones();
  @override
  State<_ListaCotizaciones> createState() => _ListaCotizacionesState();
}

class _ListaCotizacionesState extends State<_ListaCotizaciones> {
  List<Cotizacion> _cotizaciones = [];
  bool _cargando = true;
  String _filtroEstado = 'Todos';
  final _estados = ['Todos', 'Borrador', 'Enviada', 'Aprobada', 'Pedido', 'Vencida', 'Rechazada'];

  final _coloresEstado = {
    'Borrador': Colors.grey, 'Enviada': Color(0xFF185fa5),
    'Aprobada': Color(0xFF1d9e75), 'Pedido': Color(0xFF7c3aed),
    'Vencida': Color(0xFFef9f27), 'Rechazada': Color(0xFFe24b4a),
  };

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final cots = await SupabaseService.getCotizaciones();
      if (mounted) setState(() { _cotizaciones = cots; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  List<Cotizacion> get _filtradas => _filtroEstado == 'Todos'
    ? _cotizaciones
    : _cotizaciones.where((c) => c.estado == _filtroEstado).toList();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.all(12), child:
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:
          _estados.map((e) {
            final color = _coloresEstado[e] ?? AppColors.azul;
            return GestureDetector(
              onTap: () => setState(() => _filtroEstado = e),
              child: Container(margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _filtroEstado == e ? (e == 'Todos' ? AppColors.azul : color) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _filtroEstado == e ? (e == 'Todos' ? AppColors.azul : color) : AppColors.grisBorde)),
                child: Text(e, style: TextStyle(fontSize: 11,
                  color: _filtroEstado == e ? Colors.white : AppColors.textoSecundario))));
          }).toList()))),
      Expanded(child: _cargando
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _cargar, child: _filtradas.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.description_outlined, size: 48, color: AppColors.textoSecundario),
                const SizedBox(height: 8),
                Text(_filtroEstado == 'Todos' ? 'No hay cotizaciones aún' : 'No hay cotizaciones en estado "$_filtroEstado"',
                  style: const TextStyle(color: AppColors.textoSecundario)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _filtradas.length,
                itemBuilder: (_, i) => _TarjetaCotizacion(
                  cotizacion: _filtradas[i],
                  coloresEstado: _coloresEstado,
                  onActualizar: _cargar,
                )))),
    ]);
  }
}

class _TarjetaCotizacion extends StatelessWidget {
  final Cotizacion cotizacion;
  final Map<String, Color> coloresEstado;
  final VoidCallback onActualizar;
  const _TarjetaCotizacion({required this.cotizacion, required this.coloresEstado, required this.onActualizar});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final color = coloresEstado[cotizacion.estado] ?? Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1)),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cotizacion.cliente?.nombre ?? cotizacion.clienteId ?? 'Sin cliente',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            if (cotizacion.cliente?.empresa != null)
              Text(cotizacion.cliente!.empresa!, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            Text(cotizacion.folio ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(cotizacion.estado, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))),
            const SizedBox(height: 4),
            Text(fmt.format(cotizacion.total),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.azul)),
          ]),
        ]),
        const SizedBox(height: 8),
        if (cotizacion.createdAt != null)
          Text('Creada: ${DateFormat('dd/MM/yyyy').format(cotizacion.createdAt!)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        const SizedBox(height: 8),
        // Cambiar estado
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          const Text('Estado: ', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          ...['Borrador', 'Enviada', 'Aprobada', 'Pedido'].map((e) {
            final c = coloresEstado[e] ?? Colors.grey;
            final esActual = cotizacion.estado == e;
            return GestureDetector(
              onTap: esActual ? null : () => _cambiarEstado(context, e),
              child: Container(margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: esActual ? c : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c)),
                child: Text(e, style: TextStyle(fontSize: 10,
                  color: esActual ? Colors.white : c, fontWeight: FontWeight.w500))));
          }),
          if (cotizacion.estado != 'Pedido')
            GestureDetector(
              onTap: () => _convertirAPedido(context),
              child: Container(margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.verde, borderRadius: BorderRadius.circular(12)),
                child: const Text('→ Pedido', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)))),
        ])),
      ]));
  }

  Future<void> _cambiarEstado(BuildContext context, String nuevoEstado) async {
    try {
      await SupabaseService.cambiarEstadoCotizacion(cotizacion.id!, nuevoEstado);
      onActualizar();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado cambiado a $nuevoEstado'), backgroundColor: AppColors.azul));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _convertirAPedido(BuildContext context) async {
    try {
      await SupabaseService.convertirEnPedido(cotizacion);
      onActualizar();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Pedido creado — visible en Avances'), backgroundColor: AppColors.verde));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

// ═══════════════════════════════════════════
// CATÁLOGO Y PDFs
// ═══════════════════════════════════════════
class _CatalogoPDFs extends StatefulWidget {
  const _CatalogoPDFs();
  @override
  State<_CatalogoPDFs> createState() => _CatalogoPDFsState();
}

class _CatalogoPDFsState extends State<_CatalogoPDFs> {
  List<Producto> _productos = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    try {
      final prods = await SupabaseService.getProductos();
      if (mounted) setState(() { _productos = prods; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  @override
  Widget build(BuildContext context) {
    return _cargando ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.all(14), children: [
          ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.chat),
            label: const Text('Enviar catálogo por WhatsApp'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366))),
          const SizedBox(height: 12),
          ..._productos.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.grisBorde, width: 0.5)),
            child: ListTile(
              title: Text(p.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text('SKU: ${p.sku ?? "—"}', style: const TextStyle(fontSize: 11)),
              trailing: Text('\$${p.precioVenta.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.azul))))),
          const SizedBox(height: 20),
        ]);
  }
}
