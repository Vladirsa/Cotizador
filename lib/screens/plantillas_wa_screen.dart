// lib/screens/plantillas_wa_screen.dart
// HETNA CNC — Editor de plantillas de WhatsApp
// Cada taller personaliza sus mensajes y número desde aquí
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

// ══════════════════════════════════════════════════════
// MODELO
// ══════════════════════════════════════════════════════
class PlantillaWa {
  final String? id;
  final String tipo;
  final String nombre;
  String mensaje;
  final bool activo;

  PlantillaWa({this.id, required this.tipo, required this.nombre,
    required this.mensaje, this.activo = true});

  factory PlantillaWa.fromJson(Map<String, dynamic> j) => PlantillaWa(
    id: j['id'],
    tipo: j['tipo'] ?? j['categoria'] ?? 'general',
    nombre: j['nombre'] ?? j['titulo'] ?? '',
    mensaje: j['mensaje'] ?? j['cuerpo'] ?? '',
    activo: j['activo'] ?? true);

  // Variables disponibles para usar en los mensajes
  static const variables = [
    '*NOMBRE*',   // Nombre del cliente
    '*FOLIO*',    // Folio de la cotización/pedido
    '*MONTO*',    // Monto total
    '*EMPRESA*',  // Nombre del taller
    '*TELEFONO*', // Teléfono del taller
    '*FECHA*',    // Fecha actual
  ];

  static const descripciones = {
    'seguimiento_dia3':        'Seguimiento — Día 3',
    'seguimiento_dia5':        'Seguimiento — Día 5',
    'seguimiento_dia7':        'Seguimiento — Día 7 (último)',
    'post_entrega':            'Post entrega',
    'pago_anticipo_pendiente': 'Anticipo pendiente',
    'pago_final_pendiente':    'Pago final pendiente',
    'avance_produccion':       'En producción',
    'avance_entrega':          'Listo para entrega',
    'avance_entregado':        'Entregado',
  };

  static const emojis = {
    'seguimiento_dia3': '📋',
    'seguimiento_dia5': '📋',
    'seguimiento_dia7': '⏰',
    'post_entrega':     '🎉',
    'pago_anticipo_pendiente': '💰',
    'pago_final_pendiente':    '💰',
    'avance_produccion': '🔧',
    'avance_entrega':    '📦',
    'avance_entregado':  '✅',
  };

  String get emoji => emojis[tipo] ?? '💬';
  String get descripcion => descripciones[tipo] ?? nombre;
}

// ══════════════════════════════════════════════════════
// PANTALLA PRINCIPAL
// ══════════════════════════════════════════════════════
class PlantillasWaScreen extends StatefulWidget {
  const PlantillasWaScreen({super.key});
  @override
  State<PlantillasWaScreen> createState() => _PlantillasWaScreenState();
}

class _PlantillasWaScreenState extends State<PlantillasWaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<PlantillaWa> _plantillas = [];
  Map<String, dynamic>? _config;
  bool _cargando = true;
  bool _guardando = false;

  // Controladores de configuración
  final _numCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  String _modo = 'app';

  final _sb = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _numCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final results = await Future.wait([
        _sb.from('plantillas_wa').select('id, tipo, titulo, cuerpo, nombre, mensaje, activo').eq('activo', true).order('titulo'),
        _sb.from('configuracion_empresa').select(
          'whatsapp_numero, whatsapp_token, whatsapp_modo').maybeSingle(),
      ]);

      final plantillasData = results[0] as List;
      final configData = results[1] as Map<String, dynamic>?;

      if (mounted) setState(() {
        _plantillas = plantillasData.map((j) => PlantillaWa.fromJson(j)).toList();
        _config = configData;
        if (configData != null) {
          _numCtrl.text = configData['whatsapp_numero'] ?? '';
          _tokenCtrl.text = configData['whatsapp_token'] ?? '';
          _modo = configData['whatsapp_modo'] ?? 'app';
        }
        _cargando = false;
      });
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Plantillas WhatsApp',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
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
          tabs: const [
            Tab(text: '💬 Mensajes'),
            Tab(text: '⚙️ Configuración'),
          ])),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            _tabMensajes(),
            _tabConfiguracion(),
          ]));
  }

  // ── TAB 1: MENSAJES ─────────────────────────────────
  Widget _tabMensajes() {
    return Column(children: [
      // Banner explicativo
      Container(
        color: AppColors.azulClaro,
        padding: const EdgeInsets.all(12),
        child: const Row(children: [
          Text('💡', style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Expanded(child: Text(
            'Personaliza cada mensaje. Usa *NOMBRE*, *FOLIO*, *MONTO*, *EMPRESA*, *TELEFONO* como variables — se reemplazan automáticamente al enviar.',
            style: TextStyle(fontSize: 11, color: AppColors.azul))),
        ])),
      // Lista de plantillas
      Expanded(child: _plantillas.isEmpty
        ? _cardVacio()
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _plantillas.length,
            itemBuilder: (_, i) => _cardPlantilla(_plantillas[i]))),
    ]);
  }

  Widget _cardPlantilla(PlantillaWa p) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header de la tarjeta
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          color: AppColors.azulClaro,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
        child: Row(children: [
          Text(p.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(child: Text(p.descripcion,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: AppColors.azul))),
          GestureDetector(
            onTap: () => _editarPlantilla(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.azul,
                borderRadius: BorderRadius.circular(20)),
              child: const Text('Editar',
                style: TextStyle(fontSize: 11, color: Colors.white,
                  fontWeight: FontWeight.w600)))),
        ])),
      // Preview del mensaje
      Padding(
        padding: const EdgeInsets.all(14),
        child: Text(p.mensaje,
          style: const TextStyle(fontSize: 12, color: AppColors.textoPrincipal, height: 1.5),
          maxLines: 4, overflow: TextOverflow.ellipsis)),
      // Variables usadas
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Wrap(spacing: 4, runSpacing: 4,
          children: PlantillaWa.variables
            .where((v) => p.mensaje.contains(v))
            .map((v) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.verde.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: Text(v, style: const TextStyle(
                fontSize: 10, color: AppColors.verde, fontWeight: FontWeight.w600))))
            .toList())),
    ]));

  Widget _cardVacio() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text('💬', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      const Text('No hay plantillas configuradas',
        style: TextStyle(fontSize: 14, color: AppColors.textoSecundario)),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: _crearPlantillasDefault,
        icon: const Icon(Icons.add, color: Colors.white, size: 16),
        label: const Text('Crear plantillas default',
          style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul)),
    ]));

  // ── TAB 2: CONFIGURACIÓN ────────────────────────────
  Widget _tabConfiguracion() => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      // Número de WhatsApp del taller
      _seccionCard('📱 Número de WhatsApp del taller',
        'Este número se usa para enviar mensajes a tus clientes.',
        child: Column(children: [
          TextField(
            controller: _numCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Número (10 dígitos)',
              hintText: '2461217072',
              prefixText: '+52 ',
              prefixIcon: const Icon(Icons.phone_outlined, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true)),
          const SizedBox(height: 8),
          const Text(
            'Solo el número, sin +52. Ej: 2461217072',
            style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ])),

      const SizedBox(height: 14),

      // Modo de envío
      _seccionCard('🔄 Modo de envío',
        'Cómo quieres enviar los mensajes.',
        child: Column(children: [
          _cardModo('app', '📱 Abrir WhatsApp',
            'Abre la app de WhatsApp en el celular. El mensaje se prepara automáticamente.',
            'Gratis, sin configuración'),
          const SizedBox(height: 8),
          _cardModo('api', '🚀 WhatsApp Business API',
            'Envía directamente desde tu número Business. No abre la app.',
            'Requiere cuenta Meta Business + token'),
        ])),

      if (_modo == 'api') ...[
        const SizedBox(height: 14),
        _seccionCard('🔑 Token de acceso Meta',
          'Token permanente de tu cuenta de WhatsApp Business API.',
          child: Column(children: [
            TextField(
              controller: _tokenCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Token de acceso',
                hintText: 'EAAxxxxxxxxx...',
                prefixIcon: const Icon(Icons.key_outlined, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true)),
            const SizedBox(height: 8),
            const Text(
              'Encuéntralo en: Meta Business → WhatsApp → Configuración API → Token de acceso permanente',
              style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          ])),
      ],

      const SizedBox(height: 20),

      // Botón guardar configuración
      SizedBox(width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _guardando ? null : _guardarConfig,
          icon: _guardando
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_outlined, color: Colors.white, size: 18),
          label: Text(_guardando ? 'Guardando...' : 'Guardar configuración',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.verde,
            padding: const EdgeInsets.symmetric(vertical: 14)))),

      const SizedBox(height: 16),

      // Info sobre variables
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.azulClaro,
          borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Variables disponibles en los mensajes:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.azul)),
          const SizedBox(height: 10),
          ...PlantillaWa.variables.map((v) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.azul,
                  borderRadius: BorderRadius.circular(10)),
                child: Text(v, style: const TextStyle(
                  fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600))),
              const SizedBox(width: 10),
              Text(_descripcionVariable(v),
                style: const TextStyle(fontSize: 12, color: AppColors.textoPrincipal)),
            ]))),
        ])),
    ]);

  Widget _cardModo(String valor, String titulo, String desc, String nota) {
    final sel = _modo == valor;
    return GestureDetector(
      onTap: () => setState(() => _modo = valor),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? AppColors.azul : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? AppColors.azul : AppColors.grisBorde,
            width: sel ? 1.5 : 0.5)),
        child: Row(children: [
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: sel ? Colors.white : AppColors.textoSecundario, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: sel ? Colors.white : AppColors.textoPrincipal)),
            Text(desc, style: TextStyle(
              fontSize: 11,
              color: sel ? Colors.white70 : AppColors.textoSecundario)),
            Text(nota, style: TextStyle(
              fontSize: 10, fontStyle: FontStyle.italic,
              color: sel ? Colors.white60 : AppColors.textoSecundario)),
          ])),
        ])));
  }

  Widget _seccionCard(String titulo, String subtitulo, {required Widget child}) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.azul)),
        Text(subtitulo, style: const TextStyle(
          fontSize: 11, color: AppColors.textoSecundario)),
        const SizedBox(height: 14),
        child,
      ]));

  // ── EDITAR PLANTILLA ────────────────────────────────
  void _editarPlantilla(PlantillaWa p) {
    final ctrl = TextEditingController(text: p.mensaje);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.azulClaro,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${p.emoji} ${p.descripcion}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.azul)),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close, color: AppColors.azul, size: 20)),
              ]),
              const SizedBox(height: 4),
              const Text('Toca las variables para insertarlas en el mensaje:',
                style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
              const SizedBox(height: 8),
              // Chips de variables
              Wrap(spacing: 6, runSpacing: 4,
                children: PlantillaWa.variables.map((v) => GestureDetector(
                  onTap: () {
                    final pos = ctrl.selection.base.offset;
                    final text = ctrl.text;
                    final newText = pos >= 0
                      ? text.substring(0, pos) + v + text.substring(pos)
                      : text + v;
                    ctrl.text = newText;
                    ctrl.selection = TextSelection.collapsed(
                      offset: (pos >= 0 ? pos : text.length) + v.length);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.azul,
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(v, style: const TextStyle(
                      fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600))))).toList()),
            ])),

          // Editor del mensaje
          Expanded(child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16,
              MediaQuery.of(ctx).viewInsets.bottom + 12),
            child: TextField(
              controller: ctrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 13, height: 1.6),
              decoration: InputDecoration(
                hintText: 'Escribe el mensaje...',
                filled: true,
                fillColor: AppColors.gris,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.grisBorde)))))),

          // Botones
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16,
              MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.grisBorde),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.textoSecundario)))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: ElevatedButton.icon(
                onPressed: () async {
                  await _guardarPlantilla(p, ctrl.text.trim());
                  if (mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.save_outlined, color: Colors.white, size: 16),
                label: const Text('Guardar mensaje',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verde,
                  padding: const EdgeInsets.symmetric(vertical: 12)))),
            ])),
        ])));
  }

  // ── GUARDAR PLANTILLA ───────────────────────────────
  Future<void> _guardarPlantilla(PlantillaWa p, String nuevoMensaje) async {
    if (nuevoMensaje.isEmpty) return;
    try {
      if (p.id != null) {
        await _sb.from('plantillas_wa')
          .update({
            'mensaje': nuevoMensaje,
            'cuerpo': nuevoMensaje, // columna original
          })
          .eq('id', p.id!);
      } else {
        await _sb.from('plantillas_wa').insert({
          'tipo': p.tipo,
          'nombre': p.nombre,
          'titulo': p.nombre, // columna original
          'mensaje': nuevoMensaje,
          'cuerpo': nuevoMensaje, // columna original
          'categoria': p.tipo,
        });
      }
      setState(() {
        final idx = _plantillas.indexWhere((pl) => pl.tipo == p.tipo);
        if (idx >= 0) _plantillas[idx].mensaje = nuevoMensaje;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Mensaje guardado'),
        backgroundColor: AppColors.verde));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    }
  }

  // ── GUARDAR CONFIGURACIÓN ───────────────────────────
  Future<void> _guardarConfig() async {
    setState(() => _guardando = true);
    try {
      await _sb.from('configuracion_empresa').update({
        'whatsapp_numero': _numCtrl.text.trim(),
        'whatsapp_token': _tokenCtrl.text.trim().isEmpty ? null : _tokenCtrl.text.trim(),
        'whatsapp_modo': _modo,
      }).eq('negocio_id', _sb.auth.currentUser?.id ?? '');

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Configuración guardada'),
        backgroundColor: AppColors.verde));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── CREAR PLANTILLAS DEFAULT ─────────────────────────
  Future<void> _crearPlantillasDefault() async {
    setState(() => _cargando = true);
    final defaults = [
      {'tipo': 'seguimiento_dia3', 'nombre': 'Seguimiento día 3',
       'mensaje': '¡Hola *NOMBRE*! 😊\n\nTe escribo de *EMPRESA* sobre tu cotización *FOLIO*.\n\n¿Tienes alguna duda? Estamos aquí.\n\n📱 *TELEFONO*'},
      {'tipo': 'seguimiento_dia5', 'nombre': 'Seguimiento día 5',
       'mensaje': '¡Hola *NOMBRE*! 👋\n\nTe contacto de *EMPRESA* sobre *FOLIO*.\n\nPodemos ajustar lo que necesites. ¿Cuándo platicamos?\n\n📱 *TELEFONO*'},
      {'tipo': 'seguimiento_dia7', 'nombre': 'Seguimiento día 7',
       'mensaje': '¡Hola *NOMBRE*! ⏰\n\nLa cotización *FOLIO* vence pronto.\n\n📱 *TELEFONO* — *EMPRESA*'},
      {'tipo': 'post_entrega', 'nombre': 'Post entrega',
       'mensaje': '¡Hola *NOMBRE*! 🎉\n\nEsperamos que disfrutes tu pedido de *EMPRESA*. ¿Cómo te fue? 🙏'},
      {'tipo': 'pago_anticipo_pendiente', 'nombre': 'Anticipo pendiente',
       'mensaje': '¡Hola *NOMBRE*! 💰\n\nAnticipo del pedido *FOLIO* pendiente.\nMonto: *MONTO*\n\n📱 *TELEFONO*'},
      {'tipo': 'pago_final_pendiente', 'nombre': 'Pago final',
       'mensaje': '¡Hola *NOMBRE*! 📦\n\nTu pedido *FOLIO* está LISTO.\nMonto: *MONTO*\n\n📱 *TELEFONO*'},
      {'tipo': 'avance_produccion', 'nombre': 'En producción',
       'mensaje': '¡Hola *NOMBRE*! 🔧 Tu pedido *FOLIO* está en producción. — *EMPRESA*'},
      {'tipo': 'avance_entrega', 'nombre': 'Listo para entrega',
       'mensaje': '¡Hola *NOMBRE*! 📦 Tu pedido *FOLIO* está LISTO. ¿Cuándo coordinamos? 📱 *TELEFONO*'},
      {'tipo': 'avance_entregado', 'nombre': 'Entregado',
       'mensaje': '¡Hola *NOMBRE*! 🎉 Tu pedido *FOLIO* fue entregado. ¡Gracias por confiar en *EMPRESA*! 💙'},
    ];

    for (final d in defaults) {
      try {
        await _sb.from('plantillas_wa').insert({
          ...d,
          'titulo': d['nombre'],
          'cuerpo': d['mensaje'],
          'categoria': d['tipo'],
        });
      } catch (_) {}
    }
    _cargar();
  }

  String _descripcionVariable(String v) {
    switch (v) {
      case '*NOMBRE*':   return 'Nombre del cliente';
      case '*FOLIO*':    return 'Número de cotización o pedido';
      case '*MONTO*':    return 'Monto total en pesos';
      case '*EMPRESA*':  return 'Nombre de tu taller';
      case '*TELEFONO*': return 'Tu número de WhatsApp';
      case '*FECHA*':    return 'Fecha de hoy';
      default: return '';
    }
  }
}
