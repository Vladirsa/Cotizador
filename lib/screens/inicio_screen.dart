import 'package:flutter/material.dart';
import '../main.dart';
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HETNA CNC')),
      body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(Icons.dashboard_outlined, size: 64, color: AppColors.azul),
        SizedBox(height: 16), Text('Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))])));
  }
}
