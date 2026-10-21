// lib/screens/config_simulador_screen.dart
// HETNA CNC — Configuración del simulador (solo admin)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/auth_service.dart';
import 'simulador_screen.dart' hide SimuladorScreen;

class ConfigSimuladorScreen extends StatefulWidget {
  const ConfigSimuladorScreen({super.key});
  @override
  State<ConfigSimuladorScreen> createState() => _ConfigSimuladorScreenState();
}

class _ConfigSimuladorScreenState extends State<ConfigSimuladorScreen> {
  List<SimServicio> _servicios = [];
  SimServicio? _servicioSel;
  SimConfig? _config;
  bool _cargando = true;
  bool _guardando = false;
  final _fmt = NumberFormat('\$#,##0.00', 'es_MX');

  @override
  void initState() { super.initState(); _cargarServicios(); }

  Future<void> _cargarServicios() async {
    setState(() => _cargando = true);
    final svcs = await SimuladorDataService.getServicios();
    if (mounted) setState(() {
      _servicios = svcs;
      _cargando = false;
    });
  }

  Future<void> _cargarConfig(SimServicio s) async {
    setState(() { _cargando = true; _config = null; });
    final cfg = await SimuladorDataService.getConfig(s.id);
    if (mounted) setState(() { _config = cfg; _cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0.5,
        title: const Text('Configurar simulador',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
        actions: [
          IconButton(
            onPressed: () => _mostrarAyudaGeneral(),
            icon: const Icon(Icons.help_outline, color: AppColors.azul),
            tooltip: 'Ayuda'),
          if (_servicioSel != null)
            TextButton.icon(
              onPressed: _agregarServicio,
              icon: const Icon(Icons.add, color: AppColors.azul, size: 18),
              label: const Text('Nuevo', style: TextStyle(color: AppColors.azul))),
        ]),
      body: _cargando && _servicios.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _servicioSel == null
          ? _pantallaServicios()
          : _pantallaConfig(),
    );
  }

  // ── LISTA DE SERVICIOS ──────────────────────────────
  Widget _pantallaServicios() => ListView(padding: const EdgeInsets.all(14), children: [
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.azulClaro, borderRadius: BorderRadius.circular(10)),
      child: const Text(
        '⚙️ Selecciona un servicio para configurar sus tarifas, materiales, tipos de trabajo y extras.',
        style: TextStyle(fontSize: 13, color: AppColors.azul))),
    const SizedBox(height: 14),
    ..._servicios.map((s) => GestureDetector(
      onTap: () {
        setState(() => _servicioSel = s);
        _cargarConfig(s);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Row(children: [
          Text(s.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.nombre, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.azul)),
            Text('Toca para configurar', style: const TextStyle(
              fontSize: 11, color: AppColors.textoSecundario)),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
        ])))),
  ]);

  // ── CONFIGURACIÓN DE UN SERVICIO ────────────────────
  Widget _pantallaConfig() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_config == null) return const Center(child: Text('Error al cargar'));
    final cfg = _config!;

    return ListView(padding: const EdgeInsets.all(14), children: [
      // Header
      GestureDetector(
        onTap: () => setState(() { _servicioSel = null; _config = null; }),
        child: Row(children: [
          const Icon(Icons.arrow_back_ios, size: 16, color: AppColors.azul),
          const SizedBox(width: 6),
          Text('${_servicioSel!.emoji} ${_servicioSel!.nombre}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
        ])),
      const SizedBox(height: 16),

      // ── TARIFAS ──
      _seccionCard('💰 Tarifas', cfg.tarifas.values.toList(),
        ayuda: 'El precio base por unidad de trabajo, por ejemplo "corte por metro" a \$50, o "precio por hora de máquina" a \$300.',
        addLabel: '+ Agregar tarifa',
        onAdd: () => _nuevoItem('tarifa'),
        builder: (_, i) {
          final t = cfg.tarifas.values.toList()[i];
          return _itemEditable(
            titulo: t.nombre,
            subtitulo: t.unidad ?? '',
            valor: t.valor,
            onGuardar: (v) => _guardarTarifa(t.id, v),
            onEliminar: () => _eliminarItem('sim_tarifas', t.id, () => _cargarConfig(_servicioSel!)),
          );
        }),

      const SizedBox(height: 12),

      // ── RANGOS (solo router) ──
      if (cfg.rangos.isNotEmpty || _servicioSel?.nombre.toLowerCase().contains('router') == true)
        _seccionCard('📊 Tabla de rangos (Router)',
          cfg.rangos,
          ayuda: 'Para cuando el precio cambia según qué tan grande es el trabajo (ej. cortar 1-10 piezas a \$50 c/u, pero 11-50 piezas a \$40 c/u). "Índice desde/hasta" son los límites del rango.',
          addLabel: '+ Agregar rango',
          onAdd: () => _nuevoRango(),
          builder: (_, i) {
            final r = cfg.rangos[i];
            return _itemRango(r);
          }),

      if (cfg.rangos.isNotEmpty) const SizedBox(height: 12),

      // ── MATERIALES ──
      if (false) // materiales ahora en inventario
        _seccionCard('🪨 Materiales',
          [],
          addLabel: '+ Agregar material',
          onAdd: () => _nuevoNombre('sim_materiales', 'Material'),
          builder: (_, i) {
            final m = [][i];
            return _itemNombre(m.nombre, m.id, 'sim_materiales');
          }),

      if (false) // materiales ahora en inventario const SizedBox(height: 12),

      // ── TIPOS DE TRABAJO ──
      if (cfg.tipos.isNotEmpty)
        _seccionCard('🔨 Tipos de trabajo',
          cfg.tipos,
          ayuda: 'Variantes dentro del servicio (ej. "Corte simple", "Relieve 3D"). El Factor de complejidad multiplica el precio base: 1.0 = normal, 1.5 = 50% más caro, 3.0 = el triple.',
          addLabel: '+ Agregar tipo',
          onAdd: () => _nuevoTipo(),
          builder: (_, i) {
            final t = cfg.tipos[i];
            return _itemTipoTrabajo(t);
          }),

      if (cfg.tipos.isNotEmpty) const SizedBox(height: 12),

      // ── ACABADOS ──
      if (cfg.acabados.isNotEmpty)
        _seccionCard('✨ Acabados',
          cfg.acabados,
          ayuda: 'Terminados opcionales que el cliente puede elegir y suman un costo fijo (ej. "Barniz", "Pintura", "Pulido").',
          addLabel: '+ Agregar acabado',
          onAdd: () => _nuevoExtra('sim_acabados', 'Acabado'),
          builder: (_, i) {
            final a = cfg.acabados[i];
            return _itemEditable(
              titulo: a.nombre,
              subtitulo: "",
              valor: a.precio,
              onGuardar: (v) => _guardarPrecio('sim_acabados', a.id, v),
              onEliminar: () => _eliminarItem('sim_acabados', a.id, () => _cargarConfig(_servicioSel!)),
            );
          }),

      if (cfg.acabados.isNotEmpty) const SizedBox(height: 12),

      // ── EXTRAS ──
      if (cfg.extras.isNotEmpty)
        _seccionCard('🎁 Extras',
          cfg.extras,
          ayuda: 'Cargos adicionales opcionales que no son de terminado (ej. "Entrega urgente", "Diseño personalizado"). Pueden ser precio fijo, porcentaje, o por pieza.',
          addLabel: '+ Agregar extra',
          onAdd: () => _nuevoExtra('sim_extras', 'Extra'),
          builder: (_, i) {
            final e = cfg.extras[i];
            return _itemEditable(
              titulo: e.nombre,
              subtitulo: "",
              valor: e.precio,
              onGuardar: (v) => _guardarPrecio('sim_extras', e.id, v),
              onEliminar: () => _eliminarItem('sim_extras', e.id, () => _cargarConfig(_servicioSel!)),
            );
          }),

      const SizedBox(height: 40),
    ]);
  }

  // ── CARD SECCIÓN ────────────────────────────────────
  Widget _seccionCard<T>(String titulo, List<T> items, {
    required Widget Function(BuildContext, int) builder,
    required String addLabel,
    required VoidCallback onAdd,
    String? ayuda,
  }) => Container(
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Text(titulo, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
            if (ayuda != null) GestureDetector(
              onTap: () => _mostrarAyuda(titulo, ayuda),
              child: Padding(padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.help_outline, size: 16, color: AppColors.textoSecundario.withOpacity(0.7)))),
          ]),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.azulClaro, borderRadius: BorderRadius.circular(20)),
              child: Text(addLabel, style: const TextStyle(
                fontSize: 11, color: AppColors.azul, fontWeight: FontWeight.w600)))),
        ])),
      const Divider(height: 1, color: AppColors.grisBorde),
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.grisBorde),
        itemBuilder: builder),
    ]));

  // ── AYUDA: diálogo corto por sección ────────────────
  void _mostrarAyuda(String titulo, String texto) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.help_outline, color: AppColors.azul, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(titulo, style: const TextStyle(fontSize: 15))),
      ]),
      content: Text(texto, style: const TextStyle(fontSize: 13, height: 1.4)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))]));
  }

  // ── AYUDA: pantalla completa del Simulador ──────────
  void _mostrarAyudaGeneral() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: ListView(controller: scrollCtrl, padding: const EdgeInsets.fromLTRB(20, 12, 20, 30), children: [
            Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('❓ Cómo funciona el Simulador', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.azul)),
            const SizedBox(height: 8),
            const Text(
              'El Simulador calcula un precio sugerido para un trabajo, combinando lo que tú configuras aquí '
              '(tarifas, tipos de trabajo) con las medidas que captura tu vendedor al cotizar. Aquí abajo se '
              'explica cada sección para que sepas qué llenar.',
              style: TextStyle(fontSize: 13, color: AppColors.textoSecundario, height: 1.4)),
            _bloqueAyuda('💰 Tarifas',
              'El precio base por unidad de trabajo. Por ejemplo, "corte por metro" a \$50, o "precio por hora de '
              'máquina" a \$300. Cada servicio (Router, Herrería, Láser, etc.) tiene sus propias tarifas.'),
            _bloqueAyuda('🔨 Tipos de trabajo y Factor de complejidad',
              'Un "tipo de trabajo" es una variante dentro del servicio — por ejemplo, dentro de Router puedes '
              'tener "Corte simple", "Relieve 3D", "Escultura". El Factor de complejidad multiplica el precio '
              'base según qué tan difícil es ese trabajo comparado con lo más sencillo:\n\n'
              '• Factor 1.0 = trabajo normal, sin ajuste (corte simple)\n'
              '• Factor 1.5 = 50% más caro que lo normal\n'
              '• Factor 3.0 = el triple de precio (por ejemplo, relieve 3D, que tarda más y desgasta más la '
              'herramienta)\n\n'
              'Regla simple: entre más tiempo, cuidado o desgaste de herramienta necesite un trabajo, más alto '
              'debe ser su factor.'),
            _bloqueAyuda('📊 Tabla de rangos',
              'Se usa cuando el precio no es siempre el mismo por unidad, sino que cambia según qué tan grande '
              'es el trabajo — por ejemplo, cortar de 1 a 10 piezas cuesta \$50 cada una, pero de 11 a 50 piezas '
              'baja a \$40 cada una (por volumen). "Índice desde" e "Índice hasta" son los límites de ese rango '
              '(ej. desde 1 hasta 10), y "Precio" es lo que aplica dentro de ese rango.'),
            _bloqueAyuda('✨ Acabados',
              'Opciones extra de terminado que el cliente puede elegir y que suman un costo fijo al final — '
              'por ejemplo "Barniz", "Pintura", "Pulido". Se le suman al precio base del trabajo si el cliente '
              'los pide.'),
            _bloqueAyuda('🎁 Extras',
              'Cargos adicionales opcionales que no son de terminado — por ejemplo "Entrega urgente", "Diseño '
              'personalizado", "Instalación". Pueden ser un precio fijo, un porcentaje del total, o un precio '
              'por pieza, según cómo lo configures.'),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(10)),
              child: const Text('💡 Consejo: si no estás seguro de un precio, empieza con un número '
                'aproximado y ajústalo después de cotizar unos trabajos reales — es más fácil corregir '
                'que adivinar desde cero.',
                style: TextStyle(fontSize: 12, color: AppColors.azul, height: 1.4))),
          ]))));
  }

  Widget _bloqueAyuda(String titulo, String texto) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textoPrincipal)),
      const SizedBox(height: 6),
      Text(texto, style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario, height: 1.45)),
    ]));

  // ── ITEM EDITABLE (tarifa con valor numérico) ───────
  Widget _itemEditable({
    required String titulo, required String subtitulo,
    required double valor, required void Function(double) onGuardar,
    required VoidCallback onEliminar,
  }) {
    final ctrl = TextEditingController(
      text: valor % 1 == 0 ? valor.toInt().toString() : valor.toStringAsFixed(2));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          if (subtitulo.isNotEmpty)
            Text(subtitulo, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ])),
        const SizedBox(width: 10),
        SizedBox(width: 90,
          child: TextFormField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              isDense: true, filled: true, fillColor: AppColors.gris,
              prefixText: '\$',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.grisBorde))),
            onFieldSubmitted: (v) {
              final d = double.tryParse(v);
              if (d != null) onGuardar(d);
            })),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            final d = double.tryParse(ctrl.text);
            if (d != null) onGuardar(d);
          },
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.verde, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.check, color: Colors.white, size: 16))),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onEliminar,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.rojo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.delete_outline, color: AppColors.rojo, size: 16))),
      ]));
  }

  // ── ITEM NOMBRE (material, sin valor) ───────────────
  Widget _itemNombre(String nombre, String id, String tabla) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(child: Text(nombre,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        GestureDetector(
          onTap: () => _editarNombre(id, tabla, nombre),
          child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textoSecundario)),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _eliminarItem(tabla, id, () => _cargarConfig(_servicioSel!)),
          child: const Icon(Icons.delete_outline, size: 16, color: AppColors.rojo)),
      ]));

  // ── ITEM TIPO DE TRABAJO (con factor) ───────────────
  Widget _itemTipoTrabajo(SimTipoTrabajo t) {
    final ctrl = TextEditingController(text: t.factor.toString());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('Factor de complejidad: ${t.factor}',
            style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ])),
        const SizedBox(width: 10),
        SizedBox(width: 70,
          child: TextFormField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              isDense: true, filled: true, fillColor: AppColors.gris,
              labelText: 'Factor',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            onFieldSubmitted: (v) async {
              final d = double.tryParse(v);
              if (d != null) {
                await Supabase.instance.client.from('sim_tipos_trabajo')
                  .update({'factor_complejidad': d}).eq('id', t.id);
                _cargarConfig(_servicioSel!);
              }
            })),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () async {
            final d = double.tryParse(ctrl.text);
            if (d != null) {
              await Supabase.instance.client.from('sim_tipos_trabajo')
                .update({'factor_complejidad': d}).eq('id', t.id);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Factor guardado'),
                  backgroundColor: AppColors.verde));
              _cargarConfig(_servicioSel!);
            }
          },
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.verde, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.check, color: Colors.white, size: 16))),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _eliminarItem('sim_tipos_trabajo', t.id, () => _cargarConfig(_servicioSel!)),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.rojo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.delete_outline, color: AppColors.rojo, size: 16))),
      ]));
  }

  // ── ITEM RANGO ───────────────────────────────────────
  Widget _itemRango(SimRango r) {
    final precioCtrl = TextEditingController(
      text: r.precio % 1 == 0 ? r.precio.toInt().toString() : r.precio.toString());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${r.desde.toInt()} — ${r.hasta.toInt()}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.azul)),
          if (false)
            Text("", style: const TextStyle(
              fontSize: 11, color: AppColors.textoSecundario)),
        ])),
        SizedBox(width: 90,
          child: TextFormField(
            controller: precioCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              isDense: true, filled: true, fillColor: AppColors.gris,
              prefixText: '\$',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            onFieldSubmitted: (v) async {
              final d = double.tryParse(v);
              if (d != null) await _guardarPrecio('sim_rangos', r.id, d);
            })),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () async {
            final d = double.tryParse(precioCtrl.text);
            if (d != null) {
              await _guardarPrecio('sim_rangos', r.id, d);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Rango guardado'),
                  backgroundColor: AppColors.verde));
            }
          },
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.verde, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.check, color: Colors.white, size: 16))),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _eliminarItem('sim_rangos', r.id, () => _cargarConfig(_servicioSel!)),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.rojo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.delete_outline, color: AppColors.rojo, size: 16))),
      ]));
  }

  // ══════════════════════════════════════════════════
  // OPERACIONES CRUD
  // ══════════════════════════════════════════════════
  final _sb = Supabase.instance.client;

  Future<void> _guardarTarifa(String id, double valor) async {
    await _sb.from('sim_tarifas').update({'valor': valor}).eq('id', id);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Tarifa guardada'),
        backgroundColor: AppColors.verde));
    _cargarConfig(_servicioSel!);
  }

  Future<void> _guardarPrecio(String tabla, String id, double valor) async {
    await _sb.from(tabla).update({'precio': valor}).eq('id', id);
    _cargarConfig(_servicioSel!);
  }

  Future<void> _eliminarItem(String tabla, String id, VoidCallback onExito) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('¿Eliminar este elemento? No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white))),
        ]));
    if (confirm == true) {
      await _sb.from(tabla).delete().eq('id', id);
      onExito();
    }
  }

  Future<void> _editarNombre(String id, String tabla, String nombreActual) async {
    final ctrl = TextEditingController(text: nombreActual);
    await showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Editar nombre'),
      content: TextField(controller: ctrl,
        decoration: const InputDecoration(labelText: 'Nombre')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () async {
            await _sb.from(tabla).update({'nombre': ctrl.text.trim()}).eq('id', id);
            if (mounted) Navigator.pop(context);
            _cargarConfig(_servicioSel!);
          },
          child: const Text('Guardar')),
      ]));
  }

  // ── NUEVOS ITEMS ────────────────────────────────────
  Future<void> _nuevoItem(String tipo) async {
    final nombreCtrl = TextEditingController();
    final valorCtrl = TextEditingController(text: '0');
    final unidadCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _bottomForm('Nueva tarifa', [
        TextField(controller: nombreCtrl,
          decoration: const InputDecoration(labelText: 'Nombre', isDense: true,
            border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: valorCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Valor (\$)', isDense: true,
            border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: unidadCtrl,
          decoration: const InputDecoration(labelText: 'Unidad (\$/m2, \$/min...)',
            isDense: true, border: OutlineInputBorder())),
      ], onGuardar: () async {
        await _sb.from('sim_tarifas').insert({'negocio_id': AuthService.negocioId,
          'servicio_id': _servicioSel!.id,
          'clave': nombreCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
          'nombre': nombreCtrl.text.trim(),
          'valor': double.tryParse(valorCtrl.text) ?? 0,
          'unidad': unidadCtrl.text.trim(),
          'activo': true,
        });
        _cargarConfig(_servicioSel!);
      }));
  }

  Future<void> _nuevoRango() async {
    final desdeCtrl = TextEditingController();
    final hastaCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _bottomForm('Nuevo rango', [
        Row(children: [
          Expanded(child: TextField(controller: desdeCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Indice desde',
              isDense: true, border: OutlineInputBorder()))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: hastaCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Indice hasta',
              isDense: true, border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: precioCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Precio (\$)',
            isDense: true, border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: descCtrl,
          decoration: const InputDecoration(labelText: 'Descripcion (opcional)',
            isDense: true, border: OutlineInputBorder())),
      ], onGuardar: () async {
        await _sb.from('sim_rangos').insert({'negocio_id': AuthService.negocioId,
          'servicio_id': _servicioSel!.id,
          'indice_desde': double.tryParse(desdeCtrl.text) ?? 0,
          'indice_hasta': double.tryParse(hastaCtrl.text) ?? 0,
          'precio': double.tryParse(precioCtrl.text) ?? 0,
          'descripcion': descCtrl.text.trim(),
          'activo': true,
        });
        _cargarConfig(_servicioSel!);
      }));
  }

  Future<void> _nuevoNombre(String tabla, String label) async {
    final ctrl = TextEditingController();
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _bottomForm('Nuevo $label', [
        TextField(controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: label,
            isDense: true, border: const OutlineInputBorder())),
      ], onGuardar: () async {
        await _sb.from(tabla).insert({
          'servicio_id': _servicioSel!.id,
          'nombre': ctrl.text.trim(),
          'activo': true,
        });
        _cargarConfig(_servicioSel!);
      }));
  }

  Future<void> _nuevoTipo() async {
    final nombreCtrl = TextEditingController();
    final factorCtrl = TextEditingController(text: '1.0');
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _bottomForm('Nuevo tipo de trabajo', [
        TextField(controller: nombreCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre',
            isDense: true, border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: factorCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Factor de complejidad (ej: 1.5)',
            helperText: 'Corte simple = 1.0, Relieve 3D = 3.0, Escultura = 6.0',
            isDense: true, border: OutlineInputBorder())),
      ], onGuardar: () async {
        await _sb.from('sim_tipos_trabajo').insert({'negocio_id': AuthService.negocioId,
          'servicio_id': _servicioSel!.id,
          'nombre': nombreCtrl.text.trim(),
          'factor_complejidad': double.tryParse(factorCtrl.text) ?? 1.0,
          'activo': true,
        });
        _cargarConfig(_servicioSel!);
      }));
  }

  Future<void> _nuevoExtra(String tabla, String label) async {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController(text: '0');
    String tipoPrecio = 'fijo';
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) =>
        _bottomForm('Nuevo $label', [
          TextField(controller: nombreCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: label,
              isDense: true, border: const OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: precioCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Precio (\$)',
              isDense: true, border: OutlineInputBorder())),
          const SizedBox(height: 10),
          // Tipo precio
          Wrap(spacing: 6, children: ['fijo','porcentaje','por_pieza'].map((t) =>
            GestureDetector(
              onTap: () => setS(() => tipoPrecio = t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: tipoPrecio == t ? AppColors.azul : AppColors.gris,
                  borderRadius: BorderRadius.circular(20)),
                child: Text(t, style: TextStyle(
                  fontSize: 11,
                  color: tipoPrecio == t ? Colors.white : AppColors.textoSecundario))))).toList()),
        ], onGuardar: () async {
          await _sb.from(tabla).insert({
            'servicio_id': _servicioSel!.id,
            'nombre': nombreCtrl.text.trim(),
            'precio': double.tryParse(precioCtrl.text) ?? 0,
            'tipo_precio': tipoPrecio,
            'activo': true,
          });
          _cargarConfig(_servicioSel!);
        })));
  }

  Future<void> _agregarServicio() async {
    // Solo mostrar info de cómo agregar un nuevo servicio
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Agregar servicio'),
      content: const Text(
        'Para agregar un nuevo tipo de servicio al simulador, '
        'insertar un registro en la tabla sim_servicios en Supabase '
        'con la clave, nombre y emoji del nuevo servicio.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Entendido')),
      ]));
  }

  // ── BOTTOM FORM HELPER ──────────────────────────────
  Widget _bottomForm(String titulo, List<Widget> campos,
      {required Future<void> Function() onGuardar}) =>
    Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16, right: 16, top: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Text(titulo, style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ...campos,
        const SizedBox(height: 16),
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await onGuardar();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.azul,
              padding: const EdgeInsets.symmetric(vertical: 12)),
            child: const Text('Guardar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
      ]));
}
