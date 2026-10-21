// lib/screens/config_costos_screen.dart
// HETNA CNC — Configuración de costos del taller (Capa 1)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/auth_service.dart';

String get _negocioId => AuthService.negocioId ?? '';

class ConfigCostosScreen extends StatefulWidget {
  const ConfigCostosScreen({super.key});
  @override
  State<ConfigCostosScreen> createState() => _ConfigCostosScreenState();
}

class _ConfigCostosScreenState extends State<ConfigCostosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _sb = Supabase.instance.client;
  bool _cargando = true;
  bool _guardando = false;
  final _fmt = NumberFormat(r'$#,##0.00', 'es_MX');

  // ── EMPRESA ──────────────────────────────────────
  final _nombreCtrl    = TextEditingController();
  final _margenMinCtrl = TextEditingController(text: '20');
  final _margenRecCtrl = TextEditingController(text: '35');
  final _ivaCtrl       = TextEditingController(text: '16');
  final _horasDiaCtrl  = TextEditingController(text: '8');
  final _diasSemCtrl   = TextEditingController(text: '6');

  // ── COSTOS FIJOS ─────────────────────────────────
  final Map<String, TextEditingController> _costosCtrls = {
    'costo_renta':        TextEditingController(text: '0'),
    'costo_luz':          TextEditingController(text: '0'),
    'costo_agua':         TextEditingController(text: '0'),
    'costo_internet':     TextEditingController(text: '0'),
    'costo_nomina_admin': TextEditingController(text: '0'),
    'costo_contador':     TextEditingController(text: '0'),
    'costo_licencias':    TextEditingController(text: '0'),
    'costo_publicidad':   TextEditingController(text: '0'),
    'costo_seguros':      TextEditingController(text: '0'),
    'costo_depreciacion': TextEditingController(text: '0'),
    'costo_mantenimiento':TextEditingController(text: '0'),
    'costo_otros':        TextEditingController(text: '0'),
  };

  final Map<String, String> _costosLabels = {
    'costo_renta':        '🏭 Renta / Local',
    'costo_luz':          '💡 Electricidad',
    'costo_agua':         '💧 Agua',
    'costo_internet':     '🌐 Internet / Teléfono',
    'costo_nomina_admin': '👥 Nómina administrativa',
    'costo_contador':     '📊 Contador / Contabilidad',
    'costo_licencias':    '📋 Licencias / Software',
    'costo_publicidad':   '📢 Publicidad / Marketing',
    'costo_seguros':      '🛡️ Seguros',
    'costo_depreciacion': '📉 Depreciación general',
    'costo_mantenimiento':'🔧 Mantenimiento general',
    'costo_otros':        '📦 Otros gastos fijos',
  };

  // Costos calculados
  double _costoFijoMensual = 0;
  double _costoDiario = 0;
  double _costoHora = 0;
  double _costoMinuto = 0;

  // ── MAQUINARIA ───────────────────────────────────
  List<Map<String, dynamic>> _maquinas = [];
  List<Map<String, dynamic>> _operadores = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nombreCtrl.dispose();
    for (final c in _costosCtrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final results = await Future.wait([
        _sb.from('empresa_config').select()
          .eq('negocio_id', _negocioId).maybeSingle(),
        _sb.from('maquinaria').select()
          .eq('negocio_id', _negocioId).eq('activo', true),
        _sb.from('mano_obra').select()
          .eq('negocio_id', _negocioId).eq('activo', true),
      ]);

      final cfg = results[0] as Map<String, dynamic>?;
      if (cfg != null) {
        _nombreCtrl.text = cfg['nombre'] ?? '';
        _margenMinCtrl.text = (cfg['margen_minimo'] ?? 20).toString();
        _margenRecCtrl.text = (cfg['margen_recomendado'] ?? 35).toString();
        _ivaCtrl.text = (cfg['iva_pct'] ?? 16).toString();
        _horasDiaCtrl.text = (cfg['horas_dia'] ?? 8).toString();
        _diasSemCtrl.text = (cfg['dias_semana'] ?? 6).toString();
        for (final key in _costosCtrls.keys) {
          _costosCtrls[key]!.text =
            ((cfg[key] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
        }
        _recalcular();
      }

      if (mounted) setState(() {
        _maquinas = (results[1] as List).cast<Map<String, dynamic>>();
        _operadores = (results[2] as List).cast<Map<String, dynamic>>();
        _cargando = false;
      });
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _recalcular() {
    double total = 0;
    for (final c in _costosCtrls.values) {
      total += double.tryParse(c.text) ?? 0;
    }
    final horas = double.tryParse(_horasDiaCtrl.text) ?? 8;
    setState(() {
      _costoFijoMensual = total;
      _costoDiario = total / 30;
      _costoHora = total / (30 * horas);
      _costoMinuto = total / (30 * horas * 60);
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final datos = <String, dynamic>{
        'negocio_id': _negocioId,
        'nombre': _nombreCtrl.text.trim(),
        'margen_minimo': double.tryParse(_margenMinCtrl.text) ?? 20,
        'margen_recomendado': double.tryParse(_margenRecCtrl.text) ?? 35,
        'iva_pct': double.tryParse(_ivaCtrl.text) ?? 16,
        'horas_dia': double.tryParse(_horasDiaCtrl.text) ?? 8,
        'dias_semana': int.tryParse(_diasSemCtrl.text) ?? 6,
      };
      for (final key in _costosCtrls.keys) {
        datos[key] = double.tryParse(_costosCtrls[key]!.text) ?? 0;
      }

      // Buscar TODAS las filas existentes (por si hay duplicados de ejecuciones SQL previas)
      final existingRows = await _sb.from('empresa_config')
        .select('id').eq('negocio_id', _negocioId);
      final rows = existingRows as List;

      if (rows.isEmpty) {
        await _sb.from('empresa_config').insert(datos);
      } else {
        // Actualizar la primera fila y borrar duplicados si existieran
        final idPrincipal = rows.first['id'];
        await _sb.from('empresa_config').update(datos).eq('id', idPrincipal);
        if (rows.length > 1) {
          for (int i = 1; i < rows.length; i++) {
            await _sb.from('empresa_config').delete().eq('id', rows[i]['id']);
          }
        }
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Configuración guardada'),
        backgroundColor: AppColors.verde));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al guardar: $e'), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Configuración de Costos',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.azul))),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          isScrollable: true,
          tabs: const [
            Tab(text: '🏢 Empresa'),
            Tab(text: '💰 Costos fijos'),
            Tab(text: '⚙️ Máquinas'),
            Tab(text: '👷 Operadores'),
          ])),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            _tabEmpresa(),
            _tabCostosFijos(),
            _tabMaquinas(),
            _tabOperadores(),
          ]));
  }

  // ── TAB EMPRESA ──────────────────────────────────
  Widget _tabEmpresa() => ListView(padding: const EdgeInsets.all(14), children: [
    _card('Datos del negocio', [
      _campo(_nombreCtrl, 'Nombre del negocio', Icons.business_outlined),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _campoNum(_ivaCtrl, 'IVA %', sufijo: '%')),
        const SizedBox(width: 10),
        Expanded(child: _campoNum(_horasDiaCtrl, 'Horas/día')),
        const SizedBox(width: 10),
        Expanded(child: _campoNum(_diasSemCtrl, 'Días/semana')),
      ]),
    ]),
    const SizedBox(height: 12),
    _card('Márgenes de utilidad', [
      const Text(
        'El precio de venta = Costo Total ÷ (1 - Margen)',
        style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _campoNum(_margenMinCtrl, 'Margen mínimo %',
          color: AppColors.rojo, sufijo: '%')),
        const SizedBox(width: 10),
        Expanded(child: _campoNum(_margenRecCtrl, 'Margen recomendado %',
          color: AppColors.verde, sufijo: '%')),
      ]),
      const SizedBox(height: 10),
      // Preview márgenes
      if (_margenRecCtrl.text.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.azulClaro, borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            const Text('Ejemplo: trabajo con costo de \$1,000',
              style: TextStyle(fontSize: 11, color: AppColors.azul)),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _previewMargen('Mínimo',
                _calcPrecio(1000, double.tryParse(_margenMinCtrl.text) ?? 20),
                AppColors.rojo),
              _previewMargen('Recomendado',
                _calcPrecio(1000, double.tryParse(_margenRecCtrl.text) ?? 35),
                AppColors.verde),
            ]),
          ])),
      ],
    ]),
  ]);

  double _calcPrecio(double costo, double margen) =>
    margen >= 100 ? costo * 2 : costo / (1 - margen / 100);

  Widget _previewMargen(String label, double precio, Color color) => Column(children: [
    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
    Text(_fmt.format(precio),
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
  ]);

  // ── TAB COSTOS FIJOS ─────────────────────────────
  Widget _tabCostosFijos() => ListView(padding: const EdgeInsets.all(14), children: [
    // Panel de resumen
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.azul, Color(0xFF2d5a8e)]),
        borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        const Text('RESUMEN DE COSTOS FIJOS',
          style: TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text(_fmt.format(_costoFijoMensual),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
        const Text('por mes', style: TextStyle(fontSize: 12, color: Colors.white60)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _kpiCosto('Por día', _fmt.format(_costoDiario)),
          _kpiCosto('Por hora', _fmt.format(_costoHora)),
          _kpiCosto('Por minuto', '\$${_costoMinuto.toStringAsFixed(4)}'),
        ]),
      ])),
    const SizedBox(height: 14),
    // Campos de costos
    _card('Costos fijos mensuales', [
      ...(_costosCtrls.entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(_costosLabels[e.key] ?? e.key,
            style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 10),
          SizedBox(width: 120, child: TextFormField(
            controller: e.value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              isDense: true, filled: true, fillColor: AppColors.gris,
              prefixText: r'$',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            onChanged: (_) => _recalcular())),
        ])))),
    ]),
  ]);

  Widget _kpiCosto(String label, String val) => Column(children: [
    Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
  ]);

  // ── TAB MÁQUINAS ─────────────────────────────────
  Widget _tabMaquinas() => Column(children: [
    Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
      ..._maquinas.map((m) => _cardMaquina(m)),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => _editarMaquina(null),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Agregar máquina'),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.azul),
          foregroundColor: AppColors.azul)),
    ])),
  ]);

  Widget _cardMaquina(Map<String, dynamic> m) {
    final costoHora = _calcCostoHoraMaquina(m);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Row(children: [
        Text(m['emoji'] ?? '⚙️', style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m['nombre'] ?? '', style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.azul)),
          Text('${(m['horas_mes'] ?? 0).toStringAsFixed(0)} hrs/mes  •  '
            '\$${(m['costo_kwh'] ?? 0).toStringAsFixed(2)}/kWh',
            style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_fmt.format(costoHora),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.verde)),
          const Text('/ hora', style: TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _editarMaquina(m),
            child: const Icon(Icons.edit_outlined, size: 18, color: AppColors.azul)),
        ]),
      ]));
  }

  double _calcCostoHoraMaquina(Map<String, dynamic> m) {
    final valor = (m['valor_adquisicion'] as num?)?.toDouble() ?? 0;
    final vidaUtil = (m['vida_util_anos'] as num?)?.toDouble() ??
      (m['vida_util_años'] as num?)?.toDouble() ?? 5;
    final horasMes = (m['horas_mes'] as num?)?.toDouble() ?? 160;
    final kwh = (m['consumo_kwh'] as num?)?.toDouble() ?? 0;
    final costoKwh = (m['costo_kwh'] as num?)?.toDouble() ?? 2.5;
    final mant = (m['mantenimiento_mes'] as num?)?.toDouble() ?? 0;
    final consumibles = (m['consumibles_hora'] as num?)?.toDouble() ?? 0;

    final depreciacion = vidaUtil > 0 ? valor / (vidaUtil * 12 * horasMes) : 0;
    final electr = kwh * costoKwh;
    final mantHora = horasMes > 0 ? mant / horasMes : 0;
    return depreciacion + electr + mantHora + consumibles;
  }

  void _editarMaquina(Map<String, dynamic>? maquina) {
    final nombreCtrl = TextEditingController(text: maquina?['nombre'] ?? '');
    final valorCtrl = TextEditingController(
      text: ((maquina?['valor_adquisicion'] as num?)?.toDouble() ?? 0).toStringAsFixed(0));
    final vidaCtrl = TextEditingController(
      text: ((maquina?['vida_util_años'] as num?)?.toDouble() ?? 5).toStringAsFixed(0));
    final horasCtrl = TextEditingController(
      text: ((maquina?['horas_mes'] as num?)?.toDouble() ?? 160).toStringAsFixed(0));
    final kwhCtrl = TextEditingController(
      text: ((maquina?['consumo_kwh'] as num?)?.toDouble() ?? 0).toStringAsFixed(2));
    final costoKwhCtrl = TextEditingController(
      text: ((maquina?['costo_kwh'] as num?)?.toDouble() ?? 2.50).toStringAsFixed(2));
    final mantCtrl = TextEditingController(
      text: ((maquina?['mantenimiento_mes'] as num?)?.toDouble() ?? 0).toStringAsFixed(0));
    final consCtrl = TextEditingController(
      text: ((maquina?['consumibles_hora'] as num?)?.toDouble() ?? 0).toStringAsFixed(2));
    String emojiSel = maquina?['emoji'] ?? '⚙️';

    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) {
        // Preview costo/hora en tiempo real
        double previewCosto() {
          final v = double.tryParse(valorCtrl.text) ?? 0;
          final vida = double.tryParse(vidaCtrl.text) ?? 5;
          final hrs = double.tryParse(horasCtrl.text) ?? 160;
          final kwh = double.tryParse(kwhCtrl.text) ?? 0;
          final ckwh = double.tryParse(costoKwhCtrl.text) ?? 2.5;
          final mant = double.tryParse(mantCtrl.text) ?? 0;
          final cons = double.tryParse(consCtrl.text) ?? 0;
          final dep = vida > 0 ? v / (vida * 12 * hrs) : 0;
          return dep + (kwh * ckwh) + (hrs > 0 ? mant / hrs : 0) + cons;
        }

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.88,
          decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(maquina == null ? 'Nueva máquina' : 'Editar ${maquina['nombre']}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                GestureDetector(onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close)),
              ])),
            const Divider(height: 1),
            Expanded(child: SingleChildScrollView(
              padding: EdgeInsets.only(left: 16, right: 16, top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: Column(children: [
                // Emojis
                Wrap(spacing: 8, runSpacing: 8,
                  children: ['⚙️','🔧','⚡','🔴','🖨️','🛠️','🏭','🔩'].map((e) =>
                    GestureDetector(onTap: () => setS(() => emojiSel = e),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: emojiSel == e ? AppColors.azulClaro : AppColors.gris,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: emojiSel == e ? AppColors.azul : AppColors.grisBorde)),
                        child: Center(child: Text(e,
                          style: const TextStyle(fontSize: 22)))))).toList()),
                const SizedBox(height: 12),
                _campo(nombreCtrl, 'Nombre de la máquina', Icons.precision_manufacturing_outlined),
                const SizedBox(height: 10),
                // Costos
                Row(children: [
                  Expanded(child: _campoNum2(valorCtrl, 'Valor de compra \$', setS)),
                  const SizedBox(width: 8),
                  Expanded(child: _campoNum2(vidaCtrl, 'Vida útil (años)', setS)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _campoNum2(horasCtrl, 'Horas trabajo/mes', setS)),
                  const SizedBox(width: 8),
                  Expanded(child: _campoNum2(kwhCtrl, 'Consumo (kWh/hr)', setS)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _campoNum2(costoKwhCtrl, 'Precio kWh \$', setS)),
                  const SizedBox(width: 8),
                  Expanded(child: _campoNum2(mantCtrl, 'Mantenimiento \$/mes', setS)),
                ]),
                const SizedBox(height: 10),
                _campoNum2(consCtrl, 'Consumibles \$/hora (fresas, brocas...)', setS),
                const SizedBox(height: 14),
                // Preview costo/hora
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.verde.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.verde.withOpacity(0.3))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Costo/hora calculado:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(_fmt.format(previewCosto()),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                        color: AppColors.verde)),
                  ])),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final datos = {
                        'negocio_id': _negocioId,
                        'nombre': nombreCtrl.text.trim(),
                        'emoji': emojiSel,
                        'valor_adquisicion': double.tryParse(valorCtrl.text) ?? 0,
                        'vida_util_años': double.tryParse(vidaCtrl.text) ?? 5,
                        'horas_mes': double.tryParse(horasCtrl.text) ?? 160,
                        'consumo_kwh': double.tryParse(kwhCtrl.text) ?? 0,
                        'costo_kwh': double.tryParse(costoKwhCtrl.text) ?? 2.5,
                        'mantenimiento_mes': double.tryParse(mantCtrl.text) ?? 0,
                        'consumibles_hora': double.tryParse(consCtrl.text) ?? 0,
                        'activo': true,
                      };
                      if (maquina != null) {
                        await _sb.from('maquinaria').update(datos)
                          .eq('id', maquina['id']);
                      } else {
                        await _sb.from('maquinaria').insert(datos);
                      }
                      if (mounted) { Navigator.pop(ctx); _cargar(); }
                    },
                    icon: const Icon(Icons.save_outlined, color: Colors.white),
                    label: const Text('Guardar máquina',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.azul,
                      padding: const EdgeInsets.symmetric(vertical: 13)))),
              ]))),
          ]));
      }));
  }

  // ── TAB OPERADORES ───────────────────────────────
  Widget _tabOperadores() => Column(children: [
    Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
      ..._operadores.map((o) => _cardOperador(o)),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => _editarOperador(null),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Agregar operador'),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.azul),
          foregroundColor: AppColors.azul)),
    ])),
  ]);

  Widget _cardOperador(Map<String, dynamic> o) {
    final salario = (o['salario_mes'] as num?)?.toDouble() ?? 0;
    final prest = (o['prestaciones_pct'] as num?)?.toDouble() ?? 35;
    final horas = (o['horas_mes'] as num?)?.toDouble() ?? 192;
    final costoTotal = salario * (1 + prest / 100);
    final costoHora = horas > 0 ? costoTotal / horas : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Row(children: [
        Text(o['emoji'] ?? '👷', style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(o['nombre'] ?? '', style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.azul)),
          Text('Salario: ${_fmt.format(salario)}/mes  •  '
            'Prestaciones: ${prest.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          Text('${horas.toStringAsFixed(0)} horas/mes',
            style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_fmt.format(costoHora),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.naranja)),
          const Text('/ hora', style: TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _editarOperador(o),
            child: const Icon(Icons.edit_outlined, size: 18, color: AppColors.azul)),
        ]),
      ]));
  }

  void _editarOperador(Map<String, dynamic>? op) {
    final nombreCtrl = TextEditingController(text: op?['nombre'] ?? '');
    final salarioCtrl = TextEditingController(
      text: ((op?['salario_mes'] as num?)?.toDouble() ?? 0).toStringAsFixed(0));
    final prestCtrl = TextEditingController(
      text: ((op?['prestaciones_pct'] as num?)?.toDouble() ?? 35).toStringAsFixed(0));
    final horasCtrl = TextEditingController(
      text: ((op?['horas_mes'] as num?)?.toDouble() ?? 192).toStringAsFixed(0));
    String emojiSel = op?['emoji'] ?? '👷';

    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) {
        double costoHora() {
          final sal = double.tryParse(salarioCtrl.text) ?? 0;
          final prest = double.tryParse(prestCtrl.text) ?? 35;
          final hrs = double.tryParse(horasCtrl.text) ?? 192;
          return hrs > 0 ? sal * (1 + prest / 100) / hrs : 0;
        }

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(op == null ? 'Nuevo operador' : 'Editar ${op['nombre']}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                GestureDetector(onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close)),
              ])),
            const Divider(height: 1),
            Expanded(child: SingleChildScrollView(
              padding: EdgeInsets.only(left: 16, right: 16, top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: Column(children: [
                Wrap(spacing: 8, runSpacing: 8,
                  children: ['👷','🎨','🔧','👨‍💻','⚒️','🧰'].map((e) =>
                    GestureDetector(onTap: () => setS(() => emojiSel = e),
                      child: Container(width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: emojiSel == e ? AppColors.azulClaro : AppColors.gris,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: emojiSel == e ? AppColors.azul : AppColors.grisBorde)),
                        child: Center(child: Text(e,
                          style: const TextStyle(fontSize: 22)))))).toList()),
                const SizedBox(height: 12),
                _campo(nombreCtrl, 'Nombre / Puesto', Icons.person_outlined),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _campoNum2(salarioCtrl, 'Salario \$/mes', setS)),
                  const SizedBox(width: 8),
                  Expanded(child: _campoNum2(prestCtrl, 'Prestaciones %', setS)),
                ]),
                const SizedBox(height: 10),
                _campoNum2(horasCtrl, 'Horas laborales al mes', setS),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.naranja.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Costo/hora calculado:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(_fmt.format(costoHora()),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                        color: AppColors.naranja)),
                  ])),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final datos = {
                        'negocio_id': _negocioId,
                        'nombre': nombreCtrl.text.trim(),
                        'emoji': emojiSel,
                        'salario_mes': double.tryParse(salarioCtrl.text) ?? 0,
                        'prestaciones_pct': double.tryParse(prestCtrl.text) ?? 35,
                        'horas_mes': double.tryParse(horasCtrl.text) ?? 192,
                        'activo': true,
                      };
                      if (op != null) {
                        await _sb.from('mano_obra').update(datos).eq('id', op['id']);
                      } else {
                        await _sb.from('mano_obra').insert(datos);
                      }
                      if (mounted) { Navigator.pop(ctx); _cargar(); }
                    },
                    icon: const Icon(Icons.save_outlined, color: Colors.white),
                    label: const Text('Guardar operador',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.azul,
                      padding: const EdgeInsets.symmetric(vertical: 13)))),
              ]))),
          ]));
      }));
  }

  // ── HELPERS ──────────────────────────────────────
  Widget _card(String titulo, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.azul)),
      const SizedBox(height: 14),
      ...children,
    ]));

  Widget _campo(TextEditingController ctrl, String label, [IconData? icon]) =>
    TextFormField(controller: ctrl,
      decoration: InputDecoration(labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        border: const OutlineInputBorder(), isDense: true),
      style: const TextStyle(fontSize: 13));

  Widget _campoNum(TextEditingController ctrl, String label,
    {Color? color, String? sufijo}) =>
    TextFormField(controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label, suffixText: sufijo,
        border: const OutlineInputBorder(), isDense: true,
        labelStyle: TextStyle(color: color)),
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
      onChanged: (_) => setState(() {}));

  Widget _campoNum2(TextEditingController ctrl, String label,
    StateSetter setS) =>
    TextFormField(controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(
        labelText: label, border: const OutlineInputBorder(), isDense: true),
      style: const TextStyle(fontSize: 13),
      onChanged: (_) => setS(() {}));
}
