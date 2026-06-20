import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: Row(children: [
          const Text('Alertas'),
          if (_alertas.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.rojo, borderRadius: BorderRadius.circular(20)),
              child: Text('${_alertas.length}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
          ],
        ]),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)],
      ),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _cargar, child: _alertas.isEmpty
            ? _vacia()
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _alertas.length,
                itemBuilder: (_, i) => _TarjetaAlerta(
                  alerta: _alertas[i],
                  onCompletada: _cargar))),
    );
  }

  Widget _vacia() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 72, height: 72,
      decoration: const BoxDecoration(color: AppColors.verdeClaro, shape: BoxShape.circle),
      child: const Icon(Icons.check_circle_outline, size: 36, color: AppColors.verde)),
    const SizedBox(height: 16),
    const Text('¡Todo al día!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.verde)),
    const SizedBox(height: 8),
    const Text('No hay seguimientos pendientes.', style: TextStyle(color: AppColors.textoSecundario)),
  ]));
}

class _TarjetaAlerta extends StatefulWidget {
  final Alerta alerta;
  final VoidCallback onCompletada;
  const _TarjetaAlerta({required this.alerta, required this.onCompletada});
  @override
  State<_TarjetaAlerta> createState() => _TarjetaAlertaState();
}

class _TarjetaAlertaState extends State<_TarjetaAlerta> {
  bool _enviando = false;
  late String _mensaje;

  @override
  void initState() {
    super.initState();
    _mensaje = WhatsAppService.mensajeSeguimiento(
      nombreCliente: widget.alerta.clienteNombre ?? 'Cliente',
      tipo: widget.alerta.tipo ?? 'default',
      folio: widget.alerta.cotizacionFolio,
      total: widget.alerta.cotizacionTotal,
    );
  }

  Color get _color {
    switch (widget.alerta.tipo) {
      case 'seguimiento_dia3': return AppColors.ambar;
      case 'seguimiento_dia5': return AppColors.rojo;
      case 'seguimiento_dia7': return const Color(0xFF7c3aed);
      case 'post_entrega': return AppColors.verde;
      default: return AppColors.azul;
    }
  }

  String get _etiqueta {
    switch (widget.alerta.tipo) {
      case 'seguimiento_dia3': return '⏰ Día 3';
      case 'seguimiento_dia5': return '🔴 Día 5 — Urgente';
      case 'seguimiento_dia7': return '⚠️ Día 7 — Último';
      case 'post_entrega': return '✅ Post entrega';
      default: return '📋 Seguimiento';
    }
  }

  String get _waNumero => widget.alerta.clienteWhatsapp ?? '';
  bool get _tieneWA => _waNumero.isNotEmpty;
  String get _numeroNormalizado => WhatsAppService.normalizarNumero(_waNumero);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _color, width: 4),
          top: BorderSide(color: AppColors.grisBorde, width: 0.5),
          right: BorderSide(color: AppColors.grisBorde, width: 0.5),
          bottom: BorderSide(color: AppColors.grisBorde, width: 0.5))),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ─── Header ───
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.alerta.clienteNombre ?? 'Sin cliente',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (widget.alerta.clienteEmpresa != null)
              Text(widget.alerta.clienteEmpresa!,
                style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            if (widget.alerta.cotizacionFolio != null)
              Text(widget.alerta.cotizacionFolio!,
                style: const TextStyle(fontSize: 11, color: AppColors.azul)),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(_etiqueta, style: TextStyle(fontSize: 10, color: _color, fontWeight: FontWeight.w600))),
            if (widget.alerta.cotizacionTotal != null) ...[
              const SizedBox(height: 4),
              Text('\$${widget.alerta.cotizacionTotal!.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
            ],
          ]),
        ]),

        const SizedBox(height: 10),

        // ─── Vista previa mensaje ───
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Color(0xFFf0fdf4),
            borderRadius: BorderRadius.all(Radius.circular(8)),
            border: Border(left: BorderSide(color: Color(0xFF25D366), width: 3))),
          child: Text(_mensaje, style: const TextStyle(fontSize: 11, height: 1.5, color: Color(0xFF1a3a2a)))),

        // Número que se usará
        if (_tieneWA) ...[
          const SizedBox(height: 6),
          Text('📱 WA: $_waNumero → $_numeroNormalizado',
            style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
        ],

        const SizedBox(height: 12),

        // ─── Botones ───
        Row(children: [
          // Editar
          OutlinedButton.icon(
            onPressed: _editarMensaje,
            icon: Icon(Icons.edit_outlined, size: 14, color: _color),
            label: Text('Editar', style: TextStyle(fontSize: 12, color: _color)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _color),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),

          const SizedBox(width: 8),

          // Enviar WA — siempre visible
          Expanded(child: ElevatedButton.icon(
            onPressed: _enviando ? null : _enviarWA,
            icon: _enviando
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.chat, size: 16, color: Colors.white),
            label: Text(
              _tieneWA ? 'Enviar WA' : 'Sin WA registrado',
              style: const TextStyle(fontSize: 12, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _tieneWA ? const Color(0xFF25D366) : Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 8)))),

          const SizedBox(width: 8),

          // Completar
          ElevatedButton.icon(
            onPressed: _marcarCompletada,
            icon: const Icon(Icons.check, size: 14, color: Colors.white),
            label: const Text('Listo', style: TextStyle(fontSize: 12, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.azul,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
        ]),

        if (!_tieneWA) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(6)),
            child: const Row(children: [
              Icon(Icons.warning_amber_outlined, size: 14, color: AppColors.ambar),
              SizedBox(width: 6),
              Expanded(child: Text('Agrega el WhatsApp en Más → Clientes → Editar cliente',
                style: TextStyle(fontSize: 10, color: AppColors.ambar))),
            ])),
        ],
      ]));
  }

  void _editarMensaje() {
    final ctrl = TextEditingController(text: _mensaje);
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Editar mensaje WA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ]),
          const SizedBox(height: 10),
          Expanded(child: TextField(
            controller: ctrl, maxLines: null, expands: true,
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.gris,
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
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('Enviar WA'))),
          ]),
        ])));
  }

  Future<void> _enviarWA() async {
    if (!_tieneWA) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠ Este cliente no tiene WhatsApp registrado'),
          backgroundColor: AppColors.ambar));
      return;
    }
    setState(() => _enviando = true);
    try {
      final ok = await WhatsAppService.abrirChat(numero: _waNumero, mensaje: _mensaje);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ No se pudo abrir WhatsApp. Número: $_numeroNormalizado'),
          backgroundColor: AppColors.rojo,
          action: SnackBarAction(
            label: 'Editar cliente',
            textColor: Colors.white,
            onPressed: () {})));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _marcarCompletada() async {
    try {
      await SupabaseService.marcarAlertaCompletada(widget.alerta.id!);
      widget.onCompletada();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    }
  }
}
