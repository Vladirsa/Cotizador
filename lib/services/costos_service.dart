// ============================================
// lib/services/costos_service.dart
// Cotizador 2.0 · Fase 4 — Costo real, rentabilidad y mantenimiento
//
// - Costo por hora de cada máquina y operador: misma fórmula que
//   Configuración → Costos del taller (config_costos_screen.dart).
// - pedido_costos: lo que de verdad costó cada pedido (horas de máquina,
//   material del inventario, horas de operador, otros).
// - Mantenimiento: horas de cada máquina (v_horas_maquina = horas_base +
//   horas capturadas en pedidos), tareas cada N horas / N días y registro.
// Tablas en supabase/fase4_factura_costos_mantenimiento.sql
// ============================================
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'supabase_service.dart';

class CostosService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _neg => AuthService.negocioId ?? '';

  static double _n(dynamic v, [double d = 0]) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? d);

  // ── Costo por hora ────────────────────────────────────────────────
  static double costoHoraMaquina(Map<String, dynamic> m) {
    final valor = _n(m['valor_adquisicion']);
    final vida = _n(m['vida_util_anos'] ?? m['vida_util_años'], 5);
    final horasMes = _n(m['horas_mes'], 160);
    final kwh = _n(m['consumo_kwh']);
    final costoKwh = _n(m['costo_kwh'], 2.5);
    final mant = _n(m['mantenimiento_mes']);
    final consumibles = _n(m['consumibles_hora']);
    final depreciacion = vida > 0 && horasMes > 0 ? valor / (vida * 12 * horasMes) : 0.0;
    final mantHora = horasMes > 0 ? mant / horasMes : 0.0;
    return depreciacion + kwh * costoKwh + mantHora + consumibles;
  }

  static double costoHoraOperador(Map<String, dynamic> o) {
    final salario = _n(o['salario_mes']);
    final prest = _n(o['prestaciones_pct'], 35);
    final horas = _n(o['horas_mes'], 192);
    return horas > 0 ? salario * (1 + prest / 100) / horas : 0.0;
  }

  static const _fijos = ['costo_renta', 'costo_luz', 'costo_agua', 'costo_internet', 'costo_nomina_admin',
    'costo_contador', 'costo_licencias', 'costo_publicidad', 'costo_seguros', 'costo_depreciacion',
    'costo_mantenimiento', 'costo_otros'];

  /// Gastos fijos del taller repartidos por hora trabajada.
  static double costoHoraTaller(Map<String, dynamic>? cfg) {
    if (cfg == null) return 0;
    final total = _fijos.fold<double>(0, (s, k) => s + _n(cfg[k]));
    final horas = _n(cfg['horas_dia'], 8);
    final diasMes = _n(cfg['dias_semana'], 6) * 4.33;
    return diasMes > 0 && horas > 0 ? total / (diasMes * horas) : 0.0;
  }

  static Future<List<Map<String, dynamic>>> maquinas({bool soloActivas = true}) async {
    try {
      var q = _db.from('maquinaria').select().eq('negocio_id', _neg);
      if (soloActivas) q = q.eq('activo', true);
      final r = await q.order('nombre');
      return (r as List).cast<Map<String, dynamic>>();
    } catch (_) { return []; }
  }

  static Future<List<Map<String, dynamic>>> operadores() async {
    try {
      final r = await _db.from('mano_obra').select().eq('negocio_id', _neg).eq('activo', true);
      return (r as List).cast<Map<String, dynamic>>();
    } catch (_) { return []; }
  }

  static Future<Map<String, dynamic>?> empresaConfig() async {
    try {
      final r = await _db.from('empresa_config').select().eq('negocio_id', _neg).maybeSingle();
      return r == null ? null : Map<String, dynamic>.from(r as Map);
    } catch (_) { return null; }
  }

  // ── Costo real por pedido ─────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> costosPedido(String pedidoId) async {
    final r = await _db.from('pedido_costos').select().eq('pedido_id', pedidoId).order('creado');
    return (r as List).cast<Map<String, dynamic>>();
  }

  /// Agrega un costo. Si es material del inventario, también le da salida.
  static Future<void> agregarCosto({
    required String pedidoId, required String folio, required String tipo, required String concepto,
    required double cantidad, required double costoUnitario, String? maquinaId, String? materialId,
  }) async {
    if (materialId != null) {
      final err = await SupabaseService.registrarMovimiento(
        materialId: materialId, tipo: 'salida', cantidad: cantidad.round(), motivo: 'Pedido $folio');
      if (err != null) throw Exception(err);
    }
    await _db.from('pedido_costos').insert({
      'negocio_id': _neg.isEmpty ? null : _neg,
      'pedido_id': pedidoId,
      'tipo': tipo,
      'concepto': concepto,
      'maquina_id': maquinaId,
      'material_id': materialId,
      'cantidad': cantidad,
      'costo_unitario': double.parse(costoUnitario.toStringAsFixed(2)),
      'costo_total': double.parse((cantidad * costoUnitario).toStringAsFixed(2)),
    });
  }

  /// Borra un costo; si era material del inventario, lo regresa al stock.
  static Future<void> borrarCosto(Map<String, dynamic> c, String folio) async {
    await _db.from('pedido_costos').delete().eq('id', c['id']);
    if (c['tipo'] == 'material' && c['material_id'] != null) {
      await SupabaseService.registrarMovimiento(
        materialId: c['material_id'].toString(), tipo: 'entrada', cantidad: _n(c['cantidad']).round(),
        motivo: 'Corrección pedido $folio');
    }
  }

  /// Ingreso sin IVA de un pedido (usa el % de IVA de su cotización).
  static Future<Map<String, double>> ivaDeCotizaciones(List<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      final r = await _db.from('cotizaciones').select('id, iva_pct').in_('id', ids);
      return {for (final c in (r as List)) c['id'].toString(): _n(c['iva_pct'], 16)};
    } catch (_) { return {}; }
  }

  static double sinIva(double total, double? ivaPct) => total / (1 + (ivaPct ?? 16) / 100);

  /// Costos de muchos pedidos de una vez (para Rentabilidad).
  static Future<List<Map<String, dynamic>>> costosDePedidos(List<String> ids) async {
    if (ids.isEmpty) return [];
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < ids.length; i += 150) {
      final parte = ids.sublist(i, i + 150 > ids.length ? ids.length : i + 150);
      final r = await _db.from('pedido_costos').select().in_('pedido_id', parte);
      out.addAll((r as List).cast<Map<String, dynamic>>());
    }
    return out;
  }

  // ── Mantenimiento ─────────────────────────────────────────────────
  static Future<Map<String, double>> horasMaquinas() async {
    try {
      final r = await _db.from('v_horas_maquina').select();
      return {for (final h in (r as List)) h['maquina_id'].toString(): _n(h['horas'])};
    } catch (_) { return {}; }
  }

  static Future<void> actualizarMaquina(String id, Map<String, dynamic> datos) async {
    await _db.from('maquinaria').update(datos).eq('id', id);
  }

  static Future<List<Map<String, dynamic>>> tareas() async {
    final r = await _db.from('mantenimiento_tareas').select().order('nombre');
    return (r as List).cast<Map<String, dynamic>>();
  }

  static Future<void> guardarTarea(Map<String, dynamic> t) async {
    final id = t['id'];
    final datos = Map<String, dynamic>.from(t)..remove('id');
    if (id == null) {
      await _db.from('mantenimiento_tareas').insert({'negocio_id': _neg.isEmpty ? null : _neg, ...datos});
    } else {
      await _db.from('mantenimiento_tareas').update(datos).eq('id', id);
    }
  }

  static Future<void> borrarTarea(String id) async {
    await _db.from('mantenimiento_tareas').delete().eq('id', id);
  }

  static Future<List<Map<String, dynamic>>> registros({String? maquinaId, int limite = 50}) async {
    var q = _db.from('mantenimiento_registros').select();
    if (maquinaId != null) q = q.eq('maquina_id', maquinaId);
    final r = await q.order('fecha', ascending: false).limit(limite);
    return (r as List).cast<Map<String, dynamic>>();
  }

  /// Marca una tarea como hecha: guarda el registro, reinicia el contador y,
  /// si costó algo, lo anota en Gastos.
  static Future<void> marcarHecha({
    required Map<String, dynamic> tarea, required String maquinaNombre, required double horasActuales,
    double costo = 0, String? notas,
  }) async {
    final hoy = DateTime.now();
    final fecha = '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
    await _db.from('mantenimiento_registros').insert({
      'negocio_id': _neg.isEmpty ? null : _neg,
      'maquina_id': tarea['maquina_id'],
      'tarea_id': tarea['id'],
      'descripcion': tarea['nombre'],
      'fecha': fecha,
      'horas_maquina': horasActuales,
      'costo': costo,
      'notas': (notas ?? '').trim().isEmpty ? null : notas!.trim(),
    });
    await _db.from('mantenimiento_tareas').update({
      'ultima_horas': horasActuales, 'ultima_fecha': fecha, 'avisado_en': null,
    }).eq('id', tarea['id']);
    if (costo > 0) {
      try {
        await _db.from('gastos').insert({
          'negocio_id': _neg.isEmpty ? null : _neg,
          'concepto': 'Mantenimiento: ${tarea['nombre']} · $maquinaNombre',
          'monto': costo,
          'tipo': 'indirecto',
          'categoria': 'equipo',
          'tipo_gasto_sat': 'equipo',
          'fecha': fecha,
          'tiene_factura': false,
        });
      } catch (_) {/* si la tabla de gastos es distinta, el registro ya quedó */}
    }
  }

  /// Estado de una tarea: 'vencido', 'pronto' u 'ok', con cuánto lleva.
  static ({String estado, double avance, String detalle}) revisar(Map<String, dynamic> t, double horas, DateTime hoy) {
    double avance = 0;
    final partes = <String>[];
    final cadaH = t['cada_horas'] == null ? null : _n(t['cada_horas']);
    final cadaD = t['cada_dias'] == null ? null : _n(t['cada_dias']).toInt();
    if (cadaH != null && cadaH > 0) {
      final lleva = horas - _n(t['ultima_horas']);
      avance = lleva / cadaH;
      partes.add('${lleva.clamp(0, 99999).toStringAsFixed(0)} / ${cadaH.toStringAsFixed(0)} h');
    }
    if (cadaD != null && cadaD > 0) {
      final ultima = DateTime.tryParse('${t['ultima_fecha'] ?? ''}') ?? hoy;
      final dias = DateTime(hoy.year, hoy.month, hoy.day).difference(DateTime(ultima.year, ultima.month, ultima.day)).inDays;
      final a = dias / cadaD;
      if (a > avance) avance = a;
      partes.add('$dias / $cadaD d');
    }
    final estado = avance >= 1 ? 'vencido' : avance >= 0.8 ? 'pronto' : 'ok';
    return (estado: estado, avance: avance, detalle: partes.join(' · '));
  }
}
