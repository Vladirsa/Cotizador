import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_service.dart';
import '../models/models.dart';

class CitasScreen extends StatefulWidget {
  const CitasScreen({super.key});
  @override
  State<CitasScreen> createState() => _CitasScreenState();
}

class _CitasScreenState extends State<CitasScreen> {
  List<Map<String, dynamic>> _citas = [];
  bool _cargando = true;
  String _filtro = 'Programada';
  final _fmtFecha = DateFormat('EEEE dd MMM', 'es_MX');
  final _fmtHora  = DateFormat('HH:mm');

  final _estados = ['Programada', 'Confirmada', 'Completada', 'Cancelada', 'Todas'];

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await SupabaseService.getCitas();
      if (mounted) setState(() { _citas = res; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  List<Map<String, dynamic>> get _filtradas => _filtro == 'Todas'
    ? _citas
    : _citas.where((c) => c['estado'] == _filtro).toList();

  Future<void> _nuevaCita() async {
    final result = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => const _FormCita()));
    if (result == true) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Agenda de citas',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textoPrincipal)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.azul),
            onPressed: _nuevaCita),
        ]),
      body: Column(children: [
        // Filtros
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _estados.map((e) {
              final activo = _filtro == e;
              final count = e == 'Todas' ? _citas.length
                : _citas.where((c) => c['estado'] == e).length;
              final color = _colorEstado(e);
              return GestureDetector(
                onTap: () => setState(() => _filtro = e),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: activo ? color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: activo ? color : AppColors.grisBorde)),
                  child: Text('$e ($count)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: activo ? Colors.white : AppColors.textoSecundario))));
            }).toList()))),

        // Lista
        Expanded(child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _filtradas.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.event_busy_outlined, size: 48, color: AppColors.grisBorde),
                const SizedBox(height: 12),
                Text('Sin citas ${_filtro == "Todas" ? "" : _filtro.toLowerCase()}s',
                  style: const TextStyle(fontSize: 14, color: AppColors.textoSecundario)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _nuevaCita,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Agendar cita', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _filtradas.length,
                itemBuilder: (_, i) {
                  final cita = _filtradas[i];
                  final fecha = DateTime.tryParse(cita['fecha_hora'] as String? ?? '');
                  final estado = cita['estado'] as String? ?? 'Programada';
                  final color = _colorEstado(estado);
                  final hoy = DateTime.now();
                  final esHoy = fecha != null &&
                    fecha.year == hoy.year && fecha.month == hoy.month && fecha.day == hoy.day;
                  final pasada = fecha != null && fecha.isBefore(hoy) && estado == 'Programada';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pasada ? AppColors.rojo.withOpacity(0.3) : color.withOpacity(0.2),
                        width: esHoy ? 2 : 0.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                    child: Column(children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.07),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8)),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(fecha != null ? '${fecha.day}' : '--',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                              Text(fecha != null ? DateFormat('MMM', 'es_MX').format(fecha).toUpperCase() : '',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                            ])),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(cita['titulo'] as String? ?? '',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            if (cita['clientes'] != null)
                              Text((cita['clientes'] as Map<String, dynamic>?)?['nombre'] as String? ?? '',
                                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                            if (fecha != null)
                              Text(
                                '${esHoy ? "🔵 HOY — " : ""}'
                                '${_fmtFecha.format(fecha).capitalize()} · ${_fmtHora.format(fecha)}'
                                '${cita['duracion_min'] != null ? " (${cita['duracion_min']} min)" : ""}',
                                style: TextStyle(fontSize: 11,
                                  color: esHoy ? AppColors.azul : AppColors.textoSecundario,
                                  fontWeight: esHoy ? FontWeight.w600 : FontWeight.normal)),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20)),
                            child: Text(estado,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color))),
                        ])),
                      // Acciones
                      if (estado == 'Programada' || estado == 'Confirmada')
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                          child: Row(children: [
                            // Notificar por WA
                            if ((cita['clientes'] as Map?)?['whatsapp'] != null)
                              Expanded(child: ElevatedButton.icon(
                                onPressed: () => _notificarWA(cita),
                                icon: const Icon(Icons.chat, size: 14, color: Colors.white),
                                label: const Text('Notificar WA', style: TextStyle(fontSize: 11, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  padding: const EdgeInsets.symmetric(vertical: 8)))),
                            if ((cita['clientes'] as Map?)?['whatsapp'] != null)
                              const SizedBox(width: 6),
                            // Confirmar
                            if (estado == 'Programada')
                              Expanded(child: OutlinedButton.icon(
                                onPressed: () => _cambiarEstado(cita['id'] as String, 'Confirmada'),
                                icon: const Icon(Icons.check, size: 14, color: AppColors.verde),
                                label: const Text('Confirmar', style: TextStyle(fontSize: 11, color: AppColors.verde)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.verde),
                                  padding: const EdgeInsets.symmetric(vertical: 8)))),
                            const SizedBox(width: 6),
                            // Menú más opciones
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textoSecundario),
                              onSelected: (v) async {
                                if (v == 'completar') await _cambiarEstado(cita['id'] as String, 'Completada');
                                if (v == 'cancelar') await _cambiarEstado(cita['id'] as String, 'Cancelada');
                                if (v == 'editar') {
                                  final ok = await Navigator.push<bool>(context,
                                    MaterialPageRoute(builder: (_) => _FormCita(cita: cita)));
                                  if (ok == true) await _cargar();
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'editar',
                                  child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Editar')])),
                                const PopupMenuItem(value: 'completar',
                                  child: Row(children: [Icon(Icons.task_alt_outlined, size: 16, color: AppColors.verde), SizedBox(width: 8), Text('Marcar completada')])),
                                const PopupMenuItem(value: 'cancelar',
                                  child: Row(children: [Icon(Icons.cancel_outlined, size: 16, color: AppColors.rojo), SizedBox(width: 8), Text('Cancelar', style: TextStyle(color: AppColors.rojo))])),
                              ]),
                          ])),
                    ]));
                })),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevaCita,
        backgroundColor: AppColors.azul,
        child: const Icon(Icons.event_note_outlined, color: Colors.white)));
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Programada': return AppColors.azul;
      case 'Confirmada': return AppColors.verde;
      case 'Completada': return const Color(0xFF7c3aed);
      case 'Cancelada':  return AppColors.rojo;
      default:           return AppColors.textoSecundario;
    }
  }

  Future<void> _cambiarEstado(String id, String estado) async {
    await SupabaseService.actualizarCita(id, {'estado': estado});
    await _cargar();
  }

  Future<void> _notificarWA(Map<String, dynamic> cita) async {
    final wa = (cita['clientes'] as Map?)?['whatsapp'] as String? ?? '';
    if (wa.isEmpty) return;
    final nombre = (cita['clientes'] as Map?)?['nombre'] as String? ?? 'Cliente';
    final fecha = DateTime.tryParse(cita['fecha_hora'] as String? ?? '');
    final lugar = cita['lugar'] as String? ?? 'Taller HETNA CNC';
    final titulo = cita['titulo'] as String? ?? '';
    final msg = 'Hola *$nombre* 📅 Te confirmamos tu cita en *HETNA CNC*:\n\n'
      '📋 *$titulo*\n'
      '📅 *${fecha != null ? DateFormat("EEEE dd 'de' MMMM 'a las' HH:mm", 'es_MX').format(fecha) : ""}*\n'
      '📍 *$lugar*\n\n'
      'Si necesitas reprogramar avísanos con anticipación. ¡Te esperamos! 😊';
    await WhatsAppService.abrirChat(numero: wa, mensaje: msg);
    await SupabaseService.actualizarCita(cita['id'] as String, {'wa_enviado': true});
    await _cargar();
  }
}

extension StringExt on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

// ══════════════════════════════════════════════════
// FORMULARIO DE CITA
// ══════════════════════════════════════════════════
class _FormCita extends StatefulWidget {
  final Map<String, dynamic>? cita;
  const _FormCita({this.cita});
  @override
  State<_FormCita> createState() => _FormCitaState();
}

class _FormCitaState extends State<_FormCita> {
  final _tituloCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _lugarCtrl  = TextEditingController();
  final _durCtrl    = TextEditingController();
  DateTime _fecha   = DateTime.now().add(const Duration(days: 1));
  String? _clienteId;
  String _clienteNombre = '';
  bool _guardando = false;
  final _fmt = DateFormat("EEEE dd 'de' MMMM, HH:mm", 'es_MX');

  @override
  void initState() {
    super.initState();
    final c = widget.cita;
    if (c != null) {
      _tituloCtrl.text = c['titulo'] ?? '';
      _descCtrl.text   = c['descripcion'] ?? '';
      _lugarCtrl.text  = c['lugar'] ?? 'Taller HETNA CNC';
      _durCtrl.text    = c['duracion_min']?.toString() ?? '60';
      if (c['fecha_hora'] != null) {
        _fecha = DateTime.tryParse(c['fecha_hora'] as String) ?? _fecha;
      }
      if (c['clientes'] != null) {
        _clienteId     = c['cliente_id'] as String?;
        _clienteNombre = (c['clientes'] as Map<String, dynamic>?)?['nombre'] as String? ?? '';
      }
    } else {
      _lugarCtrl.text = 'Taller HETNA CNC';
      _durCtrl.text   = '60';
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose(); _descCtrl.dispose();
    _lugarCtrl.dispose(); _durCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarCliente() async {
    final clientes = await SupabaseService.getClientes();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(children: [
          const Padding(padding: EdgeInsets.all(14),
            child: Text('Seleccionar cliente',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          Expanded(child: ListView.builder(
            itemCount: clientes.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(clientes[i].nombre),
              subtitle: Text(clientes[i].empresa ?? ''),
              onTap: () {
                setState(() { _clienteId = clientes[i].id; _clienteNombre = clientes[i].nombre; });
                Navigator.pop(context);
              }))),
        ])));
  }

  Future<void> _seleccionarFecha() async {
    final f = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)));
    if (f == null || !mounted) return;
    final t = await showTimePicker(
      context: context, initialTime: TimeOfDay.fromDateTime(_fecha));
    if (!mounted) return;
    setState(() {
      _fecha = t != null
        ? DateTime(f.year, f.month, f.day, t.hour, t.minute)
        : f;
    });
  }

  Future<void> _guardar() async {
    if (_tituloCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es obligatorio')));
      return;
    }
    setState(() => _guardando = true);
    try {
      final datos = {
        'titulo'      : _tituloCtrl.text.trim(),
        'descripcion' : _descCtrl.text.trim(),
        'lugar'       : _lugarCtrl.text.trim(),
        'duracion_min': int.tryParse(_durCtrl.text.trim()) ?? 60,
        'fecha_hora'  : _fecha.toIso8601String(),
        'cliente_id'  : _clienteId,
        'recordatorio': true,
        'estado'      : 'Programada',
      };
      if (widget.cita != null) {
        await SupabaseService.actualizarCita(widget.cita!['id'] as String, datos);
      } else {
        await SupabaseService.crearCita(datos);
        // Crear alerta de recordatorio 24h antes
        await SupabaseService.crearAlerta({
          'tipo'            : 'recordatorio_cita',
          'titulo'          : 'Cita mañana: ${_tituloCtrl.text.trim()}',
          'cliente_id'      : _clienteId,
          'fecha_programada': _fecha.subtract(const Duration(hours: 24)).toIso8601String(),
          'completada'      : false,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    }
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(widget.cita == null ? 'Nueva cita' : 'Editar cita',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textoPrincipal)),
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: Text(_guardando ? 'Guardando...' : 'Guardar',
              style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700))),
        ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Título
        TextField(
          controller: _tituloCtrl,
          decoration: InputDecoration(
            labelText: 'Motivo de la cita *',
            hintText: 'Ej: Ver muestras de tablas de cocina',
            prefixIcon: const Icon(Icons.event_note_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          textCapitalization: TextCapitalization.sentences),
        const SizedBox(height: 12),

        // Cliente
        GestureDetector(
          onTap: _seleccionarCliente,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gris,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.grisBorde)),
            child: Row(children: [
              const Icon(Icons.person_outline, size: 18, color: AppColors.textoSecundario),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _clienteNombre.isEmpty ? 'Seleccionar cliente (opcional)' : _clienteNombre,
                style: TextStyle(fontSize: 13,
                  color: _clienteNombre.isEmpty ? AppColors.textoSecundario : AppColors.textoPrincipal))),
              const Icon(Icons.chevron_right, size: 16, color: AppColors.textoSecundario),
            ]))),
        const SizedBox(height: 12),

        // Fecha y hora
        GestureDetector(
          onTap: _seleccionarFecha,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.azulClaro,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.azul.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.azul),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _fmt.format(_fecha).capitalize(),
                style: const TextStyle(fontSize: 13, color: AppColors.azul, fontWeight: FontWeight.w600))),
              const Text('Cambiar', style: TextStyle(fontSize: 11, color: AppColors.azul)),
            ]))),
        const SizedBox(height: 12),

        // Lugar y duración
        Row(children: [
          Expanded(child: TextField(
            controller: _lugarCtrl,
            decoration: InputDecoration(
              labelText: 'Lugar',
              prefixIcon: const Icon(Icons.place_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
          const SizedBox(width: 10),
          SizedBox(width: 100, child: TextField(
            controller: _durCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Duración',
              suffixText: 'min',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
        ]),
        const SizedBox(height: 12),

        // Notas
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Notas (opcional)',
            hintText: 'Detalles de la cita...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          textCapitalization: TextCapitalization.sentences),
        const SizedBox(height: 8),

        // Info recordatorio
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.verde.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.verde.withOpacity(0.2))),
          child: const Row(children: [
            Icon(Icons.notifications_active_outlined, size: 16, color: AppColors.verde),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Se creará una alerta de recordatorio 24 horas antes de la cita',
              style: TextStyle(fontSize: 11, color: AppColors.verde))),
          ])),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.azul,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(_guardando ? 'Guardando...' : 'Agendar cita',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ]));
  }
}
