// lib/screens/envios_screen.dart
// HETNA CNC — Envíos HETNA dentro de la app
//
// Cotiza con todas las paqueterías (precio HETNA, margen incluido). Si se abre
// desde una cotización, al elegir una opción el precio regresa al campo
// "Envío" de esa cotización (Navigator.pop con EnvioElegido).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/hetna_api.dart';
import '../i18n/tr.dart';

class EnvioElegido {
  final String? cotizacionId;
  final OpcionEnvio opcion;
  EnvioElegido(this.cotizacionId, this.opcion);
  String get descripcion => '${opcion.paqueteria} ${opcion.servicio}'
    '${opcion.dias != null ? trf(' ({0} días)', [(opcion.dias)]) : ''}';
}

class EnviosScreen extends StatefulWidget {
  final String? cpDestino;
  final bool paraCotizacion; // true = al elegir, regresa el precio
  const EnviosScreen({super.key, this.cpDestino, this.paraCotizacion = false});
  @override
  State<EnviosScreen> createState() => _EnviosScreenState();
}

class _EnviosScreenState extends State<EnviosScreen> {
  static const _empaques = ['Caja de cartón', 'Sobre', 'Tubo', 'Bolsa o paquete blando', 'Tarima o bulto'];
  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 0);

  final _cpO = TextEditingController(), _cpD = TextEditingController();
  final _peso = TextEditingController(text: '2'), _largo = TextEditingController(text: '30'),
        _ancho = TextEditingController(text: '30'), _alto = TextEditingController(text: '20');
  InfoCP? _infoO, _infoD;
  String? _colO, _colD;
  String _tipo = _empaques.first;
  bool _cargando = false;
  String? _error;
  CotizacionEnvio? _res;

  @override
  void initState() {
    super.initState();
    _cpD.text = widget.cpDestino ?? '';
    _cargarOrigen();
    if (_cpD.text.length == 5) _buscarCP(false);
  }

  Future<void> _cargarOrigen() async {
    try {
      final p = await SharedPreferences.getInstance();
      final cp = p.getString('envio_cp_origen');
      if (cp != null && cp.length == 5) {
        _cpO.text = cp;
        _colO = p.getString('envio_colonia_origen');
        await _buscarCP(true, coloniaGuardada: _colO);
      }
    } catch (_) {}
  }

  Future<void> _buscarCP(bool origen, {String? coloniaGuardada}) async {
    final cp = (origen ? _cpO : _cpD).text.trim();
    if (cp.length != 5) return;
    try {
      final info = await HetnaApi.codigoPostal(cp);
      if (!mounted) return;
      setState(() {
        final col = coloniaGuardada != null && info.colonias.contains(coloniaGuardada)
          ? coloniaGuardada
          : (info.colonias.length == 1 ? info.colonias.first : null);
        if (origen) { _infoO = info; _colO = col; } else { _infoD = info; _colD = col; }
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  double? _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));

  Future<void> _cotizar() async {
    FocusScope.of(context).unfocus();
    final peso = _n(_peso), l = _n(_largo), a = _n(_ancho), h = _n(_alto);
    if (_cpO.text.length != 5 || _cpD.text.length != 5) {
      setState(() => _error = tr('Escribe los dos códigos postales (5 dígitos).'));
      return;
    }
    if (peso == null || l == null || a == null || h == null) {
      setState(() => _error = tr('Revisa el peso y las medidas.'));
      return;
    }
    setState(() { _cargando = true; _error = null; _res = null; });
    try {
      final r = await HetnaApi.cotizarEnvio(
        cpOrigen: _cpO.text, coloniaOrigen: _colO ?? '',
        cpDestino: _cpD.text, coloniaDestino: _colD ?? '',
        tipo: _tipo, peso: peso, largo: l, ancho: a, alto: h);
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString('envio_cp_origen', _cpO.text);
        if (_colO != null) await p.setString('envio_colonia_origen', _colO!);
      } catch (_) {}
      if (mounted) setState(() { _res = r; if (r.opciones.isEmpty) _error = r.aviso ?? tr('No hay paqueterías para esa ruta.'); });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: Text(tr('Envíos HETNA')),
        backgroundColor: Colors.white, foregroundColor: AppColors.azul, elevation: 0.5),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _caja(tr('Origen'), _cpO, _infoO, _colO, (v) => setState(() => _colO = v), true),
        _caja(tr('Destino'), _cpD, _infoD, _colD, (v) => setState(() => _colD = v), false),
        _bloque(tr('Paquete'), Column(children: [
          DropdownButtonFormField<String>(
            value: _tipo, isExpanded: true,
            decoration: InputDecoration(labelText: tr('Tipo de empaque'), isDense: true, border: OutlineInputBorder()),
            items: _empaques.map((e) => DropdownMenuItem(value: e, child: Text(tr(e)))).toList(),
            onChanged: (v) => setState(() => _tipo = v ?? _tipo)),
          const SizedBox(height: 10),
          Row(children: [
            _num(_peso, tr('Peso'), 'kg'), const SizedBox(width: 6),
            _num(_largo, tr('Largo'), 'cm'), const SizedBox(width: 6),
            _num(_ancho, tr('Ancho'), 'cm'), const SizedBox(width: 6),
            _num(_alto, tr('Alto'), 'cm'),
          ]),
        ])),
        const SizedBox(height: 4),
        SizedBox(height: 48, child: ElevatedButton.icon(
          onPressed: _cargando ? null : _cotizar,
          icon: _cargando
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.local_shipping_outlined, color: Colors.white),
          label: Text(tr('Cotizar envío'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.naranja,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 13))),
        if (_res != null && _res!.opciones.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('${_res!.opciones.length} opciones'
            '${_res!.pesoCobrado != null ? trf(' · peso cobrado {0} kg', [(_res!.pesoCobrado)]) : ''}',
            style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const SizedBox(height: 8),
          ..._res!.opciones.map(_opcion),
        ],
      ]));
  }

  Widget _opcion(OpcionEnvio o) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(o.paqueteria, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        Text('${o.servicio}${o.dias != null ? trf(' · {0} días', [(o.dias)]) : ''}'
          '${o.recoleccion ? tr(' · recolección') : ''}',
          style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(_fmt.format(o.precio), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.azul)),
        if (widget.paraCotizacion)
          TextButton(onPressed: () => Navigator.pop(context, EnvioElegido(_res?.id, o)),
            child: Text(tr('Usar en cotización')))
        else if (_res?.id != null)
          TextButton(
            onPressed: () => launchUrl(Uri.parse(HetnaApi.urlSolicitarEnvio(_res!.id!, o.tarifaId)),
              mode: LaunchMode.externalApplication),
            child: Text(tr('Comprar guía'))),
      ]),
    ]));

  Widget _caja(String titulo, TextEditingController cp, InfoCP? info, String? col,
      ValueChanged<String?> onCol, bool origen) =>
    _bloque(titulo, Column(children: [
      TextField(controller: cp, keyboardType: TextInputType.number, maxLength: 5,
        decoration: InputDecoration(labelText: tr('Código postal'), isDense: true, counterText: '',
          border: const OutlineInputBorder(),
          helperText: info != null ? '${info.municipio}, ${info.estado}' : null),
        onChanged: (v) { if (v.length == 5) _buscarCP(origen); }),
      if (info != null && info.colonias.length > 1) ...[
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: col, isExpanded: true,
          decoration: InputDecoration(labelText: tr('Colonia'), isDense: true, border: OutlineInputBorder()),
          items: info.colonias.map((c) => DropdownMenuItem(value: c, child: Text(tr(c), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onCol),
      ],
    ]));

  Widget _num(TextEditingController c, String l, String u) => Expanded(child: TextField(
    controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: l, suffixText: u, isDense: true, border: const OutlineInputBorder())));

  Widget _bloque(String t, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr(t), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.azul)),
      const SizedBox(height: 10),
      child,
    ]));
}
