import 'package:flutter/material.dart';
import '../main.dart';
class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Configuración')),
      body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(Icons.settings_outlined, size: 64, color: AppColors.azul),
        SizedBox(height: 16), Text('Configuración', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))])));
  }
}
