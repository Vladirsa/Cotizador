// ============================================
// lib/screens/costo_real_screen.dart
// Cotizador 2.0 · Fase 4 — Costo real y utilidad de un pedido
//
// Al terminar (o mientras se hace) el taller anota lo que de verdad gastó:
// horas de cada máquina, material del inventario (le da salida), horas del
// operador y otros gastos. La app calcula utilidad y margen reales; las horas
// de máquina también alimentan el contador de mantenimiento.
// ============================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../main.dart';
import '../models/models.dart';
import '../i18n/tr.dart';
import '../services/costos_service.dart';
import '../services/supabase_service.dart';

class CostoRealScreen extends StatefulWidget {
  final Pedido pedido;
  const CostoRealScreen({super.key, required this.pedido});

  @override
  State<CostoRealScreen> createState() => _CostoRealScreenState();
}

class _CostoRealScreenState extends State<CostoRealScreen> {
  bool _cargando = true;
  String? _error;
  List<Map<String, dynamic>> _costos = [];
  List<Map<String, dynamic>> _maquinas = [];
  List<Map<String, dynamic>> _operadores = [];
  List<Map<String, dynamic>> _materiales = [];
  double _costoHoraTaller = 0;
  double? _ivaPct;

  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);

  static const _iconos = {
    'maquina': Icons.precision_manufacturing_outlined,
    'material': Icons.inventory_2_outlined,
    'operador': Icons.engineering_outlined,
    'otro': Icons.receipt_outlined,
  };

  String get _pid => widget.pedido.id ?? '';

  double get _ingreso => CostosService.sinIva(widget.pedido.total ?? 0, _ivaPct);
  double get _costo => _costos.fold(0.0, (s, c) => s + ((c['costo_total'] ?? 0) as num).toDouble());
  double get _utilidad => _ingreso - _costo;
  double get _margen => _ingreso > 0 ? _utilidad / _ingreso * 100 : 0;
  double get _horasMaquina => _costos.where((c) => c['tipo'] == 'maquina')
    .fold(0.0, (s, c) => s + ((c['cantidad'] ?? 0) as num).toDouble());

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final cot = widget.pedido.cotizacionId;
      final r = await Future.wait([
        CostosService.costosPedido(_pid),
        CostosService.maquinas(),
        CostosService.operadores(),
        SupabaseService.getMateriales(),
        CostosService.empresaConfig(),
        CostosService.ivaDeCotizaciones(cot == null ? [] : [cot]),
      ]);
      final iva = r[5] as Map<String, double>;
      setState(() {
        _costos = r[0] as List<Map<String, dynamic>>;
        _maquinas = r[1] as List<Map<String, dynamic>>;
        _operadores = r[2] as List<Map<String, dynamic>>;
        _materiales = r[3] as List<Map<String, dynamic>>;
        final cfg = r[4] as Map<String, dynamic>?;
        _costoHoraTaller = CostosService.costoHoraTaller(cfg);
        _ivaPct = cot != null && iva.containsKey(cot) ? iva[cot] : ((cfg?['iva_pct'] as num?)?.toDouble() ?? 16);
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _cargando = false;
        _error = e.toString().contains('pedido_costos')
          ? tr('Falta correr el SQL de la Fase 4 en Supabase (tabla pedido_costos).')
          : e.toString();
      });
    }
  }

  void _aviso(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: error ? AppColors.rojo : AppColors.verde));
  }

  double _num(String t) => double.tryParse(t.trim().replaceAll(',', '.')) ?? 0;

  // ── Agregar ─────────────────────────────────────────────────────────
  Future<void> _agregar(String tipo) async {
    List<Map<String, dynamic>> opciones = [];
    String titulo = tr('Otro gasto');
    String etiquetaCant = tr('Cantidad');
    if (tipo == 'maquina') { opciones = _maquinas; titulo = tr('Horas de máquina'); etiquetaCant = tr('Horas'); }
    if (tipo == 'operador') { opciones = _operadores; titulo = tr('Horas de operador'); etiquetaCant = tr('Horas'); }
    if (tipo == 'material') { opciones = _materiales; titulo = tr('Material del inventario'); }
    if (tipo != 'otro' && opciones.isEmpty) {
      _aviso(tipo == 'material'
        ? tr('No tienes materiales en Inventario todavía.')
        : tr('Primero da de alta tus máquinas y operadores en Configuración → Costos del taller.'), error: true);
      return;
    }

    Map<String, dynamic>? sel = opciones.isNotEmpty ? opciones.first : null;
    final conceptoCtrl = TextEditingController();
    final cantCtrl = TextEditingController(text: tipo == 'otro' ? '1' : '');
    final unitCtrl = TextEditingController();

    double unitDe(Map<String, dynamic>? o) {
      if (o == null) return 0;
      if (tipo == 'maquina') return CostosService.costoHoraMaquina(o);
      if (tipo == 'operador') return CostosService.costoHoraOperador(o);
      return ((o['costo_unitario'] ?? 0) as num).toDouble();
    }
    if (tipo != 'otro') unitCtrl.text = unitDe(sel).toStringAsFixed(2);

    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final total = _num(cantCtrl.text) * _num(unitCtrl.text);
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (tipo != 'otro') DropdownButtonFormField<Map<String, dynamic>>(
              value: sel, isExpanded: true,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              items: opciones.map((o) => DropdownMenuItem(value: o, child: Text(
                tipo == 'material'
                  ? '${o['nombre']} · ${trf('hay {0} {1}', [o['stock_actual'] ?? 0, o['unidad'] ?? ''])}'
                  : (o['nombre'] ?? '').toString(),
                overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => set(() { sel = v; unitCtrl.text = unitDe(v).toStringAsFixed(2); }))
            else TextField(controller: conceptoCtrl, decoration: InputDecoration(
              labelText: tr('Concepto'), hintText: tr('Flete, maquila externa, pintura…'), isDense: true,
              border: const OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: cantCtrl, autofocus: tipo != 'otro',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => set(() {}),
                decoration: InputDecoration(labelText: tipo == 'material' ? trf('Cantidad ({0})', [sel?['unidad'] ?? '']) : etiquetaCant,
                  isDense: true, border: const OutlineInputBorder()))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: unitCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => set(() {}),
                decoration: InputDecoration(
                  labelText: tipo == 'otro' ? tr('Monto') : (tipo == 'material' ? tr('Costo unitario') : tr('Costo por hora')),
                  prefixText: '\$', isDense: true, border: const OutlineInputBorder()))),
            ]),
            if (tipo == 'material') Padding(padding: const EdgeInsets.only(top: 6),
              child: Text(tr('Se descuenta del inventario.'), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
            if (tipo == 'maquina') Padding(padding: const EdgeInsets.only(top: 6),
              child: Text(tr('Estas horas también cuentan para el mantenimiento de la máquina.'),
                style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
            const SizedBox(height: 12),
            Row(children: [
              Text(trf('Total: {0}', [_fmt.format(total)]), style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancelar'))),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Agregar'))),
            ]),
          ]));
      }));
    if (ok != true) return;

    final cantidad = _num(cantCtrl.text);
    final unit = _num(unitCtrl.text);
    if (cantidad <= 0 || (tipo != 'otro' && sel == null) || (tipo == 'otro' && conceptoCtrl.text.trim().isEmpty)) {
      _aviso(tr('Revisa la cantidad y el concepto.'), error: true);
      return;
    }
    if (tipo == 'material' && cantidad != cantidad.roundToDouble()) {
      _aviso(tr('El inventario cuenta en unidades enteras: usa un número sin decimales.'), error: true);
      return;
    }
    try {
      await CostosService.agregarCosto(
        pedidoId: _pid, folio: widget.pedido.folio, tipo: tipo,
        concepto: tipo == 'otro' ? conceptoCtrl.text.trim() : (sel!['nombre'] ?? '').toString(),
        cantidad: cantidad, costoUnitario: unit,
        maquinaId: tipo == 'maquina' ? sel!['id']?.toString() : null,
        materialId: tipo == 'material' ? sel!['id']?.toString() : null);
      await _cargar();
    } catch (e) {
      _aviso(e.toString(), error: true);
    }
  }

  Future<void> _agregarFijos() async {
    final horas = _horasMaquina;
    if (_costoHoraTaller <= 0 || horas <= 0) {
      _aviso(horas <= 0
        ? tr('Primero anota las horas de máquina del pedido.')
        : tr('Captura tus gastos fijos en Configuración → Costos del taller.'), error: true);
      return;
    }
    try {
      await CostosService.agregarCosto(pedidoId: _pid, folio: widget.pedido.folio, tipo: 'otro',
        concepto: trf('Gastos fijos del taller ({0} h)', [horas.toStringAsFixed(1)]),
        cantidad: horas, costoUnitario: _costoHoraTaller);
      await _cargar();
    } catch (e) {
      _aviso(e.toString(), error: true);
    }
  }

  Future<void> _borrar(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(tr('¿Quitar este costo?')),
      content: Text(c['tipo'] == 'material' ? tr('El material regresa al inventario.') : '${c['concepto'] ?? ''}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('No'))),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Quitar'), style: const TextStyle(color: AppColors.rojo))),
      ]));
    if (ok != true) return;
    try {
      await CostosService.borrarCosto(c, widget.pedido.folio);
      await _cargar();
    } catch (e) {
      _aviso(e.toString(), error: true);
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: Text(trf('Costo real · {0}', [widget.pedido.folio]))),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24),
              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.rojo))))
          : ListView(padding: const EdgeInsets.all(16), children: [
              _resumen(),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _boton('maquina', tr('Máquina')),
                _boton('material', tr('Material')),
                _boton('operador', tr('Operador')),
                _boton('otro', tr('Otro gasto')),
                if (_costoHoraTaller > 0) ActionChip(
                  avatar: const Icon(Icons.home_work_outlined, size: 16, color: AppColors.azul),
                  label: Text(tr('Gastos fijos'), style: const TextStyle(fontSize: 12)),
                  onPressed: _agregarFijos),
              ]),
              const SizedBox(height: 14),
              if (_costos.isEmpty)
                Padding(padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(tr('Todavía no anotas costos. Empieza por las horas de máquina y el material.'),
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textoSecundario)))
              else ..._costos.map(_fila),
              const SizedBox(height: 30),
            ]));
  }

  Widget _boton(String tipo, String texto) => ActionChip(
    avatar: Icon(_iconos[tipo], size: 16, color: AppColors.azul),
    label: Text('+ $texto', style: const TextStyle(fontSize: 12)),
    onPressed: () => _agregar(tipo));

  Widget _resumen() {
    final color = _margen >= 30 ? AppColors.verde : _margen >= 15 ? AppColors.naranja : AppColors.rojo;
    Widget kpi(String t, String v, {Color? c}) => Expanded(child: Column(children: [
      Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c ?? AppColors.textoPrincipal)),
      Text(t, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
    ]));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(children: [
        Row(children: [
          kpi(tr('Venta sin IVA'), _fmt.format(_ingreso)),
          kpi(tr('Costo real'), _fmt.format(_costo)),
          kpi(tr('Utilidad'), _fmt.format(_utilidad), c: color),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
          value: (_margen / 100).clamp(0, 1).toDouble(), minHeight: 8,
          backgroundColor: AppColors.gris, color: color)),
        const SizedBox(height: 6),
        Text(trf('Margen real: {0}%', [_margen.toStringAsFixed(1)]),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]));
  }

  Widget _fila(Map<String, dynamic> c) {
    final tipo = (c['tipo'] ?? 'otro').toString();
    final cant = ((c['cantidad'] ?? 0) as num).toDouble();
    final unit = ((c['costo_unitario'] ?? 0) as num).toDouble();
    final unidad = tipo == 'maquina' || tipo == 'operador' ? 'h' : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: ListTile(
        dense: true,
        leading: Icon(_iconos[tipo] ?? Icons.receipt_outlined, color: AppColors.azul),
        title: Text((c['concepto'] ?? '').toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text('${cant % 1 == 0 ? cant.toStringAsFixed(0) : cant.toStringAsFixed(2)}$unidad × ${_fmt.format(unit)}',
          style: const TextStyle(fontSize: 11)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_fmt.format(((c['costo_total'] ?? 0) as num).toDouble()), style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.textoSecundario), onPressed: () => _borrar(c)),
        ])));
  }
}
