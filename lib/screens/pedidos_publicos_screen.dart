// lib/screens/pedidos_publicos_screen.dart
// HETNA CNC — Administrar pedidos que llegan de clientes (sin cuenta)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';

class PedidosPublicosScreen extends StatefulWidget {
  const PedidosPublicosScreen({super.key});
  @override
  State<PedidosPublicosScreen> createState() => _PedidosPublicosScreenState();
}

class _PedidosPublicosScreenState extends State<PedidosPublicosScreen> {
  List<Map<String, dynamic>> _pedidos = [];
  bool _cargando = true;
  String _filtro = 'nuevo';
  final _fmt = NumberFormat(r'$#,##0', 'es_MX');

  final _estados = ['nuevo', 'confirmado', 'pagado', 'convertido', 'rechazado'];
  final _etiquetas = {
    'nuevo': '🆕 Nuevos', 'confirmado': '✅ Confirmados',
    'pagado': '💰 Pagados', 'convertido': '🏭 En producción',
    'rechazado': '❌ Rechazados',
  };
  final _colores = {
    'nuevo': AppColors.rojo, 'confirmado': AppColors.azul,
    'pagado': AppColors.verde, 'convertido': const Color(0xFF7c3aed),
    'rechazado': AppColors.textoSecundario,
  };

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final negId = AuthService.negocioId;
      final data = await Supabase.instance.client
        .from('pedidos_publicos')
        .select()
        .eq('negocio_id', negId as Object)
        .order('created_at', ascending: false);
      if (mounted) setState(() {
        _pedidos = List<Map<String, dynamic>>.from(data);
        _cargando = false;
      });
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<Map<String, dynamic>> get _filtrados =>
    _pedidos.where((p) => p['estado'] == _filtro).toList();

  Future<void> _cambiarEstado(String id, String nuevoEstado) async {
    try {
      await Supabase.instance.client.from('pedidos_publicos')
        .update({'estado': nuevoEstado}).eq('id', id);
      _cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    }
  }

  // Convierte el pedido público en un cliente + cotización + pedido
  // real dentro del flujo normal de producción (Avances)
  Future<void> _convertirAProduccion(Map<String, dynamic> p) async {
    try {
      // 1. Buscar o crear el cliente por su WhatsApp
      final clientes = await SupabaseService.getClientes();
      Cliente cliente;
      final existentes = clientes.where((c) =>
        c.whatsapp == p['telefono_cliente'] || c.telefono == p['telefono_cliente']).toList();
      if (existentes.isNotEmpty) {
        cliente = existentes.first;
      } else {
        cliente = await SupabaseService.crearClienteRapidoWA(
          numero: p['telefono_cliente'], nombre: p['nombre_cliente']);
      }

      // 2. Armar los items de la cotización
      List<CotizacionItem> items = [];
      if (p['tipo'] == 'catalogo' && p['items'] != null) {
        for (final item in (p['items'] as List)) {
          items.add(CotizacionItem(
            nombreProducto: item['nombre'] ?? 'Producto',
            cantidad: (item['cantidad'] as num?)?.toInt() ?? 1,
            precioUnitario: (item['precio'] as num?)?.toDouble() ?? 0,
          ));
        }
      } else {
        items.add(CotizacionItem(
          nombreProducto: p['descripcion_personalizada'] ?? 'Pedido personalizado',
          cantidad: 1,
          precioUnitario: (p['monto_estimado'] as num?)?.toDouble() ?? 0,
        ));
      }

      // 3. Crear la cotización ya como Pedido (salta el borrador)
      final cot = Cotizacion(
        cliente: cliente, clienteId: cliente.id,
        items: items, estado: 'Pedido',
        notas: 'Pedido recibido desde el enlace público de clientes.',
        createdAt: DateTime.now());
      final cotGuardada = await SupabaseService.crearCotizacion(cot, items);
      await SupabaseService.convertirEnPedido(cotGuardada);

      // 4. Marcar el pedido público como convertido
      await _cambiarEstado(p['id'], 'convertido');

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Pedido enviado a producción — visible en Avances'),
        backgroundColor: AppColors.verde));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al convertir: $e'), backgroundColor: AppColors.rojo));
    }
  }

  Future<void> _abrirWhatsApp(String telefono) async {
    var n = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    if (n.length == 10) n = '521$n';
    await launchUrl(Uri.parse('https://wa.me/$n'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: const Text('Pedidos de clientes'),
        backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0),
      body: Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: _estados.map((e) {
              final count = _pedidos.where((p) => p['estado'] == e).length;
              final activo = _filtro == e;
              final color = _colores[e] ?? AppColors.azul;
              return GestureDetector(
                onTap: () => setState(() => _filtro = e),
                child: Container(margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: activo ? color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: activo ? color : AppColors.grisBorde)),
                  child: Text('${_etiquetas[e]} ($count)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: activo ? Colors.white : AppColors.textoSecundario))));
            }).toList()))),
        Expanded(child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _cargar, child: _filtrados.isEmpty
              ? ListView(children: const [
                  Padding(padding: EdgeInsets.all(40),
                    child: Center(child: Text('No hay pedidos en este estado',
                      style: TextStyle(color: AppColors.textoSecundario))))])
              : ListView.builder(padding: const EdgeInsets.all(12),
                  itemCount: _filtrados.length,
                  itemBuilder: (_, i) => _cardPedido(_filtrados[i])))),
      ]));
  }

  Widget _cardPedido(Map<String, dynamic> p) {
    final color = _colores[p['estado']] ?? AppColors.azul;
    final esCatalogo = p['tipo'] == 'catalogo';
    final fecha = DateTime.tryParse(p['created_at'] ?? '');
    final items = esCatalogo ? (p['items'] as List? ?? []) : [];

    return Container(margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4),
          top: const BorderSide(color: AppColors.grisBorde, width: 0.5),
          right: const BorderSide(color: AppColors.grisBorde, width: 0.5),
          bottom: const BorderSide(color: AppColors.grisBorde, width: 0.5))),
      child: Padding(padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['nombre_cliente'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              GestureDetector(
                onTap: () => _abrirWhatsApp(p['telefono_cliente'] ?? ''),
                child: Row(children: [
                  const Icon(Icons.chat, size: 12, color: AppColors.whatsapp),
                  const SizedBox(width: 4),
                  Text(p['telefono_cliente'] ?? '',
                    style: const TextStyle(fontSize: 11, color: AppColors.whatsapp)),
                ])),
            ])),
            if (fecha != null) Text(DateFormat('dd/MM HH:mm').format(fecha),
              style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          ]),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(8)),
            child: esCatalogo
              ? Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: items.map((it) => Text(
                    '• ${it['nombre']} x${it['cantidad']}',
                    style: const TextStyle(fontSize: 12))).toList())
              : Text(p['descripcion_personalizada'] ?? '',
                  style: const TextStyle(fontSize: 12))),
          if (p['monto_estimado'] != null) ...[
            const SizedBox(height: 6),
            Text('Estimado: ${_fmt.format(p['monto_estimado'])}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
          ],
          const SizedBox(height: 10),
          _botonesAccion(p),
        ])));
  }

  Widget _botonesAccion(Map<String, dynamic> p) {
    final estado = p['estado'];
    if (estado == 'convertido' || estado == 'rechazado') {
      return Text(estado == 'convertido' ? '✅ Ya está en producción' : '❌ Rechazado',
        style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario, fontStyle: FontStyle.italic));
    }
    return Wrap(spacing: 6, runSpacing: 6, children: [
      if (estado == 'nuevo')
        ElevatedButton(
          onPressed: () => _cambiarEstado(p['id'], 'confirmado'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          child: const Text('Confirmar', style: TextStyle(fontSize: 11, color: Colors.white))),
      if (estado == 'confirmado')
        ElevatedButton(
          onPressed: () => _cambiarEstado(p['id'], 'pagado'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          child: const Text('Marcar pagado', style: TextStyle(fontSize: 11, color: Colors.white))),
      if (estado == 'pagado' || estado == 'confirmado')
        ElevatedButton(
          onPressed: () => _convertirAProduccion(p),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7c3aed),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          child: const Text('→ Enviar a producción', style: TextStyle(fontSize: 11, color: Colors.white))),
      if (estado == 'nuevo')
        OutlinedButton(
          onPressed: () => _cambiarEstado(p['id'], 'rechazado'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.rojo,
            side: const BorderSide(color: AppColors.rojo),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          child: const Text('Rechazar', style: TextStyle(fontSize: 11))),
    ]);
  }
}
