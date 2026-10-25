// lib/screens/premium_screen.dart
// HETNA CNC — Planes del taller (mismos precios que hetnacnc.com)
//
// Cómo se paga:
// - Si la app viene de Google Play y el producto existe, se usa Google Play.
// - Si no (APK directo o versión web), suscripción mensual con Mercado Pago:
//   el backend de hetnacnc.com crea la suscripción, la app abre el enlace de
//   pago y, cuando Mercado Pago confirma, el servidor cambia `negocios.plan`.
//   "Ya pagué, actualizar" vuelve a revisar el pago por si el aviso tarda.
// - WhatsApp queda como alternativa (transferencia, factura, dudas).
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
      '10 cotizaciones sencillas al mes', '1 cotización profesional de muestra', 'Clientes, productos y avances', 'Alertas y seguimiento por WhatsApp',
      'Calculadora CNC y Envíos HETNA', '1 usuario',
    ],
    Plan.taller: [
      'Cotizaciones ilimitadas', 'Cotización profesional (formato internacional, sin marca)', 'Simulador de costos con 3 precios', 'Costos de tu taller',
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

  void _aviso(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto), backgroundColor: error ? AppColors.rojo : AppColors.azul));
  }

  Future<void> _porWhatsApp(Plan p) async {
    final msg = 'Hola, quiero contratar el plan ${Planes.nombres[p]} '
      '(\$${Planes.precios[p]} al mes) del Cotizador HETNA.\n'
      'Mi taller: ${AuthService.nombreUsuario ?? ''}\nID: ${AuthService.negocioId ?? ''}';
    final uri = Uri.parse('https://wa.me/${HetnaApi.whatsappHetna}?text=${Uri.encodeComponent(msg)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _contratar(Plan p) async {
    if (_hayGooglePlay) {
      setState(() => _ocupado = true);
      await BillingService.comprarPremium();
      return;
    }
    if (!AuthService.esAdmin) {
      _aviso('Sólo el administrador del taller puede contratar el plan.', error: true);
      return;
    }
    final token = AuthService.sesion?.accessToken;
    if (token == null) {
      _aviso('Vuelve a iniciar sesión para contratar.', error: true);
      return;
    }

    // Mercado Pago pide el correo de la cuenta con la que se va a pagar
    final correoCtrl = TextEditingController(text: AuthService.usuarioActual?.email ?? '');
    final eleccion = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Plan ${Planes.nombres[p]} · \$${Planes.precios[p]} al mes'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Se cobra cada mes con Mercado Pago (tarjeta de crédito o débito). '
          'Puedes cancelar cuando quieras y conservas el plan hasta el fin del mes pagado.',
          style: TextStyle(fontSize: 12, color: AppColors.textoSecundario, height: 1.4)),
        const SizedBox(height: 14),
        TextField(controller: correoCtrl, keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo de tu cuenta de Mercado Pago',
            helperText: 'Debe ser el mismo con el que entras a Mercado Pago',
            isDense: true, border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'whatsapp'),
          child: const Text('Prefiero WhatsApp')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, 'mp'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul),
          child: const Text('Pagar con Mercado Pago', style: TextStyle(color: Colors.white))),
      ]));
    final correoPago = correoCtrl.text.trim();
    correoCtrl.dispose();
    if (eleccion == 'whatsapp') return _porWhatsApp(p);
    if (eleccion != 'mp') return;

    setState(() => _ocupado = true);
    try {
      final url = await SuscripcionApi.crear(token, p.name, correoPago);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      _aviso('Cuando termines de pagar en Mercado Pago, toca "Ya pagué — actualizar mi plan".');
    } on HetnaError catch (e) {
      _aviso(e.mensaje, error: true);
    } catch (_) {
      _aviso('No pudimos abrir Mercado Pago. Revisa tu conexión o escríbenos por WhatsApp.', error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _actualizar() async {
    setState(() => _ocupado = true);
    if (_hayGooglePlay) await BillingService.restaurarCompras();
    final token = AuthService.sesion?.accessToken;
    if (token != null && AuthService.esAdmin) {
      try { await SuscripcionApi.verificar(token); } catch (_) {}
    }
    await AuthService.refrescarPerfil();
    if (!mounted) return;
    setState(() => _ocupado = false);
    _aviso('Tu plan: ${Planes.nombres[AuthService.planActual]}');
  }

  Future<void> _cancelar() async {
    final token = AuthService.sesion?.accessToken;
    if (token == null) return;
    final renueva = AuthService.planRenueva;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Cancelar suscripción'),
      content: Text('Ya no se te cobrará. Conservas tu plan '
        '${renueva != null ? 'hasta el ${_fecha(renueva)}' : 'hasta el fin del mes pagado'} '
        'y después tu taller pasa a Gratis.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, seguir')),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sí, cancelar', style: TextStyle(color: AppColors.rojo))),
      ]));
    if (ok != true) return;
    setState(() => _ocupado = true);
    try {
      await SuscripcionApi.cancelar(token);
      await AuthService.refrescarPerfil();
      _aviso('Suscripción cancelada.');
    } on HetnaError catch (e) {
      _aviso(e.mensaje, error: true);
    } catch (_) {
      _aviso('No se pudo cancelar. Intenta de nuevo o escríbenos.', error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  static String _fecha(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  // Estado de la suscripción de Mercado Pago (si tiene)
  Widget? _estadoSuscripcion() {
    final estado = AuthService.planEstado;
    if (estado == null) return null;
    final String texto;
    Color color = AppColors.azul;
    if (estado == 'activa') {
      final r = AuthService.planRenueva;
      texto = r != null ? 'Suscripción activa · se renueva el ${_fecha(r)}' : 'Suscripción activa';
    } else {
      final v = AuthService.planVence;
      texto = v != null && v.isAfter(DateTime.now())
        ? 'Suscripción ${estado == 'pausada' ? 'pausada' : 'cancelada'} · tu plan sigue hasta el ${_fecha(v)}'
        : 'Suscripción ${estado == 'pausada' ? 'pausada' : 'cancelada'}';
      color = AppColors.ambar;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grisBorde)),
      child: Row(children: [
        Expanded(child: Text(texto, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600))),
        if (estado == 'activa' && AuthService.esAdmin)
          TextButton(onPressed: _ocupado ? null : _cancelar,
            child: const Text('Cancelar', style: TextStyle(fontSize: 12, color: AppColors.rojo))),
      ]));
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
        if (_estadoSuscripcion() != null) _estadoSuscripcion()!,
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
