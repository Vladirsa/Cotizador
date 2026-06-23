import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_service.dart';
import '../services/pdf_service.dart';
import 'factura_screen.dart';

class AvancesScreen extends StatefulWidget {
  const AvancesScreen({super.key});
  @override
  State<AvancesScreen> createState() => _AvancesScreenState();
}

class _AvancesScreenState extends State<AvancesScreen> {
  List<Pedido> _pedidos = [];
  bool _cargando = true;
  String _filtro = 'Activos';

  static const _etapas = ['Pedido', 'Pago50', 'Produccion', 'Pruebas', 'PagoCompleto', 'Entrega', 'Entregado'];
  static const _etiquetas = {
    'Pedido': 'Pedido recibido',
    'Pago50': 'Pago 50% anticipo',
    'Produccion': 'En producción',
    'Pruebas': 'Control de calidad',
    'PagoCompleto': 'Pago 100% completado',
    'Entrega': 'Listo para entrega',
    'Entregado': 'Entregado ✅',
  };
  static const _coloresEtapa = {
    'Pedido': AppColors.azul,
    'Pago50': AppColors.ambar,
    'Produccion': Color(0xFF7c3aed),
    'Pruebas': AppColors.rojo,
    'PagoCompleto': Color(0xFF059669),
    'Entrega': AppColors.verde,
    'Entregado': AppColors.verde,
  };

  final _filtros = ['Activos', 'Pedido', 'Pago50', 'Produccion', 'Pruebas', 'PagoCompleto', 'Entrega', 'Entregado', 'Todos'];
  final _etiquetasFiltro = {
    'Pago50': 'Pago 50%',
    'Produccion': 'Producción',
    'PagoCompleto': 'Pago 100%',
  };

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final pedidos = await SupabaseService.getPedidos();
      if (mounted) setState(() { _pedidos = pedidos; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  List<Pedido> get _filtrados {
    switch (_filtro) {
      case 'Activos': return _pedidos.where((p) => p.estado != 'Entregado' && p.estado != 'Cancelado').toList();
      case 'Todos': return _pedidos;
      default: return _pedidos.where((p) => p.estado == _filtro).toList();
    }
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
      appBar: AppBar(title: const Text('Avances de pedidos'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)]),
      body: Column(children: [
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
                    Text(label, style: TextStyle(fontSize: 11,
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
    Text(_filtro == 'Activos' ? 'No hay pedidos activos' : 'No hay pedidos en "$_filtro"',
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
  Color get _colorActual => widget.colores[widget.pedido.estado] ?? AppColors.azul;
  String get _etiquetaActual => widget.etiquetas[widget.pedido.estado] ?? widget.pedido.estado;
  String? get _siguienteEtapa => _idx < widget.etapas.length - 1 ? widget.etapas[_idx + 1] : null;

  String _mensajeWA(String etapa) {
    final nombre = widget.pedido.cliente?.nombre ?? 'Cliente';
    final folio = widget.pedido.folio;
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final total = widget.pedido.total ?? 0;
    final anticipo = total / 2;
    final restante = total - anticipo;
    final montoTotal = total > 0 ? fmt.format(total) : '';
    final montoAnticipo = total > 0 ? fmt.format(anticipo) : '';
    final montoRestante = total > 0 ? fmt.format(restante) : '';
    switch (etapa) {
      case 'Pago50': return '¡Hola $nombre! ✅ Recibimos tu anticipo del 50%${montoAnticipo.isNotEmpty ? " ($montoAnticipo)" : ""} del pedido *$folio*. ¡Empezamos a producir! 🔧\n\nRecuerda que el saldo restante${montoRestante.isNotEmpty ? " de *$montoRestante*" : ""} se liquida antes de la entrega. — *HETNA CNC*';
      case 'Produccion': return '¡Hola $nombre! 🔧 Tu pedido *$folio* está en producción. Te avisamos cuando esté listo. — *HETNA CNC*';
      case 'Pruebas': return '¡Hola $nombre! 🔍 Tu pedido *$folio* está en control de calidad. ¡Casi listo! — *HETNA CNC*';
      case 'PagoCompleto': return '¡Hola $nombre! 💳 Tu pedido *$folio* está listo. Para entregarlo necesitamos el pago del saldo restante${montoRestante.isNotEmpty ? " de *$montoRestante*" : ""}. ¿Cuándo puedes realizarlo? — *HETNA CNC*';
      case 'Entrega': return '¡Hola $nombre! 📦 Tu pedido *$folio* está *LISTO para entrega*. ¿Cuándo coordinamos? — *HETNA CNC*';
      case 'Entregado': return '¡Hola $nombre! 🎉 Tu pedido *$folio* fue entregado. ¡Gracias por confiar en *HETNA CNC*! Si necesitas algo más, con gusto te atendemos. 😊';
      default: return '¡Hola $nombre! Tu pedido *$folio* está en proceso. — *HETNA CNC*';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final nombre = widget.pedido.cliente?.nombre ?? widget.pedido.cliente?.empresa ?? 'Sin cliente';
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
            Text(nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
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
              child: Text(_etiquetaActual, style: TextStyle(fontSize: 10, color: _colorActual, fontWeight: FontWeight.w700))),
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
              'Pedido': 'Pedido', 'Pago50': 'Pago 50%', 'Produccion': 'Prod.',
              'Pruebas': 'QC', 'PagoCompleto': 'Pago 100%', 'Entrega': 'Entrega', 'Entregado': '✅',
            }[etapa] ?? etapa;
            return Padding(padding: const EdgeInsets.only(right: 8), child: Column(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: esActual ? color : (pasada ? AppColors.verde.withOpacity(0.6) : Colors.grey.shade300))),
              const SizedBox(height: 2),
              Text(etiquetaCorta, style: TextStyle(fontSize: 8,
                color: esActual ? color : (pasada ? AppColors.verde : AppColors.textoSecundario),
                fontWeight: esActual ? FontWeight.w700 : FontWeight.normal)),
            ]));
          }).toList())),

        const SizedBox(height: 10),

        // Botones
        if (!_esEntregado && siguienteEtapa != null)
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

        const SizedBox(height: 6),
        // Botón Ver PDF de cotización
        if (widget.pedido.cotizacionId != null)
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: _generandoPdf ? null : _verPdfCotizacion,
            icon: _generandoPdf
              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined, size: 14),
            label: Text(_generandoPdf ? 'Generando...' : 'Ver pedido PDF',
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
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => FacturaScreen(pedido: widget.pedido))),
            icon: const Icon(Icons.receipt_long_outlined, size: 14, color: Colors.white),
            label: const Text('Generar factura', style: TextStyle(fontSize: 12, color: Colors.white)),
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
                onPressed: _notificarCliente,
                icon: const Icon(Icons.chat, size: 14, color: Colors.white),
                label: const Text('Notificar WA', style: TextStyle(fontSize: 12, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 8)))),
          if (tieneWA && !_esEntregado) const SizedBox(width: 6),
          if (!_esEntregado) Expanded(child: OutlinedButton.icon(
            onPressed: () => _cambiarEtapa('Entregado'),
            icon: const Icon(Icons.check_circle_outline, size: 14),
            label: const Text('Entregado', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.verde,
              side: const BorderSide(color: AppColors.verde),
              padding: const EdgeInsets.symmetric(vertical: 8)))),
          if (_esEntregado) const Expanded(child: Center(child: Text('✅ Pedido entregado',
            style: TextStyle(color: AppColors.verde, fontWeight: FontWeight.w600)))),
        ]),
        if (_esEntregado) ...[
          const SizedBox(height: 6),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generarNotaCompra,
              icon: const Icon(Icons.task_alt_outlined, size: 14, color: Colors.white),
              label: const Text('Generar nota de compra', style: TextStyle(fontSize: 12, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verde,
                padding: const EdgeInsets.symmetric(vertical: 10)))),
        ],
      ]));
  }

  Future<void> _generarNotaCompra() async {
    try {
      final pedido = widget.pedido;
      // Construir cotizacion desde el pedido
      Cotizacion? cot;
      if (pedido.cotizacionId != null) {
        final cots = await SupabaseService.getCotizaciones();
        cot = cots.where((c) => c.id == pedido.cotizacionId).firstOrNull;
        if (cot != null && cot.items.isEmpty) {
          final items = await SupabaseService.getCotizacionItems(cot.id!);
          cot = Cotizacion(
            id: cot.id, folio: cot.folio, cliente: cot.cliente,
            clienteId: cot.clienteId, estado: cot.estado, items: items,
            descuentoPct: cot.descuentoPct, descuentoFijo: cot.descuentoFijo,
            ivaPct: cot.ivaPct, costoEnvio: cot.costoEnvio,
            metodoPago: cot.metodoPago, condicionEntrega: cot.condicionEntrega,
            fechaEntrega: cot.fechaEntrega, diasHabiles: cot.diasHabiles,
            vigenciaDias: cot.vigenciaDias, notas: cot.notas,
            pdfUrl: cot.pdfUrl, createdAt: cot.createdAt, totalBd: cot.totalBd);
        }
      }
      if (cot == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se encontró la cotización del pedido')));
        return;
      }
      final cfg = await SupabaseService.getConfiguracion();
      final bytes = await PdfService.generarNotaCompra(
        cotizacion: cot,
        empresa: cfg,
        folioPedido: pedido.folio);
      await PdfService.compartirPdf(bytes, 'nota_compra_${pedido.folio ?? "nota"}.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    }
  }

  Future<void> _cambiarEtapa(String nueva) async {
    setState(() => _cambiando = true);
    try {
      await SupabaseService.actualizarEtapaPedido(widget.pedido.id!, nueva);
      // Guardar referencia al navigator y context ANTES de llamar onActualizar
      final tieneWA = mounted && (widget.pedido.cliente?.whatsappNumero ?? '').isNotEmpty;
      final etiqueta = widget.etiquetas[nueva] ?? nueva;
      final clienteNombre = widget.pedido.cliente?.nombre ?? '';
      final etapaParaNotificar = nueva;
      // Notificar al padre DESPUÉS de capturar referencias
      widget.onActualizar();
      // Mostrar dialog si tiene WA
      if (tieneWA && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            title: Text('→ $etiqueta'),
            content: Text('¿Notificar a $clienteNombre por WhatsApp?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('No')),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(dialogCtx).pop();
                  await _notificarCliente(etapa: etapaParaNotificar);
                },
                icon: const Icon(Icons.chat, size: 14, color: Colors.white),
                label: const Text('Sí, notificar', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366))),
            ]));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _cambiando = false);
    }
  }

  Future<void> _notificarCliente({String? etapa}) async {
    setState(() => _enviandoWA = true);
    try {
      final msg = _mensajeWA(etapa ?? widget.pedido.estado);
      await WhatsAppService.abrirChat(numero: widget.pedido.cliente!.whatsappNumero, mensaje: msg);
    } finally {
      if (mounted) setState(() => _enviandoWA = false);
    }
  }

  Future<void> _verPdfCotizacion() async {
    if (widget.pedido.cotizacionId == null) return;
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
        cotFinal = Cotizacion(
          id: cot.id, folio: cot.folio, cliente: cot.cliente, clienteId: cot.clienteId,
          estado: cot.estado, items: items,
          descuentoPct: cot.descuentoPct, descuentoFijo: cot.descuentoFijo,
          ivaPct: cot.ivaPct, costoEnvio: cot.costoEnvio,
          metodoPago: cot.metodoPago, condicionEntrega: cot.condicionEntrega,
          fechaEntrega: cot.fechaEntrega, diasHabiles: cot.diasHabiles,
          vigenciaDias: cot.vigenciaDias, notas: cot.notas,
          pdfUrl: cot.pdfUrl, createdAt: cot.createdAt, totalBd: cot.totalBd);
      }
      final cfg = await SupabaseService.getConfiguracion();
      final bytes = await PdfService.generarCotizacion(cotizacion: cotFinal, empresa: cfg);
      await PdfService.verPdf(bytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }
}
