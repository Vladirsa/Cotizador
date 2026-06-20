import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  String _filtro = 'Todos';

  final _filtros = ['Todos', 'Día 3', 'Día 5', 'Día 7', 'Post entrega'];

  String _tipoFiltro(String f) {
    switch (f) {
      case 'Día 3': return 'seguimiento_dia3';
      case 'Día 5': return 'seguimiento_dia5';
      case 'Día 7': return 'seguimiento_dia7';
      case 'Post entrega': return 'post_entrega';
      default: return '';
    }
  }

  List<Alerta> get _filtradas => _filtro == 'Todos'
    ? _alertas
    : _alertas.where((a) => a.tipo == _tipoFiltro(_filtro)).toList();

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
      body: Column(children: [
        // ─── Resumen por tipo ───
        if (_alertas.isNotEmpty) _resumenCompacto(),

        // ─── Filtros ───
        Container(color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:
            _filtros.map((f) {
              final count = f == 'Todos' ? _alertas.length
                : _alertas.where((a) => a.tipo == _tipoFiltro(f)).length;
              final colores = {
                'Día 3': AppColors.ambar, 'Día 5': AppColors.rojo,
                'Día 7': const Color(0xFF7c3aed), 'Post entrega': AppColors.verde,
              };
              final color = colores[f] ?? AppColors.azul;
              final activo = _filtro == f;
              return GestureDetector(
                onTap: () => setState(() => _filtro = f),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: activo ? color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: activo ? color : AppColors.grisBorde)),
                  child: Text('$f ($count)', style: TextStyle(fontSize: 11,
                    color: activo ? Colors.white : AppColors.textoSecundario,
                    fontWeight: activo ? FontWeight.w600 : FontWeight.normal))));
            }).toList()))),

        // ─── Lista ───
        Expanded(child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _cargar, child: _filtradas.isEmpty
              ? _vacia()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtradas.length,
                  itemBuilder: (_, i) => _TarjetaAlerta(
                    alerta: _filtradas[i],
                    onCompletada: _cargar)))),
      ]),
    );
  }

  Widget _resumenCompacto() {
    final grupos = {
      'seguimiento_dia3': {'label': '⏰ Día 3', 'color': AppColors.ambar},
      'seguimiento_dia5': {'label': '🔴 Día 5', 'color': AppColors.rojo},
      'seguimiento_dia7': {'label': '⚠️ Día 7', 'color': const Color(0xFF7c3aed)},
      'post_entrega': {'label': '✅ Post', 'color': AppColors.verde},
    };
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(children: [
        ...grupos.entries.map((e) {
          final count = _alertas.where((a) => a.tipo == e.key).length;
          final color = e.value['color'] as Color;
          final label = e.value['label'] as String;
          return Container(
            margin: const EdgeInsets.only(right: 8, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: count > 0 ? color.withOpacity(0.1) : AppColors.gris,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: count > 0 ? color : AppColors.grisBorde)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                color: count > 0 ? color : AppColors.textoSecundario)),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 10,
                color: count > 0 ? color : AppColors.textoSecundario)),
            ]));
        }),
      ]));
  }

  Widget _vacia() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 72, height: 72,
      decoration: const BoxDecoration(color: AppColors.verdeClaro, shape: BoxShape.circle),
      child: const Icon(Icons.check_circle_outline, size: 36, color: AppColors.verde)),
    const SizedBox(height: 16),
    const Text('¡Todo al día!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.verde)),
    const SizedBox(height: 8),
    Text(_filtro == 'Todos' ? 'No hay alertas pendientes' : 'No hay alertas de "$_filtro"',
      style: const TextStyle(color: AppColors.textoSecundario)),
  ]));
}

// ═══════════════════════════════════════════
// TARJETA DE ALERTA — DINÁMICA
// ═══════════════════════════════════════════
class _TarjetaAlerta extends StatefulWidget {
  final Alerta alerta;
  final VoidCallback onCompletada;
  const _TarjetaAlerta({required this.alerta, required this.onCompletada});
  @override
  State<_TarjetaAlerta> createState() => _TarjetaAlertaState();
}

class _TarjetaAlertaState extends State<_TarjetaAlerta> {
  bool _enviando = false;
  bool _expandido = false;
  late String _mensaje;
  final _fmt = NumberFormat('\$#,##0', 'es_MX');

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
      case 'seguimiento_dia3': return '⏰ Seguimiento — Día 3 sin respuesta';
      case 'seguimiento_dia5': return '🔴 Urgente — Día 5 sin respuesta';
      case 'seguimiento_dia7': return '⚠️ Último aviso — Día 7';
      case 'post_entrega': return '✅ Post entrega — Solicitar reseña';
      default: return '📋 Seguimiento pendiente';
    }
  }

  String get _accion {
    switch (widget.alerta.tipo) {
      case 'seguimiento_dia3': return 'Preguntar si revisó la cotización';
      case 'seguimiento_dia5': return 'Ofrecer ajuste o reunión';
      case 'seguimiento_dia7': return 'Oferta especial de cierre';
      case 'post_entrega': return 'Pedir reseña e invitar a seguir redes';
      default: return 'Dar seguimiento';
    }
  }

  bool get _tieneWA => (widget.alerta.clienteWhatsapp ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _color, width: 5),
          top: BorderSide(color: _color.withOpacity(0.2), width: 0.5),
          right: BorderSide(color: AppColors.grisBorde, width: 0.5),
          bottom: BorderSide(color: AppColors.grisBorde, width: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ─── Fila superior — tipo + acción requerida ───
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: _color.withOpacity(0.06),
            borderRadius: const BorderRadius.only(topRight: Radius.circular(12))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_etiqueta, style: TextStyle(fontSize: 11, color: _color, fontWeight: FontWeight.w700)),
              Text(_accion, style: TextStyle(fontSize: 10, color: _color.withOpacity(0.8))),
            ])),
            // Monto si existe
            if (widget.alerta.cotizacionTotal != null)
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: Text(_fmt.format(widget.alerta.cotizacionTotal!),
                  style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w800))),
          ])),

        // ─── Info del cliente ───
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _color.withOpacity(0.1),
            child: Text((widget.alerta.clienteNombre ?? 'C')[0].toUpperCase(),
              style: TextStyle(color: _color, fontWeight: FontWeight.w800, fontSize: 14))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.alerta.clienteNombre ?? 'Sin cliente',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            if (widget.alerta.clienteEmpresa != null)
              Text(widget.alerta.clienteEmpresa!,
                style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            if (widget.alerta.cotizacionFolio != null)
              Text('📄 ${widget.alerta.cotizacionFolio}',
                style: const TextStyle(fontSize: 10, color: AppColors.azul)),
          ])),
          // Botón expandir mensaje
          TextButton.icon(
            onPressed: () => setState(() => _expandido = !_expandido),
            icon: Icon(_expandido ? Icons.expand_less : Icons.message_outlined,
              size: 16, color: AppColors.textoSecundario),
            label: Text(_expandido ? 'Ocultar' : 'Ver mensaje',
              style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            style: TextButton.styleFrom(padding: EdgeInsets.zero)),
        ])),

        // ─── Preview del mensaje (expandible) ───
        if (_expandido)
          Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFf0fdf4),
                borderRadius: BorderRadius.all(Radius.circular(8)),
                border: Border(left: BorderSide(color: Color(0xFF25D366), width: 3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.chat, size: 12, color: Color(0xFF25D366)),
                  SizedBox(width: 4),
                  Text('Mensaje a enviar:', style: TextStyle(fontSize: 10, color: Color(0xFF25D366), fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                Text(_mensaje, style: const TextStyle(fontSize: 11, height: 1.5, color: Color(0xFF1a3a2a))),
                if (_tieneWA) ...[
                  const SizedBox(height: 6),
                  Text('📱 ${widget.alerta.clienteWhatsapp} → ${WhatsAppService.normalizarNumero(widget.alerta.clienteWhatsapp!)}',
                    style: const TextStyle(fontSize: 9, color: AppColors.textoSecundario)),
                ],
              ]))),

        // ─── BOTONES — siempre visibles ───
        Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), child: Row(children: [
          // ENVIAR WA — botón principal grande
          Expanded(child: ElevatedButton(
            onPressed: _tieneWA && !_enviando ? _enviarWA : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _tieneWA ? const Color(0xFF25D366) : Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 10)),
            child: _enviando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.chat, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(_tieneWA ? 'Enviar WhatsApp' : 'Sin WhatsApp',
                    style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                ]))),
          const SizedBox(width: 6),
          // Editar mensaje
          OutlinedButton(
            onPressed: _editarMensaje,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _color),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
            child: Icon(Icons.edit_outlined, size: 18, color: _color)),
          const SizedBox(width: 6),
          // Marcar completada
          ElevatedButton(
            onPressed: _marcarCompletada,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.azul,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
            child: const Icon(Icons.check, size: 18, color: Colors.white)),
        ])),

        // Aviso sin WA
        if (!_tieneWA)
          Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(6)),
              child: const Row(children: [
                Icon(Icons.warning_amber_outlined, size: 14, color: AppColors.ambar),
                SizedBox(width: 6),
                Expanded(child: Text('Sin WhatsApp. Ve a Más → Clientes → Editar cliente.',
                  style: TextStyle(fontSize: 10, color: AppColors.ambar))),
              ]))),
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
        padding: EdgeInsets.only(left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Editar mensaje WA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ]),
          const SizedBox(height: 10),
          Expanded(child: TextField(
            controller: ctrl, maxLines: null, expands: true,
            decoration: InputDecoration(filled: true, fillColor: AppColors.gris,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
            style: const TextStyle(fontSize: 13))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () { setState(() => _mensaje = ctrl.text); Navigator.pop(context); },
              child: const Text('Guardar'))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              onPressed: () { setState(() => _mensaje = ctrl.text); Navigator.pop(context); _enviarWA(); },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('Enviar WA'))),
          ]),
        ])));
  }

  Future<void> _enviarWA() async {
    if (!_tieneWA) return;
    setState(() => _enviando = true);
    try {
      await WhatsAppService.abrirChat(numero: widget.alerta.clienteWhatsapp!, mensaje: _mensaje);
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
