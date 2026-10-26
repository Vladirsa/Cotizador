// ============================================
// lib/screens/factura_screen.dart
// ============================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../i18n/tr.dart';

class FacturaScreen extends StatefulWidget {
  final Pedido pedido;
  const FacturaScreen({super.key, required this.pedido});

  @override
  State<FacturaScreen> createState() => _FacturaScreenState();
}

class _FacturaScreenState extends State<FacturaScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _cargando = true;
  bool _generando = false;
  bool _facturaActivada = false;
  Map<String, dynamic> _cfg = {};

  // Datos fiscales del receptor
  final _rfcCtrl         = TextEditingController();
  final _razonCtrl       = TextEditingController();
  final _cpCtrl          = TextEditingController();
  String _regimenReceptor = '616';
  String _usoCFDI         = 'G03';

  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);

  // Catálogos SAT
  final _regimenes = {
    '601': '601 - General Personas Morales',
    '612': '612 - Act. Empresariales y Profesionales',
    '616': '616 - Sin Obligaciones Fiscales',
    '621': '621 - Incorporación Fiscal',
    '626': '626 - RESICO',
  };

  final _usosCFDI = {
    'G01': 'G01 - Adquisición de mercancias',
    'G03': 'G03 - Gastos en general',
    'I01': 'I01 - Construcciones',
    'I04': 'I04 - Equipo de computo',
    'S01': 'S01 - Sin efectos fiscales',
    'CP01': 'CP01 - Pagos',
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _rfcCtrl.dispose(); _razonCtrl.dispose(); _cpCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final cfg = await SupabaseService.getConfiguracion();
      _cfg = cfg;
      _facturaActivada = cfg['factura_activo'] ?? false;

      // Prellenar con datos fiscales del cliente si los tiene
      final cliente = widget.pedido.cliente;
      if (cliente != null) {
        // Cargar datos fiscales del cliente desde BD
        final datosCliente = await SupabaseService.getDatosFiscalesCliente(cliente.id ?? '');
        _rfcCtrl.text         = datosCliente['rfc_fiscal'] ?? '';
        _razonCtrl.text       = datosCliente['razon_social'] ?? cliente.nombre;
        _cpCtrl.text          = datosCliente['cp_fiscal'] ?? '';
        _regimenReceptor      = datosCliente['regimen_fiscal'] ?? '616';
        _usoCFDI              = datosCliente['uso_cfdi'] ?? 'G03';
      }
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  double get _subtotal => (widget.pedido.total ?? 0) / 1.16;
  double get _iva      => _subtotal * 0.16;
  double get _total    => widget.pedido.total ?? 0;

  Future<void> _guardarDatosFiscales() async {
    if (widget.pedido.cliente?.id == null) return;
    try {
      await SupabaseService.guardarDatosFiscalesCliente(
        clienteId: widget.pedido.cliente!.id!,
        datos: {
          'rfc_fiscal'     : _rfcCtrl.text.trim().toUpperCase(),
          'razon_social'   : _razonCtrl.text.trim(),
          'cp_fiscal'      : _cpCtrl.text.trim(),
          'regimen_fiscal' : _regimenReceptor,
          'uso_cfdi'       : _usoCFDI,
        });
    } catch (_) {}
  }

  Future<void> _generarFactura() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _generando = true);

    try {
      await _guardarDatosFiscales();

      final datosFactura = {
        'pedido_id'          : widget.pedido.id,
        'cotizacion_id'      : widget.pedido.cotizacionId,
        'cliente_id'         : widget.pedido.cliente?.id,
        'subtotal'           : _subtotal,
        'iva'                : _iva,
        'total'              : _total,
        'datos_envio'        : {
          'rfc_receptor'     : _rfcCtrl.text.trim().toUpperCase(),
          'razon_social'     : _razonCtrl.text.trim(),
          'cp_fiscal'        : _cpCtrl.text.trim(),
          'regimen_receptor' : _regimenReceptor,
          'uso_cfdi'         : _usoCFDI,
          'rfc_emisor'       : _cfg['factura_rfc_emisor'] ?? '',
          'regimen_emisor'   : _cfg['factura_regimen_fiscal'] ?? '612',
          'serie'            : _cfg['factura_serie'] ?? 'A',
          'proveedor'        : _cfg['factura_proveedor'] ?? 'Facturapi',
          'api_url'          : _cfg['factura_api_url'] ?? '',
          // api_key NO se guarda en el snapshot por seguridad
        },
      };

      // Guardar en tabla facturas con estado pendiente
      await SupabaseService.crearFacturaPendiente(datosFactura);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('✅ Datos guardados — factura lista para timbrar cuando configures tu proveedor')),
          backgroundColor: AppColors.verde,
          duration: Duration(seconds: 4)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    }
    if (mounted) setState(() => _generando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Generar factura'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : Form(key: _formKey,
            child: ListView(padding: const EdgeInsets.all(16), children: [

              // ── RESUMEN DEL PEDIDO ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.azul.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.azul.withOpacity(0.2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.assignment_outlined, size: 16, color: AppColors.azul),
                    const SizedBox(width: 8),
                    Text(widget.pedido.folio,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.verde.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                      child: Text(widget.pedido.estado,
                        style: const TextStyle(fontSize: 10, color: AppColors.verde, fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 8),
                  Text(tr(widget.pedido.cliente?.nombre ?? '—'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const Divider(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Subtotal:', style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                    Text(_fmt.format(_subtotal), style: const TextStyle(fontSize: 12)),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(tr('IVA 16%:'), style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                    Text(_fmt.format(_iva), style: const TextStyle(fontSize: 12)),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(_fmt.format(_total),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.azul)),
                  ]),
                ])),

              const SizedBox(height: 16),

              // ── AVISO SI NO ESTÁ ACTIVADA ──
              if (!_facturaActivada)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFE08A))),
                  child: Row(children: [
                    Icon(Icons.warning_amber_outlined, size: 18, color: Color(0xFF856404)),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      tr('La facturación no está activada. Ve a Configuración → Facturación para conectar tu proveedor.'),
                      style: TextStyle(fontSize: 11, color: Color(0xFF856404)))),
                  ])),

              // ── DATOS DEL RECEPTOR ──
              _seccion(tr('📋 DATOS FISCALES DEL RECEPTOR')),
              const SizedBox(height: 8),

              _campo(_rfcCtrl, tr('RFC del receptor *'), Icons.badge_outlined,
                mayusculas: true, hint: 'XAXX010101000',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return tr('RFC requerido');
                  final rfc = v.trim().toUpperCase();
                  if (rfc.length < 12 || rfc.length > 13) return tr('RFC inválido (12-13 caracteres)');
                  return null;
                }),

              _campo(_razonCtrl, tr('Razón social *'), Icons.business_outlined,
                hint: tr('Nombre como aparece en el SAT'),
                validator: (v) => (v == null || v.trim().isEmpty) ? tr('Campo requerido') : null),

              _campo(_cpCtrl, tr('Código postal fiscal *'), Icons.location_on_outlined,
                tipo: TextInputType.number, hint: '12345',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return tr('CP requerido');
                  if (v.trim().length != 5) return tr('CP debe tener 5 dígitos');
                  return null;
                }),

              // Régimen fiscal receptor
              Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.grisBorde, width: 0.5)),
                  child: DropdownButtonFormField<String>(
                    value: _regimenReceptor,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr('Régimen fiscal receptor'),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.account_balance_outlined, size: 18, color: AppColors.azul)),
                    items: _regimenes.entries.map((e) =>
                      DropdownMenuItem(value: e.key,
                        child: Text(tr(e.value), style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setState(() => _regimenReceptor = v!)))),

              // Uso CFDI
              Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.grisBorde, width: 0.5)),
                  child: DropdownButtonFormField<String>(
                    value: _usoCFDI,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr('Uso del CFDI'),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.receipt_outlined, size: 18, color: AppColors.azul)),
                    items: _usosCFDI.entries.map((e) =>
                      DropdownMenuItem(value: e.key,
                        child: Text(tr(e.value), style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setState(() => _usoCFDI = v!)))),

              const SizedBox(height: 8),

              // Nota informativa
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.grisBorde)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.save_outlined, size: 14, color: AppColors.textoSecundario),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    tr('Los datos fiscales se guardarán en el perfil del cliente para futuras facturas.'),
                    style: TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
                ])),

              const SizedBox(height: 20),

              // Botón generar
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generando ? null : _generarFactura,
                  icon: _generando
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.receipt_long_outlined, color: Colors.white),
                  label: Text(tr(_generando ? tr('Guardando...') : tr('Guardar datos de factura')),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1a3a5c),
                    padding: const EdgeInsets.symmetric(vertical: 14)))),

              const SizedBox(height: 8),

              if (!_facturaActivada)
                SizedBox(width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Ir a Configuración — navegar desde home
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(tr('Ve a Más → Configuración para activar la facturación')),
                        duration: Duration(seconds: 3)));
                    },
                    icon: const Icon(Icons.settings_outlined, size: 14),
                    label: Text(tr('Ir a Configuración'), style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.azul,
                      side: const BorderSide(color: AppColors.azul),
                      padding: const EdgeInsets.symmetric(vertical: 12)))),

              const SizedBox(height: 30),
            ])));
  }

  Widget _seccion(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(tr(titulo),
      style: const TextStyle(fontSize: 11, color: AppColors.azul,
        fontWeight: FontWeight.w700, letterSpacing: 0.5)));

  Widget _campo(TextEditingController ctrl, String label, IconData icono, {
    TextInputType tipo = TextInputType.text, String? hint,
    bool mayusculas = false, String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      textCapitalization: mayusculas ? TextCapitalization.characters : TextCapitalization.sentences,
      validator: validator,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        hintStyle: const TextStyle(fontSize: 11, color: AppColors.textoSecundario),
        prefixIcon: Icon(icono, size: 18, color: AppColors.azul),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.grisBorde, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.grisBorde, width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.azul, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.rojo, width: 1)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))));
}
