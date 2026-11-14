// lib/widgets/calculo_material.dart
// HETNA CNC — "Material y aprovechamiento" de un diseño: medida del tablón u
// hoja, separación entre piezas, cuántas piezas se piden y precio del
// material → piezas por tablón/hoja, cuántos se compran (completos) y el costo
// de material por pieza. Ver services/aprovechamiento.dart.
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
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
  /// Para el precio sugerido: largo de corte de la pieza (mm) y perforaciones (contornos)
  final double corteMm;
  final int perforaciones;
  /// Pone el precio sugerido por pieza en el producto de la cotización
  final ValueChanged<double>? onPrecio;
  /// Costo por hora de máquina y margen del taller (para llenar el precio sugerido)
  final Future<({double costoHora, double margen})> Function()? cargarCostos;
  const CalculoMaterial({super.key, required this.pzLargo, required this.pzAncho, required this.datos, required this.onCambio, this.onAplicar,
    this.cargarInventario, this.corteMm = 0, this.perforaciones = 0, this.onPrecio, this.cargarCostos});
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
      // Especificación técnica de la pieza (sale en el PDF y en su plano del anexo)
      'nombre': TextEditingController(text: v('nombre', '')),
      'parte_cliente': TextEditingController(text: v('parte_cliente', '')),
      'proceso': TextEditingController(text: v('proceso', '')),
      'grado': TextEditingController(text: v('grado', '')),
      'tolerancia': TextEditingController(text: v('tolerancia', '')),
      'rev_cad': TextEditingController(text: v('rev_cad', 'A')),
      'criticas': TextEditingController(text: v('criticas', '')),
      // Precio sugerido por pieza
      'vel': TextEditingController(text: v('vel', '')),
      'costo_hora': TextEditingController(text: v('costo_hora', '')),
      'acabado_pz': TextEditingController(text: v('acabado_pz', '')),
      'margen': TextEditingController(text: v('margen', '35')),
    };
    _materialId = widget.datos['material_id'] as String?;
    _stock = double.tryParse('${widget.datos['stock'] ?? ''}');
    // Si ya se eligió de la bodega, se refrescan precio y existencias
    if (_materialId != null) _refrescarDeBodega();
  }

  String? _materialId; // fila de inventario_bodega elegida
  double? _stock;      // existencias en bodega (en hojas o tablones)
  bool _cargando = false;

  bool _verPrecio = false, _costosCargados = false;

  static Future<({double costoHora, double margen})> _costosDelTaller() async {
    try {
      final t = await Simulador2Data.taller();
      final maqs = await Simulador2Data.maquinas();
      final conCosto = maqs.where((m) => m.costoHora > 0).toList();
      return (costoHora: conCosto.isNotEmpty ? conCosto.first.costoHora : 0.0, margen: t.margenPct);
    } catch (_) {
      return (costoHora: 0.0, margen: 35.0);
    }
  }

  // La primera vez que se abre el precio sugerido se llenan costo por hora y margen del taller
  Future<void> _abrirPrecio() async {
    setState(() => _verPrecio = !_verPrecio);
    if (!_verPrecio || _costosCargados) return;
    _costosCargados = true;
    final c = await (widget.cargarCostos ?? _costosDelTaller)();
    if (!mounted) return;
    if (_n('costo_hora') <= 0 && c.costoHora > 0) _c['costo_hora']!.text = c.costoHora.toStringAsFixed(0);
    if (_c['margen']!.text.trim().isEmpty || (widget.datos['margen'] == null && c.margen > 0)) _c['margen']!.text = c.margen.toStringAsFixed(0);
    _guardar();
  }

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
    Widget texto(String k, String etiqueta, {String? ayuda}) => TextField(controller: _c[k], onChanged: (_) => _guardar(),
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: etiqueta, helperText: ayuda, isDense: true, border: const OutlineInputBorder()));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Especificación técnica de la pieza ──
      Text(tr('Especificación técnica'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.azul)),
      const SizedBox(height: 6),
      texto('nombre', tr('Nombre y descripción de la pieza')),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: texto('parte_cliente', tr('N.º de parte del cliente'))),
        const SizedBox(width: 8),
        SizedBox(width: 110, child: texto('rev_cad', tr('Revisión CAD'))),
      ]),
      const SizedBox(height: 8),
      texto('proceso', tr('Proceso (Router CNC 2D, plasma, láser, torno…)')),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: texto('tolerancia', tr('Tolerancia'), ayuda: tr('Ej: ±0.2 mm o "según plano aprobado"'))),
        const SizedBox(width: 8),
        Expanded(child: texto('criticas', tr('Cotas críticas (números)'), ayuda: tr('Ej: 3, 5, 9 (de la lista de cotas)'))),
      ]),
      const Divider(height: 22),
      Text(tr('Material y aprovechamiento'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.azul)),
      const SizedBox(height: 4),
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
      texto('grado', tr('Grado comercial del material (ej. MDF E1, acero A36, aluminio 6061-T6)')),
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
      const SizedBox(height: 8),
      InkWell(onTap: _abrirPrecio, child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
        const Icon(Icons.price_change_outlined, size: 18, color: AppColors.verde),
        const SizedBox(width: 6),
        Expanded(child: Text(tr('Precio sugerido por pieza (material + máquina + acabado)'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
        Icon(_verPrecio ? Icons.expand_less : Icons.expand_more, size: 20, color: AppColors.textoSecundario),
      ]))),
      if (_verPrecio) _precioSugerido(r),
    ]);
  }

  // material por pieza + tiempo de corte × $/hora + acabado, ÷ (1 − margen)
  Widget _precioSugerido(ResultadoMaterial r) {
    Widget campo(String k, String etiqueta, {String? sufijo, String? prefijo}) => SizedBox(width: 128, child: TextField(
      controller: _c[k], keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _guardar(),
      decoration: InputDecoration(labelText: etiqueta, suffixText: sufijo, prefixText: prefijo, isDense: true, border: const OutlineInputBorder())));
    final fmt2 = Pais.fmt();
    final vel = _n('vel'), costoHora = _n('costo_hora'), acabado = _n('acabado_pz'), margen = _n('margen').clamp(0, 90).toDouble();
    final metros = widget.corteMm / 1000;
    const segPerf = 2.0;
    final tiempo = vel > 0 ? metros / vel + widget.perforaciones * segPerf / 60 : 0.0;
    final maquina = tiempo / 60 * costoHora;
    final material = _n('precio') > 0 ? r.costoPorPieza : 0.0;
    final costo = material + maquina + acabado;
    final precio = margen >= 90 ? costo : costo / (1 - margen / 100);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        campo('vel', tr('Velocidad de corte'), sufijo: 'm/min'),
        campo('costo_hora', tr('Costo por hora de máquina'), prefijo: '\$'),
        campo('acabado_pz', tr('Acabado por pieza'), prefijo: '\$'),
        campo('margen', tr('Margen'), sufijo: '%'),
      ]),
      const SizedBox(height: 8),
      Container(
        width: double.infinity, padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.grisBorde)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (vel <= 0) Text(tr('Pon la velocidad de corte de tu máquina con este material para calcular el tiempo.'), style: const TextStyle(fontSize: 11.5, color: AppColors.naranja))
          else Text(trf('Tiempo por pieza: {0} m ÷ {1} m/min + {2} perforaciones × 2 s = {3} min', [metros.toStringAsFixed(2), vel.toStringAsFixed(1), widget.perforaciones, tiempo.toStringAsFixed(2)]),
            style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          Text(trf('Material {0} + máquina {1} + acabado {2} = costo {3}', [fmt2.format(material), fmt2.format(maquina), fmt2.format(acabado), fmt2.format(costo)]),
            style: const TextStyle(fontSize: 11.5)),
          if (_n('precio') <= 0) Text(tr('Sin precio del material: el costo de material queda en \$0.'), style: const TextStyle(fontSize: 10.5, color: AppColors.naranja)),
          const SizedBox(height: 4),
          Text(trf('Precio sugerido: {0} por pieza (margen {1} %)', [fmt2.format(precio), margen.toStringAsFixed(0)]),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.verde)),
          if (widget.onPrecio != null && precio > 0) Align(alignment: Alignment.centerRight, child: TextButton.icon(
            onPressed: () => widget.onPrecio!(double.parse(precio.toStringAsFixed(2))),
            icon: const Icon(Icons.check, size: 16),
            label: Text(tr('Usar este precio en el producto'), style: const TextStyle(fontSize: 12)))),
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
        if (!alcanza) Align(alignment: Alignment.centerRight, child: TextButton.icon(
          onPressed: () => Share.share(_textoPedido(faltan, unidades)),
          icon: const Icon(Icons.shopping_cart_outlined, size: 16),
          label: Text(tr('Pedir al proveedor'), style: const TextStyle(fontSize: 12)))),
      ]));
  }

  // Mensaje listo para mandar por WhatsApp o correo al proveedor
  String _textoPedido(int faltan, String unidades) {
    final mat = _c['material']!.text.trim(), esp = _c['espesor']!.text.trim();
    final med = '${_n('mat_l').toStringAsFixed(0)} × ${_n('mat_a').toStringAsFixed(0)} mm';
    return trf('Hola, quiero pedir {0} {1} de {2}{3}, medida {4}. ¿Me confirmas precio y tiempo de entrega? Gracias.',
      [faltan, unidades, mat.isEmpty ? tr('material') : mat, esp.isEmpty ? '' : ' $esp mm', med]);
  }

  String _descripcion(ResultadoMaterial r, String unidades) {
    final med = '${_n('mat_l').toStringAsFixed(0)} × ${_n('mat_a').toStringAsFixed(0)} mm';
    final base = trf('{0} {1} de {2} ({3} pz por {4})', [r.unidades, unidades, med, r.porUnidad, _esHoja ? tr('hoja') : tr('tablón')]);
    return _n('precio') > 0 ? '$base · ${trf('material {0} por pieza', [Pais.fmt().format(r.costoPorPieza)])}' : base;
  }
}
