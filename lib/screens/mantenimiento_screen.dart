// ============================================
// lib/screens/mantenimiento_screen.dart
// Cotizador 2.0 · Fase 4 — Mantenimiento de máquinas
//
// Cada máquina lleva sus horas (las que ya traía + las horas capturadas en
// el costo real de los pedidos). Las tareas se repiten cada N horas o cada
// N días; la app marca ok / pronto / vencido y el servidor manda aviso
// cuando toca. "Hecho" guarda el registro y reinicia el contador.
// ============================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../main.dart';
import '../i18n/tr.dart';
import '../services/costos_service.dart';

class MantenimientoScreen extends StatefulWidget {
  const MantenimientoScreen({super.key});
  @override
  State<MantenimientoScreen> createState() => _MantenimientoScreenState();
}

// Plantillas por tipo de máquina: (nombre, cada horas, cada días)
const _plantillas = <String, List<(String, num?, int?)>>{
  'router': [
    ('Lubricar guías lineales y husillos', 50, null),
    ('Limpiar colector de polvo y mesa', 8, null),
    ('Revisar y limpiar pinzas (collets) y tuerca', 100, null),
    ('Revisar bandas, cremalleras y tensión', 200, null),
    ('Revisar rodamientos del spindle (ruido y juego)', 500, null),
  ],
  'laser': [
    ('Limpiar espejos y lente', 40, null),
    ('Revisar nivel y temperatura del agua del chiller', null, 7),
    ('Cambiar el agua del chiller', null, 30),
    ('Limpiar rejilla / panal y charola', 40, null),
    ('Revisar alineación de espejos', 200, null),
  ],
  'plasma': [
    ('Revisar consumibles (boquilla y electrodo)', 8, null),
    ('Drenar compresor y trampa de agua', null, 1),
    ('Cambiar el agua de la mesa', null, 30),
    ('Lubricar guías y cremalleras', 50, null),
  ],
  'fibra': [
    ('Limpiar lente protectora', 8, null),
    ('Revisar agua del chiller', null, 7),
    ('Lubricar guías y cremalleras', 50, null),
  ],
  'impresora3d': [
    ('Nivelar la cama', 20, null),
    ('Revisar y limpiar la boquilla', 50, null),
    ('Limpiar y lubricar ejes', 100, null),
  ],
  'otra': [
    ('Lubricación general', 50, null),
    ('Limpieza general', null, 7),
  ],
};

const _tipos = {
  'router': 'Router CNC',
  'laser': 'Láser CO2',
  'fibra': 'Láser de fibra',
  'plasma': 'Plasma',
  'impresora3d': 'Impresora 3D',
  'otra': 'Otra',
};

class _MantenimientoScreenState extends State<MantenimientoScreen> {
  bool _cargando = true;
  String? _error;
  List<Map<String, dynamic>> _maquinas = [];
  Map<String, double> _horas = {};
  List<Map<String, dynamic>> _tareas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final r = await Future.wait([CostosService.maquinas(), CostosService.horasMaquinas(), CostosService.tareas()]);
      setState(() {
        _maquinas = r[0] as List<Map<String, dynamic>>;
        _horas = r[1] as Map<String, double>;
        _tareas = r[2] as List<Map<String, dynamic>>;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _cargando = false;
        _error = e.toString().contains('mantenimiento')
          ? tr('Falta correr el SQL de la Fase 4 en Supabase (tablas de mantenimiento).')
          : e.toString();
      });
    }
  }

  double _horasDe(Map<String, dynamic> m) =>
    _horas[m['id'].toString()] ?? ((m['horas_base'] as num?)?.toDouble() ?? 0);

  List<Map<String, dynamic>> _tareasDe(Map<String, dynamic> m) =>
    _tareas.where((t) => t['maquina_id'].toString() == m['id'].toString() && t['activa'] != false).toList();

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: Text(tr('Mantenimiento de máquinas'))),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24),
              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.rojo))))
          : RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(16), children: [
              Text(tr('Las horas suben solas con las horas de máquina que anotas en el costo real de cada pedido. Te avisamos cuando toca cada tarea.'),
                style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
              const SizedBox(height: 12),
              if (_maquinas.isEmpty)
                Padding(padding: const EdgeInsets.all(24), child: Text(
                  tr('Primero da de alta tus máquinas en Configuración → Costos del taller.'),
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textoSecundario)))
              else ..._maquinas.map((m) {
                final horas = _horasDe(m);
                final ts = _tareasDe(m);
                final estados = ts.map((t) => CostosService.revisar(t, horas, hoy).estado).toList();
                final vencidas = estados.where((e) => e == 'vencido').length;
                final pronto = estados.where((e) => e == 'pronto').length;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: vencidas > 0 ? AppColors.rojo : AppColors.grisBorde, width: vencidas > 0 ? 1 : 0.5)),
                  child: ListTile(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => _MaquinaScreen(maquina: m)));
                      _cargar();
                    },
                    leading: Text((m['emoji'] ?? '⚙️').toString(), style: const TextStyle(fontSize: 26)),
                    title: Text((m['nombre'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      trf('{0} h', [horas.toStringAsFixed(0)]),
                      if (m['tipo_maquina'] != null) tr(_tipos[m['tipo_maquina']] ?? ''),
                      ts.isEmpty ? tr('sin tareas') : trf('{0} tareas', [ts.length]),
                    ].join(' · '), style: const TextStyle(fontSize: 12)),
                    trailing: vencidas > 0
                      ? _chip(trf('{0} vencidas', [vencidas]), AppColors.rojo, AppColors.rojoClaro)
                      : pronto > 0
                        ? _chip(trf('{0} pronto', [pronto]), AppColors.naranja, AppColors.ambarClaro)
                        : ts.isEmpty ? const Icon(Icons.chevron_right)
                          : _chip(tr('Al día'), AppColors.verde, AppColors.verdeClaro),
                  ));
              }),
            ])));
  }
}

Widget _chip(String t, Color c, Color fondo) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
  child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)));

// ══════════════════════════════════════════════════════
// Detalle de una máquina
// ══════════════════════════════════════════════════════
class _MaquinaScreen extends StatefulWidget {
  final Map<String, dynamic> maquina;
  const _MaquinaScreen({required this.maquina});
  @override
  State<_MaquinaScreen> createState() => _MaquinaScreenState();
}

class _MaquinaScreenState extends State<_MaquinaScreen> {
  late Map<String, dynamic> _m = Map<String, dynamic>.from(widget.maquina);
  bool _cargando = true;
  double _horas = 0;
  List<Map<String, dynamic>> _tareas = [];
  List<Map<String, dynamic>> _registros = [];
  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 0);

  String get _id => _m['id'].toString();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final r = await Future.wait([CostosService.horasMaquinas(), CostosService.tareas(), CostosService.registros(maquinaId: _id, limite: 30)]);
      setState(() {
        _horas = (r[0] as Map<String, double>)[_id] ?? ((_m['horas_base'] as num?)?.toDouble() ?? 0);
        _tareas = (r[1] as List<Map<String, dynamic>>).where((t) => t['maquina_id'].toString() == _id).toList();
        _registros = r[2] as List<Map<String, dynamic>>;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      _aviso(e.toString(), error: true);
    }
  }

  void _aviso(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: error ? AppColors.rojo : AppColors.verde));
  }

  double _num(String t) => double.tryParse(t.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _editarMaquina() async {
    final base = (_m['horas_base'] as num?)?.toDouble() ?? 0;
    final capturadas = (_horas - base).clamp(0, 999999).toDouble();
    final ctrl = TextEditingController(text: _horas.toStringAsFixed(0));
    String? tipo = _m['tipo_maquina'] as String?;
    final ok = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: Text(tr('Datos de la máquina')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: tipo, isExpanded: true,
          decoration: InputDecoration(labelText: tr('Tipo de máquina')),
          items: _tipos.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(tr(e.value)))).toList(),
          onChanged: (v) => set(() => tipo = v)),
        const SizedBox(height: 10),
        TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tr('Horas que marca hoy la máquina'), suffixText: 'h')),
        const SizedBox(height: 6),
        Text(tr('Si tu control (Mach3, DSP, Ruida…) marca horas, copia ese número.'),
          style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancelar'))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Guardar'))),
      ])));
    if (ok != true) return;
    // horas_base = lo que marca hoy menos lo ya capturado en pedidos
    final nuevaBase = (_num(ctrl.text) - capturadas).clamp(0, 999999).toDouble();
    try {
      await CostosService.actualizarMaquina(_id, {'horas_base': nuevaBase, 'tipo_maquina': tipo});
      _m = {..._m, 'horas_base': nuevaBase, 'tipo_maquina': tipo};
      await _cargar();
    } catch (e) {
      _aviso(e.toString(), error: true);
    }
  }

  Future<void> _recomendadas() async {
    final tipo = (_m['tipo_maquina'] as String?) ?? '';
    if (!_plantillas.containsKey(tipo)) {
      await _editarMaquina();
      if (!_plantillas.containsKey(_m['tipo_maquina'])) return;
    }
    final lista = _plantillas[_m['tipo_maquina']]!;
    final existentes = _tareas.map((t) => (t['nombre'] ?? '').toString().toLowerCase()).toSet();
    final nuevas = lista.where((p) => !existentes.contains(tr(p.$1).toLowerCase())).toList();
    if (nuevas.isEmpty) { _aviso(tr('Ya tienes las tareas recomendadas.')); return; }
    try {
      final hoy = DateTime.now();
      for (final p in nuevas) {
        await CostosService.guardarTarea({
          'maquina_id': _id, 'nombre': tr(p.$1), 'cada_horas': p.$2, 'cada_dias': p.$3,
          'ultima_horas': _horas,
          'ultima_fecha': '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}',
        });
      }
      _aviso(trf('✅ {0} tareas agregadas. Cuentan desde hoy.', [nuevas.length]));
      await _cargar();
    } catch (e) {
      _aviso(e.toString(), error: true);
    }
  }

  Future<void> _editarTarea(Map<String, dynamic>? t) async {
    final nombre = TextEditingController(text: (t?['nombre'] ?? '').toString());
    final horas = TextEditingController(text: t?['cada_horas'] == null ? '' : '${(t!['cada_horas'] as num).toDouble().toStringAsFixed(0)}');
    final dias = TextEditingController(text: t?['cada_dias'] == null ? '' : '${t!['cada_dias']}');
    final accion = await showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: Text(t == null ? tr('Nueva tarea') : tr('Editar tarea')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nombre, decoration: InputDecoration(labelText: tr('¿Qué hay que hacer?'))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: horas, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: tr('Cada'), suffixText: tr('horas')))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: dias, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: tr('o cada'), suffixText: tr('días')))),
        ]),
        const SizedBox(height: 6),
        Text(tr('Llena uno o los dos; avisa con lo que llegue primero.'), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      ]),
      actions: [
        if (t != null) TextButton(onPressed: () => Navigator.pop(context, 'borrar'),
          child: Text(tr('Borrar'), style: const TextStyle(color: AppColors.rojo))),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancelar'))),
        ElevatedButton(onPressed: () => Navigator.pop(context, 'guardar'), child: Text(tr('Guardar'))),
      ]));
    try {
      if (accion == 'borrar' && t != null) {
        await CostosService.borrarTarea(t['id'].toString());
      } else if (accion == 'guardar') {
        final h = _num(horas.text), d = int.tryParse(dias.text.trim()) ?? 0;
        if (nombre.text.trim().isEmpty || (h <= 0 && d <= 0)) {
          _aviso(tr('Escribe la tarea y cada cuántas horas o días.'), error: true);
          return;
        }
        await CostosService.guardarTarea({
          if (t != null) 'id': t['id'],
          if (t == null) 'maquina_id': _id,
          if (t == null) 'ultima_horas': _horas,
          'nombre': nombre.text.trim(),
          'cada_horas': h > 0 ? h : null,
          'cada_dias': d > 0 ? d : null,
        });
      } else {
        return;
      }
      await _cargar();
    } catch (e) {
      _aviso(e.toString(), error: true);
    }
  }

  Future<void> _hecho(Map<String, dynamic> t) async {
    final horasCtrl = TextEditingController(text: _horas.toStringAsFixed(0));
    final costoCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(tr('Marcar como hecho')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((t['nombre'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(controller: horasCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tr('Horas de la máquina'), suffixText: 'h')),
        TextField(controller: costoCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tr('¿Cuánto costó? (opcional)'), prefixText: '\$')),
        TextField(controller: notasCtrl, decoration: InputDecoration(labelText: tr('Notas (opcional)'))),
        const SizedBox(height: 6),
        Text(tr('Si pones un costo, también se anota en Gastos.'), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Cancelar'))),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Hecho'))),
      ]));
    if (ok != true) return;
    try {
      await CostosService.marcarHecha(tarea: t, maquinaNombre: (_m['nombre'] ?? '').toString(),
        horasActuales: _num(horasCtrl.text) > 0 ? _num(horasCtrl.text) : _horas,
        costo: _num(costoCtrl.text), notas: notasCtrl.text);
      _aviso(tr('✅ Listo, el contador vuelve a empezar.'));
      await _cargar();
    } catch (e) {
      _aviso(e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final ordenadas = [..._tareas]..sort((a, b) =>
      CostosService.revisar(b, _horas, hoy).avance.compareTo(CostosService.revisar(a, _horas, hoy).avance));
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: Text((_m['nombre'] ?? '').toString()),
        actions: [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _editarMaquina)]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editarTarea(null), icon: const Icon(Icons.add), label: Text(tr('Tarea'))),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.grisBorde, width: 0.5)),
              child: Row(children: [
                const Icon(Icons.timer_outlined, color: AppColors.azul, size: 28),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(trf('{0} horas', [_horas.toStringAsFixed(0)]), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  Text(_m['tipo_maquina'] == null ? tr('Toca el lápiz para poner el tipo y las horas que marca hoy.')
                      : tr(_tipos[_m['tipo_maquina']] ?? ''),
                    style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                ])),
              ])),
            const SizedBox(height: 12),
            if (_tareas.isEmpty) ...[
              Text(tr('Sin tareas todavía.'), style: const TextStyle(color: AppColors.textoSecundario)),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(onPressed: _recomendadas, icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(tr('Agregar tareas recomendadas para esta máquina'))),
            const SizedBox(height: 12),
            ...ordenadas.map((t) {
              final r = CostosService.revisar(t, _horas, hoy);
              final color = r.estado == 'vencido' ? AppColors.rojo : r.estado == 'pronto' ? AppColors.naranja : AppColors.verde;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: r.estado == 'vencido' ? AppColors.rojo : AppColors.grisBorde, width: 0.5)),
                child: Row(children: [
                  Expanded(child: InkWell(onTap: () => _editarTarea(t), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((t['nombre'] ?? '').toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                      value: r.avance.clamp(0, 1).toDouble(), minHeight: 6, backgroundColor: AppColors.gris, color: color)),
                    const SizedBox(height: 4),
                    Text('${r.detalle}  ·  ${tr(r.estado == 'vencido' ? 'toca ya' : r.estado == 'pronto' ? 'pronto' : 'al día')}',
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                  ]))),
                  const SizedBox(width: 6),
                  TextButton(onPressed: () => _hecho(t), child: Text(tr('Hecho'))),
                ]));
            }),
            if (_registros.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(tr('Historial'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
              const SizedBox(height: 6),
              ..._registros.map((g) {
                final f = DateTime.tryParse('${g['fecha'] ?? ''}');
                final costo = ((g['costo'] ?? 0) as num).toDouble();
                return ListTile(
                  dense: true, contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline, color: AppColors.verde, size: 20),
                  title: Text((g['descripcion'] ?? '').toString(), style: const TextStyle(fontSize: 12)),
                  subtitle: Text([
                    if (f != null) DateFormat('dd/MM/yyyy').format(f),
                    if (g['horas_maquina'] != null) '${((g['horas_maquina'] as num).toDouble()).toStringAsFixed(0)} h',
                    if ((g['notas'] ?? '').toString().isNotEmpty) g['notas'].toString(),
                  ].join(' · '), style: const TextStyle(fontSize: 11)),
                  trailing: costo > 0 ? Text(_fmt.format(costo), style: const TextStyle(fontSize: 12)) : null);
              }),
            ],
          ])));
  }
}
