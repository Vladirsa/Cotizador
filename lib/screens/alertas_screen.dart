import 'package:flutter/material.dart';
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
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.rojo, borderRadius: BorderRadius.circular(20)),
              child: Text('${_alertas.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
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
                  onCompletada: () { _cargar(); },
                ))),
    );
  }

  Widget _pantallaVacia() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.verdeClaro, shape: BoxShape.circle),
      child: const Icon(Icons.check_circle_outline, size: 40, color: AppColors.verde)),
    const SizedBox(height: 16),
    const Text('¡Todo al día!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.verde)),
    const SizedBox(height: 8),
    const Text('No hay seguimientos pendientes por ahora.', style: TextStyle(color: AppColors.textoSecundario)),
    const SizedBox(height: 24),
    const Text('Las alertas aparecen automáticamente\ncuando una cotización lleva días sin respuesta.',
      textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
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

  // Mensajes predefinidos editables por tipo
  static const Map<String, String> _mensajesBase = {
    'seguimiento_dia3': '¡Hola [NOMBRE]! 😊 Te escribo de *HETNA CNC* para saber si pudiste revisar la cotización [FOLIO]. ¿Tienes alguna duda o quieres ajustar algo? Estamos para ayudarte.',
    'seguimiento_dia5': '¡Hola [NOMBRE]! Te contacto nuevamente de *HETNA CNC* sobre la cotización [FOLIO]. ¿Podemos platicar para ver si hay algo que podamos mejorar en la propuesta?',
    'seguimiento_dia7': '¡Hola [NOMBRE]! Es el último aviso de *HETNA CNC* sobre tu cotización [FOLIO] que vence pronto. Si te interesa, podemos hacer un ajuste especial para cerrar esta semana. 🎯',
    'post_entrega': '¡Hola [NOMBRE]! Esperamos que estés disfrutando tu pedido de *HETNA CNC*. Nos gustaría saber tu opinión 😊 Y si tienes amigos que necesiten algo similar, con gusto los atendemos.\n\nSíguenos: Instagram @hetna_cnc',
    'default': '¡Hola [NOMBRE]! Te escribo de *HETNA CNC* con relación a tu cotización [FOLIO]. ¿Podemos ayudarte en algo?',
  };

  String _generarMensaje() {
    final tipo = widget.alerta.tipo ?? 'default';
    final template = _mensajesBase[tipo] ?? _mensajesBase['default']!;
    return template
      .replaceAll('[NOMBRE]', widget.alerta.clienteNombre ?? 'Cliente')
      .replaceAll('[FOLIO]', widget.alerta.cotizacionFolio ?? 'sin folio');
  }

  Color get _colorTipo {
    switch (widget.alerta.tipo) {
      case 'seguimiento_dia3': return AppColors.ambar;
      case 'seguimiento_dia5': return AppColors.rojo;
      case 'seguimiento_dia7': return const Color(0xFF7c3aed);
      case 'post_entrega': return AppColors.verde;
      default: return AppColors.azul;
    }
  }

  String get _etiquetaTipo {
    switch (widget.alerta.tipo) {
      case 'seguimiento_dia3': return 'Día 3 sin respuesta';
      case 'seguimiento_dia5': return 'Día 5 — Urgente';
      case 'seguimiento_dia7': return 'Día 7 — Último aviso';
      case 'post_entrega': return 'Post entrega';
      default: return 'Seguimiento';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorTipo;
    final wa = widget.alerta.clienteWhatsapp ?? '';
    final tieneWA = wa.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4),
          top: BorderSide(color: AppColors.grisBorde, width: 0.5),
          right: BorderSide(color: AppColors.grisBorde, width: 0.5),
          bottom: BorderSide(color: AppColors.grisBorde, width: 0.5))),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.alerta.clienteNombre ?? 'Sin cliente',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            if (widget.alerta.clienteEmpresa != null)
              Text(widget.alerta.clienteEmpresa!, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            if (widget.alerta.cotizacionFolio != null)
              Text('Cotización: ${widget.alerta.cotizacionFolio}',
                style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(_etiquetaTipo, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600))),
            if (widget.alerta.cotizacionTotal != null) ...[
              const SizedBox(height: 4),
              Text('\$${widget.alerta.cotizacionTotal!.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
            ],
          ]),
        ]),

        const SizedBox(height: 10),

        // Vista previa del mensaje
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(8),
            border: const Border(left: BorderSide(color: Color(0xFF25D366), width: 2))),
          child: Text(_generarMensaje(), style: const TextStyle(fontSize: 11, height: 1.5, color: AppColors.azul))),

        const SizedBox(height: 10),

        // Botones
        Row(children: [
          // Editar mensaje
          OutlinedButton.icon(
            onPressed: () => _editarMensaje(context),
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text('Editar', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6))),
          const SizedBox(width: 6),

          // Enviar WA
          Expanded(child: ElevatedButton.icon(
            onPressed: (!tieneWA || _enviando) ? null : _enviarWhatsApp,
            icon: _enviando
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.chat, size: 14),
            label: Text(tieneWA ? 'Enviar WA' : 'Sin WA', style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: tieneWA ? const Color(0xFF25D366) : Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 6)))),
          const SizedBox(width: 6),

          // Completar
          ElevatedButton.icon(
            onPressed: _marcarCompletada,
            icon: const Icon(Icons.check, size: 14),
            label: const Text('Listo', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.azul,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6))),
        ]),

        if (!tieneWA)
          const Padding(padding: EdgeInsets.only(top: 6),
            child: Text('⚠ Este cliente no tiene WhatsApp registrado. Edítalo en CRM → Clientes.',
              style: TextStyle(fontSize: 10, color: AppColors.ambar))),
      ]),
    );
  }

  void _editarMensaje(BuildContext context) {
    final ctrl = TextEditingController(text: _generarMensaje());
    showModalBottomSheet(context: context, isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(padding: const EdgeInsets.all(16), height: 400,
          child: Column(children: [
            const Text('Editar mensaje', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Expanded(child: TextField(controller: ctrl, maxLines: null, expands: true,
              decoration: const InputDecoration(contentPadding: EdgeInsets.all(12)),
              style: const TextStyle(fontSize: 13))),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); _enviarMensaje(ctrl.text); },
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('Enviar este mensaje por WA'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366))),
          ]))));
  }

  Future<void> _enviarWhatsApp() async {
    await _enviarMensaje(_generarMensaje());
  }

  Future<void> _enviarMensaje(String mensaje) async {
    setState(() => _enviando = true);
    try {
      final wa = widget.alerta.clienteWhatsapp ?? '';
      // Limpiar número y asegurar formato correcto
      var numero = wa.replaceAll(RegExp(r'[^0-9]'), '');
      // Si tiene 10 dígitos agregar código de México
      if (numero.length == 10) numero = '52$numero';
      // Si tiene 12 dígitos con 52 al inicio, dejar como está
      // Si tiene 13 dígitos con 521, dejar como está

      if (numero.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Número de WhatsApp no válido'), backgroundColor: AppColors.rojo));
        return;
      }

      final url = 'https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}';
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Intentar con wa.me directo
        final urlDirecto = Uri.parse('whatsapp://send?phone=$numero&text=${Uri.encodeComponent(mensaje)}');
        if (await canLaunchUrl(urlDirecto)) {
          await launchUrl(urlDirecto, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ No se pudo abrir WhatsApp. Verifica que esté instalado.'),
              backgroundColor: AppColors.rojo));
        }
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
