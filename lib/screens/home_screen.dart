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
import 'reportes_screen.dart';
import 'premium_screen.dart';
import 'calculadora_cnc_screen.dart';
import 'envios_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/hetna_api.dart';
import '../i18n/tr.dart';

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
  void initState() { super.initState(); _cargarAlertas(); _abrirPlanesSiLoPide(); }

  // Los correos de "elige tu plan" abren hetnacnc.com/cotizador/?planes=1: al
  // entrar se abre la pantalla de planes (una vez por sesión). En Android/iOS
  // Uri.base no trae parámetros, así que ahí no pasa nada.
  static bool _planesMostrados = false;
  void _abrirPlanesSiLoPide() {
    if (_planesMostrados || Uri.base.queryParameters['planes'] != '1') return;
    _planesMostrados = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
    });
  }

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
      _btn(0, Icons.dashboard_outlined, tr('Inicio')),
      _btn(1, Icons.notifications_outlined, tr('Alertas'), badge: _alertas),
      _btn(2, Icons.description_outlined, tr('Cotizar')),
      _btn(3, Icons.local_shipping_outlined, tr('Avances')),
      _btn(4, Icons.calculate_outlined, tr('Simular'), plan: 'simulador'),
      // Botón Más
      Expanded(child: Builder(builder: (ctx) => GestureDetector(
        onTap: () => Scaffold.of(ctx).openDrawer(),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.grid_view_outlined, size: 22,
            color: _tab >= 5 ? AppColors.azul : AppColors.textoSecundario),
          const SizedBox(height: 2),
          Text(tr('Más'), style: TextStyle(fontSize: 9,
            color: _tab >= 5 ? AppColors.azul : AppColors.textoSecundario,
            fontWeight: _tab >= 5 ? FontWeight.w600 : FontWeight.normal)),
        ])))),
    ]))),
  );

  Widget _btn(int idx, IconData icon, String label, {int badge = 0, String? plan}) {
    final active = idx == _tab;
    final bloqueado = plan != null && !AuthService.puede(plan);
    return Expanded(child: GestureDetector(
      onTap: () async {
        if (bloqueado) {
          await AuthService.exigirModulo(context, plan!, funcion: label);
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
        Text(tr(label), style: TextStyle(fontSize: 9,
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
          Text(tr('HETNA CNC'),
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(tr(AuthService.nombreUsuario ?? tr('Usuario')),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(tr(AuthService.rol ?? ''),
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
          // Aviso de plan / trial
          if ((AuthService.plan == 'trial' || AuthService.plan == 'prueba') && !AuthService.trialVencido) ...[
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20)),
              child: Text(trf('🎁 Prueba: {0} días restantes', [(AuthService.diasTrialRestantes)]),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))),
          ],
          if (AuthService.trialVencido) ...[
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20)),
              child: Text(tr('⏰ Prueba vencida — actualiza tu plan'),
                style: TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.w700))),
          ],
        ])),
      _dItem(Icons.people_outline,         tr('CRM Clientes'),        5, modulo: 'clientes'),
      _dItem(Icons.inventory_2_outlined,   tr('Productos y Catálogo'),6, modulo: 'productos'),
      _dItem(Icons.warehouse_outlined,     tr('Inventario Bodega'),   7, plan: 'inventario', modulo: 'inventario'),
      _dItem(Icons.receipt_long_outlined,  tr('Gastos y Compras'),    8, plan: 'gastos', modulo: 'gastos'),
      _dItem(Icons.campaign_outlined,      tr('Marketing'),           9, plan: 'marketing', modulo: 'marketing'),
      _dItem(Icons.group_outlined,         tr('Mi equipo'),          10, plan: 'equipo', modulo: 'equipo'),
      const Divider(height: 1),
      _dItem(Icons.bar_chart_outlined,     tr('Reportes Excel'),     11, plan: 'reportes', modulo: 'reportes'),
      _dItem(Icons.settings_outlined,      tr('Configuración'),      12, modulo: 'config'),
      _dItem(Icons.tune_outlined,          tr('Config Simulador'),   13, plan: 'config_simulador'),
      _dItem(Icons.calculate_outlined,     tr('Costos del taller'),  14, plan: 'costos_taller'),
      // ── Herramientas HETNA (abiertas en todos los planes) ──
      const Divider(height: 1),
      _seccion(tr('HERRAMIENTAS HETNA')),
      _dPush(Icons.precision_manufacturing_outlined, tr('Calculadora CNC'), const CalculadoraCncScreen()),
      _dPush(Icons.local_shipping_outlined, tr('Envíos HETNA'), const EnviosScreen()),
      // ── Ecosistema hetnacnc.com ──
      const Divider(height: 1),
      _seccion(tr('HETNA CNC')),
      _dLink(Icons.storefront_outlined, tr('Tienda'), HetnaApi.urlTienda),
      _dLink(Icons.forum_outlined, tr('Foro CNC'), HetnaApi.urlForo),
      _dLink(Icons.science_outlined, tr('Laboratorio CAM'), HetnaApi.urlLaboratorio),
      _dLink(Icons.gavel_outlined, tr('Licitaciones (RFQ)'), HetnaApi.urlLicitaciones),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.workspace_premium_outlined, color: AppColors.naranja, size: 22),
        title: Text(tr('Mi plan'), style: TextStyle(fontSize: 14)),
        trailing: Text(Planes.nombres[AuthService.planActual]!,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.naranja)),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
        }),
      if (AuthService.esAdmin)
        ListTile(
          leading: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.textoSecundario, size: 22),
          title: Text(tr('Permisos por rol'), style: TextStyle(fontSize: 14)),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PermisosScreen()));
          }),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.logout_outlined, color: AppColors.rojo, size: 22),
        title: Text(tr('Cerrar sesión'),
          style: TextStyle(fontSize: 14, color: AppColors.rojo)),
        onTap: () async {
          Navigator.pop(context);
          await AuthService.logout();
          if (mounted) Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
        }),
    ]));

  Widget _seccion(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(tr(t), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
      color: AppColors.textoSecundario, letterSpacing: 0.8)));

  Widget _dPush(IconData icon, String label, Widget pantalla) => ListTile(
    leading: Icon(icon, color: AppColors.naranja, size: 22),
    title: Text(tr(label), style: const TextStyle(fontSize: 14)),
    onTap: () {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    });

  Widget _dLink(IconData icon, String label, String url) => ListTile(
    leading: Icon(icon, color: AppColors.azul, size: 22),
    title: Text(tr(label), style: const TextStyle(fontSize: 14)),
    trailing: const Icon(Icons.open_in_new, size: 16, color: AppColors.textoSecundario),
    onTap: () {
      Navigator.pop(context);
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    });

  Widget _dItem(IconData icon, String label, int idx, {String? plan, String? modulo}) {
    final active = _tab == idx;
    final bloqueadoPremium = plan != null && !AuthService.puede(plan);
    final sinPermisoRol = modulo != null && !AuthService.tieneAcceso(modulo);
    final bloqueado = bloqueadoPremium || sinPermisoRol;
    return ListTile(
      leading: Icon(icon,
        color: bloqueado ? AppColors.textoSecundario.withOpacity(0.4)
          : (active ? AppColors.azul : AppColors.textoSecundario), size: 22),
      title: Text(tr(label), style: TextStyle(fontSize: 14,
        color: bloqueado ? AppColors.textoSecundario.withOpacity(0.4)
          : (active ? AppColors.azul : Colors.black),
        fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      trailing: bloqueado ? const Icon(Icons.lock, size: 16, color: Colors.amber) : null,
      selected: active,
      selectedTileColor: AppColors.azulClaro,
      onTap: () async {
        Navigator.pop(context);
        if (bloqueadoPremium) {
          await AuthService.exigirModulo(context, plan!, funcion: label);
          return;
        }
        if (sinPermisoRol) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(trf('No tienes permiso para ver "{0}". Pide a tu administrador que te lo active.', [label])),
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
        title: Text(tr('Alertas y Agenda'),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
            color: AppColors.azul)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          tabs: [
            Tab(icon: Icon(Icons.calendar_month_outlined, size: 18), text: tr('Agenda')),
            Tab(icon: Icon(Icons.notifications_outlined, size: 18), text: tr('Alertas')),
            Tab(icon: Icon(Icons.event_outlined, size: 18), text: tr('Citas')),
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
