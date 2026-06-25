// lib/screens/reportes_screen.dart
// HETNA CNC — Exportar reportes a Excel
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});
  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  // Filtros
  DateTime _desde = DateTime.now().subtract(const Duration(days: 30));
  DateTime _hasta = DateTime.now();
  String _estadoCot = 'Todos';
  String _estadoPed = 'Todos';

  bool _generando = false;
  String? _ultimoArchivo;

  final _fmtFecha = DateFormat('dd/MM/yyyy', 'es_MX');
  final _fmtNum = NumberFormat('#,##0.00', 'es_MX');

  final _estadosCot = ['Todos', 'Borrador', 'Enviada', 'Aprobada', 'Pedido', 'Vencida', 'Rechazada'];
  final _estadosPed = ['Todos', 'Pedido', 'Pago', 'Produccion', 'Pruebas', 'Entrega', 'Entregado'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Exportar reportes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul))),
      body: ListView(padding: const EdgeInsets.all(14), children: [

        // ── Banner ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.azul, Color(0xFF2d5a8e)]),
            borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Text('📊', style: TextStyle(fontSize: 32)),
            SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Reportes Excel', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              Text('Exporta cotizaciones, pedidos y gastos\nen formato .xlsx para analizar en Excel.',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
            ])),
          ])),

        const SizedBox(height: 16),

        // ── Filtro de fechas ──
        _seccion('RANGO DE FECHAS'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Column(children: [
            Row(children: [
              Expanded(child: _selectorFecha('Desde', _desde, (d) => setState(() => _desde = d))),
              const SizedBox(width: 10),
              Expanded(child: _selectorFecha('Hasta', _hasta, (d) => setState(() => _hasta = d))),
            ]),
            const SizedBox(height: 10),
            // Accesos rápidos
            SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: Row(children: [
                _btnRapido('Este mes', () {
                  final hoy = DateTime.now();
                  setState(() {
                    _desde = DateTime(hoy.year, hoy.month, 1);
                    _hasta = DateTime(hoy.year, hoy.month + 1, 0);
                  });
                }),
                _btnRapido('Mes anterior', () {
                  final hoy = DateTime.now();
                  setState(() {
                    _desde = DateTime(hoy.year, hoy.month - 1, 1);
                    _hasta = DateTime(hoy.year, hoy.month, 0);
                  });
                }),
                _btnRapido('Últimos 3 meses', () {
                  setState(() {
                    _desde = DateTime.now().subtract(const Duration(days: 90));
                    _hasta = DateTime.now();
                  });
                }),
                _btnRapido('Este año', () {
                  setState(() {
                    _desde = DateTime(DateTime.now().year, 1, 1);
                    _hasta = DateTime(DateTime.now().year, 12, 31);
                  });
                }),
              ])),
          ])),

        const SizedBox(height: 16),

        // ── COTIZACIONES ──
        _seccion('COTIZACIONES'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Incluye: folio, cliente, productos, totales, estado, fecha.',
              style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            const SizedBox(height: 10),
            const Text('Filtrar por estado:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6,
              children: _estadosCot.map((e) => GestureDetector(
                onTap: () => setState(() => _estadoCot = e),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _estadoCot == e ? AppColors.azul : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _estadoCot == e ? AppColors.azul : AppColors.grisBorde)),
                  child: Text(e, style: TextStyle(
                    fontSize: 11,
                    color: _estadoCot == e ? Colors.white : AppColors.textoSecundario,
                    fontWeight: _estadoCot == e ? FontWeight.w600 : FontWeight.normal))))).toList()),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generando ? null : () => _exportarCotizaciones(),
                icon: _generando
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.table_chart_outlined, color: Colors.white, size: 18),
                label: const Text('Exportar cotizaciones .xlsx',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.azul,
                  padding: const EdgeInsets.symmetric(vertical: 11)))),
          ])),

        const SizedBox(height: 12),

        // ── PEDIDOS / NOTAS DE COMPRA ──
        _seccion('PEDIDOS Y NOTAS DE COMPRA'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Incluye: folio, cliente, total, etapa, fechas de creación y entrega.',
              style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            const SizedBox(height: 10),
            const Text('Filtrar por etapa:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6,
              children: _estadosPed.map((e) => GestureDetector(
                onTap: () => setState(() => _estadoPed = e),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _estadoPed == e ? const Color(0xFF7c3aed) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _estadoPed == e ? const Color(0xFF7c3aed) : AppColors.grisBorde)),
                  child: Text(e, style: TextStyle(
                    fontSize: 11,
                    color: _estadoPed == e ? Colors.white : AppColors.textoSecundario,
                    fontWeight: _estadoPed == e ? FontWeight.w600 : FontWeight.normal))))).toList()),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generando ? null : () => _exportarPedidos(),
                icon: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 18),
                label: const Text('Exportar pedidos .xlsx',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7c3aed),
                  padding: const EdgeInsets.symmetric(vertical: 11)))),
          ])),

        const SizedBox(height: 12),

        // ── GASTOS ──
        _seccion('GASTOS Y COMPRAS'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grisBorde, width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Incluye: concepto, categoría, tipo (directo/indirecto), monto, fecha.',
              style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generando ? null : () => _exportarGastos(),
                icon: const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 18),
                label: const Text('Exportar gastos .xlsx',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rojo,
                  padding: const EdgeInsets.symmetric(vertical: 11)))),
          ])),

        const SizedBox(height: 12),

        // ── REPORTE COMPLETO ──
        _seccion('REPORTE COMPLETO'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.verde.withOpacity(0.3), width: 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.auto_awesome, color: AppColors.verde, size: 16),
              SizedBox(width: 6),
              Text('Todo en un solo archivo', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.verde)),
            ]),
            const SizedBox(height: 4),
            const Text('Un .xlsx con 3 pestañas: Cotizaciones, Pedidos y Gastos.',
              style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generando ? null : () => _exportarCompleto(),
                icon: _generando
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_outlined, color: Colors.white, size: 18),
                label: const Text('Exportar reporte completo',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verde,
                  padding: const EdgeInsets.symmetric(vertical: 12)))),
          ])),

        const SizedBox(height: 30),
      ]));
  }

  // ══════════════════════════════════════════
  // EXPORTAR COTIZACIONES
  // ══════════════════════════════════════════
  Future<void> _exportarCotizaciones() async {
    setState(() => _generando = true);
    try {
      final cotizaciones = await SupabaseService.getCotizaciones();
      final filtradas = cotizaciones.where((c) {
        final dentroFecha = c.createdAt != null &&
          c.createdAt!.isAfter(_desde.subtract(const Duration(days: 1))) &&
          c.createdAt!.isBefore(_hasta.add(const Duration(days: 1)));
        final dentroEstado = _estadoCot == 'Todos' || c.estado == _estadoCot;
        return dentroFecha && dentroEstado;
      }).toList();

      final excel = Excel.createExcel();
      final sheet = excel['Cotizaciones'];
      excel.delete('Sheet1');

      // Headers
      final headers = [
        'Folio', 'Fecha', 'Cliente', 'Empresa', 'Estado',
        'Subtotal', 'Descuento %', 'IVA %', 'Total',
        'Método de pago', 'Condición entrega', 'Vigencia (días)', 'Notas'
      ];
      _escribirEncabezado(sheet, headers);

      // Datos
      for (int i = 0; i < filtradas.length; i++) {
        final c = filtradas[i];
        final row = i + 1;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(c.folio ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          TextCellValue(c.createdAt != null ? _fmtFecha.format(c.createdAt!) : '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          TextCellValue(c.cliente?.nombre ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          TextCellValue(c.cliente?.empresa ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          TextCellValue(c.estado);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          DoubleCellValue(c.subtotal);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value =
          DoubleCellValue(c.descuentoPct);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value =
          DoubleCellValue(c.ivaPct);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value =
          DoubleCellValue(c.total);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value =
          TextCellValue(c.metodoPago ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value =
          TextCellValue(c.condicionEntrega ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row)).value =
          IntCellValue(c.vigenciaDias);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row)).value =
          TextCellValue(c.notas ?? '');
      }

      await _guardarYCompartir(excel, 'Cotizaciones_HETNA_${_fmtFecha.format(_desde)}_${_fmtFecha.format(_hasta)}');
    } catch (e) {
      _mostrarError('Error al exportar cotizaciones: $e');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  // ══════════════════════════════════════════
  // EXPORTAR PEDIDOS
  // ══════════════════════════════════════════
  Future<void> _exportarPedidos() async {
    setState(() => _generando = true);
    try {
      final pedidos = await SupabaseService.getPedidos();
      final filtrados = pedidos.where((p) {
        final dentroFecha = p.createdAt != null &&
          p.createdAt!.isAfter(_desde.subtract(const Duration(days: 1))) &&
          p.createdAt!.isBefore(_hasta.add(const Duration(days: 1)));
        final dentroEstado = _estadoPed == 'Todos' || p.estado == _estadoPed;
        return dentroFecha && dentroEstado;
      }).toList();

      final excel = Excel.createExcel();
      final sheet = excel['Pedidos'];
      excel.delete('Sheet1');

      final headers = [
        'Folio', 'Fecha creación', 'Cliente', 'Empresa',
        'Estado', 'Total', 'Fecha entrega estimada', 'Fecha entregado',
        'Cotización origen', 'Notas internas'
      ];
      _escribirEncabezado(sheet, headers);

      for (int i = 0; i < filtrados.length; i++) {
        final p = filtrados[i];
        final row = i + 1;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(p.folio);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          TextCellValue(p.createdAt != null ? _fmtFecha.format(p.createdAt!) : '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          TextCellValue(p.cliente?.nombre ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          TextCellValue(p.cliente?.empresa ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          TextCellValue(p.estado);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          DoubleCellValue(p.total ?? 0);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value =
          TextCellValue(p.fechaEntregaEstimada != null ? _fmtFecha.format(p.fechaEntregaEstimada!) : '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value =
          TextCellValue(p.fechaEntregado != null ? _fmtFecha.format(p.fechaEntregado!) : '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value =
          TextCellValue(p.cotizacionId ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value =
          TextCellValue(p.notasInternas ?? '');
      }

      await _guardarYCompartir(excel, 'Pedidos_HETNA_${_fmtFecha.format(_desde)}_${_fmtFecha.format(_hasta)}');
    } catch (e) {
      _mostrarError('Error al exportar pedidos: $e');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  // ══════════════════════════════════════════
  // EXPORTAR GASTOS
  // ══════════════════════════════════════════
  Future<void> _exportarGastos() async {
    setState(() => _generando = true);
    try {
      final gastos = await SupabaseService.getGastos();
      final filtrados = gastos.where((g) {
        final fecha = g['fecha'] != null ? DateTime.tryParse(g['fecha']) : null;
        if (fecha == null) return false;
        return fecha.isAfter(_desde.subtract(const Duration(days: 1))) &&
          fecha.isBefore(_hasta.add(const Duration(days: 1)));
      }).toList();

      final excel = Excel.createExcel();
      final sheet = excel['Gastos'];
      excel.delete('Sheet1');

      final headers = ['Fecha', 'Concepto', 'Categoría', 'Tipo', 'Monto', 'Notas'];
      _escribirEncabezado(sheet, headers);

      for (int i = 0; i < filtrados.length; i++) {
        final g = filtrados[i];
        final row = i + 1;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(g['fecha'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          TextCellValue(g['concepto'] ?? g['descripcion'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          TextCellValue(g['categoria'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          TextCellValue(g['tipo'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          DoubleCellValue((g['monto'] as num?)?.toDouble() ?? 0);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          TextCellValue(g['notas'] ?? '');
      }

      await _guardarYCompartir(excel, 'Gastos_HETNA_${_fmtFecha.format(_desde)}_${_fmtFecha.format(_hasta)}');
    } catch (e) {
      _mostrarError('Error al exportar gastos: $e');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  // ══════════════════════════════════════════
  // EXPORTAR COMPLETO (3 pestañas)
  // ══════════════════════════════════════════
  Future<void> _exportarCompleto() async {
    setState(() => _generando = true);
    try {
      final results = await Future.wait([
        SupabaseService.getCotizaciones(),
        SupabaseService.getPedidos(),
        SupabaseService.getGastos(),
      ]);

      final cotizaciones = (results[0] as List<Cotizacion>).where((c) =>
        c.createdAt != null &&
        c.createdAt!.isAfter(_desde.subtract(const Duration(days: 1))) &&
        c.createdAt!.isBefore(_hasta.add(const Duration(days: 1)))).toList();

      final pedidos = (results[1] as List<Pedido>).where((p) =>
        p.createdAt != null &&
        p.createdAt!.isAfter(_desde.subtract(const Duration(days: 1))) &&
        p.createdAt!.isBefore(_hasta.add(const Duration(days: 1)))).toList();

      final gastos = (results[2] as List<Map<String, dynamic>>).where((g) {
        final fecha = g['fecha'] != null ? DateTime.tryParse(g['fecha']) : null;
        return fecha != null &&
          fecha.isAfter(_desde.subtract(const Duration(days: 1))) &&
          fecha.isBefore(_hasta.add(const Duration(days: 1)));
      }).toList();

      final excel = Excel.createExcel();
      excel.delete('Sheet1');

      // ── Hoja 1: Resumen ──
      final resumen = excel['Resumen'];
      _escribirEncabezado(resumen, ['Concepto', 'Valor']);
      final totalVentas = pedidos.where((p) => p.estado == 'Entregado')
        .fold(0.0, (s, p) => s + (p.total ?? 0));
      final totalGastos = gastos.fold(0.0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0));
      resumen.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue('Período');
      resumen.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value =
        TextCellValue('${_fmtFecha.format(_desde)} al ${_fmtFecha.format(_hasta)}');
      resumen.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = TextCellValue('Total cotizaciones');
      resumen.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value = IntCellValue(cotizaciones.length);
      resumen.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value = TextCellValue('Total pedidos');
      resumen.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value = IntCellValue(pedidos.length);
      resumen.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4)).value = TextCellValue('Ventas (entregados)');
      resumen.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4)).value = DoubleCellValue(totalVentas);
      resumen.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5)).value = TextCellValue('Total gastos');
      resumen.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 5)).value = DoubleCellValue(totalGastos);
      resumen.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 6)).value = TextCellValue('Utilidad neta');
      resumen.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 6)).value = DoubleCellValue(totalVentas - totalGastos);

      // ── Hoja 2: Cotizaciones ──
      final sheetCot = excel['Cotizaciones'];
      _escribirEncabezado(sheetCot, ['Folio', 'Fecha', 'Cliente', 'Empresa', 'Estado', 'Subtotal', 'Desc%', 'IVA%', 'Total', 'Método pago']);
      for (int i = 0; i < cotizaciones.length; i++) {
        final c = cotizaciones[i];
        final r = i + 1;
        sheetCot.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).value = TextCellValue(c.folio ?? '');
        sheetCot.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).value = TextCellValue(c.createdAt != null ? _fmtFecha.format(c.createdAt!) : '');
        sheetCot.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r)).value = TextCellValue(c.cliente?.nombre ?? '');
        sheetCot.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r)).value = TextCellValue(c.cliente?.empresa ?? '');
        sheetCot.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r)).value = TextCellValue(c.estado);
        sheetCot.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r)).value = DoubleCellValue(c.subtotal);
        sheetCot.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: r)).value = DoubleCellValue(c.descuentoPct);
        sheetCot.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: r)).value = DoubleCellValue(c.ivaPct);
        sheetCot.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: r)).value = DoubleCellValue(c.total);
        sheetCot.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: r)).value = TextCellValue(c.metodoPago ?? '');
      }

      // ── Hoja 3: Pedidos ──
      final sheetPed = excel['Pedidos'];
      _escribirEncabezado(sheetPed, ['Folio', 'Fecha', 'Cliente', 'Estado', 'Total', 'Fecha entrega', 'Entregado']);
      for (int i = 0; i < pedidos.length; i++) {
        final p = pedidos[i];
        final r = i + 1;
        sheetPed.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).value = TextCellValue(p.folio);
        sheetPed.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).value = TextCellValue(p.createdAt != null ? _fmtFecha.format(p.createdAt!) : '');
        sheetPed.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r)).value = TextCellValue(p.cliente?.nombre ?? '');
        sheetPed.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r)).value = TextCellValue(p.estado);
        sheetPed.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r)).value = DoubleCellValue(p.total ?? 0);
        sheetPed.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r)).value = TextCellValue(p.fechaEntregaEstimada != null ? _fmtFecha.format(p.fechaEntregaEstimada!) : '');
        sheetPed.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: r)).value = TextCellValue(p.fechaEntregado != null ? _fmtFecha.format(p.fechaEntregado!) : '');
      }

      // ── Hoja 4: Gastos ──
      final sheetGas = excel['Gastos'];
      _escribirEncabezado(sheetGas, ['Fecha', 'Concepto', 'Categoría', 'Tipo', 'Monto']);
      for (int i = 0; i < gastos.length; i++) {
        final g = gastos[i];
        final r = i + 1;
        sheetGas.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).value = TextCellValue(g['fecha'] ?? '');
        sheetGas.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).value = TextCellValue(g['concepto'] ?? g['descripcion'] ?? '');
        sheetGas.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r)).value = TextCellValue(g['categoria'] ?? '');
        sheetGas.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r)).value = TextCellValue(g['tipo'] ?? '');
        sheetGas.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r)).value = DoubleCellValue((g['monto'] as num?)?.toDouble() ?? 0);
      }

      await _guardarYCompartir(excel, 'ReporteCompleto_HETNA_${_fmtFecha.format(_desde)}_${_fmtFecha.format(_hasta)}');
    } catch (e) {
      _mostrarError('Error al generar reporte: $e');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  // ══════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════
  void _escribirEncabezado(Sheet sheet, List<String> headers) {
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1a3a5c'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
    }
  }

  Future<void> _guardarYCompartir(Excel excel, String nombre) async {
    final bytes = excel.save();
    if (bytes == null) throw Exception('Error al generar el archivo');
    final dir = await getTemporaryDirectory();
    final archivo = File('${dir.path}/$nombre.xlsx');
    await archivo.writeAsBytes(bytes);
    if (mounted) {
      await Share.shareXFiles(
        [XFile(archivo.path)],
        text: 'Reporte HETNA CNC — $nombre',
        subject: 'Reporte HETNA CNC');
    }
  }

  void _mostrarError(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.rojo));
  }

  Widget _selectorFecha(String label, DateTime fecha, void Function(DateTime) onChanged) =>
    GestureDetector(
      onTap: () async {
        final sel = await showDatePicker(
          context: context,
          initialDate: fecha,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030));
        if (sel != null) onChanged(sel);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.grisBorde),
          borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.azul),
            const SizedBox(width: 6),
            Text(_fmtFecha.format(fecha),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.azul)),
          ]),
        ])));

  Widget _btnRapido(String label, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.azulClaro,
          borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: const TextStyle(
          fontSize: 11, color: AppColors.azul, fontWeight: FontWeight.w600))));

  Widget _seccion(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(titulo, style: const TextStyle(
      fontSize: 10, fontWeight: FontWeight.w700,
      color: AppColors.textoSecundario, letterSpacing: 1.5)));
}
