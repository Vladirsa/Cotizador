import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_service.dart';
import '../services/pdf_service.dart';
import '../services/auth_service.dart';
import 'factura_screen.dart';
import 'envios_screen.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../i18n/tr.dart';

class AvancesScreen extends StatefulWidget {
  const AvancesScreen({super.key});
  @override
  State<AvancesScreen> createState() => _AvancesScreenState();
}

class _AvancesScreenState extends State<AvancesScreen> {
  List<Pedido> _pedidos = [];
  bool _cargando = true;
  String _filtro = 'Activos';
  String _busqueda = '';
  DateTimeRange? _rangoFechas;
  final _busquedaCtrl = TextEditingController();

  static const _etapas = ['Pedido', 'Pago50', 'Produccion', 'Pruebas', 'PagoCompleto', 'Entrega', 'Entregado'];
  static const _etiquetas = {
    'Pedido': 'Pedido recibido',
    'Pago50': 'Anticipo recibido',
    'Produccion': 'En producción',
    'Pruebas': 'Control de calidad',
    'PagoCompleto': 'Pago 100% completado',
    'Entrega': 'Listo para entrega',
    'Entregado': 'Entregado ✅',
    'Cancelado': 'Cancelado ❌',
  };
  static const _coloresEtapa = {
    'Pedido': AppColors.azul,
    'Pago50': AppColors.ambar,
    'Produccion': Color(0xFF7c3aed),
    'Pruebas': AppColors.rojo,
    'PagoCompleto': Color(0xFF059669),
    'Entrega': AppColors.verde,
    'Entregado': AppColors.verde,
    'Cancelado': Color(0xFF6b7280),
  };

  final _filtros = ['Activos', 'Pedido', 'Pago50', 'Produccion', 'Pruebas', 'PagoCompleto', 'Entrega', 'Entregado', 'Cancelado', 'Todos'];
  final _etiquetasFiltro = {
    'Pago50': 'Anticipo',
    'Produccion': 'Producción',
    'PagoCompleto': 'Pago 100%',
  };

  @override
  void initState() { super.initState(); _cargar(); }

  @override
  void dispose() { _busquedaCtrl.dispose(); super.dispose(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final pedidos = await SupabaseService.getPedidos();
      if (mounted) setState(() { _pedidos = pedidos; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  List<Pedido> get _filtrados {
    List<Pedido> base;
    switch (_filtro) {
      case 'Activos': base = _pedidos.where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado').toList(); break;
      case 'Todos': base = _pedidos; break;
      default: base = _pedidos.where((p) => p.estado == _filtro).toList();
    }
    // Filtro por búsqueda de nombre de cliente / folio
    if (_busqueda.trim().isNotEmpty) {
      final q = _busqueda.trim().toLowerCase();
      base = base.where((p) {
        final nombre = (p.cliente?.nombre ?? '').toLowerCase();
        final empresa = (p.cliente?.empresa ?? '').toLowerCase();
        final folio = p.folio.toLowerCase();
        return nombre.contains(q) || empresa.contains(q) || folio.contains(q);
      }).toList();
    }
    // Filtro por rango de fechas (usando fecha de creación del pedido)
    if (_rangoFechas != null) {
      base = base.where((p) {
        if (p.createdAt == null) return false;
        final fecha = DateTime(p.createdAt!.year, p.createdAt!.month, p.createdAt!.day);
        final desde = DateTime(_rangoFechas!.start.year, _rangoFechas!.start.month, _rangoFechas!.start.day);
        final hasta = DateTime(_rangoFechas!.end.year, _rangoFechas!.end.month, _rangoFechas!.end.day);
        return !fecha.isBefore(desde) && !fecha.isAfter(hasta);
      }).toList();
    }
    return base;
  }

  int _count(String f) {
    if (f == 'Activos') return _pedidos.where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado').length;
    if (f == 'Todos') return _pedidos.length;
    return _pedidos.where((p) => p.estado == f).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(title: Text(tr('Avances de pedidos')),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)]),
      body: Column(children: [
        // Búsqueda por nombre/folio + filtro de fechas
        Container(color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _busquedaCtrl,
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                hintText: tr('Buscar por cliente o folio...'),
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _busqueda.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() { _busqueda = ''; _busquedaCtrl.clear(); }))
                  : null,
                isDense: true, filled: true, fillColor: AppColors.gris,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none)),
              style: const TextStyle(fontSize: 12))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final rango = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange: _rangoFechas,
                  locale: const Locale('es', 'MX'));
                if (rango != null) setState(() => _rangoFechas = rango);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _rangoFechas != null ? AppColors.azul : AppColors.gris,
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.date_range,
                  size: 18, color: _rangoFechas != null ? Colors.white : AppColors.textoSecundario))),
            if (_rangoFechas != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _rangoFechas = null),
                child: const Icon(Icons.close, size: 16, color: AppColors.rojo)),
            ],
          ])),
        if (_rangoFechas != null)
          Container(width: double.infinity, color: Colors.white,
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
            child: Text(
              '${DateFormat(enIngles ? 'MM/dd/yy' : 'dd/MM/yy').format(_rangoFechas!.start)} - ${DateFormat(enIngles ? 'MM/dd/yy' : 'dd/MM/yy').format(_rangoFechas!.end)}',
              style: const TextStyle(fontSize: 10, color: AppColors.azul, fontWeight: FontWeight.w600))),

        // Filtros por etapa
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: _filtros.map((f) {
              final label = _etiquetasFiltro[f] ?? f;
              final count = _count(f);
              final activo = _filtro == f;
              final color = _coloresEtapa[f] ?? AppColors.azul;
              return GestureDetector(
                onTap: () => setState(() => _filtro = f),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: activo ? color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: activo ? color : AppColors.grisBorde)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(tr(label), style: TextStyle(fontSize: 11,
                      color: activo ? Colors.white : AppColors.textoSecundario,
                      fontWeight: activo ? FontWeight.w700 : FontWeight.normal)),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: activo ? Colors.white.withOpacity(0.3) : color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                        child: Text('$count', style: TextStyle(fontSize: 9,
                          color: activo ? Colors.white : color, fontWeight: FontWeight.w700))),
                    ],
                  ])));
            }).toList()))),

        Expanded(child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _cargar, child: _filtrados.isEmpty
              ? _vacia()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtrados.length,
                  itemBuilder: (_, i) => _TarjetaPedido(
                    pedido: _filtrados[i],
                    etapas: _etapas,
                    etiquetas: _etiquetas,
                    colores: _coloresEtapa,
                    onActualizar: _cargar)))),
      ]),
    );
  }

  Widget _vacia() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.local_shipping_outlined, size: 56, color: AppColors.textoSecundario),
    const SizedBox(height: 12),
    Text(tr(_filtro == 'Activos' ? tr('No hay pedidos activos') : trf('No hay pedidos en "{0}"', [_filtro])),
      style: const TextStyle(color: AppColors.textoSecundario)),
  ]));
}

class _TarjetaPedido extends StatefulWidget {
  final Pedido pedido;
  final List<String> etapas;
  final Map<String, String> etiquetas;
  final Map<String, Color> colores;
  final VoidCallback onActualizar;
  const _TarjetaPedido({required this.pedido, required this.etapas, required this.etiquetas,
    required this.colores, required this.onActualizar});
  @override
  State<_TarjetaPedido> createState() => _TarjetaPedidoState();
}

class _TarjetaPedidoState extends State<_TarjetaPedido> {
  // % de anticipo del taller (Costos del taller); antes el "Resta" era siempre la mitad
  double _anticipoPct = 50;
  @override
  void initState() {
    super.initState();
    WhatsAppService.anticipoPct().then((p) { if (mounted) setState(() => _anticipoPct = p); });
  }
  bool _enviandoWA = false;
  bool _cambiando = false;
  bool _generandoPdf = false;

  int get _idx => widget.etapas.indexOf(widget.pedido.estado).clamp(0, widget.etapas.length - 1);
  double get _progreso => (_idx + 1) / widget.etapas.length;
  bool get _esEntregado => widget.pedido.estado == 'Entregado';
  bool get _cancelado => widget.pedido.estado == 'Cancelado';
  Color get _colorActual => widget.colores[widget.pedido.estado] ?? AppColors.azul;
  String get _etiquetaActual => widget.etiquetas[widget.pedido.estado] ?? widget.pedido.estado;
  String? get _siguienteEtapa => _idx < widget.etapas.length - 1 ? widget.etapas[_idx + 1] : null;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final nombre = widget.pedido.cliente?.nombre ?? widget.pedido.cliente?.empresa ?? tr('Sin cliente');
    final tieneWA = (widget.pedido.cliente?.whatsappNumero ?? '').isNotEmpty;
    final siguienteEtapa = _siguienteEtapa;
    final etiquetaSiguiente = siguienteEtapa != null ? (widget.etiquetas[siguienteEtapa] ?? siguienteEtapa) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(nombre), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            if (widget.pedido.cliente?.empresa != null)
              Text(widget.pedido.cliente!.empresa!, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            Text(widget.pedido.folio, style: const TextStyle(fontSize: 10, color: AppColors.azul)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmt.format(widget.pedido.total ?? 0),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.azul)),
            // Mostrar restante si está en etapa de pago parcial
            if (widget.pedido.total != null && widget.pedido.total! > 0 &&
                (widget.pedido.estado == 'Pago50' || widget.pedido.estado == 'Produccion' ||
                 widget.pedido.estado == 'Pruebas'))
              Text('Resta: ${fmt.format(widget.pedido.total! * (1 - _anticipoPct / 100))}',
                style: const TextStyle(fontSize: 10, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _colorActual.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(tr(_etiquetaActual), style: TextStyle(fontSize: 10, color: _colorActual, fontWeight: FontWeight.w700))),
          ]),
        ]),

        const SizedBox(height: 10),

        // Barra de progreso
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: _progreso, backgroundColor: AppColors.gris, minHeight: 6,
          valueColor: AlwaysStoppedAnimation(_esEntregado ? AppColors.verde : _colorActual))),
        const SizedBox(height: 4),

        // Etapas compactas
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
          children: widget.etapas.asMap().entries.map((e) {
            final i = e.key;
            final etapa = e.value;
            final esActual = i == _idx;
            final pasada = i < _idx;
            final color = widget.colores[etapa] ?? AppColors.azul;
            final etiquetaCorta = {
              'Pedido': 'Pedido', 'Pago50': 'Anticipo', 'Produccion': 'Prod.',
              'Pruebas': 'QC', 'PagoCompleto': 'Pago 100%', 'Entrega': 'Entrega', 'Entregado': '✅',
            }[etapa] ?? etapa;
            return Padding(padding: const EdgeInsets.only(right: 8), child: Column(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: esActual ? color : (pasada ? AppColors.verde.withOpacity(0.6) : Colors.grey.shade300))),
              const SizedBox(height: 2),
              Text(tr(etiquetaCorta), style: TextStyle(fontSize: 8,
                color: esActual ? color : (pasada ? AppColors.verde : AppColors.textoSecundario),
                fontWeight: esActual ? FontWeight.w700 : FontWeight.normal)),
            ]));
          }).toList())),

        const SizedBox(height: 10),

        // Aviso de cancelado
        if (_cancelado)
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF6b7280).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(tr('❌ Pedido cancelado'),
              style: TextStyle(color: Color(0xFF6b7280), fontWeight: FontWeight.w700, fontSize: 12)))),

        // Botones
        if (!_esEntregado && !_cancelado && siguienteEtapa != null)
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _cambiando ? null : () => _cambiarEtapa(siguienteEtapa),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.colores[siguienteEtapa] ?? AppColors.azul,
              padding: const EdgeInsets.symmetric(vertical: 10)),
            child: _cambiando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.arrow_forward, size: 15, color: Colors.white),
                  const SizedBox(width: 6),
                  Flexible(child: Text('→ $etiquetaSiguiente',
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis)),
                ]))),

        // Cancelar pedido — visible mientras no esté ya entregado o cancelado
        if (!_esEntregado && !_cancelado) ...[
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, child: TextButton.icon(
            onPressed: _cambiando ? null : _confirmarCancelar,
            icon: const Icon(Icons.cancel_outlined, size: 14, color: AppColors.rojo),
            label: Text(tr('Cancelar pedido'),
              style: TextStyle(fontSize: 12, color: AppColors.rojo, fontWeight: FontWeight.w600)))),
        ],

        const SizedBox(height: 6),
        // Botón Ver PDF de cotización
        if (widget.pedido.cotizacionId != null)
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: _generandoPdf ? null : _verPdfCotizacion,
            icon: _generandoPdf
              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined, size: 14),
            label: Text(tr(_generandoPdf ? tr('Generando...') : tr('Ver pedido PDF')),
              style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1a3a5c),
              side: const BorderSide(color: Color(0xFF1a3a5c)),
              padding: const EdgeInsets.symmetric(vertical: 7)))),
        // Guía de envío y liga de seguimiento (Fase 2)
        if ((widget.pedido.guia ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.local_shipping_outlined, size: 16, color: AppColors.azul),
              const SizedBox(width: 6),
              Expanded(child: Text(
                [if ((widget.pedido.paqueteria ?? '').isNotEmpty) widget.pedido.paqueteria!, trf('Guía {0}', [widget.pedido.guia!])].join(' · '),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              InkWell(onTap: _editarGuia, child: const Padding(padding: EdgeInsets.all(2),
                child: Icon(Icons.edit_outlined, size: 16, color: AppColors.textoSecundario))),
            ])),
        ],
        if (!_cancelado) ...[
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _editarGuia,
              icon: const Icon(Icons.local_shipping_outlined, size: 14),
              label: Text(tr((widget.pedido.guia ?? '').isEmpty ? 'Guía de envío' : 'Cambiar guía'), style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.azul,
                side: const BorderSide(color: AppColors.grisBorde), padding: const EdgeInsets.symmetric(vertical: 7)))),
            if (widget.pedido.cotizacionId != null) ...[
              const SizedBox(width: 6),
              Expanded(child: OutlinedButton.icon(
                onPressed: _compartirSeguimiento,
                icon: const Icon(Icons.link, size: 14),
                label: Text(tr('Liga de seguimiento'), style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.azul,
                  side: const BorderSide(color: AppColors.grisBorde), padding: const EdgeInsets.symmetric(vertical: 7)))),
            ],
          ]),
        ],
        const SizedBox(height: 6),
        // Botón Facturar — visible cuando ya pagaron
        if (widget.pedido.estado == 'PagoCompleto' ||
            widget.pedido.estado == 'Entrega' ||
            widget.pedido.estado == 'Entregado')
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () async {
              if (!AuthService.puede('facturacion')) {
                await AuthService.exigirModulo(context, 'facturacion', funcion: tr('Facturación (CFDI)'));
                return;
              }
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => FacturaScreen(pedido: widget.pedido)));
            },
            icon: Icon(AuthService.puede('facturacion') ? Icons.receipt_long_outlined : Icons.lock_outline,
              size: 14, color: Colors.white),
            label: Text(tr('Generar factura'), style: TextStyle(fontSize: 12, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1a3a5c),
              padding: const EdgeInsets.symmetric(vertical: 8)))),
        const SizedBox(height: 6),
        Row(children: [
          if (tieneWA) Expanded(child: _enviandoWA
            ? ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 8)),
                child: const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
            : ElevatedButton.icon(
                onPressed: () async {
                  if (!AuthService.esPremiumActivo) {
                    await AuthService.exigirPremium(context, funcion: tr('Notificaciones automáticas de WhatsApp'));
                    return;
                  }
                  _notificarCliente();
                },
                icon: Icon(AuthService.esPremiumActivo ? Icons.chat : Icons.lock_outline, size: 14, color: Colors.white),
                label: Text(tr('Notificar WA'), style: TextStyle(fontSize: 12, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 8)))),
          if (tieneWA && !_esEntregado && !_cancelado) const SizedBox(width: 6),
          if (!_esEntregado && !_cancelado) Expanded(child: OutlinedButton.icon(
            onPressed: () => _cambiarEtapa('Entregado'),
            icon: const Icon(Icons.check_circle_outline, size: 14),
            label: Text(tr('Entregado'), style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.verde,
              side: const BorderSide(color: AppColors.verde),
              padding: const EdgeInsets.symmetric(vertical: 8)))),
          if (_esEntregado) Expanded(child: Center(child: Text(tr('✅ Pedido entregado'),
            style: TextStyle(color: AppColors.verde, fontWeight: FontWeight.w600)))),
        ]),
        if (_esEntregado) ...[
          const SizedBox(height: 6),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generarNotaCompra,
              icon: const Icon(Icons.task_alt_outlined, size: 14, color: Colors.white),
              label: Text(tr('Generar nota de compra'), style: TextStyle(fontSize: 12, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verde,
                padding: const EdgeInsets.symmetric(vertical: 10)))),
        ],
      ]));
  }

  Future<void> _generarNotaCompra() async {
    final ingles = await PdfService.elegirIdioma(context);
    if (ingles == null) return;
    try {
      final pedido = widget.pedido;
      // Construir cotizacion desde el pedido
      Cotizacion? cot;
      if (pedido.cotizacionId != null) {
        final cots = await SupabaseService.getCotizaciones();
        cot = cots.where((c) => c.id == pedido.cotizacionId).firstOrNull;
        if (cot != null && cot.items.isEmpty) {
          final items = await SupabaseService.getCotizacionItems(cot.id!);
          cot = cot.copiaConItems(items);
        }
      }
      if (cot == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('No se encontró la cotización del pedido'))));
        return;
      }
      final cfg = await SupabaseService.getConfiguracion();
      final bytes = await PdfService.generarNotaCompra(
        cotizacion: cot,
        empresa: cfg,
        folioPedido: pedido.folio,
        ingles: ingles);
      if (mounted) await PdfService.mostrarOpcionesEnvio(
        context, bytes, 'nota_compra_${pedido.folio ?? "nota"}.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    }
  }

  void _confirmarCancelar() {
    final motivoCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('¿Cancelar este pedido?')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(tr('Esta acción marcará el pedido como cancelado. Podrás seguir viéndolo en el filtro "Cancelado".'),
          style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
        const SizedBox(height: 12),
        TextField(controller: motivoCtrl,
          decoration: InputDecoration(labelText: tr('Motivo (opcional)'), isDense: true,
            border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('No cancelar'))),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            _cambiarEtapa('Cancelado');
          },
          child: Text(tr('Sí, cancelar pedido'),
            style: TextStyle(color: AppColors.rojo, fontWeight: FontWeight.w700))),
      ]));
  }

  Future<void> _cambiarEtapa(String nueva) async {
    setState(() => _cambiando = true);
    try {
      await SupabaseService.actualizarEtapaPedido(widget.pedido.id!, nueva);
      widget.onActualizar();
      // Sin notificación automática por ahora — usa el botón manual
      // "Notificar WA" cuando quieras avisarle al cliente.
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _cambiando = false);
    }
  }

  // ── Guía de envío ────────────────────────────────────────────────
  static const _paqueterias = ['DHL', 'Estafeta', 'FedEx', 'Paquetexpress', 'UPS', '99 Minutos', 'J&T Express', 'Redpack', 'Castores', 'Tres Guerras', 'Otra'];

  Future<void> _editarGuia() async {
    final p = widget.pedido;
    String paq = _paqueterias.contains(p.paqueteria) ? p.paqueteria! : ((p.paqueteria ?? '').isEmpty ? 'DHL' : 'Otra');
    final otraCtrl = TextEditingController(text: _paqueterias.contains(p.paqueteria) ? '' : (p.paqueteria ?? ''));
    final guiaCtrl = TextEditingController(text: p.guia ?? '');
    final urlCtrl = TextEditingController(text: p.rastreoUrl ?? '');
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Guía de envío'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('Tu cliente la ve y la rastrea desde la liga de su cotización. ¿Todavía no tienes guía? Cotízala y cómprala con Envíos HETNA.'),
            style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(ctx, MaterialPageRoute(builder: (_) => const EnviosScreen()));
            },
            icon: const Icon(Icons.calculate_outlined, size: 16),
            label: Text(tr('Cotizar y comprar guía con Envíos HETNA'), style: const TextStyle(fontSize: 12)))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: paq, isExpanded: true,
            decoration: InputDecoration(labelText: tr('Paquetería'), isDense: true, border: const OutlineInputBorder()),
            items: _paqueterias.map((x) => DropdownMenuItem(value: x, child: Text(x == 'Otra' ? tr('Otra') : x))).toList(),
            onChanged: (v) => setM(() => paq = v ?? 'DHL')),
          if (paq == 'Otra') ...[
            const SizedBox(height: 8),
            TextField(controller: otraCtrl, decoration: InputDecoration(labelText: tr('¿Cuál paquetería?'), isDense: true, border: const OutlineInputBorder())),
          ],
          const SizedBox(height: 8),
          TextField(controller: guiaCtrl, decoration: InputDecoration(labelText: tr('Número de guía'), isDense: true, border: const OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: urlCtrl, keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: tr('Liga de rastreo (opcional)'),
              helperText: tr('Para DHL, FedEx y UPS se arma sola.'), isDense: true, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(children: [
            if ((p.guia ?? '').isNotEmpty) TextButton(
              onPressed: () { guiaCtrl.clear(); urlCtrl.clear(); Navigator.pop(ctx, true); },
              child: Text(tr('Quitar guía'), style: const TextStyle(color: AppColors.rojo))),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
              onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Guardar'))),
          ]),
        ]))));
    if (ok != true) return;
    final url = urlCtrl.text.trim();
    if (url.isNotEmpty && !url.startsWith('https://')) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('La liga de rastreo debe empezar con https://'))));
      return;
    }
    try {
      final nombrePaq = paq == 'Otra' ? otraCtrl.text.trim() : paq;
      await SupabaseService.guardarGuiaPedido(p.id!,
        paqueteria: guiaCtrl.text.trim().isEmpty ? null : nombrePaq, guia: guiaCtrl.text, rastreoUrl: url);
      widget.onActualizar();
      if (mounted && guiaCtrl.text.trim().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Guía guardada. Tu cliente ya la ve en su liga.'))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(trf('No se pudo guardar la guía: {0}', [e])), backgroundColor: AppColors.rojo));
    }
  }

  // ── Liga de seguimiento ─────────────────────────────────────────
  Future<void> _compartirSeguimiento() async {
    final liga = await SupabaseService.ligaSeguimiento(widget.pedido.cotizacionId!);
    if (!mounted) return;
    if (liga == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Esta cotización todavía no tiene liga. Revisa que se haya corrido liga_cotizacion.sql.'))));
      return;
    }
    final nombre = widget.pedido.cliente?.nombre ?? '';
    final msg = trf('¡Hola {0}! 😊 Aquí puedes ver en todo momento cómo va tu pedido *{1}* (etapas, fotos y guía de envío):\n{2}\n\n— *{3}*',
      [nombre, widget.pedido.folio, liga, AuthService.marcaTaller]);
    await showModalBottomSheet(context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Liga de seguimiento'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('Es la misma liga de la cotización: ahora también muestra el avance, las fotos y la guía.'),
            style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Expanded(child: SelectableText(liga, style: const TextStyle(fontSize: 12))),
              IconButton(icon: const Icon(Icons.copy, size: 18), tooltip: tr('Copiar'), onPressed: () async {
                await Clipboard.setData(ClipboardData(text: liga));
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(tr('Liga copiada'))));
              }),
            ])),
          const SizedBox(height: 10),
          Row(children: [
            if ((widget.pedido.cliente?.whatsappNumero ?? '').isNotEmpty) ...[
              Expanded(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), minimumSize: const Size(0, 44)),
                icon: const Icon(Icons.chat, size: 16, color: Colors.white),
                label: Text(tr('Mandar por WhatsApp'), style: const TextStyle(fontSize: 12, color: Colors.white)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await WhatsAppService.abrirChatConSelector(context,
                    numero: widget.pedido.cliente!.whatsappNumero, mensaje: msg);
                })),
              const SizedBox(width: 8),
            ],
            Expanded(child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(tr('Abrir'), style: const TextStyle(fontSize: 12)),
              onPressed: () => launchUrl(Uri.parse(liga), mode: LaunchMode.externalApplication))),
          ]),
        ]))));
  }

  Future<void> _notificarCliente({String? etapa}) async {
    setState(() => _enviandoWA = true);
    try {
      var msg = await WhatsAppService.getPlantillaAvance(
        etapa: etapa ?? widget.pedido.estado,
        nombreCliente: widget.pedido.cliente?.nombre ?? tr('Cliente'),
        folio: widget.pedido.folio,
        montoTotal: widget.pedido.total,
        pedidoId: widget.pedido.id,
      );
      // Guía y liga de seguimiento al final del mensaje
      final p = widget.pedido;
      if ((p.guia ?? '').isNotEmpty) {
        msg += trf('\n\n📦 Guía {0}: {1}', [p.paqueteria ?? '', p.guia!]);
      }
      if (p.cotizacionId != null) {
        final liga = await SupabaseService.ligaSeguimiento(p.cotizacionId!);
        if (liga != null) msg += trf('\n\nSigue tu pedido aquí: {0}', [liga]);
      }
      // Deja elegir con cuál WhatsApp mandarlo (Business u otra app).
      if (mounted) await WhatsAppService.abrirChatConSelector(context,
        numero: widget.pedido.cliente!.whatsappNumero, mensaje: msg);
    } finally {
      if (mounted) setState(() => _enviandoWA = false);
    }
  }

  Future<void> _verPdfCotizacion() async {
    if (widget.pedido.cotizacionId == null) return;
    final ingles = await PdfService.elegirIdioma(context);
    if (ingles == null) return;
    setState(() => _generandoPdf = true);
    try {
      // Cargar cotización con items
      final cotizaciones = await SupabaseService.getCotizaciones();
      final cot = cotizaciones.firstWhere(
        (c) => c.id == widget.pedido.cotizacionId,
        orElse: () => throw Exception('Cotización no encontrada'));
      // Si no tiene items, cargarlos
      var cotFinal = cot;
      if (cot.items.isEmpty) {
        final items = await SupabaseService.getCotizacionItems(cot.id!);
        cotFinal = cot.copiaConItems(items);
      }
      final cfg = await SupabaseService.getConfiguracion();
      final bytes = await PdfService.generarCotizacion(cotizacion: cotFinal, empresa: cfg, ingles: ingles);
      await PdfService.verPdf(bytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trf('Error al generar PDF: {0}', [e])), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }
}
