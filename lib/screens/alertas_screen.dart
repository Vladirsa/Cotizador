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
      body: Column(children: [
        // ─── Resumen compacto ───
        if (_alertas.isNotEmpty) _resumenCompacto(),

        // ─── Filtros ───
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    final d3 = _alertas.where((a) => a.tipo == 'seguimiento_dia3').length;
    final d5 = _alertas.where((a) => a.tipo == 'seguimiento_dia5').length;
    final d7 = _alertas.where((a) => a.tipo == 'seguimiento_dia7').length;
    final post = _alertas.where((a) => a.tipo == 'post_entrega').length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(children: [
        _resumenItem('Día 3', d3, AppColors.ambar),
        _resumenItem('Día 5', d5, AppColors.rojo),
        _resumenItem('Día 7', d7, const Color(0xFF7c3aed)),
        _resumenItem('Post', post, AppColors.verde),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.rojoClaro, borderRadius: BorderRadius.circular(20)),
          child: Text('${_alertas.length} pendientes',
            style: const TextStyle(fontSize: 11, color: AppColors.rojo, fontWeight: FontWeight.w700))),
      ]));
  }

  Widget _resumenItem(String label, int count, Color color) => Container(
    margin: const EdgeInsets.only(right: 8, bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: count > 0 ? color.withOpacity(0.1) : AppColors.gris,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: count > 0 ? color : AppColors.grisBorde)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
        color: count > 0 ? color : AppColors.textoSecundario)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: count > 0 ? color : AppColors.textoSecundario)),
    ]));

  Widget _vacia() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 72, height: 72,
      decoration: const BoxDecoration(color: AppColors.verdeClaro, shape: BoxShape.circle),
      child: const Icon(Icons.check_circle_outline, size: 36, color: AppColors.verde)),
    const SizedBox(height: 16),
    const Text('¡Todo al día!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.verde)),
    const SizedBox(height: 8),
    Text(_filtro == 'Todos' ? 'No hay alertas pendientes' : 'No hay alertas de tipo "$_filtro"',
      style: const TextStyle(color: AppColors.textoSecundario)),
  ]));
}

// ═══════════════════════════════════════════
// TARJETA DE ALERTA
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
      case 'seguimiento_dia5': return '🔴 Día 5';
      case 'seguimiento_dia7': return '⚠️ Día 7';
      case 'post_entrega': return '✅ Post';
      default: return '📋';
    }
  }

  bool get _tieneWA => (widget.alerta.clienteWhatsapp ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _color, width: 4),
          top: BorderSide(color: AppColors.grisBorde, width: 0.5),
          right: BorderSide(color: AppColors.grisBorde, width: 0.5),
          bottom: BorderSide(color: AppColors.grisBorde, width: 0.5))),
      child: Column(children: [

        // ─── Cabecera compacta ───
        Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(children: [
            // Badge tipo
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Text(_etiqueta, style: TextStyle(fontSize: 11, color: _color, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            // Nombre
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.alerta.clienteNombre ?? 'Sin cliente',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              if (widget.alerta.cotizacionFolio != null)
                Text(widget.alerta.cotizacionFolio!,
                  style: const TextStyle(fontSize: 10, color: AppColors.azul)),
            ])),
            // Monto
            if (widget.alerta.cotizacionTotal != null)
              Text('\$${widget.alerta.cotizacionTotal!.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
            // Expandir
            IconButton(
              icon: Icon(_expandido ? Icons.expand_less : Icons.expand_more, size: 20),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _expandido = !_expandido)),
          ])),

        // ─── Mensaje (solo si expandido) ───
        if (_expandido) Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFf0fdf4),
              borderRadius: BorderRadius.all(Radius.circular(8)),
              border: Border(left: BorderSide(color: Color(0xFF25D366), width: 3))),
            child: Text(_mensaje, style: const TextStyle(fontSize: 11, height: 1.5, color: Color(0xFF1a3a2a))))),

        // ─── Botones siempre visibles ───
        Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          // Botón WA — principal, siempre visible
          Expanded(child: ElevatedButton(
            onPressed: _tieneWA && !_enviando ? _enviarWA : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _tieneWA ? const Color(0xFF25D366) : Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 8)),
            child: _enviando
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.chat, size: 15, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(_tieneWA ? 'Enviar WA' : 'Sin WA',
                    style: const TextStyle(fontSize: 12, color: Colors.white)),
                ]))),
          const SizedBox(width: 6),
          // Editar mensaje
          OutlinedButton(
            onPressed: _editarMensaje,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _color),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            child: Icon(Icons.edit_outlined, size: 16, color: _color)),
          const SizedBox(width: 6),
          // Completar
          ElevatedButton(
            onPressed: _marcarCompletada,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.azul,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            child: const Icon(Icons.check, size: 16, color: Colors.white)),
        ])),
      ]));
  }

  void _editarMensaje() {
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠ Agrega el WhatsApp en Clientes → Editar'),
        backgroundColor: AppColors.ambar));
      return;
    }
    setState(() => _enviando = true);
    try {
      await WhatsAppService.abrirChat(
        numero: widget.alerta.clienteWhatsapp!,
        mensaje: _mensaje);
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
