// ============================================
// lib/screens/catalogo_screen.dart
// ============================================
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/pdf_service.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../utils/app_colors.dart';
import 'package:intl/intl.dart';

class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // PDFs
  List<PdfCatalogo> _pdfs = [];
  bool _cargandoPdfs = true;
  bool _subiendo = false;

  // Catálogos personalizados
  List<Map<String, dynamic>> _catalogos = [];
  bool _cargandoCatalogos = true;

  // Productos (para crear catálogos)
  List<Producto> _productos = [];
  final Set<String> _seleccionados = {};
  bool _cargandoProductos = false;

  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    await Future.wait([_cargarPdfs(), _cargarCatalogos()]);
  }

  Future<void> _cargarPdfs() async {
    setState(() => _cargandoPdfs = true);
    try {
      final pdfs = await SupabaseService.getPdfs();
      if (mounted) setState(() { _pdfs = pdfs; _cargandoPdfs = false; });
    } catch (_) {
      if (mounted) setState(() => _cargandoPdfs = false);
    }
  }

  Future<void> _cargarCatalogos() async {
    setState(() => _cargandoCatalogos = true);
    try {
      final cats = await SupabaseService.getCatalogosPersonalizados();
      if (mounted) setState(() { _catalogos = cats; _cargandoCatalogos = false; });
    } catch (_) {
      if (mounted) setState(() => _cargandoCatalogos = false);
    }
  }

  Future<void> _cargarProductos() async {
    setState(() => _cargandoProductos = true);
    try {
      final prods = await SupabaseService.getProductos();
      if (mounted) setState(() { _productos = prods; _cargandoProductos = false; });
    } catch (_) {
      if (mounted) setState(() => _cargandoProductos = false);
    }
  }

  // ─── SUBIR PDF ─────────────────────────────
  Future<void> _subirPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    // Pedir nombre y categoría
    final info = await _dialogNombrePdf(file.name.replaceAll('.pdf', ''));
    if (info == null) return;

    setState(() => _subiendo = true);
    try {
      await SupabaseService.subirPdfCatalogo(
        nombre: info['nombre']!,
        bytes: Uint8List.fromList(file.bytes!),
        categoria: info['categoria'],
      );
      await _cargarPdfs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ PDF subido correctamente'),
          backgroundColor: AppColors.verde));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al subir: $e'),
          backgroundColor: AppColors.rojo));
      }
    }
    if (mounted) setState(() => _subiendo = false);
  }

  Future<Map<String, String>?> _dialogNombrePdf(String nombreInicial) async {
    final nombreCtrl = TextEditingController(text: nombreInicial);
    String? categoria;
    final categorias = ['Tablas de cortar', 'Llaveros', 'Servilleteros', 'Acrilico', 'Metal', 'Maquinaria', 'General'];

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Agregar PDF al catálogo', style: TextStyle(fontSize: 15)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre del catálogo', border: OutlineInputBorder()),
              autofocus: true),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: categoria,
              decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
              hint: const Text('Seleccionar categoría'),
              items: categorias.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setS(() => categoria = v)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (nombreCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, {'nombre': nombreCtrl.text.trim(), 'categoria': categoria ?? 'General'});
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul),
              child: const Text('Subir', style: TextStyle(color: Colors.white))),
          ])));
  }

  // ─── ELIMINAR PDF ──────────────────────────
  Future<void> _eliminarPdf(PdfCatalogo pdf) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar PDF'),
        content: Text('¿Eliminar "${pdf.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white))),
        ]));
    if (confirmar == true) {
      await SupabaseService.eliminarPdf(pdf.id!, pdf.url);
      await _cargarPdfs();
    }
  }

  // ─── ABRIR PDF ─────────────────────────────
  Future<void> _abrirPdf(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ─── ENVIAR POR WA ─────────────────────────
  void _enviarPorWA(PdfCatalogo pdf) {
    final msg = Uri.encodeComponent(
      '📋 *Catálogo HETNA CNC*\n${pdf.nombre}\n\n${pdf.url}\n\n¡Aquí puedes ver todos nuestros productos y precios! 🪵✨');
    launchUrl(Uri.parse('https://wa.me/?text=$msg'), mode: LaunchMode.externalApplication);
  }

  // ─── CREAR CATÁLOGO PERSONALIZADO ──────────
  Future<void> _mostrarCrearCatalogo() async {
    _seleccionados.clear();
    if (_productos.isEmpty) await _cargarProductos();

    final nombreCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              // Header
              Container(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Nuevo catálogo de productos',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del catálogo',
                      hintText: 'Ej: Lista de precios Junio 2026',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('${_seleccionados.length} productos seleccionados',
                      style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                    const Spacer(),
                    if (_seleccionados.isNotEmpty)
                      TextButton(
                        onPressed: () => setS(() => _seleccionados.clear()),
                        child: const Text('Limpiar', style: TextStyle(fontSize: 12))),
                  ]),
                ])),

              // Lista de productos
              Expanded(child: _cargandoProductos
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scrollCtrl,
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
                        title: Text(p.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          '${_fmt.format(p.precioVenta)} • ${p.categoriaNombre ?? ''}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                        secondary: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.azul.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.azul)),
                        activeColor: AppColors.azul,
                        dense: true);
                    })),

              // Botón guardar
              Container(padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
                child: SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _seleccionados.isEmpty ? null : () async {
                      if (nombreCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Ingresa un nombre para el catálogo')));
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        await SupabaseService.crearCatalogoPersonalizado(
                          nombre: nombreCtrl.text.trim(),
                          productoIds: _seleccionados.toList());
                        await _cargarCatalogos();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('✅ Catálogo creado'),
                          backgroundColor: AppColors.verde));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Error: $e'), backgroundColor: AppColors.rojo));
                      }
                    },
                    icon: const Icon(Icons.save_outlined, color: Colors.white),
                    label: Text(
                      _seleccionados.isEmpty ? 'Selecciona productos' : 'Guardar catálogo (${_seleccionados.length})',
                      style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.azul,
                      disabledBackgroundColor: AppColors.grisBorde,
                      padding: const EdgeInsets.symmetric(vertical: 12))))),
            ])))));
  }

  // ─── GENERAR PDF DE LISTA ──────────────────
  Future<void> _generarPdfLista(Map<String, dynamic> cat) async {
    final productoIds = List<String>.from(cat['producto_ids'] ?? []);
    if (productoIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta lista no tiene productos')));
      return;
    }
    if (_productos.isEmpty) await _cargarProductos();
    final prods = _productos.where((p) => productoIds.contains(p.id)).toList();
    if (prods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron los productos')));
      return;
    }
    setState(() => _subiendo = true);
    try {
      final cfg = await SupabaseService.getConfiguracion();
      final bytes = await PdfService.generarListadoProductos(
        nombreLista: cat['nombre'] as String? ?? 'Lista HETNA CNC',
        productos: prods,
        empresa: cfg);
      final nombre = (cat['nombre'] as String? ?? 'catalogo')
          .replaceAll(' ', '_').toLowerCase();
      await PdfService.compartirPdf(bytes, '$nombre.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e'),
          backgroundColor: AppColors.rojo));
    }
    if (mounted) setState(() => _subiendo = false);
  }

  // ─── ENVIAR CATÁLOGO POR WA ────────────────
  Future<void> _enviarCatalogoWA(Map<String, dynamic> cat) async {
    final productoIds = List<String>.from(cat['producto_ids'] ?? []);
    if (productoIds.isEmpty) return;

    if (_productos.isEmpty) await _cargarProductos();

    final prods = _productos.where((p) => productoIds.contains(p.id)).toList();
    if (prods.isEmpty) return;

    final sb = StringBuffer();
    sb.writeln('📋 *${cat['nombre']}*');
    sb.writeln('━━━━━━━━━━━━━━━━━━');
    for (final p in prods) {
      sb.writeln('▪️ *${p.nombre}*');
      sb.writeln('   💰 ${_fmt.format(p.precioVenta)}');
      if (p.descripcion != null && p.descripcion!.isNotEmpty) {
        sb.writeln('   ${p.descripcion}');
      }
      sb.writeln();
    }
    sb.writeln('━━━━━━━━━━━━━━━━━━');
    sb.writeln('🪵 *HETNA CNC* — Productos personalizados en madera, MDF y acrílico');
    sb.writeln('📞 Contáctanos para más información');

    final msg = Uri.encodeComponent(sb.toString());
    launchUrl(Uri.parse('https://wa.me/?text=$msg'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textoPrincipal,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.picture_as_pdf_outlined, size: 18), text: 'PDFs'),
            Tab(icon: Icon(Icons.list_alt_outlined, size: 18), text: 'Listas'),
          ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarTodo),
        ]),
      body: TabBarView(
        controller: _tabController,
        children: [_tabPdfs(), _tabListas()]),
    );
  }

  // ─── TAB PDFs ──────────────────────────────
  Widget _tabPdfs() {
    return Column(children: [
      // Botón subir
      Padding(padding: const EdgeInsets.all(14),
        child: SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _subiendo ? null : _subirPdf,
            icon: _subiendo
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.upload_file, color: Colors.white),
            label: Text(_subiendo ? 'Subiendo...' : 'Subir PDF de catálogo',
              style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.azul,
              padding: const EdgeInsets.symmetric(vertical: 12))))),

      // Lista PDFs
      Expanded(child: _cargandoPdfs
        ? const Center(child: CircularProgressIndicator())
        : _pdfs.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 56, color: AppColors.grisBorde),
              const SizedBox(height: 12),
              const Text('No hay catálogos subidos aún',
                style: TextStyle(fontSize: 14, color: AppColors.textoSecundario)),
              const SizedBox(height: 6),
              const Text('Sube PDFs con tus productos y precios\npara enviarlos por WhatsApp a tus clientes',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            ]))
          : RefreshIndicator(
              onRefresh: _cargarPdfs,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                itemCount: _pdfs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _tarjetaPdf(_pdfs[i])))),
    ]);
  }

  Widget _tarjetaPdf(PdfCatalogo pdf) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.rojo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.picture_as_pdf, color: AppColors.rojo, size: 24)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pdf.nombre,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Row(children: [
              if (pdf.categoria != null)
                Container(
                  margin: const EdgeInsets.only(right: 6, top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.azul.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(pdf.categoria!,
                    style: const TextStyle(fontSize: 10, color: AppColors.azul, fontWeight: FontWeight.w500))),
              if (pdf.tamanoTexto.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 3),
                  child: Text(pdf.tamanoTexto,
                    style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario))),
            ]),
          ])),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textoSecundario),
            onPressed: () => _eliminarPdf(pdf),
            padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _abrirPdf(pdf.url),
            icon: const Icon(Icons.open_in_new, size: 14),
            label: const Text('Ver PDF', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.azul,
              side: const BorderSide(color: AppColors.azul),
              padding: const EdgeInsets.symmetric(vertical: 6)))),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _enviarPorWA(pdf),
            icon: const Icon(Icons.chat, size: 14, color: Colors.white),
            label: const Text('Enviar WA', style: TextStyle(fontSize: 12, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(vertical: 6)))),
        ]),
      ]));
  }

  // ─── TAB LISTAS ────────────────────────────
  Widget _tabListas() {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(14),
        child: SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _mostrarCrearCatalogo,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Crear lista de productos', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.azul,
              padding: const EdgeInsets.symmetric(vertical: 12))))),

      Expanded(child: _cargandoCatalogos
        ? const Center(child: CircularProgressIndicator())
        : _catalogos.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.list_alt_outlined, size: 56, color: AppColors.grisBorde),
              const SizedBox(height: 12),
              const Text('No hay listas creadas aún',
                style: TextStyle(fontSize: 14, color: AppColors.textoSecundario)),
              const SizedBox(height: 6),
              const Text('Crea listas personalizadas de productos\ny envíalas por WhatsApp con precios',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            ]))
          : RefreshIndicator(
              onRefresh: _cargarCatalogos,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                itemCount: _catalogos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _tarjetaCatalogo(_catalogos[i])))),
    ]);
  }

  Widget _tarjetaCatalogo(Map<String, dynamic> cat) {
    final ids = List<String>.from(cat['producto_ids'] ?? []);
    final fecha = cat['created_at'] != null
      ? DateFormat('dd/MM/yyyy').format(DateTime.parse(cat['created_at']))
      : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.azul.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.list_alt, color: AppColors.azul, size: 24)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cat['nombre'] ?? 'Sin nombre',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${ids.length} producto${ids.length != 1 ? "s" : ""} • $fecha',
              style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          ])),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textoSecundario),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Eliminar lista'),
                  content: Text('¿Eliminar "${cat['nombre']}"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
                      child: const Text('Eliminar', style: TextStyle(color: Colors.white))),
                  ]));
              if (ok == true) {
                await SupabaseService.eliminarCatalogoPersonalizado(cat['id']);
                await _cargarCatalogos();
              }
            },
            padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]),
        if (cat['descripcion'] != null && (cat['descripcion'] as String).isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 6),
            child: Text(cat['descripcion'],
              style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _subiendo ? null : () => _generarPdfLista(cat),
            icon: _subiendo
              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined, size: 14),
            label: const Text('Generar PDF', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.rojo,
              side: const BorderSide(color: AppColors.rojo),
              padding: const EdgeInsets.symmetric(vertical: 8)))),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _enviarCatalogoWA(cat),
            icon: const Icon(Icons.chat, size: 14, color: Colors.white),
            label: const Text('Enviar WA', style: TextStyle(fontSize: 11, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(vertical: 8)))),
        ]),
      ]));
  }
}
