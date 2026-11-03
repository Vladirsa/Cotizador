// ============================================
// lib/screens/factura_screen.dart
// Cotizador 2.0 · Fase 4 — Facturar un pedido (CFDI 4.0 real)
//
// Timbra con el servidor de HETNA (Facturapi). Los conceptos salen de la
// cotización del pedido; aquí sólo se capturan los datos del cliente.
// Después se puede ver/compartir el PDF y el XML, mandarla por correo o
// cancelarla (motivo 02 o 03).
// ============================================
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/hetna_api.dart';
import '../services/pdf_service.dart';
import '../services/supabase_service.dart';
import '../i18n/tr.dart';
import 'facturacion_config_screen.dart';

class FacturaScreen extends StatefulWidget {
  final Pedido pedido;
  const FacturaScreen({super.key, required this.pedido});

  @override
  State<FacturaScreen> createState() => _FacturaScreenState();
}

class _FacturaScreenState extends State<FacturaScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _cargando = true;
  bool _timbrando = false;
  bool _ocupado = false;
  String? _error;
  Map<String, dynamic> _estado = {};
  List<Map<String, dynamic>> _facturas = [];

  final _rfcCtrl    = TextEditingController();
  final _razonCtrl  = TextEditingController();
  final _cpCtrl     = TextEditingController();
  final _correoCtrl = TextEditingController();
  String _regimen   = '616';
  String _uso       = 'G03';
  String _formaPago = '03';
  String _metodo    = 'PUE';

  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);

  static const _usos = {
    'G01': 'G01 · Adquisición de mercancías',
    'G03': 'G03 · Gastos en general',
    'I02': 'I02 · Mobiliario y equipo de oficina',
    'I04': 'I04 · Equipo de cómputo y accesorios',
    'I08': 'I08 · Otra maquinaria y equipo',
    'S01': 'S01 · Sin efectos fiscales',
  };

  static const _formas = {
    '03': '03 · Transferencia',
    '01': '01 · Efectivo',
    '04': '04 · Tarjeta de crédito',
    '28': '28 · Tarjeta de débito',
    '02': '02 · Cheque',
    '31': '31 · Intermediario de pagos',
    '99': '99 · Por definir',
  };

  String? get _token => AuthService.sesion?.accessToken;

  Map<String, dynamic>? get _vigente {
    final modo = _estado['modo'] ?? 'prueba';
    for (final f in _facturas) {
      if (f['estado'] != 'cancelada' && f['modo'] == modo) return f;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _rfcCtrl.dispose(); _razonCtrl.dispose(); _cpCtrl.dispose(); _correoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final token = _token;
    if (token == null) {
      setState(() { _cargando = false; _error = tr('Vuelve a iniciar sesión.'); });
      return;
    }
    setState(() { _cargando = true; _error = null; });
    try {
      final pid = widget.pedido.id ?? '';
      final r = await Future.wait([
        FacturaApi.estado(token),
        SupabaseService.getCfdiEmitidos(pedidoId: pid, limite: 10),
        SupabaseService.getDatosFiscalesCliente(widget.pedido.cliente?.id ?? widget.pedido.clienteId ?? ''),
      ]);
      _estado = r[0] as Map<String, dynamic>;
      _facturas = r[1] as List<Map<String, dynamic>>;
      final dc = r[2] as Map<String, dynamic>;
      final cli = widget.pedido.cliente;
      if (_rfcCtrl.text.isEmpty) _rfcCtrl.text = (dc['rfc_fiscal'] ?? cli?.rfc ?? '').toString();
      if (_razonCtrl.text.isEmpty) _razonCtrl.text = (dc['razon_social'] ?? cli?.empresa ?? cli?.nombre ?? '').toString();
      if (_cpCtrl.text.isEmpty) _cpCtrl.text = (dc['cp_fiscal'] ?? cli?.codigoPostal ?? '').toString();
      if (_correoCtrl.text.isEmpty) _correoCtrl.text = (cli?.correo ?? dc['correo'] ?? '').toString();
      final reg = (dc['regimen_fiscal'] ?? '').toString();
      if (_regimenes.containsKey(reg)) _regimen = reg;
      final uso = (dc['uso_cfdi'] ?? '').toString();
      if (_usos.containsKey(uso)) _uso = uso;
      if (mounted) setState(() => _cargando = false);
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _error = e.toString(); });
    }
  }

  Map<String, String> get _regimenes {
    final m = ((_estado['regimenes'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), v.toString()));
    return m.isEmpty ? {'616': 'Sin obligaciones fiscales'} : m;
  }

  void _aviso(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: error ? AppColors.rojo : AppColors.verde));
  }

  void _publicoEnGeneral() {
    final cp = '${((_estado['datos'] as Map?) ?? {})['cp'] ?? ''}';
    setState(() {
      _rfcCtrl.text = 'XAXX010101000';
      _razonCtrl.text = 'PUBLICO EN GENERAL';
      if (cp.length == 5) _cpCtrl.text = cp;
      _regimen = '616';
      _uso = 'S01';
    });
  }

  Future<void> _timbrar() async {
    final token = _token;
    if (token == null || !_formKey.currentState!.validate()) return;
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(tr('¿Timbrar la factura?')),
      content: Text(_estado['modo'] == 'real'
        ? trf('Se emitirá ante el SAT a {0} ({1}). Si algo sale mal se puede cancelar.', [_razonCtrl.text.trim(), _rfcCtrl.text.trim().toUpperCase()])
        : tr('Modo prueba: la factura no tiene validez ante el SAT.')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Cancelar'))),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Timbrar'))),
      ]));
    if (ok != true) return;
    setState(() => _timbrando = true);
    try {
      final r = await FacturaApi.emitir(token, {
        'pedido_id': widget.pedido.id,
        'rfc': _rfcCtrl.text.trim().toUpperCase(),
        'razon_social': _razonCtrl.text.trim(),
        'cp': _cpCtrl.text.trim(),
        'regimen': _regimen,
        'uso': _uso,
        'forma_pago': _metodo == 'PPD' ? '99' : _formaPago,
        'metodo_pago': _metodo,
        'correo': _correoCtrl.text.trim(),
      });
      final extra = r['extra'] == true;
      _aviso(extra
        ? trf('✅ Factura timbrada. Ésta pasó tu cupo del mes: se suman {0} a tu cargo del día 1.', [_fmt.format((r['precio_extra'] ?? 2) as num)])
        : (r['enviada_a'] != null
            ? trf('✅ Factura timbrada y enviada a {0}', [r['enviada_a']])
            : tr('✅ Factura timbrada')));
      await _cargar();
    } catch (e) {
      _aviso(e.toString(), error: true);
    }
    if (mounted) setState(() => _timbrando = false);
  }

  Future<void> _conBytes(String tipo, Future<void> Function(Uint8List bytes, String nombre) hacer) async {
    final token = _token;
    final f = _vigente;
    if (token == null || f == null) return;
    setState(() => _ocupado = true);
    try {
      final bytes = await FacturaApi.archivo(token, f['id'].toString(), tipo);
      final nombre = '${f['serie'] ?? ''}${f['folio'] ?? widget.pedido.folio}.$tipo';
      await hacer(bytes, nombre);
    } catch (e) {
      _aviso(e.toString(), error: true);
    }
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _verPdf() => _conBytes('pdf', (b, _) => PdfService.verPdf(b));

  Future<void> _compartir() async {
    final token = _token;
    final f = _vigente;
    if (token == null || f == null) return;
    setState(() => _ocupado = true);
    try {
      final id = f['id'].toString();
      final r = await Future.wait([FacturaApi.archivo(token, id, 'pdf'), FacturaApi.archivo(token, id, 'xml')]);
      final base = '${f['serie'] ?? ''}${f['folio'] ?? widget.pedido.folio}';
      await Share.shareXFiles([
        XFile.fromData(r[0], name: '$base.pdf', mimeType: 'application/pdf'),
        XFile.fromData(r[1], name: '$base.xml', mimeType: 'application/xml'),
      ], text: trf('Factura {0}', [base]));
    } catch (e) {
      _aviso(e.toString(), error: true);
    }
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _enviarCorreo() async {
    final token = _token;
    final f = _vigente;
    if (token == null || f == null) return;
    final ctrl = TextEditingController(text: (f['receptor_correo'] ?? _correoCtrl.text).toString());
    final correo = await showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: Text(tr('Enviar factura por correo')),
      content: TextField(controller: ctrl, keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(labelText: tr('Correo del cliente'))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancelar'))),
        ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: Text(tr('Enviar'))),
      ]));
    if (correo == null || correo.isEmpty) return;
    setState(() => _ocupado = true);
    try {
      final a = await FacturaApi.enviar(token, f['id'].toString(), correo);
      _aviso(trf('✅ Enviada a {0}', [a ?? correo]));
    } catch (e) {
      _aviso(e.toString(), error: true);
    }
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _cancelar() async {
    final token = _token;
    final f = _vigente;
    if (token == null || f == null) return;
    if (!AuthService.esAdmin) {
      _aviso(tr('Sólo el administrador puede cancelar facturas.'), error: true);
      return;
    }
    String motivo = '02';
    final ok = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: Text(tr('Cancelar factura')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        RadioListTile<String>(value: '02', groupValue: motivo, onChanged: (v) => set(() => motivo = v!), dense: true,
          title: Text(tr('02 · Tiene errores (la vuelvo a hacer)'), style: const TextStyle(fontSize: 13))),
        RadioListTile<String>(value: '03', groupValue: motivo, onChanged: (v) => set(() => motivo = v!), dense: true,
          title: Text(tr('03 · El trabajo no se llevó a cabo'), style: const TextStyle(fontSize: 13))),
        const SizedBox(height: 6),
        Text(tr('Si la factura es de más de \$1,000 o tiene más de 3 días, el cliente puede tener que aceptar la cancelación en el buzón del SAT.'),
          style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('No'))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
          onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Cancelar factura'), style: const TextStyle(color: Colors.white))),
      ])));
    if (ok != true) return;
    setState(() => _ocupado = true);
    try {
      final estado = await FacturaApi.cancelar(token, f['id'].toString(), motivo);
      _aviso(estado == 'cancelacion_pendiente'
        ? tr('Cancelación enviada: falta que el cliente la acepte en el SAT.')
        : tr('Factura cancelada.'));
      await _cargar();
    } catch (e) {
      _aviso(e.toString(), error: true);
    }
    if (mounted) setState(() => _ocupado = false);
  }

  // ── UI ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: Text(trf('Facturar {0}', [widget.pedido.folio]))),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.rojo)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _cargar, child: Text(tr('Reintentar'))),
            ])))
          : ListView(padding: const EdgeInsets.all(16), children: [
              _resumenPedido(),
              const SizedBox(height: 14),
              if (_estado['plan_permite'] != true || _estado['listo'] != true)
                _faltaConfigurar()
              else if (_vigente != null)
                _facturaHecha(_vigente!)
              else
                _formulario(),
              if (_facturas.any((f) => f['estado'] == 'cancelada')) ...[
                const SizedBox(height: 16),
                Text(tr('Canceladas'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textoSecundario)),
                ..._facturas.where((f) => f['estado'] == 'cancelada').map((f) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${f['serie'] ?? ''}${f['folio'] ?? ''} · ${f['receptor_rfc'] ?? ''} · ${_fmt.format((f['total'] ?? 0) as num)}',
                    style: const TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough)))),
              ],
              const SizedBox(height: 30),
            ]));
  }

  Widget _caja({required Widget child, Color color = Colors.white}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: child);

  Widget _resumenPedido() {
    final prueba = _estado['modo'] != 'real' && _estado['disponible'] == true;
    return _caja(color: AppColors.azulClaro, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.assignment_outlined, size: 16, color: AppColors.azul),
        const SizedBox(width: 8),
        Text(widget.pedido.folio, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
        const Spacer(),
        if (prueba) Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(20)),
          child: Text(tr('Modo prueba'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.naranja))),
      ]),
      const SizedBox(height: 6),
      Text(widget.pedido.cliente?.nombre ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(trf('Total del pedido: {0}', [_fmt.format(widget.pedido.total ?? 0)]),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      Text(tr('Los conceptos, el descuento, el envío y el IVA salen de la cotización del pedido.'),
        style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
    ]));
  }

  Widget _faltaConfigurar() {
    final permite = _estado['plan_permite'] == true;
    final pendientes = ((_estado['pendientes'] as List?) ?? []).map((e) => tr(e.toString())).toList();
    return _caja(color: AppColors.naranjaClaro, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(permite ? tr('Antes de facturar, configura tu factura electrónica') : tr('La factura electrónica viene desde el plan Taller'),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      ...pendientes.map((p) => Text('•  $p', style: const TextStyle(fontSize: 12))),
      const SizedBox(height: 10),
      ElevatedButton.icon(
        onPressed: () async {
          if (!permite) {
            await AuthService.exigirModulo(context, 'facturacion', funcion: tr('Facturación (CFDI)'));
            return;
          }
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const FacturacionConfigScreen()));
          _cargar();
        },
        icon: const Icon(Icons.settings_outlined, size: 16),
        label: Text(permite ? tr('Configurar ahora') : tr('Ver planes'))),
    ]));
  }

  Widget _facturaHecha(Map<String, dynamic> f) {
    final pendiente = f['estado'] == 'cancelacion_pendiente';
    final folio = '${f['serie'] ?? ''}${f['folio'] ?? ''}';
    return _caja(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(pendiente ? Icons.hourglass_top : Icons.verified, color: pendiente ? AppColors.naranja : AppColors.verde),
        const SizedBox(width: 8),
        Expanded(child: Text(pendiente ? tr('Cancelación pendiente') : trf('Factura {0} timbrada', [folio]),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 8),
      Text('${f['receptor_nombre'] ?? ''} · ${f['receptor_rfc'] ?? ''}', style: const TextStyle(fontSize: 12)),
      if ((f['uuid'] ?? '').toString().isNotEmpty)
        SelectableText(trf('Folio fiscal: {0}', [f['uuid']]), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      const SizedBox(height: 6),
      Text(trf('Subtotal {0} · IVA {1} · Total {2}', [
        _fmt.format((f['subtotal'] ?? 0) as num), _fmt.format((f['iva'] ?? 0) as num), _fmt.format((f['total'] ?? 0) as num)]),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      if (_ocupado) const LinearProgressIndicator(),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ElevatedButton.icon(onPressed: _ocupado ? null : _verPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16), label: Text(tr('Ver PDF'))),
        OutlinedButton.icon(onPressed: _ocupado ? null : _compartir,
          icon: const Icon(Icons.share_outlined, size: 16), label: Text(tr('Compartir PDF y XML'))),
        OutlinedButton.icon(onPressed: _ocupado ? null : _enviarCorreo,
          icon: const Icon(Icons.email_outlined, size: 16), label: Text(tr('Enviar por correo'))),
        if (!pendiente && AuthService.esAdmin) TextButton.icon(onPressed: _ocupado ? null : _cancelar,
          icon: const Icon(Icons.block, size: 16, color: AppColors.rojo),
          label: Text(tr('Cancelar factura'), style: const TextStyle(color: AppColors.rojo))),
      ]),
    ]));
  }

  Widget _campo(TextEditingController c, String etiqueta, {String? hint, TextInputType? tipo, bool mayus = false,
      int? max, String? Function(String?)? validar}) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: TextFormField(
      controller: c, keyboardType: tipo, maxLength: max, validator: validar,
      textCapitalization: mayus ? TextCapitalization.characters : TextCapitalization.none,
      decoration: InputDecoration(labelText: etiqueta, hintText: hint, isDense: true, counterText: '',
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))));

  Widget _lista(String etiqueta, String valor, Map<String, String> opciones, ValueChanged<String> cambio) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: DropdownButtonFormField<String>(
      value: opciones.containsKey(valor) ? valor : opciones.keys.first, isExpanded: true,
      decoration: InputDecoration(labelText: etiqueta, isDense: true, filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      items: opciones.entries.map((e) => DropdownMenuItem(value: e.key,
        child: Text(tr(e.value), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) { if (v != null) setState(() => cambio(v)); }));

  Widget _formulario() {
    final regimenes = _regimenes.map((k, v) => MapEntry(k, '$k · $v'));
    return Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(tr('Datos fiscales del cliente'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul))),
        TextButton(onPressed: _publicoEnGeneral, child: Text(tr('Público en general'), style: const TextStyle(fontSize: 12))),
      ]),
      Text(tr('Pídele al cliente su Constancia de Situación Fiscal y copia los datos tal cual.'),
        style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      const SizedBox(height: 10),
      _campo(_rfcCtrl, tr('RFC'), hint: 'XAXX010101000', mayus: true, max: 13, validar: (v) {
        final r = (v ?? '').trim().toUpperCase();
        if (!RegExp(r'^[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}$').hasMatch(r)) return tr('RFC inválido (12 o 13 caracteres)');
        return null;
      }),
      _campo(_razonCtrl, tr('Razón social o nombre'), hint: tr('Sin "S.A. de C.V." al final'), mayus: true,
        validar: (v) => (v ?? '').trim().isEmpty ? tr('Campo requerido') : null),
      _campo(_cpCtrl, tr('Código postal fiscal'), hint: '90300', tipo: TextInputType.number, max: 5,
        validar: (v) => (v ?? '').trim().length != 5 ? tr('CP debe tener 5 dígitos') : null),
      _lista(tr('Régimen fiscal del cliente'), _regimen, regimenes, (v) => _regimen = v),
      _lista(tr('Uso del CFDI'), _uso, _usos, (v) => _uso = v),
      const SizedBox(height: 4),
      Text(tr('Pago'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'PUE', label: Text(tr('Ya pagó (PUE)'), style: const TextStyle(fontSize: 12))),
          ButtonSegment(value: 'PPD', label: Text(tr('Paga después (PPD)'), style: const TextStyle(fontSize: 12))),
        ],
        selected: {_metodo},
        onSelectionChanged: (s) => setState(() => _metodo = s.first)),
      const SizedBox(height: 10),
      if (_metodo == 'PUE') _lista(tr('Forma de pago'), _formaPago, _formas, (v) => _formaPago = v)
      else Padding(padding: const EdgeInsets.only(bottom: 10),
        child: Text(tr('Con PPD la forma de pago va como 99 (por definir). Cuando te paguen, se hace el complemento de pago.'),
          style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
      _campo(_correoCtrl, tr('Correo para mandarle la factura (opcional)'), tipo: TextInputType.emailAddress),
      const SizedBox(height: 6),
      SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(
        onPressed: _timbrando ? null : _timbrar,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul),
        icon: _timbrando
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.receipt_long, color: Colors.white),
        label: Text(_timbrando ? tr('Timbrando…') : tr('Timbrar factura'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
    ]));
  }
}
