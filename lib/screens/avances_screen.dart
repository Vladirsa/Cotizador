import 'package:flutter/material.dart';
import '../main.dart';
class AvancesScreen extends StatelessWidget {
  const AvancesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Avances')),
      body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(Icons.local_shipping_outlined, size: 64, color: AppColors.azul),
        SizedBox(height: 16), Text('Pedidos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))])));
  }
}
