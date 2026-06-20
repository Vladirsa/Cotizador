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
  String _filtro = 'Activos';

  static const _etapas = ['Activos', 'Pedido', 'Pago', 'Produccion', 'Pruebas', 'Entrega', 'Entregado', 'Todos'];
  static const _etiquetas = {'Produccion': 'Producción'};

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final pedidos = await SupabaseService.getPedidos();
      if (mounted) setState(() { _pedidos = pedidos; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<Pedido> get _filtrados {
    switch (_filtro) {
      case 'Activos': return _pedidos.where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado').toList();
      case 'Todos': return _pedidos;
      default: return _pedidos.where((p) => p.estado == _filtro).toList();
    }
  }

  int _countFiltro(String f) {
    if (f == 'Activos') return _pedidos.where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado').length;
    if (f == 'Todos') return _pedidos.length;
    return _pedidos.where((p) => p.estado == f).length;
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
        // ─── Filtros por etapa ───
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: _etapas.map((f) {
              final label = _etiquetas[f] ?? f;
              final count = _countFiltro(f);
              final activo = _filtro == f;
              Color color;
              switch (f) {
                case 'Activos': color = AppColors.azul; break;
                case 'Pedido': color = AppColors.azul; break;
                case 'Pago': color = AppColors.ambar; break;
                case 'Produccion': color = const Color(0xFF7c3aed); break;
                case 'Pruebas': color = AppColors.rojo; break;
                case 'Entrega': color = AppColors.verde; break;
                case 'Entregado': color = AppColors.verde; break;
                default: color = Colors.grey;
              }
              return GestureDetector(
                onTap: () => setState(() => _filtro = f),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: activo ? color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: activo ? color : AppColors.grisBorde)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(label, style: TextStyle(fontSize: 11,
                      color: activo ? Colors.white : AppColors.textoSecundario,
                      fontWeight: activo ? FontWeight.w700 : FontWeight.normal)),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: activo ? Colors.white.withOpacity(0.3) : color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                        child: Text('$count', style: TextStyle(fontSize: 9,
                          color: activo ? Colors.white : color, fontWeight: FontWeight.w700))),
                    ],
                  ])));
            }).toList()))),

        // ─── Lista de pedidos ───
        Expanded(child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _cargar, child: _filtrados.isEmpty
              ? _pantallaVacia()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtrados.length,
                  itemBuilder: (_, i) => _TarjetaPedido(
                    pedido: _filtrados[i],
                    onActualizar: _cargar)))),
      ]),
    );
  }

  Widget _pantallaVacia() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.local_shipping_outlined, size: 56, color: AppColors.textoSecundario),
    const SizedBox(height: 12),
    Text(_filtro == 'Activos' ? 'No hay pedidos activos' : 'No hay pedidos en esta etapa',
      style: const TextStyle(color: AppColors.textoSecundario, fontSize: 16)),
    const SizedBox(height: 8),
    const Text('Convierte una cotización en pedido\ndesde la pantalla Cotizar.',
      textAlign: TextAlign.center, style: TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
  ]));
}

// ═══════════════════════════════════════════
// TARJETA DE PEDIDO
// ═══════════════════════════════════════════
class _TarjetaPedido extends StatefulWidget {
  final Pedido pedido;
  final VoidCallback onActualizar;
  const _TarjetaPedido({required this.pedido, required this.onActualizar});
  @override
  State<_TarjetaPedido> createState() => _TarjetaPedidoState();
}

class _TarjetaPedidoState extends State<_TarjetaPedido> {
  bool _enviandoWA = false;
  bool _cambiando = false;

  static const _etapas = ['Pedido', 'Pago', 'Produccion', 'Pruebas', 'Entrega', 'Entregado'];
  static const _etiquetasEtapa = {
    'Pedido': 'Pedido recibido',
    'Pago': 'Pago confirmado',
    'Produccion': 'En producción',
    'Pruebas': 'Control de calidad',
    'Entrega': 'Listo para entrega',
    'Entregado': 'Entregado ✅',
  };

  static const _coloresEtapa = {
    'Pedido': AppColors.azul,
    'Pago': AppColors.ambar,
    'Produccion': Color(0xFF7c3aed),
    'Pruebas': AppColors.rojo,
    'Entrega': AppColors.verde,
    'Entregado': AppColors.verde,
  };

  int get _idx => _etapas.indexOf(widget.pedido.estado).clamp(0, _etapas.length - 1);
  double get _progreso => (_idx + 1) / _etapas.length;
  bool get _esEntregado => widget.pedido.estado == 'Entregado';
  Color get _colorActual => _coloresEtapa[widget.pedido.estado] ?? AppColors.azul;

  String _mensajeWA(String etapa) {
    final nombre = widget.pedido.cliente?.nombre ?? 'Cliente';
    final folio = widget.pedido.folio;
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final monto = widget.pedido.total != null ? ' por ${fmt.format(widget.pedido.total!)}' : '';
    switch (etapa) {
      case 'Pago': return '¡Hola $nombre! ✅ Confirmamos tu pago del pedido *$folio*$monto. Ya estamos trabajando en él. — *HETNA CNC*';
      case 'Produccion': return '¡Hola $nombre! 🔧 Tu pedido *$folio* entró a producción. Te avisamos cuando esté listo. — *HETNA CNC*';
      case 'Pruebas': return '¡Hola $nombre! 🔍 Tu pedido *$folio* está en control de calidad. ¡Casi listo! — *HETNA CNC*';
      case 'Entrega': return '¡Hola $nombre! 📦 Tu pedido *$folio* está *LISTO* para entrega. ¿Cuándo podemos coordinar? — *HETNA CNC*';
      case 'Entregado': return '¡Hola $nombre! 🎉 Tu pedido *$folio* fue entregado. ¡Gracias por confiar en *HETNA CNC*! Si necesitas algo más, con gusto te atendemos.';
      default: return '¡Hola $nombre! Tu pedido *$folio* está en proceso. — *HETNA CNC*';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final nombre = widget.pedido.cliente?.nombre ?? widget.pedido.cliente?.empresa ?? 'Sin cliente';
    final tieneWA = (widget.pedido.cliente?.whatsappNumero ?? '').isNotEmpty;
    final siguienteEtapa = _idx < _etapas.length - 1 ? _etapas[_idx + 1] : null;

    final diasRestantes = widget.pedido.fechaEntregaEstimada != null
      ? widget.pedido.fechaEntregaEstimada!.difference(DateTime.now()).inDays : null;
    final urgente = diasRestantes != null && diasRestantes <= 2 && !_esEntregado;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgente ? AppColors.rojo.withOpacity(0.5) : AppColors.grisBorde,
          width: urgente ? 1.5 : 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ─── Header ───
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            if (widget.pedido.cliente?.empresa != null)
              Text(widget.pedido.cliente!.empresa!, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            Text(widget.pedido.folio, style: const TextStyle(fontSize: 11, color: AppColors.azul, fontWeight: FontWeight.w500)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmt.format(widget.pedido.total ?? 0),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.azul)),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _colorActual.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(_etiquetasEtapa[widget.pedido.estado] ?? widget.pedido.estado,
                style: TextStyle(fontSize: 10, color: _colorActual, fontWeight: FontWeight.w700))),
          ]),
        ]),

        // Fecha estimada
        if (widget.pedido.fechaEntregaEstimada != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.calendar_today_outlined, size: 12, color: urgente ? AppColors.rojo : AppColors.textoSecundario),
            const SizedBox(width: 4),
            Text('Entrega: ${DateFormat('dd/MM/yyyy').format(widget.pedido.fechaEntregaEstimada!)}',
              style: TextStyle(fontSize: 11, color: urgente ? AppColors.rojo : AppColors.textoSecundario,
                fontWeight: urgente ? FontWeight.w600 : FontWeight.normal)),
            if (diasRestantes != null && !_esEntregado) ...[
              const SizedBox(width: 8),
              Text(diasRestantes <= 0 ? '⚠ Vencido' : '$diasRestantes días',
                style: TextStyle(fontSize: 10, color: urgente ? AppColors.rojo : AppColors.textoSecundario,
                  fontWeight: FontWeight.w600)),
            ],
          ]),
        ],

        const SizedBox(height: 12),

        // ─── Barra de progreso ───
        ClipRRect(borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progreso, backgroundColor: AppColors.gris, minHeight: 8,
            valueColor: AlwaysStoppedAnimation(_esEntregado ? AppColors.verde : AppColors.azul))),
        const SizedBox(height: 6),
        Row(children: _etapas.map((e) {
          final i = _etapas.indexOf(e);
          final activa = i <= _idx;
          final esActual = i == _idx;
          final color = _coloresEtapa[e] ?? AppColors.azul;
          return Expanded(child: Column(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: esActual ? color : (activa ? AppColors.verde.withOpacity(0.5) : AppColors.gris))),
            const SizedBox(height: 2),
            Text(e == 'Produccion' ? 'Prod.' : e,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 7,
                color: esActual ? color : (activa ? AppColors.verde : AppColors.textoSecundario),
                fontWeight: esActual ? FontWeight.w700 : FontWeight.normal)),
          ]));
        }).toList()),

        const SizedBox(height: 12),

        // ─── Botones de acción ───
        if (!_esEntregado && siguienteEtapa != null) ...[
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _cambiando ? null : () => _cambiarEtapa(siguienteEtapa),
            style: ElevatedButton.styleFrom(
              backgroundColor: _coloresEtapa[siguienteEtapa] ?? AppColors.azul,
              padding: const EdgeInsets.symmetric(vertical: 10)),
            child: _cambiando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('Avanzar a: ${_etiquetasEtapa[siguienteEtapa] ?? siguienteEtapa}',
                    style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                ]))),
          const SizedBox(height: 8),
        ],

        Row(children: [
          if (tieneWA) Expanded(child: ElevatedButton(
            onPressed: _enviandoWA ? null : _notificarCliente,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(vertical: 8)),
            child: _enviandoWA
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.chat, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Notificar cliente', style: TextStyle(fontSize: 12, color: Colors.white)),
                ]))),
          if (tieneWA && !_esEntregado) const SizedBox(width: 8),
          if (!_esEntregado) Expanded(child: OutlinedButton(
            onPressed: () => _cambiarEtapa('Entregado'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.verde,
              side: const BorderSide(color: AppColors.verde),
              padding: const EdgeInsets.symmetric(vertical: 8)),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle, size: 15),
              SizedBox(width: 6),
              Text('Entregado', style: TextStyle(fontSize: 12)),
            ]))),
          if (_esEntregado) const Expanded(child: Center(child: Row(
            mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle, color: AppColors.verde, size: 18),
            SizedBox(width: 6),
            Text('Pedido entregado ✅', style: TextStyle(color: AppColors.verde, fontWeight: FontWeight.w600)),
          ]))),
        ]),
      ]));
  }

  Future<void> _cambiarEtapa(String nueva) async {
    setState(() => _cambiando = true);
    try {
      await SupabaseService.actualizarEtapaPedido(widget.pedido.id!, nueva);
      widget.onActualizar();
      if (mounted && (widget.pedido.cliente?.whatsappNumero ?? '').isNotEmpty) {
        showDialog(context: context, builder: (_) => AlertDialog(
          title: Text('Etapa: ${_etiquetasEtapa[nueva] ?? nueva}'),
          content: Text('¿Notificar a ${widget.pedido.cliente?.nombre} por WhatsApp?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
            ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); _notificarCliente(etapa: nueva); },
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('Sí, notificar'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366))),
          ]));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _cambiando = false);
    }
  }

  Future<void> _notificarCliente({String? etapa}) async {
    setState(() => _enviandoWA = true);
    try {
      final msg = _mensajeWA(etapa ?? widget.pedido.estado);
      var numero = (widget.pedido.cliente?.whatsappNumero ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      if (numero.length == 10) numero = '52$numero';
      final url = 'https://wa.me/$numero?text=${Uri.encodeComponent(msg)}';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error WA: $e')));
    } finally {
      if (mounted) setState(() => _enviandoWA = false);
    }
  }
}
