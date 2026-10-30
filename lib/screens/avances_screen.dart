import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_service.dart';
import '../services/pdf_service.dart';
import '../services/auth_service.dart';
import 'factura_screen.dart';
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
              Text('Resta: ${fmt.format(widget.pedido.total! / 2)}',
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

  Future<void> _notificarCliente({String? etapa}) async {
    setState(() => _enviandoWA = true);
    try {
      final msg = await WhatsAppService.getPlantillaAvance(
        etapa: etapa ?? widget.pedido.estado,
        nombreCliente: widget.pedido.cliente?.nombre ?? tr('Cliente'),
        folio: widget.pedido.folio,
        montoTotal: widget.pedido.total,
        pedidoId: widget.pedido.id,
      );
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
