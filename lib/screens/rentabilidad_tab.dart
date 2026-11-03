// ============================================
// lib/screens/rentabilidad_tab.dart
// Cotizador 2.0 · Fase 4 — Rentabilidad real (Reportes → Rentabilidad)
//
// Con el costo real que se anota en cada pedido: ventas, costo, utilidad y
// margen del periodo; rentabilidad por máquina (la venta de cada pedido se
// reparte entre sus máquinas según las horas) y por cliente.
// ============================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../main.dart';
import '../models/models.dart';
import '../i18n/tr.dart';
import '../services/costos_service.dart';
import '../services/supabase_service.dart';

class RentabilidadTab extends StatefulWidget {
  const RentabilidadTab({super.key});
  @override
  State<RentabilidadTab> createState() => _RentabilidadTabState();
}

class _Suma {
  double ventas = 0, costo = 0, horas = 0;
  int pedidos = 0;
  double get utilidad => ventas - costo;
  double get margen => ventas > 0 ? utilidad / ventas * 100 : 0;
}

class _RentabilidadTabState extends State<RentabilidadTab> {
  String _periodo = 'mes';
  bool _cargando = true;
  String? _error;

  final _total = _Suma();          // pedidos con costo capturado
  double _ventasTodas = 0;         // todos los pedidos del periodo
  int _sinCostos = 0;
  final Map<String, _Suma> _porMaquina = {};
  final Map<String, _Suma> _porCliente = {};
  final List<({Pedido p, double ventas, double costo})> _pedidos = [];

  final _fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 0);

  static const _periodos = {'mes': 'Este mes', 'pasado': 'Mes pasado', 'tres': 'Últimos 3 meses', 'anio': 'Este año'};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  (DateTime, DateTime) _rango() {
    final h = DateTime.now();
    switch (_periodo) {
      case 'pasado': return (DateTime(h.year, h.month - 1, 1), DateTime(h.year, h.month, 1));
      case 'tres': return (DateTime(h.year, h.month - 2, 1), DateTime(h.year, h.month + 1, 1));
      case 'anio': return (DateTime(h.year, 1, 1), DateTime(h.year + 1, 1, 1));
      default: return (DateTime(h.year, h.month, 1), DateTime(h.year, h.month + 1, 1));
    }
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final (desde, hasta) = _rango();
      final todos = await SupabaseService.getPedidos();
      final pedidos = todos.where((p) {
        final f = p.createdAt;
        return f != null && !f.isBefore(desde) && f.isBefore(hasta) && p.estado != 'Cancelado' && p.id != null;
      }).toList();
      final cotIds = pedidos.map((p) => p.cotizacionId).whereType<String>().toSet().toList();
      final r = await Future.wait([
        CostosService.ivaDeCotizaciones(cotIds),
        CostosService.costosDePedidos(pedidos.map((p) => p.id!).toList()),
        CostosService.maquinas(soloActivas: false),
      ]);
      final iva = r[0] as Map<String, double>;
      final costos = r[1] as List<Map<String, dynamic>>;
      final nombres = {for (final m in r[2] as List<Map<String, dynamic>>) m['id'].toString(): (m['nombre'] ?? '').toString()};

      final porPedido = <String, List<Map<String, dynamic>>>{};
      for (final c in costos) {
        porPedido.putIfAbsent(c['pedido_id'].toString(), () => []).add(c);
      }

      _total..ventas = 0..costo = 0..pedidos = 0;
      _ventasTodas = 0;
      _sinCostos = 0;
      _porMaquina.clear();
      _porCliente.clear();
      _pedidos.clear();

      for (final p in pedidos) {
        final ventas = CostosService.sinIva(p.total ?? 0, p.cotizacionId == null ? null : iva[p.cotizacionId]);
        _ventasTodas += ventas;
        final lineas = porPedido[p.id] ?? [];
        if (lineas.isEmpty) { _sinCostos++; continue; }
        final costo = lineas.fold<double>(0, (s, c) => s + ((c['costo_total'] ?? 0) as num).toDouble());
        _total..ventas += ventas..costo += costo..pedidos += 1;
        _pedidos.add((p: p, ventas: ventas, costo: costo));

        final cli = p.cliente?.empresa?.isNotEmpty == true ? p.cliente!.empresa! : (p.cliente?.nombre ?? tr('Sin cliente'));
        final sc = _porCliente.putIfAbsent(cli, () => _Suma());
        sc..ventas += ventas..costo += costo..pedidos += 1;

        // Horas por máquina dentro del pedido → reparto de venta y costo
        final horas = <String, double>{};
        for (final c in lineas.where((c) => c['tipo'] == 'maquina' && c['maquina_id'] != null)) {
          final id = c['maquina_id'].toString();
          horas[id] = (horas[id] ?? 0) + ((c['cantidad'] ?? 0) as num).toDouble();
        }
        final totalH = horas.values.fold<double>(0, (s, h) => s + h);
        if (totalH > 0) {
          horas.forEach((id, h) {
            final parte = h / totalH;
            final sm = _porMaquina.putIfAbsent(nombres[id] ?? tr('Máquina'), () => _Suma());
            sm..ventas += ventas * parte..costo += costo * parte..horas += h..pedidos += 1;
          });
        }
      }
      _pedidos.sort((a, b) {
        double m(({Pedido p, double ventas, double costo}) x) => x.ventas > 0 ? (x.ventas - x.costo) / x.ventas : 0;
        return m(a).compareTo(m(b));
      });
      if (mounted) setState(() => _cargando = false);
    } catch (e) {
      if (mounted) setState(() {
        _cargando = false;
        _error = e.toString().contains('pedido_costos')
          ? tr('Falta correr el SQL de la Fase 4 en Supabase (tabla pedido_costos).')
          : e.toString();
      });
    }
  }

  Color _color(double margen) => margen >= 30 ? AppColors.verde : margen >= 15 ? AppColors.naranja : AppColors.rojo;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(16), children: [
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _periodos.entries.map((e) =>
        Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
          label: Text(tr(e.value), style: const TextStyle(fontSize: 12)),
          selected: _periodo == e.key,
          onSelected: (_) { setState(() => _periodo = e.key); _cargar(); }))).toList())),
      const SizedBox(height: 12),
      if (_cargando) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
      else if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.rojo))
      else ..._contenido(),
    ]));
  }

  List<Widget> _contenido() {
    if (_total.pedidos == 0) {
      return [
        _caja(Column(children: [
          const Icon(Icons.calculate_outlined, size: 40, color: AppColors.azul),
          const SizedBox(height: 8),
          Text(tr('Aún no hay pedidos con costo real en este periodo.'), textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(tr('En Avances, abre un pedido y toca "Costo real y utilidad" para anotar horas de máquina, material y operador.'),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          if (_ventasTodas > 0) Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(trf('Ventas del periodo (sin IVA): {0}', [_fmt.format(_ventasTodas)]), style: const TextStyle(fontSize: 12))),
        ])),
      ];
    }
    final maquinas = _porMaquina.entries.toList()..sort((a, b) => b.value.utilidad.compareTo(a.value.utilidad));
    final clientes = _porCliente.entries.toList()..sort((a, b) => b.value.utilidad.compareTo(a.value.utilidad));
    return [
      _resumen(),
      if (_sinCostos > 0) Padding(padding: const EdgeInsets.only(top: 8),
        child: Text(trf('{0} pedidos del periodo no tienen costo real anotado y no entran en la utilidad (ventas totales sin IVA: {1}).',
          [_sinCostos, _fmt.format(_ventasTodas)]), style: const TextStyle(fontSize: 11, color: AppColors.naranja))),
      const SizedBox(height: 16),
      _titulo(tr('Rentabilidad por máquina')),
      if (maquinas.isEmpty) Text(tr('Anota horas de máquina en los pedidos para ver esta parte.'),
        style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario))
      else ...maquinas.map((e) => _filaMaquina(e.key, e.value)),
      const SizedBox(height: 16),
      _titulo(tr('Clientes que más utilidad dejan')),
      ...clientes.take(8).map((e) => _fila(e.key, e.value, trf('{0} pedidos', [e.value.pedidos]))),
      const SizedBox(height: 16),
      _titulo(tr('Pedidos con menor margen')),
      ..._pedidos.take(5).map((x) {
        final s = _Suma()..ventas = x.ventas..costo = x.costo;
        return _fila('${x.p.folio} · ${x.p.cliente?.nombre ?? ''}', s, null);
      }),
      const SizedBox(height: 30),
    ];
  }

  Widget _caja(Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: child);

  Widget _titulo(String t) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)));

  Widget _resumen() {
    Widget kpi(String t, String v, {Color? c}) => Expanded(child: Column(children: [
      Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c ?? AppColors.textoPrincipal)),
      Text(t, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario), textAlign: TextAlign.center),
    ]));
    final c = _color(_total.margen);
    return _caja(Column(children: [
      Row(children: [
        kpi(tr('Ventas sin IVA'), _fmt.format(_total.ventas)),
        kpi(tr('Costo real'), _fmt.format(_total.costo)),
        kpi(tr('Utilidad'), _fmt.format(_total.utilidad), c: c),
        kpi(tr('Margen'), '${_total.margen.toStringAsFixed(1)}%', c: c),
      ]),
      const SizedBox(height: 6),
      Text(trf('{0} pedidos con costo real', [_total.pedidos]), style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
    ]));
  }

  Widget _filaMaquina(String nombre, _Suma s) {
    final porHora = s.horas > 0 ? s.utilidad / s.horas : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.precision_manufacturing_outlined, size: 18, color: AppColors.azul),
          const SizedBox(width: 6),
          Expanded(child: Text(nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
          Text('${s.margen.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.w800, color: _color(s.margen))),
        ]),
        const SizedBox(height: 6),
        Text(trf('Horas trabajadas: {0} h', [s.horas.toStringAsFixed(1)]), style: const TextStyle(fontSize: 12)),
        Text(trf('Ingresos: {0}  ·  Costo: {1}', [_fmt.format(s.ventas), _fmt.format(s.costo)]), style: const TextStyle(fontSize: 12)),
        Text(trf('Utilidad: {0}  ({1} por hora)', [_fmt.format(s.utilidad), _fmt.format(porHora)]),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _color(s.margen))),
      ]));
  }

  Widget _fila(String titulo, _Suma s, String? sub) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: ListTile(
      dense: true,
      title: Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text([if (sub != null) sub, trf('venta {0}', [_fmt.format(s.ventas)])].join(' · '), style: const TextStyle(fontSize: 11)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(_fmt.format(s.utilidad), style: TextStyle(fontWeight: FontWeight.w700, color: _color(s.margen))),
        Text('${s.margen.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      ])));
}
