// lib/widgets/calculo_material.dart
// HETNA CNC — "Material y aprovechamiento" de un diseño: medida del tablón u
// hoja, separación entre piezas, cuántas piezas se piden y precio del
// material → piezas por tablón/hoja, cuántos se compran (completos) y el costo
// de material por pieza. Ver services/aprovechamiento.dart.
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/aprovechamiento.dart';
import '../services/pais.dart';
import '../simulador2/motor.dart' show Material2;
import '../simulador2/simulador2_data.dart';

/// Medidas comunes de material (largo × ancho en mm)
const presetsMaterial = <(String, double, double)>[
  ('Hoja 1.22 × 2.44 m', 2440, 1220),
  ('Hoja 1.83 × 2.44 m', 2440, 1830),
  ('Tablón 2.44 m × 30 cm', 2440, 300),
  ('Tablón 2.40 m × 10 cm', 2400, 100),
];

class CalculoMaterial extends StatefulWidget {
  final double pzLargo, pzAncho; // medidas de la pieza en mm
  final Map<String, dynamic> datos; // lo guardado: mat_l, mat_a, sep, orilla, piezas, precio
  final ValueChanged<Map<String, dynamic>> onCambio;
  /// Aplica el resultado al producto de la cotización (cantidad y descripción)
  final void Function(ResultadoMaterial r, String descripcion)? onAplicar;
  /// Materiales de la bodega (inventario). Por omisión, los del taller en Supabase.
  final Future<List<Material2>> Function()? cargarInventario;
  const CalculoMaterial({super.key, required this.pzLargo, required this.pzAncho, required this.datos, required this.onCambio, this.onAplicar, this.cargarInventario});
  @override
  State<CalculoMaterial> createState() => _CalculoMaterialState();
}

class _CalculoMaterialState extends State<CalculoMaterial> {
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    String v(String k, String def) { final x = widget.datos[k]; return x == null ? def : '$x'; }
    _c = {
      'mat_l': TextEditingController(text: v('mat_l', '2440')),
      'mat_a': TextEditingController(text: v('mat_a', '1220')),
      'sep': TextEditingController(text: v('sep', '10')),
      'orilla': TextEditingController(text: v('orilla', '0')),
      'piezas': TextEditingController(text: v('piezas', '1')),
      'precio': TextEditingController(text: v('precio', '')),
      // Material y espesor de ESTA pieza: salen en su croquis del PDF
      'material': TextEditingController(text: v('material', '')),
      'espesor': TextEditingController(text: v('espesor', '')),
      'acabado': TextEditingController(text: v('acabado', '')),
    };
    _materialId = widget.datos['material_id'] as String?;
    _stock = double.tryParse('${widget.datos['stock'] ?? ''}');
    // Si ya se eligió de la bodega, se refrescan precio y existencias
    if (_materialId != null) _refrescarDeBodega();
  }

  String? _materialId; // fila de inventario_bodega elegida
  double? _stock;      // existencias en bodega (en hojas o tablones)
  bool _cargando = false;

  Future<List<Material2>> _inventario() => (widget.cargarInventario ?? Simulador2Data.materiales)();

  Future<void> _refrescarDeBodega() async {
    final l = await _inventario();
    if (!mounted) return;
    for (final m in l) {
      if (m.id == _materialId) { _usarMaterial(m, avisar: false); return; }
    }
  }

  void _usarMaterial(Material2 m, {bool avisar = true}) {
    _materialId = m.id;
    _stock = m.stock;
    _c['material']!.text = m.nombre;
    if (m.espesorMm > 0) _c['espesor']!.text = m.espesorMm % 1 == 0 ? m.espesorMm.toStringAsFixed(0) : m.espesorMm.toString();
    if (m.esHoja) { _c['mat_l']!.text = m.hojaLargo.toStringAsFixed(0); _c['mat_a']!.text = m.hojaAncho.toStringAsFixed(0); }
    if (m.precio > 0) _c['precio']!.text = m.precio % 1 == 0 ? m.precio.toStringAsFixed(0) : m.precio.toStringAsFixed(2);
    _guardar();
  }

  // Lista de la bodega para elegir el material de esta pieza
  Future<void> _elegirDeBodega() async {
    setState(() => _cargando = true);
    final l = (await _inventario()).where((m) => !m.porPeso).toList();
    if (!mounted) return;
    setState(() => _cargando = false);
    if (l.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Tu bodega no tiene materiales en hoja o tablón. Agrégalos en Inventario con su medida, precio y existencias.')), backgroundColor: AppColors.naranja));
      return;
    }
    final fmt = Pais.fmt(centavos: false);
    final m = await showModalBottomSheet<Material2>(context: context, isScrollControlled: true, builder: (ctx) => SafeArea(child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(12), child: Text(tr('Elige el material de tu bodega'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
        Flexible(child: ListView(shrinkWrap: true, children: [
          for (final x in l) ListTile(
            dense: true,
            leading: Icon(x.esRetazo ? Icons.content_cut : Icons.inventory_2_outlined, color: x.stock > 0 ? AppColors.verde : AppColors.textoSecundario),
            title: Text(x.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text([
              if (x.espesorMm > 0) '${x.espesorMm % 1 == 0 ? x.espesorMm.toInt() : x.espesorMm} mm',
              if (x.esHoja) '${x.hojaLargo.round()} × ${x.hojaAncho.round()} mm',
              '${fmt.format(x.precio)}/${x.unidad}',
              x.stock > 0 ? trf('{0} en bodega', [x.stock % 1 == 0 ? x.stock.toInt() : x.stock]) : tr('sin existencias'),
            ].join(' · '), style: const TextStyle(fontSize: 11)),
            onTap: () => Navigator.pop(ctx, x)),
        ])),
      ]))));
    if (m != null) _usarMaterial(m);
  }

  @override
  void dispose() { for (final c in _c.values) { c.dispose(); } super.dispose(); }

  double _n(String k) => double.tryParse(_c[k]!.text.replaceAll(',', '.').trim()) ?? 0;

  void _guardar() {
    widget.onCambio({
      for (final e in _c.entries) e.key: e.value.text.trim(),
      if (_materialId != null) 'material_id': _materialId,
      if (_stock != null) 'stock': _stock,
    });
    setState(() {});
  }

  void _preset(double l, double a) { _c['mat_l']!.text = l.toStringAsFixed(0); _c['mat_a']!.text = a.toStringAsFixed(0); _guardar(); }

  bool get _esHoja => _n('mat_a') >= 600; // hojas: 1220 o más de ancho; tablones: angostos

  @override
  Widget build(BuildContext context) {
    final r = calcularMaterial(pzL: widget.pzLargo, pzA: widget.pzAncho, matL: _n('mat_l'), matA: _n('mat_a'),
      sep: _n('sep'), orilla: _n('orilla'), piezas: _n('piezas').round(), precio: _n('precio'));
    final unidad = _esHoja ? tr('hoja') : tr('tablón');
    final unidades = _esHoja ? tr('hojas') : tr('tablones');
    final fmt = Pais.fmt(centavos: false), fmt2 = Pais.fmt();
    Widget campo(String k, String etiqueta, {String? sufijo, String? prefijo}) => SizedBox(width: 128, child: TextField(
      controller: _c[k], keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => _guardar(),
      decoration: InputDecoration(labelText: etiqueta, suffixText: sufijo, prefixText: prefijo, isDense: true, border: const OutlineInputBorder())));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(trf('Pieza: {0} × {1} mm', [widget.pzLargo.toStringAsFixed(0), widget.pzAncho.toStringAsFixed(0)]), style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario)),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: _cargando ? null : _elegirDeBodega,
        icon: _cargando ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.warehouse_outlined, size: 16),
        label: Text(_materialId != null ? tr('Cambiar material de la bodega') : tr('Elegir material de mi bodega'), style: const TextStyle(fontSize: 12.5)))),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(flex: 3, child: TextField(controller: _c['material'], onChanged: (_) => _guardar(), textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: tr('Material (ej. MDF, pino, acrílico)'), isDense: true, border: const OutlineInputBorder()))),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: TextField(controller: _c['espesor'], onChanged: (_) => _guardar(), keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tr('Espesor'), suffixText: 'mm', isDense: true, border: const OutlineInputBorder()))),
      ]),
      const SizedBox(height: 8),
      TextField(controller: _c['acabado'], onChanged: (_) => _guardar(), textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: tr('Acabado (ej. barniz, pintura, pulido, sin acabado)'), isDense: true, border: const OutlineInputBorder())),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 4, children: [
        for (final p in presetsMaterial) ActionChip(label: Text(tr(p.$1), style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact,
          onPressed: () => _preset(p.$2, p.$3)),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        campo('mat_l', tr('Largo del material'), sufijo: 'mm'),
        campo('mat_a', tr('Ancho del material'), sufijo: 'mm'),
        campo('sep', tr('Separación entre piezas'), sufijo: 'mm'),
        campo('orilla', tr('Orilla'), sufijo: 'mm'),
        campo('piezas', tr('Piezas a fabricar')),
        campo('precio', trf('Precio por {0}', [unidad]), prefijo: '\$'),
      ]),
      const SizedBox(height: 8),
      if (!r.cabe) Text(tr('La pieza no cabe en ese material, ni derecha ni girada.'), style: const TextStyle(fontSize: 12, color: AppColors.rojo, fontWeight: FontWeight.w600))
      else Container(
        width: double.infinity, padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.grisBorde)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(trf('{0} piezas por {1}', [r.porUnidad, unidad]), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.azul)),
          Text(trf('Acomodo: {0} a lo largo × {1} a lo ancho{2}{3}', [r.columnas, r.filas, r.girada ? ' · ${tr('pieza girada 90°')}' : '',
            r.extraFranja > 0 ? ' · ${trf('+{0} en la franja que sobra', [r.extraFranja])}' : '']), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          const SizedBox(height: 6),
          Text(trf('Para {0} piezas: {1} {2} completos', [r.piezas, r.unidades, unidades]), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          if (r.sobranEnUltima > 0) Text(trf('En el último {0} sobra lugar para {1} piezas más.', [unidad, r.sobranEnUltima]), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          Text(trf('Aprovechamiento del material: {0} %', [r.aprovechamientoPct.toStringAsFixed(0)]), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          if (_materialId != null && _stock != null) _existencias(r, unidades),
          if (_n('precio') > 0) ...[
            const SizedBox(height: 6),
            Text(trf('Material: {0} {1} × {2} = {3}', [r.unidades, unidades, fmt.format(_n('precio')), fmt.format(r.costoTotal)]), style: const TextStyle(fontSize: 12.5)),
            Text(trf('Costo de material por pieza: {0}', [fmt2.format(r.costoPorPieza)]), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.verde)),
            if (_esHoja) Text(tr('Se cobra la hoja completa: la parte que sobra queda como retazo del taller.'), style: const TextStyle(fontSize: 10.5, color: AppColors.textoSecundario)),
          ],
          if (widget.onAplicar != null) Align(alignment: Alignment.centerRight, child: TextButton.icon(
            onPressed: () => widget.onAplicar!(r, _descripcion(r, unidades)),
            icon: const Icon(Icons.check, size: 16),
            label: Text(tr('Usar en el producto'), style: const TextStyle(fontSize: 12)))),
        ])),
    ]);
  }

  // Lo que hay en bodega contra lo que pide este trabajo
  Widget _existencias(ResultadoMaterial r, String unidades) {
    final hay = (_stock ?? 0).floor();
    final faltan = r.unidades - hay;
    final alcanza = faltan <= 0;
    final costoFalta = faltan > 0 ? faltan * _n('precio') : 0.0;
    return Container(
      margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(8), width: double.infinity,
      decoration: BoxDecoration(color: alcanza ? AppColors.verdeClaro : AppColors.ambarClaro, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trf('En bodega: {0} {1}', [hay, unidades]), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        Text(alcanza
            ? trf('Alcanza con lo de bodega; te quedan {0}.', [hay - r.unidades])
            : trf('Faltan {0} {1} por comprar{2}.', [faltan, unidades, costoFalta > 0 ? ' (${Pais.fmt(centavos: false).format(costoFalta)})' : '']),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: alcanza ? AppColors.verde : AppColors.naranja)),
      ]));
  }

  String _descripcion(ResultadoMaterial r, String unidades) {
    final med = '${_n('mat_l').toStringAsFixed(0)} × ${_n('mat_a').toStringAsFixed(0)} mm';
    final base = trf('{0} {1} de {2} ({3} pz por {4})', [r.unidades, unidades, med, r.porUnidad, _esHoja ? tr('hoja') : tr('tablón')]);
    return _n('precio') > 0 ? '$base · ${trf('material {0} por pieza', [Pais.fmt().format(r.costoPorPieza)])}' : base;
  }
}
