// ============================================
// lib/main.dart
// HETNA CNC - Punto de entrada
// ============================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/notificaciones_service.dart';
import 'screens/home_screen.dart';

// ─── CONFIGURAR SUPABASE ─────────────────────
// Credenciales inyectadas automáticamente por GitHub Actions
// NO cambies estos valores manualmente — usa GitHub Secrets:
//   SUPABASE_URL = https://ldfmkfbhcbsbecfbzsny.supabase.co
//   SUPABASE_ANON_KEY = tu publishable key (sb_publishable_...)
const supabaseUrl = 'https://TU_PROYECTO.supabase.co';
const supabaseKey = 'TU_ANON_KEY';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  // Inicializar notificaciones locales
  await NotificacionesService.inicializar();

  runApp(const HetnaCncApp());
}

class HetnaCncApp extends StatelessWidget {
  const HetnaCncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HETNA CNC',
      debugShowCheckedModeBanner: false,
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
      home: const HomeScreen(),
    );
  }
}

// Colores globales de la app
class AppColors {
  static const azul = Color(0xFF1a3a5c);
  static const azulClaro = Color(0xFFe6f1fb);
  static const verde = Color(0xFF1d9e75);
  static const verdeClaro = Color(0xFFe1f5ee);
  static const ambar = Color(0xFFef9f27);
  static const ambarClaro = Color(0xFFfaeeda);
  static const rojo = Color(0xFFe24b4a);
  static const rojoClaro = Color(0xFFfcebeb);
  static const gris = Color(0xFFf5f6fa);
  static const grisBorde = Color(0xFFE5E7EB);
  static const textoSecundario = Color(0xFF6B7280);
  static const whatsapp = Color(0xFF25D366);
}
