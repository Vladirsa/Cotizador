// ============================================
// lib/screens/marketing_screen.dart
// ============================================
import 'package:flutter/material.dart';
import 'cupones_screen.dart';
import 'plantillas_wa_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../i18n/tr.dart';

class MarketingScreen extends StatefulWidget {
  const MarketingScreen({super.key});
  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: Text(tr('Marketing'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _mostrarAyudaMarketing(context),
            icon: const Icon(Icons.help_outline, color: AppColors.azul),
            tooltip: tr('Ayuda')),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: [
            Tab(icon: Icon(Icons.inbox_outlined, size: 16), text: tr('Cola de hoy')),
            Tab(icon: Icon(Icons.people_outline, size: 16), text: tr('Campañas')),
            Tab(icon: Icon(Icons.message_outlined, size: 16), text: tr('Plantillas WA')),
            Tab(icon: Icon(Icons.discount_outlined, size: 16), text: tr('Cupones')),
          ]),
      ),
      body: TabBarView(controller: _tabs, children: [
        const _ColaTab(),
        const _CampanasTab(),
        const _PlantillasTab(),
        const CuponesScreen(),
      ]));
  }
}

// ══════════════════════════════════════════════════════
// AYUDA — pantalla completa de Marketing
// ══════════════════════════════════════════════════════
void _mostrarAyudaMarketing(BuildContext context) {
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
          Text(tr('❓ Cómo funciona Marketing'), style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.azul)),
          const SizedBox(height: 8),
          Text(
            tr('Este módulo te ayuda a mandar mensajes de WhatsApp a varios clientes a la vez, de forma organizada y sin saturar tu número (Meta limita cuántos mensajes puedes mandar por día).'),
            style: TextStyle(fontSize: 13, color: AppColors.textoSecundario, height: 1.4)),
          _bloqueAyudaMkt(tr('📥 Cola de hoy'),
            tr('Aquí aparecen los mensajes que ya están listos para mandarse hoy — vienen de una Campaña que lanzaste. Los revisas uno por uno y confirmas si ya los enviaste. Tiene un límite diario para no violar las reglas de WhatsApp Business (mandar demasiados mensajes seguidos puede hacer que Meta bloquee tu número).')),
          _bloqueAyudaMkt(tr('👥 Campañas y Segmento objetivo'),
            tr('Una Campaña es "a quién le voy a mandar qué mensaje". El "Segmento objetivo" es el grupo de clientes que la recibirá — por ejemplo, "Clientes que no han comprado en 30 días" o "Todos los clientes activos". Eliges el segmento, eliges la plantilla de mensaje, y defines cuántos mensajes por día quieres mandar de esa campaña (para que se reparta en la Cola de varios días si el grupo es grande).')),
          _bloqueAyudaMkt(tr('💬 Plantillas WA y Variables'),
            tr('Una plantilla es un mensaje pre-escrito que se reutiliza. Puedes meterle variables que se rellenan solas con los datos de cada cliente:\n\n• *NOMBRE* = se cambia por el nombre del cliente\n• *FOLIO* = número de cotización o pedido\n• *MONTO* = el precio o total en pesos\n• *FECHA* = la fecha actual\n\nPor ejemplo: "Hola *NOMBRE*, tu cotización *FOLIO* por *MONTO* sigue disponible" se convierte automáticamente en "Hola Juan, tu cotización COT-045 por \$1,200 sigue disponible" para cada cliente.')),
          _bloqueAyudaMkt(tr('🎟️ Cupones'),
            tr('Códigos de descuento que puedes activar para tus campañas o compartir directamente con clientes — por ejemplo un cupón "VERANO10" que da 10% de descuento.')),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(10)),
            child: Text(tr('💡 Consejo: empieza con campañas chicas (pocos mensajes al día) para probar cómo responden tus clientes, antes de mandar a todo tu segmento de golpe.'),
              style: TextStyle(fontSize: 12, color: AppColors.azul, height: 1.4))),
        ]))));
}

Widget _bloqueAyudaMkt(String titulo, String texto) => Padding(
  padding: const EdgeInsets.only(top: 18),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(tr(titulo), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textoPrincipal)),
    const SizedBox(height: 6),
    Text(tr(texto), style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario, height: 1.45)),
  ]));

// ══════════════════════════════════════════════
// TAB 1 — COLA DE MENSAJES DE HOY
// ══════════════════════════════════════════════
class _ColaTab extends StatefulWidget {
  const _ColaTab();
  @override
  State<_ColaTab> createState() => _ColaTabState();
}

class _ColaTabState extends State<_ColaTab> {
  List<Map<String, dynamic>> _cola = [];
  List<Map<String, dynamic>> _historial = [];
  bool _cargando = true;
  int _enviadosHoy = 0;
  static const int _limitesDiario = 5;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final results = await Future.wait([
        SupabaseService.getColaMensajesHoy(),
        SupabaseService.getColaMensajesHistorial(),
        SupabaseService.countMensajesEnviadosHoy(),
      ]);
      if (mounted) setState(() {
        _cola = results[0] as List<Map<String, dynamic>>;
        _historial = results[1] as List<Map<String, dynamic>>;
        _enviadosHoy = results[2] as int;
        _cargando = false;
      });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  Future<void> _enviar(Map<String, dynamic> msg) async {
    if (_enviadosHoy >= _limitesDiario) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('⚠️ Límite diario alcanzado (5 mensajes). Continúa mañana.')),
        backgroundColor: AppColors.ambar));
      return;
    }
    final cl = msg['clientes'] as Map<String, dynamic>?;
    final wa = cl?['whatsapp'] as String? ?? cl?['telefono'] as String? ?? '';
    if (wa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('Este cliente no tiene WhatsApp registrado'))));
      return;
    }

    // Normalizar número mexicano
    String numero = wa.replaceAll(RegExp(r'[^0-9]'), '');
    if (numero.length == 10) numero = '521$numero';
    else if (numero.length == 12 && numero.startsWith('52')) numero = '521${numero.substring(2)}';

    final texto = Uri.encodeComponent(msg['mensaje_final'] as String? ?? '');
    await launchUrl(Uri.parse('https://wa.me/$numero?text=$texto'),
        mode: LaunchMode.externalApplication);

    // Confirmar envío
    if (mounted) {
      final confirmar = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('¿Enviaste el mensaje?'), style: TextStyle(fontSize: 15)),
          content: Text(tr('Confirma si el mensaje fue enviado exitosamente.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text(tr('No enviado'))),
            ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
              child: Text(tr('Sí, enviado'), style: TextStyle(color: Colors.white))),
          ]));
      if (confirmar == true) {
        await SupabaseService.marcarMensajeEnviado(msg['id']);
        await _cargar();
      }
    }
  }

  Future<void> _omitir(Map<String, dynamic> msg) async {
    await SupabaseService.marcarMensajeOmitido(msg['id']);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final restantes = _limitesDiario - _enviadosHoy;
    return _cargando
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [

          // Barra de límite diario
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: restantes > 0 ? AppColors.azulClaro : AppColors.rojoClaro,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: restantes > 0
                ? AppColors.azul.withOpacity(0.2) : AppColors.rojo.withOpacity(0.3))),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Icon(restantes > 0 ? Icons.schedule_outlined : Icons.block_outlined,
                    size: 16, color: restantes > 0 ? AppColors.azul : AppColors.rojo),
                  const SizedBox(width: 8),
                  Text(tr(restantes > 0
                    ? trf('Puedes enviar {0} mensaje{1} hoy', [restantes, (restantes != 1 ? "s" : "")])
                    : tr('Límite diario alcanzado')),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: restantes > 0 ? AppColors.azul : AppColors.rojo)),
                ]),
                Text(trf('{0}/{1} enviados', [_enviadosHoy, _limitesDiario]),
                  style: TextStyle(fontSize: 11,
                    color: restantes > 0 ? AppColors.azul : AppColors.rojo)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _enviadosHoy / _limitesDiario,
                  backgroundColor: Colors.white,
                  minHeight: 6,
                  valueColor: AlwaysStoppedAnimation(
                    restantes > 0 ? AppColors.azul : AppColors.rojo))),
            ])),

          const SizedBox(height: 14),

          // Cola pendiente
          if (_cola.isEmpty)
            Container(padding: const EdgeInsets.all(24), alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                const Icon(Icons.inbox_outlined, size: 48, color: AppColors.grisBorde),
                const SizedBox(height: 8),
                Text(tr('No hay mensajes pendientes para hoy'),
                  style: TextStyle(color: AppColors.textoSecundario)),
                const SizedBox(height: 6),
                Text(tr('Ve a Campañas para agregar mensajes a la cola'),
                  style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _cargar,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: Text(tr('Actualizar')),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.azul,
                    side: const BorderSide(color: AppColors.azul))),
              ]))
          else ...[
            Text(trf('{0} mensaje{1} pendientes', [(_cola.length), (_cola.length != 1 ? "s" : "")]),
              style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario,
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._cola.map((msg) => _TarjetaMensaje(
              msg: msg,
              puedeEnviar: restantes > 0,
              onEnviar: () => _enviar(msg),
              onOmitir: () => _omitir(msg))),
          ],

          // Historial reciente
          if (_historial.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(tr('HISTORIAL RECIENTE'), style: TextStyle(fontSize: 10,
              color: AppColors.textoSecundario, letterSpacing: 1, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._historial.take(5).map((msg) {
              final enviado = msg['estado'] == 'enviado';
              final cl = msg['clientes'] as Map<String, dynamic>?;
              return Container(margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.grisBorde, width: 0.5)),
                child: Row(children: [
                  Icon(enviado ? Icons.check_circle_outline : Icons.cancel_outlined,
                    size: 16, color: enviado ? AppColors.verde : AppColors.textoSecundario),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr(cl?['nombre'] as String? ?? '—'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    Text(tr(msg['campana'] as String? ?? tr('Sin campaña')),
                      style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
                  ])),
                  Text(tr(enviado ? tr('Enviado') : tr('Omitido')),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: enviado ? AppColors.verde : AppColors.textoSecundario)),
                ]));
            }),
          ],
          const SizedBox(height: 20),
        ]));
  }
}

class _TarjetaMensaje extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool puedeEnviar;
  final VoidCallback onEnviar;
  final VoidCallback onOmitir;
  const _TarjetaMensaje({required this.msg, required this.puedeEnviar,
    required this.onEnviar, required this.onOmitir});

  @override
  Widget build(BuildContext context) {
    final cl = msg['clientes'] as Map<String, dynamic>?;
    final nombre = cl?['nombre'] as String? ?? '—';
    final campana = msg['campana'] as String? ?? '';
    final mensaje = msg['mensaje_final'] as String? ?? '';

    return Container(margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)]),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 16, backgroundColor: AppColors.azulClaro,
            child: Text(tr(nombre.isNotEmpty ? nombre[0].toUpperCase() : '?'),
              style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700, fontSize: 13))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(nombre), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            if (campana.isNotEmpty)
              Text(tr(campana), style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF25D366).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
            child: Text(tr('Pendiente'),
              style: TextStyle(fontSize: 9, color: Color(0xFF25D366), fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(8),
            border: const Border(left: BorderSide(color: Color(0xFF25D366), width: 3))),
          child: Text(tr(mensaje), style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.azul))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: onOmitir,
            icon: const Icon(Icons.skip_next_outlined, size: 14),
            label: Text(tr('Omitir'), style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textoSecundario,
              side: const BorderSide(color: AppColors.grisBorde),
              padding: const EdgeInsets.symmetric(vertical: 8)))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: ElevatedButton.icon(
            onPressed: puedeEnviar ? onEnviar : null,
            icon: const Icon(Icons.send, size: 14, color: Colors.white),
            label: Text(tr('Enviar por WhatsApp'), style: TextStyle(fontSize: 12, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              disabledBackgroundColor: AppColors.grisBorde,
              padding: const EdgeInsets.symmetric(vertical: 8)))),
        ]),
      ])));
  }
}

// ══════════════════════════════════════════════
// TAB 2 — CAMPAÑAS / SEGMENTOS
// ══════════════════════════════════════════════
class _CampanasTab extends StatefulWidget {
  const _CampanasTab();
  @override
  State<_CampanasTab> createState() => _CampanasTabState();
}

class _CampanasTabState extends State<_CampanasTab> {
  List<Map<String, dynamic>> _plantillas = [];
  List<Map<String, dynamic>> _campanas   = [];
  bool _cargando = true;

  // ── Segmentos con descripción ──
  final _segmentos = [
    {
      'key': 'activos',
      'nombre': 'Clientes activos',
      'desc': 'Clientes con pedidos en los últimos 90 días',
      'icon': Icons.person_outline,
      'color': AppColors.verde,
    },
    {
      'key': 'potenciales',
      'nombre': 'Clientes potenciales',
      'desc': 'Contactos que aún no han comprado',
      'icon': Icons.person_add_outlined,
      'color': AppColors.ambar,
    },
    {
      'key': 'frecuentes',
      'nombre': 'Clientes frecuentes',
      'desc': 'Clientes con 2+ pedidos entregados',
      'icon': Icons.star_outline,
      'color': const Color(0xFF7c3aed),
    },
    {
      'key': 'cotizaciones_pendientes',
      'nombre': 'Cotizaciones sin respuesta',
      'desc': 'Enviadas hace más de 3 días sin aprobación',
      'icon': Icons.pending_actions_outlined,
      'color': AppColors.rojo,
    },
    {
      'key': 'todos',
      'nombre': 'Todos los clientes',
      'desc': 'Enviar a toda tu base de contactos',
      'icon': Icons.people_outline,
      'color': AppColors.azul,
    },
  ];

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final plantillas = await SupabaseService.getPlantillasWA();
      final campanas   = await SupabaseService.getCampanas();
      if (mounted) setState(() {
        _plantillas = plantillas;
        _campanas   = campanas;
        _cargando   = false;
      });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  // ── Crear / Editar campaña ──
  Future<void> _editarCampana([Map<String, dynamic>? campana]) async {
    final nombreCtrl = TextEditingController(text: campana?['nombre'] ?? '');
    String? segKey     = campana?['segmento_key'];
    String? plantId    = campana?['plantilla_id'];
    int limite         = campana?['limite_diario'] ?? 20;
    Map<String, dynamic>? segSel = segKey != null
      ? _segmentos.firstWhere((s) => s['key'] == segKey, orElse: () => _segmentos[0])
      : null;
    Map<String, dynamic>? plantSel = plantId != null
      ? _plantillas.firstWhere((p) => p['id'] == plantId, orElse: () => _plantillas[0])
      : null;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) =>
        AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              // Header
              Container(padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
                child: Row(children: [
                  Expanded(child: Text(
                    tr(campana == null ? tr('Nueva campaña') : tr('Editar campaña')),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx, false)),
                ])),
              // Contenido
              Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
                // Nombre
                TextField(
                  controller: nombreCtrl,
                  decoration: InputDecoration(
                    labelText: tr('Nombre de la campaña *'),
                    hintText: tr('Ej: Reactivación de clientes dormidos'),
                    prefixIcon: const Icon(Icons.campaign_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  textCapitalization: TextCapitalization.sentences),
                const SizedBox(height: 16),
                // Segmento
                Text(tr('Segmento objetivo'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ..._segmentos.map((s) {
                  final sel = segSel?['key'] == s['key'];
                  final color = s['color'] as Color;
                  return GestureDetector(
                    onTap: () => setS(() { segSel = s; segKey = s['key'] as String; }),
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
                        Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 16, color: sel ? color : AppColors.textoSecundario),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr(s['nombre'] as String),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: sel ? color : AppColors.textoPrincipal)),
                          Text(tr(s['desc'] as String),
                            style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                        ])),
                      ])));
                }),
                const SizedBox(height: 16),
                // Plantilla
                Text(tr('Mensaje a enviar'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (_plantillas.isEmpty)
                  Container(padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFEF3E2),
                      borderRadius: BorderRadius.circular(8)),
                    child: Text(tr('No hay plantillas. Crea una en la pestaña Plantillas.'),
                      style: TextStyle(fontSize: 12, color: AppColors.ambar))),
                ..._plantillas.map((p) {
                  final sel = plantSel?['id'] == p['id'];
                  return GestureDetector(
                    onTap: () => setS(() { plantSel = p; plantId = p['id'] as String; }),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.azulClaro : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? AppColors.azul : AppColors.grisBorde,
                          width: sel ? 1.5 : 0.5)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(sel ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 16, color: sel ? AppColors.azul : AppColors.textoSecundario),
                          const SizedBox(width: 8),
                          Expanded(child: Text(tr(p['titulo'] as String? ?? ''),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: sel ? AppColors.azul : AppColors.textoPrincipal))),
                        ]),
                        if (sel && (p['cuerpo'] as String? ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.gris,
                              borderRadius: BorderRadius.circular(6)),
                            child: Text(tr(p['cuerpo'] as String? ?? ''),
                              style: const TextStyle(fontSize: 11, height: 1.5))),
                        ],
                      ])));
                }),
                const SizedBox(height: 16),
                // Límite diario
                Text(tr('Mensajes por día'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(tr('¿Cuántos mensajes enviar diariamente de esta campaña?'),
                  style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [5, 10, 20, 30, 50, 100].map((n) {
                  final sel = limite == n;
                  return GestureDetector(
                    onTap: () => setS(() => limite = n),
                    child: Container(
                      width: 56, height: 40,
                      decoration: BoxDecoration(
                        color: sel ? AppColors.azul : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde)),
                      child: Center(child: Text('$n',
                        style: TextStyle(fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : AppColors.textoSecundario)))));
                }).toList()),
              ])),
              // Botón guardar
              Container(padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
                child: SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final nombre = nombreCtrl.text.trim();
                      if (nombre.isEmpty || segKey == null || plantId == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(tr('Completa nombre, segmento y mensaje'))));
                        return;
                      }
                      final datos = {
                        if (campana?['id'] != null) 'id': campana!['id'],
                        'nombre'         : nombre,
                        'segmento_key'   : segKey,
                        'plantilla_id'   : plantId,
                        'limite_diario'  : limite,
                        'activa'         : true,
                      };
                      Navigator.pop(ctx, true);
                      try {
                        await SupabaseService.guardarCampana(datos);
                        await _cargar();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(tr(campana == null ? tr('✅ Campaña creada') : tr('✅ Campaña actualizada'))),
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
                    child: Text(tr(campana == null ? tr('Crear campaña') : tr('Guardar cambios')),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  )))
            ])))));
    if (ok == true) await _cargar();
  }

  // ── Eliminar campaña ──
  Future<void> _eliminarCampana(Map<String, dynamic> campana) async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('Eliminar campaña')),
        content: Text(trf('¿Eliminar "{0}"?', [(campana['nombre'])])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Cancelar'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
            child: Text(tr('Eliminar'), style: TextStyle(color: Colors.white))),
        ]));
    if (ok == true) {
      await SupabaseService.eliminarCampana(campana['id'] as String);
      await _cargar();
    }
  }

  // ── Lanzar campaña guardada ──
  Future<void> _lanzarCampanaGuardada(Map<String, dynamic> campana) async {
    try {
      final plantilla = _plantillas.firstWhere(
        (p) => p['id'] == campana['plantilla_id'],
        orElse: () => <String, dynamic>{});
      if (plantilla.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('La plantilla de esta campaña ya no existe'))));
        return;
      }
      final segKey = campana['segmento_key'] as String? ?? 'todos';
      final limite = campana['limite_diario'] as int? ?? 20;
      final clientes = await SupabaseService.getClientesPorSegmento(segKey);
      final conWA = clientes.where((c) => c.whatsappNumero.isNotEmpty).take(limite).toList();
      if (conWA.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No hay clientes con WhatsApp en este segmento'))));
        return;
      }
      for (final cliente in conWA) {
        final msg = (plantilla['cuerpo'] as String? ?? '')
          .replaceAll('*NOMBRE*', cliente.nombre)
          .replaceAll('[Nombre]', cliente.nombre);
        await SupabaseService.agregarAColaMarketing(
          clienteId: cliente.id!,
          mensajeFinal: msg,
          plantillaId: plantilla['id'] as String?,
          campana: campana['nombre'] as String? ?? '',
        );
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(trf('✅ {0} mensajes de "{1}" agregados a la cola', [(conWA.length), (campana['nombre'])])),
        backgroundColor: AppColors.verde));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    }
  }

  Future<void> _lanzarRapido(Map<String, dynamic> seg) async {
    if (_plantillas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Crea una plantilla primero en la pestaña Plantillas'))));
      return;
    }
    Map<String, dynamic>? plantillaSel;
    int limite = 20;
    final ok = await showModalBottomSheet<bool>(context: context,
      isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Container(
        height: MediaQuery.of(ctx).size.height * 0.65,
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          Container(padding: const EdgeInsets.fromLTRB(16,16,8,12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
            child: Row(children: [
              Expanded(child: Text('Lanzar: ${seg['nombre']}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx, false)),
            ])),
          Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
            Text(tr('Selecciona plantilla:'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._plantillas.map((p) {
              final sel = plantillaSel?['id'] == p['id'];
              return GestureDetector(
                onTap: () => setS(() => plantillaSel = p),
                child: Container(margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.azulClaro : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde, width: sel ? 1.5 : 0.5)),
                  child: Row(children: [
                    Icon(sel ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 16, color: sel ? AppColors.azul : AppColors.textoSecundario),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tr(p['titulo'] as String? ?? ''),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: sel ? AppColors.azul : AppColors.textoPrincipal))),
                  ])));
            }),
            const SizedBox(height: 12),
            Text(tr('Mensajes a enviar hoy:'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [5, 10, 20, 30, 50].map((n) {
              final sel = limite == n;
              return GestureDetector(
                onTap: () => setS(() => limite = n),
                child: Container(width: 52, height: 38,
                  decoration: BoxDecoration(
                    color: sel ? AppColors.azul : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde)),
                  child: Center(child: Text('$n',
                    style: TextStyle(fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : AppColors.textoSecundario)))));
            }).toList()),
          ])),
          Container(padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: plantillaSel == null ? null : () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.azul,
                  disabledBackgroundColor: AppColors.grisBorde,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: Text(tr(plantillaSel == null ? tr('Selecciona plantilla') : trf('Agregar {0} a la cola', [limite])),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))),
        ]))));
    if (ok != true || plantillaSel == null) return;
    try {
      final clientes = await SupabaseService.getClientesPorSegmento(seg['key'] as String);
      final conWA = clientes.where((c) => c.whatsappNumero.isNotEmpty).take(limite).toList();
      if (conWA.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trf('Sin clientes con WA en "{0}"', [(seg['nombre'])]))));
        return;
      }
      for (final cliente in conWA) {
        final msg = (plantillaSel!['cuerpo'] as String? ?? '')
          .replaceAll('*NOMBRE*', cliente.nombre)
          .replaceAll('[Nombre]', cliente.nombre);
        await SupabaseService.agregarAColaMarketing(
          clienteId: cliente.id!, mensajeFinal: msg,
          plantillaId: plantillaSel!['id'] as String?,
          campana: '${seg['nombre']} — ${plantillaSel!['titulo']}');
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(trf('✅ {0} mensajes agregados a la cola', [(conWA.length)])),
        backgroundColor: AppColors.verde));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _cargando
      ? const Center(child: CircularProgressIndicator())
      : Column(children: [
          // ── Botón nueva campaña ──
          Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _editarCampana(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(tr('+ Nueva campaña'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.azul,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
          const SizedBox(height: 8),

          // ── Lista de campañas guardadas ──
          Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
            if (_campanas.isNotEmpty) ...[
              Text(tr('MIS CAMPAÑAS'), style: TextStyle(fontSize: 10,
                color: AppColors.textoSecundario, letterSpacing: 1, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._campanas.map((camp) {
                final segKey = camp['segmento_key'] as String? ?? '';
                final seg = _segmentos.firstWhere(
                  (s) => s['key'] == segKey, orElse: () => _segmentos.last);
                final color = seg['color'] as Color;
                final plantilla = _plantillas.firstWhere(
                  (p) => p['id'] == camp['plantilla_id'],
                  orElse: () => <String, dynamic>{});
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.grisBorde, width: 0.5)),
                  child: Column(children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Container(width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                        child: Icon(seg['icon'] as IconData, color: color, size: 20)),
                      title: Text(tr(camp['nombre'] as String? ?? ''),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr(seg['nombre'] as String),
                          style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                        if (plantilla.isNotEmpty)
                          Text('📝 ${plantilla['titulo'] ?? ''}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                        Text(trf('📬 {0} mensajes/día', [(camp['limite_diario'] ?? 20)]),
                          style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                      ]),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (v) async {
                          if (v == 'editar') _editarCampana(camp);
                          if (v == 'eliminar') _eliminarCampana(camp);
                          if (v == 'lanzar') _lanzarCampanaGuardada(camp);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'lanzar',
                            child: Row(children: [Icon(Icons.send, size: 16, color: AppColors.verde), SizedBox(width: 8), Text(tr('Lanzar ahora'))])),
                          PopupMenuItem(value: 'editar',
                            child: Row(children: [Icon(Icons.edit_outlined, size: 16, color: AppColors.azul), SizedBox(width: 8), Text(tr('Editar'))])),
                          PopupMenuItem(value: 'eliminar',
                            child: Row(children: [Icon(Icons.delete_outline, size: 16, color: AppColors.rojo), SizedBox(width: 8), Text(tr('Eliminar'), style: TextStyle(color: AppColors.rojo))])),
                        ]),
                    ),
                  ]));
              }),
              const SizedBox(height: 14),
            ],

            // ── Segmentos rápidos ──
            Text(tr('LANZAMIENTO RÁPIDO'), style: TextStyle(fontSize: 10,
              color: AppColors.textoSecundario, letterSpacing: 1, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.azul.withOpacity(0.2))),
              child: Row(children: [
                Icon(Icons.info_outline, color: AppColors.azul, size: 14),
                SizedBox(width: 6),
                Expanded(child: Text(tr('Lanza una campaña directa sin guardarla.'),
                  style: TextStyle(fontSize: 11, color: AppColors.azul))),
              ])),
            const SizedBox(height: 8),
            ..._segmentos.map((seg) {
              final color = seg['color'] as Color;
              return Container(margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.grisBorde, width: 0.5)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(seg['icon'] as IconData, color: color, size: 18)),
                  title: Text(tr(seg['nombre'] as String),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  subtitle: Text(tr(seg['desc'] as String),
                    style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
                  trailing: GestureDetector(
                    onTap: () => _lanzarRapido(seg),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(tr('Lanzar'), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700))))));
            }),
            const SizedBox(height: 20),
          ])),
        ]);
  }
}

// ══════════════════════════════════════════════
// TAB 3 — PLANTILLAS DE MENSAJES
// ══════════════════════════════════════════════
class _PlantillasTab extends StatefulWidget {
  const _PlantillasTab();
  @override
  State<_PlantillasTab> createState() => _PlantillasTabState();
}

class _PlantillasTabState extends State<_PlantillasTab> {
  List<Map<String, dynamic>> _plantillas = [];
  bool _cargando = true;

  final _categorias = ['General', 'Cotizacion', 'Pedido', 'Promocion', 'Seguimiento'];
  final _coloresCat = {
    'General'    : AppColors.azul,
    'Cotizacion' : const Color(0xFF7c3aed),
    'Pedido'     : AppColors.verde,
    'Promocion'  : AppColors.ambar,
    'Seguimiento': AppColors.rojo,
  };

  // Los "tipos" específicos que el código busca automáticamente. Sin
  // elegir uno de estos, la plantilla queda como texto de referencia
  // general (útil para campañas manuales) pero NUNCA se dispara sola.
  final _tiposAutomaticos = <String, String>{
    '': 'Ninguno (plantilla de uso general / campañas)',
    'seguimiento_dia3': 'Seguimiento — Día 3 sin respuesta',
    'seguimiento_dia5': 'Seguimiento — Día 5 sin respuesta',
    'seguimiento_dia7': 'Seguimiento — Día 7 sin respuesta',
    'post_entrega': 'Seguimiento — Después de entregar',
    'pago_anticipo_pendiente': 'Seguimiento — Anticipo pendiente',
    'pago_final_pendiente': 'Seguimiento — Pago final pendiente',
    'cliente_interesado': 'Seguimiento — Cliente interesado',
    'produccion_sin_avance': 'Seguimiento — Producción sin avance',
    'avance_pago50': 'Avance de pedido — Pago 50% recibido',
    'avance_produccion': 'Avance de pedido — Entró a producción',
    'avance_pruebas': 'Avance de pedido — En control de calidad',
    'avance_pagocompleto': 'Avance de pedido — Listo, falta pago',
    'avance_entrega': 'Avance de pedido — Listo para entrega',
    'avance_entregado': 'Avance de pedido — Entregado',
    'avance_cancelado': 'Avance de pedido — Cancelado',
  };

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final p = await SupabaseService.getPlantillasWA();
      if (mounted) setState(() { _plantillas = p; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  Future<void> _editar([Map<String, dynamic>? plantilla]) async {
    final tituloCtrl = TextEditingController(text: plantilla?['titulo'] as String? ?? '');
    final cuerpoCtrl = TextEditingController(text: plantilla?['cuerpo'] as String? ?? '');
    String cat = plantilla?['categoria'] as String? ?? tr('General');
    String tipoSel = plantilla?['tipo'] as String? ?? '';
    if (!_tiposAutomaticos.containsKey(tipoSel)) tipoSel = '';

    final ok = await showModalBottomSheet<bool>(context: context,
      isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) =>
        Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(tr(plantilla == null ? tr('Nueva plantilla') : tr('Editar plantilla')),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx, false)),
              ]),
              const SizedBox(height: 12),
              TextField(controller: tituloCtrl,
                decoration: InputDecoration(labelText: tr('Título *'), border: OutlineInputBorder())),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(value: cat,
                decoration: InputDecoration(labelText: tr('Categoría'), border: OutlineInputBorder()),
                items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(tr(c)))).toList(),
                onChanged: (v) => setS(() => cat = v!)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(value: tipoSel,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('¿Para qué mensaje automático es? (opcional)'),
                  border: OutlineInputBorder()),
                items: _tiposAutomaticos.entries.map((e) => DropdownMenuItem(
                  value: e.key, child: Text(tr(e.value), style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setS(() => tipoSel = v ?? '')),
              const SizedBox(height: 4),
              Text(tr('Si eliges una opción distinta a "Ninguno", este mensaje reemplaza el texto por defecto justo en ese momento automático (ej. cuando el pedido pasa a producción).'),
                style: TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
              const SizedBox(height: 8),
              TextField(controller: cuerpoCtrl, maxLines: 4,
                decoration: InputDecoration(
                  labelText: tr('Mensaje'),
                  hintText: tr('Variables: escribe NOMBRE FOLIO MONTO FECHA en mayúsculas rodeadas de *'),
                  border: OutlineInputBorder())),
              const SizedBox(height: 4),
              Text(tr('Variables: *NOMBRE* *FOLIO* *MONTO* *FECHA* — y en mensajes de avance también *ANTICIPO* y *RESTANTE* (en mayúsculas entre asteriscos)'),
                style: TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Capturar valores ANTES de cerrar el sheet
                    final titulo = tituloCtrl.text.trim();
                    final cuerpo = cuerpoCtrl.text.trim();
                    final categoria = cat;
                    final tipo = tipoSel;
                    if (titulo.isEmpty || cuerpo.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(tr('Completa el título y el mensaje'))));
                      return;
                    }
                    Navigator.pop(ctx, true);
                    try {
                      await SupabaseService.guardarPlantillaWA({
                        if (plantilla != null) 'id': plantilla['id'],
                        'titulo'   : titulo,
                        'cuerpo'   : cuerpo,
                        'categoria': categoria,
                        'tipo'     : tipo.isEmpty ? null : tipo,
                        'activo'   : true,
                      });
                      await _cargar();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(tr('✅ Plantilla guardada')), backgroundColor: AppColors.verde));
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.rojo));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul),
                  child: Text(tr('Guardar'), style: TextStyle(color: Colors.white)))),
            ]))))));

    if (ok != true) return;
    // Lógica ya ejecutada dentro del onPressed arriba
  }

  Future<void> _eliminar(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('Eliminar plantilla')),
        content: Text(trf('¿Eliminar "{0}"?', [(p['titulo'])])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Cancelar'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
            child: Text(tr('Eliminar'), style: TextStyle(color: Colors.white))),
        ]));
    if (ok != true) return;
    await SupabaseService.eliminarPlantillaWA(p['id']);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(14),
        child: SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _editar(),
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(tr('Nueva plantilla'), style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul,
              padding: const EdgeInsets.symmetric(vertical: 11))))),
      Expanded(child: _cargando
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _cargar,
            child: _plantillas.isEmpty
              ? Center(child: Text(tr('Sin plantillas. Crea la primera.'),
                  style: TextStyle(color: AppColors.textoSecundario)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  itemCount: _plantillas.length,
                  itemBuilder: (_, i) {
                    final p = _plantillas[i];
                    final cat = p['categoria'] as String? ?? tr('General');
                    final color = _coloresCat[cat] ?? AppColors.azul;
                    return Container(margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
                      child: Padding(padding: const EdgeInsets.all(12), child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20)),
                            child: Text(tr(cat), style: TextStyle(fontSize: 9, color: color,
                              fontWeight: FontWeight.w700))),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.edit_outlined, size: 16,
                            color: AppColors.textoSecundario),
                            onPressed: () => _editar(p),
                            padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                          const SizedBox(width: 4),
                          IconButton(icon: const Icon(Icons.delete_outline, size: 16,
                            color: AppColors.rojo),
                            onPressed: () => _eliminar(p),
                            padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                        ]),
                        const SizedBox(height: 6),
                        Text(tr(p['titulo'] as String? ?? ''),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Container(padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.gris,
                            borderRadius: BorderRadius.circular(8),
                            border: Border(left: BorderSide(color: color, width: 3))),
                          child: Text(tr(p['cuerpo'] as String? ?? ''),
                            style: const TextStyle(fontSize: 11, height: 1.5, color: AppColors.azul))),
                      ])));
                  }))),
    ]);
  }
}

// ── Tab configuración WhatsApp (plantillas editables) ──
class _ConfigWaTab extends StatelessWidget {
  const _ConfigWaTab();
  @override
  Widget build(BuildContext context) {
    return const PlantillasWaScreen();
  }
}
