// lib/screens/premium_screen.dart
// HETNA CNC — Planes del taller (mismos precios que hetnacnc.com)
//
// Cómo se paga:
// - Si la app viene de Google Play y el producto existe, se usa Google Play.
// - Si no (APK directo o versión web), suscripción mensual con Mercado Pago
//   (México, MXN) o con PayPal (USD, tarjeta internacional): el backend de
//   hetnacnc.com crea la suscripción, la app abre el enlace de pago y, cuando
//   el proveedor confirma, el servidor cambia `negocios.plan`.
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
import '../i18n/tr.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _ocupado = false;
  // Precios en USD y formas de pago activas, desde hetnacnc.com
  Map<String, dynamic>? _precios;

  bool get _hayPaypal => _precios?['paypal'] == true;
  num? _usd(Plan p) => ((_precios?['planes'] as Map?)?[p.name] as Map?)?['usd'] as num?;

  static const _incluye = Planes.incluye;

  @override
  void initState() {
    super.initState();
    SuscripcionApi.precios().then((d) {
      if (mounted) setState(() => _precios = d);
    }).catchError((_) {});
    BillingService.onError = (msg) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(msg)), backgroundColor: AppColors.rojo));
    };
    BillingService.onCompraExitosa = () {
      if (!mounted) return;
      setState(() => _ocupado = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('✅ ¡Listo! Tu plan quedó activo')), backgroundColor: AppColors.verde));
      Navigator.pop(context);
    };
  }

  bool get _hayGooglePlay => BillingService.disponible && BillingService.productoPremium != null;

  void _aviso(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr(texto)), backgroundColor: error ? AppColors.rojo : AppColors.azul));
  }

  Future<void> _porWhatsApp(Plan p) async {
    final msg = trf('Hola, quiero contratar el plan {0} (\${1} al mes) del Cotizador HETNA.\nMi taller: {2}\nID: {3}', [(Planes.nombres[p]), (Planes.precios[p]), (AuthService.nombreUsuario ?? ''), (AuthService.negocioId ?? '')]);
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
      _aviso(tr('Sólo el administrador del taller puede contratar el plan.'), error: true);
      return;
    }
    final token = AuthService.sesion?.accessToken;
    if (token == null) {
      _aviso(tr('Vuelve a iniciar sesión para contratar.'), error: true);
      return;
    }

    // 1) Forma de pago
    final usd = _usd(p);
    final forma = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(
      title: Text(trf('Plan {0}', [(Planes.nombres[p])])),
      children: [
        _opcionPago(ctx, 'mp', Icons.credit_card, tr('Mercado Pago'),
          trf('México · \${0} MXN al mes · tarjeta de crédito o débito', [(Planes.precios[p])])),
        if (_hayPaypal && usd != null)
          _opcionPago(ctx, 'paypal', Icons.public, tr('PayPal'),
            trf('US\${0} al mes · tarjeta internacional o cuenta PayPal', [usd])),
        _opcionPago(ctx, 'whatsapp', Icons.chat_outlined, tr('WhatsApp'),
          tr('Transferencia, factura o dudas')),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Text(tr('Se cobra cada mes. Puedes cancelar cuando quieras y conservas el plan hasta el fin del mes pagado.'),
            style: TextStyle(fontSize: 11, color: AppColors.textoSecundario, height: 1.4))),
      ]));
    if (forma == null) return;
    if (forma == 'whatsapp') return _porWhatsApp(p);

    // 2) Mercado Pago pide el correo de la cuenta con la que se va a pagar
    var correoPago = '';
    if (forma == 'mp') {
      final correoCtrl = TextEditingController(text: AuthService.usuarioActual?.email ?? '');
      final seguir = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: Text(trf('Mercado Pago · \${0} MXN al mes', [(Planes.precios[p])])),
        content: TextField(controller: correoCtrl, keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: tr('Correo de tu cuenta de Mercado Pago'),
            helperText: tr('Debe ser el mismo con el que entras a Mercado Pago'),
            isDense: true, border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancelar'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul),
            child: Text(tr('Ir a pagar'), style: TextStyle(color: Colors.white))),
        ]));
      correoPago = correoCtrl.text.trim();
      correoCtrl.dispose();
      if (seguir != true) return;
    }
    final proveedor = forma == 'paypal' ? 'paypal' : 'mercadopago';
    final nombreProveedor = forma == 'paypal' ? tr('PayPal') : tr('Mercado Pago');

    setState(() => _ocupado = true);
    try {
      final url = await SuscripcionApi.crear(token, p.name, correoPago, proveedor: proveedor);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      _aviso(trf('Cuando termines de pagar en {0}, toca "Ya pagué — actualizar mi plan".', [nombreProveedor]));
    } on HetnaError catch (e) {
      _aviso(e.mensaje, error: true);
    } catch (_) {
      _aviso(trf('No pudimos abrir {0}. Revisa tu conexión o escríbenos por WhatsApp.', [nombreProveedor]), error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Widget _opcionPago(BuildContext ctx, String valor, IconData icono, String titulo, String detalle) =>
    SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, valor),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(children: [
        Icon(icono, color: AppColors.azul, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(titulo), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(tr(detalle), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
        ])),
      ]));

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
    _aviso(trf('Tu plan: {0}', [(Planes.nombres[AuthService.planActual])]));
  }

  Future<void> _cancelar() async {
    final token = AuthService.sesion?.accessToken;
    if (token == null) return;
    final renueva = AuthService.planRenueva;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('Cancelar suscripción')),
      content: Text(trf('Ya no se te cobrará. Conservas tu plan {0} y después tu taller pasa a Gratis.', [(renueva != null ? trf('hasta el {0}', [(_fecha(renueva))]) : tr('hasta el fin del mes pagado'))])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('No, seguir'))),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
          child: Text(tr('Sí, cancelar'), style: TextStyle(color: AppColors.rojo))),
      ]));
    if (ok != true) return;
    setState(() => _ocupado = true);
    try {
      await SuscripcionApi.cancelar(token);
      await AuthService.refrescarPerfil();
      _aviso(tr('Suscripción cancelada.'));
    } on HetnaError catch (e) {
      _aviso(e.mensaje, error: true);
    } catch (_) {
      _aviso(tr('No se pudo cancelar. Intenta de nuevo o escríbenos.'), error: true);
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
      texto = r != null ? trf('Suscripción activa · se renueva el {0}', [(_fecha(r))]) : tr('Suscripción activa');
    } else {
      final v = AuthService.planVence;
      texto = v != null && v.isAfter(DateTime.now())
        ? trf('Suscripción {0} · tu plan sigue hasta el {1}', [(estado == 'pausada' ? 'pausada' : 'cancelada'), (_fecha(v))])
        : trf('Suscripción {0}', [(estado == 'pausada' ? 'pausada' : 'cancelada')]);
      color = AppColors.ambar;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grisBorde)),
      child: Row(children: [
        Expanded(child: Text(tr(texto), style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600))),
        if (estado == 'activa' && AuthService.esAdmin)
          TextButton(onPressed: _ocupado ? null : _cancelar,
            child: Text(tr('Cancelar'), style: TextStyle(fontSize: 12, color: AppColors.rojo))),
      ]));
  }

  @override
  Widget build(BuildContext context) {
    final actual = AuthService.planActual;
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: Text(tr('Planes HETNA')),
        backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (AuthService.plan == 'trial' || AuthService.plan == 'prueba')
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(10)),
            child: Text(tr(AuthService.trialVencido
                ? tr('Tu prueba terminó. Elige un plan para seguir usando los módulos con candado.')
                : trf('Prueba: {0} días con todo abierto.', [(AuthService.diasTrialRestantes)])),
              style: const TextStyle(fontSize: 12, color: AppColors.ambar, fontWeight: FontWeight.w600))),
        if (_estadoSuscripcion() != null) _estadoSuscripcion()!,
        ...Plan.values.map((p) => _tarjeta(p, actual)),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _ocupado ? null : _actualizar,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(tr('Ya pagué — actualizar mi plan'))),
        TextButton(
          onPressed: () => launchUrl(Uri.parse(HetnaApi.urlPlanes), mode: LaunchMode.externalApplication),
          child: Text(tr('Ver planes en hetnacnc.com'),
            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario))),
      ]));
  }

  Widget _tarjeta(Plan p, Plan actual) {
    // En la prueba todo está abierto (se ve como Industrial), pero el taller
    // todavía no paga: debe poder contratar cualquier plan de pago.
    final enPrueba = AuthService.plan == 'trial' || AuthService.plan == 'prueba';
    final esActual = !enPrueba && p == actual;
    final puedeContratar = p != Plan.gratis && (enPrueba || p.index > actual.index);
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
          Text(tr(Planes.precios[p] == 0 ? tr('Gratis') : '\$${Planes.precios[p]}'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          if (Planes.precios[p]! > 0)
            const Text(' /mes', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ]),
        if (_hayPaypal && _usd(p) != null && Planes.precios[p]! > 0)
          Align(alignment: Alignment.centerRight,
            child: Text(trf('o US\${0}/mes con PayPal', [(_usd(p))]),
              style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
        const SizedBox(height: 8),
        ...(_incluye[p] ?? []).map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.check, size: 16, color: AppColors.verde),
            const SizedBox(width: 6),
            Expanded(child: Text(tr(t), style: const TextStyle(fontSize: 13))),
          ]))),
        const SizedBox(height: 8),
        if (esActual)
          Text(tr('✓ Tu plan actual'), style: TextStyle(color: AppColors.verde, fontWeight: FontWeight.w700))
        else if (puedeContratar)
          SizedBox(width: double.infinity, height: 42, child: ElevatedButton(
            onPressed: _ocupado ? null : () => _contratar(p),
            style: ElevatedButton.styleFrom(backgroundColor: destacado ? AppColors.naranja : AppColors.azul,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(tr(_hayGooglePlay ? tr('Suscribirme') : trf('Contratar {0}', [(Planes.nombres[p])])),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
      ]));
  }
}
