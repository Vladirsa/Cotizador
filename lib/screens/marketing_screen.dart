import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_service.dart';

class MarketingScreen extends StatefulWidget {
  const MarketingScreen({super.key});
  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: const Text('Marketing'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Campañas'),
            Tab(text: 'Segmentar'),
            Tab(text: 'Mensajes'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        const _CampanasTab(),
        const _SegmentarTab(),
        const _MensajesTab(),
      ]),
    );
  }
}

// ─── CAMPAÑAS ───────────────────────────────
class _CampanasTab extends StatelessWidget {
  const _CampanasTab();

  @override
  Widget build(BuildContext context) {
    final campanas = [
      _Campana(
        titulo: 'Seguimiento cotización vencida',
        descripcion: 'Clientes con cotización sin respuesta hace 3+ días',
        segmento: 'Cotizaciones pendientes',
        color: AppColors.rojo,
        icon: Icons.access_time,
        mensaje: 'Hola [Nombre], tu cotización No. [Folio] está próxima a vencer. ¿Podemos ajustar algo para ayudarte a decidir? — HETNA CNC',
      ),
      _Campana(
        titulo: 'Promoción fresas para MDF',
        descripcion: 'Clientes que compraron Router CNC',
        segmento: 'Compraron Router CNC',
        color: AppColors.verde,
        icon: Icons.local_offer,
        mensaje: 'Hola [Nombre], tenemos disponibles fresas para MDF con envío inmediato. ¿Te interesa conocer precios? — HETNA CNC',
      ),
      _Campana(
        titulo: 'Recordatorio de mantenimiento',
        descripcion: 'Clientes con más de 6 meses sin compra',
        segmento: 'Clientes inactivos',
        color: AppColors.ambar,
        icon: Icons.build_outlined,
        mensaje: 'Hola [Nombre], ¿cómo va tu equipo CNC? Si necesitas refacciones o servicio de mantenimiento, estamos a tus órdenes. — HETNA CNC',
      ),
      _Campana(
        titulo: 'Nuevo curso Router CNC',
        descripcion: 'Todos los clientes activos',
        segmento: 'Clientes activos',
        color: const Color(0xFF7c3aed),
        icon: Icons.school_outlined,
        mensaje: 'Hola [Nombre], te invitamos a nuestro nuevo curso de operación de Router CNC. Cupos limitados. ¿Te interesa más información? — HETNA CNC',
      ),
      _Campana(
        titulo: 'Recompra de consumibles',
        descripcion: 'Compraron consumibles hace 30+ días',
        segmento: 'Compraron consumibles',
        color: AppColors.azul,
        icon: Icons.refresh,
        mensaje: 'Hola [Nombre], ¿ya se te terminaron los consumibles? Tenemos stock disponible con envío rápido. — HETNA CNC',
      ),
    ];

    return ListView(padding: const EdgeInsets.all(14), children: [
      Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.azul.withOpacity(0.2))),
        child: const Row(children: [
          Icon(Icons.info_outline, color: AppColors.azul, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('Cada campaña abre WhatsApp con el mensaje prellenado para cada cliente. Tú decides si envías o ajustas antes de mandar.',
            style: TextStyle(fontSize: 12, color: AppColors.azul))),
        ])),
      const SizedBox(height: 12),
      ...campanas.map((c) => _TarjetaCampana(campana: c)),
    ]);
  }
}

class _Campana {
  final String titulo, descripcion, segmento, mensaje;
  final Color color;
  final IconData icon;
  const _Campana({required this.titulo, required this.descripcion, required this.segmento, required this.color, required this.icon, required this.mensaje});
}

class _TarjetaCampana extends StatelessWidget {
  final _Campana campana;
  const _TarjetaCampana({required this.campana});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: campana.color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(campana.icon, color: campana.color, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(campana.titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(campana.descripcion, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            ])),
          ]),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: campana.color, width: 2))),
            child: Text(campana.mensaje, style: const TextStyle(fontSize: 11, color: AppColors.azul, height: 1.5))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _verClientes(context),
              icon: const Icon(Icons.people_outline, size: 16),
              label: Text('Ver ${campana.segmento}', style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.azul, side: const BorderSide(color: AppColors.azul)),
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _lanzarCampana(context),
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Lanzar', style: TextStyle(fontSize: 12)),
            )),
          ]),
        ]),
      ),
    );
  }

  void _verClientes(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cargando clientes: ${campana.segmento}...')));
  }

  void _lanzarCampana(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(campana.titulo),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Se abrirá WhatsApp para cada cliente con el mensaje prellenado.', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(8)),
          child: Text(campana.mensaje, style: const TextStyle(fontSize: 12))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abriendo WhatsApp para primer cliente...')));
          },
          child: const Text('Iniciar campaña'),
        ),
      ],
    ));
  }
}

// ─── SEGMENTACIÓN ────────────────────────────
class _SegmentarTab extends StatefulWidget {
  const _SegmentarTab();
  @override
  State<_SegmentarTab> createState() => _SegmentarTabState();
}

class _SegmentarTabState extends State<_SegmentarTab> {
  final _segmentos = [
    {'nombre': 'Compraron Router CNC', 'icono': Icons.precision_manufacturing, 'color': AppColors.azul, 'cantidad': 0},
    {'nombre': 'Compraron Láser CO₂', 'icono': Icons.highlight, 'color': AppColors.rojo, 'cantidad': 0},
    {'nombre': 'Compraron Plasma CNC', 'icono': Icons.flash_on, 'color': AppColors.ambar, 'cantidad': 0},
    {'nombre': 'Compran refacciones', 'icono': Icons.settings, 'color': AppColors.verde, 'cantidad': 0},
    {'nombre': 'Clientes inactivos +6 meses', 'icono': Icons.person_off_outlined, 'color': Colors.grey, 'cantidad': 0},
    {'nombre': 'Cotizaciones sin respuesta', 'icono': Icons.pending_actions, 'color': const Color(0xFF7c3aed), 'cantidad': 0},
    {'nombre': 'Clientes frecuentes', 'icono': Icons.star_outline, 'color': AppColors.ambar, 'cantidad': 0},
    {'nombre': 'Distribuidores', 'icono': Icons.store_outlined, 'color': AppColors.azul, 'cantidad': 0},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(14), children: [
      const Text('Selecciona un segmento para ver los clientes y enviarles un mensaje personalizado.',
        style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
      const SizedBox(height: 12),
      ..._segmentos.map((s) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: ListTile(
          leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: (s['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(s['icono'] as IconData, color: s['color'] as Color, size: 18)),
          title: Text(s['nombre'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          subtitle: Text('${s['cantidad']} clientes', style: const TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textoSecundario),
          onTap: () => _verSegmento(context, s['nombre'] as String),
        ),
      )),
    ]);
  }

  void _verSegmento(BuildContext context, String nombre) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cargando: $nombre')));
  }
}

// ─── MENSAJES PREDISEÑADOS ──────────────────
class _MensajesTab extends StatefulWidget {
  const _MensajesTab();
  @override
  State<_MensajesTab> createState() => _MensajesTabState();
}

class _MensajesTabState extends State<_MensajesTab> {
  final _mensajes = [
    {'titulo': 'Bienvenida cliente nuevo', 'cuerpo': 'Hola [Nombre], bienvenido a HETNA CNC. Somos especialistas en maquinaria CNC, refacciones y servicios. ¿En qué podemos ayudarte?'},
    {'titulo': 'Seguimiento cotización 3 días', 'cuerpo': 'Hola [Nombre], ¿pudiste revisar la cotización No. [Folio]? Quedo atento para cualquier ajuste. — HETNA CNC'},
    {'titulo': 'Cotización por vencer', 'cuerpo': 'Hola [Nombre], tu cotización No. [Folio] vence en 2 días. ¿Hay algo que podamos ajustar? — HETNA CNC'},
    {'titulo': 'Cupón de descuento', 'cuerpo': 'Hola [Nombre], como cliente especial te compartimos un 5% de descuento. Código: [CUPON]. Válido esta semana. — HETNA CNC'},
    {'titulo': 'Pedido en producción', 'cuerpo': 'Hola [Nombre], tu pedido No. [Folio] está en producción. Fecha estimada de entrega: [Fecha]. — HETNA CNC'},
    {'titulo': 'Pedido listo para entrega', 'cuerpo': 'Hola [Nombre], tu equipo está listo. ¿Cuándo podemos coordinar la entrega? — HETNA CNC'},
    {'titulo': 'Post-venta satisfacción', 'cuerpo': 'Hola [Nombre], ¿cómo va tu nuevo equipo? Si tienes alguna duda o necesitas capacitación, estamos a tus órdenes. — HETNA CNC'},
    {'titulo': 'Invitación redes sociales', 'cuerpo': 'Hola [Nombre], síguenos en Instagram @hetna_cnc para ver proyectos, novedades y promociones. ¡Al seguirnos: 3% en tu próxima compra! 🎁'},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(14), children: [
      ..._mensajes.map((m) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m['titulo']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(6),
            border: const Border(left: BorderSide(color: Color(0xFF25D366), width: 2))),
            child: Text(m['cuerpo']!, style: const TextStyle(fontSize: 11, height: 1.5))),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(
              onPressed: () => _editarMensaje(context, m),
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Editar', style: TextStyle(fontSize: 12)),
            ),
            ElevatedButton.icon(
              onPressed: () => _usarMensaje(context, m['cuerpo']!),
              icon: const Icon(Icons.send, size: 14),
              label: const Text('Usar', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            ),
          ]),
        ]),
      )),
    ]);
  }

  void _editarMensaje(BuildContext context, Map<String, String> mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Editor de mensaje próximamente')));
  }

  void _usarMensaje(BuildContext context, String cuerpo) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Selecciona un cliente para enviar este mensaje'),
      action: SnackBarAction(label: 'Ir a Clientes', onPressed: () {}),
    ));
  }
}
