// ============================================
// lib/main.dart
// HETNA CNC - Punto de entrada
// ============================================

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/fcm_service.dart';
import 'firebase_options.dart';
import 'services/notificaciones_service.dart';
import 'screens/home_screen.dart';
import 'screens/nueva_password_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/billing_service.dart';

const supabaseUrl = 'https://ldfmkfbhcbsbecfbzsny.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxkZm1rZmJoY2JzYmVjZmJ6c255Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE3MTU5NzEsImV4cCI6MjA5NzI5MTk3MX0.N6KsmCz_HeHdc921VQflXJywgU2ctAON7wLSZViCEc4';

// Se activa cuando el usuario toca el enlace de "recuperar contraseña"
// desde su correo y regresa a la app.
final ValueNotifier<bool> mostrarRecuperarPass = ValueNotifier(false);

// Idioma actual de la app. Empieza en español; se actualiza desde
// Configuración y se guarda en el dispositivo para recordarlo.
final ValueNotifier<Locale> idiomaActual = ValueNotifier(const Locale('es', 'MX'));

Future<void> cambiarIdioma(String codigo) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('idioma', codigo);
  idiomaActual.value = codigo == 'en' ? const Locale('en') : const Locale('es', 'MX');
}

Future<void> _cargarIdiomaGuardado() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final codigo = prefs.getString('idioma');
    if (codigo == 'en') idiomaActual.value = const Locale('en');
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  await _cargarIdiomaGuardado();

  // Google Play Billing — no bloquea el arranque si falla
  // (ej. no está disponible en Web, o no hay Play Console configurado aún)
  try {
    await BillingService.inicializar();
  } catch (e) {
    print('BillingService no disponible: $e');
  }
  await initializeDateFormatting('es_MX', null);

  // Escuchar el evento de recuperación de contraseña ANTES de correr la app,
  // para no perdernos el evento si la app abre recién desde el enlace del correo.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      mostrarRecuperarPass.value = true;
    }
  });

  // Firebase FCM
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
    await FcmService.inicializar();
  } catch (e) {
    print('FCM no disponible: \$e');
  }

  // flutter_local_notifications no funciona en navegador — solo Android/iOS
  if (!kIsWeb) {
    try {
      await NotificacionesService.inicializar();
    } catch (e) {
      print('NotificacionesService no disponible: $e');
    }
  }
  runApp(const HetnaCncApp());
}

class HetnaCncApp extends StatelessWidget {
  const HetnaCncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: idiomaActual,
      builder: (context, locale, _) => MaterialApp(
      title: 'HETNA CNC',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'MX'),
        Locale('es'),
        Locale('en'),
      ],
      locale: locale,
      // En pantallas anchas (computadora/web) centra la app dentro de
      // un "marco" con fondo de marca, en vez de estirar el diseño
      // móvil a lo ancho de toda la pantalla — se ve mucho más
      // profesional / ejecutivo. El ancho se adapta a la pantalla
      // (entre 700 y 1000px) en vez de un tamaño fijo.
      builder: (context, child) {
        if (child == null) return const SizedBox();
        if (!kIsWeb) return child;
        return LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth <= 760) return child;
          final anchoMarco = (constraints.maxWidth * 0.65).clamp(700.0, 1000.0);
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0f2438), Color(0xFF1a3a5c)])),
            child: Center(
              child: Container(
                width: anchoMarco,
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight - 48,
                  minHeight: 640,
                ),
                margin: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 40, offset: const Offset(0, 20))]),
                clipBehavior: Clip.antiAlias,
                child: child)));
        });
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1a3a5c),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1a3a5c),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF1a3a5c),
            fontSize: 17,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFFf5f6fa),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1a3a5c),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1a3a5c), width: 1),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
      ),
      home: ValueListenableBuilder<bool>(
        valueListenable: mostrarRecuperarPass,
        builder: (_, mostrar, __) =>
          mostrar ? const NuevaPasswordScreen() : const AuthGate()),
    ));
  }
}

// ─── COLORES GLOBALES ────────────────────────
class AppColors {
  static const azul           = Color(0xFF1a3a5c);
  static const azulClaro      = Color(0xFFe6f1fb);
  static const verde          = Color(0xFF1d9e75);
  static const verdeClaro     = Color(0xFFe1f5ee);
  static const ambar          = Color(0xFFef9f27);
  static const ambarClaro     = Color(0xFFfaeeda);
  static const naranja        = Color(0xFFD97706);
  static const naranjaClaro   = Color(0xFFFFF3CD);
  static const rojo           = Color(0xFFe24b4a);
  static const rojoClaro      = Color(0xFFfcebeb);
  static const gris           = Color(0xFFf5f6fa);
  static const grisBorde      = Color(0xFFE5E7EB);
  static const textoSecundario= Color(0xFF6B7280);
  static const textoPrincipal = Color(0xFF111827);
  static const whatsapp       = Color(0xFF25D366);
}

// ════════════════════════════════════════════════════════════
// AuthGate — el "portero" de la app.
//
// Antes, la app abría directo en HomeScreen sin revisar si de
// verdad había una sesión activa. Eso causaba que, cuando Android
// mata la app en segundo plano (algo normal en celulares con poca
// memoria) y la vuelves a abrir, la app se veía "deslogueada"
// aunque Supabase SÍ recordaba la sesión — porque nadie recargaba
// el negocio/rol/plan del usuario en memoria.
//
// AuthGate revisa la sesión real de Supabase cada vez que la app
// arranca (o cada vez que cambia el estado de sesión), y solo
// entonces decide: ¿Login o Home?
// ════════════════════════════════════════════════════════════
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _cargando = true;
  bool _autenticado = false;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _revisarSesion();

    // Reacciona en vivo si el usuario inicia o cierra sesión
    // mientras la app está abierta (sin necesidad de reiniciarla)
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // Muy importante: el enlace de "recuperar contraseña" también
      // crea una sesión temporal, y eso dispara este mismo stream de
      // eventos. Si no la ignoramos aquí, el portero cree que es un
      // login normal y manda a la app en vez de dejar pasar la
      // pantalla de "Nueva contraseña".
      if (data.event == AuthChangeEvent.passwordRecovery) return;

      if (data.event == AuthChangeEvent.signedIn) {
        _revisarSesion();
      }
      if (data.event == AuthChangeEvent.signedOut) {
        if (mounted) setState(() { _autenticado = false; _cargando = false; });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _revisarSesion() async {
    final sesion = Supabase.instance.client.auth.currentSession;
    if (sesion == null) {
      if (mounted) setState(() { _autenticado = false; _cargando = false; });
      return;
    }
    // Hay sesión válida de Supabase — recargar negocio/rol/plan
    // antes de mostrar la app (esto es lo que antes faltaba)
    await AuthService.refrescarPerfil();
    if (mounted) setState(() { _autenticado = true; _cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: AppColors.gris,
        body: Center(child: CircularProgressIndicator()));
    }
    return _autenticado ? const HomeScreen() : const LoginScreen();
  }
}
