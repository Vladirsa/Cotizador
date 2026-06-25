// lib/screens/agenda_screen.dart
// HETNA CNC — Agenda Inteligente
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

// ══════════════════════════════════════════════════════
// MODELO EVENTO
// ══════════════════════════════════════════════════════
class AgendaEvento {
  final String id;
  final String tipo;
  final String titulo;
  final String? descripcion;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final bool todoDia;
  final String color;
  final String? cotizacionId;
  final String? pedidoId;
  final String? clienteId;
  final String? clienteNombre;
  final double monto;
  final bool completado;

  AgendaEvento({
    required this.id, required this.tipo, required this.titulo,
    this.descripcion, required this.fechaInicio, this.fechaFin,
    this.todoDia = true, this.color = '#1a3a5c',
    this.cotizacionId, this.pedidoId, this.clienteId,
    this.clienteNombre, this.monto = 0, this.completado = false,
  });

  factory AgendaEvento.fromJson(Map<String, dynamic> j) => AgendaEvento(
    id: j['id'] as String,
    tipo: j['tipo'] as String,
    titulo: j['titulo'] as String,
    descripcion: j['descripcion'] as String?,
    fechaInicio: DateTime.parse(j['fecha_inicio'] as String).toLocal(),
    fechaFin: j['fecha_fin'] != null ? DateTime.parse(j['fecha_fin']).toLocal() : null,
    todoDia: j['todo_el_dia'] as bool? ?? true,
    color: j['color'] as String? ?? '#1a3a5c',
    cotizacionId: j['cotizacion_id'] as String?,
    pedidoId: j['pedido_id'] as String?,
    clienteId: j['cliente_id'] as String?,
    clienteNombre: j['cliente_nombre'] as String?,
    monto: (j['monto'] as num?)?.toDouble() ?? 0,
    completado: j['completado'] as bool? ?? false,
  );

  Color get colorObj {
    try {
      final hex = color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) { return AppColors.azul; }
  }

  String get tipoLabel {
    switch (tipo) {
      case 'entrega_cotizacion': return 'Entrega cotización';
      case 'entrega_pedido':     return 'Entrega pedido';
      case 'cita':               return 'Cita';
      case 'pago_pendiente':     return 'Pago pendiente';
      case 'seguimiento':        return 'Seguimiento';
      case 'produccion':         return 'Producción';
      default:                   return 'Evento';
    }
  }

  String get tipoEmoji {
    switch (tipo) {
      case 'entrega_cotizacion': return '📋';
      case 'entrega_pedido':     return '🚚';
      case 'cita':               return '📅';
      case 'pago_pendiente':     return '💰';
      case 'seguimiento':        return '🔔';
      case 'produccion':         return '🔧';
      default:                   return '📌';
    }
  }

  // Semáforo por días restantes
  Color get semaforo {
    if (completado) return AppColors.verde;
    final dias = fechaInicio.difference(DateTime.now()).inDays;
    if (dias < 0)  return AppColors.rojo;
    if (dias <= 2) return AppColors.ambar;
    return AppColors.verde;
  }

  String get semaforoLabel {
    if (completado) return 'Completado';
    final dias = fechaInicio.difference(DateTime.now()).inDays;
    if (dias < 0)  return 'Vencido (${dias.abs()}d)';
    if (dias == 0) return 'Hoy';
    if (dias == 1) return 'Mañana';
    return 'En $dias días';
  }
}

// ══════════════════════════════════════════════════════
// SERVICIO DE AGENDA
// ══════════════════════════════════════════════════════
class AgendaService {
  static final _sb = Supabase.instance.client;

  static Future<List<AgendaEvento>> getEventos({
    DateTime? desde,
    DateTime? hasta,
    bool soloActivos = true,
  }) async {
    try {
      var query = _sb.from('agenda_eventos').select();
      if (soloActivos) query = query.eq('completado', false);
      if (desde != null) query = query.gte('fecha_inicio', desde.toIso8601String());
      if (hasta != null) query = query.lte('fecha_inicio', hasta.toIso8601String());
      final data = await query.order('fecha_inicio');
      return (data as List).map((j) => AgendaEvento.fromJson(j)).toList();
    } catch (e) {
      print('AgendaService.getEventos error: $e');
      return [];
    }
  }

  static Future<List<AgendaEvento>> getEventosDelDia(DateTime dia) async {
    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fin = inicio.add(const Duration(days: 1));
    return getEventos(desde: inicio, hasta: fin, soloActivos: false);
  }

  static Future<List<AgendaEvento>> getPendientes() async {
    try {
      final data = await _sb
        .from('agenda_eventos')
        .select()
        .eq('completado', false)
        .order('fecha_inicio')
        .limit(50);
      return (data as List).map((j) => AgendaEvento.fromJson(j)).toList();
    } catch (e) { return []; }
  }

  static Future<void> completarEvento(String id) async {
    await _sb.from('agenda_eventos').update({
      'completado': true,
      'completado_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<AgendaEvento?> crearEvento({
    required String tipo,
    required String titulo,
    String? descripcion,
    required DateTime fechaInicio,
    String? clienteNombre,
    String? cotizacionId,
    String? pedidoId,
    double monto = 0,
    String color = '#1a3a5c',
  }) async {
    try {
      final data = await _sb.from('agenda_eventos').insert({
        'tipo': tipo,
        'titulo': titulo,
        'descripcion': descripcion,
        'fecha_inicio': fechaInicio.toIso8601String(),
        'todo_el_dia': true,
        'cliente_nombre': clienteNombre,
        'cotizacion_id': cotizacionId,
        'pedido_id': pedidoId,
        'monto': monto,
        'color': color,
        'completado': false,
      }).select().single();
      return AgendaEvento.fromJson(data);
    } catch (e) {
      print('AgendaService.crearEvento error: $e');
      return null;
    }
  }
}

// ══════════════════════════════════════════════════════
// PANTALLA PRINCIPAL
// ══════════════════════════════════════════════════════
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  DateTime _mesActual = DateTime.now();
  DateTime _diaSeleccionado = DateTime.now();
  List<AgendaEvento> _todosEventos = [];
  List<AgendaEvento> _eventosDia = [];
  List<AgendaEvento> _pendientes = [];
  bool _cargando = true;

  final _fmtFecha = DateFormat('dd/MM/yyyy', 'es_MX');
  final _fmtMes = DateFormat('MMMM yyyy', 'es_MX');
  final _fmt = NumberFormat('\$#,##0', 'es_MX');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final inicio = DateTime(_mesActual.year, _mesActual.month, 1);
    final fin = DateTime(_mesActual.year, _mesActual.month + 1, 0);
    final results = await Future.wait([
      AgendaService.getEventos(desde: inicio, hasta: fin, soloActivos: false),
      AgendaService.getEventosDelDia(_diaSeleccionado),
      AgendaService.getPendientes(),
    ]);
    if (mounted) setState(() {
      _todosEventos = results[0];
      _eventosDia   = results[1];
      _pendientes   = results[2];
      _cargando     = false;
    });
  }

  Future<void> _seleccionarDia(DateTime dia) async {
    setState(() => _diaSeleccionado = dia);
    final eventos = await AgendaService.getEventosDelDia(dia);
    if (mounted) setState(() => _eventosDia = eventos);
  }

  // Eventos del mes agrupados por día
  Map<int, List<AgendaEvento>> get _eventosPorDia {
    final map = <int, List<AgendaEvento>>{};
    for (final e in _todosEventos) {
      final dia = e.fechaInicio.day;
      map.putIfAbsent(dia, () => []).add(e);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Agenda Inteligente',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.azul),
            onPressed: _nuevoEvento),
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
            const Tab(text: '📅 Calendario'),
            Tab(text: '☀️ Hoy (${_eventosDia.where((e) => !e.completado).length})'),
            Tab(text: '⏳ Pendientes (${_pendientes.length})'),
          ]),
      ),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            _tabCalendario(),
            _tabHoy(),
            _tabPendientes(),
          ]),
    );
  }

  // ── TAB 1: CALENDARIO ───────────────────────────────
  Widget _tabCalendario() {
    return Column(children: [
      // Navegación de mes
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.azul),
            onPressed: () {
              setState(() => _mesActual = DateTime(_mesActual.year, _mesActual.month - 1));
              _cargar();
            }),
          GestureDetector(
            onTap: () {
              setState(() {
                _mesActual = DateTime.now();
                _diaSeleccionado = DateTime.now();
              });
              _cargar();
            },
            child: Text(_fmtMes.format(_mesActual).toUpperCase(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.azul))),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.azul),
            onPressed: () {
              setState(() => _mesActual = DateTime(_mesActual.year, _mesActual.month + 1));
              _cargar();
            }),
        ])),

      // Días de la semana
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: ['L','M','X','J','V','S','D'].map((d) =>
          Expanded(child: Center(child: Text(d,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: d == 'D' || d == 'S' ? AppColors.rojo.withOpacity(0.6) : AppColors.textoSecundario))))).toList())),

      // Grid del mes
      Container(
        color: Colors.white,
        child: _buildGrilla()),

      // Eventos del día seleccionado
      Expanded(child: _eventosDelDiaSeleccionado()),
    ]);
  }

  Widget _buildGrilla() {
    final primerDia = DateTime(_mesActual.year, _mesActual.month, 1);
    // Lunes=1, pero queremos Lunes como primer columna
    int offsetInicio = primerDia.weekday - 1; // 0=lunes
    final diasEnMes = DateTime(_mesActual.year, _mesActual.month + 1, 0).day;
    final totalCeldas = offsetInicio + diasEnMes;
    final filas = (totalCeldas / 7).ceil();
    final eventosPorDia = _eventosPorDia;
    final hoy = DateTime.now();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, childAspectRatio: 1.1),
      itemCount: filas * 7,
      itemBuilder: (_, idx) {
        final diaNum = idx - offsetInicio + 1;
        if (diaNum < 1 || diaNum > diasEnMes) return const SizedBox();
        final fecha = DateTime(_mesActual.year, _mesActual.month, diaNum);
        final esHoy = fecha.year == hoy.year && fecha.month == hoy.month && fecha.day == hoy.day;
        final esSel = fecha.year == _diaSeleccionado.year && fecha.month == _diaSeleccionado.month && fecha.day == _diaSeleccionado.day;
        final eventos = eventosPorDia[diaNum] ?? [];
        final tieneEventos = eventos.isNotEmpty;
        final tieneVencidos = eventos.any((e) => !e.completado && e.fechaInicio.isBefore(DateTime.now()));

        return GestureDetector(
          onTap: () => _seleccionarDia(fecha),
          child: Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: esSel ? AppColors.azul : esHoy ? AppColors.azulClaro : Colors.transparent,
              borderRadius: BorderRadius.circular(6)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$diaNum', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: esSel ? Colors.white : esHoy ? AppColors.azul : AppColors.textoPrincipal)),
              if (tieneEventos)
                Container(
                  width: 4, height: 4,
                  decoration: BoxDecoration(
                    color: tieneVencidos
                      ? (esSel ? Colors.white : AppColors.rojo)
                      : (esSel ? Colors.white70 : AppColors.naranja),
                    shape: BoxShape.circle)),
            ])));
      });
  }

  Widget _eventosDelDiaSeleccionado() {
    final esTitulo = _fmtFecha.format(_diaSeleccionado);
    final esHoy = _diaSeleccionado.day == DateTime.now().day &&
      _diaSeleccionado.month == DateTime.now().month &&
      _diaSeleccionado.year == DateTime.now().year;

    return Container(
      color: AppColors.gris,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(esHoy ? 'Hoy — $esTitulo' : esTitulo,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.azul)),
            Text('${_eventosDia.length} evento${_eventosDia.length != 1 ? "s" : ""}',
              style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          ])),
        Expanded(child: _eventosDia.isEmpty
          ? const Center(child: Text('Sin eventos este día',
              style: TextStyle(color: AppColors.textoSecundario, fontSize: 13)))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _eventosDia.map((e) => _cardEvento(e)).toList())),
      ]));
  }

  // ── TAB 2: HOY ──────────────────────────────────────
  Widget _tabHoy() {
    final hoy = DateTime.now();
    final eventosHoy = _pendientes.where((e) {
      final f = e.fechaInicio;
      return f.year == hoy.year && f.month == hoy.month && f.day == hoy.day;
    }).toList();
    final manana = hoy.add(const Duration(days: 1));
    final eventosManana = _pendientes.where((e) {
      final f = e.fechaInicio;
      return f.year == manana.year && f.month == manana.month && f.day == manana.day;
    }).toList();
    final vencidos = _pendientes.where((e) => e.fechaInicio.isBefore(hoy)).toList();
    final proximos = _pendientes.where((e) {
      final dias = e.fechaInicio.difference(hoy).inDays;
      return dias > 1 && dias <= 7;
    }).toList();

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        // Resumen visual
        Row(children: [
          _kpiHoy('Vencidos', '${vencidos.length}', AppColors.rojo, Icons.warning_amber_outlined),
          const SizedBox(width: 8),
          _kpiHoy('Hoy', '${eventosHoy.length}', AppColors.ambar, Icons.today_outlined),
          const SizedBox(width: 8),
          _kpiHoy('Esta semana', '${proximos.length}', AppColors.azul, Icons.date_range_outlined),
        ]),
        const SizedBox(height: 14),

        if (vencidos.isNotEmpty) ...[
          _secLabel('🔴 VENCIDOS', AppColors.rojo),
          ...vencidos.map((e) => _cardEvento(e)),
          const SizedBox(height: 10),
        ],
        if (eventosHoy.isNotEmpty) ...[
          _secLabel('☀️ HOY', AppColors.ambar),
          ...eventosHoy.map((e) => _cardEvento(e)),
          const SizedBox(height: 10),
        ],
        if (eventosManana.isNotEmpty) ...[
          _secLabel('🌅 MAÑANA', AppColors.azul),
          ...eventosManana.map((e) => _cardEvento(e)),
          const SizedBox(height: 10),
        ],
        if (proximos.isNotEmpty) ...[
          _secLabel('📆 PRÓXIMOS 7 DÍAS', AppColors.verde),
          ...proximos.map((e) => _cardEvento(e)),
        ],
        if (vencidos.isEmpty && eventosHoy.isEmpty && eventosManana.isEmpty && proximos.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 40),
            alignment: Alignment.center,
            child: const Column(children: [
              Text('🎉', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text('¡Sin pendientes esta semana!',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.verde)),
            ])),
      ]));
  }

  // ── TAB 3: PENDIENTES ───────────────────────────────
  Widget _tabPendientes() {
    final grupos = <String, List<AgendaEvento>>{
      'entrega_cotizacion': [],
      'entrega_pedido': [],
      'cita': [],
      'pago_pendiente': [],
      'seguimiento': [],
      'produccion': [],
      'personalizado': [],
    };
    for (final e in _pendientes) {
      grupos.putIfAbsent(e.tipo, () => []).add(e);
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        if (_pendientes.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 60),
            alignment: Alignment.center,
            child: const Column(children: [
              Text('✅', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text('Todo al día', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.verde)),
              SizedBox(height: 8),
              Text('No hay eventos pendientes', style: TextStyle(
                color: AppColors.textoSecundario)),
            ]))
        else
          ...grupos.entries
            .where((g) => g.value.isNotEmpty)
            .map((g) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _secLabel(
                '${g.value.first.tipoEmoji} ${g.value.first.tipoLabel.toUpperCase()}',
                g.value.first.colorObj),
              ...g.value.map((e) => _cardEvento(e)),
              const SizedBox(height: 10),
            ])),
      ]));
  }

  // ── CARD EVENTO ─────────────────────────────────────
  Widget _cardEvento(AgendaEvento e) {
    final semaforo = e.semaforo;
    return Dismissible(
      key: Key(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.verde,
          borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 24)),
      confirmDismiss: (_) async {
        await AgendaService.completarEvento(e.id);
        _cargar();
        return true;
      },
      child: GestureDetector(
        onTap: () => _verDetalleEvento(e),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(color: e.completado ? AppColors.grisBorde : semaforo, width: 3),
              top: BorderSide(color: AppColors.grisBorde, width: 0.5),
              right: BorderSide(color: AppColors.grisBorde, width: 0.5),
              bottom: BorderSide(color: AppColors.grisBorde, width: 0.5))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Text(e.tipoEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.titulo, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: e.completado ? AppColors.textoSecundario : AppColors.textoPrincipal,
                  decoration: e.completado ? TextDecoration.lineThrough : null),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                if (e.clienteNombre != null)
                  Text(e.clienteNombre!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: semaforo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(e.semaforoLabel, style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600, color: semaforo))),
                ]),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (e.monto > 0) Text(_fmt.format(e.monto),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.azul)),
                if (!e.completado) GestureDetector(
                  onTap: () async {
                    await AgendaService.completarEvento(e.id);
                    _cargar();
                  },
                  child: Container(
                    width: 28, height: 28, margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: AppColors.verde,
                      borderRadius: BorderRadius.circular(7)),
                    child: const Icon(Icons.check, size: 14, color: Colors.white))),
                if (e.completado) const Icon(Icons.check_circle, size: 18, color: AppColors.verde),
              ]),
            ]))));
  }

  // ── DETALLE EVENTO ──────────────────────────────────
  void _verDetalleEvento(AgendaEvento e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Text(e.tipoEmoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(e.tipoLabel, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: e.semaforo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
              child: Text(e.semaforoLabel, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: e.semaforo))),
          ]),
          const SizedBox(height: 16),
          _detalleRow(Icons.calendar_today_outlined, 'Fecha', _fmtFecha.format(e.fechaInicio)),
          if (e.clienteNombre != null) _detalleRow(Icons.person_outline, 'Cliente', e.clienteNombre!),
          if (e.monto > 0) _detalleRow(Icons.attach_money_outlined, 'Monto', _fmt.format(e.monto)),
          if (e.descripcion != null) _detalleRow(Icons.notes_outlined, 'Notas', e.descripcion!),
          const SizedBox(height: 16),
          if (!e.completado)
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await AgendaService.completarEvento(e.id);
                  _cargar();
                },
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text('Marcar como completado',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verde,
                  padding: const EdgeInsets.symmetric(vertical: 12)))),
        ])));
  }

  Widget _detalleRow(IconData icon, String label, String valor) =>
    Padding(padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.textoSecundario),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
        Expanded(child: Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ]));

  // ── NUEVO EVENTO MANUAL ─────────────────────────────
  void _nuevoEvento() {
    final tituloCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    DateTime fechaSel = DateTime.now().add(const Duration(days: 1));
    String tipoSel = 'personalizado';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) =>
        Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16, right: 16, top: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Nuevo evento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            // Tipo
            Wrap(spacing: 6, runSpacing: 6,
              children: ['entrega_cotizacion','entrega_pedido','cita','pago_pendiente','seguimiento','personalizado']
                .map((t) {
                  final ev = AgendaEvento(id:'', tipo:t, titulo:'', fechaInicio:DateTime.now());
                  final sel = tipoSel == t;
                  return GestureDetector(
                    onTap: () => setS(() => tipoSel = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.azul : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde)),
                      child: Text('${ev.tipoEmoji} ${ev.tipoLabel}',
                        style: TextStyle(fontSize: 11,
                          color: sel ? Colors.white : AppColors.textoSecundario))));
                }).toList()),
            const SizedBox(height: 12),
            TextField(
              controller: tituloCtrl,
              decoration: InputDecoration(
                labelText: 'Título del evento',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true)),
            const SizedBox(height: 10),
            // Fecha
            GestureDetector(
              onTap: () async {
                final fecha = await showDatePicker(
                  context: ctx,
                  initialDate: fechaSel,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)));
                if (fecha != null) setS(() => fechaSel = fecha);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.grisBorde),
                  borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.azul),
                  const SizedBox(width: 8),
                  Text(DateFormat('dd/MM/yyyy').format(fechaSel),
                    style: const TextStyle(fontSize: 13)),
                ]))),
            const SizedBox(height: 10),
            TextField(
              controller: notasCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (tituloCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  await AgendaService.crearEvento(
                    tipo: tipoSel,
                    titulo: tituloCtrl.text.trim(),
                    descripcion: notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
                    fechaInicio: fechaSel);
                  _cargar();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.azul,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text('Crear evento',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
          ]))));
  }

  // ── HELPERS ─────────────────────────────────────────
  Widget _kpiHoy(String label, String valor, Color color, IconData icon) =>
    Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
      ])));

  Widget _secLabel(String texto, Color color) =>
    Padding(padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(texto, style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: color, letterSpacing: 1)));
}
