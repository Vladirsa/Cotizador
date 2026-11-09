// lib/screens/crm_seguimiento_screen.dart
// HETNA CNC — CRM con seguimiento (ver lib/services/crm_service.dart)
//
//   SeguimientoBody     pestaña "Hoy": a quién hablarle hoy + embudo
//   TarjetaCrmCliente   en la ficha del cliente: último contacto, próximo
//                       paso, registrar contacto y bitácora
//   dialogoPerdida      por qué se perdió una cotización
//   ImportarClientesScreen  de Excel o CSV
import 'dart:convert';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/crm_service.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_service.dart';
import '../i18n/tr.dart';
import 'clientes_screen.dart';

String _tel(Cliente c) {
  final n = c.whatsappNumero;
  if (n.isEmpty) return '';
  return n.length == 10 ? '521$n' : n;
}

Future<void> _abrirWA(BuildContext context, Cliente c, String mensaje) async {
  final n = _tel(c);
  if (n.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Este cliente no tiene WhatsApp.'))));
    return;
  }
  await WhatsAppService.abrirChatConSelector(context, numero: n, mensaje: mensaje);
  if (c.id != null) {
    try { await CrmService.registrarContacto(c.id!, 'whatsapp', null); } catch (_) {}
  }
}

// ══════════════════════════════════════════════════════
// HOY
// ══════════════════════════════════════════════════════
class SeguimientoBody extends StatefulWidget {
  const SeguimientoBody({super.key});
  @override
  State<SeguimientoBody> createState() => _SeguimientoBodyState();
}

class _SeguimientoBodyState extends State<SeguimientoBody> {
  List<TareaSeguimiento> _tareas = [];
  Embudo? _embudo;
  bool _cargando = true;
  String _error = '';
  final _fmt = NumberFormat(r'$#,##0', 'es_MX');

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = ''; });
    try {
      final t = await CrmService.hoy();
      final e = await CrmService.embudo();
      if (mounted) setState(() { _tareas = t; _embudo = e; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _error = e.toString().contains('proximo_paso') || e.toString().contains('contactos_cliente')
        ? tr('Falta correr supabase/crm_seguimiento.sql en Supabase.') : e.toString(); });
    }
  }

  Future<void> _mensaje(TareaSeguimiento t) async {
    String msg;
    final nombre = t.cliente.nombre.split(' ').first;
    if (t.tipo == 'cotizacion' && t.cotizacion != null) {
      msg = await WhatsAppService.getPlantilla(tipo: t.dias >= 5 ? 'seguimiento_dia5' : 'seguimiento_dia3', nombreCliente: nombre, folio: t.cotizacion!.folio, monto: t.cotizacion!.total);
    } else if (t.tipo == 'dormido') {
      msg = trf('Hola {0}, soy de {1}. Hace tiempo que no nos saludamos: ¿tienes algún proyecto en puerta? Con gusto te cotizo.', [nombre, AuthService.marcaTaller]);
    } else {
      msg = trf('Hola {0}, te escribo de {1} para darle seguimiento: {2}.', [nombre, AuthService.marcaTaller, t.titulo]);
    }
    if (mounted) await _abrirWA(context, t.cliente, msg);
    _cargar();
  }

  Future<void> _resolver(TareaSeguimiento t) async {
    if (t.tipo == 'cotizacion' && t.cotizacion != null) {
      final r = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.check_circle, color: AppColors.verde), title: Text(tr('La aceptó: marcar aprobada')), onTap: () => Navigator.pop(ctx, 'ganada')),
        ListTile(leading: const Icon(Icons.cancel, color: AppColors.rojo), title: Text(tr('Se perdió (decir por qué)')), onTap: () => Navigator.pop(ctx, 'perdida')),
        ListTile(leading: const Icon(Icons.schedule, color: AppColors.ambar), title: Text(tr('Sigue pensándolo: recordarme después')), onTap: () => Navigator.pop(ctx, 'despues')),
      ])));
      if (r == 'ganada') await SupabaseService.cambiarEstadoCotizacion(t.cotizacion!.id!, 'Aprobada');
      if (r == 'perdida') await dialogoPerdida(context, t.cotizacion!);
      if (r == 'despues') await _programarPaso(t.cliente, trf('Volver a preguntar por {0}', [t.cotizacion!.folio ?? tr('la cotización')]));
    } else if (t.tipo == 'paso') {
      await CrmService.guardarProximoPaso(t.cliente.id!, null, null);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Hecho. Si quieres otro paso, ponlo en la ficha del cliente.'))));
    } else {
      await CrmService.registrarContacto(t.cliente.id!, 'otro', tr('Se intentó reactivar'));
    }
    _cargar();
  }

  Future<void> _programarPaso(Cliente c, String texto) async {
    final f = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 3)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (f == null) return;
    await CrmService.guardarProximoPaso(c.id!, texto, f);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.warning_amber, color: AppColors.ambar, size: 40), const SizedBox(height: 8),
      Text(_error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
      TextButton(onPressed: _cargar, child: Text(tr('Reintentar'))),
    ])));
    final e = _embudo;
    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(12), children: [
      if (e != null) _embudoWidget(e),
      const SizedBox(height: 8),
      Text(tr('A quién hablarle hoy').toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textoSecundario, letterSpacing: .6)),
      const SizedBox(height: 6),
      if (_tareas.isEmpty) Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.grisBorde)),
        child: Row(children: [const Icon(Icons.celebration_outlined, color: AppColors.verde), const SizedBox(width: 10), Expanded(child: Text(tr('Nada pendiente. Las cotizaciones enviadas sin respuesta, los pasos programados y los clientes que dejaron de comprar aparecen aquí.'), style: const TextStyle(fontSize: 13)))])),
      ..._tareas.map(_tarjetaTarea),
    ]));
  }

  Widget _embudoWidget(Embudo e) {
    Widget paso(String nombre, int n, Color color, String sub) => Expanded(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(.4))),
      child: Column(children: [
        Text('$n', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(nombre, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, color: AppColors.textoSecundario)),
      ])));
    final motivos = e.motivos.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final montoGanado = e.ganadas.fold<double>(0, (s, c) => s + c.total);
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.grisBorde)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(tr('Embudo (últimos 90 días)'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(trf('Cierre {0}%', [e.tasaCierre.toStringAsFixed(0)]), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.verde)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          paso(tr('Potenciales'), e.potenciales.length, AppColors.azul, tr('sin cotizar')),
          paso(tr('Cotizados'), e.cotizados.length, AppColors.ambar, tr('esperando')),
          paso(tr('Ganados'), e.ganadas.length, AppColors.verde, _fmt.format(montoGanado)),
          paso(tr('Perdidos'), e.perdidas.length, AppColors.rojo, tr('con motivo')),
        ]),
        if (motivos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: motivos.map((m) => Chip(
            visualDensity: VisualDensity.compact, backgroundColor: AppColors.rojoClaro,
            label: Text('${tr(CrmService.motivosPerdida[m.key] ?? tr('Sin motivo'))}: ${m.value}', style: const TextStyle(fontSize: 11, color: AppColors.rojo)))).toList()),
        ],
      ]));
  }

  Widget _tarjetaTarea(TareaSeguimiento t) {
    final color = t.tipo == 'paso' ? AppColors.ambar : t.tipo == 'cotizacion' ? AppColors.azul : AppColors.rojo;
    final icono = t.tipo == 'paso' ? Icons.flag_outlined : t.tipo == 'cotizacion' ? Icons.description_outlined : Icons.bedtime_outlined;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.grisBorde), boxShadow: [BoxShadow(color: color, offset: const Offset(-3, 0))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icono, size: 18, color: color), const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistorialClienteScreen(cliente: t.cliente))).then((_) => _cargar()),
              child: Text(t.cliente.nombreCompleto, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.azul))),
            Text(tr(t.titulo), style: const TextStyle(fontSize: 13)),
            Text(tr(t.detalle), style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario)),
          ])),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ElevatedButton.icon(onPressed: () => _mensaje(t), icon: const Icon(Icons.chat, size: 14, color: Colors.white),
            label: Text(tr('WhatsApp'), style: const TextStyle(fontSize: 12, color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.whatsapp, padding: const EdgeInsets.symmetric(vertical: 8)))),
          const SizedBox(width: 6),
          if (_tel(t.cliente).isNotEmpty) OutlinedButton(onPressed: () async {
              await launchUrl(Uri.parse('tel:+${_tel(t.cliente)}'));
              if (t.cliente.id != null) { try { await CrmService.registrarContacto(t.cliente.id!, 'llamada', null); } catch (_) {} }
            }, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), child: const Icon(Icons.call, size: 16)),
          const SizedBox(width: 6),
          Expanded(child: OutlinedButton(onPressed: () => _resolver(t), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
            child: Text(t.tipo == 'cotizacion' ? tr('¿Qué pasó?') : tr('Hecho'), style: const TextStyle(fontSize: 12)))),
        ]),
      ]));
  }
}

// ══════════════════════════════════════════════════════
// FICHA DEL CLIENTE: seguimiento
// ══════════════════════════════════════════════════════
class TarjetaCrmCliente extends StatefulWidget {
  final Cliente cliente;
  const TarjetaCrmCliente({super.key, required this.cliente});
  @override
  State<TarjetaCrmCliente> createState() => _TarjetaCrmClienteState();
}

class _TarjetaCrmClienteState extends State<TarjetaCrmCliente> {
  late Cliente _c = widget.cliente;
  List<ContactoCliente> _contactos = [];
  bool _verTodo = false;
  final _fecha = DateFormat('dd/MM/yyyy');
  final _hora = DateFormat('dd/MM HH:mm');

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    try {
      final cs = await CrmService.contactos(_c.id!);
      final r = await SupabaseService.getClientes();
      final actual = r.where((x) => x.id == _c.id).toList();
      if (mounted) setState(() { _contactos = cs; if (actual.isNotEmpty) _c = actual.first; });
    } catch (_) {}
  }

  Future<void> _registrar() async {
    String tipo = 'llamada';
    final nota = TextEditingController();
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Registrar contacto'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, children: CrmService.tiposContacto.entries.map((e) => ChoiceChip(label: Text(tr(e.value)), selected: tipo == e.key, onSelected: (_) => setM(() => tipo = e.key))).toList()),
          const SizedBox(height: 10),
          TextField(controller: nota, maxLines: 2, decoration: InputDecoration(labelText: tr('¿Qué se habló? (opcional)'), isDense: true, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul, minimumSize: const Size(0, 46)),
            child: Text(tr('Guardar'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
        ]))));
    if (ok != true) return;
    await CrmService.registrarContacto(_c.id!, tipo, nota.text);
    _cargar();
  }

  Future<void> _paso() async {
    final texto = TextEditingController(text: _c.proximoPaso ?? '');
    DateTime? fecha = _c.proximoPasoFecha ?? DateTime.now().add(const Duration(days: 3));
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Próximo paso'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          TextField(controller: texto, autofocus: true, decoration: InputDecoration(labelText: tr('Qué hay que hacer'), hintText: tr('Ej. Mandarle la cotización del letrero'), isDense: true, border: const OutlineInputBorder())),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () async {
              final f = await showDatePicker(context: ctx, initialDate: fecha!, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (f != null) setM(() => fecha = f);
            }, icon: const Icon(Icons.event, size: 16), label: Text(trf('Para el {0}', [_fecha.format(fecha!)]))),
          const SizedBox(height: 12),
          Row(children: [
            if ((_c.proximoPaso ?? '').isNotEmpty) TextButton(onPressed: () { texto.clear(); Navigator.pop(ctx, true); }, child: Text(tr('Quitar'), style: const TextStyle(color: AppColors.rojo))),
            const Spacer(),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul), child: Text(tr('Guardar'), style: const TextStyle(color: Colors.white))),
          ]),
        ]))));
    if (ok != true) return;
    await CrmService.guardarProximoPaso(_c.id!, texto.text, texto.text.trim().isEmpty ? null : fecha);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final dias = _c.ultimoContacto == null ? null : DateTime.now().difference(_c.ultimoContacto!).inDays;
    final vencido = _c.proximoPasoFecha != null && _c.proximoPasoFecha!.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    final lista = _verTodo ? _contactos : _contactos.take(3).toList();
    return Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(14, 8, 14, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(dias == null ? tr('Sin contactos registrados') : dias == 0 ? tr('Último contacto: hoy') : trf('Último contacto: hace {0} días', [dias]),
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: dias != null && dias > 30 ? AppColors.rojo : AppColors.textoSecundario))),
        TextButton.icon(onPressed: _registrar, icon: const Icon(Icons.add_comment_outlined, size: 16), label: Text(tr('Registrar'), style: const TextStyle(fontSize: 12))),
      ]),
      GestureDetector(onTap: _paso, child: Container(width: double.infinity, padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: vencido ? AppColors.rojoClaro : AppColors.ambarClaro, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(Icons.flag_outlined, size: 16, color: vencido ? AppColors.rojo : AppColors.ambar), const SizedBox(width: 8),
          Expanded(child: (_c.proximoPaso ?? '').isEmpty
            ? Text(tr('Sin próximo paso. Toca para poner uno.'), style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario))
            : Text('${_c.proximoPaso} · ${_c.proximoPasoFecha != null ? _fecha.format(_c.proximoPasoFecha!) : ''}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: vencido ? AppColors.rojo : AppColors.textoPrincipal))),
          const Icon(Icons.edit_outlined, size: 14, color: AppColors.textoSecundario),
        ]))),
      if (lista.isNotEmpty) ...[
        const SizedBox(height: 8),
        ...lista.map((k) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(k.tipo == 'whatsapp' ? Icons.chat : k.tipo == 'llamada' ? Icons.call : k.tipo == 'visita' ? Icons.store : k.tipo == 'correo' ? Icons.mail_outline : Icons.circle, size: 13, color: AppColors.textoSecundario),
          const SizedBox(width: 6),
          Expanded(child: Text('${k.fecha != null ? _hora.format(k.fecha!) : ''} · ${tr(CrmService.tiposContacto[k.tipo] ?? k.tipo)}${(k.quien ?? '').isNotEmpty ? ' · ${k.quien}' : ''}${(k.nota ?? '').isNotEmpty ? '\n${k.nota}' : ''}', style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario))),
        ]))),
        if (_contactos.length > 3) TextButton(onPressed: () => setState(() => _verTodo = !_verTodo), child: Text(_verTodo ? tr('Ver menos') : trf('Ver los {0}', [_contactos.length]), style: const TextStyle(fontSize: 12))),
      ],
    ]));
  }
}

// ══════════════════════════════════════════════════════
// SE PERDIÓ: POR QUÉ
// ══════════════════════════════════════════════════════
Future<bool> dialogoPerdida(BuildContext context, Cotizacion c) async {
  String motivo = 'precio';
  final nota = TextEditingController();
  final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trf('¿Por qué se perdió {0}?', [c.folio ?? tr('la cotización')]), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(tr('Con esto el embudo te dice qué estás perdiendo más: precio, tiempos o seguimiento.'), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
        const SizedBox(height: 10),
        ...CrmService.motivosPerdida.entries.map((e) => RadioListTile<String>(dense: true, contentPadding: EdgeInsets.zero, value: e.key, groupValue: motivo, title: Text(tr(e.value), style: const TextStyle(fontSize: 13.5)), onChanged: (v) => setM(() => motivo = v!))),
        TextField(controller: nota, decoration: InputDecoration(labelText: tr('Nota (opcional)'), isDense: true, border: const OutlineInputBorder())),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo, minimumSize: const Size(0, 46)),
          child: Text(tr('Marcar como perdida'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
      ]))));
  if (ok != true) return false;
  await CrmService.perder(c.id!, motivo, nota.text);
  return true;
}

// ══════════════════════════════════════════════════════
// IMPORTAR DE EXCEL O CSV
// ══════════════════════════════════════════════════════
class ImportarClientesScreen extends StatefulWidget {
  const ImportarClientesScreen({super.key});
  @override
  State<ImportarClientesScreen> createState() => _ImportarClientesScreenState();
}

class _ImportarClientesScreenState extends State<ImportarClientesScreen> {
  List<List<String>> _filas = [];
  List<String> _encabezados = [];
  final Map<String, int> _mapa = {}; // campo → columna
  bool _trabajando = false;
  String _nombreArchivo = '';

  static const _campos = {
    'nombre': ['nombre', 'cliente', 'contacto', 'name'],
    'empresa': ['empresa', 'compañia', 'compania', 'negocio', 'razon social', 'razón social', 'company'],
    'whatsapp': ['whatsapp', 'celular', 'cel', 'movil', 'móvil', 'phone', 'mobile'],
    'telefono': ['telefono', 'teléfono', 'tel', 'fijo'],
    'correo': ['correo', 'email', 'e-mail', 'mail'],
    'ciudad': ['ciudad', 'city', 'municipio'],
    'estado': ['estado', 'state'],
    'notas': ['notas', 'nota', 'comentarios', 'observaciones'],
  };

  Future<void> _elegir() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls', 'csv', 'txt'], withData: true);
    final f = r?.files.first;
    if (f == null || f.bytes == null) return;
    setState(() { _trabajando = true; _nombreArchivo = f.name; });
    try {
      List<List<String>> filas = [];
      final ext = f.extension?.toLowerCase() ?? '';
      if (ext == 'xlsx' || ext == 'xls') {
        final libro = Excel.decodeBytes(f.bytes!);
        final hoja = libro.tables.values.firstWhere((t) => t.maxRows > 0, orElse: () => libro.tables.values.first);
        for (final r in hoja.rows) {
          filas.add(r.map((c) => (c?.value?.toString() ?? '').trim()).toList());
        }
      } else {
        final texto = utf8.decode(f.bytes!, allowMalformed: true);
        final sep = texto.contains('\t') ? '\t' : (texto.split('\n').first.split(';').length > texto.split('\n').first.split(',').length ? ';' : ',');
        for (final l in const LineSplitter().convert(texto)) {
          if (l.trim().isEmpty) continue;
          filas.add(_partirCsv(l, sep));
        }
      }
      filas = filas.where((r) => r.any((c) => c.isNotEmpty)).toList();
      if (filas.length < 2) throw Exception(tr('El archivo no trae filas con datos.'));
      final enc = filas.first.map((e) => e.toLowerCase().trim()).toList();
      _mapa.clear();
      _campos.forEach((campo, alias) {
        for (var i = 0; i < enc.length; i++) {
          if (alias.any((a) => enc[i] == a || enc[i].startsWith(a)) && !_mapa.containsValue(i)) { _mapa[campo] = i; break; }
        }
      });
      setState(() { _encabezados = filas.first; _filas = filas.sublist(1); });
      if (!_mapa.containsKey('nombre')) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('No encontré la columna "Nombre": elígela abajo.'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trf('No pude leer el archivo: {0}', [e])), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  static List<String> _partirCsv(String linea, String sep) {
    final out = <String>[];
    final b = StringBuffer();
    bool enComillas = false;
    for (var i = 0; i < linea.length; i++) {
      final ch = linea[i];
      if (ch == '"') {
        if (enComillas && i + 1 < linea.length && linea[i + 1] == '"') { b.write('"'); i++; } else { enComillas = !enComillas; }
      } else if (ch == sep && !enComillas) { out.add(b.toString().trim()); b.clear(); }
      else { b.write(ch); }
    }
    out.add(b.toString().trim());
    return out;
  }

  String _v(List<String> fila, String campo) {
    final i = _mapa[campo];
    return i == null || i >= fila.length ? '' : fila[i].trim();
  }

  List<Cliente> get _clientes => _filas.map((f) {
    final nombre = _v(f, 'nombre').isNotEmpty ? _v(f, 'nombre') : _v(f, 'empresa');
    if (nombre.isEmpty) return null;
    final vacio = (String s) => s.isEmpty ? null : s;
    return Cliente(nombre: nombre, empresa: vacio(_v(f, 'empresa')), whatsapp: vacio(_v(f, 'whatsapp')), telefono: vacio(_v(f, 'telefono')),
      correo: vacio(_v(f, 'correo')), ciudad: vacio(_v(f, 'ciudad')), estado: vacio(_v(f, 'estado')), notas: vacio(_v(f, 'notas')));
  }).whereType<Cliente>().toList();

  Future<void> _importar() async {
    final lista = _clientes;
    if (lista.isEmpty) return;
    setState(() => _trabajando = true);
    try {
      final r = await CrmService.importar(lista);
      if (!mounted) return;
      await showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(tr('Importación lista')),
        content: Text(trf('{0} clientes nuevos. {1} ya existían y se saltaron.', [r.nuevos, r.repetidos])),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Aceptar')))]));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = _clientes;
    return Scaffold(backgroundColor: AppColors.gris, appBar: AppBar(title: Text(tr('Importar clientes'))),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.grisBorde)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Sube un Excel (.xlsx) o un CSV con una fila por cliente. La primera fila son los títulos: Nombre, Empresa, WhatsApp, Teléfono, Correo, Ciudad, Estado, Notas (los que tengas).'), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            ElevatedButton.icon(onPressed: _trabajando ? null : _elegir, icon: const Icon(Icons.upload_file, color: Colors.white, size: 18),
              label: Text(_nombreArchivo.isEmpty ? tr('Elegir archivo') : _nombreArchivo, style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul)),
          ])),
        if (_encabezados.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(tr('Columnas').toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textoSecundario)),
          const SizedBox(height: 6),
          ..._campos.keys.map((campo) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
            SizedBox(width: 90, child: Text(tr(campo[0].toUpperCase() + campo.substring(1)), style: TextStyle(fontSize: 13, fontWeight: campo == 'nombre' ? FontWeight.w700 : FontWeight.w500))),
            Expanded(child: DropdownButtonFormField<int>(value: _mapa[campo], isExpanded: true,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
              items: [DropdownMenuItem<int>(value: null, child: Text(tr('— no viene —'), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario))),
                ...List.generate(_encabezados.length, (i) => DropdownMenuItem(value: i, child: Text(_encabezados[i].isEmpty ? trf('Columna {0}', [i + 1]) : _encabezados[i], style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))],
              onChanged: (v) => setState(() { if (v == null) _mapa.remove(campo); else _mapa[campo] = v; }))),
          ]))),
          const SizedBox(height: 10),
          Text(trf('{0} clientes listos para importar', [lista.length]), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ...lista.take(5).map((c) => Text('• ${c.nombreCompleto}${(c.whatsapp ?? c.telefono ?? '').isNotEmpty ? ' · ${c.whatsapp ?? c.telefono}' : ''}', style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario))),
          if (lista.length > 5) Text(trf('… y {0} más', [lista.length - 5]), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _trabajando || lista.isEmpty || !_mapa.containsKey('nombre') ? null : _importar,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde, minimumSize: const Size(0, 48)),
            child: Text(_trabajando ? tr('Importando…') : trf('Importar {0} clientes', [lista.length]), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
          Text(tr('Los que ya existan (mismo WhatsApp o mismo nombre y empresa) se saltan.'), style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario)),
        ],
      ]));
  }
}
