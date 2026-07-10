// lib/services/auth_service.dart
// HETNA CNC — Autenticación y roles con Supabase Auth
import 'package:flutter/material.dart';
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
  static String? _plan;
  static DateTime? _trialHasta;
  static String? _nombreUsuario;

  static String? get negocioId     => _negocioId;
  static String? get rol           => _rol;
  static String? get plan          => _plan;

  // ── Sistema de planes: master/premium siempre activo, trial mientras
  //    no venza, gratis o trial vencido = funciones limitadas ──
  static bool get esPremiumActivo {
    if (_plan == 'master' || _plan == 'premium') return true;
    if (_plan == 'trial' && _trialHasta != null) {
      return DateTime.now().isBefore(_trialHasta!);
    }
    return false;
  }

  static bool get trialVencido =>
    _plan == 'trial' && _trialHasta != null && DateTime.now().isAfter(_trialHasta!);

  static int get diasTrialRestantes {
    if (_plan != 'trial' || _trialHasta == null) return 0;
    final dias = _trialHasta!.difference(DateTime.now()).inDays;
    return dias < 0 ? 0 : dias;
  }
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
      // Usamos lista en vez de maybeSingle() para no fallar si hay filas
      // duplicadas (de registros anteriores). Tomamos la más reciente.
      final rows = await _sb
          .from('usuarios_negocio')
          .select('negocio_id, rol, nombre')
          .eq('user_id', uid)
          .eq('activo', true)
          .order('id', ascending: false)
          .limit(1);
      final list = rows as List;
      if (list.isNotEmpty) {
        final data = list.first as Map<String, dynamic>;
        _negocioId     = data['negocio_id'] as String?;
        _rol           = data['rol'] as String?;
        _nombreUsuario = data['nombre'] as String?;
      }

      // Cargar el plan del taller (master/trial/gratis/premium) + vencimiento
      if (_negocioId != null) {
        try {
          final negocio = await _sb.from('negocios')
            .select('plan, trial_hasta')
            .eq('id', _negocioId!)
            .maybeSingle();
          if (negocio != null) {
            _plan = negocio['plan'] as String?;
            _trialHasta = negocio['trial_hasta'] != null
              ? DateTime.tryParse(negocio['trial_hasta'])
              : null;
          }
        } catch (e) {
          print('AuthService: error cargando plan: $e');
        }
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
    _plan          = null;
    _trialHasta    = null;
    await _sb.auth.signOut();
  }

  // ── Verifica si puede usar una función premium.
  //    Si no puede, muestra un aviso con opción de continuar como está.
  //    Devuelve true si puede continuar (premium activo). ──
  static Future<bool> exigirPremium(BuildContext context, {String funcion = 'esta función'}) async {
    if (esPremiumActivo) return true;

    final esTrialVencido = trialVencido;
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.lock_outline, color: Colors.amber),
        const SizedBox(width: 8),
        const Expanded(child: Text('Función Premium', style: TextStyle(fontSize: 16))),
      ]),
      content: Text(esTrialVencido
        ? 'Tu prueba gratuita de 1 mes terminó. Para seguir usando $funcion, actualiza tu plan.'
        : 'Para usar $funcion necesitas el plan Premium.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
          child: const Text('Ver planes', style: TextStyle(color: Colors.white))),
      ]));
    return false;
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
      // Upsert: si ya existe la fila del usuario, actualiza en vez de duplicar
      await _sb.from('usuarios_negocio').upsert({
        'user_id'   : userId,
        'negocio_id': _negocioId,
        'rol'       : rol,
        'nombre'    : nombre,
        'correo'    : correo,
        'activo'    : true,
      }, onConflict: 'user_id');
      return null;
    } catch (e) {
      return 'Error: $e';
    }
  }

  // ── Actualizar solo el ROL de un usuario existente (por id de fila) ──
  static Future<String?> actualizarRolUsuario({
    required String usuarioNegocioId,
    required String nuevoRol,
  }) async {
    try {
      await _sb.from('usuarios_negocio')
        .update({'rol': nuevoRol}).eq('id', usuarioNegocioId);
      return null;
    } catch (e) {
      return 'Error: $e';
    }
  }

  // ══════════════════════════════════════════════════════
  // SISTEMA DE INVITACIONES DE EQUIPO (dinámico, sin Supabase Dashboard)
  // ══════════════════════════════════════════════════════

  // Generar código corto legible (6 caracteres)
  static String _generarCodigo() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sin O/0/I/1 confusos
    final rnd = DateTime.now().microsecondsSinceEpoch;
    var seed = rnd;
    final buf = StringBuffer();
    for (int i = 0; i < 6; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      buf.write(chars[seed % chars.length]);
    }
    return buf.toString();
  }

  // Admin genera una invitación con rol asignado
  // Devuelve el mapa con la invitación en 'data', o el error en 'error'
  static Future<Map<String, dynamic>> crearInvitacion({
    required String rol,
    String? nombreSugerido,
    String? correoSugerido,
  }) async {
    if (_negocioId == null) {
      return {'error': 'No se detectó tu taller activo. Cierra sesión y vuelve a entrar.'};
    }
    try {
      String codigo = _generarCodigo();
      for (int intento = 0; intento < 3; intento++) {
        final existe = await _sb.from('invitaciones_equipo')
          .select('id').eq('codigo', codigo).maybeSingle();
        if (existe == null) break;
        codigo = _generarCodigo();
      }
      final data = await _sb.from('invitaciones_equipo').insert({
        'negocio_id': _negocioId,
        'codigo': codigo,
        'rol': rol,
        'nombre_sugerido': nombreSugerido,
        'correo_sugerido': correoSugerido,
        'creado_por': usuarioActual?.id,
      }).select().single();
      return {'data': data};
    } catch (e) {
      print('crearInvitacion error: $e');
      return {'error': 'No se pudo generar la invitación: $e'};
    }
  }

  // Listar invitaciones pendientes (no usadas) del negocio
  static Future<List<Map<String, dynamic>>> listarInvitacionesPendientes() async {
    if (_negocioId == null) return [];
    try {
      final data = await _sb.from('invitaciones_equipo')
        .select()
        .eq('negocio_id', _negocioId!)
        .eq('usado', false)
        .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  // Cancelar/eliminar una invitación pendiente
  static Future<void> cancelarInvitacion(String id) async {
    try {
      await _sb.from('invitaciones_equipo').delete().eq('id', id);
    } catch (_) {}
  }

  // ── Nuevo usuario: crear cuenta + canjear código de invitación ──
  static Future<AuthResult> crearCuentaConInvitacion({
    required String codigo,
    required String nombre,
    required String correo,
    required String password,
  }) async {
    try {
      final codigoLimpio = codigo.trim().toUpperCase();

      // 1. Validar que el código existe y no ha sido usado
      final inv = await _sb.from('invitaciones_equipo')
        .select().eq('codigo', codigoLimpio).maybeSingle();

      if (inv == null) {
        return AuthResult.error('Código de invitación no válido');
      }
      if (inv['usado'] == true) {
        return AuthResult.error('Este código ya fue utilizado');
      }
      final expiresAt = DateTime.tryParse(inv['expires_at'] ?? '');
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        return AuthResult.error('Este código de invitación expiró');
      }

      // 2. Crear la cuenta en Supabase Auth
      final res = await _sb.auth.signUp(email: correo, password: password);
      if (res.user == null) {
        return AuthResult.error('No se pudo crear la cuenta');
      }
      final uid = res.user!.id;

      // 3. Vincular al negocio con el rol de la invitación
      await _sb.from('usuarios_negocio').insert({
        'user_id'   : uid,
        'negocio_id': inv['negocio_id'],
        'rol'       : inv['rol'],
        'nombre'    : nombre,
        'correo'    : correo,
        'activo'    : true,
      });

      // 4. Marcar invitación como usada
      await _sb.from('invitaciones_equipo').update({
        'usado': true,
        'usado_por': uid,
      }).eq('id', inv['id']);

      // 5. Cargar el perfil recién creado en memoria
      await _cargarPerfil();
      if (_negocioId == null) {
        return AuthResult.error('La cuenta se creó pero no se pudo vincular al taller. Contacta al administrador.');
      }
      return AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.error(_traducirError(e.message));
    } catch (e) {
      return AuthResult.error('Error al crear la cuenta: $e');
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
