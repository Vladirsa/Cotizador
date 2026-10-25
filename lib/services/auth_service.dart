// lib/services/auth_service.dart
// HETNA CNC — Autenticación y roles con Supabase Auth
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/premium_screen.dart';
import 'planes.dart';
export 'planes.dart' show Plan, Planes;

class AuthService {
  static final _sb = Supabase.instance.client;

  // ── Sesión actual ────────────────────────────────────────
  static User? get usuarioActual => _sb.auth.currentUser;
  static bool  get estaLogueado  => usuarioActual != null;
  static Session? get sesion     => _sb.auth.currentSession;

  // ── Datos del negocio/rol en memoria ──────────────────
  static String? _negocioId;
  static String? _rol;
  static String? _plan;
  static DateTime? _trialHasta;
  static Set<String> _modulosPermitidos = {};
  static bool _permisosConfigurados = false; // si el admin nunca configuró nada, no bloquear
  static String? _nombreUsuario;

  // Suscripción con Mercado Pago (las escribe sólo el servidor de hetnacnc.com)
  static String? _planEstado;   // activa | cancelada | pausada
  static DateTime? _planRenueva; // siguiente cobro
  static DateTime? _planVence;   // hasta cuándo dura lo pagado si se canceló

  static String? get planEstado    => _planEstado;
  static DateTime? get planRenueva => _planRenueva;
  static DateTime? get planVence   => _planVence;
  static bool get tieneSuscripcion => _planEstado == 'activa';

  // ── A dónde regresa el enlace de los correos ──
  // Web: la misma página del Cotizador. Android: el enlace abre la app
  // (el APK ya registra com.hetnacnc.app://reset-callback; Supabase abre la
  // sesión con cualquier enlace, sea de confirmar correo o de recuperar).
  // Las dos direcciones deben estar en Supabase > Authentication > URL
  // Configuration > Redirect URLs.
  static String get urlRegreso =>
    kIsWeb ? 'https://hetnacnc.com/cotizador/' : 'com.hetnacnc.app://reset-callback/';
  static String get urlRecuperar =>
    kIsWeb ? 'https://hetnacnc.com/cotizador/' : 'com.hetnacnc.app://reset-callback/';

  static String? get negocioId     => _negocioId;
  static String? get rol           => _rol;
  static String? get plan          => _plan;

  // ── Planes: qué abre cada uno está en services/planes.dart.
  //    Prueba vigente = todo abierto; prueba vencida = Gratis ──
  static bool get _esPrueba => _plan == 'trial' || _plan == 'prueba';

  // Plan que manda ahora (ver services/planes.dart)
  static Plan get planActual => Planes.efectivo(_plan,
    pruebaVigente: _esPrueba && _trialHasta != null && DateTime.now().isBefore(_trialHasta!));

  // ¿El plan del taller abre este módulo? (además del permiso por rol)
  static bool puede(String modulo) => Planes.abre(planActual, modulo);

  // Compatibilidad: cualquier plan de pago o prueba vigente
  static bool get esPremiumActivo => planActual.index >= Plan.taller.index;

  static bool get trialVencido =>
    _esPrueba && _trialHasta != null && DateTime.now().isAfter(_trialHasta!);

  // Módulos que el usuario actual puede ver.
  // Admin/super_admin siempre ven todo. Si el negocio nunca configuró
  // permisos para un rol, por defecto SÍ puede ver todo (no bloquea
  // por accidente talleres que no han tocado esta función).
  static bool tieneAcceso(String modulo) {
    if (esAdmin) return true;
    if (!_permisosConfigurados) return true;
    return _modulosPermitidos.contains(modulo);
  }

  static int get diasTrialRestantes {
    if (!_esPrueba || _trialHasta == null) return 0;
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
      if (e.message.contains('Email not confirmed')) {
        return AuthResult.confirmar(
          'Falta confirmar tu correo. Abre el enlace que te enviamos (revisa también spam) y vuelve a entrar.');
      }
      return AuthResult.error(_traducirError(e.message));
    } catch (e) {
      return AuthResult.error('Error de conexión. Verifica tu internet.');
    }
  }

  // ── Reenviar el correo de confirmación ─────────────────
  // Devuelve null si se envió, o el mensaje de error.
  static Future<String?> reenviarConfirmacion(String correo) async {
    try {
      await _sb.auth.resend(
        type: OtpType.signup, email: correo.trim(), emailRedirectTo: urlRegreso);
      return null;
    } on AuthException catch (e) {
      return _traducirError(e.message);
    } catch (e) {
      return 'No se pudo reenviar el correo. Intenta de nuevo en un minuto.';
    }
  }

  // ── Cargar perfil del usuario (negocio + rol) ──────────
  // Público — para refrescar el plan/rol desde fuera (ej. después de
  // una compra exitosa en BillingService)
  static Future<void> refrescarPerfil() => _cargarPerfil();

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
      var list = rows as List;

      // Se unió a un equipo con código, pero tuvo que confirmar su correo
      // antes de entrar: el código quedó guardado en su cuenta y se canjea
      // aquí, en su primer inicio de sesión.
      final pendiente = usuarioActual?.userMetadata?['invitacion'] as String?;
      if (list.isEmpty && pendiente != null && pendiente.isNotEmpty) {
        try {
          final canje = await _sb.rpc('canjear_invitacion', params: {
            'p_codigo': pendiente,
            'p_nombre': (usuarioActual?.userMetadata?['nombre'] as String?) ?? '',
            'p_correo': usuarioActual?.email ?? '',
          });
          if (canje is Map && canje['exito'] == true) {
            await _sb.auth.updateUser(UserAttributes(data: {'invitacion': null}));
            list = await _sb
                .from('usuarios_negocio')
                .select('negocio_id, rol, nombre')
                .eq('user_id', uid)
                .eq('activo', true)
                .order('id', ascending: false)
                .limit(1) as List;
          }
        } catch (e) {
          print('AuthService: no se pudo canjear la invitación pendiente: $e');
        }
      }

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
        // Aparte: si todavía no se corre suscripciones_y_correos.sql, estas
        // columnas no existen y el plan de arriba debe cargar igual.
        try {
          final s = await _sb.from('negocios')
            .select('plan_estado, plan_renueva, plan_vence')
            .eq('id', _negocioId!)
            .maybeSingle();
          _planEstado  = s?['plan_estado'] as String?;
          _planRenueva = s?['plan_renueva'] != null ? DateTime.tryParse(s!['plan_renueva']) : null;
          _planVence   = s?['plan_vence'] != null ? DateTime.tryParse(s!['plan_vence']) : null;
        } catch (_) {
          _planEstado = null; _planRenueva = null; _planVence = null;
        }
      }

      // Cargar permisos personalizados del rol actual
      if (_negocioId != null && _rol != null) {
        try {
          final permisos = await _sb.from('permisos_rol')
            .select('modulo, activo')
            .eq('negocio_id', _negocioId!)
            .eq('rol', _rol!);
          final list = permisos as List;
          if (list.isNotEmpty) {
            _permisosConfigurados = true;
            _modulosPermitidos = list
              .where((p) => p['activo'] == true)
              .map((p) => p['modulo'] as String)
              .toSet();
          } else {
            _permisosConfigurados = false;
            _modulosPermitidos = {};
          }
        } catch (e) {
          print('AuthService: error cargando permisos: $e');
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
    _planEstado    = null;
    _planRenueva   = null;
    _planVence     = null;
    _modulosPermitidos = {};
    _permisosConfigurados = false;
    await _sb.auth.signOut();
  }

  // ── Roles configurables (excluye administrador/super_admin, que
  //    siempre tienen acceso total) ──
  static const rolesConfigurables = [
    'vendedor', 'operador_cnc', 'almacenista', 'contador'
  ];

  // Todos los módulos que se pueden activar/desactivar por rol
  static const modulosDisponibles = [
    'clientes', 'productos', 'inventario', 'gastos',
    'marketing', 'equipo', 'reportes', 'config', 'simulador',
  ];

  // Leer los permisos actuales de un rol específico (para la pantalla
  // de administración, no para el usuario logueado)
  static Future<Set<String>> leerPermisosDeRol(String rol) async {
    if (_negocioId == null) return {};
    try {
      final data = await _sb.from('permisos_rol')
        .select('modulo, activo')
        .eq('negocio_id', _negocioId!)
        .eq('rol', rol);
      final list = data as List;
      return list.where((p) => p['activo'] == true)
        .map((p) => p['modulo'] as String).toSet();
    } catch (e) {
      print('leerPermisosDeRol error: $e');
      return {};
    }
  }

  // Guardar de un jalón todos los permisos de un rol (reemplaza los
  // anteriores) — se llama al tocar "Guardar" en la pantalla de permisos
  static Future<String?> guardarPermisosDeRol(String rol, Set<String> modulosActivos) async {
    if (_negocioId == null) return 'Sin negocio activo';
    try {
      // Borrar los permisos viejos del rol y escribir los nuevos
      await _sb.from('permisos_rol')
        .delete().eq('negocio_id', _negocioId!).eq('rol', rol);

      final filas = modulosDisponibles.map((m) => {
        'negocio_id': _negocioId,
        'rol': rol,
        'modulo': m,
        'activo': modulosActivos.contains(m),
      }).toList();

      await _sb.from('permisos_rol').insert(filas);

      // Si el rol que se configuró es el del usuario actual, refrescar
      if (_rol == rol) {
        _permisosConfigurados = true;
        _modulosPermitidos = modulosActivos;
      }
      return null;
    } catch (e) {
      return 'Error al guardar permisos: $e';
    }
  }

  // ── Verifica si puede usar una función premium.
  //    Si no puede, muestra un aviso con opción de continuar como está.
  //    Devuelve true si puede continuar (premium activo). ──
  static Future<bool> exigirPremium(BuildContext context, {String funcion = 'esta función'}) =>
    exigirModulo(context, 'simulador', funcion: funcion);

  // Si el plan no abre el módulo, avisa qué plan lo abre y lleva a "Ver planes".
  // Devuelve true si puede continuar.
  static Future<bool> exigirModulo(BuildContext context, String modulo, {String funcion = 'esta función'}) async {
    if (puede(modulo)) return true;
    final requerido = Planes.planMinimo(modulo);
    final nombre = Planes.nombres[requerido];
    final precio = Planes.precios[requerido];

    final esTrialVencido = trialVencido;
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.lock_outline, color: Colors.amber),
        const SizedBox(width: 8),
        Expanded(child: Text('Disponible en plan $nombre', style: const TextStyle(fontSize: 16))),
      ]),
      content: Text(esTrialVencido
        ? 'Tu prueba gratuita terminó. Para seguir usando $funcion activa el plan $nombre (\$$precio al mes).'
        : 'Para usar $funcion necesitas el plan $nombre (\$$precio al mes).'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PremiumScreen()));
          },
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

      // 1. Validar el código (función segura, funciona sin sesión iniciada)
      final validacion = await _sb.rpc('validar_invitacion',
        params: {'p_codigo': codigoLimpio});

      if (validacion['valido'] != true) {
        return AuthResult.error(validacion['mensaje'] ?? 'Código de invitación no válido');
      }

      // 2. Crear la cuenta en Supabase Auth
      // El código va guardado en la cuenta: si Supabase pide confirmar el
      // correo, aún no hay sesión para canjearlo; se canjea al primer login.
      final res = await _sb.auth.signUp(
        email: correo, password: password,
        data: {'nombre': nombre, 'invitacion': codigoLimpio},
        emailRedirectTo: urlRegreso);
      if (res.user == null) {
        return AuthResult.error('No se pudo crear la cuenta');
      }
      if (res.session == null) {
        return AuthResult.confirmar(
          'Te enviamos un correo a $correo. Ábrelo, toca "Confirmar mi correo" y luego inicia sesión: entrarás directo a tu taller.');
      }

      // 3. Canjear el código ya autenticado: vincula al taller y
      //    marca el código como usado, todo en un paso atómico
      final canje = await _sb.rpc('canjear_invitacion', params: {
        'p_codigo': codigoLimpio,
        'p_nombre': nombre,
        'p_correo': correo,
      });

      if (canje['exito'] != true) {
        return AuthResult.error(canje['mensaje'] ??
          'La cuenta se creó pero no se pudo vincular al taller. Contacta al administrador.');
      }

      // 4. Cargar el perfil recién creado en memoria
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
  /// La cuenta existe pero falta confirmar el correo (no es un error del usuario)
  final bool requiereConfirmar;
  const AuthResult._(this.exito, this.error, [this.requiereConfirmar = false]);
  factory AuthResult.ok()                => const AuthResult._(true, null);
  factory AuthResult.error(String e)     => AuthResult._(false, e);
  factory AuthResult.confirmar(String m) => AuthResult._(false, m, true);
}
