// ============================================
// lib/screens/avances_screen.dart
// ============================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_service.dart';

class AvancesScreen extends StatefulWidget {
  const AvancesScreen({super.key});
  @override
  State<AvancesScreen> createState() => _AvancesScreenState();
}

class _AvancesScreenState extends State<AvancesScreen> {
  List<Pedido> _pedidos = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final pedidos = await SupabaseService.getPedidos();
      if (mounted) setState(() { _pedidos = pedidos; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  @override
  Widget build(BuildContext context) {
    final activos = _pedidos.where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado').toList();
    final entregados = _pedidos.where((p) => p.estado == 'Entregado').toList();

    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: const Text('Avances de pedidos'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
      ]),
      body: _cargando ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [
          if (activos.isEmpty && entregados.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No hay pedidos activos', style: TextStyle(color: AppColors.textoSecundario)))),
          if (activos.isNotEmpty) ...[
            _seccion('Pedidos activos (${activos.length})'),
            ...activos.map((p) => _TarjetaPedido(pedido: p, onActualizar: _cargar)),
          ],
          if (entregados.isNotEmpty) ...[
            _seccion('Entregados recientes'),
            ...entregados.take(5).map((p) => _TarjetaPedido(pedido: p, onActualizar: _cargar)),
          ],
        ])),
    );
  }

  Widget _seccion(String t) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario, letterSpacing: 1)));
}

class _TarjetaPedido extends StatelessWidget {
  final Pedido pedido;
  final VoidCallback onActualizar;
  const _TarjetaPedido({required this.pedido, required this.onActualizar});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final etapas = ['Pedido', 'Pago', 'Produccion', 'Pruebas', 'Entrega', 'Entregado'];
    final idx = etapas.indexOf(pedido.estado);
    final pct = idx < 0 ? 0.0 : (idx + 1) / etapas.length;
    final esEntregado = pedido.estado == 'Entregado';

    final diasRestantes = pedido.fechaEntregaEstimada != null
      ? pedido.fechaEntregaEstimada!.difference(DateTime.now()).inDays : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pedido.folio, style: const TextStyle(fontSize: 12, color: AppColors.azul, fontWeight: FontWeight.w600)),
            Text(pedido.cliente?.nombre ?? 'Sin cliente', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            if (pedido.total != null) Text(fmt.format(pedido.total!), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          ])),
          _badgeEstado(pedido.estado),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: pct, backgroundColor: AppColors.gris, minHeight: 6,
          valueColor: AlwaysStoppedAnimation(esEntregado ? AppColors.verde : AppColors.azul),
        )),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: etapas.map((e) {
          final esDone = etapas.indexOf(e) <= idx;
          return Expanded(child: Text(e == 'Produccion' ? 'Prod.' : e,
            textAlign: TextAlign.center, style: TextStyle(fontSize: 8,
              color: esDone ? AppColors.verde : AppColors.textoSecundario,
              fontWeight: e == pedido.estado ? FontWeight.w700 : FontWeight.normal)));
        }).toList()),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          if (pedido.fechaEntregaEstimada != null)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Entrega: ${DateFormat('dd/MM/yyyy').format(pedido.fechaEntregaEstimada!)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
              if (diasRestantes != null && !esEntregado)
                Text(diasRestantes <= 3 ? '⚠ ${diasRestantes}d restantes' : '$diasRestantes días restantes',
                  style: TextStyle(fontSize: 10, color: diasRestantes <= 3 ? AppColors.rojo : AppColors.textoSecundario)),
            ])
          else const SizedBox(),
          if (!esEntregado)
            ElevatedButton.icon(
              onPressed: () => _notificarAvance(context),
              icon: const Icon(Icons.chat, size: 14),
              label: const Text('Notificar', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
            )
          else
            Row(children: [
              const Icon(Icons.check_circle, color: AppColors.verde, size: 14),
              const SizedBox(width: 4),
              const Text('Entregado', style: TextStyle(fontSize: 11, color: AppColors.verde)),
            ]),
        ]),
        if (!esEntregado) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            'Pago', 'Produccion', 'Pruebas', 'Entrega', 'Entregado'
          ].map((e) => GestureDetector(
            onTap: () => _cambiarEtapa(context, e),
            child: Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: e == pedido.estado ? AppColors.azul : Colors.white, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: e == pedido.estado ? AppColors.azul : AppColors.grisBorde)),
              child: Text(e, style: TextStyle(fontSize: 10, color: e == pedido.estado ? Colors.white : AppColors.textoSecundario))),
          )).toList())),
        ],
      ]),
    );
  }

  Widget _badgeEstado(String estado) {
    final colores = {'Pedido': AppColors.azul, 'Pago': AppColors.ambar, 'Produccion': const Color(0xFF7c3aed),
      'Pruebas': AppColors.rojo, 'Entrega': AppColors.verde, 'Entregado': AppColors.verde};
    final color = colores[estado] ?? Colors.grey;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(estado, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)));
  }

  Future<void> _notificarAvance(BuildContext context) async {
    if (pedido.cliente?.whatsappNumero.isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente sin WhatsApp registrado')));
      return;
    }
    await WhatsAppService.enviarAvancePedido(
      whatsapp: pedido.cliente!.whatsappNumero,
      nombreCliente: pedido.cliente!.nombre,
      folio: pedido.folio,
      etapa: pedido.estado,
      fechaEstimada: pedido.fechaEntregaEstimada,
    );
  }

  Future<void> _cambiarEtapa(BuildContext context, String etapa) async {
    try {
      await SupabaseService.actualizarEtapaPedido(pedido.id!, etapa);
      onActualizar();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
