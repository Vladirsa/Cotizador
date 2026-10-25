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

  // Logo HETNA CNC en base64 (PNG de 24 colores, ~9 KB)
  static const String _logoB64 = 'iVBORw0KGgoAAAANSUhEUgAAAPAAAADwCAMAAAAJixmgAAAASFBMVEUAAFQAAErohhkBATsAAFoAAEMAAE8AAGAAAGf////ojSsCAB4EAjHnoljpm0VSHRh9OBvBbjUbAw+dUirciD53cYI6NUzHw82LxeLhAAAAGHRSTlP////////////////////////////////gEcFnAAAiE0lEQVR42u2diWLbuK6GKWtzJcZak7z/m14R4AKQoBbX9sw55ypJ25mmrT//AAiAm/rzP/ao/wd+//Prnv8B4N/f758fXf6UP9ujf36+P06tPgqrte77Xpun3z7gPz4M/THg3x9kLbdHl/AzfCH0738b8PfPhlVaSHzCfxron+//IuDNbw0tqluiPWuwbEQ2nx9DVh9RV6P5ogHPg3vmvnfvhC4/hKw+gltinOrneVyWqYPn1t2mZRk3auvY2zd8AFm9O1T11mv1puy4rIYUH/i569YJmG0s698evtSbcXuwWG1wJ4TdfpzgWS16ty4Wefvq342s3oxbo3DzOKG0G92mKDzDYARHnSdANmFMvxlZvRNXe2OeHJi3Xwhg/n24bb/jfuO9Kqt3GjMOOGDMDKoGrrpmv2lVdoPU738S8JZDerXmYekgQiFuXUaPl98i2yTsbdmXeiduELALJlvDF35Y5GDYJny5qK6/f/8TgB2u9uo6XAtqf6xL/yt4X1awg25DDs7QvwFZvQUXo62Nwlbd2jwB10sM/xPeG/vmbMj6fSqr1+L+2LCzvVaDawhW8Mwa0bYP8jhq88ve/4Ft5Jr73kXynxcjvxIYk2bEnUf03RX1ql1gNpTh04Ob38f3CHVeSPKlv/+dwN80iwSxOotbO1auL2XH78E/2DmVsV4uX6uyei0uDrzjZHHNi3aY6Y/J4/4weP66Ob6V+ZWFlHoVbo+JoXnF68O9YG2dFn/KYCIqylzXIQ21I5llfhXyK4BNSaRtuevUnQjuhcdAJ8gvrSrUK3CjPCPgxtHpgNb/wiUs9m/yhv37zwPbpLmkvutTZukp2EctRLESfdkOzFTlV5TL6iW4uvQFLybEQBZR7j78PSm3r21gdiq/slxWf4+LWaBLmpfZdKpe82yDOaSb+Ca+plx+HthkkQHXJs2327SM44hfC/5w+CH/b/jDRmCXb/oC7K/yTfUXuN7MjLuZ5wE/+If8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';

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
