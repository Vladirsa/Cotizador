// lib/services/auth_service.dart
// HETNA CNC — Autenticación y roles con Supabase Auth
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _sb = Supabase.instance.client;

  // ── Sesión actual ──────────────────────────────────────
  static User? get usuarioActual => _sb.auth.currentUser;
  static bool  get estaLogueado  => usuarioActual != null;
  static Session? get sesion     => _sb.auth.currentSession;

  // ── Datos del negocio/rol en memoria ──────────────────
  static String? _negocioId;
  static String? _rol;
  static String? _nombreUsuario;

  static String? get negocioId     => _negocioId;
  static String? get rol           => _rol;
  static String? get nombreUsuario => _nombreUsuario;

  static bool get esAdmin      => _rol == 'administrador' || _rol == 'super_admin';
  static bool get esVendedor   => _rol == 'vendedor' || esAdmin;
  static bool get esOperador   => _rol == 'operador_cnc' || esAdmin;
  static bool get esAlmacenista=> _rol == 'almacenista' || esAdmin;
  static bool get esContador   => _rol == 'contador' || esAdmin;
  static bool get esSuperAdmin => _rol == 'super_admin';

  // ── Login ──────────────────────────────────────────────
  static Future<AuthResult> login({
    required String correo,
    required String password,
  }) async {
    try {
      final res = await _sb.auth.signInWithPassword(
        email: correo,
        password: password,
      );
      if (res.user == null) return AuthResult.error('Credenciales incorrectas');
      await _cargarPerfil();
      if (_negocioId == null) {
        await _sb.auth.signOut();
        return AuthResult.error('Usuario sin negocio asignado. Contacta al administrador.');
      }
      return AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.error(_traducirError(e.message));
    } catch (e) {
      return AuthResult.error('Error de conexión. Verifica tu internet.');
    }
  }

  // ── Cargar perfil del usuario (negocio + rol) ──────────
  static Future<void> _cargarPerfil() async {
    try {
      final uid = usuarioActual?.id;
      if (uid == null) return;
      final data = await _sb
          .from('usuarios_negocio')
          .select('negocio_id, rol, nombre')
          .eq('user_id', uid)
          .eq('activo', true)
          .maybeSingle();
      if (data != null) {
        _negocioId     = data['negocio_id'] as String?;
        _rol           = data['rol'] as String?;
        _nombreUsuario = data['nombre'] as String?;
      }
    } catch (e) {
      print('AuthService._cargarPerfil error: $e');
    }
  }

  // ── Restaurar sesión al arrancar la app ───────────────
  static Future<bool> restaurarSesion() async {
    try {
      final session = _sb.auth.currentSession;
      if (session == null) return false;
      await _cargarPerfil();
      return _negocioId != null;
    } catch (_) {
      return false;
    }
  }

  // ── Logout ─────────────────────────────────────────────
  static Future<void> logout() async {
    _negocioId     = null;
    _rol           = null;
    _nombreUsuario = null;
    await _sb.auth.signOut();
  }

  // ── Cambiar contraseña ─────────────────────────────────
  static Future<String?> cambiarPassword({
    required String passwordActual,
    required String passwordNuevo,
  }) async {
    try {
      await _sb.auth.updateUser(UserAttributes(password: passwordNuevo));
      return null; // null = éxito
    } on AuthException catch (e) {
      return _traducirError(e.message);
    } catch (_) {
      return 'Error al cambiar contraseña';
    }
  }

  // ── Crear usuario en usuarios_negocio (admin only) ─────
  // Se llama después de que el admin crea la cuenta en Supabase Dashboard
  static Future<String?> registrarUsuarioEnNegocio({
    required String userId,
    required String nombre,
    required String correo,
    required String rol,
  }) async {
    try {
      if (_negocioId == null) return 'Sin negocio activo';
      await _sb.from('usuarios_negocio').insert({
        'user_id'   : userId,
        'negocio_id': _negocioId,
        'rol'       : rol,
        'nombre'    : nombre,
        'correo'    : correo,
        'activo'    : true,
      });
      return null;
    } catch (e) {
      return 'Error: $e';
    }
  }

  // ── Listar usuarios del negocio (admin) ───────────────
  static Future<List<Map<String, dynamic>>> getUsuariosNegocio() async {
    try {
      final data = await _sb
          .from('usuarios_negocio')
          .select('id, user_id, nombre, correo, rol, activo, created_at')
          .eq('negocio_id', _negocioId ?? '')
          .order('created_at');
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  // ── Desactivar usuario ────────────────────────────────
  static Future<void> desactivarUsuario(String id) async {
    await _sb.from('usuarios_negocio').update({'activo': false}).eq('id', id);
  }

  // ── Traducir errores de Supabase Auth al español ──────
  static String _traducirError(String msg) {
    if (msg.contains('Invalid login credentials')) return 'Correo o contraseña incorrectos';
    if (msg.contains('Email not confirmed'))       return 'Confirma tu correo antes de entrar';
    if (msg.contains('Too many requests'))         return 'Demasiados intentos. Espera unos minutos';
    if (msg.contains('User not found'))            return 'Usuario no encontrado';
    if (msg.contains('network'))                   return 'Sin conexión a internet';
    return msg;
  }
}

// ── Resultado de operaciones Auth ─────────────────────────
class AuthResult {
  final bool exito;
  final String? error;
  const AuthResult._(this.exito, this.error);
  factory AuthResult.ok()            => const AuthResult._(true, null);
  factory AuthResult.error(String e) => AuthResult._(false, e);
}
