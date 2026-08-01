// ============================================
// lib/screens/config_screen.dart
// ============================================
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';
import '../services/notificaciones_service.dart';
import '../services/supabase_service.dart';
import '../services/woocommerce_service.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _cargando = true;
  bool _guardando = false;

  // Empresa
  final _nombreCtrl   = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl   = TextEditingController();
  final _direccionCtrl= TextEditingController();
  final _rfcCtrl      = TextEditingController();
  final _leyendaCtrl  = TextEditingController();
  String? _logoUrl;
  Uint8List? _logoPreview;
  bool _subiendoLogo = false;
  String _colorPrimario = '#1a3a5c';
  String _colorSecundario = '#185fa5';
  final _coloresDisponibles = [
    {'nombre': 'Azul HETNA', 'primario': '#1a3a5c', 'secundario': '#185fa5'},
    {'nombre': 'Verde', 'primario': '#0f4c3a', 'secundario': '#1d9e75'},
    {'nombre': 'Morado', 'primario': '#3b1f5c', 'secundario': '#7c3aed'},
    {'nombre': 'Rojo', 'primario': '#5c1a1a', 'secundario': '#dc2626'},
    {'nombre': 'Naranja', 'primario': '#5c3a1a', 'secundario': '#ea580c'},
    {'nombre': 'Negro/Gris', 'primario': '#1f2937', 'secundario': '#4b5563'},
  ];

  // WhatsApp


  // Facturación
  final _apiKeyCtrl   = TextEditingController();
  final _apiUrlCtrl   = TextEditingController();
  final _rfcEmisorCtrl= TextEditingController();
  final _serieCtrl    = TextEditingController();
  bool _facturaActivo = false;
  String _proveedor   = 'Facturapi';
  String _regimenFiscal = '612';

  final _proveedores = ['Facturapi', 'SAT Directo', 'Contpaqi', 'Aspel', 'Otro'];
  final _regimenesFiscales = {
    '601': '601 - General de Ley Personas Morales',
    '612': '612 - Personas Físicas con Actividades Empresariales',
    '616': '616 - Sin Obligaciones Fiscales',
    '621': '621 - Incorporación Fiscal',
    '626': '626 - Régimen Simplificado de Confianza',
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _telefonoCtrl.dispose(); _correoCtrl.dispose();
    _direccionCtrl.dispose(); _rfcCtrl.dispose(); _leyendaCtrl.dispose();
    _apiKeyCtrl.dispose(); _apiUrlCtrl.dispose();
    _rfcEmisorCtrl.dispose(); _serieCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final cfg = await SupabaseService.getConfiguracion();
    setState(() {
      _nombreCtrl.text    = cfg['nombre_comercial'] ?? 'HETNA CNC';
      _telefonoCtrl.text  = cfg['telefono'] ?? '';
      _correoCtrl.text    = cfg['correo'] ?? '';
      _direccionCtrl.text = cfg['direccion'] ?? '';
      _rfcCtrl.text       = cfg['rfc'] ?? '';
      _leyendaCtrl.text   = cfg['leyenda_pdf'] ?? '';
      _logoUrl            = cfg['logo_url'];
      _colorPrimario      = cfg['color_primario'] ?? '#1a3a5c';
      _colorSecundario    = cfg['color_secundario'] ?? '#185fa5';
      // Facturación
      _apiKeyCtrl.text    = cfg['factura_api_key'] ?? '';
      _apiUrlCtrl.text    = cfg['factura_api_url'] ?? '';
      _rfcEmisorCtrl.text = cfg['factura_rfc_emisor'] ?? '';
      _serieCtrl.text     = cfg['factura_serie'] ?? 'A';
      _facturaActivo      = cfg['factura_activo'] ?? false;
      _proveedor          = cfg['factura_proveedor'] ?? 'Facturapi';
      _regimenFiscal      = cfg['factura_regimen_fiscal'] ?? '612';
      _cargando = false;
    });
  }

  Future<void> _elegirLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      setState(() { _logoPreview = bytes; _subiendoLogo = true; });

      final ext = (file.extension ?? 'png').toLowerCase();
      final url = await SupabaseService.subirLogo(bytes, ext);

      if (url != null) {
        setState(() { _logoUrl = url; _subiendoLogo = false; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Logo actualizado — no olvides guardar'), backgroundColor: AppColors.azul));
      } else {
        setState(() => _subiendoLogo = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo subir el logo'), backgroundColor: AppColors.rojo));
      }
    } catch (e) {
      setState(() => _subiendoLogo = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await SupabaseService.guardarConfiguracion({
        'nombre_comercial'      : _nombreCtrl.text.trim(),
        'telefono'              : _telefonoCtrl.text.trim(),
        'correo'                : _correoCtrl.text.trim(),
        'direccion'             : _direccionCtrl.text.trim(),
        'rfc'                   : _rfcCtrl.text.trim().toUpperCase(),
        'leyenda_pdf'           : _leyendaCtrl.text.trim(),
        'color_primario'        : _colorPrimario,
        'color_secundario'      : _colorSecundario,
        if (_logoUrl != null) 'logo_url': _logoUrl,
        'factura_api_key'       : _apiKeyCtrl.text.trim(),
        'factura_api_url'       : _apiUrlCtrl.text.trim(),
        'factura_rfc_emisor'    : _rfcEmisorCtrl.text.trim().toUpperCase(),
        'factura_serie'         : _serieCtrl.text.trim().toUpperCase(),
        'factura_activo'        : _facturaActivo,
        'factura_proveedor'     : _proveedor,
        'factura_regimen_fiscal': _regimenFiscal,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Configuración guardada'),
        backgroundColor: AppColors.verde));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    }
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.azul))),
        ]),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : Form(key: _formKey,
            child: ListView(padding: const EdgeInsets.all(16), children: [

              // ── DATOS DE LA EMPRESA ──
              _seccion('🏢 DATOS DE LA EMPRESA'),
              const SizedBox(height: 8),
              _campo(_nombreCtrl, 'Nombre comercial', Icons.store_outlined, requerido: true),
              _campo(_rfcCtrl, 'RFC', Icons.badge_outlined, mayusculas: true,
                hint: 'XAXX010101000'),
              _campo(_telefonoCtrl, 'Teléfono / WhatsApp', Icons.phone_outlined,
                tipo: TextInputType.phone),
              _campo(_correoCtrl, 'Correo electrónico', Icons.email_outlined,
                tipo: TextInputType.emailAddress),
              _campo(_direccionCtrl, 'Dirección', Icons.location_on_outlined, lineas: 2),
              _campo(_leyendaCtrl, 'Leyenda en PDF', Icons.notes_outlined, lineas: 2,
                hint: 'Ej: Garantía 6 meses en productos de madera'),

              const SizedBox(height: 20),

              // ── WOOCOMMERCE ──
              _seccion('🛍️ SINCRONIZAR CON TU TIENDA WOOCOMMERCE'),
              const SizedBox(height: 8),
              _CardWooCommerce(),

              const SizedBox(height: 20),

              // ── LOGO Y COLORES DE MARCA ──
              _seccion('🎨 LOGO Y COLORES DE TUS PDFs'),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.grisBorde, width: 0.5)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Logo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(width: 70, height: 70,
                      decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.grisBorde)),
                      child: _logoPreview != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(9),
                            child: Image.memory(_logoPreview!, fit: BoxFit.contain))
                        : (_logoUrl != null && _logoUrl!.isNotEmpty)
                          ? ClipRRect(borderRadius: BorderRadius.circular(9),
                              child: Image.network(_logoUrl!, fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined,
                                  color: AppColors.textoSecundario)))
                          : const Icon(Icons.image_outlined, color: AppColors.textoSecundario, size: 28)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      OutlinedButton.icon(
                        onPressed: _subiendoLogo ? null : _elegirLogo,
                        icon: _subiendoLogo
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_outlined, size: 16),
                        label: Text(_subiendoLogo ? 'Subiendo...' : 'Cambiar logo'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.azul,
                          side: const BorderSide(color: AppColors.azul))),
                      const SizedBox(height: 4),
                      const Text('Aparecerá en cotizaciones y notas de compra',
                        style: TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
                    ])),
                  ]),
                  const SizedBox(height: 16),
                  const Text('Color de marca', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 10, runSpacing: 10, children: _coloresDisponibles.map((c) {
                    final sel = _colorPrimario == c['primario'];
                    final colorObj = Color(int.parse((c['primario'] as String).replaceFirst('#', '0xFF')));
                    return GestureDetector(
                      onTap: () => setState(() {
                        _colorPrimario = c['primario'] as String;
                        _colorSecundario = c['secundario'] as String;
                      }),
                      child: Column(children: [
                        Container(width: 42, height: 42,
                          decoration: BoxDecoration(color: colorObj, shape: BoxShape.circle,
                            border: Border.all(color: sel ? Colors.black : Colors.transparent, width: 2.5)),
                          child: sel ? const Icon(Icons.check, color: Colors.white, size: 20) : null),
                        const SizedBox(height: 3),
                        Text(c['nombre'] as String, style: const TextStyle(fontSize: 9, color: AppColors.textoSecundario)),
                      ]));
                  }).toList()),
                ])),

              const SizedBox(height: 20),

              // ── CATEGORÍAS DE PRODUCTOS ──
              _seccion('🏷️ CATEGORÍAS DE PRODUCTOS'),
              const SizedBox(height: 8),
              _CategoriasWidget(),

              const SizedBox(height: 20),

              const SizedBox(height: 20),

              // ── NOTIFICACIONES ──
              _seccion('🔔 NOTIFICACIONES'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.grisBorde, width: 0.5)),
                child: Column(children: [
                  const Row(children: [
                    Icon(Icons.notifications_active_outlined, size: 18, color: AppColors.azul),
                    SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Alertas en tiempo real', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('Supabase Realtime activo — recibes notificaciones de nuevos pedidos, alertas y seguimientos automáticamente',
                        style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                    ])),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await NotificacionesService.probar();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('✅ Notificación de prueba enviada — revisa tu barra'),
                          backgroundColor: AppColors.verde));
                      },
                      icon: const Icon(Icons.notifications_outlined, size: 16),
                      label: const Text('Probar notificación', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.azul,
                        side: const BorderSide(color: AppColors.azul),
                        padding: const EdgeInsets.symmetric(vertical: 10)))),
                ])),

              const SizedBox(height: 20),

              // ── FACTURACIÓN ──
              _seccion('🧾 FACTURACIÓN ELECTRÓNICA'),
              const SizedBox(height: 8),

              // Toggle activar facturación
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.grisBorde, width: 0.5)),
                child: Row(children: [
                  const Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.azul),
                  const SizedBox(width: 10),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Activar facturación', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('Habilita el botón de facturar en pedidos',
                      style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                  ])),
                  Switch(
                    value: _facturaActivo,
                    activeColor: AppColors.azul,
                    onChanged: (v) => setState(() => _facturaActivo = v)),
                ])),

              if (_facturaActivo) ...[
                const SizedBox(height: 10),

                // Proveedor
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.grisBorde, width: 0.5)),
                  child: DropdownButtonFormField<String>(
                    value: _proveedor,
                    decoration: const InputDecoration(
                      labelText: 'Proveedor de facturación',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.cloud_outlined, size: 18, color: AppColors.azul)),
                    items: _proveedores.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) => setState(() => _proveedor = v!))),

                const SizedBox(height: 8),

                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.azul.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.azul.withOpacity(0.2))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.info_outline, size: 14, color: AppColors.azul),
                      const SizedBox(width: 6),
                      Text('Configuración de $_proveedor',
                        style: const TextStyle(fontSize: 12, color: AppColors.azul, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 6),
                    const Text(
                      'Obtén tu API Key desde el panel de tu proveedor y pégala aquí. '
                      'Cuando estés listo, la conexión se activa automáticamente.',
                      style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                  ])),

                const SizedBox(height: 8),

                // API Key
                _campoPassword(_apiKeyCtrl, 'API Key', Icons.key_outlined,
                  hint: 'sk_live_xxxxxxxxxxxxxxxxxxxx'),

                // API URL
                _campo(_apiUrlCtrl, 'URL del API', Icons.link_outlined,
                  tipo: TextInputType.url,
                  hint: 'https://api.facturapi.io/v2'),

                // RFC emisor
                _campo(_rfcEmisorCtrl, 'RFC del emisor (tu empresa)', Icons.badge_outlined,
                  mayusculas: true, hint: 'XAXX010101000'),

                // Régimen fiscal
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.grisBorde, width: 0.5)),
                  child: DropdownButtonFormField<String>(
                    value: _regimenFiscal,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Régimen fiscal',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.account_balance_outlined, size: 18, color: AppColors.azul)),
                    items: _regimenesFiscales.entries.map((e) =>
                      DropdownMenuItem(value: e.key,
                        child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setState(() => _regimenFiscal = v!))),

                // Serie
                _campo(_serieCtrl, 'Serie de comprobante', Icons.tag_outlined,
                  hint: 'A', mayusculas: true),

                const SizedBox(height: 8),

                // Estado de conexión
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _apiKeyCtrl.text.isNotEmpty
                      ? AppColors.verde.withOpacity(0.05)
                      : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _apiKeyCtrl.text.isNotEmpty
                        ? AppColors.verde.withOpacity(0.3)
                        : AppColors.grisBorde)),
                  child: Row(children: [
                    Icon(
                      _apiKeyCtrl.text.isNotEmpty ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                      size: 16,
                      color: _apiKeyCtrl.text.isNotEmpty ? AppColors.verde : AppColors.textoSecundario),
                    const SizedBox(width: 8),
                    Text(
                      _apiKeyCtrl.text.isNotEmpty
                        ? 'API Key configurada — lista para conectar'
                        : 'Pendiente configurar API Key',
                      style: TextStyle(
                        fontSize: 12,
                        color: _apiKeyCtrl.text.isNotEmpty ? AppColors.verde : AppColors.textoSecundario)),
                  ])),
              ],

              const SizedBox(height: 32),
            ])));
  }

  Widget _seccion(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(titulo,
      style: const TextStyle(fontSize: 11, color: AppColors.azul,
        fontWeight: FontWeight.w700, letterSpacing: 0.5)));

  Widget _campo(TextEditingController ctrl, String label, IconData icono, {
    TextInputType tipo = TextInputType.text,
    String? hint, bool requerido = false, bool mayusculas = false, int lineas = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      maxLines: lineas,
      textCapitalization: mayusculas ? TextCapitalization.characters : TextCapitalization.sentences,
      validator: requerido ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null : null,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
        prefixIcon: Icon(icono, size: 18, color: AppColors.azul),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.grisBorde, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.grisBorde, width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.azul, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))));

  Widget _campoPassword(TextEditingController ctrl, String label, IconData icono, {String? hint}) {
    bool oculto = true;
    return StatefulBuilder(builder: (_, setS) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: ctrl,
        obscureText: oculto,
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          hintStyle: const TextStyle(fontSize: 11, color: AppColors.textoSecundario),
          prefixIcon: Icon(icono, size: 18, color: AppColors.azul),
          suffixIcon: IconButton(
            icon: Icon(oculto ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: AppColors.textoSecundario),
            onPressed: () => setS(() => oculto = !oculto)),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.grisBorde, width: 0.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.grisBorde, width: 0.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.azul, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)))));
  }
}

// ══════════════════════════════════════════════
// Widget CRUD de Categorías de Productos
// ══════════════════════════════════════════════
class _CategoriasWidget extends StatefulWidget {
  const _CategoriasWidget();
  @override
  State<_CategoriasWidget> createState() => _CategoriasWidgetState();
}

class _CategoriasWidgetState extends State<_CategoriasWidget> {
  List<Map<String, dynamic>> _cats = [];
  bool _cargando = true;

  final _iconos = ['box','wood','metal','laser','cnc','tool','star','home','gift','custom'];
  final _colores = ['#1a3a5c','#1d9e75','#e24b4a','#ef9f27','#7c3aed','#0ea5e9','#f59e0b','#10b981'];

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await SupabaseService.getCategoriasMap();
      if (mounted) setState(() { _cats = res; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  Future<void> _agregar() async {
    final nombreCtrl = TextEditingController();
    String colorSel = _colores.first;
    final result = await showDialog<String>(context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('Nueva categoría', style: TextStyle(fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nombreCtrl, autofocus: true,
            decoration: const InputDecoration(labelText: 'Nombre *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          const Align(alignment: Alignment.centerLeft,
            child: Text('Color', style: TextStyle(fontSize: 12, color: AppColors.textoSecundario))),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: _colores.map((hex) {
            final color = Color(int.parse('FF${hex.replaceAll('#','')}', radix: 16));
            return GestureDetector(
              onTap: () => setS(() => colorSel = hex),
              child: Container(width: 28, height: 28,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                  border: Border.all(
                    color: colorSel == hex ? Colors.black : Colors.transparent, width: 2))));
          }).toList()),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (nombreCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, nombreCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul),
            child: const Text('Agregar', style: TextStyle(color: Colors.white))),
        ])));
    if (result == null) return;
    try {
      await SupabaseService.crearCategoria({'nombre': result, 'color_hex': colorSel, 'icono': 'box'});
      await _cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _editar(Map<String, dynamic> cat) async {
    final nombreCtrl = TextEditingController(text: cat['nombre']);
    String colorSel = cat['color_hex'] ?? _colores.first;
    final result = await showDialog<String>(context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('Editar categoría', style: TextStyle(fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nombreCtrl,
            decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          const Align(alignment: Alignment.centerLeft,
            child: Text('Color', style: TextStyle(fontSize: 12, color: AppColors.textoSecundario))),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: _colores.map((hex) {
            final color = Color(int.parse('FF${hex.replaceAll('#','')}', radix: 16));
            return GestureDetector(
              onTap: () => setS(() => colorSel = hex),
              child: Container(width: 28, height: 28,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                  border: Border.all(
                    color: colorSel == hex ? Colors.black : Colors.transparent, width: 2))));
          }).toList()),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nombreCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul),
            child: const Text('Guardar', style: TextStyle(color: Colors.white))),
        ])));
    if (result == null || result.isEmpty) return;
    try {
      await SupabaseService.actualizarCategoria(cat['id'], {'nombre': result, 'color_hex': colorSel});
      await _cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _eliminar(Map<String, dynamic> cat) async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${cat['nombre']}"? Los productos de esta categoría quedarán sin categoría.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white))),
        ]));
    if (ok != true) return;
    try {
      await SupabaseService.eliminarCategoria(cat['id']);
      await _cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Botón agregar
      SizedBox(width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _agregar,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Agregar categoría', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.azul,
            side: const BorderSide(color: AppColors.azul),
            padding: const EdgeInsets.symmetric(vertical: 10)))),
      const SizedBox(height: 8),
      // Lista de categorías
      if (_cargando)
        const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
      else if (_cats.isEmpty)
        Container(padding: const EdgeInsets.all(16), alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: const Text('No hay categorías. Agrega la primera.',
            style: TextStyle(color: AppColors.textoSecundario, fontSize: 12)))
      else
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Column(children: _cats.asMap().entries.map((e) {
            final cat = e.value;
            final isLast = e.key == _cats.length - 1;
            final hexColor = cat['color_hex'] ?? '#1a3a5c';
            final color = Color(int.parse('FF${hexColor.replaceAll('#','')}', radix: 16));
            return Column(children: [
              ListTile(dense: true,
                leading: Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.label_outline, color: color, size: 18)),
                title: Text(cat['nombre'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textoSecundario),
                    onPressed: () => _editar(cat),
                    constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.rojo),
                    onPressed: () => _eliminar(cat),
                    constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                ])),
              if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
            ]);
          }).toList())),
    ]);
  }
}

// ── Tarjeta de configuración de WooCommerce ─────────────
class _CardWooCommerce extends StatefulWidget {
  @override
  State<_CardWooCommerce> createState() => _CardWooCommerceState();
}

class _CardWooCommerceState extends State<_CardWooCommerce> {
  final _urlAutoCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  bool _cargando = true;
  bool _conectado = false;
  bool _conectandoAuto = false;
  bool _esperandoAprobacion = false;
  String? _tokenPendiente;
  bool _mostrarManual = false;
  bool _probando = false;
  bool _sincronizando = false;
  String? _resultadoPrueba;
  bool _resultadoOk = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final config = await WooCommerceService.obtenerConfig();
    if (config != null && (config['woocommerce_url'] as String?)?.isNotEmpty == true) {
      _urlCtrl.text = config['woocommerce_url'] ?? '';
      _keyCtrl.text = config['woocommerce_consumer_key'] ?? '';
      _secretCtrl.text = config['woocommerce_consumer_secret'] ?? '';
      _conectado = true;
      _resultadoOk = true;
    }
    if (mounted) setState(() => _cargando = false);
  }

  // ── Conexión automática — el usuario solo aprueba, sin copiar nada ──
  Future<void> _conectarAutomatico() async {
    if (_urlAutoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Escribe la URL de tu tienda'), backgroundColor: AppColors.rojo));
      return;
    }
    setState(() => _conectandoAuto = true);
    final token = await WooCommerceService.iniciarAutorizacion(_urlAutoCtrl.text);
    setState(() {
      _conectandoAuto = false;
      if (token != null) {
        _tokenPendiente = token;
        _esperandoAprobacion = true;
      }
    });
    if (token == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo abrir la página de autorización'),
        backgroundColor: AppColors.rojo));
    }
  }

  Future<void> _verificarAprobacion() async {
    if (_tokenPendiente == null) return;
    setState(() => _conectandoAuto = true);
    final aprobado = await WooCommerceService.verificarAutorizacion(_tokenPendiente!);
    setState(() => _conectandoAuto = false);
    if (aprobado) {
      setState(() => _esperandoAprobacion = false);
      await _cargar();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ ¡Tienda conectada!'), backgroundColor: AppColors.verde));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Todavía no se ha aprobado. Termina el paso en tu navegador primero.'),
        backgroundColor: AppColors.ambar));
    }
  }

  // ── Conexión manual (respaldo, por si la automática no aplica) ──
  Future<void> _guardarYProbar() async {
    if (_urlCtrl.text.trim().isEmpty) return;
    setState(() { _probando = true; _resultadoPrueba = null; });

    final errorGuardar = await WooCommerceService.guardarConfig(
      url: _urlCtrl.text, consumerKey: _keyCtrl.text, consumerSecret: _secretCtrl.text);
    if (errorGuardar != null) {
      setState(() { _resultadoPrueba = errorGuardar; _resultadoOk = false; _probando = false; });
      return;
    }

    final errorConexion = await WooCommerceService.probarConexion(
      url: _urlCtrl.text, consumerKey: _keyCtrl.text, consumerSecret: _secretCtrl.text);
    setState(() {
      _resultadoOk = errorConexion == null;
      _conectado = _resultadoOk;
      _resultadoPrueba = errorConexion ?? '✅ Conexión exitosa';
      _probando = false;
    });
  }

  Future<void> _sincronizarAhora() async {
    setState(() => _sincronizando = true);
    final resultado = await WooCommerceService.sincronizar();
    setState(() => _sincronizando = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(resultado),
      backgroundColor: resultado.startsWith('✅') ? AppColors.verde : AppColors.rojo));
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    // Si ya está conectado (por cualquiera de los 2 métodos), mostrar
    // solo el estado + botón de sincronizar
    if (_conectado) {
      return Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.verde.withOpacity(0.4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.check_circle, color: AppColors.verde, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Conectado a: ${_urlCtrl.text}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            TextButton(
              onPressed: () => setState(() { _conectado = false; _resultadoOk = false; }),
              child: const Text('Cambiar', style: TextStyle(fontSize: 11))),
          ]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _sincronizando ? null : _sincronizarAhora,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul),
            child: _sincronizando
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Sincronizar productos ahora', style: TextStyle(color: Colors.white)))),
        ]));
    }

    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Trae automáticamente tus productos desde tu tienda WooCommerce.',
          style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        const SizedBox(height: 14),

        if (!_esperandoAprobacion) ...[
          const Text('Solo escribe tu dirección — te llevaremos a tu propia tienda',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.azul)),
          const SizedBox(height: 8),
          TextField(controller: _urlAutoCtrl,
            decoration: const InputDecoration(labelText: 'URL de tu tienda',
              hintText: 'https://mitienda.com', isDense: true, border: OutlineInputBorder())),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _conectandoAuto ? null : _conectarAutomatico,
            icon: _conectandoAuto
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.link, color: Colors.white, size: 18),
            label: const Text('Conectar mi tienda', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul,
              padding: const EdgeInsets.symmetric(vertical: 12)))),
        ] else ...[
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('1. Se abrió tu tienda en el navegador',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Text('2. Inicia sesión si te lo pide',
                style: TextStyle(fontSize: 12)),
              const Text('3. Toca "Aprobar" cuando te lo muestre WooCommerce',
                style: TextStyle(fontSize: 12)),
              const Text('4. Regresa aquí y toca el botón de abajo',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ])),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _conectandoAuto ? null : _verificarAprobacion,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde),
            child: _conectandoAuto
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Ya aprobé, verificar conexión', style: TextStyle(color: Colors.white)))),
          TextButton(
            onPressed: () => setState(() => _esperandoAprobacion = false),
            child: const Text('Cancelar', style: TextStyle(fontSize: 11))),
        ],

        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => setState(() => _mostrarManual = !_mostrarManual),
          child: Text(_mostrarManual ? '▲ Ocultar conexión manual' : '▼ ¿Prefieres ingresar las claves tú mismo?',
            style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario,
              decoration: TextDecoration.underline))),

        if (_mostrarManual) ...[
          const SizedBox(height: 10),
          const Text('WordPress → WooCommerce → Ajustes → Avanzado → API REST → Agregar clave',
            style: TextStyle(fontSize: 10, color: AppColors.azul, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          TextField(controller: _urlCtrl,
            decoration: const InputDecoration(labelText: 'URL de tu tienda',
              hintText: 'https://mitienda.com', isDense: true, border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _keyCtrl,
            decoration: const InputDecoration(labelText: 'Consumer Key',
              hintText: 'ck_xxxxxxxxxxxx', isDense: true, border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _secretCtrl, obscureText: true,
            decoration: const InputDecoration(labelText: 'Consumer Secret',
              hintText: 'cs_xxxxxxxxxxxx', isDense: true, border: OutlineInputBorder())),
          const SizedBox(height: 12),

          if (_resultadoPrueba != null) ...[
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _resultadoOk ? AppColors.verdeClaro : AppColors.rojoClaro,
                borderRadius: BorderRadius.circular(8)),
              child: Text(_resultadoPrueba!, style: TextStyle(fontSize: 12,
                color: _resultadoOk ? AppColors.verde : AppColors.rojo))),
            const SizedBox(height: 10),
          ],

          SizedBox(width: double.infinity, child: OutlinedButton(
            onPressed: _probando ? null : _guardarYProbar,
            child: _probando
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar y probar conexión'))),
        ],
      ]));
  }
}
