// lib/screens/equipo_screen.dart
// HETNA CNC — Gestión de equipo y roles
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'premium_screen.dart';
import '../i18n/tr.dart';

// ══════════════════════════════════════════════════════
// MODELO
// ══════════════════════════════════════════════════════
class UsuarioNegocio {
  final String id;
  final String userId;
  final String negocioId;
  final String rol;
  final String? nombre;
  final String? correo;
  final bool activo;
  final DateTime? createdAt;

  UsuarioNegocio({
    required this.id, required this.userId, required this.negocioId,
    required this.rol, this.nombre, this.correo,
    this.activo = true, this.createdAt,
  });

  factory UsuarioNegocio.fromJson(Map<String, dynamic> j) => UsuarioNegocio(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    negocioId: j['negocio_id'] as String,
    rol: j['rol'] as String,
    nombre: j['nombre'] as String?,
    correo: j['correo'] as String?,
    activo: j['activo'] as bool? ?? true,
    createdAt: j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
  );

  String get rolLabel {
    switch (rol) {
      case 'super_admin':   return 'Super Admin';
      case 'administrador': return 'Administrador';
      case 'vendedor':      return 'Vendedor';
      case 'operador_cnc':  return 'Operador CNC';
      case 'almacenista':   return 'Almacenista';
      case 'contador':      return 'Contador';
      default:              return rol;
    }
  }

  String get rolEmoji {
    switch (rol) {
      case 'super_admin':   return '👑';
      case 'administrador': return '🔑';
      case 'vendedor':      return '💼';
      case 'operador_cnc':  return '⚙️';
      case 'almacenista':   return '📦';
      case 'contador':      return '💰';
      default:              return '👤';
    }
  }

  Color rolColor(BuildContext context) {
    switch (rol) {
      case 'super_admin':   return const Color(0xFF7c3aed);
      case 'administrador': return AppColors.azul;
      case 'vendedor':      return AppColors.verde;
      case 'operador_cnc':  return AppColors.ambar;
      case 'almacenista':   return const Color(0xFF92400e);
      case 'contador':      return AppColors.rojo;
      default:              return AppColors.textoSecundario;
    }
  }
}

// ══════════════════════════════════════════════════════
// PERMISOS POR ROL
// ══════════════════════════════════════════════════════
const _permisosRol = {
  'administrador': [
    '✅ Todo el sistema',
    '✅ Crear y editar usuarios',
    '✅ Ver finanzas y gastos',
    '✅ Configuración del negocio',
    '✅ Eliminar registros',
  ],
  'vendedor': [
    '✅ Cotizaciones (crear/editar/enviar)',
    '✅ Clientes y CRM',
    '✅ Ver pedidos',
    '✅ Alertas y seguimiento',
    '✅ Marketing y campañas',
    '❌ Finanzas y gastos',
    '❌ Configuración',
  ],
  'operador_cnc': [
    '✅ Ver pedidos asignados',
    '✅ Actualizar etapas de producción',
    '✅ Ver inventario de materiales',
    '❌ Cotizaciones',
    '❌ Clientes',
    '❌ Finanzas',
  ],
  'almacenista': [
    '✅ Inventario completo',
    '✅ Entradas y salidas de material',
    '✅ Ver pedidos (solo materiales)',
    '❌ Cotizaciones',
    '❌ Clientes',
    '❌ Finanzas',
  ],
  'contador': [
    '✅ Gastos e ingresos',
    '✅ Dashboard financiero',
    '✅ Exportar reportes',
    '✅ Ver cotizaciones (solo montos)',
    '❌ Editar cotizaciones',
    '❌ Clientes',
  ],
};

// ══════════════════════════════════════════════════════
// PANTALLA PRINCIPAL
// ══════════════════════════════════════════════════════
class EquipoScreen extends StatefulWidget {
  const EquipoScreen({super.key});
  @override
  State<EquipoScreen> createState() => _EquipoScreenState();
}

class _EquipoScreenState extends State<EquipoScreen> {
  List<UsuarioNegocio> _usuarios = [];
  List<Map<String, dynamic>> _invitacionesPendientes = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarInvitaciones();
  }

  Future<void> _cargarInvitaciones() async {
    final data = await AuthService.listarInvitacionesPendientes();
    if (mounted) setState(() => _invitacionesPendientes = data);
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await AuthService.getUsuariosNegocio();
      if (mounted) setState(() {
        _usuarios = data.map((j) => UsuarioNegocio.fromJson(j)).toList();
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = AuthService.esAdmin;

    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(tr('Mi equipo'),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
        actions: [
          if (esAdmin)
            TextButton.icon(
              onPressed: _invitarUsuario,
              icon: const Icon(Icons.person_add_outlined, color: AppColors.azul, size: 18),
              label: Text(tr('Invitar'), style: TextStyle(color: AppColors.azul, fontWeight: FontWeight.w600))),
        ]),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _cargar,
            child: ListView(padding: const EdgeInsets.all(14), children: [

              // ── Mi perfil ──
              _seccion(tr('MI PERFIL')),
              _cardMiPerfil(),
              const SizedBox(height: 16),

              // ── Equipo ──
              _seccion(trf('EQUIPO DEL TALLER ({0})', [(_usuarios.length)])),
              if (_usuarios.isEmpty)
                _cardVacio()
              else
                ..._usuarios.map((u) => _cardUsuario(u, esAdmin)),

              // ── Invitaciones pendientes (solo admin) ──
              if (esAdmin && _invitacionesPendientes.isNotEmpty) ...[
                const SizedBox(height: 16),
                _seccion(trf('INVITACIONES PENDIENTES ({0})', [(_invitacionesPendientes.length)])),
                ..._invitacionesPendientes.map((inv) => _cardInvitacionPendiente(inv)),
              ],

              const SizedBox(height: 16),

              // ── Roles y permisos (info) ──
              _seccion(tr('ROLES Y PERMISOS')),
              _cardRolesInfo(),

              const SizedBox(height: 20),
            ])));
  }

  // ── Tarjeta de invitación pendiente ──────────────────
  Widget _cardInvitacionPendiente(Map<String, dynamic> inv) {
    final uTmp = UsuarioNegocio(id:'', userId:'', negocioId:'', rol: inv['rol'] as String);
    final codigo = inv['codigo'] as String;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.ambar.withOpacity(0.4))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(8)),
          child: Text(tr(codigo), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
            letterSpacing: 2, color: AppColors.azul, fontFamily: 'monospace'))),
        const SizedBox(width: 10),
        Expanded(child: Text('${uTmp.rolEmoji} ${tr(uTmp.rolLabel)}',
          style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario))),
        IconButton(
          onPressed: () async {
            await AuthService.cancelarInvitacion(inv['id'] as String);
            _cargarInvitaciones();
          },
          icon: const Icon(Icons.close, size: 18, color: AppColors.rojo)),
      ]));
  }

  // ── Mi perfil ──────────────────────────────────────
  Widget _cardMiPerfil() {
    final nombre = AuthService.nombreUsuario ?? tr('Usuario');
    final rol = AuthService.rol ?? '';
    final correo = AuthService.usuarioActual?.email ?? '';
    final usu = UsuarioNegocio(
      id: '', userId: '', negocioId: '',
      rol: rol, nombre: nombre, correo: correo);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.azul, Color(0xFF2d5a8e)]),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        _avatar(nombre, usu.rolColor(context), size: 50),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(nombre), style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(tr(correo), style: const TextStyle(
            fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20)),
            child: Text('${usu.rolEmoji} ${tr(usu.rolLabel)}',
              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600))),
        ])),
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
          onPressed: () => _editarPerfil(nombre)),
      ]));
  }

  // ── Card usuario ────────────────────────────────────
  Widget _cardUsuario(UsuarioNegocio u, bool esAdmin) {
    final esMismoUsuario = u.userId == AuthService.usuarioActual?.id;
    final color = u.rolColor(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: u.activo ? Colors.white : AppColors.gris,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: u.activo ? AppColors.grisBorde : AppColors.grisBorde,
          width: 0.5),
        boxShadow: u.activo ? [BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 6, offset: const Offset(0, 2))] : null),
      child: Row(children: [
        Stack(children: [
          _avatar(u.nombre ?? u.correo ?? '?', color),
          if (!u.activo)
            Positioned(bottom: 0, right: 0,
              child: Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  color: AppColors.rojo, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5)),
                child: const Icon(Icons.close, size: 8, color: Colors.white))),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(tr(u.nombre ?? tr('Sin nombre')), style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: u.activo ? AppColors.textoPrincipal : AppColors.textoSecundario)),
            if (esMismoUsuario) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.azulClaro,
                  borderRadius: BorderRadius.circular(10)),
                child: Text(tr('Tú'), style: TextStyle(fontSize: 9, color: AppColors.azul, fontWeight: FontWeight.w700))),
            ],
          ]),
          if (u.correo != null)
            Text(tr(u.correo!), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
            child: Text('${u.rolEmoji} ${tr(u.rolLabel)}',
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))),
        ])),
        if (esAdmin && !esMismoUsuario)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textoSecundario, size: 20),
            onSelected: (accion) => _accionUsuario(accion, u),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'cambiar_rol', child: Row(children: [
                Icon(Icons.manage_accounts_outlined, size: 16), SizedBox(width: 8),
                Text(tr('Cambiar rol'), style: TextStyle(fontSize: 13)),
              ])),
              PopupMenuItem(value: u.activo ? 'desactivar' : 'activar',
                child: Row(children: [
                  Icon(u.activo ? Icons.block_outlined : Icons.check_circle_outline, size: 16,
                    color: u.activo ? AppColors.rojo : AppColors.verde),
                  const SizedBox(width: 8),
                  Text(tr(u.activo ? tr('Desactivar') : tr('Activar')),
                    style: TextStyle(fontSize: 13, color: u.activo ? AppColors.rojo : AppColors.verde)),
                ])),
            ]),
      ]));
  }

  Widget _cardVacio() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Column(children: [
      const Icon(Icons.group_outlined, size: 48, color: AppColors.grisBorde),
      const SizedBox(height: 12),
      Text(tr('No hay usuarios registrados'),
        style: TextStyle(fontSize: 14, color: AppColors.textoSecundario)),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: _invitarUsuario,
        icon: const Icon(Icons.person_add_outlined, size: 16),
        label: Text(tr('Invitar primer usuario'))),
    ]));

  // ── Roles info ──────────────────────────────────────
  Widget _cardRolesInfo() {
    final roles = ['administrador', 'vendedor', 'operador_cnc', 'almacenista', 'contador'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(tr('Ver permisos por rol'),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.azul)),
        leading: const Icon(Icons.shield_outlined, color: AppColors.azul),
        children: roles.map((rol) {
          final uTmp = UsuarioNegocio(id:'', userId:'', negocioId:'', rol: rol);
          final color = uTmp.rolColor(context);
          final permisos = _permisosRol[rol] ?? [];
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.15))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${uTmp.rolEmoji} ${tr(uTmp.rolLabel)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 8),
              ...permisos.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(tr(p), style: const TextStyle(fontSize: 12, color: AppColors.textoPrincipal)))),
            ]));
        }).toList()));
  }

  // ── INVITAR USUARIO (por código, sin Supabase Dashboard) ──
  void _invitarUsuario() {
    // Límite de usuarios del plan (activos + invitaciones sin usar)
    final limite = Planes.usuarios[AuthService.planActual];
    final ocupados = _usuarios.where((u) => u.activo).length + _invitacionesPendientes.length;
    if (limite != null && ocupados >= limite) {
      final siguiente = AuthService.planActual == Plan.pro ? tr('Industrial') : tr('Pro');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(trf('Tu plan {0} permite {1} {2}. Sube a {3} para agregar más.', [(Planes.nombres[AuthService.planActual]), limite, (limite == 1 ? 'usuario' : 'usuarios'), siguiente])),
        backgroundColor: AppColors.ambar,
        action: SnackBarAction(label: tr('Ver planes'), textColor: Colors.white,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen())))));
      return;
    }
    String rolSel = 'vendedor';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) =>
        Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16, right: 16, top: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(tr('Invitar a alguien al taller'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(tr('Genera un código y compártelo. La persona lo usa para crear su propia cuenta.'),
              style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
              textAlign: TextAlign.center),
            const SizedBox(height: 16),

            // Rol
            Align(alignment: Alignment.centerLeft,
              child: Text(tr('Rol que tendrá:'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6,
              children: ['vendedor','operador_cnc','almacenista','contador','administrador'].map((r) {
                final uTmp = UsuarioNegocio(id:'', userId:'', negocioId:'', rol: r);
                final sel = rolSel == r;
                final color = uTmp.rolColor(context);
                return GestureDetector(
                  onTap: () => setS(() => rolSel = r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? color : AppColors.grisBorde)),
                    child: Text('${uTmp.rolEmoji} ${tr(uTmp.rolLabel)}',
                      style: TextStyle(fontSize: 11,
                        color: sel ? Colors.white : AppColors.textoSecundario,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal))));
              }).toList()),
            const SizedBox(height: 16),

            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final resultado = await AuthService.crearInvitacion(rol: rolSel);
                  if (resultado['error'] != null) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(tr(resultado['error'] as String)),
                      backgroundColor: AppColors.rojo));
                    return;
                  }
                  final inv = resultado['data'] as Map<String, dynamic>;
                  if (mounted) _mostrarCodigoGenerado(inv['codigo'] as String, rolSel);
                  _cargarInvitaciones();
                },
                icon: const Icon(Icons.qr_code_2, color: Colors.white, size: 18),
                label: Text(tr('Generar código de invitación'),
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.azul,
                  padding: const EdgeInsets.symmetric(vertical: 12)))),
          ])))));
  }

  // ── Mostrar el código generado con opción de compartir ──
  void _mostrarCodigoGenerado(String codigo, String rol) {
    final uTmp = UsuarioNegocio(id:'', userId:'', negocioId:'', rol: rol);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('Código generado')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Rol: ${uTmp.rolEmoji} ${tr(uTmp.rolLabel)}',
            style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.azulClaro,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.azul.withOpacity(0.3))),
            child: Text(tr(codigo),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                letterSpacing: 4, color: AppColors.azul))),
          const SizedBox(height: 12),
          Text(tr('Válido por 7 días. La persona lo ingresa al crear su cuenta en la app.'),
            style: TextStyle(fontSize: 11, color: AppColors.textoSecundario),
            textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cerrar'))),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: codigo));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(tr('Código copiado'))));
            },
            icon: const Icon(Icons.copy, size: 16, color: Colors.white),
            label: Text(tr('Copiar'), style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul)),
        ]));
  }

  // ── EDITAR PERFIL
  // ── EDITAR PERFIL ───────────────────────────────────
  void _editarPerfil(String nombreActual) {
    final ctrl = TextEditingController(text: nombreActual);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('Editar mi nombre')),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: tr('Nombre completo'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancelar'))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Actualizar en usuarios_negocio
              try {
                final sb = await AuthService.getUsuariosNegocio();
                final mio = sb.firstWhere((u) => u['user_id'] == AuthService.usuarioActual?.id);
                await AuthService.registrarUsuarioEnNegocio(
                  userId: mio['user_id'],
                  nombre: ctrl.text.trim(),
                  correo: mio['correo'] ?? '',
                  rol: mio['rol']);
                _cargar();
              } catch (_) {}
            },
            child: Text(tr('Guardar'))),
        ]));
  }

  // ── ACCIONES SOBRE USUARIO ──────────────────────────
  void _accionUsuario(String accion, UsuarioNegocio u) async {
    if (accion == 'cambiar_rol') {
      _cambiarRol(u);
    } else if (accion == 'desactivar') {
      final conf = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('Desactivar usuario')),
          content: Text(trf('¿Desactivar a {0}? Ya no podrá acceder a la app.', [(u.nombre ?? u.correo)])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Cancelar'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
              child: Text(tr('Desactivar'), style: TextStyle(color: Colors.white))),
          ]));
      if (conf == true) {
        await AuthService.desactivarUsuario(u.id);
        _cargar();
      }
    } else if (accion == 'activar') {
      await _activarUsuario(u.id);
      _cargar();
    }
  }

  Future<void> _activarUsuario(String id) async {
    try {
      await Supabase.instance.client
        .from('usuarios_negocio')
        .update({'activo': true})
        .eq('id', id);
    } catch (_) {}
  }

  // ── CAMBIAR ROL ─────────────────────────────────────
  void _cambiarRol(UsuarioNegocio u) {
    String rolSel = u.rol;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) =>
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(trf('Cambiar rol de {0}', [(u.nombre ?? "usuario")]),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8,
              children: ['administrador','vendedor','operador_cnc','almacenista','contador'].map((r) {
                final uTmp = UsuarioNegocio(id:'', userId:'', negocioId:'', rol: r);
                final sel = rolSel == r;
                final color = uTmp.rolColor(context);
                return GestureDetector(
                  onTap: () => setS(() => rolSel = r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? color : AppColors.grisBorde)),
                    child: Text('${uTmp.rolEmoji} ${tr(uTmp.rolLabel)}',
                      style: TextStyle(fontSize: 12,
                        color: sel ? Colors.white : AppColors.textoSecundario,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.normal))));
              }).toList()),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final error = await AuthService.actualizarRolUsuario(
                    usuarioNegocioId: u.id,
                    nuevoRol: rolSel);
                  if (error != null) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr(error)),
                        backgroundColor: AppColors.rojo));
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(tr('✅ Rol actualizado')),
                        backgroundColor: AppColors.verde));
                      _cargar();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.azul,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
                child: Text(tr('Guardar cambio'),
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
          ]))));
  }

  // ── HELPERS ─────────────────────────────────────────
  Widget _avatar(String nombre, Color color, {double size = 40}) {
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size / 4)),
      child: Center(child: Text(tr(inicial),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
          fontSize: size * 0.4))));
  }

  Widget _seccion(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(tr(titulo), style: const TextStyle(
      fontSize: 10, fontWeight: FontWeight.w700,
      color: AppColors.textoSecundario, letterSpacing: 1.5)));
}
