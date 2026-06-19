import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class AvancesScreen extends StatefulWidget {
  const AvancesScreen({super.key});
  @override
  State<AvancesScreen> createState() => _AvancesScreenState();
}

class _AvancesScreenState extends State<AvancesScreen> {
  List<Pedido> _pedidos = [];
  bool _cargando = true;
  String _filtroEstado = 'Activos';

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final pedidos = await SupabaseService.getPedidos();
      if (mounted) setState(() { _pedidos = pedidos; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  List<Pedido> get _filtrados {
    switch (_filtroEstado) {
      case 'Activos': return _pedidos.where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado').toList();
      case 'Entregados': return _pedidos.where((p) => p.estado == 'Entregado').toList();
      default: return _pedidos;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: const Text('Avances de pedidos'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)],
      ),
      body: Column(children: [
        // Filtros
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: ['Activos', 'Todos', 'Entregados'].map((f) => GestureDetector(
            onTap: () => setState(() => _filtroEstado = f),
            child: Container(margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _filtroEstado == f ? AppColors.azul : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _filtroEstado == f ? AppColors.azul : AppColors.grisBorde)),
              child: Text(f, style: TextStyle(fontSize: 12,
                color: _filtroEstado == f ? Colors.white : AppColors.textoSecundario))))).toList())),
        Expanded(child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _cargar, child: _filtrados.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.local_shipping_outlined, size: 56, color: AppColors.textoSecundario),
                  const SizedBox(height: 12),
                  const Text('No hay pedidos', style: TextStyle(color: AppColors.textoSecundario, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Los pedidos aparecen aquí cuando\nconviertes una cotización en pedido',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtrados.length,
                  itemBuilder: (_, i) => _TarjetaPedido(
                    pedido: _filtrados[i],
                    onActualizar: _cargar,
                  )))),
      ]),
    );
  }
}

class _TarjetaPedido extends StatefulWidget {
  final Pedido pedido;
  final VoidCallback onActualizar;
  const _TarjetaPedido({required this.pedido, required this.onActualizar});
  @override
  State<_TarjetaPedido> createState() => _TarjetaPedidoState();
}

class _TarjetaPedidoState extends State<_TarjetaPedido> {
  bool _enviandoNotif = false;

  // Etapas en orden
  static const _etapas = ['Pedido', 'Pago', 'Produccion', 'Pruebas', 'Entrega', 'Entregado'];
  static const _etiquetas = ['Pedido', 'Pago recibido', 'En producción', 'Control calidad', 'Listo entrega', 'Entregado ✅'];

  // Mensaje WA por etapa
  static String _mensajeEtapa(String nombreCliente, String folio, String etapa) {
    switch (etapa) {
      case 'Pago': return '¡Hola $nombreCliente! ✅ Confirmamos recepción de tu pago para el pedido $folio. ¡Ya empezamos a trabajar en él! — HETNA CNC';
      case 'Produccion': return '¡Hola $nombreCliente! 🔧 Tu pedido $folio está en producción. Te avisamos cuando esté listo. — HETNA CNC';
      case 'Pruebas': return '¡Hola $nombreCliente! 🔍 Tu pedido $folio está en control de calidad. Casi listo! — HETNA CNC';
      case 'Entrega': return '¡Hola $nombreCliente! 📦 Tu pedido $folio está LISTO para entrega. ¿Cuándo podemos coordinar? — HETNA CNC';
      case 'Entregado': return '¡Hola $nombreCliente! 🎉 Tu pedido $folio fue entregado. ¡Esperamos que estés muy satisfecho! Si necesitas algo más, con gusto te atendemos. — HETNA CNC';
      default: return '¡Hola $nombreCliente! Tu pedido $folio está en proceso. — HETNA CNC';
    }
  }

  int get _idxActual => _etapas.indexOf(widget.pedido.estado).clamp(0, _etapas.length - 1);
  double get _progreso => (_idxActual + 1) / _etapas.length;
  bool get _esEntregado => widget.pedido.estado == 'Entregado';

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final diasRestantes = widget.pedido.fechaEntregaEstimada != null
      ? widget.pedido.fechaEntregaEstimada!.difference(DateTime.now()).inDays : null;
    final urgente = diasRestantes != null && diasRestantes <= 2 && !_esEntregado;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgente ? AppColors.rojo.withOpacity(0.4) : AppColors.grisBorde, width: urgente ? 1.5 : 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ─── Header ───
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.pedido.folio, style: const TextStyle(fontSize: 11, color: AppColors.azul, fontWeight: FontWeight.w600)),
            Text(widget.pedido.cliente?.nombre ?? 'Sin cliente',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (widget.pedido.cliente?.empresa != null)
              Text(widget.pedido.cliente!.empresa!, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (widget.pedido.total != null)
              Text(fmt.format(widget.pedido.total!),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.azul)),
            if (diasRestantes != null && !_esEntregado)
              Container(margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: urgente ? AppColors.rojoClaro : AppColors.ambarClaro,
                  borderRadius: BorderRadius.circular(20)),
                child: Text(diasRestantes <= 0 ? '⚠ Vencido' : '$diasRestantes días',
                  style: TextStyle(fontSize: 10, color: urgente ? AppColors.rojo : AppColors.ambar, fontWeight: FontWeight.w600))),
          ]),
        ]),

        const SizedBox(height: 12),

        // ─── Barra de progreso ───
        ClipRRect(borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progreso, backgroundColor: AppColors.gris, minHeight: 8,
            valueColor: AlwaysStoppedAnimation(_esEntregado ? AppColors.verde : AppColors.azul))),
        const SizedBox(height: 6),

        // Etiquetas de progreso
        Row(children: List.generate(_etapas.length, (i) {
          final activa = i <= _idxActual;
          final esActual = i == _idxActual;
          return Expanded(child: Text(_etiquetas[i],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 7,
              color: esActual ? AppColors.azul : (activa ? AppColors.verde : AppColors.textoSecundario),
              fontWeight: esActual ? FontWeight.w700 : FontWeight.normal)));
        })),

        const SizedBox(height: 12),

        // ─── Botones de etapa ───
        if (!_esEntregado) ...[
          const Text('Cambiar etapa:', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          const SizedBox(height: 6),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:
            _etapas.map((e) {
              final esActual = e == widget.pedido.estado;
              final idx = _etapas.indexOf(e);
              final esSiguiente = idx == _idxActual + 1;
              return GestureDetector(
                onTap: (esActual || idx > _idxActual + 1) ? null : () => _cambiarEtapa(e),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: esActual ? AppColors.azul : (esSiguiente ? AppColors.azulClaro : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: esActual ? AppColors.azul : (esSiguiente ? AppColors.azul : AppColors.grisBorde))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (esSiguiente) const Icon(Icons.arrow_forward, size: 10, color: AppColors.azul),
                    if (esSiguiente) const SizedBox(width: 3),
                    Text(e == 'Produccion' ? 'Producción' : e,
                      style: TextStyle(fontSize: 10,
                        color: esActual ? Colors.white : (esSiguiente ? AppColors.azul : AppColors.textoSecundario),
                        fontWeight: (esActual || esSiguiente) ? FontWeight.w600 : FontWeight.normal)),
                  ])));
            }).toList())),
        ],

        const SizedBox(height: 10),

        // ─── Acciones ───
        Row(children: [
          if (widget.pedido.cliente?.whatsappNumero.isNotEmpty ?? false) ...[
            Expanded(child: ElevatedButton.icon(
              onPressed: _enviandoNotif ? null : _notificarCliente,
              icon: _enviandoNotif
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.chat, size: 16),
              label: Text(_enviandoNotif ? 'Abriendo...' : 'Notificar cliente', style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                padding: const EdgeInsets.symmetric(vertical: 8)))),
            const SizedBox(width: 8),
          ],
          if (!_esEntregado)
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _cambiarEtapa('Entregado'),
              icon: const Icon(Icons.check_circle, size: 16),
              label: const Text('Marcar entregado', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verde,
                padding: const EdgeInsets.symmetric(vertical: 8)))),
          if (_esEntregado)
            const Expanded(child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle, color: AppColors.verde, size: 18),
              SizedBox(width: 6),
              Text('Pedido entregado', style: TextStyle(color: AppColors.verde, fontWeight: FontWeight.w600)),
            ]))),
        ]),
      ]),
    );
  }

  Future<void> _cambiarEtapa(String nuevaEtapa) async {
    try {
      await SupabaseService.actualizarEtapaPedido(widget.pedido.id!, nuevaEtapa);
      widget.onActualizar();
      if (mounted && (widget.pedido.cliente?.whatsappNumero.isNotEmpty ?? false)) {
        // Preguntar si notificar
        showDialog(context: context, builder: (_) => AlertDialog(
          title: Text('Etapa: $nuevaEtapa'),
          content: Text('¿Notificar a ${widget.pedido.cliente?.nombre} por WhatsApp?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('No por ahora')),
            ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); _notificarCliente(); },
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('Sí, notificar'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366))),
          ]));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _notificarCliente() async {
    setState(() => _enviandoNotif = true);
    try {
      final nombre = widget.pedido.cliente?.nombre ?? 'Cliente';
      final folio = widget.pedido.folio;
      final mensaje = _mensajeEtapa(nombre, folio, widget.pedido.estado);
      final numero = (widget.pedido.cliente?.whatsappNumero ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      final url = 'https://wa.me/52$numero?text=${Uri.encodeComponent(mensaje)}';
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error WA: $e')));
    } finally {
      if (mounted) setState(() => _enviandoNotif = false);
    }
  }
}
