// lib/screens/reportes_screen.dart
// HETNA CNC — Reportes Excel + Fiscal SAT
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});
  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Reportes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.azul,
          unselectedLabelColor: AppColors.textoSecundario,
          indicatorColor: AppColors.azul,
          tabs: const [
            Tab(icon: Icon(Icons.table_chart_outlined, size: 16), text: 'Excel'),
            Tab(icon: Icon(Icons.receipt_outlined, size: 16), text: 'Fiscal SAT'),
          ])),
      body: TabBarView(controller: _tabCtrl, children: [
        const _TabExcel(),
        const _TabFiscal(),
      ]));
  }
}

// ══════════════════════════════════════════════════════
// TAB EXCEL
// ══════════════════════════════════════════════════════
class _TabExcel extends StatefulWidget {
  const _TabExcel();
  @override
  State<_TabExcel> createState() => _TabExcelState();
}

class _TabExcelState extends State<_TabExcel> {
  DateTime _desde = DateTime.now().subtract(const Duration(days: 30));
  DateTime _hasta = DateTime.now();
  String _estadoCot = 'Todos';
  String _estadoPed = 'Todos';
  bool _generando = false;

  final _fmtFecha = DateFormat('dd/MM/yyyy', 'es_MX');
  final _estadosCot = ['Todos','Borrador','Enviada','Aprobada','Pedido','Vencida','Rechazada'];
  final _estadosPed = ['Todos','Pedido','Pago','Produccion','Pruebas','Entrega','Entregado'];

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(14), children: [
      // Banner
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
            Text('Exporta cotizaciones, pedidos y gastos en .xlsx',
              style: TextStyle(fontSize: 12, color: Colors.white70)),
          ])),
        ])),

      const SizedBox(height: 16),

      // Filtro fechas
      _seccion('RANGO DE FECHAS'),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(children: [
          Row(children: [
            Expanded(child: _selectorFecha('Desde', _desde,
              (d) => setState(() => _desde = d))),
            const SizedBox(width: 10),
            Expanded(child: _selectorFecha('Hasta', _hasta,
              (d) => setState(() => _hasta = d))),
          ]),
          const SizedBox(height: 10),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: [
              _btnRapido('Este mes', () => setState(() {
                final h = DateTime.now();
                _desde = DateTime(h.year, h.month, 1);
                _hasta = DateTime(h.year, h.month + 1, 0);
              })),
              _btnRapido('Mes anterior', () => setState(() {
                final h = DateTime.now();
                _desde = DateTime(h.year, h.month - 1, 1);
                _hasta = DateTime(h.year, h.month, 0);
              })),
              _btnRapido('3 meses', () => setState(() {
                _desde = DateTime.now().subtract(const Duration(days: 90));
                _hasta = DateTime.now();
              })),
              _btnRapido('Este año', () => setState(() {
                _desde = DateTime(DateTime.now().year, 1, 1);
                _hasta = DateTime(DateTime.now().year, 12, 31);
              })),
            ])),
        ])),

      const SizedBox(height: 16),

      // Cotizaciones
      _seccion('COTIZACIONES'),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Folio, cliente, productos, totales, estado, fecha.',
            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const SizedBox(height: 10),
          const Text('Filtrar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6,
            children: _estadosCot.map((e) => GestureDetector(
              onTap: () => setState(() => _estadoCot = e),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _estadoCot == e ? AppColors.azul : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _estadoCot == e ? AppColors.azul : AppColors.grisBorde)),
                child: Text(e, style: TextStyle(
                  fontSize: 11,
                  color: _estadoCot == e ? Colors.white : AppColors.textoSecundario,
                  fontWeight: _estadoCot == e ? FontWeight.w600 : FontWeight.normal))))).toList()),
          const SizedBox(height: 14),
          _btnExportar('Exportar cotizaciones .xlsx', AppColors.azul,
            _generando ? null : _exportarCotizaciones),
        ])),

      const SizedBox(height: 12),

      // Pedidos
      _seccion('PEDIDOS'),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Folio, cliente, total, etapa, fechas.',
            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6,
            children: _estadosPed.map((e) => GestureDetector(
              onTap: () => setState(() => _estadoPed = e),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _estadoPed == e ? const Color(0xFF7c3aed) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _estadoPed == e ? const Color(0xFF7c3aed) : AppColors.grisBorde)),
                child: Text(e, style: TextStyle(
                  fontSize: 11,
                  color: _estadoPed == e ? Colors.white : AppColors.textoSecundario))))).toList()),
          const SizedBox(height: 14),
          _btnExportar('Exportar pedidos .xlsx', const Color(0xFF7c3aed),
            _generando ? null : _exportarPedidos),
        ])),

      const SizedBox(height: 12),

      // Gastos
      _seccion('GASTOS'),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Concepto, categoría, tipo, monto, fecha.',
            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const SizedBox(height: 14),
          _btnExportar('Exportar gastos .xlsx', AppColors.rojo,
            _generando ? null : _exportarGastos),
        ])),

      const SizedBox(height: 12),

      // Reporte completo
      _seccion('REPORTE COMPLETO'),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.verde.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.auto_awesome, color: AppColors.verde, size: 16),
            SizedBox(width: 6),
            Text('4 pestañas: Resumen + Cotizaciones + Pedidos + Gastos',
              style: TextStyle(fontSize: 12, color: AppColors.verde, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 14),
          _btnExportar('Exportar reporte completo', AppColors.verde,
            _generando ? null : _exportarCompleto),
        ])),

      const SizedBox(height: 30),
    ]);
  }

  // ── EXPORTAR ────────────────────────────────────────
  Future<void> _exportarCotizaciones() async {
    setState(() => _generando = true);
    try {
      final cotizaciones = await SupabaseService.getCotizaciones();
      final filtradas = cotizaciones.where((c) {
        final ok = c.createdAt != null &&
          c.createdAt!.isAfter(_desde.subtract(const Duration(days: 1))) &&
          c.createdAt!.isBefore(_hasta.add(const Duration(days: 1)));
        return ok && (_estadoCot == 'Todos' || c.estado == _estadoCot);
      }).toList();

      final excel = Excel.createExcel();
      final sheet = excel['Cotizaciones'];
      excel.delete('Sheet1');
      _header(sheet, ['Folio','Fecha','Cliente','Empresa','Estado',
        'Subtotal','Desc%','IVA%','Total','Método pago']);
      for (int i = 0; i < filtradas.length; i++) {
        final c = filtradas[i]; final r = i + 1;
        _cell(sheet, 0, r, c.folio ?? '');
        _cell(sheet, 1, r, c.createdAt != null ? _fmtFecha.format(c.createdAt!) : '');
        _cell(sheet, 2, r, c.cliente?.nombre ?? '');
        _cell(sheet, 3, r, c.cliente?.empresa ?? '');
        _cell(sheet, 4, r, c.estado);
        _cellNum(sheet, 5, r, c.subtotal);
        _cellNum(sheet, 6, r, c.descuentoPct);
        _cellNum(sheet, 7, r, c.ivaPct);
        _cellNum(sheet, 8, r, c.total);
        _cell(sheet, 9, r, c.metodoPago ?? '');
      }
      await _guardar(excel, 'Cotizaciones_${_fmtFecha.format(_desde)}');
    } catch (e) { _error('$e'); }
    finally { if (mounted) setState(() => _generando = false); }
  }

  Future<void> _exportarPedidos() async {
    setState(() => _generando = true);
    try {
      final pedidos = await SupabaseService.getPedidos();
      final filtrados = pedidos.where((p) {
        final ok = p.createdAt != null &&
          p.createdAt!.isAfter(_desde.subtract(const Duration(days: 1))) &&
          p.createdAt!.isBefore(_hasta.add(const Duration(days: 1)));
        return ok && (_estadoPed == 'Todos' || p.estado == _estadoPed);
      }).toList();

      final excel = Excel.createExcel();
      final sheet = excel['Pedidos'];
      excel.delete('Sheet1');
      _header(sheet, ['Folio','Fecha','Cliente','Estado','Total',
        'F.Entrega estimada','F.Entregado','Notas']);
      for (int i = 0; i < filtrados.length; i++) {
        final p = filtrados[i]; final r = i + 1;
        _cell(sheet, 0, r, p.folio);
        _cell(sheet, 1, r, p.createdAt != null ? _fmtFecha.format(p.createdAt!) : '');
        _cell(sheet, 2, r, p.cliente?.nombre ?? '');
        _cell(sheet, 3, r, p.estado);
        _cellNum(sheet, 4, r, p.total ?? 0);
        _cell(sheet, 5, r, p.fechaEntregaEstimada != null ? _fmtFecha.format(p.fechaEntregaEstimada!) : '');
        _cell(sheet, 6, r, p.fechaEntregado != null ? _fmtFecha.format(p.fechaEntregado!) : '');
        _cell(sheet, 7, r, p.notasInternas ?? '');
      }
      await _guardar(excel, 'Pedidos_${_fmtFecha.format(_desde)}');
    } catch (e) { _error('$e'); }
    finally { if (mounted) setState(() => _generando = false); }
  }

  Future<void> _exportarGastos() async {
    setState(() => _generando = true);
    try {
      final gastos = await SupabaseService.getGastos();
      final filtrados = gastos.where((g) {
        final fecha = g['fecha'] != null ? DateTime.tryParse(g['fecha']) : null;
        return fecha != null &&
          fecha.isAfter(_desde.subtract(const Duration(days: 1))) &&
          fecha.isBefore(_hasta.add(const Duration(days: 1)));
      }).toList();

      final excel = Excel.createExcel();
      final sheet = excel['Gastos'];
      excel.delete('Sheet1');
      _header(sheet, ['Fecha','Concepto','Categoría','Tipo','Monto']);
      for (int i = 0; i < filtrados.length; i++) {
        final g = filtrados[i]; final r = i + 1;
        _cell(sheet, 0, r, g['fecha'] ?? '');
        _cell(sheet, 1, r, g['concepto'] ?? '');
        _cell(sheet, 2, r, g['categoria'] ?? '');
        _cell(sheet, 3, r, g['tipo'] ?? '');
        _cellNum(sheet, 4, r, (g['monto'] as num?)?.toDouble() ?? 0);
      }
      await _guardar(excel, 'Gastos_${_fmtFecha.format(_desde)}');
    } catch (e) { _error('$e'); }
    finally { if (mounted) setState(() => _generando = false); }
  }

  Future<void> _exportarCompleto() async {
    setState(() => _generando = true);
    try {
      final results = await Future.wait([
        SupabaseService.getCotizaciones(),
        SupabaseService.getPedidos(),
        SupabaseService.getGastos(),
      ]);
      final cots = (results[0] as List<Cotizacion>).where((c) =>
        c.createdAt != null &&
        c.createdAt!.isAfter(_desde.subtract(const Duration(days: 1))) &&
        c.createdAt!.isBefore(_hasta.add(const Duration(days: 1)))).toList();
      final peds = (results[1] as List<Pedido>).where((p) =>
        p.createdAt != null &&
        p.createdAt!.isAfter(_desde.subtract(const Duration(days: 1))) &&
        p.createdAt!.isBefore(_hasta.add(const Duration(days: 1)))).toList();
      final gasts = (results[2] as List<Map<String,dynamic>>).where((g) {
        final f = g['fecha'] != null ? DateTime.tryParse(g['fecha']) : null;
        return f != null &&
          f.isAfter(_desde.subtract(const Duration(days: 1))) &&
          f.isBefore(_hasta.add(const Duration(days: 1)));
      }).toList();

      final excel = Excel.createExcel();
      excel.delete('Sheet1');

      // Resumen
      final res = excel['Resumen'];
      _header(res, ['Concepto','Valor']);
      final tv = peds.where((p) => p.estado == 'Entregado')
        .fold(0.0, (s, p) => s + (p.total ?? 0));
      final tg = gasts.fold(0.0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0));
      _cell(res,0,1,'Período'); _cell(res,1,1,'${_fmtFecha.format(_desde)} al ${_fmtFecha.format(_hasta)}');
      _cell(res,0,2,'Cotizaciones'); _cellNum(res,1,2,cots.length.toDouble());
      _cell(res,0,3,'Pedidos'); _cellNum(res,1,3,peds.length.toDouble());
      _cell(res,0,4,'Ventas entregadas'); _cellNum(res,1,4,tv);
      _cell(res,0,5,'Total gastos'); _cellNum(res,1,5,tg);
      _cell(res,0,6,'Utilidad neta'); _cellNum(res,1,6,tv-tg);

      // Cotizaciones
      final sc = excel['Cotizaciones'];
      _header(sc, ['Folio','Fecha','Cliente','Estado','Total']);
      for (int i = 0; i < cots.length; i++) {
        final c = cots[i];
        _cell(sc,0,i+1,c.folio??'');
        _cell(sc,1,i+1,c.createdAt!=null?_fmtFecha.format(c.createdAt!):'');
        _cell(sc,2,i+1,c.cliente?.nombre??'');
        _cell(sc,3,i+1,c.estado);
        _cellNum(sc,4,i+1,c.total);
      }

      // Pedidos
      final sp = excel['Pedidos'];
      _header(sp, ['Folio','Fecha','Cliente','Estado','Total']);
      for (int i = 0; i < peds.length; i++) {
        final p = peds[i];
        _cell(sp,0,i+1,p.folio);
        _cell(sp,1,i+1,p.createdAt!=null?_fmtFecha.format(p.createdAt!):'');
        _cell(sp,2,i+1,p.cliente?.nombre??'');
        _cell(sp,3,i+1,p.estado);
        _cellNum(sp,4,i+1,p.total??0);
      }

      // Gastos
      final sg = excel['Gastos'];
      _header(sg, ['Fecha','Concepto','Categoría','Monto']);
      for (int i = 0; i < gasts.length; i++) {
        final g = gasts[i];
        _cell(sg,0,i+1,g['fecha']??'');
        _cell(sg,1,i+1,g['concepto']??'');
        _cell(sg,2,i+1,g['categoria']??'');
        _cellNum(sg,3,i+1,(g['monto'] as num?)?.toDouble()??0);
      }

      await _guardar(excel, 'Reporte_Completo_${_fmtFecha.format(_desde)}');
    } catch (e) { _error('$e'); }
    finally { if (mounted) setState(() => _generando = false); }
  }

  // ── Helpers ─────────────────────────────────────────
  void _header(Sheet s, List<String> headers) {
    for (int i = 0; i < headers.length; i++) {
      final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1a3a5c'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
    }
  }

  void _cell(Sheet s, int col, int row, String val) =>
    s.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).value =
      TextCellValue(val);

  void _cellNum(Sheet s, int col, int row, double val) =>
    s.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).value =
      DoubleCellValue(val);

  Future<void> _guardar(Excel excel, String nombre) async {
    final bytes = excel.save();
    if (bytes == null) throw Exception('Error generando archivo');
    final dir = await getTemporaryDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    final archivo = File('${dir.path}/$nombre.xlsx');
    await archivo.writeAsBytes(bytes);
    if (mounted) {
      await Share.shareXFiles([XFile(archivo.path)],
        text: 'Reporte HETNA CNC — $nombre');
    }
  }

  void _error(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.rojo));
  }

  Widget _seccion(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(t, style: const TextStyle(
      fontSize: 10, fontWeight: FontWeight.w700,
      color: AppColors.textoSecundario, letterSpacing: 1.5)));

  Widget _btnExportar(String label, Color color, VoidCallback? onTap) =>
    SizedBox(width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12)),
        child: _generando
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))));

  Widget _selectorFecha(String label, DateTime fecha, void Function(DateTime) onChange) =>
    GestureDetector(
      onTap: () async {
        final sel = await showDatePicker(
          context: context, initialDate: fecha,
          firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (sel != null) onChange(sel);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.grisBorde),
          borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(
            fontSize: 10, color: AppColors.textoSecundario)),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.azul),
            const SizedBox(width: 6),
            Text(_fmtFecha.format(fecha), style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.azul)),
          ]),
        ])));

  Widget _btnRapido(String label, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.azulClaro, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: const TextStyle(
          fontSize: 11, color: AppColors.azul, fontWeight: FontWeight.w600))));
}

// ══════════════════════════════════════════════════════
// TAB FISCAL SAT
// ══════════════════════════════════════════════════════
class _TabFiscal extends StatefulWidget {
  const _TabFiscal();
  @override
  State<_TabFiscal> createState() => _TabFiscalState();
}

class _TabFiscalState extends State<_TabFiscal> {
  DateTime _desde = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _hasta = DateTime.now();
  bool _generando = false;
  Map<String, dynamic>? _res;
  String _regimen = 'RESICO';

  final _fmt = NumberFormat(r'$#,##0.00', 'es_MX');
  final _fmtFecha = DateFormat('dd/MM/yyyy', 'es_MX');

  @override
  void initState() { super.initState(); _calcular(); }

  Future<void> _calcular() async {
    setState(() => _generando = true);
    try {
      final sb = Supabase.instance.client;
      final peds = await sb.from('pedidos').select('total, created_at')
        .eq('estado', 'Entregado')
        .gte('created_at', _desde.toIso8601String())
        .lte('created_at', _hasta.toIso8601String());
      final gasts = await sb.from('gastos').select('monto, categoria, tipo')
        .gte('fecha', _desde.toIso8601String().substring(0,10))
        .lte('fecha', _hasta.toIso8601String().substring(0,10));

      final ingresos = (peds as List).fold(0.0, (s, p) => s + ((p['total'] as num?)?.toDouble() ?? 0));
      final tGastos = (gasts as List).fold(0.0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0));
      final gDir = (gasts).where((g) => g['tipo']=='directo')
        .fold(0.0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0));
      final utilidad = ingresos - tGastos;
      final ivaTras = ingresos * 0.16;
      final ivaAcred = tGastos * 0.16;
      final ivaC = (ivaTras - ivaAcred).clamp(0.0, double.infinity);
      double isr = 0;
      if (_regimen == 'RESICO') {
        if (ingresos <= 300000) isr = ingresos * 0.01;
        else if (ingresos <= 500000) isr = ingresos * 0.015;
        else if (ingresos <= 1000000) isr = ingresos * 0.02;
        else isr = ingresos * 0.025;
      } else {
        if (utilidad > 0) {
          if (utilidad <= 125900) isr = utilidad * 0.0192;
          else if (utilidad <= 1000000) isr = utilidad * 0.30;
          else isr = utilidad * 0.35;
        }
      }
      if (mounted) setState(() {
        _res = {
          'ingresos': ingresos, 'gDir': gDir,
          'gInd': tGastos - gDir, 'tGastos': tGastos,
          'utilidad': utilidad, 'ivaTras': ivaTras,
          'ivaAcred': ivaAcred, 'ivaC': ivaC, 'isr': isr,
          'nPed': peds.length, 'nGast': gasts.length,
        };
        _generando = false;
      });
    } catch (e) { if (mounted) setState(() => _generando = false); }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(14), children: [
      // Banner
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF8B0000), Color(0xFFB71C1C)]),
          borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Text('🏛️', style: TextStyle(fontSize: 28)),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Módulo Fiscal SAT', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('Estimado de impuestos. No sustituye declaración oficial.',
              style: TextStyle(fontSize: 11, color: Colors.white70)),
          ])),
        ])),

      const SizedBox(height: 12),

      // Régimen
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Régimen fiscal', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            _chipRegimen('RESICO', 'Régimen Simplificado de Confianza'),
            _chipRegimen('Empresarial', 'Actividades Empresariales'),
          ]),
        ])),

      const SizedBox(height: 12),

      // Período
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Período fiscal', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _selectorFecha('Desde', _desde,
              (d) { setState(() => _desde = d); _calcular(); })),
            const SizedBox(width: 10),
            Expanded(child: _selectorFecha('Hasta', _hasta,
              (d) { setState(() => _hasta = d); _calcular(); })),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: [
              _btnQ('Ene-Mar', 1, 3), _btnQ('Abr-Jun', 4, 6),
              _btnQ('Jul-Sep', 7, 9), _btnQ('Oct-Dic', 10, 12),
              _btnRapido('Este año', () { setState(() {
                _desde = DateTime(DateTime.now().year, 1, 1);
                _hasta = DateTime(DateTime.now().year, 12, 31);
              }); _calcular(); }),
            ])),
        ])),

      const SizedBox(height: 12),

      if (_generando)
        const Center(child: Padding(padding: EdgeInsets.all(20),
          child: CircularProgressIndicator()))
      else if (_res != null) ...[
        _cardFiscal('💰 Ingresos y Gastos', [
          _linea('Ingresos totales (${_res!['nPed']} pedidos)', _res!['ingresos'], color: AppColors.verde),
          _linea('Gastos directos (materiales)', _res!['gDir'], color: AppColors.rojo),
          _linea('Gastos indirectos (fijos)', _res!['gInd'], color: AppColors.rojo),
          const Divider(height: 14),
          _linea('Utilidad / Base gravable', _res!['utilidad'], bold: true,
            color: (_res!['utilidad'] as double) >= 0 ? AppColors.verde : AppColors.rojo),
        ]),
        const SizedBox(height: 10),
        _cardFiscal('🧾 IVA', [
          _linea('IVA trasladado (cobrado 16%)', _res!['ivaTras']),
          _linea('IVA acreditable (pagado en gastos)', _res!['ivaAcred']),
          const Divider(height: 14),
          _linea('IVA a cargo (pagar al SAT)', _res!['ivaC'], bold: true, color: AppColors.rojo),
          const SizedBox(height: 6),
          _aviso('Declaración mensual — límite día 17 del mes siguiente.'),
        ]),
        const SizedBox(height: 10),
        _cardFiscal('🏦 ISR', [
          _lineaTexto('Régimen', _regimen == 'RESICO'
            ? 'RESICO — tasa sobre ingresos' : 'Empresarial — tasa sobre utilidad'),
          _linea('Base de cálculo', _regimen == 'RESICO'
            ? _res!['ingresos'] : _res!['utilidad']),
          const Divider(height: 14),
          _linea('ISR estimado', _res!['isr'], bold: true, color: AppColors.rojo),
          const SizedBox(height: 6),
          _aviso('Pago provisional mensual. Declaración anual en Abril.'),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF8B0000),
            borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            const Text('TOTAL ESTIMADO A PAGAR AL SAT',
              style: TextStyle(fontSize: 11, color: Colors.white70, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(_fmt.format((_res!['ivaC'] as double) + (_res!['isr'] as double)),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            Text('IVA: ${_fmt.format(_res!['ivaC'])}  +  ISR: ${_fmt.format(_res!['isr'])}',
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ])),
        const SizedBox(height: 10),
        _cardFiscal('📋 Checklist SAT', [
          _check('Declaración IVA mensual (día 17)', true),
          _check('Pago provisional ISR mensual (día 17)', true),
          _check('DIOT mensual (proveedores)', true),
          _check('Declaración anual ISR (Abril)', false),
          _check('Contabilidad electrónica (trimestral)', false),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.ambarClaro,
            borderRadius: BorderRadius.circular(10)),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('⚠️', style: TextStyle(fontSize: 14)),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Estimación orientativa. Consulta con tu contador para la declaración oficial.',
              style: TextStyle(fontSize: 11, color: Color(0xFF854f0b)))),
          ])),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _exportarFiscal,
            icon: const Icon(Icons.download_outlined, color: Colors.white, size: 16),
            label: const Text('Exportar reporte fiscal .xlsx',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              padding: const EdgeInsets.symmetric(vertical: 13)))),
      ],

      const SizedBox(height: 30),
    ]);
  }

  Future<void> _exportarFiscal() async {
    if (_res == null) return;
    setState(() => _generando = true);
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Reporte Fiscal SAT'];
      excel.delete('Sheet1');

      void wc(int col, int row, String val, {bool bold = false}) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = TextCellValue(val);
        if (bold) cell.cellStyle = CellStyle(bold: true);
      }

      wc(0, 0, 'REPORTE FISCAL ESTIMADO — HETNA CNC', bold: true);
      wc(0, 1, 'Período: ${_fmtFecha.format(_desde)} al ${_fmtFecha.format(_hasta)}');
      wc(0, 2, 'Régimen: $_regimen');
      wc(0, 4, 'CONCEPTO', bold: true); wc(1, 4, 'MONTO', bold: true);

      final filas = [
        ['Ingresos totales', _fmt.format(_res!['ingresos'])],
        ['Gastos directos', _fmt.format(_res!['gDir'])],
        ['Gastos indirectos', _fmt.format(_res!['gInd'])],
        ['Total gastos', _fmt.format(_res!['tGastos'])],
        ['Utilidad/Base gravable', _fmt.format(_res!['utilidad'])],
        ['', ''],
        ['IVA trasladado', _fmt.format(_res!['ivaTras'])],
        ['IVA acreditable', _fmt.format(_res!['ivaAcred'])],
        ['IVA a cargo', _fmt.format(_res!['ivaC'])],
        ['', ''],
        ['ISR estimado', _fmt.format(_res!['isr'])],
        ['', ''],
        ['TOTAL A PAGAR SAT', _fmt.format((_res!['ivaC'] as double) + (_res!['isr'] as double))],
      ];

      for (int i = 0; i < filas.length; i++) {
        wc(0, i + 5, filas[i][0], bold: filas[i][0].toUpperCase() == filas[i][0] && filas[i][0].isNotEmpty);
        wc(1, i + 5, filas[i][1]);
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('Error');
      final dir = await getTemporaryDirectory();
      if (!await dir.exists()) await dir.create(recursive: true);
      final archivo = File('${dir.path}/ReporteFiscal_${DateFormat('ddMMyyyy').format(_desde)}.xlsx');
      await archivo.writeAsBytes(bytes);
      if (mounted) await Share.shareXFiles([XFile(archivo.path)], text: 'Reporte Fiscal SAT');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.rojo));
    }
    finally { if (mounted) setState(() => _generando = false); }
  }

  Widget _chipRegimen(String clave, String label) => GestureDetector(
    onTap: () { setState(() => _regimen = clave); _calcular(); },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _regimen == clave ? const Color(0xFF8B0000) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _regimen == clave ? const Color(0xFF8B0000) : AppColors.grisBorde)),
      child: Column(children: [
        Text(clave, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: _regimen == clave ? Colors.white : AppColors.textoPrincipal)),
        Text(label, style: TextStyle(
          fontSize: 10, color: _regimen == clave ? Colors.white70 : AppColors.textoSecundario)),
      ])));

  Widget _cardFiscal(String titulo, List<Widget> items) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
      const SizedBox(height: 12),
      ...items,
    ]));

  Widget _linea(String label, double monto, {bool bold=false, Color? color}) =>
    Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.normal))),
        Text(_fmt.format(monto), style: TextStyle(
          fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color ?? AppColors.textoPrincipal)),
      ]));

  Widget _lineaTexto(String label, String valor) =>
    Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Expanded(child: Text(valor, textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario))),
      ]));

  Widget _aviso(String texto) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: AppColors.azulClaro, borderRadius: BorderRadius.circular(8)),
    child: Text(texto, style: const TextStyle(fontSize: 11, color: AppColors.azul)));

  Widget _check(String texto, bool mensual) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(Icons.check_circle_outline, size: 16,
        color: mensual ? AppColors.verde : AppColors.ambar),
      const SizedBox(width: 8),
      Expanded(child: Text(texto, style: const TextStyle(fontSize: 12))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: mensual ? AppColors.verde.withOpacity(0.1) : AppColors.ambar.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10)),
        child: Text(mensual ? 'Mensual' : 'Anual',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
            color: mensual ? AppColors.verde : AppColors.ambar))),
    ]));

  Widget _selectorFecha(String label, DateTime fecha, void Function(DateTime) onChange) =>
    GestureDetector(
      onTap: () async {
        final sel = await showDatePicker(context: context,
          initialDate: fecha, firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (sel != null) onChange(sel);
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
            Text(_fmtFecha.format(fecha), style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.azul)),
          ]),
        ])));

  Widget _btnQ(String label, int mesI, int mesF) => _btnRapido(label, () {
    final y = DateTime.now().year;
    setState(() { _desde = DateTime(y, mesI, 1); _hasta = DateTime(y, mesF + 1, 0); });
    _calcular();
  });

  Widget _btnRapido(String label, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFfce8e8), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: const TextStyle(
          fontSize: 11, color: Color(0xFF8B0000), fontWeight: FontWeight.w600))));
}
