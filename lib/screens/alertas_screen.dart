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
  String _filtro = 'todos';

  static const Map<String, Map<String, dynamic>> _tipos = {
    'todos':                   {'label': 'Todos',             'color': Color(0xFF1a3a5c)},
    'seguimiento_dia3':        {'label': 'Día 3',             'color': Color(0xFFef9f27)},
    'seguimiento_dia5':        {'label': 'Día 5',             'color': Color(0xFFef9f27)},
    'seguimiento_dia7':        {'label': 'Día 7 🔴',          'color': Color(0xFFe24b4a)},
    'post_entrega':            {'label': 'Post entrega',      'color': Color(0xFF1d9e75)},
    'pago_anticipo_pendiente': {'label': '💰 Anticipo',       'color': Color(0xFFe24b4a)},
    'pago_final_pendiente':    {'label': '💰 Pago final',     'color': Color(0xFFe24b4a)},
    'produccion_sin_avance':   {'label': '🔧 Producción',     'color': Color(0xFFef9f27)},
    'qc_pendiente':            {'label': '✅ Calidad',         'color': Color(0xFFef9f27)},
    'cliente_interesado':      {'label': 'Interesado',        'color': Color(0xFF7c3aed)},
    'recordatorio_cita':       {'label': 'Cita',              'color': Color(0xFF1a3a5c)},
    'nuevo_contacto_wa':       {'label': 'Nuevo contacto',    'color': Color(0xFF1d9e75)},
  };

  List<Alerta> get _filtradas => _filtro == 'todos'
    ? _alertas
    : _alertas.where((a) => a.tipo == _filtro).toList();

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      // También generar alertas automáticas
      try { await SupabaseService.generarAlertasAutomaticas(); } catch (_) {}
      final alertas = await SupabaseService.getAlertasPendientes();
      if (mounted) setState(() { _alertas = alertas; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _nuevaAlerta() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _NuevaAlertaScreen(onGuardada: _cargar)));
  }

  @override
  Widget build(BuildContext context) {
    final tiposActivos = _tipos.entries.where((e) {
      if (e.key == 'todos') return true;
      return _alertas.any((a) => a.tipo == e.key);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(children: [
          const Text('Alertas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textoPrincipal)),
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
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: AppColors.azul),
            onPressed: _cargar),
          IconButton(
            icon: const Icon(Icons.add_alert_outlined, color: AppColors.azul),
            tooltip: 'Nueva alerta',
            onPressed: _nuevaAlerta),
        ]),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            // ── Filtros ──
            if (tiposActivos.length > 1)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: tiposActivos.map((e) {
                    final color = e.value['color'] as Color;
                    final label = e.value['label'] as String;
                    final count = e.key == 'todos'
                      ? _alertas.length
                      : _alertas.where((a) => a.tipo == e.key).length;
                    final activo = _filtro == e.key;
                    return GestureDetector(
                      onTap: () => setState(() => _filtro = e.key),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: activo ? color : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: activo ? color : AppColors.grisBorde)),
                        child: Text('$label ($count)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: activo ? Colors.white : AppColors.textoSecundario))));
                  }).toList()))),

            // ── Lista ──
            Expanded(child: _filtradas.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.grisBorde),
                  const SizedBox(height: 12),
                  const Text('Sin alertas pendientes',
                    style: TextStyle(fontSize: 14, color: AppColors.textoSecundario)),
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
                    onCompletada: _cargar))),
          ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevaAlerta,
        backgroundColor: AppColors.azul,
        child: const Icon(Icons.add_alert_outlined, color: Colors.white)));
  }
}

// ══════════════════════════════════════════════════
// PANTALLA NUEVA ALERTA — pantalla separada para evitar
// problemas de scope con StatefulBuilder anidado
// ══════════════════════════════════════════════════
class _NuevaAlertaScreen extends StatefulWidget {
  final VoidCallback onGuardada;
  const _NuevaAlertaScreen({required this.onGuardada});
  @override
  State<_NuevaAlertaScreen> createState() => _NuevaAlertaScreenState();
}

class _NuevaAlertaScreenState extends State<_NuevaAlertaScreen> {
  final _tituloCtrl = TextEditingController();
  final _notasCtrl  = TextEditingController();
  String _tipo = 'recordatorio_cita';
  DateTime _fecha = DateTime.now().add(const Duration(days: 1));
  String? _clienteId;
  String _clienteNombre = '';
  bool _guardando = false;

  final _tiposNuevo = const {
    'recordatorio_cita'  : '📅 Recordatorio de cita',
    'cliente_interesado' : '⭐ Cliente interesado en producto',
    'seguimiento_dia3'   : '⏰ Seguimiento de cotización',
    'pago_anticipo_pendiente': '💰 Recordatorio de pago',
  };

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
                setState(() {
                  _clienteId = clientes[i].id;
                  _clienteNombre = clientes[i].nombre;
                });
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
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha));
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
        const SnackBar(content: Text('Escribe el título de la alerta')));
      return;
    }
    setState(() => _guardando = true);
    try {
      await SupabaseService.crearAlerta({
        'tipo'            : _tipo,
        'titulo'          : _tituloCtrl.text.trim(),
        'notas'           : _notasCtrl.text.trim(),
        'cliente_id'      : _clienteId,
        'fecha_programada': _fecha.toIso8601String(),
        'completada'      : false,
      });
      widget.onGuardada();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Alerta creada'),
          backgroundColor: Color(0xFF1d9e75)));
      }
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
        title: const Text('Nueva alerta',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textoPrincipal)),
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: Text(_guardando ? 'Guardando...' : 'Guardar',
              style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700))),
        ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Tipo
        const Text('Tipo de alerta',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ..._tiposNuevo.entries.map((e) {
          final sel = _tipo == e.key;
          return GestureDetector(
            onTap: () => setState(() => _tipo = e.key),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: sel ? AppColors.azulClaro : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: sel ? AppColors.azul : AppColors.grisBorde,
                  width: sel ? 1.5 : 0.5)),
              child: Row(children: [
                Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 16, color: sel ? AppColors.azul : AppColors.textoSecundario),
                const SizedBox(width: 10),
                Text(e.value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: sel ? AppColors.azul : AppColors.textoPrincipal)),
              ])));
        }),
        const SizedBox(height: 16),

        // Título
        TextField(
          controller: _tituloCtrl,
          decoration: InputDecoration(
            labelText: 'Título / descripción *',
            hintText: 'Ej: Llamar a Juan sobre la tabla de cocina',
            prefixIcon: const Icon(Icons.title_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          textCapitalization: TextCapitalization.sentences),
        const SizedBox(height: 12),

        // Cliente
        GestureDetector(
          onTap: _seleccionarCliente,
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
                _clienteNombre.isEmpty ? 'Vincular cliente (opcional)' : _clienteNombre,
                style: TextStyle(fontSize: 13,
                  color: _clienteNombre.isEmpty ? AppColors.textoSecundario : AppColors.textoPrincipal))),
              const Icon(Icons.chevron_right, size: 16, color: AppColors.textoSecundario),
            ]))),
        const SizedBox(height: 12),

        // Fecha
        GestureDetector(
          onTap: _seleccionarFecha,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.azulClaro,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.azul.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.azul),
              const SizedBox(width: 10),
              Text(DateFormat('dd/MM/yyyy HH:mm').format(_fecha),
                style: const TextStyle(fontSize: 13, color: AppColors.azul, fontWeight: FontWeight.w600)),
              const Spacer(),
              const Text('Cambiar', style: TextStyle(fontSize: 11, color: AppColors.azul)),
            ]))),
        const SizedBox(height: 12),

        // Notas
        TextField(
          controller: _notasCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Notas (opcional)',
            hintText: 'Detalles adicionales...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          textCapitalization: TextCapitalization.sentences),
        const SizedBox(height: 24),

        // Botón guardar
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.azul,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(_guardando ? 'Guardando...' : 'Crear alerta',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ]));
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }
}

// ══════════════════════════════════════════════════
// TARJETA DE ALERTA
// ══════════════════════════════════════════════════
class _TarjetaAlerta extends StatefulWidget {
  final Alerta alerta;
  final Map<String, Map<String, dynamic>> tipos;
  final VoidCallback onCompletada;
  const _TarjetaAlerta({
    required this.alerta,
    required this.tipos,
    required this.onCompletada});
  @override
  State<_TarjetaAlerta> createState() => _TarjetaAlertaState();
}

class _TarjetaAlertaState extends State<_TarjetaAlerta> {
  bool _enviando = false;
  late String _mensaje;

  @override
  void initState() { super.initState(); _mensaje = _buildMensaje(); }

  String _buildMensaje() {
    final nombre = widget.alerta.clienteNombre ?? 'Cliente';
    final folio  = widget.alerta.cotizacionFolio ?? '';
    switch (widget.alerta.tipo) {
      case 'seguimiento_dia3':
        return 'Hola *$nombre* 👋 Te contactamos de *HETNA CNC*. ¿Tuviste oportunidad de revisar la cotización $folio? Con gusto resolvemos tus dudas 😊';
      case 'seguimiento_dia5':
        return 'Hola *$nombre*, somos *HETNA CNC*. La cotización $folio sigue disponible. ¿Te interesa continuar? ✅';
      case 'seguimiento_dia7':
        return 'Hola *$nombre* 🔔 Último recordatorio sobre la cotización $folio. La oferta vence pronto. — *HETNA CNC*';
      case 'post_entrega':
        return 'Hola *$nombre* ✅ Esperamos que estés disfrutando tu pedido. Tu opinión es importante para nosotros. ¡Gracias! — *HETNA CNC*';
      case 'pago_anticipo_pendiente':
        return 'Hola *$nombre* 👋 Te recordamos que el anticipo del 50% del pedido *$folio* está pendiente. Para iniciar producción necesitamos confirmarlo. — *HETNA CNC*';
      case 'pago_final_pendiente':
        return 'Hola *$nombre* ✅ Tu pedido *$folio* está listo. Para proceder con la entrega necesitamos el saldo restante. — *HETNA CNC*';
      case 'produccion_sin_avance':
        return 'Hola *$nombre* 🔧 Tu pedido *$folio* está en producción. Te notificaremos cuando esté listo. — *HETNA CNC*';
      case 'cliente_interesado':
        return 'Hola *$nombre* 👋 Vi que te interesa alguno de nuestros productos. ¿Te puedo ayudar a cotizar? — *HETNA CNC*';
      case 'recordatorio_cita':
        return 'Hola *$nombre* 📅 Te recuerdo nuestra cita programada. ¿Todo bien para la reunión? — *HETNA CNC*';
      case 'nuevo_contacto_wa':
        return 'Hola *$nombre* 👋 Gracias por contactar a *HETNA CNC*. ¿En qué podemos ayudarte?';
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
    final fmt   = DateFormat('dd/MM/yy HH:mm');
    final vencida = a.fechaProgramada != null && a.fechaProgramada!.isBefore(DateTime.now());

    return Dismissible(
      key: Key(a.id ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.verde,
          borderRadius: BorderRadius.circular(12)),
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
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: vencida ? AppColors.rojo : color, width: 3),
            top: BorderSide(color: AppColors.grisBorde, width: 0.5),
            right: BorderSide(color: AppColors.grisBorde, width: 0.5),
            bottom: BorderSide(color: AppColors.grisBorde, width: 0.5))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Icono tipo
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.notifications_outlined, size: 16, color: color)),
            const SizedBox(width: 10),
            // Info
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.titulo ?? (info['label'] as String),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              if (a.clienteNombre != null)
                Text(a.clienteNombre!,
                  style: TextStyle(fontSize: 11, color: color),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (a.fechaProgramada != null)
                Text(fmt.format(a.fechaProgramada!),
                  style: TextStyle(fontSize: 10,
                    color: vencida ? AppColors.rojo : AppColors.textoSecundario)),
            ])),
            const SizedBox(width: 8),
            // Botones compactos
            Row(mainAxisSize: MainAxisSize.min, children: [
              // Editar mensaje
              GestureDetector(
                onTap: _editarMensaje,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.edit_outlined, size: 15, color: color))),
              const SizedBox(width: 6),
              // Enviar WA
              if (_tieneWA) GestureDetector(
                onTap: _enviando ? null : _enviarWA,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                  child: _enviando
                    ? const Padding(padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF25D366)))
                    : const Icon(Icons.chat, size: 15, color: Color(0xFF25D366)))),
              if (!_tieneWA) Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.ambarClaro,
                  borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.phone_disabled_outlined, size: 15, color: AppColors.ambar)),
              const SizedBox(width: 6),
              // Completar
              GestureDetector(
                onTap: () async {
                  await SupabaseService.marcarAlertaCompletada(a.id!);
                  widget.onCompletada();
                },
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.azul,
                    borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.check, size: 15, color: Colors.white))),
            ]),
          ]))));
  }  // fin build _TarjetaAlerta

  void _editarMensaje() {
    final ctrl = TextEditingController(text: _mensaje);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Editar mensaje WA',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ]),
          const SizedBox(height: 10),
          Expanded(child: TextField(
            controller: ctrl,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.gris,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none)),
            style: const TextStyle(fontSize: 13))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () {
                setState(() => _mensaje = ctrl.text);
                Navigator.pop(context);
              },
              child: const Text('Guardar'))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              onPressed: () {
                setState(() => _mensaje = ctrl.text);
                Navigator.pop(context);
                _enviarWA();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366)),
              icon: const Icon(Icons.chat, size: 16, color: Colors.white),
              label: const Text('Enviar WA',
                style: TextStyle(color: Colors.white)))),
          ]),
        ])));
  }

  Future<void> _enviarWA() async {
    if (!_tieneWA) return;
    setState(() => _enviando = true);
    try {
      await WhatsAppService.abrirChat(
        numero: widget.alerta.clienteWhatsapp!,
        mensaje: _mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}

// ── AlertasBody: versión sin Scaffold para usar en TabBarView ──
class AlertasBody extends StatefulWidget {
  const AlertasBody({super.key});
  @override
  State<AlertasBody> createState() => _AlertasBodyState();
}

class _AlertasBodyState extends State<AlertasBody> {
  List<Alerta> _alertas = [];
  bool _cargando = true;
  String _filtro = 'todos';

  static const Map<String, Map<String, dynamic>> _tiposB = {
    'todos':                   {'label': 'Todos',          'color': Color(0xFF1a3a5c)},
    'seguimiento_dia3':        {'label': 'Dia 3',          'color': Color(0xFFef9f27)},
    'seguimiento_dia5':        {'label': 'Dia 5',          'color': Color(0xFFef9f27)},
    'seguimiento_dia7':        {'label': 'Dia 7',          'color': Color(0xFFe24b4a)},
    'post_entrega':            {'label': 'Post entrega',   'color': Color(0xFF1d9e75)},
    'pago_anticipo_pendiente': {'label': 'Anticipo',       'color': Color(0xFFe24b4a)},
    'pago_final_pendiente':    {'label': 'Pago final',     'color': Color(0xFFe24b4a)},
    'produccion_sin_avance':   {'label': 'Produccion',     'color': Color(0xFFef9f27)},
    'cliente_interesado':      {'label': 'Interesado',     'color': Color(0xFF7c3aed)},
    'recordatorio_cita':       {'label': 'Cita',           'color': Color(0xFF1a3a5c)},
  };

  List<Alerta> get _filtradas => _filtro == 'todos'
    ? _alertas : _alertas.where((a) => a.tipo == _filtro).toList();

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      try { await SupabaseService.generarAlertasAutomaticas(); } catch (_) {}
      final alertas = await SupabaseService.getAlertasPendientes();
      if (mounted) setState(() { _alertas = alertas; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiposActivos = _tiposB.entries
      .where((e) => e.key == 'todos' || _alertas.any((a) => a.tipo == e.key))
      .toList();

    return Column(children: [
      // Barra de acciones
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          Expanded(child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: tiposActivos.map((e) {
              final sel = _filtro == e.key;
              final color = e.value['color'] as Color;
              return GestureDetector(
                onTap: () => setState(() => _filtro = e.key),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? color : AppColors.grisBorde)),
                  child: Text(e.value['label'] as String,
                    style: TextStyle(fontSize: 11,
                      color: sel ? Colors.white : AppColors.textoSecundario,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal))));
            }).toList()))),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.azul),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => _NuevaAlertaScreen(onGuardada: _cargar)))),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.azul, size: 18),
            onPressed: _cargar),
        ])),
      // Lista
      Expanded(child: _cargando
        ? const Center(child: CircularProgressIndicator())
        : _filtradas.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('🎉', style: TextStyle(fontSize: 40)),
              SizedBox(height: 8),
              Text('Sin alertas pendientes', style: TextStyle(color: AppColors.textoSecundario)),
            ]))
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _filtradas.length,
                itemBuilder: (_, i) => _TarjetaAlerta(
                  alerta: _filtradas[i],
                  tipos: _tiposB,
                  onCompletada: _cargar)))),
    ]);
  }
}
