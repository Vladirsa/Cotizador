// lib/screens/login_screen.dart
// HETNA CNC — Pantalla de login
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _correoCtrl   = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool _cargando      = false;
  bool _verPassword   = false;
  String? _error;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _cargando = true; _error = null; });

    final result = await AuthService.login(
      correo: _correoCtrl.text.trim(),
      password: _passCtrl.text,
    );

    if (!mounted) return;

    if (result.exito) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      setState(() { _cargando = false; _error = result.error; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
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
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.azul,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                        color: AppColors.azul.withOpacity(0.3),
                        blurRadius: 20, offset: const Offset(0, 8))]),
                    child: const Center(
                      child: Text('H',
                        style: TextStyle(color: Colors.white,
                          fontSize: 42, fontWeight: FontWeight.w800)))),
                  const SizedBox(height: 16),
                  const Text('HETNA CNC',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                      color: AppColors.azul, letterSpacing: 1)),
                  const Text('Sistema de gestión',
                    style: TextStyle(fontSize: 13, color: AppColors.textoSecundario)),

                  const SizedBox(height: 40),

                  // ── Tarjeta login ──
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16, offset: const Offset(0, 4))]),
                    child: Column(children: [

                      const Align(alignment: Alignment.centerLeft,
                        child: Text('Iniciar sesión',
                          style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textoPrincipal))),
                      const SizedBox(height: 20),

                      // Correo
                      TextFormField(
                        controller: _correoCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: const Icon(Icons.email_outlined,
                            size: 20, color: AppColors.textoSecundario),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.grisBorde))),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                          if (!v.contains('@')) return 'Correo inválido';
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
                          labelText: 'Contraseña',
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
                            borderSide: const BorderSide(
                              color: AppColors.grisBorde))),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                          if (v.length < 6) return 'Mínimo 6 caracteres';
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
                      ],

                      const SizedBox(height: 20),

                      // Botón
                      SizedBox(width: double.infinity,
                        height: 48,
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
                            : const Text('Entrar',
                                style: TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)))),
                    ])),

                  const SizedBox(height: 24),

                  // Rol actual (debug visible solo en desarrollo)
                  const Text('Acceso restringido · Solo personal autorizado',
                    style: TextStyle(fontSize: 11,
                      color: AppColors.textoSecundario),
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
