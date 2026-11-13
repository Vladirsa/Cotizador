// lib/widgets/calculo_material.dart
// HETNA CNC — "Material y aprovechamiento" de un diseño: medida del tablón u
// hoja, separación entre piezas, cuántas piezas se piden y precio del
// material → piezas por tablón/hoja, cuántos se compran (completos) y el costo
// de material por pieza. Ver services/aprovechamiento.dart.
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/aprovechamiento.dart';
import '../services/pais.dart';

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
  const CalculoMaterial({super.key, required this.pzLargo, required this.pzAncho, required this.datos, required this.onCambio, this.onAplicar});
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
    };
  }

  @override
  void dispose() { for (final c in _c.values) { c.dispose(); } super.dispose(); }

  double _n(String k) => double.tryParse(_c[k]!.text.replaceAll(',', '.').trim()) ?? 0;

  void _guardar() {
    widget.onCambio({for (final e in _c.entries) e.key: e.value.text.trim()});
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
      Row(children: [
        Expanded(flex: 3, child: TextField(controller: _c['material'], onChanged: (_) => _guardar(), textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: tr('Material (ej. MDF, pino, acrílico)'), isDense: true, border: const OutlineInputBorder()))),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: TextField(controller: _c['espesor'], onChanged: (_) => _guardar(), keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tr('Espesor'), suffixText: 'mm', isDense: true, border: const OutlineInputBorder()))),
      ]),
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

  String _descripcion(ResultadoMaterial r, String unidades) {
    final med = '${_n('mat_l').toStringAsFixed(0)} × ${_n('mat_a').toStringAsFixed(0)} mm';
    final mat = _c['material']!.text.trim(), esp = _c['espesor']!.text.trim();
    final que = [if (mat.isNotEmpty) mat, if (esp.isNotEmpty) '$esp mm'].join(' ');
    final base = trf('Material: {0} {1} de {2} ({3} pz por {4})', [r.unidades, unidades, med, r.porUnidad, _esHoja ? tr('hoja') : tr('tablón')])
      + (que.isNotEmpty ? ' · $que' : '');
    return _n('precio') > 0 ? '$base · ${trf('material {0} por pieza', [Pais.fmt().format(r.costoPorPieza)])}' : base;
  }
}
