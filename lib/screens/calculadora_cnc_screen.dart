// lib/screens/calculadora_cnc_screen.dart
// HETNA CNC — Calculadora CNC (router, láser CO₂, plasma, fibra, 3D y costo)
//
// Los formularios NO están escritos aquí: vienen de hetnacnc.com
// (/api/app/calculadora), igual que en el Copiloto IA de la web. Si se agrega o
// corrige una calculadora en la web, la app la muestra sin publicar versión nueva.
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/hetna_api.dart';

class CalculadoraCncScreen extends StatefulWidget {
  const CalculadoraCncScreen({super.key});
  @override
  State<CalculadoraCncScreen> createState() => _CalculadoraCncScreenState();
}

class _CalculadoraCncScreenState extends State<CalculadoraCncScreen> {
  List<CalcDef> _lista = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final l = await HetnaApi.calculadoras();
      if (mounted) setState(() => _lista = l);
    } catch (e) {
      if (mounted) setState(() => _error = 'Sin conexión con hetnacnc.com. $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  static const _iconos = {
    'router': Icons.precision_manufacturing_outlined,
    'laser_co2': Icons.flash_on_outlined,
    'plasma': Icons.local_fire_department_outlined,
    'fibra': Icons.highlight_outlined,
    'impresora_3d': Icons.view_in_ar_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: const Text('Calculadora CNC'),
        backgroundColor: Colors.white, foregroundColor: AppColors.azul, elevation: 0.5),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
              mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textoSecundario)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
              ])))
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Valores de partida. Confírmalos siempre con un corte de prueba.',
                style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
              const SizedBox(height: 12),
              ..._lista.map((c) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.grisBorde, width: 0.5)),
                child: ListTile(
                  leading: Icon(_iconos[c.maquina] ?? Icons.calculate_outlined, color: AppColors.naranja),
                  title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text(c.resumen, style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _FormularioCalc(def: c)))))),
            ]));
  }
}

class _FormularioCalc extends StatefulWidget {
  final CalcDef def;
  const _FormularioCalc({required this.def});
  @override
  State<_FormularioCalc> createState() => _FormularioCalcState();
}

class _FormularioCalcState extends State<_FormularioCalc> {
  final Map<String, TextEditingController> _num = {};
  final Map<String, String?> _opc = {};
  CalcResultado? _res;
  bool _calculando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in widget.def.campos) {
      if (c.tipo == 'opcion') { _opc[c.k] = null; } else { _num[c.k] = TextEditingController(); }
    }
  }

  @override
  void dispose() { for (final c in _num.values) { c.dispose(); } super.dispose(); }

  Future<void> _calcular() async {
    FocusScope.of(context).unfocus();
    final entrada = <String, dynamic>{};
    for (final c in widget.def.campos) {
      if (c.tipo == 'opcion') {
        if (_opc[c.k] != null) entrada[c.k] = _opc[c.k];
      } else {
        final v = double.tryParse(_num[c.k]!.text.replaceAll(',', '.'));
        if (v != null) entrada[c.k] = v;
      }
      if (c.req && !entrada.containsKey(c.k)) {
        setState(() => _error = 'Falta: ${c.etiqueta}');
        return;
      }
    }
    setState(() { _calculando = true; _error = null; });
    try {
      final r = await HetnaApi.calcular(widget.def.id, entrada);
      if (mounted) setState(() => _res = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _calculando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.def;
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: Text(d.nombre, style: const TextStyle(fontSize: 15)),
        backgroundColor: Colors.white, foregroundColor: AppColors.azul, elevation: 0.5),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ...d.campos.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c.tipo == 'opcion'
          ? DropdownButtonFormField<String>(
              value: _opc[c.k], isExpanded: true,
              decoration: InputDecoration(labelText: '${c.etiqueta}${c.req ? ' *' : ''}',
                isDense: true, border: const OutlineInputBorder(), filled: true, fillColor: Colors.white),
              items: c.opciones.map((o) => DropdownMenuItem(value: o.v, child: Text(o.t, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _opc[c.k] = v))
          : TextField(
              controller: _num[c.k],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '${c.etiqueta}${c.req ? ' *' : ''}',
                suffixText: c.unidad, helperText: c.ayuda, isDense: true,
                border: const OutlineInputBorder(), filled: true, fillColor: Colors.white)))),
        SizedBox(height: 48, child: ElevatedButton(
          onPressed: _calculando ? null : _calcular,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: _calculando
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Calcular', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 10),
          child: Text(_error!, style: const TextStyle(color: AppColors.rojo))),
        if (_res != null) _resultado(_res!),
      ]));
  }

  Widget _resultado(CalcResultado r) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (r.titulo.isNotEmpty) Text(r.titulo, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.azul)),
      const SizedBox(height: 8),
      ...r.filas.map((f) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.etiqueta, style: const TextStyle(fontSize: 13)),
            if (f.nota != null) Text(f.nota!, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          ])),
          Text(f.valor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ]))),
      ..._lista('Atención', r.avisos, AppColors.ambar),
      ..._lista('Faltan datos', r.faltan, AppColors.rojo),
      ..._lista('Supuestos', r.supuestos, AppColors.textoSecundario),
    ]));

  List<Widget> _lista(String t, List<String> l, Color color) => l.isEmpty ? [] : [
    const SizedBox(height: 10),
    Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ...l.map((x) => Text('• $x', style: const TextStyle(fontSize: 12))),
  ];
}
