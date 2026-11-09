// lib/simulador2/capacidad.dart
// HETNA CNC — Fecha de entrega calculada con la carga real del taller.
//
// Carga = horas de máquina de los pedidos que todavía no se maquinan
// (estados Pedido, Pago50, Produccion), tomadas de cotizacion_items.tiempo_min
// de cada pedido (o de pedidos.tiempo_estimado_min si no hay partidas).
// Capacidad = horas_dia × días que trabaja el taller (empresa_config).
// La fecha es el día en que se termina la carga que va adelante + este pedido.
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class Entrega {
  final DateTime fecha;
  final double horasAdelante;   // trabajo que ya está en cola para esa máquina
  final double horasEste;       // este pedido
  final int diasHabiles;
  final double horasDia;
  const Entrega({required this.fecha, required this.horasAdelante, required this.horasEste, required this.diasHabiles, required this.horasDia});
}

class Capacidad {
  static final _db = Supabase.instance.client;

  static double _d(dynamic v, [double def = 0]) => (v as num?)?.toDouble() ?? def;

  /// Horas de máquina pendientes. Si se da maquinaId, sólo las de esa máquina.
  static Future<double> horasEnCola({String? maquinaId}) async {
    try {
      final peds = await _db.from('pedidos').select('id, cotizacion_id, tiempo_estimado_min, estado')
        .in_('estado', ['Pedido', 'Pago50', 'Produccion']);
      final l = (peds as List).cast<Map<String, dynamic>>();
      if (l.isEmpty) return 0;
      final cotIds = l.map((p) => p['cotizacion_id']).whereType<String>().toList();
      double min = 0;
      Map<String, double> porCot = {};
      if (cotIds.isNotEmpty) {
        var q = _db.from('cotizacion_items').select('cotizacion_id, tiempo_min, cantidad, maquina_id').in_('cotizacion_id', cotIds);
        final items = await q;
        for (final i in (items as List).cast<Map<String, dynamic>>()) {
          if (maquinaId != null && i['maquina_id'] != maquinaId) continue;
          final t = _d(i['tiempo_min']) * _d(i['cantidad'], 1);
          porCot[i['cotizacion_id'] as String] = (porCot[i['cotizacion_id'] as String] ?? 0) + t;
        }
      }
      for (final p in l) {
        final cid = p['cotizacion_id'] as String?;
        if (cid != null && porCot.containsKey(cid)) { min += porCot[cid]!; }
        else if (maquinaId == null) { min += _d(p['tiempo_estimado_min']); }
      }
      return min / 60;
    } catch (_) { return 0; }
  }

  static Future<({double horasDia, int diasSemana})> jornada() async {
    try {
      final cfg = await _db.from('empresa_config').select('horas_dia, dias_semana').eq('negocio_id', AuthService.negocioId).maybeSingle();
      return (horasDia: _d(cfg?['horas_dia'], 8), diasSemana: (_d(cfg?['dias_semana'], 6)).round().clamp(1, 7));
    } catch (_) { return (horasDia: 8.0, diasSemana: 6); }
  }

  static bool _habil(DateTime d, int diasSemana) {
    if (diasSemana >= 7) return true;
    if (d.weekday == DateTime.sunday) return false;
    if (diasSemana <= 5 && d.weekday == DateTime.saturday) return false;
    return true;
  }

  /// Cuándo se puede entregar un trabajo de `horasEste` horas en `maquinaId`.
  static Future<Entrega> fechaEntrega({required double horasEste, String? maquinaId, double horasMargen = 0}) async {
    final j = await jornada();
    final cola = await horasEnCola(maquinaId: maquinaId);
    double pendiente = cola + horasEste + horasMargen;
    // Hoy cuenta sólo si todavía es temprano (antes de las 2 pm)
    var d = DateTime.now();
    final hoyCuenta = d.hour < 14 && _habil(d, j.diasSemana);
    double disponibleHoy = hoyCuenta ? j.horasDia * (1 - d.hour / 24) : 0;
    int dias = 0;
    if (hoyCuenta) { pendiente -= disponibleHoy; }
    while (pendiente > 0 && dias < 365) {
      d = d.add(const Duration(days: 1));
      if (!_habil(d, j.diasSemana)) continue;
      pendiente -= j.horasDia;
      dias++;
    }
    // Siempre al menos el día siguiente hábil para empacar/entregar
    if (dias == 0) {
      d = d.add(const Duration(days: 1));
      while (!_habil(d, j.diasSemana)) { d = d.add(const Duration(days: 1)); }
      dias = 1;
    }
    return Entrega(fecha: DateTime(d.year, d.month, d.day), horasAdelante: cola, horasEste: horasEste, diasHabiles: dias, horasDia: j.horasDia);
  }
}
