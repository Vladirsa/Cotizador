import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

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
          const Text('Alertas de seguimiento'),
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
            ? _pantallaVacia()
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _alertas.length,
                itemBuilder: (_, i) => _TarjetaAlerta(
                  alerta: _alertas[i],
                  onCompletada: _cargar))),
    );
  }

  Widget _pantallaVacia() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 80, height: 80,
      decoration: const BoxDecoration(color: AppColors.verdeClaro, shape: BoxShape.circle),
      child: const Icon(Icons.check_circle_outline, size: 40, color: AppColors.verde)),
    const SizedBox(height: 16),
    const Text('¡Todo al día!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.verde)),
    const SizedBox(height: 8),
    const Text('No hay seguimientos pendientes.', style: TextStyle(color: AppColors.textoSecundario)),
    const SizedBox(height: 16),
    const Padding(padding: EdgeInsets.symmetric(horizontal: 32),
      child: Text('Las alertas aparecen automáticamente cuando una cotización lleva días sin respuesta.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textoSecundario))),
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

  static const _mensajesBase = {
    'seguimiento_dia3': '¡Hola [NOMBRE]! 😊 Te escribo de *HETNA CNC* para saber si pudiste revisar la cotización [FOLIO]. ¿Tienes alguna duda? Estamos para ayudarte.',
    'seguimiento_dia5': '¡Hola [NOMBRE]! Te contacto nuevamente de *HETNA CNC* sobre la cotización [FOLIO]. ¿Podemos platicar para ajustar algo?',
    'seguimiento_dia7': '¡Hola [NOMBRE]! La cotización [FOLIO] vence pronto. Si te interesa, podemos hacer un ajuste especial esta semana. 🎯 — *HETNA CNC*',
    'post_entrega': '¡Hola [NOMBRE]! Esperamos que estés disfrutando tu pedido de *HETNA CNC*. ¿Cómo te fue? 😊\n\nSíguenos: @hetna_cnc',
    'default': '¡Hola [NOMBRE]! Te escribo de *HETNA CNC* con relación a tu cotización [FOLIO]. ¿Podemos ayudarte?',
  };

  @override
  void initState() {
    super.initState();
    _mensaje = _generarMensaje();
  }

  String _generarMensaje() {
    final tipo = widget.alerta.tipo ?? 'default';
    final template = _mensajesBase[tipo] ?? _mensajesBase['default']!;
    return template
      .replaceAll('[NOMBRE]', widget.alerta.clienteNombre ?? 'Cliente')
      .replaceAll('[FOLIO]', widget.alerta.cotizacionFolio ?? 'sin folio');
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
      case 'seguimiento_dia3': return '⏰ Día 3 sin respuesta';
      case 'seguimiento_dia5': return '🔴 Día 5 — Urgente';
      case 'seguimiento_dia7': return '⚠️ Día 7 — Último aviso';
      case 'post_entrega': return '✅ Post entrega';
      default: return '📋 Seguimiento';
    }
  }

  bool get _tieneWA {
    final wa = widget.alerta.clienteWhatsapp ?? '';
    return wa.isNotEmpty;
  }

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ─── Header ───
        Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 0), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.alerta.clienteNombre ?? 'Sin cliente',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (widget.alerta.clienteEmpresa != null)
              Text(widget.alerta.clienteEmpresa!,
                style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            if (widget.alerta.cotizacionFolio != null)
              Text('Cotización: ${widget.alerta.cotizacionFolio}',
                style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(_etiqueta, style: TextStyle(fontSize: 10, color: _color, fontWeight: FontWeight.w600))),
            if (widget.alerta.cotizacionTotal != null) ...[
              const SizedBox(height: 4),
              Text('\$${NumberFormat('#,##0', 'es_MX').format(widget.alerta.cotizacionTotal!)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.azul)),
            ],
          ]),
        ])),

        // ─── Mensaje preview ───
        Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFf0fdf4),
              borderRadius: BorderRadius.circular(8),
              border: const Border(left: BorderSide(color: Color(0xFF25D366), width: 3))),
            child: Text(_mensaje, style: const TextStyle(fontSize: 11, height: 1.5, color: Color(0xFF1a3a2a))))),

        // ─── Botones ───
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          // Editar mensaje
          OutlinedButton(
            onPressed: () => _editarMensaje(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: BorderSide(color: _color)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.edit_outlined, size: 14, color: _color),
              const SizedBox(width: 4),
              Text('Editar', style: TextStyle(fontSize: 12, color: _color)),
            ])),

          const SizedBox(width: 8),

          // Enviar WA
          Expanded(child: ElevatedButton(
            onPressed: _tieneWA && !_enviando ? _enviarWA : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _tieneWA ? const Color(0xFF25D366) : Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 8)),
            child: _enviando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.chat, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(_tieneWA ? 'Enviar WA' : 'Sin WA',
                    style: TextStyle(fontSize: 12, color: _tieneWA ? Colors.white : Colors.grey)),
                ]))),

          const SizedBox(width: 8),

          // Marcar completada
          ElevatedButton(
            onPressed: _marcarCompletada,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.azul,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check, size: 14, color: Colors.white),
              SizedBox(width: 4),
              Text('Listo', style: TextStyle(fontSize: 12, color: Colors.white)),
            ])),
        ])),

        if (!_tieneWA)
          Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(6)),
              child: const Row(children: [
                Icon(Icons.warning_amber, size: 14, color: AppColors.ambar),
                SizedBox(width: 6),
                Expanded(child: Text('Sin WhatsApp registrado. Ve a Clientes y agrégalo.',
                  style: TextStyle(fontSize: 10, color: AppColors.ambar))),
              ]))),
      ]));
  }

  void _editarMensaje(BuildContext context) {
    final ctrl = TextEditingController(text: _mensaje);
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Editar mensaje', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
              child: const Text('Solo guardar'))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(
              onPressed: () { setState(() => _mensaje = ctrl.text); Navigator.pop(context); _enviarWA(); },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.chat, size: 16), SizedBox(width: 6), Text('Enviar WA'),
              ]))),
          ]),
        ])));
  }

  Future<void> _enviarWA() async {
    if (!_tieneWA) return;
    setState(() => _enviando = true);
    try {
      var numero = (widget.alerta.clienteWhatsapp ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      if (numero.length == 10) numero = '52$numero';
      final url = 'https://wa.me/$numero?text=${Uri.encodeComponent(_mensaje)}';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ No se pudo abrir WhatsApp'), backgroundColor: AppColors.rojo));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.rojo));
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
