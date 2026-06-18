// ============================================
// lib/screens/config_screen.dart
// ============================================
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/supabase_service.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _nombre = TextEditingController();
  final _rfc = TextEditingController();
  final _direccion = TextEditingController();
  final _tel1 = TextEditingController();
  final _tel2 = TextEditingController();
  final _correo = TextEditingController();
  final _web = TextEditingController();
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();
  final _tiktok = TextEditingController();
  bool _alerta3 = true, _alerta5 = true, _cupon7 = true, _alertaPostEntrega = true;
  String _ivaPorDefecto = '16% (incluido)';
  String _vigencia = '7 días hábiles';
  String _metodoPago = '50% anticipo / 50% entrega';
  bool _cargando = true, _guardando = false;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    try {
      final cfg = await SupabaseService.getConfiguracion();
      _nombre.text = cfg['nombre_comercial'] ?? 'HETNA CNC';
      _rfc.text = cfg['rfc'] ?? '';
      _direccion.text = cfg['direccion'] ?? '';
      _tel1.text = cfg['telefono1'] ?? '';
      _tel2.text = cfg['telefono2'] ?? '';
      _correo.text = cfg['correo'] ?? '';
      _web.text = cfg['sitio_web'] ?? '';
      _instagram.text = cfg['instagram'] ?? '';
      _facebook.text = cfg['facebook'] ?? '';
      _tiktok.text = cfg['tiktok'] ?? '';
      _alerta3 = cfg['alerta_dia3'] ?? true;
      _alerta5 = cfg['alerta_dia5'] ?? true;
      _cupon7 = cfg['cupon_dia7'] ?? true;
      _alertaPostEntrega = cfg['alerta_post_entrega'] ?? true;
      if (mounted) setState(() => _cargando = false);
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: const Text('Configuración'), actions: [
        TextButton(onPressed: _guardar, child: _guardando
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w600))),
      ]),
      body: _cargando ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(14), children: [
          _seccion('Datos de la empresa (autollenado)', Icons.business_outlined),
          _campo('Nombre comercial', _nombre),
          _campo('RFC', _rfc),
          _campo('Dirección fiscal', _direccion),
          Row(children: [Expanded(child: _campo('Teléfono 1', _tel1)), const SizedBox(width: 8), Expanded(child: _campo('Teléfono 2', _tel2))]),
          _campo('Correo comercial', _correo, tipo: TextInputType.emailAddress),
          _campo('Sitio web', _web),

          _seccion('Redes sociales (mensaje post-entrega)', Icons.share_outlined),
          Row(children: [Expanded(child: _campo('Instagram', _instagram)), const SizedBox(width: 8), Expanded(child: _campo('Facebook', _facebook))]),
          _campo('TikTok', _tiktok),

          _seccion('Valores por defecto en cotizaciones', Icons.description_outlined),
          _dropdownCampo('IVA', _ivaPorDefecto, ['16% (incluido)', 'No aplica IVA', 'Preguntar cada vez'],
            (v) => setState(() => _ivaPorDefecto = v!)),
          _dropdownCampo('Vigencia de cotización', _vigencia, ['7 días hábiles', '15 días hábiles', '30 días naturales'],
            (v) => setState(() => _vigencia = v!)),
          _dropdownCampo('Método de pago por defecto', _metodoPago,
            ['50% anticipo / 50% entrega', 'Pago total anticipado', 'Crédito 30 días', 'Transferencia bancaria'],
            (v) => setState(() => _metodoPago = v!)),

          _seccion('Alertas automáticas de seguimiento', Icons.notifications_outlined),
          _switchRow('Alerta día 3 sin respuesta', _alerta3, (v) => setState(() => _alerta3 = v)),
          _switchRow('Alerta día 5 — mensaje urgente', _alerta5, (v) => setState(() => _alerta5 = v)),
          _switchRow('Cupón día 7 — descuento de cierre', _cupon7, (v) => setState(() => _cupon7 = v)),
          _switchRow('Alerta post-entrega — enviar redes', _alertaPostEntrega, (v) => setState(() => _alertaPostEntrega = v)),

          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: _guardar, icon: const Icon(Icons.save_outlined), label: const Text('Guardar configuración')),
          const SizedBox(height: 20),
        ]),
    );
  }

  Widget _seccion(String titulo, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.azul),
      const SizedBox(width: 6),
      Text(titulo.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.azul, letterSpacing: 1, fontWeight: FontWeight.w600)),
    ]));

  Widget _campo(String label, TextEditingController ctrl, {TextInputType tipo = TextInputType.text}) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      const SizedBox(height: 4),
      TextField(controller: ctrl, keyboardType: tipo, style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
    ]));

  Widget _dropdownCampo(String label, String value, List<String> items, ValueChanged<String?> onChanged) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      const SizedBox(height: 4),
      DropdownButtonFormField<String>(value: value, decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 12)))).toList(), onChanged: onChanged),
    ]));

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) =>
    Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Switch(value: value, onChanged: onChanged, activeColor: AppColors.verde),
      ]));

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await SupabaseService.guardarConfiguracion({
        'nombre_comercial': _nombre.text,
        'rfc': _rfc.text,
        'direccion': _direccion.text,
        'telefono1': _tel1.text,
        'telefono2': _tel2.text,
        'correo': _correo.text,
        'sitio_web': _web.text,
        'instagram': _instagram.text,
        'facebook': _facebook.text,
        'tiktok': _tiktok.text,
        'alerta_dia3': _alerta3,
        'alerta_dia5': _alerta5,
        'cupon_dia7': _cupon7,
        'alerta_post_entrega': _alertaPostEntrega,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Configuración guardada'), backgroundColor: AppColors.verde));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}
