import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});
  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  Map<String, dynamic> _stats = {};
  List<Cotizacion> _cotizaciones = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final stats = await SupabaseService.getEstadisticasMes();
      final cots = await SupabaseService.getCotizaciones();
      if (mounted) setState(() {
        _stats = stats;
        _cotizaciones = cots.take(5).toList();
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmtMoney = NumberFormat('\$#,##0', 'es_MX');
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: Row(children: [
          Container(width: 28, height: 28,
            decoration: BoxDecoration(color: AppColors.azul, borderRadius: BorderRadius.circular(6)),
            child: const Center(child: Text('H', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
          const SizedBox(width: 8),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HETNA CNC', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.azul)),
            Text('Cotizador Pro', style: TextStyle(fontSize: 10, color: AppColors.textoSecundario, height: 1)),
          ]),
        ]),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)],
      ),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [
            _label('Resumen del mes'),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.6,
              children: [
                _stat('Solicitudes', '${_stats['solicitudes_elaboradas'] ?? 0}', AppColors.ambar, Icons.description_outlined),
                _stat('Entregados', '${_stats['pedidos_entregados'] ?? 0}', AppColors.verde, Icons.check_circle_outline),
                _stat('Alertas', '${_stats['alertas_pendientes'] ?? 0}', AppColors.rojo, Icons.notifications_outlined),
                _stat('Ventas', fmtMoney.format(_stats['ventas_mes'] ?? 0), AppColors.azul, Icons.trending_up),
              ]),
            const SizedBox(height: 16),
            _label('Últimas cotizaciones'),
            if (_cotizaciones.isEmpty)
              Container(padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.grisBorde, width: 0.5)),
                child: const Center(child: Text('No hay cotizaciones aún',
                  style: TextStyle(color: AppColors.textoSecundario)))),
            ..._cotizaciones.map((c) => _itemCot(c)),
          ])),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario, letterSpacing: 1)));

  Widget _stat(String label, String valor, Color color, IconData icon) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Icon(icon, color: color, size: 20),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
      ]),
    ]));

  Widget _itemCot(Cotizacion c) {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final colores = {
      'Borrador': Colors.grey, 'Enviada': AppColors.azul,
      'Aprobada': AppColors.verde, 'Rechazada': AppColors.rojo,
      'Pedido': const Color(0xFF7c3aed), 'Vencida': AppColors.ambar,
    };
    final color = colores[c.estado] ?? Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.cliente?.nombre ?? 'Sin cliente', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          Text(c.folio ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(c.estado, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmt.format(c.total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.azul)),
          if (c.createdAt != null)
            Text(DateFormat('dd/MM').format(c.createdAt!),
              style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ]),
      ]),
    );
  }
}
