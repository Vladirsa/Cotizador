// ============================================
// lib/main.dart
// HETNA CNC - Punto de entrada
// ============================================

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/notificaciones_service.dart';
import 'screens/home_screen.dart';

const supabaseUrl = 'https://ldfmkfbhcbsbecfbzsny.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxkZm1rZmJoY2JzYmVjZmJ6c255Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE3MTU5NzEsImV4cCI6MjA5NzI5MTk3MX0.N6KsmCz_HeHdc921VQflXJywgU2ctAON7wLSZViCEc4';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  await initializeDateFormatting('es_MX', null);
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
