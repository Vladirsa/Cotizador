// lib/screens/pedido_publico_screen.dart
// HETNA CNC — Pantalla pública: clientes hacen pedidos sin cuenta
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class PedidoPublicoScreen extends StatefulWidget {
  final String slug;
  const PedidoPublicoScreen({super.key, required this.slug});
  @override
  State<PedidoPublicoScreen> createState() => _PedidoPublicoScreenState();
}

class _PedidoPublicoScreenState extends State<PedidoPublicoScreen> {
  bool _cargando = true;
  bool _enviando = false;
  bool _enviado = false;
  String? _error;
  Map<String, dynamic>? _negocio;
  List<Map<String, dynamic>> _productos = [];
  final Map<String, int> _carrito = {};

  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  bool _esPedidoPersonalizado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final sb = Supabase.instance.client;
      final negocioData = await sb.rpc('negocio_publico_por_slug',
        params: {'p_slug': widget.slug});

      if (negocioData == null) {
        setState(() { _error = 'No encontramos este taller.'; _cargando = false; });
        return;
      }

      final productos = await sb.from('productos')
        .select()
        .eq('negocio_id', negocioData['id'])
        .eq('activo', true)
        .order('nombre');

      setState(() {
        _negocio = negocioData;
        _productos = List<Map<String, dynamic>>.from(productos);
        _cargando = false;
      });
    } catch (e) {
      setState(() { _error = 'Error al cargar: $e'; _cargando = false; });
    }
  }

  double get _totalCarrito {
    double total = 0;
    for (final p in _productos) {
      final cant = _carrito[p['id']] ?? 0;
      total += cant * (p['precio_venta'] as num? ?? 0);
    }
    return total;
  }

  int get _totalPiezas => _carrito.values.fold(0, (s, c) => s + c);

  Future<void> _enviarPedido() async {
    if (_nombreCtrl.text.trim().isEmpty || _telefonoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Escribe tu nombre y teléfono'), backgroundColor: AppColors.rojo));
      return;
    }
    if (_esPedidoPersonalizado && _descripcionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Describe lo que necesitas'), backgroundColor: AppColors.rojo));
      return;
    }
    if (!_esPedidoPersonalizado && _carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Agrega al menos un producto'), backgroundColor: AppColors.rojo));
      return;
    }

    setState(() => _enviando = true);
    try {
      final sb = Supabase.instance.client;
      final items = _esPedidoPersonalizado ? null : _productos
        .where((p) => (_carrito[p['id']] ?? 0) > 0)
        .map((p) => {
          'producto_id': p['id'],
          'nombre': p['nombre'],
          'cantidad': _carrito[p['id']],
          'precio': p['precio_venta'],
        }).toList();

      final res = await sb.from('pedidos_publicos').insert({
        'negocio_id': _negocio!['id'],
        'nombre_cliente': _nombreCtrl.text.trim(),
        'telefono_cliente': _telefonoCtrl.text.trim(),
        'correo_cliente': _correoCtrl.text.trim().isEmpty ? null : _correoCtrl.text.trim(),
        'tipo': _esPedidoPersonalizado ? 'personalizado' : 'catalogo',
        'items': items,
        'descripcion_personalizada': _esPedidoPersonalizado ? _descripcionCtrl.text.trim() : null,
        'monto_estimado': _esPedidoPersonalizado ? null : _totalCarrito,
      }).select().single();

      try {
        await sb.rpc('notificar_nuevo_pedido_publico', params: {'p_pedido_id': res['id']});
      } catch (_) {}

      setState(() { _enviado = true; _enviando = false; });
    } catch (e) {
      setState(() => _enviando = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al enviar: $e'), backgroundColor: AppColors.rojo));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_error!, textAlign: TextAlign.center))));
    }
    if (_enviado) {
      return Scaffold(
        backgroundColor: AppColors.gris,
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle, color: AppColors.verde, size: 64),
            const SizedBox(height: 16),
            const Text('¡Pedido enviado!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('${_negocio?['nombre'] ?? 'El taller'} se pondrá en contacto contigo pronto.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
          ]))));
    }

    final colorMarca = _negocio?['color_primario'] != null
      ? Color(int.parse((_negocio!['color_primario'] as String).replaceFirst('#', '0xFF')))
      : AppColors.azul;

    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: Text(_negocio?['nombre'] ?? 'Hacer pedido'),
        backgroundColor: colorMarca, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.grisBorde)),
          child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _esPedidoPersonalizado = false),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_esPedidoPersonalizado ? colorMarca : Colors.transparent,
                  borderRadius: BorderRadius.circular(8)),
                child: Text('Del catálogo', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: !_esPedidoPersonalizado ? Colors.white : AppColors.textoPrincipal))))),
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _esPedidoPersonalizado = true),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _esPedidoPersonalizado ? colorMarca : Colors.transparent,
                  borderRadius: BorderRadius.circular(8)),
                child: Text('Pedido especial', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: _esPedidoPersonalizado ? Colors.white : AppColors.textoPrincipal))))),
          ])),
        const SizedBox(height: 16),

        if (!_esPedidoPersonalizado) ...[
          if (_productos.isEmpty)
            const Padding(padding: EdgeInsets.all(20),
              child: Text('Este taller aún no tiene productos en su catálogo.',
                style: TextStyle(color: AppColors.textoSecundario))),
          ..._productos.map((p) {
            final cant = _carrito[p['id']] ?? 0;
            return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.grisBorde, width: 0.5)),
              child: Row(children: [
                Container(width: 48, height: 48, margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(8)),
                  child: (p['imagen_url'] != null && (p['imagen_url'] as String).isNotEmpty)
                    ? ClipRRect(borderRadius: BorderRadius.circular(8),
                        child: Image.network(p['imagen_url'], fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined,
                            color: AppColors.textoSecundario, size: 20)))
                    : const Icon(Icons.inventory_2_outlined, color: AppColors.textoSecundario, size: 20)),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['nombre'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('\$${(p['precio_venta'] as num? ?? 0).toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 13, color: colorMarca, fontWeight: FontWeight.w700)),
                ])),
                IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppColors.rojo),
                  onPressed: cant > 0 ? () => setState(() => _carrito[p['id']] = cant - 1) : null),
                Text('$cant', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                IconButton(icon: Icon(Icons.add_circle_outline, color: colorMarca),
                  onPressed: () => setState(() => _carrito[p['id']] = cant + 1)),
              ]));
          }),
          if (_totalPiezas > 0) ...[
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: colorMarca.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('$_totalPiezas producto${_totalPiezas > 1 ? "s" : ""}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('\$${_totalCarrito.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colorMarca)),
              ])),
          ],
        ] else ...[
          TextField(controller: _descripcionCtrl, maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Describe lo que necesitas',
              hintText: 'Ej: Necesito 10 letreros de madera de 30x20cm con mi logo...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true, fillColor: Colors.white)),
        ],

        const SizedBox(height: 20),
        const Text('Tus datos de contacto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(controller: _nombreCtrl,
          decoration: InputDecoration(labelText: 'Nombre completo *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true, fillColor: Colors.white)),
        const SizedBox(height: 10),
        TextField(controller: _telefonoCtrl, keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: 'WhatsApp / Teléfono *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true, fillColor: Colors.white)),
        const SizedBox(height: 10),
        TextField(controller: _correoCtrl, keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: 'Correo (opcional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true, fillColor: Colors.white)),

        const SizedBox(height: 24),
        SizedBox(height: 50, child: ElevatedButton(
          onPressed: _enviando ? null : _enviarPedido,
          style: ElevatedButton.styleFrom(backgroundColor: colorMarca,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _enviando
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Enviar pedido',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)))),
        const SizedBox(height: 30),
      ]));
  }
}
