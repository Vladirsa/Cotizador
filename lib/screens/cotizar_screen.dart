import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import '../services/whatsapp_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:file_picker/file_picker.dart';
import '../services/archivo_cad_service.dart';
import 'simulador_screen.dart';
import 'envios_screen.dart';
import '../services/auth_service.dart';
import '../i18n/tr.dart';

class CotizarScreen extends StatefulWidget {
  final dynamic itemInicial;
  final List<dynamic>? carritoSimulador;
  const CotizarScreen({super.key, this.itemInicial, this.carritoSimulador});
  @override
  State<CotizarScreen> createState() => _CotizarScreenState();
}

class _CotizarScreenState extends State<CotizarScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        title: Text(tr('Cotizador')),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          tabs: [
            Tab(text: tr('Nueva')),
            Tab(text: tr('Mis cotizaciones')),
            Tab(text: tr('Catálogo')),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _NuevaCotizacion(itemInicial: widget.itemInicial, carritoSimulador: widget.carritoSimulador, onGuardada: () => _tabs.animateTo(1)),
        _ListaCotizaciones(),
        const _CatalogoPDFs(),
      ]),
    );
  }
}

// ═══════════════════════════════════════════
// LISTA DE COTIZACIONES — con búsqueda + filtro de fechas
// ═══════════════════════════════════════════
class _ListaCotizaciones extends StatefulWidget {
  @override
  State<_ListaCotizaciones> createState() => _ListaCotizacionesState();
}

class _ListaCotizacionesState extends State<_ListaCotizaciones> {
  List<Cotizacion> _cotizaciones = [];
  bool _cargando = true;
  String _filtro = 'Todos';
  String _busqueda = '';
  DateTimeRange? _rangoFechas;
  final _busquedaCtrl = TextEditingController();
  final _fmt = NumberFormat('\$#,##0', 'es_MX');
  final _estados = ['Todos', 'Borrador', 'Enviada', 'Aprobada', 'Pedido', 'Vencida'];
  final _colores = {
    'Borrador': Colors.grey, 'Enviada': Color(0xFF185fa5),
    'Aprobada': Color(0xFF1d9e75), 'Pedido': Color(0xFF7c3aed),
    'Vencida': Color(0xFFef9f27), 'Rechazada': Color(0xFFe24b4a),
  };

  @override
  void initState() { super.initState(); _cargar(); }

  @override
  void dispose() { _busquedaCtrl.dispose(); super.dispose(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final cots = await SupabaseService.getCotizaciones();
      for (final c in cots) {
        if (c.items.isEmpty && c.id != null && c.total == 0) {
          final items = await SupabaseService.getCotizacionItems(c.id!);
          c.items.addAll(items);
        }
      }
      if (mounted) setState(() { _cotizaciones = cots; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  List<Cotizacion> get _filtradas {
    var lista = _filtro == 'Todos'
      ? _cotizaciones
      : _cotizaciones.where((c) => c.estado == _filtro).toList();

    if (_busqueda.trim().isNotEmpty) {
      final q = _busqueda.trim().toLowerCase();
      lista = lista.where((c) {
        final nombre = (c.cliente?.nombre ?? '').toLowerCase();
        final empresa = (c.cliente?.empresa ?? '').toLowerCase();
        final folio = (c.folio ?? '').toLowerCase();
        return nombre.contains(q) || empresa.contains(q) || folio.contains(q);
      }).toList();
    }

    if (_rangoFechas != null) {
      lista = lista.where((c) {
        if (c.createdAt == null) return false;
        final fecha = DateTime(c.createdAt!.year, c.createdAt!.month, c.createdAt!.day);
        final desde = DateTime(_rangoFechas!.start.year, _rangoFechas!.start.month, _rangoFechas!.start.day);
        final hasta = DateTime(_rangoFechas!.end.year, _rangoFechas!.end.month, _rangoFechas!.end.day);
        return !fecha.isBefore(desde) && !fecha.isAfter(hasta);
      }).toList();
    }

    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
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

      Container(color: Colors.white, padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:
          _estados.map((e) {
            final color = _colores[e] ?? AppColors.azul;
            final count = e == 'Todos' ? _cotizaciones.length
              : _cotizaciones.where((c) => c.estado == e).length;
            final activo = _filtro == e;
            return GestureDetector(
              onTap: () => setState(() => _filtro = e),
              child: Container(margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: activo ? (e == 'Todos' ? AppColors.azul : color) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: activo ? (e == 'Todos' ? AppColors.azul : color) : AppColors.grisBorde)),
                child: Text('${tr(e)} ($count)', style: TextStyle(fontSize: 11,
                  color: activo ? Colors.white : AppColors.textoSecundario,
                  fontWeight: activo ? FontWeight.w600 : FontWeight.normal))));
          }).toList()))),
      Expanded(child: _cargando
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _cargar, child: _filtradas.isEmpty
            ? Center(child: Text(tr('No hay cotizaciones'), style: TextStyle(color: AppColors.textoSecundario)))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _filtradas.length,
                itemBuilder: (_, i) => _TarjetaCotizacion(
                  cotizacion: _filtradas[i],
                  colores: _colores,
                  onActualizar: _cargar)))),
    ]);
  }
}

// ═══════════════════════════════════════════
// TARJETA DE COTIZACIÓN — con borrar disponible en todos los estados
// ═══════════════════════════════════════════
class _TarjetaCotizacion extends StatelessWidget {
  final Cotizacion cotizacion;
  final Map<String, Color> colores;
  final VoidCallback onActualizar;
  const _TarjetaCotizacion({required this.cotizacion, required this.colores, required this.onActualizar});
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final color = colores[cotizacion.estado] ?? Colors.grey;
    final nombre = cotizacion.cliente?.nombre ?? cotizacion.cliente?.empresa ?? tr('Sin cliente');
    final montoItems = cotizacion.items.fold(0.0, (s, i) => s + i.subtotal);
    final monto = cotizacion.total > 0 ? cotizacion.total
      : montoItems > 0 ? montoItems * 1.16
      : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color, width: 4),
          top: BorderSide(color: AppColors.grisBorde, width: 0.5),
          right: BorderSide(color: AppColors.grisBorde, width: 0.5),
          bottom: BorderSide(color: AppColors.grisBorde, width: 0.5))),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(nombre), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(tr(cotizacion.folio ?? ''), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            if (cotizacion.createdAt != null)
              Text(DateFormat(enIngles ? 'MM/dd/yyyy' : 'dd/MM/yyyy').format(cotizacion.createdAt!),
                style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(tr(cotizacion.estado), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600))),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(tr(monto > 0 ? fmt.format(monto) : tr('Sin monto')),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                color: monto > 0 ? AppColors.azul : AppColors.textoSecundario)),
            if (cotizacion.items.isNotEmpty)
              Text(trf(cotizacion.items.length > 1 ? '{0} productos' : '{0} producto', [cotizacion.items.length]),
                style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _eliminarCotizacion(context),
              child: const Icon(Icons.delete_outline, size: 18, color: AppColors.rojo)),
          ]),
        ])),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(children: [
            Row(children: [
              if (cotizacion.estado == 'Borrador' || cotizacion.estado == 'Pedido')
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _editarCotizacion(context),
                  icon: const Icon(Icons.edit_outlined, size: 15, color: Colors.white),
                  label: Text(tr('Editar'), style: TextStyle(fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azul,
                    padding: const EdgeInsets.symmetric(vertical: 8)))),
              if (cotizacion.estado == 'Borrador' || cotizacion.estado == 'Pedido')
                const SizedBox(width: 6),
              if (cotizacion.estado == 'Borrador')
                ElevatedButton(
                  onPressed: () => _cambiarEstado(context, 'Enviada'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF185fa5),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  child: Text(tr('→ Enviada'), style: TextStyle(fontSize: 11, color: Colors.white))),
              if (cotizacion.estado == 'Enviada')
                Expanded(child: ElevatedButton(
                  onPressed: () => _cambiarEstado(context, 'Aprobada'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1d9e75),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  child: Text(tr('→ Aprobada'), style: TextStyle(fontSize: 11, color: Colors.white)))),
              if (cotizacion.estado == 'Aprobada')
                Expanded(child: ElevatedButton(
                  onPressed: () => _convertirPedido(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7c3aed),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  child: Text(tr('→ Pedido'), style: TextStyle(fontSize: 11, color: Colors.white)))),
            ]),
            if (cotizacion.estado == 'Borrador') ...[
              const SizedBox(height: 6),
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _editarCotizacion(context),
                  icon: const Icon(Icons.edit_outlined, size: 15, color: Colors.white),
                  label: Text(tr('Editar cotización'),
                    style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azul,
                    padding: const EdgeInsets.symmetric(vertical: 10)))),
              const SizedBox(height: 6),
              _BtnPdfWA(cotizacion: cotizacion),
            ],
            if (cotizacion.estado != 'Borrador') ...[
              const SizedBox(height: 6),
              SizedBox(width: double.infinity,
                child: _BtnPdfWA(cotizacion: cotizacion)),
            ],
          ])),
      ]));
  }

  void _editarCotizacion(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text(trf('Editar — {0}', [(cotizacion.folio ?? tr('cotización'))])),
          backgroundColor: Colors.white),
        body: _NuevaCotizacion(
          cotizacionEditar: cotizacion,
          onGuardada: () { Navigator.pop(context); onActualizar(); }))));
  }

  Future<void> _cambiarEstado(BuildContext context, String nuevoEstado) async {
    try {
      await SupabaseService.cambiarEstadoCotizacion(cotizacion.id!, nuevoEstado);
      onActualizar();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(trf('✅ Estado → {0}', [nuevoEstado])), backgroundColor: AppColors.azul));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _convertirPedido(BuildContext context) async {
    try {
      Cotizacion cotConItems = cotizacion;
      if (cotizacion.items.isEmpty && cotizacion.id != null) {
        final items = await SupabaseService.getCotizacionItems(cotizacion.id!);
        cotConItems = cotizacion.copiaConItems(items);
      }
      await SupabaseService.convertirEnPedido(cotConItems);
      onActualizar();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('✅ ¡Pedido creado! Visible en Avances')),
        backgroundColor: AppColors.verde));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _eliminarCotizacion(BuildContext context) async {
    final tienePedido = cotizacion.estado == 'Pedido';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('Eliminar cotización')),
        content: Text(tr(tienePedido
          ? tr('Esta cotización tiene un pedido vinculado. Al eliminarla también se eliminará el pedido. ¿Continuar?')
          : trf('¿Eliminar la cotización {0}? Esta acción no se puede deshacer.', [(cotizacion.folio ?? "")]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Cancelar'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
            child: Text(tr('Eliminar'), style: TextStyle(color: Colors.white))),
        ]));
    if (confirmar == true) {
      try {
        if (tienePedido && cotizacion.id != null) {
          await SupabaseService.eliminarPedidoPorCotizacion(cotizacion.id!);
        }
        await SupabaseService.eliminarCotizacion(cotizacion.id!);
        onActualizar();
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('🗑️ Cotización eliminada')),
          backgroundColor: AppColors.rojo));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(trf('Error al eliminar: {0}', [e]))));
      }
    }
  }
}

// ═══════════════════════════════════════════
// NUEVA / EDITAR COTIZACIÓN
// ═══════════════════════════════════════════
class _NuevaCotizacion extends StatefulWidget {
  final VoidCallback? onGuardada;
  final Cotizacion? cotizacionEditar;
  final dynamic itemInicial;
  final List<dynamic>? carritoSimulador;
  const _NuevaCotizacion({this.onGuardada, this.cotizacionEditar, this.itemInicial, this.carritoSimulador});
  @override
  State<_NuevaCotizacion> createState() => _NuevaCotizacionState();
}

class _NuevaCotizacionState extends State<_NuevaCotizacion> {
  Cliente? _cliente;

  // ── Cotización profesional (formato internacional) ──
  String _tipo = 'sencilla';          // 'sencilla' | 'profesional'
  String _tipoOriginal = 'sencilla';  // tipo con el que se abrió (al editar)
  bool _muestraGratis = false;        // la única profesional del plan Gratis
  // (clave en datos_pro, etiqueta, renglones, texto inicial)
  static const _camposProyecto = [
    ('proyecto', 'Proyecto / referencia del cliente', 1, ''),
    ('revision', 'Revisión', 1, 'A'),
    ('moneda', 'Moneda', 1, 'MXN'),
    ('resumen', 'Resumen: qué se cotiza y supuestos principales', 3, ''),
  ];
  static const _camposAlcance = [
    ('incluye', 'Incluye (uno por renglón)', 4, ''),
    ('no_incluye', 'No incluye (uno por renglón)', 4, ''),
  ];
  static const _camposTecnicos = [
    ('material', 'Material', 1, ''),
    ('medidas', 'Medidas / espesor', 1, ''),
    ('tolerancia', 'Tolerancia general', 1, ''),
    ('acabado', 'Acabado', 1, ''),
    ('archivo', 'Archivo recibido (DXF, STEP, plano...)', 1, ''),
    ('norma', 'Norma o especificación (si aplica)', 1, ''),
  ];
  // Croquis: con largo y ancho el PDF dibuja la pieza acotada (como plano)
  static const _camposCroquis = [
    ('croquis_largo', 'Largo (mm)', 1, ''),
    ('croquis_ancho', 'Ancho (mm)', 1, ''),
    ('croquis_espesor', 'Espesor (mm)', 1, ''),
    ('croquis_barreno_d', 'Diámetro de barrenos (mm, opcional)', 1, ''),
    ('croquis_barrenos', 'Número de barrenos (opcional)', 1, ''),
  ];
  static const _camposFabricacion = [
    ('proceso', 'Proceso (ej. router CNC 3 ejes)', 1, ''),
    ('maquina', 'Máquina', 1, ''),
    ('operaciones', 'Operaciones (corte, perforado, grabado...)', 2, ''),
    ('setups', 'Número de setups', 1, ''),
    ('inspeccion', 'Inspección (calibrador, micrómetro...)', 1, ''),
  ];
  static const _camposCondiciones = [
    ('calidad', 'Condiciones técnicas y de calidad', 3,
      'Inspección dimensional en cotas críticas antes de la entrega.'),
    ('cambios', 'Cambios y cancelaciones', 2,
      'Cambios de diseño o de cantidad después de aprobar pueden modificar precio y tiempo de entrega.'),
  ];
  final Map<String, TextEditingController> _pro = {};
  // Archivo de la pieza (DXF/SVG/STL/OBJ) leído por ArchivoCadService
  Map<String, dynamic>? _archivoInfo;
  List<List<List<double>>> _archivoGeo = [];
  bool _leyendoArchivo = false;

  TextEditingController _ctrlPro(String k, String inicial) =>
    _pro.putIfAbsent(k, () => TextEditingController(text: inicial));

  Map<String, dynamic> _datosPro() {
    final d = <String, dynamic>{};
    _pro.forEach((k, c) { if (c.text.trim().isNotEmpty) d[k] = c.text.trim(); });
    d['tiempo_entrega'] = _tiempoEntrega;
    if (_muestraGratis) d['muestra'] = true;
    if (_archivoInfo != null) {
      d['archivo_info'] = _archivoInfo;
      d['archivo_geo'] = _archivoGeo.map((t) => t.map((q) => [
        (q[0] * 100).round() / 100, (q[1] * 100).round() / 100]).toList()).toList();
    }
    return d;
  }

  Future<void> _subirArchivoPieza() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ArchivoCadService.extensiones, withData: true);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final bytes = f.bytes;
      if (bytes == null) return;
      setState(() => _leyendoArchivo = true);
      final g = ArchivoCadService.leer(f.name, bytes);
      String mm(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
      setState(() {
        _archivoInfo = g.toInfo();
        _archivoGeo = g.trazos;
        _ctrlPro('croquis_largo', '').text = mm(g.largo);
        _ctrlPro('croquis_ancho', '').text = mm(g.ancho);
        if (g.es3D && g.alto > 0) _ctrlPro('croquis_espesor', '').text = mm(g.alto);
        if (!g.es3D && g.barrenos > 0 && _ctrlPro('croquis_barrenos', '').text.isEmpty) {
          _ctrlPro('croquis_barrenos', '').text = '${g.barrenos}';
        }
        final arch = _ctrlPro('archivo', '');
        if (arch.text.trim().isEmpty) arch.text = '${g.nombre} (${g.tipo.toUpperCase()})';
        final med = _ctrlPro('medidas', '');
        if (med.text.trim().isEmpty) {
          final esp = _ctrlPro('croquis_espesor', '').text.trim();
          med.text = g.es3D
            ? '${mm(g.largo)} × ${mm(g.ancho)} × ${mm(g.alto)} mm'
            : '${mm(g.largo)} × ${mm(g.ancho)} mm${esp.isNotEmpty ? " · espesor $esp mm" : ""}';
        }
        _leyendoArchivo = false;
      });
    } catch (e) {
      setState(() => _leyendoArchivo = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(trf('No se pudo leer el archivo: {0}', [e.toString().replaceFirst('Exception: ', '')])),
        backgroundColor: AppColors.rojo));
    }
  }

  Widget _resumenArchivo() {
    final i = _archivoInfo!;
    final es3D = i['tipo'] == 'stl' || i['tipo'] == 'obj';
    String n(dynamic v, [int d = 1]) => ((v as num?) ?? 0).toStringAsFixed(d);
    final filas = <(String, String)>[
      (tr('Archivo'), '${i['nombre']} · ${(i['tipo'] as String).toUpperCase()} · ${i['unidades']}'),
      (tr('Medidas'), es3D
        ? '${n(i['largo'])} × ${n(i['ancho'])} × ${n(i['alto'])} mm'
        : '${n(i['largo'])} × ${n(i['ancho'])} mm'),
      if (!es3D) (tr('Longitud de corte'), '${n((i['longitud_corte'] as num? ?? 0) / 1000, 2)} m'),
      if (!es3D) (tr('Contornos cerrados'), '${i['contornos']}'),
      if (!es3D) (tr('Barrenos (círculos)'), '${i['barrenos']}'),
      if (!es3D && ((i['area_pieza'] as num?) ?? 0) > 0) (tr('Área de la pieza'), '${n((i['area_pieza'] as num) / 100, 1)} cm²'),
      if (es3D) (tr('Triángulos'), '${i['triangulos']}'),
      if (es3D) (tr('Volumen'), '${n(i['volumen_cm3'], 2)} cm³'),
      if (es3D) (tr('Área superficial'), '${n(i['area_superficial_cm2'], 1)} cm²'),
    ];
    final avisos = (i['avisos'] as List?)?.cast<String>() ?? const [];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_archivoGeo.isNotEmpty)
          Container(height: 150, width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
            child: CustomPaint(painter: _PiezaPainter(_archivoGeo))),
        ...filas.map((f) => Padding(padding: const EdgeInsets.only(bottom: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 130, child: Text(f.$1, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
            Expanded(child: Text(f.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          ]))),
        ...avisos.map((a) => Padding(padding: const EdgeInsets.only(top: 4),
          child: Text('⚠️ $a', style: const TextStyle(fontSize: 11, color: AppColors.naranja)))),
        Align(alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() { _archivoInfo = null; _archivoGeo = []; }),
            icon: const Icon(Icons.close, size: 16),
            label: Text(tr('Quitar archivo'), style: const TextStyle(fontSize: 12)))),
      ]));
  }

  bool get _eraProfesional => _esEdicion && _tipoOriginal == 'profesional';

  // Gratis: una profesional de muestra. Devuelve true si puede usarla.
  Future<bool> _permiteProfesional() async {
    if (AuthService.puede('cotizacion_profesional') || _eraProfesional) return true;
    final n = await SupabaseService.contarCotizacionesProfesionales();
    if (n < Planes.muestrasProfesionalGratis) {
      _muestraGratis = true;
      return true;
    }
    if (!mounted) return false;
    await AuthService.exigirModulo(context, 'cotizacion_profesional',
      funcion: tr('más cotizaciones profesionales (ya usaste tu muestra gratis)'));
    return false;
  }

  Future<void> _seleccionarTipo(String tipo) async {
    if (tipo == _tipo) return;
    if (tipo == 'profesional' && !await _permiteProfesional()) return;
    if (mounted) setState(() => _tipo = tipo);
  }

  @override
  void dispose() {
    for (final c in _pro.values) { c.dispose(); }
    super.dispose();
  }
  List<CotizacionItem> _items = [];
  double _descuentoPct = 0;
  double _ivaPct = 16;
  bool _aplicaIva = true;
  double _costoEnvio = 0;
  int _envioVer = 0;            // cambia para refrescar el campo Envío
  String? _envioDescripcion;    // paquetería elegida en Envíos HETNA

  Future<void> _cotizarEnvioHetna() async {
    final r = await Navigator.push<EnvioElegido>(context, MaterialPageRoute(
      builder: (_) => EnviosScreen(cpDestino: _cliente?.codigoPostal, paraCotizacion: true)));
    if (r == null || !mounted) return;
    setState(() {
      _costoEnvio = r.opcion.precio;
      _envioDescripcion = r.descripcion;
      _envioVer++;
      final linea = 'Envío: ${r.descripcion}';
      if (!_notas.contains(linea)) _notas = _notas.isEmpty ? linea : '$_notas\n$linea';
    });
  }
  String _metodoPago = '50% anticipo / 50% entrega';
  String _condicionEntrega = 'LAB — En planta HETNA';
  String _notas = '';
  bool _generando = false;
  bool _guardando = false;
  DateTime _fechaCotizacion = DateTime.now();
  bool get _esEdicion => widget.cotizacionEditar != null;
  double get _subtotal => _items.fold(0, (s, i) => s + i.subtotal);
  double get _montoDescuento => _subtotal * _descuentoPct / 100;
  double get _baseIva => _subtotal - _montoDescuento;
  double get _montoIva => _aplicaIva ? _baseIva * _ivaPct / 100 : 0;
  double get _total => _baseIva + _montoIva + _costoEnvio;
  bool get _puedeAccionar => _items.isNotEmpty && _cliente != null;
  // La primera opción usa el % de anticipo configurado por el taller
  // (Más → Costos del taller → Material y cobro); al editar una cotización
  // vieja se conserva el texto que tenía.
  final _metodosPago = ['50% anticipo / 50% entrega', 'Pago total anticipado', 'Crédito 30 días', 'Transferencia bancaria'];
  String _opcionAnticipo(double pct) {
    final a = WhatsAppService.pctTexto(pct);
    final r = WhatsAppService.pctTexto(100 - pct);
    return '$a% anticipo / $r% entrega';
  }
  Future<void> _cargarAnticipo() async {
    final pct = await WhatsAppService.anticipoPct();
    if (!mounted) return;
    final nueva = _opcionAnticipo(pct);
    setState(() {
      final vieja = _metodosPago.first;
      _metodosPago[0] = nueva;
      if (_metodoPago == vieja || (!_esEdicion && _metodoPago == '50% anticipo / 50% entrega')) _metodoPago = nueva;
      if (!_metodosPago.contains(_metodoPago)) _metodosPago.add(_metodoPago);
    });
  }
  final _condiciones = ['LAB — En planta HETNA', 'Entrega en domicilio cliente', 'Flete por cuenta del cliente'];
  final _tiempos = ['3 días', '5 días', '7 días', '10 días', '15 días', '20 días', '30 días'];
  String _tiempoEntrega = '15 días';

  // Impuesto por defecto del taller (Configuración → Idioma, moneda e impuestos)
  Future<void> _cargarImpuestoDefault() async {
    try {
      final cfg = await SupabaseService.getConfiguracion();
      final v = double.tryParse('${cfg['impuesto_pct'] ?? ''}');
      if (v != null && v >= 0 && mounted) {
        setState(() { _ivaPct = v > 0 ? v : 16; _aplicaIva = v > 0; });
      }
      // Moneda por defecto de la cotización profesional
      final m = (cfg['moneda'] ?? '').toString().toUpperCase();
      if ((m == 'USD' || m == 'MXN') && mounted) {
        final c = _ctrlPro('moneda', m);
        if (c.text.trim().isEmpty || c.text.trim() == 'MXN') c.text = m;
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    if (widget.cotizacionEditar == null) _cargarImpuestoDefault();
    _cargarAnticipo();
    if (widget.itemInicial != null) {
      try {
        final item = widget.itemInicial!;
        _items.add(CotizacionItem(
          nombreProducto: (item.trabajo ?? item.nombre ?? tr('Servicio')).toString(),
          cantidad: 1,
          precioUnitario: ((item.precio ?? item.precioUnitario ?? 0) as num).toDouble(),
          sku: null,
        ));
      } catch (_) {}
    }
    if (widget.carritoSimulador != null) {
      for (final sv in widget.carritoSimulador!) {
        try {
          final desc = sv.descripcion ?? '';
          final nombre = '${sv.emoji} ${sv.servicio}'
            '${desc.isNotEmpty ? " — $desc" : ""}';
          _items.add(CotizacionItem(
            nombreProducto: nombre,
            cantidad: 1,
            precioUnitario: sv.total,
            sku: sv.servicio,
          ));
        } catch (e) {
          print('Error simulador: $e');
        }
      }
    }
    if (_esEdicion) {
      final c = widget.cotizacionEditar!;
      _cliente = c.cliente;
      _items = List.from(c.items);
      _descuentoPct = c.descuentoPct;
      _ivaPct = c.ivaPct > 0 ? c.ivaPct : 16;
      _aplicaIva = c.ivaPct > 0;
      _costoEnvio = c.costoEnvio;
      _metodoPago = c.metodoPago ?? '50% anticipo / 50% entrega';
      _condicionEntrega = c.condicionEntrega ?? tr('LAB — En planta HETNA');
      _notas = c.notas ?? '';
      if (c.createdAt != null) _fechaCotizacion = c.createdAt!;
      _tipo = c.tipo;
      _tipoOriginal = c.tipo;
      _muestraGratis = c.datosPro['muestra'] == true;
      if (c.datosPro['archivo_info'] is Map) {
        _archivoInfo = Map<String, dynamic>.from(c.datosPro['archivo_info'] as Map);
        _archivoGeo = GeoCad.geoDeJson(c.datosPro['archivo_geo']);
      }
      c.datosPro.forEach((k, v) {
        if (k == 'tiempo_entrega') {
          if (_tiempos.contains(v)) _tiempoEntrega = v as String;
        } else if (v is String) {
          _ctrlPro(k, '').text = v;
        }
      });
      if (_items.isEmpty && c.id != null) {
        SupabaseService.getCotizacionItems(c.id!).then((items) {
          if (mounted) setState(() => _items = items);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('\$#,##0.00', 'es_MX');
    return ListView(padding: const EdgeInsets.all(14), children: [
      if (_esEdicion)
        Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.edit, size: 16, color: AppColors.ambar),
            const SizedBox(width: 8),
            Text('Editando: ${widget.cotizacionEditar!.folio ?? tr('cotización')}',
              style: const TextStyle(fontSize: 12, color: AppColors.ambar, fontWeight: FontWeight.w600)),
          ])),
      _bloque(tr('Tipo de cotización'), Icons.description_outlined, Column(children: [
        Row(children: [
          Expanded(child: _opcionTipo('sencilla', tr('Sencilla'), tr('Partidas, condiciones y total'))),
          const SizedBox(width: 8),
          Expanded(child: _opcionTipo('profesional', tr('Profesional ⭐'), tr('Formato internacional con datos técnicos y firma'))),
        ]),
        if (_tipo == 'profesional' && _muestraGratis && !AuthService.puede('cotizacion_profesional'))
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.ambarClaro, borderRadius: BorderRadius.circular(8)),
            child: Text(
              tr('Esta es tu cotización profesional de muestra (plan Gratis). Con el plan Taller haces todas las que quieras.'),
              style: TextStyle(fontSize: 11, color: AppColors.ambar, fontWeight: FontWeight.w600))),
      ])),
      _bloque(tr('Cliente'), Icons.person_outline, _cliente == null
        ? Column(children: [
            ElevatedButton.icon(onPressed: _seleccionarCliente,
              icon: const Icon(Icons.person_search), label: Text(tr('Seleccionar cliente'))),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _nuevoClienteRapido,
              icon: const Icon(Icons.person_add_outlined), label: Text(tr('Agregar nuevo cliente'))),
          ])
        : ListTile(contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: AppColors.azulClaro,
              child: Text(_cliente!.nombre[0].toUpperCase(),
                style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700))),
            title: Text(tr(_cliente!.nombreCompleto), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(tr(_cliente!.tipoCliente)),
            trailing: TextButton(onPressed: _seleccionarCliente, child: Text(tr('Cambiar'))))),
      _bloque(tr('Fecha de cotización'), Icons.calendar_today_outlined,
        GestureDetector(
          onTap: () async {
            final fecha = await showDatePicker(
              context: context,
              initialDate: _fechaCotizacion,
              firstDate: DateTime(2023),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              locale: const Locale('es', 'MX'));
            if (fecha != null) setState(() => _fechaCotizacion = fecha);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.grisBorde)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(DateFormat(enIngles ? 'MM/dd/yyyy' : 'dd/MM/yyyy').format(_fechaCotizacion),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Icon(Icons.edit_calendar, size: 16, color: AppColors.azul),
            ]))),
      ),
      _bloque(tr('Productos'), Icons.inventory_2_outlined, Column(children: [
        if (_items.isEmpty)
          Padding(padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(tr('Agrega productos a la cotización'),
              style: TextStyle(color: AppColors.textoSecundario, fontSize: 12))),
        ..._items.map((item) => _ItemRow(
          key: ValueKey('${item.productoId}_${item.nombreProducto}'),
          item: item,
          onEliminar: () => setState(() => _items.remove(item)),
          onCantidadChanged: (v) => setState(() => item.cantidad = v),
          onPrecioChanged: (v) => setState(() => item.precioUnitario = v),
          onDetalleChanged: (titulo, desc) => setState(() {
            item.nombreProducto = titulo;
            item.descripcion = desc;
          }))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ElevatedButton.icon(onPressed: _agregarProducto,
            icon: const Icon(Icons.add, size: 18), label: Text(tr('Del catálogo')))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: _productoNuevo,
            icon: const Icon(Icons.add_box_outlined, size: 18), label: Text(tr('Nuevo rápido')))),
        ]),
      ])),
      if (_tipo == 'profesional') ...[
        _bloquePro(tr('Proyecto y resumen'), Icons.folder_outlined, _camposProyecto),
        _bloquePro(tr('Alcance'), Icons.checklist_outlined, _camposAlcance),
        _bloquePro(tr('Detalle técnico'), Icons.straighten_outlined, _camposTecnicos),
        _bloque(tr('Archivo de la pieza y croquis con medidas'), Icons.architecture_outlined, Column(children: [
          Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Text(tr('Sube el DXF, SVG, STL u OBJ: la app saca las medidas, la longitud de corte, contornos, barrenos o volumen, y el PDF lleva el dibujo real de la pieza con sus cotas y los datos técnicos. Si no tienes archivo, escribe largo y ancho y se dibuja un croquis.'),
              style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
          if (_archivoInfo == null)
            Padding(padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _leyendoArchivo ? null : _subirArchivoPieza,
                  icon: _leyendoArchivo
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file_outlined, size: 18),
                  label: Text(tr('Subir archivo de la pieza (DXF, SVG, STL, OBJ)'), style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.azul,
                    side: const BorderSide(color: AppColors.azul),
                    padding: const EdgeInsets.symmetric(vertical: 12)))))
          else _resumenArchivo(),
          ..._camposCroquis.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _ctrlPro(f.$1, f.$4),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: tr(f.$2), isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))))),
        ])),
        _bloquePro(tr('Especificaciones de fabricación'), Icons.precision_manufacturing_outlined, _camposFabricacion),
        _bloquePro(tr('Calidad y cambios'), Icons.verified_outlined, _camposCondiciones),
      ],
      _bloque(tr('Condiciones'), Icons.local_shipping_outlined, Column(children: [
        Row(children: [
          Expanded(child: _campo(tr('Tiempo entrega'), child: DropdownButtonFormField<String>(
            value: _tiempos.contains(_tiempoEntrega) ? _tiempoEntrega : '15 días',
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: _tiempos.map((t) => DropdownMenuItem(value: t, child: Text(tr(t), style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _tiempoEntrega = v!)))),
          const SizedBox(width: 8),
          Expanded(child: _campo(tr('Método de pago'), child: DropdownButtonFormField<String>(
            value: _metodosPago.contains(_metodoPago) ? _metodoPago : _metodosPago.first,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: _metodosPago.map((m) => DropdownMenuItem(value: m, child: Text(tr(m), style: const TextStyle(fontSize: 11)))).toList(),
            onChanged: (v) => setState(() => _metodoPago = v!)))),
        ]),
        const SizedBox(height: 8),
        _campo(tr('Notas'), child: TextFormField(
          key: ValueKey('notas_$_envioVer'),
          initialValue: _notas,
          decoration: InputDecoration(hintText: tr('Garantías, condiciones especiales...'),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          maxLines: 2, style: const TextStyle(fontSize: 13),
          onChanged: (v) => _notas = v)),
      ])),
      _bloque(tr('Resumen financiero'), Icons.calculate_outlined, Column(children: [
        Row(children: [
          Expanded(child: _campo(tr('Descuento %'), child: TextFormField(
            initialValue: _descuentoPct > 0 ? _descuentoPct.toStringAsFixed(0) : '',
            decoration: const InputDecoration(hintText: '0', suffixText: '%',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() => _descuentoPct = double.tryParse(v) ?? 0)))),
          const SizedBox(width: 8),
          Expanded(child: _campo(tr('Envío'), child: TextFormField(
            key: ValueKey('envio_$_envioVer'),
            initialValue: _costoEnvio > 0 ? _costoEnvio.toStringAsFixed(0) : '',
            decoration: const InputDecoration(hintText: '0', prefixText: '\$',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() => _costoEnvio = double.tryParse(v) ?? 0)))),
        ]),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(
          onPressed: _cotizarEnvioHetna,
          icon: const Icon(Icons.local_shipping_outlined, size: 16, color: AppColors.naranja),
          label: Text(tr(_envioDescripcion ?? tr('Cotizar con Envíos HETNA')),
            style: const TextStyle(fontSize: 12, color: AppColors.naranja)))),
        const SizedBox(height: 4),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _aplicaIva ? AppColors.verdeClaro : AppColors.gris,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _aplicaIva ? AppColors.verde : AppColors.grisBorde)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trf('IVA {0}%', [pctTexto(_ivaPct)]), style: TextStyle(fontWeight: FontWeight.w600,
                color: _aplicaIva ? AppColors.verde : AppColors.textoSecundario)),
              Text(tr(_aplicaIva ? tr('Incluido en el total') : tr('No aplica IVA')),
                style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            ]),
            Switch(value: _aplicaIva, onChanged: (v) => setState(() => _aplicaIva = v),
              activeColor: AppColors.verde),
          ])),
        const SizedBox(height: 10),
        if (_descuentoPct > 0) _fila(trf('Descuento {0}%', [(_descuentoPct.toInt())]), '-${fmt.format(_montoDescuento)}', AppColors.verde),
        if (_aplicaIva) _fila(trf('IVA {0}%', [pctTexto(_ivaPct)]), fmt.format(_montoIva), AppColors.textoSecundario),
        if (_costoEnvio > 0) _fila(tr('Envío'), fmt.format(_costoEnvio), AppColors.textoSecundario),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('TOTAL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.azul)),
          Text(fmt.format(_total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.azul)),
        ]),
      ])),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: _puedeAccionar && !_generando ? _generarPDF : null,
        icon: _generando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.picture_as_pdf),
        label: Text(tr('Generar y ver PDF'))),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: _puedeAccionar ? _enviarWA : null,
        icon: const Icon(Icons.chat),
        label: Text(tr('Enviar cotización por WhatsApp')),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366))),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: _puedeAccionar && !_guardando ? _guardar : null,
          icon: const Icon(Icons.save_outlined),
          label: Text(tr(_esEdicion ? tr('Guardar cambios') : tr('Guardar borrador'))))),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton.icon(
          onPressed: _puedeAccionar && !_guardando ? _convertirPedido : null,
          icon: _guardando ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_circle_outline),
          label: Text(tr('→ Convertir a PEDIDO')),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde))),
      ]),
      const SizedBox(height: 24),
    ]);
  }

  Widget _bloque(String titulo, IconData icon, Widget contenido) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 16, color: AppColors.azul), const SizedBox(width: 6),
        Text(tr(titulo), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.azul))]),
      const SizedBox(height: 10), contenido]));

  Widget _opcionTipo(String valor, String titulo, String desc) {
    final sel = _tipo == valor;
    final candado = valor == 'profesional' && !AuthService.puede('cotizacion_profesional');
    return GestureDetector(
      onTap: () => _seleccionarTipo(valor),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: sel ? AppColors.azul : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde, width: sel ? 1.5 : 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(tr(titulo), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: sel ? Colors.white : AppColors.textoPrincipal))),
            if (candado && !sel) const Icon(Icons.lock_outline, size: 14, color: Colors.amber),
          ]),
          const SizedBox(height: 2),
          Text(tr(desc), style: TextStyle(fontSize: 10,
            color: sel ? Colors.white70 : AppColors.textoSecundario)),
        ])));
  }

  Widget _bloquePro(String titulo, IconData icon, List<(String, String, int, String)> campos) =>
    _bloque(titulo, icon, Column(children: campos.map((f) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _ctrlPro(f.$1, tr(f.$4)),
        maxLines: f.$3,
        minLines: 1,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: tr(f.$2), isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))))).toList()));

  Widget _campo(String label, {required Widget child}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr(label), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      const SizedBox(height: 4), child]);

  Widget _fila(String label, String valor, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(tr(label), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
      Text(tr(valor), style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    ]));

  Future<void> _seleccionarCliente() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(tr('Seleccionar cliente'),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final clientes = await SupabaseService.getClientes();
                if (!mounted) return;
                showModalBottomSheet(context: context, isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _SelectorCliente(
                    clientes: clientes,
                    onSeleccionado: (c) { setState(() => _cliente = c); },
                    onNuevo: _nuevoClienteRapido));
              },
              icon: const Icon(Icons.people_outline, color: Colors.white),
              label: Text(tr('Clientes HETNA CNC'),
                style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azul,
                padding: const EdgeInsets.symmetric(vertical: 12)))),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _seleccionarDesdeContactos();
              },
              icon: const Icon(Icons.contact_phone_outlined, color: Colors.white),
              label: Text(tr('Agenda del celular'),
                style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7c3aed),
                padding: const EdgeInsets.symmetric(vertical: 12)))),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () { Navigator.pop(context); _nuevoClienteRapido(); },
              icon: const Icon(Icons.person_add_outlined),
              label: Text(tr('Nuevo cliente rapido')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.azul,
                side: const BorderSide(color: AppColors.azul),
                padding: const EdgeInsets.symmetric(vertical: 12)))),
        ])));
  }

  Future<void> _seleccionarDesdeContactos() async {
    try {
      final permiso = await FlutterContacts.requestPermission(readonly: true);
      if (!permiso) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Permiso de contactos denegado')),
            backgroundColor: AppColors.rojo));
        return;
      }
      final contactos = await FlutterContacts.getContacts(
        withProperties: true, withPhoto: false);
      final conTelefono = contactos.where((c) => c.phones.isNotEmpty).toList();
      conTelefono.sort((a, b) => a.displayName.compareTo(b.displayName));
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ContactosPicker(
          contactos: conTelefono,
          onSeleccionado: (c, tel, waNum) async {
            try {
              final existentes = await SupabaseService.getClientes();
              final yaExiste = existentes.where((cl) =>
                cl.whatsapp == waNum || cl.telefono == tel).toList();
              if (yaExiste.isNotEmpty) {
                if (mounted) setState(() => _cliente = yaExiste.first);
              } else {
                final nuevo = await SupabaseService.crearCliente(Cliente(
                  nombre: c.displayName,
                  whatsapp: waNum.isNotEmpty ? waNum : null,
                  telefono: tel.isNotEmpty ? tel : null,
                  correo: c.emails.isNotEmpty ? c.emails.first.address : null,
                ));
                if (mounted) setState(() => _cliente = nuevo);
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'),
                  backgroundColor: AppColors.rojo));
            }
          }));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trf('Error al acceder contactos: {0}', [e])),
          backgroundColor: AppColors.rojo));
    }
  }

  Future<void> _nuevoClienteRapido() async {
    final n = TextEditingController(), wa = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) =>
        AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(
                color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              Text(tr('Nuevo cliente rápido'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: n,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: tr('Nombre *'),
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 10),
              TextField(
                controller: wa,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: tr('WhatsApp'),
                  hintText: '2461234567',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (n.text.isEmpty) return;
                    String waNum = wa.text.trim();
                    if (waNum.isNotEmpty) {
                      waNum = waNum.replaceAll(RegExp(r'[^0-9]'), '');
                      if (waNum.length == 10) waNum = '521$waNum';
                      else if (waNum.startsWith('52') && waNum.length == 12) waNum = '521${waNum.substring(2)}';
                    }
                    final cl = await SupabaseService.crearCliente(Cliente(
                      nombre: n.text.trim(),
                      whatsapp: waNum.isEmpty ? null : waNum,
                      telefono: waNum.isEmpty ? null : waNum,
                      tipoCliente: 'Cliente potencial'));
                    if (mounted) { setState(() => _cliente = cl); Navigator.pop(ctx); }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azul,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: Text(tr('Guardar cliente'),
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
            ])))));
  }

  Future<void> _agregarProducto() async {
    final productos = await SupabaseService.getProductos();
    if (!mounted) return;
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelectorProducto(
        productos: productos,
        onSeleccionado: (p) => setState(() => _items.add(CotizacionItem.fromProducto(p)))));
  }

  Future<void> _productoNuevo() async {
    final n = TextEditingController(), p = TextEditingController();
    await showModalBottomSheet(context: context, isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(tr('Producto / Servicio rápido'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(controller: n, decoration: InputDecoration(labelText: tr('Nombre *'),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
            const SizedBox(height: 8),
            TextField(controller: p, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('Precio \$'), prefixText: '\$',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () async {
              if (n.text.isEmpty) return;
              final prod = await SupabaseService.crearProducto(Producto(
                nombre: n.text.trim(), precioVenta: double.tryParse(p.text) ?? 0,
                costo: 0, unidadMedida: 'Pieza', stockDisponible: 0));
              if (mounted) { setState(() => _items.add(CotizacionItem.fromProducto(prod))); Navigator.pop(context); }
            }, child: Text(tr('Agregar a cotización'))),
          ]))));
  }

  Future<void> _generarPDF() async {
    final ingles = await PdfService.elegirIdioma(context);
    if (ingles == null) return;
    setState(() => _generando = true);
    try {
      final cfg = await SupabaseService.getConfiguracion();
      final cot = _buildCotizacion();
      final bytes = await PdfService.generarCotizacion(cotizacion: cot, empresa: cfg, ingles: ingles);
      await PdfService.verPdf(bytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trf('Error PDF: {0}', [e]))));
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _enviarWA() async {
    if (_cliente == null) return;
    final fmt = NumberFormat('\$#,##0', 'es_MX');
    final itemsTexto = _items.map((i) => trf('• {0} x{1} = {2}', [(i.nombreProducto), (i.cantidad), (fmt.format(i.subtotal))])).join('\n');
    final msg = trf('¡Hola {0}! 👋\n\nTe comparto tu cotización de *HETNA CNC*:\n\n{1}\n\nSubtotal: {2}{3}\n*TOTAL: {4}*\n\nTiempo de entrega: {5}\nMétodo de pago: {6}\n\n¿Te parece bien? 😊 — *HETNA CNC*', [(_cliente!.nombre), itemsTexto, (fmt.format(_baseIva)), (_aplicaIva ? trf('\nIVA {0}%: {1}', [pctTexto(_ivaPct), (fmt.format(_montoIva))]) : ""), (fmt.format(_total)), _tiempoEntrega, _metodoPago]);
    if (mounted) await WhatsAppService.abrirChatConSelector(context,
      numero: _cliente!.whatsappNumero, mensaje: msg);
  }

  // Plan Gratis: 5 cotizaciones nuevas al mes (igual que en hetnacnc.com)
  Future<bool> _hayCupo() async {
    if (_esEdicion || AuthService.puede('cotizaciones_ilimitadas')) return true;
    final n = await SupabaseService.contarCotizacionesDelMes();
    if (n < Planes.limiteCotizacionesGratis) return true;
    if (!mounted) return false;
    await AuthService.exigirModulo(context, 'cotizaciones_ilimitadas',
      funcion: trf('más de {0} cotizaciones al mes', [(Planes.limiteCotizacionesGratis)]));
    return false;
  }

  Future<void> _guardar() async {
    if (_cliente == null || _items.isEmpty) return;
    if (!await _hayCupo()) return;
    if (_tipo == 'profesional' && !await _permiteProfesional()) return;
    setState(() => _guardando = true);
    try {
      if (_esEdicion) {
        final cot = _buildCotizacion(id: widget.cotizacionEditar!.id, folio: widget.cotizacionEditar!.folio);
        await SupabaseService.actualizarCotizacion(cot, _items,
          incluirTipo: _tipoOriginal == 'profesional' || _tipo == 'profesional');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('✅ Cotización actualizada')), backgroundColor: AppColors.verde));
          widget.onGuardada?.call();
        }
      } else {
        final cot = _buildCotizacion(estado: 'Borrador');
        await SupabaseService.crearCotizacion(cot, _items);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('✅ Borrador guardado')), backgroundColor: AppColors.azul));
          widget.onGuardada?.call();
          setState(() { _items = []; _cliente = null; });
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _convertirPedido() async {
    if (_cliente == null || _items.isEmpty) return;
    if (!await _hayCupo()) return;
    if (_tipo == 'profesional' && !await _permiteProfesional()) return;
    setState(() => _guardando = true);
    try {
      if (_esEdicion) {
        final cotActualizada = _buildCotizacion(
          id: widget.cotizacionEditar!.id,
          folio: widget.cotizacionEditar!.folio,
          estado: 'Pedido');
        await SupabaseService.actualizarCotizacion(cotActualizada, _items,
          incluirTipo: _tipoOriginal == 'profesional' || _tipo == 'profesional');
        await SupabaseService.convertirEnPedido(cotActualizada);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('✅ ¡Pedido actualizado! Visible en Avances')),
            backgroundColor: AppColors.verde));
          widget.onGuardada?.call();
        }
      } else {
        final cot = _buildCotizacion(estado: 'Pedido');
        final cotGuardada = await SupabaseService.crearCotizacion(cot, _items);
        await SupabaseService.convertirEnPedido(cotGuardada);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('✅ ¡Pedido creado! Visible en Avances')),
            backgroundColor: AppColors.verde));
          setState(() { _items = []; _cliente = null; _descuentoPct = 0; _costoEnvio = 0; _notas = ''; });
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Cotizacion _buildCotizacion({String? id, String? folio, String? estado}) => Cotizacion(
    id: id, folio: folio, cliente: _cliente, clienteId: _cliente?.id,
    items: _items, estado: estado ?? 'Borrador',
    descuentoPct: _descuentoPct, ivaPct: _aplicaIva ? _ivaPct : 0,
    costoEnvio: _costoEnvio, metodoPago: _metodoPago,
    condicionEntrega: _condicionEntrega, notas: _notas, createdAt: _fechaCotizacion,
    tipo: _tipo, datosPro: _tipo == 'profesional' ? _datosPro() : {});
}

// ═══════════════════════════════════════════
// ITEM ROW
// ═══════════════════════════════════════════
class _ItemRow extends StatelessWidget {
  final CotizacionItem item;
  final VoidCallback onEliminar;
  final ValueChanged<int> onCantidadChanged;
  final ValueChanged<double> onPrecioChanged;
  final void Function(String titulo, String? descripcion) onDetalleChanged;
  const _ItemRow({super.key, required this.item, required this.onEliminar,
    required this.onCantidadChanged, required this.onPrecioChanged,
    required this.onDetalleChanged});

  Future<void> _editarDetalle(BuildContext context) async {
    final tituloCtrl = TextEditingController(text: item.nombreProducto);
    final descCtrl = TextEditingController(text: item.descripcion ?? '');
    final ok = await showModalBottomSheet<bool>(context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Título y descripción'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(tr('Esto se imprime en el PDF que ve el cliente para esta línea.'),
              style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            const SizedBox(height: 12),
            TextField(controller: tituloCtrl,
              decoration: InputDecoration(labelText: tr('Título *'), border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: descCtrl, maxLines: 3,
              decoration: InputDecoration(
                labelText: tr('Descripción (opcional)'),
                hintText: tr('Ej. medidas, material, detalles del trabajo...'),
                border: OutlineInputBorder())),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () {
                if (tituloCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: Text(tr('Guardar')))),
          ]))));
    if (ok == true) {
      onDetalleChanged(tituloCtrl.text.trim(),
        descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('\$#,##0.00', 'es_MX');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: GestureDetector(
            onTap: () => _editarDetalle(context),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(tr(item.nombreProducto),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                const SizedBox(width: 4),
                const Icon(Icons.edit_outlined, size: 13, color: AppColors.textoSecundario),
              ]),
              if (item.descripcion != null && item.descripcion!.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 2),
                  child: Text(tr(item.descripcion!),
                    style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]))),
          IconButton(icon: const Icon(Icons.close, size: 16, color: AppColors.rojo),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onEliminar),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(flex: 3, child: TextFormField(
            initialValue: item.precioUnitario.toStringAsFixed(0),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(prefixText: '\$', labelText: tr('Precio unit.'), isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => onPrecioChanged(double.tryParse(v) ?? item.precioUnitario))),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.remove_circle_outline, size: 22, color: AppColors.rojo),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            onPressed: item.cantidad > 1 ? () => onCantidadChanged(item.cantidad - 1) : null),
          SizedBox(width: 52, child: TextFormField(
            key: ValueKey('cant_${item.productoId}_${item.nombreProducto}_${item.cantidad}'),
            initialValue: '${item.cantidad}',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6)),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null && n > 0) onCantidadChanged(n);
            })),
          IconButton(icon: const Icon(Icons.add_circle_outline, size: 22, color: AppColors.verde),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            onPressed: () => onCantidadChanged(item.cantidad + 1)),
          const SizedBox(width: 8),
          Text(fmt.format(item.subtotal),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
        ]),
      ]));
  }
}

// ═══════════════════════════════════════════
// SELECTORES
// ═══════════════════════════════════════════
class _SelectorCliente extends StatefulWidget {
  final List<Cliente> clientes;
  final ValueChanged<Cliente> onSeleccionado;
  final VoidCallback onNuevo;
  const _SelectorCliente({required this.clientes, required this.onSeleccionado, required this.onNuevo});
  @override
  State<_SelectorCliente> createState() => _SelectorClienteState();
}

class _SelectorClienteState extends State<_SelectorCliente> {
  String _busqueda = '';
  List<Cliente> get _filtrados => _busqueda.isEmpty ? widget.clientes
    : widget.clientes.where((c) =>
        c.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
        (c.empresa?.toLowerCase().contains(_busqueda.toLowerCase()) ?? false)).toList();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          Text(tr('Seleccionar cliente'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(autofocus: true,
            decoration: InputDecoration(hintText: tr('Buscar por nombre o empresa...'),
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true, fillColor: AppColors.gris,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
            onChanged: (v) => setState(() => _busqueda = v)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () { Navigator.pop(context); widget.onNuevo(); },
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: Text(tr('Agregar nuevo cliente'))),
        ])),
        Expanded(child: ListView.builder(
          itemCount: _filtrados.length,
          itemBuilder: (_, i) {
            final c = _filtrados[i];
            return ListTile(
              leading: CircleAvatar(backgroundColor: AppColors.azulClaro,
                child: Text(c.nombre[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700))),
              title: Text(tr(c.nombreCompleto), style: const TextStyle(fontSize: 13)),
              subtitle: Text(tr(c.tipoCliente), style: const TextStyle(fontSize: 11)),
              trailing: c.whatsappNumero.isNotEmpty
                ? const Icon(Icons.chat, color: Color(0xFF25D366), size: 18) : null,
              onTap: () { widget.onSeleccionado(c); Navigator.pop(context); });
          })),
      ]));
  }
}

class _SelectorProducto extends StatefulWidget {
  final List<Producto> productos;
  final ValueChanged<Producto> onSeleccionado;
  const _SelectorProducto({required this.productos, required this.onSeleccionado});
  @override
  State<_SelectorProducto> createState() => _SelectorProductoState();
}

class _SelectorProductoState extends State<_SelectorProducto> {
  String _busqueda = '';
  String _catFiltro = 'Todas';
  List<String> get _categorias {
    final cats = widget.productos
        .map((p) => p.categoriaNombre ?? 'Sin categoría')
        .toSet().toList()..sort();
    return ['Todas', ...cats];
  }
  List<Producto> get _filtrados {
    var lista = widget.productos;
    if (_catFiltro != 'Todas') {
      lista = lista.where((p) => (p.categoriaNombre ?? 'Sin categoría') == _catFiltro).toList();
    }
    if (_busqueda.isNotEmpty) {
      lista = lista.where((p) => p.nombre.toLowerCase().contains(_busqueda.toLowerCase())).toList();
    }
    return lista;
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 6), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Seleccionar producto'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(autofocus: true,
            decoration: InputDecoration(hintText: tr('Buscar producto...'),
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true, fillColor: AppColors.gris,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
            onChanged: (v) => setState(() => _busqueda = v)),
          const SizedBox(height: 8),
          SizedBox(height: 32,
            child: ListView(scrollDirection: Axis.horizontal, children: _categorias.map((cat) {
              final activo = _catFiltro == cat;
              return GestureDetector(
                onTap: () => setState(() => _catFiltro = cat),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: activo ? AppColors.azul : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: activo ? AppColors.azul : AppColors.grisBorde)),
                  child: Text(tr(cat), style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: activo ? Colors.white : AppColors.textoSecundario))));
            }).toList())),
        ])),
        Expanded(child: _filtrados.isEmpty
          ? Center(child: Text(tr('No hay productos'), style: TextStyle(color: AppColors.textoSecundario)))
          : ListView.builder(
              itemCount: _filtrados.length,
              itemBuilder: (_, i) {
                final p = _filtrados[i];
                return ListTile(
                  title: Text(tr(p.nombre), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: Text(tr(p.categoriaNombre ?? p.unidadMedida), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                  trailing: Text('\$${p.precioVenta.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.azul, fontSize: 15)),
                  onTap: () { widget.onSeleccionado(p); Navigator.pop(context); });
              })),
      ]));
  }
}

// ═══════════════════════════════════════════
// CATÁLOGO PDFs + LISTAS
// ═══════════════════════════════════════════
class _CatalogoPDFs extends StatefulWidget {
  const _CatalogoPDFs();
  @override
  State<_CatalogoPDFs> createState() => _CatalogoPDFsState();
}

class _CatalogoPDFsState extends State<_CatalogoPDFs> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<PdfCatalogo> _pdfs = [];
  List<Map<String, dynamic>> _catalogos = [];
  List<Producto> _productos = [];
  bool _cargando = true;
  bool _subiendo = false;
  final Set<String> _seleccionados = {};
  final _fmt = NumberFormat('\$#,##0', 'es_MX');
  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _cargar();
  }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }
  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final results = await Future.wait([
        SupabaseService.getPdfs(),
        SupabaseService.getCatalogosPersonalizados(),
        SupabaseService.getProductos(),
      ]);
      if (mounted) setState(() {
        _pdfs = results[0] as List<PdfCatalogo>;
        _catalogos = results[1] as List<Map<String, dynamic>>;
        _productos = results[2] as List<Producto>;
        _cargando = false;
      });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }
  Future<void> _subirPdf() async {
    final nombreCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final cats = ['Tablas de cortar','Llaveros','Servilleteros','Acrílico','Metal','Maquinaria','General'];
    String? categoria;
    final info = await showDialog<Map<String,String>>(context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: Text(tr('Agregar PDF al catálogo'), style: TextStyle(fontSize: 15)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nombreCtrl, autofocus: true,
            decoration: InputDecoration(labelText: tr('Nombre del catálogo *'), border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: urlCtrl,
            decoration: InputDecoration(
              labelText: tr('URL del PDF *'),
              hintText: 'https://drive.google.com/...',
              border: OutlineInputBorder()),
            keyboardType: TextInputType.url),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: categoria,
            decoration: InputDecoration(labelText: tr('Categoría'), border: OutlineInputBorder()),
            hint: Text(tr('Seleccionar')),
            items: cats.map((c) => DropdownMenuItem(value: c, child: Text(tr(c), style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setS(() => categoria = v)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancelar'))),
          ElevatedButton(
            onPressed: () {
              if (nombreCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'nombre': nombreCtrl.text.trim(),
                'url': urlCtrl.text.trim(),
                'categoria': categoria ?? 'General',
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul),
            child: Text(tr('Guardar'), style: TextStyle(color: Colors.white))),
        ])));
    if (info == null) return;
    setState(() => _subiendo = true);
    try {
      await SupabaseService.subirPdf(
        nombre: info['nombre']!, url: info['url']!, categoria: info['categoria']);
      await _cargar();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('✅ PDF agregado al catálogo')), backgroundColor: AppColors.verde));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    }
    if (mounted) setState(() => _subiendo = false);
  }
  Future<void> _enviarPdfWA(PdfCatalogo pdf) async {
    final msg = Uri.encodeComponent(
      '📋 *Catálogo HETNA CNC*\n${pdf.nombre}\n\n${pdf.url}\n\n¡Mira nuestros productos y precios! 🪵✨');
    await launchUrl(Uri.parse('https://wa.me/?text=$msg'), mode: LaunchMode.externalApplication);
  }
  Future<void> _crearCatalogo() async {
    _seleccionados.clear();
    final nombreCtrl = TextEditingController();
    await showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) =>
        DraggableScrollableSheet(initialChildSize: 0.9, maxChildSize: 0.95,
          builder: (_, sc) => Container(
            decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              Container(padding: const EdgeInsets.fromLTRB(16,16,16,10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(tr('Nueva lista de productos'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
                  const SizedBox(height: 8),
                  TextField(controller: nombreCtrl,
                    decoration: InputDecoration(labelText: tr('Nombre de la lista'),
                      hintText: tr('Ej: Precios Junio 2026'), border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(trf('{0} productos seleccionados', [(_seleccionados.length)]),
                    style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                ])),
              Expanded(child: ListView.builder(
                controller: sc,
                itemCount: _productos.length,
                itemBuilder: (_, i) {
                  final p = _productos[i];
                  final sel = _seleccionados.contains(p.id);
                  return CheckboxListTile(
                    value: sel,
                    onChanged: (v) => setS(() {
                      if (v == true) _seleccionados.add(p.id!);
                      else _seleccionados.remove(p.id);
                    }),
                    title: Text(tr(p.nombre), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: Text('${_fmt.format(p.precioVenta)} • ${p.categoriaNombre ?? ""}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                    activeColor: AppColors.azul, dense: true);
                })),
              Container(padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
                child: SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _seleccionados.isEmpty ? null : () async {
                      if (nombreCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(tr('Ingresa un nombre'))));
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        await SupabaseService.crearCatalogoPersonalizado(
                          nombre: nombreCtrl.text.trim(), productoIds: _seleccionados.toList());
                        await _cargar();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(tr('✅ Lista creada')), backgroundColor: AppColors.verde));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Error: $e'), backgroundColor: AppColors.rojo));
                      }
                    },
                    icon: const Icon(Icons.save_outlined, color: Colors.white),
                    label: Text(tr(_seleccionados.isEmpty ? tr('Selecciona productos')
                      : trf('Guardar lista ({0})', [(_seleccionados.length)])),
                      style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul,
                      disabledBackgroundColor: AppColors.grisBorde,
                      padding: const EdgeInsets.symmetric(vertical: 12))))),
            ])))));
  }
  Future<void> _enviarListaWA(Map<String, dynamic> cat) async {
    final ids = List<String>.from(cat['producto_ids'] ?? []);
    final prods = _productos.where((p) => ids.contains(p.id)).toList();
    if (prods.isEmpty) return;
    final catNombre = cat['nombre'] as String? ?? '';
    final sb = StringBuffer();
    sb.writeln(trf('📋 *{0}* — HETNA CNC', [catNombre]));
    sb.writeln('━━━━━━━━━━━━━━━━━━');
    for (final p in prods) {
      sb.writeln('▪️ *${p.nombre}*  💰 ${_fmt.format(p.precioVenta)}');
    }
    sb.writeln('━━━━━━━━━━━━━━━━━━');
    sb.writeln(tr('🪵 Contáctanos para más información'));
    final msg = Uri.encodeComponent(sb.toString());
    launchUrl(Uri.parse('https://wa.me/?text=$msg'), mode: LaunchMode.externalApplication);
  }
  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      TabBar(controller: _tabCtrl,
        labelColor: AppColors.azul, unselectedLabelColor: AppColors.textoSecundario,
        indicatorColor: AppColors.azul, labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: [Tab(text: tr('PDFs')), Tab(text: tr('Listas'))]),
      Expanded(child: TabBarView(controller: _tabCtrl, children: [
        Column(children: [
          Padding(padding: const EdgeInsets.all(12),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _subiendo ? null : _subirPdf,
                icon: _subiendo
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file, color: Colors.white),
                label: Text(tr(_subiendo ? tr('Subiendo...') : tr('Subir PDF de catálogo')),
                  style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul,
                  padding: const EdgeInsets.symmetric(vertical: 11))))),
          Expanded(child: RefreshIndicator(onRefresh: _cargar,
            child: _pdfs.isEmpty
              ? ListView(children: [Container(margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [
                    Icon(Icons.picture_as_pdf, size: 48, color: AppColors.textoSecundario),
                    SizedBox(height: 8),
                    Text(tr('No hay PDFs subidos aún'), style: TextStyle(color: AppColors.textoSecundario)),
                    SizedBox(height: 4),
                    Text(tr('Sube PDFs de catálogos para enviar por WhatsApp'),
                      style: TextStyle(fontSize: 11, color: AppColors.textoSecundario), textAlign: TextAlign.center),
                  ]))])
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: _pdfs.length,
                  itemBuilder: (_, i) {
                    final pdf = _pdfs[i];
                    return Container(margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
                      child: Column(children: [
                        ListTile(dense: true,
                          leading: Container(width: 38, height: 38,
                            decoration: BoxDecoration(color: AppColors.rojoClaro, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.picture_as_pdf, color: AppColors.rojo, size: 20)),
                          title: Text(tr(pdf.nombre), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          subtitle: Text('${pdf.categoria ?? ""} ${pdf.tamanoTexto}',
                            style: const TextStyle(fontSize: 10)),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textoSecundario),
                            onPressed: () async {
                              await SupabaseService.eliminarPdf(pdf.id!, pdf.url);
                              await _cargar();
                            })),
                        Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: Row(children: [
                            Expanded(child: OutlinedButton.icon(
                              onPressed: () => launchUrl(Uri.parse(pdf.url), mode: LaunchMode.externalApplication),
                              icon: const Icon(Icons.open_in_new, size: 13),
                              label: Text(tr('Ver'), style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.azul,
                                side: const BorderSide(color: AppColors.azul),
                                padding: const EdgeInsets.symmetric(vertical: 6)))),
                            const SizedBox(width: 6),
                            Expanded(child: ElevatedButton.icon(
                              onPressed: () => _enviarPdfWA(pdf),
                              icon: const Icon(Icons.chat, size: 13, color: Colors.white),
                              label: Text(tr('Enviar WA'), style: TextStyle(fontSize: 12, color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366),
                                padding: const EdgeInsets.symmetric(vertical: 6)))),
                          ])),
                      ]));
                  }))),
        ]),
        Column(children: [
          Padding(padding: const EdgeInsets.all(12),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _productos.isEmpty ? null : _crearCatalogo,
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(tr('Crear lista de productos'), style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul,
                  padding: const EdgeInsets.symmetric(vertical: 11))))),
          Expanded(child: RefreshIndicator(onRefresh: _cargar,
            child: _catalogos.isEmpty
              ? ListView(children: [Container(margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [
                    Icon(Icons.list_alt_outlined, size: 48, color: AppColors.textoSecundario),
                    SizedBox(height: 8),
                    Text(tr('No hay listas creadas'), style: TextStyle(color: AppColors.textoSecundario)),
                    SizedBox(height: 4),
                    Text(tr('Crea listas de productos con precios y envíalas por WhatsApp'),
                      style: TextStyle(fontSize: 11, color: AppColors.textoSecundario), textAlign: TextAlign.center),
                  ]))])
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: _catalogos.length,
                  itemBuilder: (_, i) {
                    final cat = _catalogos[i];
                    final ids = List<String>.from(cat['producto_ids'] ?? []);
                    return Container(margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
                      child: Column(children: [
                        ListTile(dense: true,
                          leading: Container(width: 38, height: 38,
                            decoration: BoxDecoration(color: AppColors.azul.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.list_alt, color: AppColors.azul, size: 20)),
                          title: Text(tr(cat['nombre'] ?? ''), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          subtitle: Text(trf('{0} productos', [ids.length]), style: const TextStyle(fontSize: 10)),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textoSecundario),
                            onPressed: () async {
                              await SupabaseService.eliminarCatalogoPersonalizado(cat['id']);
                              await _cargar();
                            })),
                        Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: SizedBox(width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _enviarListaWA(cat),
                              icon: const Icon(Icons.chat, size: 13, color: Colors.white),
                              label: Text(tr('Enviar por WhatsApp'), style: TextStyle(fontSize: 12, color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366),
                                padding: const EdgeInsets.symmetric(vertical: 8))))),
                      ]));
                  }))),
        ]),
      ])),
    ]);
  }
}

// ══════════════════════════════════════════════
// Botón PDF + compartir por WA
// ══════════════════════════════════════════════
class _BtnPdfWA extends StatefulWidget {
  final Cotizacion cotizacion;
  const _BtnPdfWA({required this.cotizacion});
  @override
  State<_BtnPdfWA> createState() => _BtnPdfWAState();
}

class _BtnPdfWAState extends State<_BtnPdfWA> {
  bool _generando = false;
  Future<void> _generar() async {
    final ingles = await PdfService.elegirIdioma(context);
    if (ingles == null) return;
    setState(() => _generando = true);
    try {
      Cotizacion cot = widget.cotizacion;
      if (cot.items.isEmpty && cot.id != null) {
        final items = await SupabaseService.getCotizacionItems(cot.id!);
        cot = cot.copiaConItems(items);
      }
      final cfg = await SupabaseService.getConfiguracion();
      final bytes = await PdfService.generarCotizacion(cotizacion: cot, empresa: cfg, ingles: ingles);
      final folio = cot.folio ?? 'cotizacion';
      if (mounted) await PdfService.mostrarOpcionesEnvio(context, bytes, '$folio.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trf('Error al generar PDF: {0}', [e])), backgroundColor: AppColors.rojo));
    }
    if (mounted) setState(() => _generando = false);
  }
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _generando ? null : _generar,
      icon: _generando
        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.share_outlined, size: 14, color: Colors.white),
      label: Text(tr(_generando ? tr('Generando...') : tr('PDF / WA')),
        style: const TextStyle(fontSize: 11, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF25D366),
        padding: const EdgeInsets.symmetric(vertical: 8)));
  }
}

// ── Widget separado para picker de contactos (evita scope anidado) ──
class _ContactosPicker extends StatefulWidget {
  final List<dynamic> contactos;
  final void Function(dynamic contacto, String tel, String waNum) onSeleccionado;
  const _ContactosPicker({required this.contactos, required this.onSeleccionado});
  @override
  State<_ContactosPicker> createState() => _ContactosPickerState();
}

class _ContactosPickerState extends State<_ContactosPicker> {
  String _busqueda = '';
  @override
  Widget build(BuildContext context) {
    final filtrados = _busqueda.isEmpty
      ? widget.contactos
      : widget.contactos.where((c) =>
          c.displayName.toLowerCase().contains(_busqueda) ||
          c.phones.first.number.contains(_busqueda)).toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)))),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              const Icon(Icons.contact_phone_outlined, color: AppColors.azul, size: 20),
              const SizedBox(width: 8),
              Text(trf('Contactos ({0})', [(filtrados.length)]),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ])),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: tr('Buscar contacto...'),
                prefixIcon: const Icon(Icons.search, color: AppColors.textoSecundario),
                isDense: true,
                filled: true,
                fillColor: AppColors.gris,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none)),
              onChanged: (q) => setState(() => _busqueda = q.toLowerCase()))),
          Expanded(child: ListView.builder(
            controller: ctrl,
            itemCount: filtrados.length,
            itemBuilder: (ctx, i) {
              final c = filtrados[i];
              final tel = c.phones.first.number.replaceAll(RegExp(r'[^0-9]'), '');
              String waNum = tel;
              if (tel.length == 10) waNum = '521$tel';
              else if (tel.startsWith('52') && tel.length == 12) {
                waNum = '521${tel.substring(2)}';
              }
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.azulClaro,
                  child: Text(
                    tr(c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?'),
                    style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700))),
                title: Text(tr(c.displayName),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(tr(c.phones.first.number),
                  style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onSeleccionado(c, tel, waNum);
                });
            })),
        ])));
  }
}

// Vista previa de la pieza (trazos en mm) para la cotización profesional
class _PiezaPainter extends CustomPainter {
  final List<List<List<double>>> trazos;
  _PiezaPainter(this.trazos);
  @override
  void paint(Canvas canvas, Size size) {
    double maxX = 0, maxY = 0;
    for (final t in trazos) { for (final q in t) { if (q[0] > maxX) maxX = q[0]; if (q[1] > maxY) maxY = q[1]; } }
    if (maxX <= 0 || maxY <= 0) return;
    const m = 10.0;
    final esc = ((size.width - 2 * m) / maxX < (size.height - 2 * m) / maxY)
      ? (size.width - 2 * m) / maxX : (size.height - 2 * m) / maxY;
    final ox = (size.width - maxX * esc) / 2, oy = (size.height - maxY * esc) / 2;
    final p = Paint()..color = AppColors.azul..strokeWidth = 1..style = PaintingStyle.stroke;
    for (final t in trazos) {
      final path = Path();
      for (int i = 0; i < t.length; i++) {
        final x = ox + t[i][0] * esc, y = size.height - (oy + t[i][1] * esc);
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      canvas.drawPath(path, p);
    }
  }
  @override
  bool shouldRepaint(covariant _PiezaPainter old) => old.trazos != trazos;
}
