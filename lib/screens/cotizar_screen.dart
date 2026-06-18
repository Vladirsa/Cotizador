import 'package:flutter/material.dart';
import '../main.dart';
class CotizarScreen extends StatelessWidget {
  const CotizarScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Cotizador')),
      body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(Icons.description_outlined, size: 64, color: AppColors.azul),
        SizedBox(height: 16), Text('Cotizador', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))])));
  }
}
