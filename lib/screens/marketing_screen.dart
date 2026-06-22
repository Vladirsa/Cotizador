// ============================================
// lib/screens/marketing_screen.dart
// ============================================
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

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
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: const Text('Marketing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.inbox_outlined, size: 16), text: 'Cola de hoy'),
            Tab(icon: Icon(Icons.people_outline, size: 16), text: 'Campañas'),
            Tab(icon: Icon(Icons.message_outlined, size: 16), text: 'Plantillas'),
          ]),
      ),
      body: TabBarView(controller: _tabs, children: [
        const _ColaTab(),
        const _CampanasTab(),
        const _PlantillasTab(),
      ]));
  }
}

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ Límite diario alcanzado (5 mensajes). Continúa mañana.'),
        backgroundColor: AppColors.ambar));
      return;
    }
    final cl = msg['clientes'] as Map<String, dynamic>?;
    final wa = cl?['whatsapp'] as String? ?? cl?['telefono'] as String? ?? '';
    if (wa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Este cliente no tiene WhatsApp registrado')));
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
          title: const Text('¿Enviaste el mensaje?', style: TextStyle(fontSize: 15)),
          content: const Text('Confirma si el mensaje fue enviado exitosamente.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('No enviado')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
              child: const Text('Sí, enviado', style: TextStyle(color: Colors.white))),
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
                  Text(restantes > 0
                    ? 'Puedes enviar $restantes mensaje${restantes != 1 ? "s" : ""} hoy'
                    : 'Límite diario alcanzado',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: restantes > 0 ? AppColors.azul : AppColors.rojo)),
                ]),
                Text('$_enviadosHoy/$_limitesDiario enviados',
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
                const Text('No hay mensajes pendientes para hoy',
                  style: TextStyle(color: AppColors.textoSecundario)),
                const SizedBox(height: 6),
                const Text('Ve a Campañas para agregar mensajes a la cola',
                  style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _cargar,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Actualizar'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.azul,
                    side: const BorderSide(color: AppColors.azul))),
              ]))
          else ...[
            Text('${_cola.length} mensaje${_cola.length != 1 ? "s" : ""} pendientes',
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
            const Text('HISTORIAL RECIENTE', style: TextStyle(fontSize: 10,
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
                    Text(cl?['nombre'] as String? ?? '—',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    Text(msg['campana'] as String? ?? 'Sin campaña',
                      style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
                  ])),
                  Text(enviado ? 'Enviado' : 'Omitido',
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
            child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700, fontSize: 13))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            if (campana.isNotEmpty)
              Text(campana, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF25D366).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
            child: const Text('Pendiente',
              style: TextStyle(fontSize: 9, color: Color(0xFF25D366), fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(8),
            border: const Border(left: BorderSide(color: Color(0xFF25D366), width: 3))),
          child: Text(mensaje, style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.azul))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: onOmitir,
            icon: const Icon(Icons.skip_next_outlined, size: 14),
            label: const Text('Omitir', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textoSecundario,
              side: const BorderSide(color: AppColors.grisBorde),
              padding: const EdgeInsets.symmetric(vertical: 8)))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: ElevatedButton.icon(
            onPressed: puedeEnviar ? onEnviar : null,
            icon: const Icon(Icons.send, size: 14, color: Colors.white),
            label: const Text('Enviar por WhatsApp', style: TextStyle(fontSize: 12, color: Colors.white)),
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
  bool _cargando = true;

  final _segmentos = [
    {'key': 'activos', 'nombre': 'Clientes activos', 'icon': Icons.person_outline, 'color': AppColors.verde},
    {'key': 'potenciales', 'nombre': 'Clientes potenciales', 'icon': Icons.person_add_outlined, 'color': AppColors.ambar},
    {'key': 'frecuentes', 'nombre': 'Clientes frecuentes', 'icon': Icons.star_outline, 'color': const Color(0xFF7c3aed)},
    {'key': 'cotizaciones_pendientes', 'nombre': 'Cotizaciones sin respuesta', 'icon': Icons.pending_actions_outlined, 'color': AppColors.rojo},
    {'key': 'todos', 'nombre': 'Todos los clientes', 'icon': Icons.people_outline, 'color': AppColors.azul},
  ];

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final plantillas = await SupabaseService.getPlantillasWA();
      if (mounted) setState(() { _plantillas = plantillas; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  Future<void> _lanzarCampana(Map<String, dynamic> seg) async {
    if (_plantillas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay plantillas disponibles. Crea una en la pestaña Plantillas.')));
      return;
    }

    Map<String, dynamic>? plantillaSel;
    int limite = 5;

    final ok = await showModalBottomSheet<bool>(context: context,
      isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) =>
        Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            Container(padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Campaña: ${seg['nombre']}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx, false)),
                ]),
                const SizedBox(height: 8),
                const Text('1. Selecciona una plantilla de mensaje:',
                  style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
              ])),
            Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
              ..._plantillas.map((p) {
                final sel = plantillaSel?['id'] == p['id'];
                return GestureDetector(
                  onTap: () => setS(() => plantillaSel = p),
                  child: Container(margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.azulClaro : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde,
                        width: sel ? 1.5 : 0.5)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 16, color: sel ? AppColors.azul : AppColors.textoSecundario),
                        const SizedBox(width: 8),
                        Expanded(child: Text(p['titulo'] as String? ?? '',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: sel ? AppColors.azul : AppColors.textoPrincipal))),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.azul.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20)),
                          child: Text(p['categoria'] as String? ?? '',
                            style: const TextStyle(fontSize: 9, color: AppColors.azul))),
                      ]),
                      if (sel) ...[
                        const SizedBox(height: 8),
                        Container(padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.gris,
                            borderRadius: BorderRadius.circular(6)),
                          child: Text(p['cuerpo'] as String? ?? '',
                            style: const TextStyle(fontSize: 11, height: 1.5))),
                      ],
                    ])));
              }),
              const SizedBox(height: 12),
              const Text('2. Límite de mensajes a agregar hoy:',
                style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children:
                [2, 3, 4, 5].map((n) {
                  final sel = limite == n;
                  return GestureDetector(
                    onTap: () => setS(() => limite = n),
                    child: Container(margin: const EdgeInsets.only(right: 8),
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: sel ? AppColors.azul : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde)),
                      child: Center(child: Text('$n',
                        style: TextStyle(fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : AppColors.textoSecundario)))));
                }).toList()),
            ])),
            Container(padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
              child: SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: plantillaSel == null ? null : () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.add_task, color: Colors.white),
                  label: Text(plantillaSel == null
                    ? 'Selecciona una plantilla'
                    : 'Agregar $limite mensajes a la cola',
                    style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azul,
                    disabledBackgroundColor: AppColors.grisBorde,
                    padding: const EdgeInsets.symmetric(vertical: 12))))),
          ]))));

    if (ok != true || plantillaSel == null) return;

    // Cargar clientes del segmento y agregar a la cola
    try {
      final clientes = await SupabaseService.getClientesPorSegmento(seg['key'] as String);
      final clientesConWA = clientes.where((c) => c.whatsappNumero.isNotEmpty).take(limite).toList();

      if (clientesConWA.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No hay clientes con WhatsApp en "${seg['nombre']}"')));
        return;
      }

      for (final cliente in clientesConWA) {
        final cuerpo = (plantillaSel!['cuerpo'] as String? ?? '')
            .replaceAll('*NOMBRE*', cliente.nombre)
            .replaceAll('[Nombre]', cliente.nombre);  // compatibilidad
        await SupabaseService.agregarAColaMarketing(
          clienteId: cliente.id!,
          mensajeFinal: cuerpo,
          plantillaId: plantillaSel!['id'] as String?,
          campana: '${seg['nombre']} — ${plantillaSel!['titulo']}',
        );
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ ${clientesConWA.length} mensajes agregados a la cola de hoy'),
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
      : ListView(padding: const EdgeInsets.all(14), children: [
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.azul.withOpacity(0.2))),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppColors.azul, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Selecciona un segmento, elige el mensaje y agrégalo a la cola del día. Máximo 5 mensajes diarios para evitar bloqueos.',
                style: TextStyle(fontSize: 11, color: AppColors.azul))),
            ])),
          const SizedBox(height: 14),
          const Text('SEGMENTOS', style: TextStyle(fontSize: 10,
            color: AppColors.textoSecundario, letterSpacing: 1, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._segmentos.map((seg) {
            final color = seg['color'] as Color;
            return Container(margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.grisBorde, width: 0.5)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                  child: Icon(seg['icon'] as IconData, color: color, size: 20)),
                title: Text(seg['nombre'] as String,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Toca para crear campaña',
                  style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text('Lanzar',
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700))),
                onTap: () => _lanzarCampana(seg)));
          }),
          const SizedBox(height: 20),
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
    String cat = plantilla?['categoria'] as String? ?? 'General';

    final ok = await showModalBottomSheet<bool>(context: context,
      isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) =>
        Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(plantilla == null ? 'Nueva plantilla' : 'Editar plantilla',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx, false)),
              ]),
              const SizedBox(height: 12),
              TextField(controller: tituloCtrl,
                decoration: const InputDecoration(labelText: 'Título *', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(value: cat,
                decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setS(() => cat = v!)),
              const SizedBox(height: 8),
              TextField(controller: cuerpoCtrl, maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Mensaje',
                  hintText: 'Variables: escribe NOMBRE FOLIO MONTO FECHA en mayúsculas rodeadas de *',
                  border: OutlineInputBorder())),
              const SizedBox(height: 4),
              const Text('Variables: *NOMBRE* *FOLIO* *MONTO* *FECHA* (en mayúsculas entre asteriscos)',
                style: TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul),
                  child: const Text('Guardar', style: TextStyle(color: Colors.white)))),
            ])))));

    if (ok != true) return;
    if (tituloCtrl.text.trim().isEmpty || cuerpoCtrl.text.trim().isEmpty) return;

    try {
      await SupabaseService.guardarPlantillaWA({
        if (plantilla != null) 'id': plantilla['id'],
        'titulo'   : tituloCtrl.text.trim(),
        'cuerpo'   : cuerpoCtrl.text.trim(),
        'categoria': cat,
      });
      await _cargar();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Plantilla guardada'), backgroundColor: AppColors.verde));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    }
  }

  Future<void> _eliminar(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar plantilla'),
        content: Text('¿Eliminar "${p['titulo']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white))),
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
            label: const Text('Nueva plantilla', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul,
              padding: const EdgeInsets.symmetric(vertical: 11))))),
      Expanded(child: _cargando
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _cargar,
            child: _plantillas.isEmpty
              ? const Center(child: Text('Sin plantillas. Crea la primera.',
                  style: TextStyle(color: AppColors.textoSecundario)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  itemCount: _plantillas.length,
                  itemBuilder: (_, i) {
                    final p = _plantillas[i];
                    final cat = p['categoria'] as String? ?? 'General';
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
                            child: Text(cat, style: TextStyle(fontSize: 9, color: color,
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
                        Text(p['titulo'] as String? ?? '',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Container(padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.gris,
                            borderRadius: BorderRadius.circular(8),
                            border: Border(left: BorderSide(color: color, width: 3))),
                          child: Text(p['cuerpo'] as String? ?? '',
                            style: const TextStyle(fontSize: 11, height: 1.5, color: AppColors.azul))),
                      ])));
                  }))),
    ]);
  }
}
