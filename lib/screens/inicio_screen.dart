import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/models.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});
  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  Map<String, dynamic> _stats = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final stats = await SupabaseService.getEstadisticasMes();
      if (mounted) setState(() { _stats = stats; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_MX');
    final fmtMoney = NumberFormat('\$#,##0', 'es_MX');

    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.azul, borderRadius: BorderRadius.circular(6)),
            child: const Center(child: Text('H', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
          const SizedBox(width: 8),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HETNA CNC', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.azul)),
            Text('Cotizador Pro', style: TextStyle(fontSize: 10, color: AppColors.textoSecundario, height: 1)),
          ]),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
          const SizedBox(width: 4),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(padding: const EdgeInsets.all(14), children: [
                // Stats grid
                _seccion('Resumen del mes'),
                GridView.count(
                  crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.6,
                  children: [
                    _statCard('Solicitudes elaboradas', '${_stats['solicitudes_elaboradas'] ?? 0}', AppColors.ambar, Icons.description_outlined),
                    _statCard('Pedidos entregados', '${_stats['pedidos_entregados'] ?? 0}', AppColors.verde, Icons.check_circle_outline),
                    _statCard('Alertas pendientes', '${_stats['alertas_pendientes'] ?? 0}', AppColors.rojo, Icons.notifications_outlined),
                    _statCard('Ventas del mes', fmtMoney.format(_stats['ventas_mes'] ?? 0), AppColors.azul, Icons.trending_up),
                  ],
                ),
                const SizedBox(height: 16),

                // Accesos rápidos
                _seccion('Accesos rápidos'),
                GridView.count(
                  crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.2,
                  children: [
                    _accesoBtn('Nueva cotización', Icons.add_circle_outline, AppColors.azul, () => _irTab(3)),
                    _accesoBtn('Nuevo cliente', Icons.person_add_outlined, AppColors.verde, () => _irTab(2)),
                    _accesoBtn('Ver alertas', Icons.notifications_outlined, AppColors.rojo, () => _irTab(1)),
                    _accesoBtn('Marketing', Icons.campaign_outlined, AppColors.ambar, () => _irTab(5)),
                  ],
                ),
                const SizedBox(height: 16),

                // Últimas cotizaciones
                _seccion('Últimas cotizaciones'),
                _UltimasCotizaciones(),
              ]),
            ),
    );
  }

  Widget _seccion(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(titulo.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario, letterSpacing: 1, fontWeight: FontWeight.w600)),
  );

  Widget _statCard(String label, String valor, Color color, IconData icon) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Icon(icon, color: color, size: 20),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
      ]),
    ]),
  );

  Widget _accesoBtn(String label, IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
      ]),
    ),
  );

  void _irTab(int index) {
    // Navegar al tab correspondiente via callback
  }
}

class _UltimasCotizaciones extends StatefulWidget {
  @override
  State<_UltimasCotizaciones> createState() => _UltimasCotizacionesState();
}

class _UltimasCotizacionesState extends State<_UltimasCotizaciones> {
  List<Cotizacion> _cotizaciones = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final res = await SupabaseService.getCotizaciones();
      if (mounted) setState(() => _cotizaciones = res);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_cotizaciones.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: const Center(child: Text('No hay cotizaciones aún', style: TextStyle(color: AppColors.textoSecundario))),
      );
    }
    return Column(children: _cotizaciones.map((c) => _ItemCotizacion(cotizacion: c)).toList());
  }
}

class _ItemCotizacion extends StatelessWidget {
  final Map<String, dynamic> cotizacion;
  const _ItemCotizacion({required this.cotizacion});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final estado = cotizacion['estado'] ?? 'Borrador';
    final colores = {
      'Borrador': Colors.grey, 'Enviada': const Color(0xFF185fa5),
      'Aprobada': AppColors.verde, 'Rechazada': AppColors.rojo,
      'Pedido': const Color(0xFF7c3aed), 'Vencida': AppColors.ambar,
    };
    final color = colores[estado] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cotizacion['clientes']?['nombre'] ?? 'Sin cliente', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          Text(cotizacion['folio'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(estado, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmt.format(cotizacion['total'] ?? 0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.azul)),
          Text(cotizacion['created_at'] != null
            ? DateFormat('dd/MM').format(DateTime.parse(cotizacion['created_at']))
            : '', style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ]),
      ]),
    );
  }
}
