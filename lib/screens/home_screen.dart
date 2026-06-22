import 'package:flutter/material.dart';
import '../main.dart';
import '../services/notificaciones_service.dart';
import '../services/supabase_service.dart';
import 'inicio_screen.dart';
import 'alertas_screen.dart';
import 'cotizar_screen.dart';
import 'avances_screen.dart';
import 'clientes_screen.dart';
import 'productos_screen.dart';
import 'inventario_screen.dart';
import 'gastos_screen.dart';
import 'marketing_screen.dart';
import 'config_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _alertas = 0;

  // Pantallas principales (barra inferior)
  final _principales = const [
    InicioScreen(),
    AlertasScreen(),
    CotizarScreen(),
    AvancesScreen(),
  ];

  // Pantallas del menú "Más"
  Widget _pantallaExtra(int tab) {
    switch (tab) {
      case 4: return const ClientesScreen();
      case 5: return const ProductosScreen();
      case 6: return const InventarioScreen();
      case 7: return const GastosScreen();
      case 8: return const GastosScreen(); // Reportes ahora en Inicio
      case 9: return const MarketingScreen();
      case 10: return const ConfigScreen();
      default: return const InicioScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarAlertas();
    // Iniciar escucha en tiempo real de Supabase
    NotificacionesService.iniciarEscuchaRealtime();
  }

  @override
  void dispose() {
    NotificacionesService.detenerEscucha();
    super.dispose();
  }

  Future<void> _cargarAlertas() async {
    try {
      final n = await SupabaseService.countAlertasPendientes();
      if (mounted) setState(() => _alertas = n);
      // Actualizar badge del ícono
      await NotificacionesService.actualizarBadge(n);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tab < 4
        ? IndexedStack(index: _tab, children: _principales)
        : _pantallaExtra(_tab),
      drawer: _drawer(),
      bottomNavigationBar: _barra(context),
    );
  }

  Widget _barra(BuildContext context) => Container(
    decoration: const BoxDecoration(color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.grisBorde, width: 0.5))),
    child: SafeArea(child: SizedBox(height: 58, child: Row(children: [
      _btn(0, Icons.dashboard_outlined, 'Inicio'),
      _btn(1, Icons.notifications_outlined, 'Alertas', badge: _alertas),
      _btn(2, Icons.description_outlined, 'Cotizar'),
      _btn(3, Icons.local_shipping_outlined, 'Avances'),
      // Botón Más
      Expanded(child: Builder(builder: (ctx) => GestureDetector(
        onTap: () => Scaffold.of(ctx).openDrawer(),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.grid_view_outlined, size: 22,
            color: _tab >= 4 ? AppColors.azul : AppColors.textoSecundario),
          const SizedBox(height: 2),
          Text('Más', style: TextStyle(fontSize: 9,
            color: _tab >= 4 ? AppColors.azul : AppColors.textoSecundario,
            fontWeight: _tab >= 4 ? FontWeight.w600 : FontWeight.normal)),
        ])))),
    ]))),
  );

  Widget _btn(int idx, IconData icon, String label, {int badge = 0}) {
    final active = idx == _tab;
    return Expanded(child: GestureDetector(
      onTap: () { setState(() => _tab = idx); if (idx == 1) _cargarAlertas(); },
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Stack(clipBehavior: Clip.none, children: [
          Icon(icon, size: 22, color: active ? AppColors.azul : AppColors.textoSecundario),
          if (badge > 0) Positioned(top: -4, right: -6,
            child: Container(width: 16, height: 16,
              decoration: const BoxDecoration(color: AppColors.rojo, shape: BoxShape.circle),
              child: Center(child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9))))),
        ]),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9,
          color: active ? AppColors.azul : AppColors.textoSecundario,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ])));
  }

  Widget _drawer() => Drawer(
    child: ListView(padding: EdgeInsets.zero, children: [
      Container(height: 110, decoration: const BoxDecoration(color: AppColors.azul),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('HETNA CNC', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const Text('Sistema de gestión', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
      _dItem(Icons.people_outline, 'CRM Clientes', 4),
      _dItem(Icons.inventory_2_outlined, 'Productos y Catálogo', 5),
      _dItem(Icons.warehouse_outlined, 'Inventario Bodega', 6),
      _dItem(Icons.receipt_long_outlined, 'Gastos y Compras', 7),
      _dItem(Icons.campaign_outlined, 'Marketing', 9),
      const Divider(height: 1),
      _dItem(Icons.settings_outlined, 'Configuración', 10),
    ]));

  Widget _dItem(IconData icon, String label, int idx) {
    final active = _tab == idx;
    return ListTile(
      leading: Icon(icon, color: active ? AppColors.azul : AppColors.textoSecundario, size: 22),
      title: Text(label, style: TextStyle(fontSize: 14,
        color: active ? AppColors.azul : Colors.black,
        fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      selected: active,
      selectedTileColor: AppColors.azulClaro,
      onTap: () { Navigator.pop(context); setState(() => _tab = idx); });
  }
}
