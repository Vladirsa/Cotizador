// ============================================
// lib/screens/home_screen.dart
// Navegación principal con barra inferior
// ============================================

import 'package:flutter/material.dart';
import '../main.dart';
import '../services/supabase_service.dart';
import 'inicio_screen.dart';
import 'alertas_screen.dart';
import 'clientes_screen.dart';
import 'cotizar_screen.dart';
import 'avances_screen.dart';
import 'config_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _alertasPendientes = 0;

  final _pantallas = const [
    InicioScreen(),
    AlertasScreen(),
    ClientesScreen(),
    CotizarScreen(),
    AvancesScreen(),
    ConfigScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _cargarAlertas();
  }

  Future<void> _cargarAlertas() async {
    try {
      final count = await SupabaseService.countAlertasPendientes();
      if (mounted) setState(() => _alertasPendientes = count);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pantallas),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                _NavBtn(index: 0, current: _tab, icon: Icons.dashboard_outlined, label: 'Inicio', onTap: _setTab),
                _NavBtn(index: 1, current: _tab, icon: Icons.notifications_outlined, label: 'Alertas', onTap: _setTab, badge: _alertasPendientes),
                _NavBtn(index: 2, current: _tab, icon: Icons.people_outline, label: 'Clientes', onTap: _setTab),
                _NavBtn(index: 3, current: _tab, icon: Icons.description_outlined, label: 'Cotizar', onTap: _setTab),
                _NavBtn(index: 4, current: _tab, icon: Icons.local_shipping_outlined, label: 'Avances', onTap: _setTab),
                _NavBtn(index: 5, current: _tab, icon: Icons.settings_outlined, label: 'Config.', onTap: _setTab),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setTab(int i) {
    setState(() => _tab = i);
    if (i == 1) _cargarAlertas();
  }
}

class _NavBtn extends StatelessWidget {
  final int index, current;
  final IconData icon;
  final String label;
  final Function(int) onTap;
  final int badge;

  const _NavBtn({
    required this.index,
    required this.current,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon,
                    size: 24,
                    color: active ? AppColors.azul : AppColors.textoSecundario),
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppColors.rojo,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? AppColors.azul : AppColors.textoSecundario,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}
