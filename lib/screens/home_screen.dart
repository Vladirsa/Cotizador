// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/supabase_service.dart';
import 'inicio_screen.dart';
import 'alertas_screen.dart';
import 'clientes_screen.dart';
import 'cotizar_screen.dart';
import 'productos_screen.dart';
import 'inventario_screen.dart';
import 'gastos_screen.dart';
import 'avances_screen.dart';
import 'marketing_screen.dart';
import 'reportes_screen.dart';
import 'config_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _alertas = 0;

  final _paginasPrincipales = const [
    InicioScreen(), AlertasScreen(), ClientesScreen(), CotizarScreen(), AvancesScreen(),
  ];

  @override
  void initState() { super.initState(); _cargarAlertas(); }

  Future<void> _cargarAlertas() async {
    try {
      final n = await SupabaseService.countAlertasPendientes();
      if (mounted) setState(() => _alertas = n);
    } catch (_) {}
  }

  Widget _pantallaExtra(int tab) {
    final pantallas = {
      5: const ProductosScreen(), 6: const InventarioScreen(),
      7: const GastosScreen(), 8: const ReportesScreen(),
      9: const MarketingScreen(), 10: const ConfigScreen(),
    };
    return pantallas[tab] ?? const InicioScreen();
  }

  @override
  Widget build(BuildContext context) {
    if (_tab >= 5) {
      return Scaffold(
        body: _pantallaExtra(_tab),
        drawer: _drawerMenu(),
        bottomNavigationBar: _barraInferior(context),
      );
    }
    return Scaffold(
      body: IndexedStack(index: _tab, children: _paginasPrincipales),
      drawer: _drawerMenu(),
      bottomNavigationBar: _barraInferior(context),
    );
  }

  Widget _barraInferior(BuildContext context) => Container(
    decoration: const BoxDecoration(color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.grisBorde, width: 0.5))),
    child: SafeArea(child: SizedBox(height: 58, child: Row(children: [
      _NavBtn(0, _tab, Icons.dashboard_outlined, 'Inicio', _setTab),
      _NavBtn(1, _tab, Icons.notifications_outlined, 'Alertas', _setTab, badge: _alertas),
      _NavBtn(2, _tab, Icons.people_outline, 'Clientes', _setTab),
      _NavBtn(3, _tab, Icons.description_outlined, 'Cotizar', _setTab),
      _NavBtn(4, _tab, Icons.local_shipping_outlined, 'Avances', _setTab),
      Expanded(child: Builder(builder: (ctx) => GestureDetector(
        onTap: () => Scaffold.of(ctx).openDrawer(),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.grid_view_outlined, size: 22,
            color: _tab >= 5 ? AppColors.azul : AppColors.textoSecundario),
          const SizedBox(height: 2),
          Text('Más', style: TextStyle(fontSize: 9,
            color: _tab >= 5 ? AppColors.azul : AppColors.textoSecundario)),
        ]),
      ))),
    ]))),
  );

  Widget _drawerMenu() => Drawer(
    child: ListView(padding: EdgeInsets.zero, children: [
      Container(height: 100, color: AppColors.azul, padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
          const Text('HETNA CNC', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const Text('Cotizador Pro', style: TextStyle(color: Colors.white70, fontSize: 11)),
        ])),
      _dItem(Icons.inventory_2_outlined, 'Productos', 5),
      _dItem(Icons.warehouse_outlined, 'Inventario Bodega', 6),
      _dItem(Icons.receipt_long_outlined, 'Gastos y Compras', 7),
      _dItem(Icons.bar_chart_outlined, 'Reportes', 8),
      _dItem(Icons.campaign_outlined, 'Marketing', 9),
      const Divider(),
      _dItem(Icons.settings_outlined, 'Configuración', 10),
    ]),
  );

  Widget _dItem(IconData icon, String label, int idx) => ListTile(
    leading: Icon(icon, color: _tab == idx ? AppColors.azul : AppColors.textoSecundario),
    title: Text(label, style: TextStyle(fontSize: 14, color: _tab == idx ? AppColors.azul : Colors.black,
      fontWeight: _tab == idx ? FontWeight.w600 : FontWeight.normal)),
    selected: _tab == idx, selectedTileColor: AppColors.azulClaro,
    onTap: () { Navigator.pop(context); setState(() => _tab = idx); },
  );

  void _setTab(int i) { setState(() => _tab = i); if (i == 1) _cargarAlertas(); }
}

class _NavBtn extends StatelessWidget {
  final int index, current, badge;
  final IconData icon;
  final String label;
  final Function(int) onTap;
  const _NavBtn(this.index, this.current, this.icon, this.label, this.onTap, {this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(child: GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Stack(clipBehavior: Clip.none, children: [
          Icon(icon, size: 22, color: active ? AppColors.azul : AppColors.textoSecundario),
          if (badge > 0) Positioned(top: -4, right: -4,
            child: Container(width: 14, height: 14,
              decoration: const BoxDecoration(color: AppColors.rojo, shape: BoxShape.circle),
              child: Center(child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 8))))),
        ]),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: active ? AppColors.azul : AppColors.textoSecundario,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ]),
    ));
  }
}
