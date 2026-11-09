// lib/screens/marketing_auto_tab.dart
// Marketing → Automático: el taller prende "recetas" y el servidor las corre
// cada mañana. El correo sale solo (con el nombre del taller) y el WhatsApp
// queda listo en "Cola de hoy" para mandarlo con un toque.
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/hetna_api.dart';
import '../services/supabase_service.dart';
import '../i18n/tr.dart';

class MarketingAutoTab extends StatefulWidget {
  /// Para mandar al usuario a la pestaña "Cola de hoy"
  final VoidCallback? irACola;
  const MarketingAutoTab({super.key, this.irACola});
  @override
  State<MarketingAutoTab> createState() => _MarketingAutoTabState();
}

class _MarketingAutoTabState extends State<MarketingAutoTab> {
  Map<String, dynamic>? _datos;
  Map<String, dynamic> _resultados = {};
  String? _error;
  bool _cargando = true;
  bool _corriendo = false;
  final Set<String> _guardando = {};

  static const _iconos = <String, IconData>{
    'seguimiento_cotizacion': Icons.mark_email_unread_outlined,
    'ultimo_aviso': Icons.timer_outlined,
    'anticipo_pendiente': Icons.payments_outlined,
    'gracias_resena': Icons.star_outline,
    'reactivacion': Icons.replay_outlined,
  };
  static const _colores = <String, Color>{
    'seguimiento_cotizacion': Color(0xFF185fa5),
    'ultimo_aviso': Color(0xFFD97706),
    'anticipo_pendiente': Color(0xFF059669),
    'gracias_resena': Color(0xFF7c3aed),
    'reactivacion': Color(0xFFe24b4a),
  };

  @override
  void initState() { super.initState(); _cargar(); }

  String? get _token => AuthService.sesion?.accessToken;
  List<Map<String, dynamic>> get _recetas =>
    ((_datos?['recetas'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> _cargar() async {
    final token = _token;
    if (token == null) return;
    setState(() { _cargando = true; _error = null; });
    try {
      final r = await Future.wait([MarketingApi.recetas(token), SupabaseService.marketingResultados()]);
      if (!mounted) return;
      setState(() {
        _datos = r[0];
        _resultados = r[1];
        _cargando = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  Future<bool> _guardar(String clave, Map<String, dynamic> cambios) async {
    final token = _token;
    if (token == null) return false;
    setState(() => _guardando.add(clave));
    try {
      await MarketingApi.guardar(token, {'receta': clave, ...cambios});
      await _cargar();
      return true;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return false;
    } finally {
      if (mounted) setState(() => _guardando.remove(clave));
    }
  }

  Future<void> _activarRecomendadas() async {
    final token = _token;
    if (token == null) return;
    setState(() => _corriendo = true);
    try {
      for (final r in _recetas.where((r) => r['recomendada'] == true && r['activa'] != true)) {
        await MarketingApi.guardar(token, {'receta': r['clave'], 'activa': true});
      }
      await _cargar();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('Listo: el piloto automático quedó prendido. Mañana a las 11:00 hace la primera revisión.')),
        backgroundColor: AppColors.verde));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _corriendo = false);
    }
  }

  Future<void> _correrAhora() async {
    final token = _token;
    if (token == null) return;
    setState(() => _corriendo = true);
    try {
      final r = await MarketingApi.correr(token);
      final correos = (r['correos'] as num?)?.toInt() ?? 0;
      final whats = (r['whatsapp'] as num?)?.toInt() ?? 0;
      await _cargar();
      if (!mounted) return;
      if (correos == 0 && whats == 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          tr('Por ahora no hay a quién escribirle. Revisamos solos todos los días.'))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(trf('{0} correo(s) enviados y {1} WhatsApp listos en tu Cola de hoy.', [correos, whats])),
          action: whats > 0 && widget.irACola != null
            ? SnackBarAction(label: tr('Ver cola'), onPressed: widget.irACola!) : null));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _corriendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.esAdmin) {
      return _aviso(Icons.lock_outline, tr('Solo el administrador del taller puede configurar el marketing automático.'));
    }
    if (_cargando && _datos == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _datos == null) {
      return _aviso(Icons.cloud_off_outlined, _error!, accion: TextButton(onPressed: _cargar, child: Text(tr('Reintentar'))));
    }
    final permitido = _datos?['permitido'] == true;
    final tablaLista = _datos?['tabla_lista'] != false;
    final recetas = _recetas;
    final activas = recetas.where((r) => r['activa'] == true).length;

    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(14), children: [
      // Explicación
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1a3a5c), Color(0xFF185fa5)]),
          borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_mode, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('Piloto automático'),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
            if (activas > 0) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
              child: Text(trf('{0} activas', [activas]), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          Text(tr('Todos los días a las 11:00 revisamos tus cotizaciones, pedidos y clientes. A quien le toca: el correo le llega solo, con el nombre de tu taller, y el WhatsApp te queda listo en "Cola de hoy" para mandarlo con un toque.'),
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, height: 1.35)),
        ])),
      const SizedBox(height: 12),

      if (!permitido)
        _tarjetaPlan()
      else if (!tablaLista)
        _avisoChico(Icons.build_outlined, tr('Falta activar esta función en el servidor (supabase/paypal_y_marketing.sql). Avísale a HETNA.'))
      else if (activas == 0)
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _corriendo ? null : _activarRecomendadas,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde, minimumSize: const Size(0, 48)),
          icon: _corriendo
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.bolt, color: Colors.white),
          label: Text(tr('Activar las recomendadas (1 toque)'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
      if (permitido && tablaLista) const SizedBox(height: 12),

      ...recetas.map((r) => _tarjeta(r, permitido && tablaLista)),

      if (permitido && tablaLista && activas > 0) ...[
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _corriendo ? null : _correrAhora,
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), foregroundColor: AppColors.azul,
            side: const BorderSide(color: AppColors.azul)),
          icon: _corriendo
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.play_arrow),
          label: Text(tr('Revisar ahora (sin esperar a mañana)'))),
        const SizedBox(height: 8),
        Text(tr('Nunca se le manda dos veces el mismo mensaje a un cliente. Los correos llevan liga para darse de baja.'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      ],
      const SizedBox(height: 24),
    ]));
  }

  Widget _tarjeta(Map<String, dynamic> r, bool editable) {
    final clave = r['clave'] as String;
    final activa = r['activa'] == true;
    final color = _colores[clave] ?? AppColors.azul;
    final res = _resultados[clave] is Map ? Map<String, dynamic>.from(_resultados[clave] as Map) : const <String, dynamic>{};
    final enviados = (res['enviados'] as num?)?.toInt() ?? 0;
    final ganadas = (res['ganadas'] as num?)?.toInt() ?? 0;
    final guardando = _guardando.contains(clave);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: activa ? color.withOpacity(0.5) : AppColors.grisBorde, width: activa ? 1 : 0.5)),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 34, height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
            child: Icon(_iconos[clave] ?? Icons.campaign_outlined, size: 18, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(tr(r['titulo'] as String? ?? ''),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
              if (r['recomendada'] == true) ...[
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.verdeClaro, borderRadius: BorderRadius.circular(10)),
                  child: Text(tr('Recomendada'), style: const TextStyle(fontSize: 9, color: AppColors.verde, fontWeight: FontWeight.w700))),
              ],
            ]),
            const SizedBox(height: 2),
            Text(tr(r['descripcion'] as String? ?? ''),
              style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario, height: 1.3)),
          ])),
          guardando
            ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
            : Switch(value: activa, activeColor: color,
                onChanged: editable ? (v) => _guardar(clave, {'activa': v}) : null),
        ]),
        Padding(padding: const EdgeInsets.only(left: 44, right: 6, top: 6), child: Row(children: [
          _chipCanal(Icons.email_outlined, tr('Correo solo'), r['correo'] != false,
            editable ? (v) => _guardar(clave, {'correo': v}) : null),
          const SizedBox(width: 6),
          _chipCanal(Icons.chat_outlined, tr('WhatsApp en cola'), r['whatsapp'] != false,
            editable ? (v) => _guardar(clave, {'whatsapp': v}) : null),
          const Spacer(),
          TextButton(
            onPressed: editable ? () => _editar(r) : null,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
            child: Text(tr('Editar'), style: const TextStyle(fontSize: 12))),
        ])),
        if (enviados > 0)
          Padding(padding: const EdgeInsets.only(left: 44, top: 2),
            child: Text(
              ganadas > 0
                ? trf('Últimos 30 días: {0} enviados · {1} se cerraron después 🎉', [enviados, ganadas])
                : trf('Últimos 30 días: {0} enviados', [enviados]),
              style: TextStyle(fontSize: 11, color: ganadas > 0 ? AppColors.verde : AppColors.textoSecundario,
                fontWeight: ganadas > 0 ? FontWeight.w700 : FontWeight.normal))),
      ]));
  }

  Widget _chipCanal(IconData icono, String texto, bool activo, ValueChanged<bool>? onChanged) => FilterChip(
    selected: activo,
    onSelected: onChanged,
    showCheckmark: false,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    avatar: Icon(icono, size: 14, color: activo ? AppColors.azul : AppColors.textoSecundario),
    label: Text(texto, style: TextStyle(fontSize: 11, color: activo ? AppColors.azul : AppColors.textoSecundario)),
    selectedColor: AppColors.azulClaro,
    backgroundColor: AppColors.gris,
    side: BorderSide(color: activo ? AppColors.azul.withOpacity(0.3) : AppColors.grisBorde, width: 0.5),
  );

  static const _ejemplo = {
    'NOMBRE': 'Juan', 'FOLIO': 'COT-2026-0042', 'MONTO': '\$4,850.00', 'LIGA': 'https://hetnacnc.com/c/…',
    'ANTICIPO': '\$2,425.00', 'VENCE': '15 de noviembre', 'CUPON': 'VUELVE10', 'RESENA': 'https://g.page/…',
  };

  String _vistaPrevia(String plantilla) {
    final vars = {..._ejemplo, 'TALLER': AuthService.marcaTaller};
    return plantilla.replaceAllMapped(RegExp(r'\*([A-ZÑ]+)\*'), (m) => vars[m.group(1)] ?? m.group(0)!);
  }

  Future<void> _editar(Map<String, dynamic> r) async {
    final clave = r['clave'] as String;
    final sugerido = r['mensaje_sugerido'] as String? ?? '';
    final msgCtrl = TextEditingController(text: (r['mensaje'] as String?)?.isNotEmpty == true ? r['mensaje'] as String : sugerido);
    final campos = ((r['campos'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final config = Map<String, dynamic>.from((r['config'] as Map?) ?? {});
    final ctrls = {for (final c in campos) c['clave'] as String: TextEditingController(text: '${config[c['clave']] ?? ''}')};
    const variables = ['NOMBRE', 'FOLIO', 'MONTO', 'LIGA', 'TALLER', 'ANTICIPO', 'VENCE', 'CUPON', 'RESENA'];

    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(r['titulo'] as String? ?? ''), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...campos.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(
            controller: ctrls[c['clave']],
            keyboardType: c['tipo'] == 'numero' ? TextInputType.number : c['tipo'] == 'url' ? TextInputType.url : TextInputType.text,
            textCapitalization: c['clave'] == 'cupon' ? TextCapitalization.characters : TextCapitalization.none,
            decoration: InputDecoration(labelText: tr(c['etiqueta'] as String? ?? ''),
              helperText: c['ayuda'] == null ? null : tr(c['ayuda'] as String), helperMaxLines: 3,
              isDense: true, border: const OutlineInputBorder())))),
          TextField(controller: msgCtrl, maxLines: 7, minLines: 4, onChanged: (_) => setM(() {}),
            decoration: InputDecoration(labelText: tr('Mensaje'), alignLabelWithHint: true, border: const OutlineInputBorder())),
          const SizedBox(height: 6),
          Text(tr('Toca una variable para agregarla. Se cambia sola por el dato de cada cliente; si no hay dato, ese renglón no se manda.'),
            style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          const SizedBox(height: 4),
          Wrap(spacing: 4, runSpacing: 0, children: variables.map((v) => ActionChip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Text('*$v*', style: const TextStyle(fontSize: 10.5)),
            onPressed: () {
              final sel = msgCtrl.selection;
              final t = msgCtrl.text;
              final pos = sel.isValid ? sel.start : t.length;
              msgCtrl.text = '${t.substring(0, pos)}*$v*${t.substring(pos)}';
              msgCtrl.selection = TextSelection.collapsed(offset: pos + v.length + 2);
              setM(() {});
            })).toList()),
          const SizedBox(height: 10),
          Text(tr('Así lo verá tu cliente:'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFE7FFDB), borderRadius: BorderRadius.circular(10)),
            child: Text(_vistaPrevia(msgCtrl.text), style: const TextStyle(fontSize: 12.5, height: 1.35))),
          const SizedBox(height: 12),
          Row(children: [
            TextButton(onPressed: () { msgCtrl.text = sugerido; setM(() {}); }, child: Text(tr('Usar el sugerido'))),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
              onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Guardar'))),
          ]),
        ])))));
    if (ok != true) return;
    final nuevaConfig = <String, dynamic>{};
    for (final c in campos) {
      final k = c['clave'] as String;
      final v = ctrls[k]!.text.trim();
      nuevaConfig[k] = c['tipo'] == 'numero' ? (int.tryParse(v) ?? config[k]) : v;
    }
    final guardado = await _guardar(clave, {'mensaje': msgCtrl.text.trim(), 'config': nuevaConfig});
    if (guardado && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('✅ Guardado')), backgroundColor: AppColors.verde));
    }
  }

  Widget _tarjetaPlan() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('El marketing automático es del plan Pro'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(tr('Puedes ver las automatizaciones; para prenderlas, sube de plan.'),
        style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
      const SizedBox(height: 10),
      ElevatedButton(
        onPressed: () => AuthService.exigirModulo(context, 'marketing', funcion: tr('Marketing automático')),
        child: Text(tr('Ver planes'))),
    ]));

  Widget _avisoChico(IconData icono, String texto) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(icono, size: 18, color: AppColors.ambar),
      const SizedBox(width: 8),
      Expanded(child: Text(texto, style: const TextStyle(fontSize: 12))),
    ]));

  Widget _aviso(IconData icono, String texto, {Widget? accion}) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icono, size: 40, color: AppColors.grisBorde),
      const SizedBox(height: 8),
      Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textoSecundario)),
      if (accion != null) accion,
    ])));
}
