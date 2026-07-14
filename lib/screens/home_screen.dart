import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../main.dart';
import 'cupones_screen.dart';
import 'citas_screen.dart';
import 'config_simulador_screen.dart';
import 'config_costos_screen.dart';
import 'plantillas_wa_screen.dart';
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
import 'simulador_screen.dart';
import 'agenda_screen.dart';
import 'equipo_screen.dart';
import 'permisos_screen.dart';
import 'pedidos_publicos_screen.dart';
import 'reportes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _alertas = 0;

  // Pantallas principales (barra inferior)
  // Tab 1 = _AlertasAgendaScreen (unifica Alertas + Agenda + Citas)
  final _principales = const [
    InicioScreen(),
    _AlertasAgendaScreen(),
    CotizarScreen(),
    AvancesScreen(),
    SimuladorScreen(),
  ];

  Widget _pantallaExtra(int tab) {
    switch (tab) {
      case 5:  return const ClientesScreen();
      case 6:  return const ProductosScreen();
      case 7:  return const InventarioScreen();
      case 8:  return const GastosScreen();
      case 9:  return const MarketingScreen();
      case 10: return const EquipoScreen();
      case 11: return const ReportesScreen();
      case 12: return const ConfigScreen();
      case 13: return const ConfigSimuladorScreen();
      case 14: return const ConfigCostosScreen();
      default: return const InicioScreen();
    }
  }

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
      body: _tab < 5
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
      _btn(4, Icons.calculate_outlined, 'Simular', premium: true),
      // Botón Más
      Expanded(child: Builder(builder: (ctx) => GestureDetector(
        onTap: () => Scaffold.of(ctx).openDrawer(),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.grid_view_outlined, size: 22,
            color: _tab >= 5 ? AppColors.azul : AppColors.textoSecundario),
          const SizedBox(height: 2),
          Text('Más', style: TextStyle(fontSize: 9,
            color: _tab >= 5 ? AppColors.azul : AppColors.textoSecundario,
            fontWeight: _tab >= 5 ? FontWeight.w600 : FontWeight.normal)),
        ])))),
    ]))),
  );

  Widget _btn(int idx, IconData icon, String label, {int badge = 0, bool premium = false}) {
    final active = idx == _tab;
    final bloqueado = premium && !AuthService.esPremiumActivo;
    return Expanded(child: GestureDetector(
      onTap: () async {
        if (bloqueado) {
          await AuthService.exigirPremium(context, funcion: label);
          return;
        }
        setState(() => _tab = idx);
        if (idx == 1) _cargarAlertas();
      },
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Stack(clipBehavior: Clip.none, children: [
          Icon(icon, size: 22, color: bloqueado
            ? AppColors.textoSecundario.withOpacity(0.4)
            : (active ? AppColors.azul : AppColors.textoSecundario)),
          if (badge > 0) Positioned(top: -4, right: -6,
            child: Container(width: 16, height: 16,
              decoration: const BoxDecoration(color: AppColors.rojo, shape: BoxShape.circle),
              child: Center(child: Text('$badge',
                style: const TextStyle(color: Colors.white, fontSize: 9))))),
          if (bloqueado) const Positioned(bottom: -2, right: -4,
            child: Icon(Icons.lock, size: 10, color: Colors.amber)),
        ]),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9,
          color: bloqueado
            ? AppColors.textoSecundario.withOpacity(0.4)
            : (active ? AppColors.azul : AppColors.textoSecundario),
          fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ])));
  }

  Widget _drawer() => Drawer(
    child: ListView(padding: EdgeInsets.zero, children: [
      Container(
        decoration: const BoxDecoration(color: AppColors.azul),
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('HETNA CNC',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(AuthService.nombreUsuario ?? 'Usuario',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(AuthService.rol ?? '',
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
          // Aviso de plan / trial
          if (AuthService.plan == 'trial' && !AuthService.trialVencido) ...[
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20)),
              child: Text('🎁 Prueba: ${AuthService.diasTrialRestantes} días restantes',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))),
          ],
          if (AuthService.trialVencido) ...[
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20)),
              child: const Text('⏰ Prueba vencida — actualiza tu plan',
                style: TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.w700))),
          ],
        ])),
      ListTile(
        leading: Icon(Icons.storefront_outlined,
          color: !AuthService.esPremiumActivo
            ? AppColors.textoSecundario.withOpacity(0.4) : AppColors.textoSecundario, size: 22),
        title: Text('Pedidos de clientes', style: TextStyle(fontSize: 14,
          color: !AuthService.esPremiumActivo ? AppColors.textoSecundario.withOpacity(0.4) : null)),
        trailing: !AuthService.esPremiumActivo ? const Icon(Icons.lock, size: 16, color: Colors.amber) : null,
        onTap: () async {
          Navigator.pop(context);
          if (!AuthService.esPremiumActivo) {
            await AuthService.exigirPremium(context, funcion: 'Pedidos de clientes');
            return;
          }
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PedidosPublicosScreen()));
        }),
      _dItem(Icons.people_outline,         'CRM Clientes',        5, modulo: 'clientes'),
      _dItem(Icons.inventory_2_outlined,   'Productos y Catálogo',6, modulo: 'productos'),
      _dItem(Icons.warehouse_outlined,     'Inventario Bodega',   7, modulo: 'inventario'),
      _dItem(Icons.receipt_long_outlined,  'Gastos y Compras',    8, modulo: 'gastos'),
      _dItem(Icons.campaign_outlined,      'Marketing',           9, premium: true, modulo: 'marketing'),
      _dItem(Icons.group_outlined,         'Mi equipo',          10, modulo: 'equipo'),
      const Divider(height: 1),
      _dItem(Icons.bar_chart_outlined,     'Reportes Excel',     11, premium: true, modulo: 'reportes'),
      _dItem(Icons.settings_outlined,      'Configuración',      12, modulo: 'config'),
      _dItem(Icons.tune_outlined,          'Config Simulador',   13),
      _dItem(Icons.calculate_outlined,     'Costos del taller',  14),
      if (AuthService.esAdmin)
        ListTile(
          leading: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.textoSecundario, size: 22),
          title: const Text('Permisos por rol', style: TextStyle(fontSize: 14)),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PermisosScreen()));
          }),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.logout_outlined, color: AppColors.rojo, size: 22),
        title: const Text('Cerrar sesión',
          style: TextStyle(fontSize: 14, color: AppColors.rojo)),
        onTap: () async {
          Navigator.pop(context);
          await AuthService.logout();
          if (mounted) Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
        }),
    ]));

  Widget _dItem(IconData icon, String label, int idx, {bool premium = false, String? modulo}) {
    final active = _tab == idx;
    final bloqueadoPremium = premium && !AuthService.esPremiumActivo;
    final sinPermisoRol = modulo != null && !AuthService.tieneAcceso(modulo);
    final bloqueado = bloqueadoPremium || sinPermisoRol;
    return ListTile(
      leading: Icon(icon,
        color: bloqueado ? AppColors.textoSecundario.withOpacity(0.4)
          : (active ? AppColors.azul : AppColors.textoSecundario), size: 22),
      title: Text(label, style: TextStyle(fontSize: 14,
        color: bloqueado ? AppColors.textoSecundario.withOpacity(0.4)
          : (active ? AppColors.azul : Colors.black),
        fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      trailing: bloqueado ? const Icon(Icons.lock, size: 16, color: Colors.amber) : null,
      selected: active,
      selectedTileColor: AppColors.azulClaro,
      onTap: () async {
        Navigator.pop(context);
        if (bloqueadoPremium) {
          await AuthService.exigirPremium(context, funcion: label);
          return;
        }
        if (sinPermisoRol) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No tienes permiso para ver "$label". Pide a tu administrador que te lo active.'),
            backgroundColor: AppColors.rojo));
          return;
        }
        setState(() => _tab = idx);
      });
  }
}

// ══════════════════════════════════════════════════════
// Alertas + Agenda + Citas unidas en una sola pestaña
// ══════════════════════════════════════════════════════
class _AlertasAgendaScreen extends StatefulWidget {
  const _AlertasAgendaScreen();
  @override
  State<_AlertasAgendaScreen> createState() => _AlertasAgendaScreenState();
}

class _AlertasAgendaScreenState extends State<_AlertasAgendaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Alertas y Agenda',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
            color: AppColors.azul)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month_outlined, size: 18), text: 'Agenda'),
            Tab(icon: Icon(Icons.notifications_outlined, size: 18), text: 'Alertas'),
            Tab(icon: Icon(Icons.event_outlined, size: 18), text: 'Citas'),
          ])),
      body: TabBarView(
        controller: _tabs,
        children: const [
          AgendaBody(),
          AlertasBody(),
          CitasScreen(),
        ]));
  }
}
