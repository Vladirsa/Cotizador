// lib/simulador2/aprender_tiempo_sheet.dart
// HETNA CNC — El simulador aprende de los tiempos reales.
//
// Además, al terminar el maquinado se anotan SOLOS los costos reales del
// pedido (horas de máquina por máquina y horas de operador) en pedido_costos,
// que es lo que alimenta Reportes → Rentabilidad por máquina y el contador de
// horas de Mantenimiento. Si el taller no usa el QR, se anotan las horas
// estimadas (y se marca que son estimadas).
//
// Cuando el operador marca "maquinado terminado" (la orden pasa de Producción
// a control de calidad), se compara cuánto se estimó en la cotización
// (cotizacion_items.tiempo_min × cantidad + preparación) con cuánto tardó de
// verdad (desde el avance "Produccion" hasta ahora). Si la diferencia es de
// más del 15 %, se ofrece corregir la velocidad de ese material en esa
// máquina. Con 10 pedidos las cotizaciones quedan exactas sin capturar nada.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../i18n/tr.dart';
import 'motor.dart';
import 'simulador2_data.dart';
import 'velocidades_hetna.dart';
import '../services/costos_service.dart';

class _Partida {
  final String maquinaId, tipoMaterial; final double espesor, tiempoMin; final int cantidad;
  _Partida(this.maquinaId, this.tipoMaterial, this.espesor, this.tiempoMin, this.cantidad);
}

Future<void> aprenderTiempoSheet(BuildContext context, {required String pedidoId, required String folio}) async {
  final db = Supabase.instance.client;
  List<_Partida> partidas = [];
  double prepMin = 0;
  DateTime? inicio;
  try {
    final p = await db.from('pedidos').select('cotizacion_id').eq('id', pedidoId).maybeSingle();
    final cotId = p?['cotizacion_id'];
    if (cotId == null) return;
    final items = await db.from('cotizacion_items').select().eq('cotizacion_id', cotId);
    for (final i in (items as List).cast<Map<String, dynamic>>()) {
      final t = (i['tiempo_min'] as num?)?.toDouble() ?? 0;
      final mq = i['maquina_id'] as String?;
      if (t <= 0 || mq == null) continue;
      partidas.add(_Partida(mq, (i['tipo_material'] ?? '').toString(), (i['espesor_mm'] as num?)?.toDouble() ?? 0, t, (i['cantidad'] as num?)?.toInt() ?? 1));
    }
    if (partidas.isEmpty) return; // la cotización no vino del simulador 2.0
    final av = await db.from('pedido_avances').select('created_at').eq('pedido_id', pedidoId).eq('etapa', 'Produccion').order('created_at', ascending: false).limit(1);
    if ((av as List).isNotEmpty) inicio = DateTime.tryParse(av.first['created_at'].toString());
  } catch (_) { return; }
  // Sin avance "Produccion" (no usaron el QR) se anotan horas estimadas abajo

  final maquinas = await Simulador2Data.maquinas();
  await Simulador2Data.cargarVelocidades();
  final Maquina2? maq = maquinas.cast<Maquina2?>().firstWhere((m) => m!.id == partidas.first.maquinaId, orElse: () => null);
  if (maq == null) return;
  prepMin = maq.preparacionMin;

  final estimado = partidas.fold(0.0, (s, p) => s + p.tiempoMin * p.cantidad) + prepMin;
  double real = inicio == null ? 0.0 : DateTime.now().difference(inicio).inMinutes.toDouble();
  if (estimado <= 0) return;
  // Si tardó más de 12 h seguramente pasó la noche sin escanear: no se aprende
  final realConfiable = real > 0 && real <= 12 * 60;
  try { await db.from('pedidos').update({'tiempo_estimado_min': estimado, if (real > 0) 'tiempo_real_min': real}).eq('id', pedidoId); } catch (_) {}

  // Costos reales automáticos: horas de máquina (por máquina) y de operador
  await _registrarCostos(pedidoId: pedidoId, folio: folio, partidas: partidas, maquinas: maquinas,
    minutosTotales: realConfiable ? real : estimado, estimadoTotal: estimado, esEstimado: !realConfiable, context: context);
  if (!realConfiable) return;

  final factor = real / estimado;
  if ((factor - 1).abs() < 0.15) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(trf('⏱ {0}: estimado {1} min, real {2} min. La velocidad va bien.', [folio, estimado.round(), real.round()])), backgroundColor: AppColors.verde));
    return;
  }

  // Sólo se corrige la velocidad de la primera partida (la más común es un
  // pedido con una sola pieza/material); la parte de máquina del tiempo real
  // se reparte quitando la preparación.
  final p0 = partidas.first;
  final mat = Material2(nombre: '${tipoMaterialPorClave(p0.tipoMaterial)?.nombre ?? p0.tipoMaterial}${p0.espesor > 0 ? ' ${p0.espesor} mm' : ''}', tipo: p0.tipoMaterial, espesorMm: p0.espesor, precio: 0);
  final velActual = Simulador2Data.velocidad(maq, mat);
  final factorMaq = (real - prepMin) / (estimado - prepMin);
  final ajuste = velocidadDesdeTiempoReal(velocidadActual: 1, tiempoEstimadoMin: estimado - prepMin, tiempoRealMin: real - prepMin);
  if (ajuste == null) return;
  final muestras = Simulador2Data.muestras(maq, mat);
  Velocidad2 nueva;
  String de = '', a = '';
  if (velActual.corteMMin > 0) {
    final n = velocidadPonderada(velActual.corteMMin, muestras, velActual.corteMMin / factorMaq);
    nueva = Velocidad2(corteMMin: n, grabadoCm2Min: velActual.grabadoCm2Min, remocionCm3Min: velActual.remocionCm3Min, impresionCm3H: velActual.impresionCm3H, sugerido: false, origen: 'tiempo_real');
    de = '${velActual.corteMMin.toStringAsFixed(2)} m/min'; a = '${n.toStringAsFixed(2)} m/min';
  } else if (velActual.remocionCm3Min > 0) {
    final n = velocidadPonderada(velActual.remocionCm3Min, muestras, velActual.remocionCm3Min / factorMaq);
    nueva = Velocidad2(corteMMin: 0, grabadoCm2Min: velActual.grabadoCm2Min, remocionCm3Min: n, impresionCm3H: 0, sugerido: false, origen: 'tiempo_real');
    de = '${velActual.remocionCm3Min.toStringAsFixed(1)} cm³/min'; a = '${n.toStringAsFixed(1)} cm³/min';
  } else if (velActual.impresionCm3H > 0) {
    final n = velocidadPonderada(velActual.impresionCm3H, muestras, velActual.impresionCm3H / factorMaq);
    nueva = Velocidad2(impresionCm3H: n, sugerido: false, origen: 'tiempo_real');
    de = '${velActual.impresionCm3H.toStringAsFixed(0)} cm³/h'; a = '${n.toStringAsFixed(0)} cm³/h';
  } else {
    return;
  }
  if (!context.mounted) return;
  final masLento = factor > 1;
  final ok = await showModalBottomSheet<bool>(context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(masLento ? Icons.trending_down : Icons.trending_up, color: masLento ? AppColors.naranja : AppColors.verde),
        const SizedBox(width: 8),
        Expanded(child: Text(trf('{0} tardó {1} % {2} de lo cotizado', [folio, ((factor - 1).abs() * 100).round(), masLento ? tr('más') : tr('menos')]), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 8),
      Text(trf('Estimado: {0} min · Real: {1} min', [estimado.round(), real.round()]), style: const TextStyle(fontSize: 13)),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(10)),
        child: Text(trf('{0} en {1}: {2} → {3}', [mat.nombre, maq.nombre, de, a]), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.azul))),
      const SizedBox(height: 6),
      Text(muestras > 0
          ? trf('Se promedia con los {0} pedidos anteriores. Las próximas cotizaciones de este material saldrán con esta velocidad.', [muestras])
          : tr('Las próximas cotizaciones de este material saldrán con esta velocidad.'),
        style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario)),
      const SizedBox(height: 14),
      Row(children: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('No, fue algo de este pedido'))),
        const Spacer(),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul),
          child: Text(tr('Actualizar velocidad'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ]),
    ])));
  if (ok != true) return;
  try {
    await Simulador2Data.guardarVelocidad(maq: maq, mat: mat, vel: nueva, origen: 'tiempo_real', muestras: muestras + 1);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Velocidad actualizada. El simulador ya la usa.')), backgroundColor: AppColors.verde));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trf('No se pudo guardar: {0}', [e])), backgroundColor: AppColors.rojo));
  }
}

/// Anota en pedido_costos las horas de máquina y de operador del pedido, una
/// sola vez (si ya hay una línea de esa máquina, no se duplica). Las horas se
/// reparten entre las máquinas según lo estimado en la cotización.
Future<void> _registrarCostos({required String pedidoId, required String folio, required List<_Partida> partidas,
    required List<Maquina2> maquinas, required double minutosTotales, required double estimadoTotal, required bool esEstimado,
    required BuildContext context}) async {
  try {
    final existentes = await CostosService.costosPedido(pedidoId);
    final yaMaq = existentes.where((c) => c['tipo'] == 'maquina').map((c) => c['maquina_id']?.toString()).toSet();
    final yaOp = existentes.any((c) => c['tipo'] == 'mano_obra');
    // minutos estimados por máquina
    final porMaq = <String, double>{};
    for (final p in partidas) { porMaq[p.maquinaId] = (porMaq[p.maquinaId] ?? 0) + p.tiempoMin * p.cantidad; }
    final sumaMaq = porMaq.values.fold(0.0, (s, v) => s + v);
    if (sumaMaq <= 0) return;
    final factor = minutosTotales / estimadoTotal; // real ÷ estimado (1 si es estimado)
    final etiqueta = esEstimado ? 'estimadas' : 'reales (QR)';
    double horasTotal = 0;
    for (final e in porMaq.entries) {
      final m = maquinas.cast<Maquina2?>().firstWhere((x) => x!.id == e.key, orElse: () => null);
      if (m == null) continue;
      // la preparación se reparte proporcional
      final min = (e.value + (estimadoTotal - sumaMaq) * e.value / sumaMaq) * factor;
      final horas = double.parse((min / 60).toStringAsFixed(2));
      horasTotal += horas;
      if (yaMaq.contains(m.id) || horas <= 0) continue;
      await CostosService.agregarCosto(pedidoId: pedidoId, folio: folio, tipo: 'maquina',
        concepto: 'Horas $etiqueta · ${m.nombre}', cantidad: horas, costoUnitario: m.costoHora, maquinaId: m.id);
    }
    if (!yaOp && horasTotal > 0) {
      final t = await Simulador2Data.taller();
      if (t.costoHoraOperador > 0) {
        await CostosService.agregarCosto(pedidoId: pedidoId, folio: folio, tipo: 'mano_obra',
          concepto: 'Operador · horas $etiqueta', cantidad: horasTotal, costoUnitario: t.costoHoraOperador);
      }
    }
    if (context.mounted && !yaMaq.contains(partidas.first.maquinaId)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(trf('Costo real anotado: {0} h de máquina ({1}). Se ve en Reportes → Rentabilidad y en Mantenimiento.', [horasTotal.toStringAsFixed(1), esEstimado ? tr('estimadas') : tr('reales')])),
        backgroundColor: AppColors.azul));
    }
  } catch (_) {}
}
