// lib/screens/pedido_estado_screen.dart
// HETNA CNC — Página pública minimalista para que el cliente vea el
// estatus de SU pedido, sin necesitar cuenta. Se accede desde la liga
// que se manda en los mensajes de avance de WhatsApp.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../main.dart';
import '../i18n/tr.dart';

class PedidoEstadoScreen extends StatefulWidget {
  final String pedidoId;
  const PedidoEstadoScreen({super.key, required this.pedidoId});
  @override
  State<PedidoEstadoScreen> createState() => _PedidoEstadoScreenState();
}

class _PedidoEstadoScreenState extends State<PedidoEstadoScreen> {
  Map<String, dynamic>? _data;
  bool _cargando = true;
  bool _noEncontrado = false;
  bool _enviandoPregunta = false;
  final _preguntaCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    final data = await SupabaseService.getEstadoPedidoPublico(widget.pedidoId);
    if (mounted) setState(() {
      _data = data;
      _noEncontrado = data == null;
      _cargando = false;
    });
  }

  Future<void> _enviarPregunta() async {
    if (_preguntaCtrl.text.trim().isEmpty) return;
    setState(() => _enviandoPregunta = true);
    final ok = await SupabaseService.agregarPreguntaPedido(
      widget.pedidoId, _preguntaCtrl.text.trim(),
      nombre: _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim());
    if (mounted) {
      setState(() => _enviandoPregunta = false);
      if (ok) {
        _preguntaCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('✅ Tu comentario fue enviado')), backgroundColor: AppColors.verde));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('No se pudo enviar, intenta de nuevo')), backgroundColor: AppColors.rojo));
      }
    }
  }

  // Orden estándar de etapas para pintar la línea de tiempo, aunque el
  // pedido esté en cualquiera de ellas o se haya saltado alguna.
  static const _ordenEtapas = [
    'Pago50', 'Produccion', 'Pruebas', 'PagoCompleto', 'Entrega', 'Entregado'
  ];
  static const _etiquetas = {
    'Pago50': 'Anticipo recibido',
    'Produccion': 'En producción',
    'Pruebas': 'Control de calidad',
    'PagoCompleto': 'Listo, falta pago',
    'Entrega': 'Listo para entrega',
    'Entregado': 'Entregado',
    'Cancelado': 'Cancelado',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      body: SafeArea(child: _cargando
        ? const Center(child: CircularProgressIndicator())
        : _noEncontrado
          ? _vistaNoEncontrado()
          : _vistaEstado()),
    );
  }

  Widget _vistaNoEncontrado() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.search_off, size: 48, color: AppColors.textoSecundario),
      const SizedBox(height: 12),
      Text(tr('No encontramos este pedido'),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(tr('Verifica que la liga esté completa, o contacta al taller.'),
        style: TextStyle(fontSize: 13, color: AppColors.textoSecundario), textAlign: TextAlign.center),
    ])));

  Widget _vistaEstado() {
    final d = _data!;
    final folio = d['folio'] as String? ?? '';
    final estado = d['estado'] as String? ?? '';
    final negocioNombre = d['negocio_nombre'] as String? ?? tr('Taller');
    final negocioTel = d['negocio_telefono'] as String?;
    final avances = (d['avances'] as List?) ?? [];
    final fotos = (d['fotos'] as List?) ?? [];
    final fmtFecha = DateFormat("d 'de' MMMM, h:mm a", 'es_MX');

    // Índice de la etapa actual dentro del orden estándar, para pintar
    // completadas/actual/pendientes en la línea de tiempo
    final idxActual = _ordenEtapas.indexOf(estado);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(children: [
          const SizedBox(height: 8),
          Text(tr(negocioNombre), style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.azul)),
          const SizedBox(height: 4),
          Text(trf('Pedido {0}', [folio]), style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textoPrincipal)),
          const SizedBox(height: 20),

          // ── Tarjeta de línea de tiempo ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (estado == 'Cancelado')
                _filaEtapa('Cancelado', true, true, null)
              else
                ..._ordenEtapas.asMap().entries.map((e) {
                  final i = e.key; final key = e.value;
                  final completada = idxActual >= 0 && i < idxActual;
                  final esActual = i == idxActual;
                  final fechaEtapa = avances.cast<Map<String, dynamic>>()
                    .where((a) => a['etapa'] == key).map((a) => a['fecha'] as String?).firstOrNull;
                  return _filaEtapa(key, completada, esActual,
                    fechaEtapa != null ? fmtFecha.format(DateTime.parse(fechaEtapa)) : null,
                    esUltimo: i == _ordenEtapas.length - 1);
                }),
            ])),

          // ── Fotos de avance ──
          if (fotos.isNotEmpty) ...[
            const SizedBox(height: 20),
            Align(alignment: Alignment.centerLeft,
              child: Text(tr('Fotos del avance'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            const SizedBox(height: 8),
            SizedBox(height: 100, child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: fotos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(borderRadius: BorderRadius.circular(10),
                child: Image.network((fotos[i] as Map)['url'] as String,
                  width: 100, height: 100, fit: BoxFit.cover)))),
          ],

          const SizedBox(height: 24),

          // ── Botón WhatsApp ──
          if (negocioTel != null && negocioTel.isNotEmpty)
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('https://wa.me/$negocioTel'),
                mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.chat, color: AppColors.whatsapp),
              label: Text(tr('Escríbenos por WhatsApp')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.whatsapp,
                side: const BorderSide(color: AppColors.whatsapp),
                padding: const EdgeInsets.symmetric(vertical: 12)))),

          const SizedBox(height: 20),

          // ── Formulario de comentario ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('¿Dudas o comentarios sobre tu pedido?'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextField(controller: _nombreCtrl,
                decoration: InputDecoration(labelText: tr('Tu nombre (opcional)'),
                  isDense: true, border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _preguntaCtrl, maxLines: 3,
                decoration: InputDecoration(labelText: tr('Escribe aquí...'),
                  isDense: true, border: OutlineInputBorder())),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: _enviandoPregunta ? null : _enviarPregunta,
                child: _enviandoPregunta
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(tr('Enviar comentario')))),
            ])),
          const SizedBox(height: 24),
        ]),
      ));
  }

  Widget _filaEtapa(String key, bool completada, bool esActual, String? fecha, {bool esUltimo = false}) {
    final color = completada || esActual ? AppColors.verde : AppColors.grisBorde;
    return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(width: 22, height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: completada ? AppColors.verde : (esActual ? AppColors.azul : Colors.white),
            border: Border.all(color: color, width: 2)),
          child: completada
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : (esActual ? const Icon(Icons.circle, size: 8, color: Colors.white) : null)),
        if (!esUltimo) Expanded(child: Container(width: 2,
          color: completada ? AppColors.verde : AppColors.grisBorde)),
      ]),
      const SizedBox(width: 12),
      Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 20), child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(_etiquetas[key] ?? key), style: TextStyle(fontSize: 14,
            fontWeight: esActual ? FontWeight.w800 : FontWeight.w600,
            color: completada || esActual ? AppColors.textoPrincipal : AppColors.textoSecundario)),
          if (fecha != null) Text(tr(fecha), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ]))),
    ]));
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
