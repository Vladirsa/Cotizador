import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_service.dart';

class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key});
  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  List<Alerta> _alertas = [];
  bool _cargando = true;
  String _filtro = 'Todos';

  // ── Tipos de alerta con íconos y colores ──
  static const _tipos = {
    'todos':                    {'label': 'Todos',              'icon': Icons.notifications_outlined,   'color': AppColors.azul},
    // Seguimiento cotizaciones
    'seguimiento_dia3':         {'label': 'Día 3',              'icon': Icons.schedule_outlined,         'color': AppColors.ambar},
    'seguimiento_dia5':         {'label': 'Día 5',              'icon': Icons.warning_amber_outlined,    'color': AppColors.ambar},
    'seguimiento_dia7':         {'label': 'Día 7 🔴',           'icon': Icons.priority_high_outlined,    'color': AppColors.rojo},
    'post_entrega':             {'label': 'Post entrega',       'icon': Icons.thumb_up_outlined,         'color': AppColors.verde},
    // Pagos
    'pago_anticipo_pendiente':  {'label': '💰 Anticipo',        'icon': Icons.payments_outlined,         'color': AppColors.rojo},
    'pago_final_pendiente':     {'label': '💰 Pago final',      'icon': Icons.price_check_outlined,      'color': AppColors.rojo},
    // Producción
    'produccion_sin_avance':    {'label': '🔧 Producción',      'icon': Icons.construction_outlined,     'color': AppColors.ambar},
    'qc_pendiente':             {'label': '✅ Control calidad',  'icon': Icons.fact_check_outlined,       'color': AppColors.ambar},
    // Clientes
    'cliente_interesado':       {'label': 'Interesado',         'icon': Icons.star_outline,              'color': const Color(0xFF7c3aed)},
    'recordatorio_cita':        {'label': 'Cita',               'icon': Icons.event_outlined,            'color': AppColors.azul},
    'mensaje_wa':               {'label': 'Mensaje WA',         'icon': Icons.chat_outlined,             'color': const Color(0xFF25D366)},
    'nuevo_contacto_wa':        {'label': 'Nuevo contacto',     'icon': Icons.person_add_outlined,       'color': AppColors.verde},
  };

  List<Alerta> get _filtradas {
    if (_filtro == 'Todos') return _alertas;
    return _alertas.where((a) => a.tipo == _filtro).toList();
  }

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final alertas = await SupabaseService.getAlertasPendientes();
      if (mounted) setState(() { _alertas = alertas; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ── Nueva alerta manual ──
  Future<void> _nuevaAlerta() async {
    final tituloCtrl = TextEditingController();
    final notasCtrl  = TextEditingController();
    String tipo = 'recordatorio_cita';
    DateTime fechaSeleccionada = DateTime.now().add(const Duration(days: 1));
    String? clienteId;
    String clienteNombre = '';

    final tiposNuevo = {
      'recordatorio_cita'   : 'Recordatorio de cita',
      'cliente_interesado'  : 'Cliente interesado en producto',
      'seguimiento_dia3'    : 'Seguimiento cotización',
    };

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) =>
        AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
                child: Row(children: [
                  const Expanded(child: Text('Nueva alerta / recordatorio',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx)),
                ])),
              // Formulario
              Expanded(child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Tipo
                  const Text('Tipo de alerta',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...tiposNuevo.entries.map((e) {
                    final info = _tipos[e.key]!;
                    final sel = tipo == e.key;
                    final color = info['color'] as Color;
                    return GestureDetector(
                      onTap: () => setS(() => tipo = e.key),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: sel ? color.withOpacity(0.08) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel ? color : AppColors.grisBorde,
                            width: sel ? 1.5 : 0.5)),
                        child: Row(children: [
                          Icon(info['icon'] as IconData, size: 18, color: sel ? color : AppColors.textoSecundario),
                          const SizedBox(width: 10),
                          Text(e.value,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: sel ? color : AppColors.textoPrincipal)),
                        ])));
                  }),
                  const SizedBox(height: 14),
                  // Título
                  TextField(
                    controller: tituloCtrl,
                    decoration: InputDecoration(
                      labelText: 'Título / descripción *',
                      hintText: 'Ej: Llamar a Juan sobre la tabla de cocina',
                      prefixIcon: const Icon(Icons.title_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    textCapitalization: TextCapitalization.sentences),
                  const SizedBox(height: 12),
                  // Cliente (opcional)
                  GestureDetector(
                    onTap: () async {
                      final clientes = await SupabaseService.getClientes();
                      if (!mounted) return;
                      final sel = await showModalBottomSheet<Cliente>(
                        context: ctx,
                        isScrollControlled: true,
                        builder: (_) => Container(
                          height: MediaQuery.of(ctx).size.height * 0.65,
                          color: Colors.white,
                          child: Column(children: [
                            const Padding(padding: EdgeInsets.all(14),
                              child: Text('Seleccionar cliente',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                            Expanded(child: ListView.builder(
                              itemCount: clientes.length,
                              itemBuilder: (_, i) => ListTile(
                                title: Text(clientes[i].nombre),
                                subtitle: Text(clientes[i].empresa ?? ''),
                                onTap: () => Navigator.pop(_, clientes[i])))),
                          ])));
                      if (sel != null) {
                        setS(() {
                          clienteId = sel.id;
                          clienteNombre = sel.nombre;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.gris,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.grisBorde)),
                      child: Row(children: [
                        const Icon(Icons.person_outline, size: 18, color: AppColors.textoSecundario),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          clienteNombre.isEmpty ? 'Vincular cliente (opcional)' : clienteNombre,
                          style: TextStyle(fontSize: 13,
                            color: clienteNombre.isEmpty ? AppColors.textoSecundario : AppColors.textoPrincipal))),
                        const Icon(Icons.chevron_right, size: 16, color: AppColors.textoSecundario),
                      ])));
                  }),
                  const SizedBox(height: 12),
                  // Fecha
                  GestureDetector(
                    onTap: () async {
                      final f = await showDatePicker(
                        context: ctx,
                        initialDate: fechaSeleccionada,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (f != null) {
                        final t = await showTimePicker(
                          context: ctx, initialTime: TimeOfDay.fromDateTime(fechaSeleccionada));
                        setS(() => fechaSeleccionada = t != null
                          ? DateTime(f.year, f.month, f.day, t.hour, t.minute)
                          : f);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.gris,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.grisBorde)),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.azul),
                        const SizedBox(width: 10),
                        Text(DateFormat('dd/MM/yyyy HH:mm').format(fechaSeleccionada),
                          style: const TextStyle(fontSize: 13, color: AppColors.azul, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        const Icon(Icons.edit_calendar_outlined, size: 14, color: AppColors.textoSecundario),
                      ]))),
                  const SizedBox(height: 12),
                  // Notas
                  TextField(
                    controller: notasCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Notas (opcional)',
                      hintText: 'Detalles adicionales...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    textCapitalization: TextCapitalization.sentences),
                ])),
              // Botón guardar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
                child: SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final titulo = tituloCtrl.text.trim();
                      if (titulo.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Escribe el título de la alerta')));
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        await SupabaseService.crearAlerta({
                          'tipo'              : tipo,
                          'titulo'            : titulo,
                          'notas'             : notasCtrl.text.trim(),
                          'cliente_id'        : clienteId,
                          'fecha_programada'  : fechaSeleccionada.toIso8601String(),
                          'completada'        : false,
                        });
                        await _cargar();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('✅ Alerta creada'),
                          backgroundColor: AppColors.verde));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.rojo));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.azul,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Crear alerta',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))),
            ])))));
  }

  @override
  Widget build(BuildContext context) {
    final tiposConCount = _tipos.entries.map((e) {
      final key = e.key;
      final count = key == 'todos'
        ? _alertas.length
        : _alertas.where((a) => a.tipo == key).length;
      return {'key': key, 'label': e.value['label'], 'count': count,
        'icon': e.value['icon'], 'color': e.value['color']};
    }).where((e) => e['key'] == 'todos' || (e['count'] as int) > 0).toList();

    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(children: [
          const Text('Alertas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textoPrincipal)),
          if (_alertas.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.rojo, borderRadius: BorderRadius.circular(20)),
              child: Text('${_alertas.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          ],
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined, color: AppColors.azul), onPressed: _cargar),
          IconButton(
            icon: const Icon(Icons.add_alert_outlined, color: AppColors.azul),
            tooltip: 'Nueva alerta',
            onPressed: _nuevaAlerta),
        ]),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            // ── Filtros horizontales ──
            if (tiposConCount.length > 1)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: tiposConCount.map((t) {
                    final key = t['key'] as String;
                    final color = t['color'] as Color;
                    final count = t['count'] as int;
                    final activo = _filtro == key;
                    return GestureDetector(
                      onTap: () => setState(() => _filtro = key),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: activo ? color : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: activo ? color : AppColors.grisBorde)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(t['icon'] as IconData, size: 13,
                            color: activo ? Colors.white : color),
                          const SizedBox(width: 5),
                          Text('${t['label']} ($count)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: activo ? Colors.white : AppColors.textoSecundario)),
                        ])));
                  }).toList()))),

            // ── Lista de alertas ──
            Expanded(child: _filtradas.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.grisBorde),
                  const SizedBox(height: 12),
                  const Text('Sin alertas pendientes', style: TextStyle(fontSize: 14, color: AppColors.textoSecundario)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _nuevaAlerta,
                    icon: const Icon(Icons.add_alert_outlined, color: Colors.white),
                    label: const Text('Crear recordatorio', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtradas.length,
                  itemBuilder: (_, i) => _TarjetaAlerta(
                    alerta: _filtradas[i],
                    tipos: _tipos,
                    onCompletada: () async {
                      await _cargar();
                    }))),
          ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevaAlerta,
        backgroundColor: AppColors.azul,
        child: const Icon(Icons.add_alert_outlined, color: Colors.white)),
    );
  }
}

// ══════════════════════════════════════════════════
// TARJETA DE ALERTA
// ══════════════════════════════════════════════════
class _TarjetaAlerta extends StatefulWidget {
  final Alerta alerta;
  final Map<String, Map<String, dynamic>> tipos;
  final VoidCallback onCompletada;
  const _TarjetaAlerta({required this.alerta, required this.tipos, required this.onCompletada});
  @override
  State<_TarjetaAlerta> createState() => _TarjetaAlertaState();
}

class _TarjetaAlertaState extends State<_TarjetaAlerta> {
  bool _enviando = false;
  late String _mensaje;

  @override
  void initState() {
    super.initState();
    _mensaje = _buildMensaje();
  }

  String _buildMensaje() {
    final a = widget.alerta;
    final nombre = a.clienteNombre ?? 'Cliente';
    final folio  = a.cotizacionFolio ?? '';
    switch (a.tipo) {
      case 'seguimiento_dia3':
        return 'Hola *$nombre* 👋 Te contactamos de *HETNA CNC*. ¿Tuviste oportunidad de revisar la cotización $folio? Con gusto resolvemos tus dudas. 😊';
      case 'seguimiento_dia5':
        return 'Hola *$nombre*, somos *HETNA CNC*. La cotización $folio sigue disponible. ¿Te interesa continuar? Estamos para servirte. ✅';
      case 'seguimiento_dia7':
        return 'Hola *$nombre* 🔔 Último recordatorio sobre la cotización $folio. La oferta vence pronto. ¿Podemos ayudarte? — *HETNA CNC*';
      case 'post_entrega':
        return 'Hola *$nombre* ✅ Esperamos que estés disfrutando tu pedido de *HETNA CNC*. Tu opinión es muy importante para nosotros. ¡Gracias!';
      case 'cliente_interesado':
        return 'Hola *$nombre* 👋 Vi que te interesa alguno de nuestros productos. ¿Te puedo ayudar a cotizar? — *HETNA CNC*';
      case 'recordatorio_cita':
        return 'Hola *$nombre* 📅 Te recuerdo nuestra cita programada. ¿Todo bien para la reunión? — *HETNA CNC*';
      case 'nuevo_contacto_wa':
        return 'Hola *$nombre* 👋 Gracias por contactar a *HETNA CNC*. ¿En qué podemos ayudarte?';
      case 'pago_anticipo_pendiente':
        return 'Hola *$nombre* 👋 Te recordamos que el anticipo del 50% de tu pedido *$folio* está pendiente. Para iniciar la producción necesitamos confirmarlo. ¿Podemos ayudarte? — *HETNA CNC*';
      case 'pago_final_pendiente':
        return 'Hola *$nombre* ✅ Tu pedido *$folio* está listo. Para proceder con la entrega necesitamos el pago del saldo restante. ¿Cuándo podemos coordinarlo? — *HETNA CNC*';
      case 'produccion_sin_avance':
        return 'Hola *$nombre* 🔧 Te informamos que tu pedido *$folio* está en proceso de producción. Te notificaremos cuando esté listo para revisión. — *HETNA CNC*';
      case 'qc_pendiente':
        return 'Nota interna: Revisar control de calidad del pedido *$folio* antes de notificar al cliente.';
      default:
        return 'Hola *$nombre*, somos *HETNA CNC*. ¿En qué podemos ayudarte? 😊';
    }
  }

  bool get _tieneWA => (widget.alerta.clienteWhatsapp ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final a = widget.alerta;
    final info = widget.tipos[a.tipo] ?? widget.tipos['seguimiento_dia3']!;
    final color = info['color'] as Color;
    final fmt = DateFormat('dd/MM/yy HH:mm');

    // Si tiene fecha programada y ya venció, resaltar
    final vencida = a.fechaProgramada != null && a.fechaProgramada!.isBefore(DateTime.now());

    return Dismissible(
      key: Key(a.id ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.verde, borderRadius: BorderRadius.circular(12)),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
          SizedBox(height: 4),
          Text('Completada', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ])),
      confirmDismiss: (_) async {
        await SupabaseService.marcarAlertaCompletada(a.id!);
        widget.onCompletada();
        return true;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: vencida ? AppColors.rojo.withOpacity(0.3) : AppColors.grisBorde,
            width: vencida ? 1.5 : 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(children: [
          // Header de la tarjeta
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.15)))),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(info['icon'] as IconData, size: 18, color: color)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.titulo ?? (info['label'] as String),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                if (a.clienteNombre != null)
                  Text(a.clienteNombre!,
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (a.fechaProgramada != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: vencida ? AppColors.rojo.withOpacity(0.1) : AppColors.azulClaro,
                      borderRadius: BorderRadius.circular(6)),
                    child: Text(fmt.format(a.fechaProgramada!),
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                        color: vencida ? AppColors.rojo : AppColors.azul))),
                if (vencida)
                  const Text('VENCIDA', style: TextStyle(fontSize: 9, color: AppColors.rojo, fontWeight: FontWeight.w700)),
              ]),
            ])),
          // Mensaje WA preview
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.gris,
                borderRadius: BorderRadius.circular(8)),
              child: Text(_mensaje,
                style: const TextStyle(fontSize: 11, height: 1.5, color: AppColors.textoSecundario),
                maxLines: 3, overflow: TextOverflow.ellipsis))),
          // Acciones
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: Row(children: [
              // Editar mensaje
              OutlinedButton.icon(
                onPressed: _editarMensaje,
                icon: Icon(Icons.edit_outlined, size: 14, color: color),
                label: Text('Editar', style: TextStyle(fontSize: 11, color: color)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6))),
              const SizedBox(width: 6),
              // Enviar WA
              if (_tieneWA) Expanded(child: ElevatedButton.icon(
                onPressed: _enviando ? null : _enviarWA,
                icon: _enviando
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.chat, size: 14, color: Colors.white),
                label: const Text('Enviar WA', style: TextStyle(fontSize: 11, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 7)))),
              if (!_tieneWA) Expanded(child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(8)),
                child: const Text('Sin número WA', style: TextStyle(fontSize: 10, color: AppColors.ambar), textAlign: TextAlign.center))),
              const SizedBox(width: 6),
              // Completar
              ElevatedButton(
                onPressed: () async {
                  await SupabaseService.marcarAlertaCompletada(a.id!);
                  widget.onCompletada();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.azul,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7)),
                child: const Icon(Icons.check, size: 16, color: Colors.white)),
            ])),
          // Tip: deslizar
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Icon(Icons.swipe_left_outlined, size: 11, color: AppColors.grisBorde),
              SizedBox(width: 4),
              Text('Desliza ← para marcar completada',
                style: TextStyle(fontSize: 9, color: AppColors.grisBorde)),
            ])),
        ])));
  }

  void _editarMensaje() {
    final ctrl = TextEditingController(text: _mensaje);
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        padding: EdgeInsets.only(left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Editar mensaje WA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ]),
          const SizedBox(height: 10),
          Expanded(child: TextField(
            controller: ctrl, maxLines: null, expands: true,
            decoration: InputDecoration(filled: true, fillColor: AppColors.gris,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
            style: const TextStyle(fontSize: 13))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () { setState(() => _mensaje = ctrl.text); Navigator.pop(context); },
              child: const Text('Guardar'))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              onPressed: () {
                setState(() => _mensaje = ctrl.text);
                Navigator.pop(context);
                _enviarWA();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
              icon: const Icon(Icons.chat, size: 16, color: Colors.white),
              label: const Text('Enviar WA', style: TextStyle(color: Colors.white)))),
          ]),
        ])));
  }

  Future<void> _enviarWA() async {
    if (!_tieneWA) return;
    setState(() => _enviando = true);
    try {
      await WhatsAppService.abrirChat(numero: widget.alerta.clienteWhatsapp!, mensaje: _mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}
