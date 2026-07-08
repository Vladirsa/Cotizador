// lib/screens/unirse_equipo_screen.dart
// HETNA CNC — Registro de nuevo miembro con código de invitación
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class UnirseEquipoScreen extends StatefulWidget {
  const UnirseEquipoScreen({super.key});
  @override
  State<UnirseEquipoScreen> createState() => _UnirseEquipoScreenState();
}

class _UnirseEquipoScreenState extends State<UnirseEquipoScreen> {
  final _codigoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _cargando = false;
  bool _verPass = false;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _crearCuenta() async {
    final codigo = _codigoCtrl.text.trim();
    final nombre = _nombreCtrl.text.trim();
    final correo = _correoCtrl.text.trim();
    final pass = _passCtrl.text;
    final passConfirm = _passConfirmCtrl.text;

    if (codigo.isEmpty || nombre.isEmpty || correo.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Completa todos los campos'), backgroundColor: AppColors.rojo));
      return;
    }
    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La contraseña debe tener al menos 6 caracteres'),
        backgroundColor: AppColors.rojo));
      return;
    }
    if (pass != passConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Las contraseñas no coinciden'), backgroundColor: AppColors.rojo));
      return;
    }

    setState(() => _cargando = true);
    final result = await AuthService.crearCuentaConInvitacion(
      codigo: codigo, nombre: nombre, correo: correo, password: pass);
    if (mounted) setState(() => _cargando = false);

    if (!mounted) return;
    if (result.exito) {
      Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? 'Error al crear la cuenta'),
        backgroundColor: AppColors.rojo));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0.5,
        title: const Text('Unirme a un taller',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.azulClaro,
              borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.qr_code_2, color: AppColors.azul, size: 28),
              SizedBox(width: 12),
              Expanded(child: Text(
                'Pide a tu administrador el código de invitación de 6 letras que generó en la app.',
                style: TextStyle(fontSize: 12, color: AppColors.azul))),
            ])),
          const SizedBox(height: 20),

          const Text('Código de invitación', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _codigoCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              hintText: 'AB3XY9',
              prefixIcon: const Icon(Icons.key_outlined, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
              letterSpacing: 4, fontFamily: 'monospace')),
          const SizedBox(height: 16),

          const Text('Tu nombre completo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _nombreCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Juan Pérez',
              prefixIcon: const Icon(Icons.person_outline, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true)),
          const SizedBox(height: 16),

          const Text('Correo electrónico', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _correoCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'correo@ejemplo.com',
              prefixIcon: const Icon(Icons.email_outlined, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true)),
          const SizedBox(height: 16),

          const Text('Crea una contraseña', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _passCtrl,
            obscureText: !_verPass,
            decoration: InputDecoration(
              hintText: 'Mínimo 6 caracteres',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _verPass = !_verPass)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true)),
          const SizedBox(height: 16),

          const Text('Confirma tu contraseña', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _passConfirmCtrl,
            obscureText: !_verPass,
            decoration: InputDecoration(
              hintText: 'Repite la contraseña',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true)),
          const SizedBox(height: 24),

          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _cargando ? null : _crearCuenta,
              icon: _cargando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(_cargando ? 'Creando cuenta...' : 'Unirme al taller',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azul,
                padding: const EdgeInsets.symmetric(vertical: 14)))),
          const SizedBox(height: 40),
        ])));
  }
}
