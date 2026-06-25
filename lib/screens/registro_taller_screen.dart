// lib/screens/registro_taller_screen.dart
// HETNA CNC — Onboarding: registro de nuevos talleres
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class RegistroTallerScreen extends StatefulWidget {
  const RegistroTallerScreen({super.key});
  @override
  State<RegistroTallerScreen> createState() => _RegistroTallerScreenState();
}

class _RegistroTallerScreenState extends State<RegistroTallerScreen> {
  final _pageCtrl = PageController();
  int _paso = 0;
  final _totalPasos = 4;

  // Datos del formulario
  String _codigo = '';
  String _nombreTaller = '';
  String _giro = 'CNC / Manufactura';
  String _telefono = '';
  String _nombreAdmin = '';
  String _correo = '';
  String _password = '';
  String _passwordConfirm = '';

  bool _cargando = false;
  bool _verPassword = false;
  String? _error;

  final _sb = Supabase.instance.client;

  final _giros = [
    'CNC / Manufactura',
    'Carpintería',
    'Herrería',
    'Diseño y corte laser',
    'Impresión 3D',
    'Taller múltiple',
    'Otro',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      body: SafeArea(child: Column(children: [
        _headerPasos(),
        Expanded(child: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _paso0Codigo(),
            _paso1DatosTaller(),
            _paso2DatosAdmin(),
            _paso3Confirmacion(),
          ])),
      ])),
    );
  }

  // ── HEADER PASOS ────────────────────────────────────
  Widget _headerPasos() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        if (_paso > 0)
          GestureDetector(
            onTap: _pasoAnterior,
            child: const Row(children: [
              Icon(Icons.arrow_back_ios, size: 14, color: AppColors.azul),
              Text('Atrás', style: TextStyle(fontSize: 13, color: AppColors.azul)),
            ]))
        else
          const SizedBox(width: 60),
        Text('Paso ${_paso + 1} de $_totalPasos',
          style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
        const SizedBox(width: 60),
      ]),
      const SizedBox(height: 10),
      // Barra de progreso
      Row(children: List.generate(_totalPasos, (i) => Expanded(
        child: Container(
          height: 4,
          margin: EdgeInsets.only(right: i < _totalPasos - 1 ? 4 : 0),
          decoration: BoxDecoration(
            color: i <= _paso ? AppColors.azul : AppColors.grisBorde,
            borderRadius: BorderRadius.circular(2)))))),
    ]));

  // ── PASO 0: CÓDIGO DE INVITACIÓN ────────────────────
  Widget _paso0Codigo() => _wrapPaso(
    titulo: '¡Bienvenido!',
    subtitulo: 'Ingresa tu código de acceso beta para crear tu taller.',
    icon: '🎟️',
    child: Column(children: [
      TextField(
        textCapitalization: TextCapitalization.characters,
        onChanged: (v) => setState(() => _codigo = v.toUpperCase()),
        decoration: InputDecoration(
          labelText: 'Código de acceso beta',
          hintText: 'HETNA-BETA-001',
          prefixIcon: const Icon(Icons.vpn_key_outlined, color: AppColors.azul),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.grisBorde))),
        style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.w600)),
      if (_error != null) ...[
        const SizedBox(height: 10),
        _widgetError(_error!),
      ],
      const SizedBox(height: 16),
      _btnPrimario('Verificar código', _validarCodigo),
      const SizedBox(height: 16),
      const Divider(),
      const SizedBox(height: 8),
      const Text('¿Ya tienes cuenta?',
        style: TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.azul),
          minimumSize: const Size(double.infinity, 44)),
        child: const Text('Iniciar sesión',
          style: TextStyle(color: AppColors.azul, fontWeight: FontWeight.w600))),
    ]));

  // ── PASO 1: DATOS DEL TALLER ────────────────────────
  Widget _paso1DatosTaller() => _wrapPaso(
    titulo: 'Tu taller',
    subtitulo: 'Información básica de tu negocio.',
    icon: '🏭',
    child: Column(children: [
      _campo('Nombre del taller *', (v) => _nombreTaller = v,
        hint: 'Ej: Taller CNC García', icon: Icons.storefront_outlined),
      const SizedBox(height: 12),
      // Giro
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Giro del negocio *',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.textoPrincipal)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6,
          children: _giros.map((g) => GestureDetector(
            onTap: () => setState(() => _giro = g),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _giro == g ? AppColors.azul : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _giro == g ? AppColors.azul : AppColors.grisBorde)),
              child: Text(g, style: TextStyle(
                fontSize: 11,
                color: _giro == g ? Colors.white : AppColors.textoSecundario,
                fontWeight: _giro == g ? FontWeight.w600 : FontWeight.normal))))).toList()),
      ]),
      const SizedBox(height: 12),
      _campo('Teléfono / WhatsApp', (v) => _telefono = v,
        hint: '246 121 7072', icon: Icons.phone_outlined,
        tipo: TextInputType.phone),
      if (_error != null) ...[const SizedBox(height: 10), _widgetError(_error!)],
      const SizedBox(height: 16),
      _btnPrimario('Continuar', _validarPaso1),
    ]));

  // ── PASO 2: DATOS DEL ADMINISTRADOR ─────────────────
  Widget _paso2DatosAdmin() => _wrapPaso(
    titulo: 'Tu cuenta',
    subtitulo: 'Crea tu acceso de administrador.',
    icon: '👤',
    child: Column(children: [
      _campo('Nombre completo *', (v) => _nombreAdmin = v,
        hint: 'Ej: Juan García', icon: Icons.person_outline,
        capitalizar: TextCapitalization.words),
      const SizedBox(height: 12),
      _campo('Correo electrónico *', (v) => _correo = v,
        hint: 'correo@ejemplo.com', icon: Icons.email_outlined,
        tipo: TextInputType.emailAddress),
      const SizedBox(height: 12),
      // Password
      StatefulBuilder(builder: (ctx, setS) => TextField(
        obscureText: !_verPassword,
        onChanged: (v) => _password = v,
        decoration: InputDecoration(
          labelText: 'Contraseña *',
          hintText: 'Mínimo 8 caracteres',
          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textoSecundario),
          suffixIcon: IconButton(
            icon: Icon(_verPassword
              ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.textoSecundario, size: 20),
            onPressed: () => setState(() => _verPassword = !_verPassword)),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.grisBorde))))),
      const SizedBox(height: 12),
      TextField(
        obscureText: true,
        onChanged: (v) => _passwordConfirm = v,
        decoration: InputDecoration(
          labelText: 'Confirmar contraseña *',
          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textoSecundario),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.grisBorde)))),
      if (_error != null) ...[const SizedBox(height: 10), _widgetError(_error!)],
      const SizedBox(height: 16),
      _btnPrimario('Crear mi taller', _registrar),
    ]));

  // ── PASO 3: CONFIRMACIÓN ─────────────────────────────
  Widget _paso3Confirmacion() => _wrapPaso(
    titulo: '¡Listo!',
    subtitulo: 'Tu taller ha sido creado exitosamente.',
    icon: '🎉',
    child: Column(children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.verde.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.verde.withOpacity(0.3))),
        child: Column(children: [
          const Icon(Icons.check_circle_outline, color: AppColors.verde, size: 56),
          const SizedBox(height: 12),
          Text(_nombreTaller,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
              color: AppColors.azul), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(_giro, style: const TextStyle(
            fontSize: 13, color: AppColors.textoSecundario)),
          const SizedBox(height: 16),
          _lineaInfo('👤 Administrador', _nombreAdmin),
          _lineaInfo('📧 Correo', _correo),
          if (_telefono.isNotEmpty) _lineaInfo('📱 WhatsApp', _telefono),
        ])),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.azulClaro, borderRadius: BorderRadius.circular(10)),
        child: const Column(children: [
          Text('Lo que puedes hacer ahora:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: AppColors.azul)),
          SizedBox(height: 10),
          _ItemOnboarding('📋', 'Crea tu primera cotización'),
          _ItemOnboarding('⚙️', 'Configura tus tarifas en el simulador'),
          _ItemOnboarding('👥', 'Invita a tu equipo de trabajo'),
          _ItemOnboarding('🏭', 'Agrega tus productos al catálogo'),
        ])),
      const SizedBox(height: 20),
      _btnPrimario('Entrar a mi taller', _entrarAlApp),
    ]));

  // ── LÓGICA ───────────────────────────────────────────
  Future<void> _validarCodigo() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final result = await _sb.rpc('validar_codigo_invitacion',
        params: {'p_codigo': _codigo.trim().toUpperCase()});
      if (result['valido'] == true) {
        _siguientePaso();
      } else {
        setState(() => _error = result['mensaje'] ?? 'Código inválido');
      }
    } catch (e) {
      setState(() => _error = 'Error al validar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _validarPaso1() {
    setState(() => _error = null);
    if (_nombreTaller.trim().isEmpty) {
      setState(() => _error = 'El nombre del taller es obligatorio');
      return;
    }
    _siguientePaso();
  }

  Future<void> _registrar() async {
    setState(() { _error = null; _cargando = true; });

    // Validaciones
    if (_nombreAdmin.trim().isEmpty || _correo.trim().isEmpty || _password.isEmpty) {
      setState(() { _error = 'Todos los campos con * son obligatorios'; _cargando = false; });
      return;
    }
    if (!_correo.contains('@')) {
      setState(() { _error = 'Correo electrónico inválido'; _cargando = false; });
      return;
    }
    if (_password.length < 8) {
      setState(() { _error = 'La contraseña debe tener mínimo 8 caracteres'; _cargando = false; });
      return;
    }
    if (_password != _passwordConfirm) {
      setState(() { _error = 'Las contraseñas no coinciden'; _cargando = false; });
      return;
    }

    try {
      // 1. Crear usuario en Supabase Auth
      final authResult = await _sb.auth.signUp(
        email: _correo.trim(),
        password: _password,
        data: {'nombre': _nombreAdmin.trim()});

      if (authResult.user == null) {
        setState(() { _error = 'Error al crear la cuenta. Intenta con otro correo.'; _cargando = false; });
        return;
      }

      final userId = authResult.user!.id;

      // 2. Crear negocio + usuario administrador via función SQL
      final result = await _sb.rpc('registrar_taller', params: {
        'p_user_id': userId,
        'p_nombre_taller': _nombreTaller.trim(),
        'p_giro': _giro,
        'p_correo': _correo.trim(),
        'p_nombre_admin': _nombreAdmin.trim(),
        'p_telefono': _telefono.trim().isEmpty ? null : _telefono.trim(),
      });

      if (result['error'] != null) {
        setState(() { _error = result['error']; _cargando = false; });
        return;
      }

      // 3. Marcar código como usado
      final negocioId = result['negocio_id'];
      await _sb.rpc('usar_codigo_invitacion', params: {
        'p_codigo': _codigo.trim().toUpperCase(),
        'p_negocio_id': negocioId,
      });

      // 4. Ir a confirmación
      _siguientePaso();

    } catch (e) {
      setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _entrarAlApp() async {
    setState(() => _cargando = true);
    try {
      // La sesión ya está activa desde el signUp
      // Solo inicializamos el AuthService
      final session = _sb.auth.currentSession;
      if (session != null) {
        await AuthService.cargarPerfil();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (_) => false);
        }
      }
    } catch (e) {
      // Si falla, regresar a login
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _siguientePaso() {
    if (_paso < _totalPasos - 1) {
      setState(() => _paso++);
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut);
    }
  }

  void _pasoAnterior() {
    if (_paso > 0) {
      setState(() => _paso--);
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut);
    }
  }

  // ── WIDGETS HELPERS ─────────────────────────────────
  Widget _wrapPaso({
    required String titulo, required String subtitulo,
    required String icon, required Widget child,
  }) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 40)),
      const SizedBox(height: 12),
      Text(titulo, style: const TextStyle(
        fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.azul)),
      const SizedBox(height: 6),
      Text(subtitulo, style: const TextStyle(
        fontSize: 14, color: AppColors.textoSecundario, height: 1.4)),
      const SizedBox(height: 24),
      child,
    ]));

  Widget _campo(String label, void Function(String) onChange, {
    String? hint, IconData? icon,
    TextInputType tipo = TextInputType.text,
    TextCapitalization capitalizar = TextCapitalization.none,
  }) => TextField(
    keyboardType: tipo,
    textCapitalization: capitalizar,
    onChanged: onChange,
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: AppColors.textoSecundario, size: 20) : null,
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.grisBorde))));

  Widget _btnPrimario(String texto, VoidCallback onTap) =>
    SizedBox(width: double.infinity, height: 50,
      child: ElevatedButton(
        onPressed: _cargando ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.azul,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: _cargando
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(texto, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))));

  Widget _widgetError(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.rojo.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.rojo, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: const TextStyle(
        fontSize: 12, color: AppColors.rojo))),
    ]));

  Widget _lineaInfo(String label, String valor) =>
    Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
        Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]));
}

// ── Widget auxiliar ──────────────────────────────────
class _ItemOnboarding extends StatelessWidget {
  final String emoji, texto;
  const _ItemOnboarding(this.emoji, this.texto);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      Text(texto, style: const TextStyle(fontSize: 13, color: AppColors.azul)),
    ]));
}
