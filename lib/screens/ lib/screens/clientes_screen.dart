import 'package:flutter/material.dart';
import '../main.dart';
class ClientesScreen extends StatelessWidget {
  const ClientesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Clientes')),
      body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(Icons.people_outline, size: 64, color: AppColors.azul),
        SizedBox(height: 16), Text('CRM Clientes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))])));
  }
}
