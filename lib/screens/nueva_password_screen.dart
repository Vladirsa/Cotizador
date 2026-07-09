// lib/screens/nueva_password_screen.dart
// HETNA CNC — Pantalla que aparece al volver del enlace de "recuperar contraseña"
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'home_screen.dart';

class NuevaPasswordScreen extends StatefulWidget {
  const NuevaPasswordScreen({super.key});
  @override
  State<NuevaPasswordScreen> createState() => _NuevaPasswordScreenState();
}

class _NuevaPasswordScreenState extends State<NuevaPasswordScreen> {
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _cargando = false;
  bool _verPass = false;
  String? _error;

  Future<void> _guardar() async {
    setState(() => _error = null);
    final pass = _passCtrl.text;
    final confirm = _passConfirmCtrl.text;

    if (pass.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    setState(() => _cargando = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: pass));

      // Ya se guardó la contraseña nueva: regresar al flujo normal de la app
      mostrarRecuperarPass.value = false;

      if (mounted) {
        Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false);
      }
    } catch (e) {
      setState(() { _error = 'No se pudo actualizar: $e'; _cargando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.lock_reset, size: 56, color: AppColors.azul),
                const SizedBox(height: 16),
                const Text('Crea tu nueva contraseña',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.azul)),
                const SizedBox(height: 6),
                const Text('Escribe tu nueva contraseña para volver a entrar a HETNA CNC.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                const SizedBox(height: 24),

                if (_error != null) ...[
                  Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.rojoClaro,
                      borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, size: 16, color: AppColors.rojo),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!,
                        style: const TextStyle(fontSize: 12, color: AppColors.rojo))),
                    ])),
                  const SizedBox(height: 16),
                ],

                TextField(controller: _passCtrl, obscureText: !_verPass,
                  decoration: InputDecoration(labelText: 'Nueva contraseña',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility, size: 18),
                      onPressed: () => setState(() => _verPass = !_verPass)),
                    isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 14),
                TextField(controller: _passConfirmCtrl, obscureText: !_verPass,
                  decoration: const InputDecoration(labelText: 'Confirmar contraseña',
                    prefixIcon: Icon(Icons.lock_outline, size: 18),
                    isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 24),

                SizedBox(height: 48, child: ElevatedButton(
                  onPressed: _cargando ? null : _guardar,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: _cargando
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar contraseña',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                          color: Colors.white)))),
              ]))))));
  }
}
