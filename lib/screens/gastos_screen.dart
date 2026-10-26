// lib/screens/gastos_screen.dart
// HETNA CNC — Gastos y Compras con campos fiscales SAT
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../i18n/tr.dart';

class GastosScreen extends StatefulWidget {
  const GastosScreen({super.key});
  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Gasto> _gastos = [];
  bool _cargando = true;

  final _fmt = NumberFormat(r'$#,##0.00', 'es_MX');
  final _fmtFecha = DateFormat(enIngles ? 'MM/dd/yyyy' : 'dd/MM/yyyy', localeFormato);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _cargar();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await SupabaseService.getGastos(periodo: tr('Todo'));
      if (mounted) setState(() {
        _gastos = (data as List)
          .map((j) => Gasto.fromJson(j as Map<String, dynamic>))
          .toList();
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // Resumen del mes
  Map<String, double> get _resumenMes {
    final hoy = DateTime.now();
    final del = _gastos.where((g) =>
      g.fecha != null &&
      g.fecha!.year == hoy.year &&
      g.fecha!.month == hoy.month).toList();
    return {
      'total': del.fold(0, (s, g) => s + g.monto),
      'directos': del.where((g) => g.tipo == 'directo')
        .fold(0, (s, g) => s + g.monto),
      'indirectos': del.where((g) => g.tipo == 'indirecto')
        .fold(0, (s, g) => s + g.monto),
      'iva_acreditable': del.fold(0, (s, g) => s + g.ivaAcreditable),
      'con_factura': del.where((g) => g.tieneFactura).length.toDouble(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(tr('Gastos y Compras'),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
            color: AppColors.azul)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.azul),
            onPressed: _cargar),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          tabs: [
            Tab(text: tr('Gastos')),
            Tab(text: tr('Nuevo gasto')),
            Tab(text: tr('Resumen')),
          ])),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            _tabGastos(),
            _TabNuevoGasto(onGuardado: () { _cargar(); _tabs.animateTo(0); }),
            _tabResumen(),
          ]));
  }

  // ── TAB GASTOS ──────────────────────────────
  Widget _tabGastos() {
    if (_gastos.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.grisBorde),
        const SizedBox(height: 12),
        Text(tr('Sin gastos registrados'),
          style: TextStyle(color: AppColors.textoSecundario)),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _tabs.animateTo(1),
          icon: const Icon(Icons.add, color: Colors.white, size: 16),
          label: Text(tr('Registrar gasto'),
            style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _gastos.length,
        itemBuilder: (_, i) => _TarjetaGasto(
          gasto: _gastos[i], fmt: _fmt, fmtFecha: _fmtFecha,
          onEditar: () => _editarGasto(_gastos[i]))));
  }

  // ── TAB RESUMEN ─────────────────────────────
  Widget _tabResumen() {
    final res = _resumenMes;
    final hoy = DateTime.now();
    final mesNombre = DateFormat('MMMM yyyy', localeFormato).format(hoy);

    // Agrupar por categoría
    final porCat = <String, double>{};
    for (final g in _gastos) {
      porCat[g.categoria] = (porCat[g.categoria] ?? 0) + g.monto;
    }
    final sortedCat = porCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(padding: const EdgeInsets.all(14), children: [
      // Header mes
      Text(mesNombre.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textoSecundario, letterSpacing: 1.5)),
      const SizedBox(height: 10),

      // KPIs
      Row(children: [
        _kpi(tr('Total mes'), res['total']!, AppColors.rojo),
        const SizedBox(width: 8),
        _kpi(tr('Con factura'), res['con_factura']!,
          AppColors.azul, esCantidad: true),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _kpi(tr('Directos'), res['directos']!, AppColors.naranja),
        const SizedBox(width: 8),
        _kpi(tr('IVA acreditable'), res['iva_acreditable']!, AppColors.verde),
      ]),

      const SizedBox(height: 16),

      // Nota fiscal
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.azulClaro,
          borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('💡 IVA acreditable este mes'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.azul)),
          const SizedBox(height: 4),
          Text(_fmt.format(res['iva_acreditable']!),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
              color: AppColors.azul)),
          const SizedBox(height: 4),
          Text(
            tr('Solo se acredita el IVA de gastos con factura válida y deducibles.'),
            style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ])),

      const SizedBox(height: 16),

      // Por categoría
      Text(tr('POR CATEGORÍA'),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
          color: AppColors.textoSecundario, letterSpacing: 1.5)),
      const SizedBox(height: 8),
      ...sortedCat.map((e) {
        final pct = res['total']! > 0 ? e.value / res['total']! : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(tr(Gasto.etiquetasTipoSat[e.key] ?? e.key),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text(_fmt.format(e.value),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppColors.rojo)),
            ]),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: pct.toDouble(),
              backgroundColor: AppColors.grisBorde,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.rojo),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2)),
            const SizedBox(height: 2),
            Text(trf('{0}% del total', [((pct * 100).toStringAsFixed(1))]),
              style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          ]));
      }),
    ]);
  }

  Widget _kpi(String label, double val, Color color,
    {bool esCantidad = false}) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr(label), style: const TextStyle(
        fontSize: 10, color: AppColors.textoSecundario)),
      const SizedBox(height: 4),
      Text(tr(esCantidad ? '${val.toInt()}' : _fmt.format(val)),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
    ])));

  void _editarGasto(Gasto g) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TabNuevoGasto(
        gastoEditar: g,
        onGuardado: () { Navigator.pop(context); _cargar(); }));
  }
}

// ══════════════════════════════════════════════════════
// FORMULARIO NUEVO/EDITAR GASTO
// ══════════════════════════════════════════════════════
class _TabNuevoGasto extends StatefulWidget {
  final Gasto? gastoEditar;
  final VoidCallback onGuardado;
  const _TabNuevoGasto({this.gastoEditar, required this.onGuardado});
  @override
  State<_TabNuevoGasto> createState() => _TabNuevoGastoState();
}

class _TabNuevoGastoState extends State<_TabNuevoGasto> {
  // Campos básicos
  final _conceptoCtrl = TextEditingController();
  final _montoCtrl    = TextEditingController();
  final _provCtrl     = TextEditingController();
  String _tipo = 'directo';
  String _categoria = 'materiales';
  DateTime _fecha = DateTime.now();

  // Campos fiscales
  bool _tieneFactura = false;
  final _rfcCtrl     = TextEditingController();
  final _folioCtrl   = TextEditingController();
  final _ivaCtrl     = TextEditingController();
  bool _esDeducible  = true;
  String _tipoSat    = 'materiales';

  bool _guardando = false;
  final _fmt = DateFormat(enIngles ? 'MM/dd/yyyy' : 'dd/MM/yyyy', localeFormato);

  @override
  void initState() {
    super.initState();
    final g = widget.gastoEditar;
    if (g != null) {
      _conceptoCtrl.text = g.concepto;
      _montoCtrl.text = g.monto.toStringAsFixed(2);
      _provCtrl.text = g.proveedor ?? '';
      _tipo = g.tipo;
      _categoria = g.categoria;
      _fecha = g.fecha ?? DateTime.now();
      _tieneFactura = g.tieneFactura;
      _rfcCtrl.text = g.rfcProveedor ?? '';
      _folioCtrl.text = g.folioFactura ?? '';
      _ivaCtrl.text = g.ivaFactura > 0 ? g.ivaFactura.toStringAsFixed(2) : '';
      _esDeducible = g.esDeducible;
      _tipoSat = g.tipoGastoSat;
    }
  }

  @override
  void dispose() {
    _conceptoCtrl.dispose(); _montoCtrl.dispose();
    _provCtrl.dispose(); _rfcCtrl.dispose();
    _folioCtrl.dispose(); _ivaCtrl.dispose();
    super.dispose();
  }

  // Calcular IVA sugerido (16% del monto sin IVA)
  void _calcularIvaSugerido() {
    final monto = double.tryParse(_montoCtrl.text) ?? 0;
    if (monto > 0 && _ivaCtrl.text.isEmpty) {
      // El monto ya incluye IVA: IVA = monto * 16/116
      final iva = monto * 16 / 116;
      _ivaCtrl.text = iva.toStringAsFixed(2);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.gastoEditar != null;
    final isBottomSheet = esEdicion;

    Widget form = SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Tipo de gasto
        Text(tr('TIPO DE GASTO'), style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: AppColors.textoSecundario, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Row(children: [
          _chipTipo('directo', tr('🔧 Directo'), tr('Materiales, consumibles')),
          const SizedBox(width: 8),
          _chipTipo('indirecto', tr('📋 Indirecto'), tr('Luz, internet, renta')),
        ]),

        const SizedBox(height: 16),

        // Concepto y monto
        _campo(_conceptoCtrl, tr('Concepto / Descripción *'),
          icon: Icons.receipt_long_outlined),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _campo(_montoCtrl, tr('Monto total \$'),
            tipo: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _campo(_provCtrl, tr('Proveedor'))),
        ]),

        const SizedBox(height: 10),

        // Fecha
        GestureDetector(
          onTap: () async {
            final sel = await showDatePicker(
              context: context, initialDate: _fecha,
              firstDate: DateTime(2020), lastDate: DateTime(2030));
            if (sel != null) setState(() => _fecha = sel);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.grisBorde),
              borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.azul),
              const SizedBox(width: 8),
              Text('Fecha: ${_fmt.format(_fecha)}',
                style: const TextStyle(fontSize: 13)),
            ]))),

        const SizedBox(height: 10),

        // Categoría SAT
        DropdownButtonFormField<String>(
          value: _tipoSat,
          decoration: InputDecoration(
            labelText: tr('Tipo de gasto (SAT)'),
            border: OutlineInputBorder(), isDense: true,
            prefixIcon: Icon(Icons.category_outlined, size: 18)),
          items: Gasto.tiposGastoSat.map((t) => DropdownMenuItem(
            value: t,
            child: Text(tr(Gasto.etiquetasTipoSat[t] ?? t),
              style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() {
            _tipoSat = v ?? _tipoSat;
            _categoria = v ?? _categoria;
          })),

        const SizedBox(height: 16),
        const Divider(),

        // ── SECCIÓN FISCAL ──────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('¿Te facturaron?'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(tr(_tieneFactura
              ? tr('IVA acreditable para el SAT')
              : tr('Sin comprobante fiscal')),
              style: TextStyle(fontSize: 11,
                color: _tieneFactura ? AppColors.verde : AppColors.textoSecundario)),
          ]),
          Switch(
            value: _tieneFactura,
            onChanged: (v) {
              setState(() => _tieneFactura = v);
              if (v) _calcularIvaSugerido();
            },
            activeColor: AppColors.verde),
        ]),

        if (_tieneFactura) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.verde.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.verde.withOpacity(0.3))),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.check_circle_outline,
                  color: AppColors.verde, size: 14),
                const SizedBox(width: 6),
                Text(tr('Datos de la factura'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.verde)),
              ]),
              const SizedBox(height: 10),

              // RFC y folio
              Row(children: [
                Expanded(child: _campo(_rfcCtrl, tr('RFC del proveedor'),
                  icon: Icons.badge_outlined)),
                const SizedBox(width: 8),
                Expanded(child: _campo(_folioCtrl, tr('Folio factura'))),
              ]),
              const SizedBox(height: 8),

              // IVA
              Row(children: [
                Expanded(child: _campo(_ivaCtrl, tr('IVA de la factura \$'),
                  tipo: TextInputType.number,
                  icon: Icons.percent_outlined)),
                const SizedBox(width: 8),
                Expanded(child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.azulClaro,
                    borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(tr('Base (sin IVA)'),
                      style: TextStyle(fontSize: 10,
                        color: AppColors.textoSecundario)),
                    const SizedBox(height: 2),
                    Text(tr(_ivaCtrl.text.isNotEmpty
                      ? '\$${((double.tryParse(_montoCtrl.text) ?? 0) - (double.tryParse(_ivaCtrl.text) ?? 0)).toStringAsFixed(2)}'
                      : '—'),
                      style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w700, color: AppColors.azul)),
                  ]))),
              ]),
              const SizedBox(height: 8),

              // Deducible
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('¿Es deducible de ISR?'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(tr('El gasto reduce tu base de ISR'),
                    style: TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
                ]),
                Switch(
                  value: _esDeducible,
                  onChanged: (v) => setState(() => _esDeducible = v),
                  activeColor: AppColors.azul),
              ]),

              // Nota IVA
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.azulClaro,
                  borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.azul),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    trf('IVA acreditable: {0} — se resta del IVA a pagar al SAT.', [(_ivaCtrl.text.isNotEmpty && _esDeducible ? '\$${_ivaCtrl.text}' : '\$0.00')]),
                    style: const TextStyle(fontSize: 10, color: AppColors.azul))),
                ])),
            ])),
        ],

        const SizedBox(height: 16),

        // Botón guardar
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined, color: Colors.white, size: 18),
            label: Text(tr(esEdicion ? tr('Actualizar gasto') : tr('Registrar gasto')),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.azul,
              padding: const EdgeInsets.symmetric(vertical: 13)))),

        const SizedBox(height: 8),
      ]));

    if (isBottomSheet) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              Text(tr('Editar gasto'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              GestureDetector(onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close)),
            ])),
          const Divider(height: 1),
          Expanded(child: form),
        ]));
    }

    return form;
  }

  Future<void> _guardar() async {
    if (_conceptoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('El concepto es obligatorio')),
        backgroundColor: AppColors.rojo));
      return;
    }
    final monto = double.tryParse(_montoCtrl.text);
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('El monto debe ser mayor a 0')),
        backgroundColor: AppColors.rojo));
      return;
    }

    setState(() => _guardando = true);
    try {
      final datos = {
        'concepto': _conceptoCtrl.text.trim(),
        'monto': monto,
        'tipo': _tipo,
        'categoria': _tipoSat,
        'tipo_gasto_sat': _tipoSat,
        'proveedor': _provCtrl.text.trim().isEmpty ? null : _provCtrl.text.trim(),
        'fecha': _fecha.toIso8601String().substring(0, 10),
        'tiene_factura': _tieneFactura,
        'rfc_proveedor': _tieneFactura && _rfcCtrl.text.isNotEmpty
          ? _rfcCtrl.text.trim().toUpperCase() : null,
        'folio_factura': _tieneFactura && _folioCtrl.text.isNotEmpty
          ? _folioCtrl.text.trim() : null,
        'iva_factura': _tieneFactura
          ? (double.tryParse(_ivaCtrl.text) ?? 0) : 0,
        'es_deducible': _tieneFactura ? _esDeducible : false,
      };

      if (widget.gastoEditar?.id != null) {
        await SupabaseService.actualizarGasto(widget.gastoEditar!.id!, datos);
      } else {
        await SupabaseService.registrarGasto(datos);
      }

      if (mounted) widget.onGuardado();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _chipTipo(String val, String titulo, String sub) {
    final sel = _tipo == val;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _tipo = val),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: sel ? AppColors.rojo : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? AppColors.rojo : AppColors.grisBorde)),
        child: Column(children: [
          Text(tr(titulo), style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: sel ? Colors.white : AppColors.textoPrincipal)),
          Text(tr(sub), style: TextStyle(
            fontSize: 10,
            color: sel ? Colors.white70 : AppColors.textoSecundario)),
        ]))));
  }

  Widget _campo(TextEditingController ctrl, String label, {
    TextInputType tipo = TextInputType.text,
    IconData? icon, int maxLines = 1,
  }) => TextFormField(
    controller: ctrl,
    keyboardType: tipo,
    maxLines: maxLines,
    inputFormatters: tipo == TextInputType.number
      ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 18) : null,
      border: const OutlineInputBorder(),
      isDense: true),
    style: const TextStyle(fontSize: 13));
}

// ── TARJETA DE GASTO ──────────────────────────
class _TarjetaGasto extends StatelessWidget {
  final Gasto gasto;
  final NumberFormat fmt;
  final DateFormat fmtFecha;
  final VoidCallback onEditar;

  const _TarjetaGasto({
    required this.gasto,
    required this.fmt,
    required this.fmtFecha,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: gasto.tipo == 'directo'
              ? AppColors.rojo.withOpacity(0.05)
              : AppColors.ambar.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: gasto.tipo == 'directo' ? AppColors.rojo : AppColors.ambar,
                borderRadius: BorderRadius.circular(10)),
              child: Text(tr(gasto.tipo == 'directo' ? tr('Directo') : tr('Indirecto')),
                style: const TextStyle(fontSize: 10, color: Colors.white,
                  fontWeight: FontWeight.w600))),
            const SizedBox(width: 6),
            if (gasto.tieneFactura)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.verde,
                  borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_outlined, size: 10, color: Colors.white),
                  SizedBox(width: 3),
                  Text(tr('Facturado'), style: TextStyle(
                    fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                ])),
            const Spacer(),
            Text(tr(gasto.fecha != null ? fmtFecha.format(gasto.fecha!) : ''),
              style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onEditar,
              child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.azul)),
          ])),

        // Cuerpo
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(gasto.concepto),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              if (gasto.proveedor != null) ...[
                const SizedBox(height: 2),
                Text(tr(gasto.proveedor!),
                  style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
              ],
              const SizedBox(height: 4),
              Text(tr(Gasto.etiquetasTipoSat[gasto.tipoGastoSat] ?? gasto.categoria),
                style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt.format(gasto.monto),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: AppColors.rojo)),
              if (gasto.tieneFactura && gasto.ivaFactura > 0) ...[
                Text('IVA: ${fmt.format(gasto.ivaFactura)}',
                  style: const TextStyle(fontSize: 10, color: AppColors.verde)),
                Text('Base: ${fmt.format(gasto.montoBase)}',
                  style: const TextStyle(fontSize: 10,
                    color: AppColors.textoSecundario)),
              ],
            ]),
          ])),
      ]));
  }
}
