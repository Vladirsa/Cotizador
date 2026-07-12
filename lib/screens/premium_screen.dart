// lib/screens/premium_screen.dart
// HETNA CNC — Pantalla de compra de suscripción Premium
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/billing_service.dart';
import '../services/auth_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _comprando = false;

  @override
  void initState() {
    super.initState();
    BillingService.onError = (msg) {
      if (mounted) {
        setState(() => _comprando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.rojo));
      }
    };
    BillingService.onCompraExitosa = () {
      if (mounted) {
        setState(() => _comprando = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ ¡Listo! Ya tienes Premium activado'),
          backgroundColor: AppColors.verde));
        Navigator.pop(context);
      }
    };
  }

  final _beneficios = const [
    ('🧮', 'Simulador de costos completo'),
    ('📢', 'Marketing y WhatsApp automático'),
    ('👥', 'Equipo sin límite de usuarios'),
    ('📋', 'Cotizaciones ilimitadas'),
  ];

  @override
  Widget build(BuildContext context) {
    final precio = BillingService.productoPremium?.price ?? '—';
    final disponible = BillingService.disponible && BillingService.productoPremium != null;

    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: const Text('Actualizar a Premium'),
        backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.azul, Color(0xFF2d5a8e)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            const Icon(Icons.workspace_premium, color: Colors.amber, size: 48),
            const SizedBox(height: 12),
            const Text('HETNA CNC Premium',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(precio,
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
            const Text('por mes', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
        const SizedBox(height: 20),

        ..._beneficios.map((b) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Row(children: [
            Text(b.$1, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(child: Text(b.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          ]))),

        const SizedBox(height: 20),

        if (!disponible)
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(10)),
            child: const Text(
              'La suscripción todavía no está disponible desde esta app. '
              'Contacta al administrador de HETNA CNC.',
              style: TextStyle(fontSize: 12, color: AppColors.ambar))),

        SizedBox(height: 50, child: ElevatedButton(
          onPressed: (!disponible || _comprando) ? null : () async {
            setState(() => _comprando = true);
            await BillingService.comprarPremium();
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _comprando
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Suscribirme ahora',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)))),

        const SizedBox(height: 10),
        TextButton(
          onPressed: () async {
            setState(() => _comprando = true);
            await BillingService.restaurarCompras();
            if (mounted) setState(() => _comprando = false);
          },
          child: const Text('Ya pagué antes — restaurar compra',
            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario))),
      ]));
  }
}
