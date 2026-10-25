// lib/screens/login_screen.dart
// HETNA CNC — Pantalla de login con logo
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'registro_taller_screen.dart';
import 'unirse_equipo_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _correoCtrl = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _formKey    = GlobalKey<FormState>();
  bool _cargando    = false;
  bool _verPassword = false;
  String? _error;
  bool _requiereConfirmar = false; // la cuenta existe pero falta confirmar el correo
  bool _reenviando = false;

  // Logo HETNA CNC en base64 (PNG de 24 colores, ~10 KB)
  static const String _logoB64 = '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';

  static Uint8List get _logoBytes {
    try { return base64Decode(_logoB64); } catch (_) { return Uint8List(0); }
  }

  @override
  void dispose() {
    _correoCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _mostrarRecuperarClave() {
    final correoCtrl = TextEditingController();
    bool enviando = false;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx2, setS) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const Text('Ingresa tu correo y te enviaremos un enlace para crear una nueva contraseña.',
            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const SizedBox(height: 14),
          TextField(controller: correoCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo electrónico',
              isDense: true, border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: enviando ? null : () async {
              final correo = correoCtrl.text.trim();
              if (correo.isEmpty || !correo.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Ingresa un correo válido'), backgroundColor: AppColors.rojo));
                return;
              }
              setS(() => enviando = true);
              try {
                await Supabase.instance.client.auth.resetPasswordForEmail(
                  correo,
                  redirectTo: AuthService.urlRecuperar);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('✅ Enviamos un enlace a $correo. Revisa tu correo (y spam).'),
                  backgroundColor: AppColors.verde));
              } catch (e) {
                setS(() => enviando = false);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Error: $e'), backgroundColor: AppColors.rojo));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul),
            child: enviando
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Enviar enlace', style: TextStyle(color: Colors.white))),
        ])));
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _cargando = true; _error = null; _requiereConfirmar = false; });
    final result = await AuthService.login(
      correo: _correoCtrl.text.trim(),
      password: _passCtrl.text);
    if (!mounted) return;
    if (result.exito) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      setState(() {
        _cargando = false;
        _error = result.error;
        _requiereConfirmar = result.requiereConfirmar;
      });
    }
  }

  Future<void> _reenviarConfirmacion() async {
    final correo = _correoCtrl.text.trim();
    if (!correo.contains('@')) return;
    setState(() => _reenviando = true);
    final error = await AuthService.reenviarConfirmacion(correo);
    if (!mounted) return;
    setState(() => _reenviando = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? '✅ Te enviamos otro correo a $correo. Revisa también spam.'),
      backgroundColor: error == null ? AppColors.verde : AppColors.rojo));
  }

  @override
  Widget build(BuildContext context) {
    final logoBytes = _logoBytes;
    return Scaffold(
      backgroundColor: AppColors.azul,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Logo ──
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 24, offset: const Offset(0, 8))]),
                    padding: const EdgeInsets.all(12),
                    child: logoBytes.isNotEmpty
                      ? Image.memory(logoBytes, fit: BoxFit.contain)
                      : const Center(child: Text('H',
                          style: TextStyle(color: AppColors.azul,
                            fontSize: 52, fontWeight: FontWeight.w800)))),
                  const SizedBox(height: 16),
                  const Text('HETNA CNC',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 2)),
                  const Text('Sistema de gestión',
                    style: TextStyle(fontSize: 13, color: Colors.white60)),

                  const SizedBox(height: 36),

                  // ── Tarjeta login ──
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20, offset: const Offset(0, 8))]),
                    child: Column(children: [
                      const Align(alignment: Alignment.centerLeft,
                        child: Text('Iniciar sesión',
                          style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.azul))),
                      const SizedBox(height: 20),

                      // Correo
                      TextFormField(
                        controller: _correoCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.loginCorreo,
                          prefixIcon: const Icon(Icons.email_outlined,
                            size: 20, color: AppColors.textoSecundario),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.grisBorde))),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                          if (!v.contains('@')) return 'Correo invalido';
                          return null;
                        }),
                      const SizedBox(height: 14),

                      // Contraseña
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: !_verPassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'Contrasena',
                          prefixIcon: const Icon(Icons.lock_outline,
                            size: 20, color: AppColors.textoSecundario),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _verPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                              size: 20, color: AppColors.textoSecundario),
                            onPressed: () =>
                              setState(() => _verPassword = !_verPassword)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.grisBorde))),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa tu contrasena';
                          if (v.length < 6) return 'Minimo 6 caracteres';
                          return null;
                        }),

                      // Error
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.rojoClaro,
                            borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            const Icon(Icons.error_outline,
                              size: 16, color: AppColors.rojo),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!,
                              style: const TextStyle(
                                fontSize: 12, color: AppColors.rojo))),
                          ])),
                        if (_requiereConfirmar)
                          Align(alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _reenviando ? null : _reenviarConfirmacion,
                              icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                              label: Text(_reenviando
                                ? 'Enviando…'
                                : 'Reenviar correo de confirmación'))),
                      ],

                      const SizedBox(height: 20),

                      // Botón
                      SizedBox(width: double.infinity, height: 48,
                        child: ElevatedButton(
                          onPressed: _cargando ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.azul,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                          child: _cargando
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                            : Text(AppLocalizations.of(context)!.loginEntrar,
                                style: const TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)))),

                      const SizedBox(height: 10),
                      Center(child: TextButton(
                        onPressed: _mostrarRecuperarClave,
                        child: Text(AppLocalizations.of(context)!.loginOlvidasteContrasena,
                          style: const TextStyle(fontSize: 12,
                            color: AppColors.textoSecundario,
                            fontWeight: FontWeight.w600)))),
                    ])),

                  const SizedBox(height: 24),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 16),
                  const Text('Nuevo taller',
                    style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RegistroTallerScreen())),
                      icon: const Icon(Icons.store_outlined, color: AppColors.azul, size: 18),
                      label: Text(AppLocalizations.of(context)!.loginRegistrarTaller,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.azul)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.azul),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))))),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, height: 44,
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const UnirseEquipoScreen())),
                      icon: const Icon(Icons.qr_code_2, color: AppColors.textoSecundario, size: 18),
                      label: Text(AppLocalizations.of(context)!.loginTengoCodigo,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.textoSecundario)))),
                  const SizedBox(height: 24),

                  const Text('Acceso restringido - Solo personal autorizado',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                    textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
