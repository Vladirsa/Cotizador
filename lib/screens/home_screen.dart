// ============================================
// lib/screens/home_screen.dart
// Navegación con 7 pestañas incluyendo Marketing
// ============================================
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/supabase_service.dart';
import 'inicio_screen.dart';
import 'alertas_screen.dart';
import 'clientes_screen.dart';
import 'cotizar_screen.dart';
import 'avances_screen.dart';
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

  final _pantallas = const [
    InicioScreen(),
    AlertasScreen(),
    ClientesScreen(),
    CotizarScreen(),
    AvancesScreen(),
    MarketingScreen(),
    ConfigScreen(),
  ];

  @override
  void initState() { super.initState(); _cargarAlertas(); }

  Future<void> _cargarAlertas() async {
    try {
      final n = await SupabaseService.countAlertasPendientes();
      if (mounted) setState(() => _alertas = n);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pantallas),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.grisBorde, width: 0.5))),
        child: SafeArea(child: SizedBox(height: 58,
          child: Row(children: [
            _NavBtn(0, _tab, Icons.dashboard_outlined, 'Inicio', _setTab),
            _NavBtn(1, _tab, Icons.notifications_outlined, 'Alertas', _setTab, badge: _alertas),
            _NavBtn(2, _tab, Icons.people_outline, 'Clientes', _setTab),
            _NavBtn(3, _tab, Icons.description_outlined, 'Cotizar', _setTab),
            _NavBtn(4, _tab, Icons.local_shipping_outlined, 'Avances', _setTab),
            _NavBtn(5, _tab, Icons.campaign_outlined, 'Marketing', _setTab),
            _NavBtn(6, _tab, Icons.settings_outlined, 'Config.', _setTab),
          ]),
        )),
      ),
    );
  }

  void _setTab(int i) {
    setState(() => _tab = i);
    if (i == 1) _cargarAlertas();
  }
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
            child: Container(width: 14, height: 14, decoration: const BoxDecoration(color: AppColors.rojo, shape: BoxShape.circle),
              child: Center(child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 8))))),
        ]),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: active ? AppColors.azul : AppColors.textoSecundario,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ]),
    ));
  }
}
