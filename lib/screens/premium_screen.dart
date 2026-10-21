// lib/screens/premium_screen.dart
// HETNA CNC — Planes del taller (mismos precios que hetnacnc.com)
//
// Cómo se paga hoy:
// - Si la app viene de Google Play y el producto existe, se usa Google Play.
// - Si no (APK directo o versión web), se contrata con HETNA por WhatsApp o en
//   hetnacnc.com. HETNA activa el plan en `negocios.plan` y la app lo toma al
//   tocar "Ya pagué, actualizar". Cuando el cobro con Mercado Pago quede
//   automático, este botón abrirá directo el pago.
// Ojo: si algún día se publica en Google Play, Google no permite mandar a pagar
// fuera de la tienda bienes digitales; por eso el enlace externo solo aparece
// cuando Google Play Billing NO está disponible.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/billing_service.dart';
import '../services/auth_service.dart';
import '../services/hetna_api.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _ocupado = false;

  static const _incluye = {
    Plan.gratis: [
      '10 cotizaciones al mes', 'Clientes, productos y avances', 'Alertas y seguimiento por WhatsApp',
      'Calculadora CNC y Envíos HETNA', '1 usuario',
    ],
    Plan.taller: [
      'Cotizaciones ilimitadas', 'Simulador de costos con 3 precios', 'Costos de tu taller',
      'Gastos y compras', 'Avisos de avance por WhatsApp', 'Fotos en productos', '2 usuarios',
    ],
    Plan.pro: [
      'Todo lo de Taller', 'Inventario de bodega', 'Marketing: cupones y plantillas de WhatsApp', 'Reportes Excel',
      'Dashboard de utilidad, gastos y conversión', 'Equipo con roles: 5 usuarios',
    ],
    Plan.industrial: [
      'Todo lo de Pro', 'Facturación electrónica (CFDI)', 'API para conectar tu sistema', 'Usuarios ilimitados',
    ],
  };

  @override
  void initState() {
    super.initState();
    BillingService.onError = (msg) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.rojo));
    };
    BillingService.onCompraExitosa = () {
      if (!mounted) return;
      setState(() => _ocupado = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ ¡Listo! Tu plan quedó activo'), backgroundColor: AppColors.verde));
      Navigator.pop(context);
    };
  }

  bool get _hayGooglePlay => BillingService.disponible && BillingService.productoPremium != null;

  Future<void> _contratar(Plan p) async {
    if (_hayGooglePlay) {
      setState(() => _ocupado = true);
      await BillingService.comprarPremium();
      return;
    }
    final msg = 'Hola, quiero contratar el plan ${Planes.nombres[p]} '
      '(\$${Planes.precios[p]} al mes) del Cotizador HETNA.\n'
      'Mi taller: ${AuthService.nombreUsuario ?? ''}\nID: ${AuthService.negocioId ?? ''}';
    final uri = Uri.parse('https://wa.me/${HetnaApi.whatsappHetna}?text=${Uri.encodeComponent(msg)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _actualizar() async {
    setState(() => _ocupado = true);
    if (_hayGooglePlay) await BillingService.restaurarCompras();
    await AuthService.refrescarPerfil();
    if (!mounted) return;
    setState(() => _ocupado = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Tu plan: ${Planes.nombres[AuthService.planActual]}'), backgroundColor: AppColors.azul));
  }

  @override
  Widget build(BuildContext context) {
    final actual = AuthService.planActual;
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: const Text('Planes HETNA'),
        backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (AuthService.plan == 'trial' || AuthService.plan == 'prueba')
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(10)),
            child: Text(AuthService.trialVencido
                ? 'Tu prueba terminó. Elige un plan para seguir usando los módulos con candado.'
                : 'Prueba: ${AuthService.diasTrialRestantes} días con todo abierto.',
              style: const TextStyle(fontSize: 12, color: AppColors.ambar, fontWeight: FontWeight.w600))),
        ...Plan.values.map((p) => _tarjeta(p, actual)),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _ocupado ? null : _actualizar,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Ya pagué — actualizar mi plan')),
        TextButton(
          onPressed: () => launchUrl(Uri.parse(HetnaApi.urlPlanes), mode: LaunchMode.externalApplication),
          child: const Text('Ver planes en hetnacnc.com',
            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario))),
      ]));
  }

  Widget _tarjeta(Plan p, Plan actual) {
    final esActual = p == actual;
    final destacado = p == Plan.taller;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: esActual ? AppColors.verde : (destacado ? AppColors.naranja : AppColors.grisBorde),
          width: esActual || destacado ? 1.5 : 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(Planes.nombres[p]!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.azul)),
          const Spacer(),
          Text(Planes.precios[p] == 0 ? 'Gratis' : '\$${Planes.precios[p]}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          if (Planes.precios[p]! > 0)
            const Text(' /mes', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ]),
        const SizedBox(height: 8),
        ...(_incluye[p] ?? []).map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.check, size: 16, color: AppColors.verde),
            const SizedBox(width: 6),
            Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
          ]))),
        const SizedBox(height: 8),
        if (esActual)
          const Text('✓ Tu plan actual', style: TextStyle(color: AppColors.verde, fontWeight: FontWeight.w700))
        else if (p.index > actual.index)
          SizedBox(width: double.infinity, height: 42, child: ElevatedButton(
            onPressed: _ocupado ? null : () => _contratar(p),
            style: ElevatedButton.styleFrom(backgroundColor: destacado ? AppColors.naranja : AppColors.azul,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(_hayGooglePlay ? 'Suscribirme' : 'Contratar ${Planes.nombres[p]}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
      ]));
  }
}
