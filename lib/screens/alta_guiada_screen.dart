// Alta guiada: 4 pantallas para que un taller nuevo cotice su primera pieza
// en la misma sesión en que se registró.
//
//   1. ¿Qué máquinas tienes?   → chips por tipo; cada una con $/h y potencia
//                                típicos de HETNA ya puestos (editables).
//   2. ¿Qué materiales usas?   → lista marcable con precios de referencia.
//   3. Tu taller               → operador $/h, margen, horas al día.
//   4. Listo                   → "Cotiza tu primera pieza" o "Ver un ejemplo".
//
// Se crean solas las máquinas (maquinaria), los materiales (inventario_bodega)
// y los datos del taller (empresa_config + mano_obra). Las velocidades son las
// de HETNA (marcadas "sugerido") hasta que el taller las corrija con tiempos
// reales. Todo se puede cambiar después en Costos del taller e Inventario.
//
// Devuelve con Navigator.pop: 'simular' (abrir el simulador), 'ejemplo'
// (abrir el simulador con la pieza de muestra) o null (saltó).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../i18n/tr.dart';
import '../services/auth_service.dart';
import '../simulador2/motor.dart';
import '../simulador2/simulador2_data.dart';
import '../simulador2/velocidades_hetna.dart';

class AltaGuiadaScreen extends StatefulWidget {
  const AltaGuiadaScreen({super.key});
  @override
  State<AltaGuiadaScreen> createState() => _AltaGuiadaScreenState();
}

class _MaqAlta {
  final String tipo;
  final TextEditingController nombre, costoHora, potencia;
  _MaqAlta(this.tipo, String nom, double costo, double pot)
    : nombre = TextEditingController(text: nom),
      costoHora = TextEditingController(text: costo.toStringAsFixed(0)),
      potencia = TextEditingController(text: pot == 0 ? '' : (pot == pot.roundToDouble() ? pot.toStringAsFixed(0) : pot.toString()));
}

class _AltaGuiadaScreenState extends State<AltaGuiadaScreen> {
  final _sb = Supabase.instance.client;
  final _fmt = NumberFormat('\$#,##0', 'es_MX');
  final _pageCtrl = PageController();
  int _paso = 0;
  static const _total = 4;
  bool _guardando = false;
  String? _error;

  // Valores típicos de HETNA por tipo de máquina: $/h en México y potencia
  // (kW spindle · W tubo láser · A plasma · kW fibra). Son punto de partida.
  static const _tipos = ['router', 'laser_co2', 'plasma', 'laser_fibra', 'router_3d', 'impresora_3d', 'torno'];
  static const _costoRef = {'router': 350.0, 'laser_co2': 320.0, 'plasma': 480.0, 'laser_fibra': 950.0, 'router_3d': 350.0, 'impresora_3d': 60.0, 'torno': 450.0};
  static const _potenciaRef = {'router': 2.2, 'laser_co2': 100.0, 'plasma': 65.0, 'laser_fibra': 1.5, 'router_3d': 2.2, 'impresora_3d': 0.0, 'torno': 3.0};
  static const _unidadPotencia = {'router': 'kW', 'laser_co2': 'W', 'plasma': 'A', 'laser_fibra': 'kW', 'router_3d': 'kW', 'impresora_3d': '', 'torno': 'kW'};
  static const _nombreRef = {'router': 'Router 1325', 'laser_co2': 'Láser CO2 1390', 'plasma': 'Plasma 1530', 'laser_fibra': 'Fibra 3015', 'router_3d': 'Router 3D', 'impresora_3d': 'Impresora 3D', 'torno': 'Torno CNC'};

  final List<_MaqAlta> _maquinas = [];
  // Materiales marcados (por id de referencia)
  final Map<String, Material2> _materiales = {};
  // Taller
  final _operadorC = TextEditingController(text: '60');
  final _margenC = TextEditingController(text: '35');
  final _horasC = TextEditingController(text: '8');

  bool _tiene(String tipo) => _maquinas.any((m) => m.tipo == tipo);

  void _alternarTipo(String tipo) {
    setState(() {
      if (_tiene(tipo)) {
        _maquinas.removeWhere((m) => m.tipo == tipo);
      } else {
        _maquinas.add(_MaqAlta(tipo, _nombreRef[tipo] ?? tipo, _costoRef[tipo] ?? 350, _potenciaRef[tipo] ?? 0));
        _preseleccionarMateriales(tipo);
      }
    });
  }

  // Los 2–3 materiales más comunes de cada tipo quedan marcados de entrada.
  void _preseleccionarMateriales(String tipo) {
    const comunes = {
      'router': ['ref_mdf_18.0', 'ref_mdf_6.0', 'ref_triplay_12.0'],
      'laser_co2': ['ref_mdf_3.0', 'ref_acrilico_3.0'],
      'plasma': ['ref_acero_3.2', 'ref_acero_6.4'],
      'laser_fibra': ['ref_acero_1.9', 'ref_inox_1.5'],
      'router_3d': ['ref_mdf_18.0'],
      'impresora_3d': ['ref_pla_0.0', 'ref_petg_0.0'],
      'torno': ['ref_aluminio_3.0', 'ref_acero_6.4'],
    };
    for (final m in Simulador2Data.materialesReferencia(tipo)) {
      if ((comunes[tipo] ?? const []).contains(m.id)) _materiales[m.id!] = m;
    }
  }

  List<Material2> _materialesDisponibles() {
    final vistos = <String>{};
    final l = <Material2>[];
    for (final maq in _maquinas) {
      for (final m in Simulador2Data.materialesReferencia(maq.tipo)) {
        if (vistos.add(m.id!)) l.add(m);
      }
    }
    return l;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      body: SafeArea(child: Column(children: [
        _header(),
        Expanded(child: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [_pasoMaquinas(), _pasoMateriales(), _pasoTaller(), _pasoListo()],
        )),
      ])),
    );
  }

  Widget _header() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    child: Column(children: [
      Row(children: [
        if (_paso > 0 && _paso < 3)
          TextButton.icon(onPressed: _atras, icon: const Icon(Icons.arrow_back_ios, size: 14), label: Text(tr('Atrás')))
        else const SizedBox(width: 80),
        Expanded(child: Text(trf('Paso {0} de {1}', [_paso + 1, _total]), textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario))),
        if (_paso < 3)
          TextButton(onPressed: _saltar, child: Text(tr('Después'), style: const TextStyle(fontSize: 12)))
        else const SizedBox(width: 80),
      ]),
      const SizedBox(height: 6),
      Row(children: List.generate(_total, (i) => Expanded(child: Container(height: 4,
        margin: EdgeInsets.only(right: i < _total - 1 ? 4 : 0),
        decoration: BoxDecoration(color: i <= _paso ? AppColors.azul : AppColors.grisBorde, borderRadius: BorderRadius.circular(2)))))),
    ]));

  Widget _wrap({required String emoji, required String titulo, required String sub, required List<Widget> hijos, required Widget boton}) => Column(children: [
    Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
      Text(emoji, style: const TextStyle(fontSize: 34)),
      const SizedBox(height: 6),
      Text(titulo, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.textoPrincipal)),
      const SizedBox(height: 4),
      Text(sub, style: const TextStyle(fontSize: 13.5, color: AppColors.textoSecundario, height: 1.35)),
      const SizedBox(height: 16),
      ...hijos,
      if (_error != null) ...[const SizedBox(height: 10), Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.rojoClaro, borderRadius: BorderRadius.circular(8)),
        child: Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 12.5)))],
    ])),
    Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(16, 10, 16, 14), child: boton),
  ]);

  Widget _btn(String texto, VoidCallback? onTap, {IconData? icono}) => SizedBox(width: double.infinity, height: 48,
    child: ElevatedButton.icon(
      onPressed: _guardando ? null : onTap,
      icon: _guardando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icono ?? Icons.arrow_forward, color: Colors.white, size: 18),
      label: Text(texto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))));

  // ── 1. Máquinas ──
  Widget _pasoMaquinas() => _wrap(
    emoji: '🏭', titulo: tr('¿Qué máquinas tienes?'),
    sub: tr('Marca las que uses. Te ponemos el costo por hora y la potencia típicos; los cambias cuando quieras.'),
    hijos: [
      Wrap(spacing: 8, runSpacing: 8, children: _tipos.map((t) => FilterChip(
        selected: _tiene(t),
        label: Text('${emojiTipoMaquina[t] ?? ''} ${nombresTipoMaquina[t] ?? t}'),
        selectedColor: AppColors.azulClaro, checkmarkColor: AppColors.azul,
        onSelected: (_) => _alternarTipo(t))).toList()),
      const SizedBox(height: 14),
      ..._maquinas.map(_tarjetaMaquina),
      if (_maquinas.isEmpty) Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.grisBorde)),
        child: Text(tr('Si todavía no tienes máquina, pasa al siguiente paso: podrás simular con las máquinas de referencia de HETNA.'),
          style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario))),
    ],
    boton: _btn(tr('Siguiente'), _siguiente));

  Widget _tarjetaMaquina(_MaqAlta m) => Container(
    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.grisBorde)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(emojiTipoMaquina[m.tipo] ?? '⚙️', style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: m.nombre, decoration: InputDecoration(isDense: true, labelText: tr('Nombre'), border: const OutlineInputBorder()))),
        IconButton(onPressed: () => _alternarTipo(m.tipo), icon: const Icon(Icons.close, size: 18, color: AppColors.textoSecundario)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: TextField(controller: m.costoHora, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(isDense: true, labelText: tr('Costo por hora'), prefixText: '\$ ', suffixText: '/h', border: const OutlineInputBorder()))),
        if ((_unidadPotencia[m.tipo] ?? '').isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: m.potencia, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(isDense: true, labelText: tr('Potencia'), suffixText: _unidadPotencia[m.tipo], border: const OutlineInputBorder()))),
        ],
      ]),
      const SizedBox(height: 6),
      Text(tr('Referencia HETNA. En "Costos del taller" puedes calcularlo con tu luz, depreciación y mantenimiento.'),
        style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
    ]));

  // ── 2. Materiales ──
  Widget _pasoMateriales() {
    final disp = _materialesDisponibles();
    return _wrap(
      emoji: '🪵', titulo: tr('¿Qué materiales usas?'),
      sub: tr('Van a tu inventario con un precio de referencia. Después pones tu precio real y tu existencia.'),
      hijos: [
        if (disp.isEmpty) Text(tr('Marca al menos una máquina en el paso anterior para ver materiales.'), style: const TextStyle(color: AppColors.textoSecundario)),
        ...disp.map((m) {
          final sel = _materiales.containsKey(m.id);
          return CheckboxListTile(
            value: sel, dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.azul,
            title: Text(m.nombre.replaceAll(' (referencia)', ''), style: const TextStyle(fontSize: 14)),
            subtitle: Text('${_fmt.format(m.precio)} / ${m.unidad == 'hoja' ? tr('hoja') : m.unidad}${m.esHoja ? ' · ${m.hojaLargo.toStringAsFixed(0)}×${m.hojaAncho.toStringAsFixed(0)} mm' : ''}',
              style: const TextStyle(fontSize: 11.5)),
            onChanged: (v) => setState(() { if (v == true) { _materiales[m.id!] = m; } else { _materiales.remove(m.id); } }));
        }),
      ],
      boton: _btn(trf('Siguiente ({0} materiales)', [_materiales.length]), _siguiente));
  }

  // ── 3. Taller ──
  Widget _pasoTaller() => _wrap(
    emoji: '🧮', titulo: tr('Tu taller en 3 números'),
    sub: tr('Con esto el simulador calcula el precio completo: material + máquina + operador + margen. Luego afinas renta, luz y lo demás en "Costos del taller".'),
    hijos: [
      _campo(_operadorC, tr('Lo que cuesta tu operador por hora'), prefijo: '\$ ', sufijo: '/h', ayuda: tr('Sueldo mensual con prestaciones ÷ horas trabajadas. 60 es típico en México.')),
      const SizedBox(height: 12),
      _campo(_margenC, tr('Margen que quieres ganar'), sufijo: '%', ayuda: tr('Sobre el costo total. 30–40 % es común en corte CNC.')),
      const SizedBox(height: 12),
      _campo(_horasC, tr('Horas que trabaja el taller al día'), sufijo: 'h', ayuda: tr('Para calcular la fecha de entrega.')),
    ],
    boton: _btn(tr('Guardar y terminar'), _guardarTodo, icono: Icons.check));

  Widget _campo(TextEditingController c, String label, {String? prefijo, String? sufijo, String? ayuda}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixText: prefijo, suffixText: sufijo, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
    if (ayuda != null) Padding(padding: const EdgeInsets.only(top: 4, left: 4), child: Text(ayuda, style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario))),
  ]);

  // ── 4. Listo ──
  Widget _pasoListo() => Column(children: [
    Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
      const SizedBox(height: 20),
      const Center(child: Text('🎉', style: TextStyle(fontSize: 56))),
      const SizedBox(height: 10),
      Center(child: Text(tr('¡Tu taller ya está listo!'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
      const SizedBox(height: 6),
      Center(child: Text(trf('{0} máquinas · {1} materiales · velocidades HETNA sugeridas', [_maquinas.length, _materiales.length]),
        textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario))),
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.verdeClaro, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Cómo funciona el simulador'), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.verde)),
          const SizedBox(height: 6),
          Text(tr('1. Sube tu DXF, SVG o STL.\n2. Elige máquina y material.\n3. HETNA calcula tiempo, costo y precio con margen.\n4. Pásalo a cotización y mándalo por WhatsApp.'),
            style: const TextStyle(fontSize: 13, height: 1.5)),
        ])),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.grisBorde)),
        child: Text(tr('En Inicio verás tu checklist de arranque: al completar los 5 pasos te regalamos 15 días más de prueba.'),
          style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario))),
    ])),
    Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(16, 10, 16, 14), child: Column(children: [
      _btn(tr('Cotiza tu primera pieza'), () => Navigator.pop(context, 'simular'), icono: Icons.calculate_outlined),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, height: 44, child: OutlinedButton.icon(
        onPressed: () => Navigator.pop(context, 'ejemplo'),
        icon: const Icon(Icons.visibility_outlined, size: 18),
        label: Text(tr('Ver una pieza de ejemplo')),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.azul, side: const BorderSide(color: AppColors.azul), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    ])),
  ]);

  // ── Navegación ──
  void _siguiente() { setState(() { _error = null; _paso++; }); _pageCtrl.animateToPage(_paso, duration: const Duration(milliseconds: 280), curve: Curves.easeInOut); }
  void _atras() { setState(() { _error = null; _paso--; }); _pageCtrl.animateToPage(_paso, duration: const Duration(milliseconds: 280), curve: Curves.easeInOut); }

  Future<void> _saltar() async {
    try { await _sb.rpc('marcar_arranque_visto'); } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  // ── Guardar ──
  double _num(TextEditingController c, double def) => double.tryParse(c.text.replaceAll(',', '.').trim()) ?? def;

  Future<void> _guardarTodo() async {
    final neg = AuthService.negocioId;
    if (neg == null) { setState(() => _error = tr('No encontré tu taller. Cierra sesión y vuelve a entrar.')); return; }
    setState(() { _guardando = true; _error = null; });
    try {
      // Máquinas: costo manual + potencia; horas_mes para que Costos del taller tenga base
      for (final m in _maquinas) {
        final pot = _num(m.potencia, 0);
        await _sb.from('maquinaria').insert({
          'negocio_id': neg,
          'nombre': m.nombre.text.trim().isEmpty ? (_nombreRef[m.tipo] ?? m.tipo) : m.nombre.text.trim(),
          'emoji': emojiTipoMaquina[m.tipo] ?? '⚙️',
          'tipo': m.tipo,
          'tipo_maquina': Simulador2Data.aFase4[m.tipo] ?? 'otra',
          'costo_hora_manual': _num(m.costoHora, _costoRef[m.tipo] ?? 350),
          if (pot > 0) 'potencia': pot,
          'preparacion_min': m.tipo == 'impresora_3d' ? 5 : m.tipo.startsWith('laser') ? 8 : 15,
          'perforacion_seg': m.tipo == 'router' ? 2 : m.tipo.startsWith('laser') ? 0.5 : 1.5,
          'horas_mes': 160,
          'activo': true,
        });
      }
      // Materiales de referencia al inventario
      for (final m in _materiales.values) {
        await Simulador2Data.agregarMaterialAlInventario(m);
      }
      // Taller: margen y horas en empresa_config; operador como fila de mano_obra
      final horas = _num(_horasC, 8);
      await Simulador2Data.guardarTaller({
        'margen_recomendado': _num(_margenC, 35),
        'horas_dia': horas,
      });
      final opHora = _num(_operadorC, 60);
      try {
        final ops = await _sb.from('mano_obra').select('id').eq('negocio_id', neg).limit(1);
        if ((ops as List).isEmpty) {
          // salario = $/h × horas_mes ÷ (1 + prestaciones)
          await _sb.from('mano_obra').insert({
            'negocio_id': neg, 'nombre': tr('Operador'), 'emoji': '👷',
            'salario_mes': (opHora * 192 / 1.35).roundToDouble(), 'prestaciones_pct': 35, 'horas_mes': 192, 'activo': true,
          });
        }
      } catch (_) {}
      try { await _sb.rpc('marcar_arranque_visto'); } catch (_) {}
      if (mounted) { setState(() => _guardando = false); _siguiente(); }
    } catch (e) {
      if (mounted) setState(() { _guardando = false; _error = '${tr('No se pudo guardar')}: $e'; });
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final m in _maquinas) { m.nombre.dispose(); m.costoHora.dispose(); m.potencia.dispose(); }
    _operadorC.dispose(); _margenC.dispose(); _horasC.dispose();
    super.dispose();
  }
}
