// lib/simulador2/simulador2_data.dart
// HETNA CNC — Datos del Simulador 2.0: máquinas, materiales (del inventario),
// costos del taller, velocidades por máquina/material, acabados e historial.
// Si la base todavía no tiene las columnas de simulador2.sql, todo sigue
// funcionando con valores por defecto (nunca truena por una columna que falta).
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/costos_service.dart';
import 'motor.dart';
import 'velocidades_hetna.dart';

/// Lo que regresa el simulador a la cotización.
class Partida2 {
  final String emoji, servicio, descripcion;
  final int cantidad;
  final double precioUnitario, total, costoTotal, tiempoMin, tiempoHoras;
  final String? materialId, maquinaId, tipoMaterial;
  final double materialUnidades, espesorMm;
  const Partida2({required this.emoji, required this.servicio, required this.descripcion, required this.cantidad,
    required this.precioUnitario, required this.total, required this.costoTotal, required this.tiempoMin,
    this.materialId, this.maquinaId, this.tipoMaterial, this.materialUnidades = 0, this.espesorMm = 0})
    : tiempoHoras = tiempoMin / 60;
}

class Simulador2Data {
  static final _sb = Supabase.instance.client;
  static String? get _neg => AuthService.negocioId;

  static double _d(dynamic v, [double def = 0]) => (v as num?)?.toDouble() ?? def;

  // ── Máquinas ──
  static Future<List<Maquina2>> maquinas() async {
    try {
      final rows = await _sb.from('maquinaria').select().eq('negocio_id', _neg).eq('activo', true).order('nombre');
      return (rows as List).cast<Map<String, dynamic>>().map(maquinaDeFila).toList();
    } catch (_) { return []; }
  }

  static double costoHoraDeFila(Map<String, dynamic> m) {
    final manual = _d(m['costo_hora_manual']);
    if (manual > 0) return manual;
    return CostosService.costoHoraMaquina(m); // misma fórmula que Costos del taller
  }

  static Maquina2 maquinaDeFila(Map<String, dynamic> m) {
    final tipo = (m['tipo'] ?? 'router').toString();
    return Maquina2(
      id: m['id'] as String, nombre: (m['nombre'] ?? 'Máquina').toString(), tipo: tipo,
      emoji: (m['emoji'] ?? emojiTipoMaquina[tipo] ?? '⚙️').toString(),
      costoHora: costoHoraDeFila(m),
      preparacionMin: _d(m['preparacion_min'], 15), perforacionSeg: _d(m['perforacion_seg'], 2),
      mesaLargo: _d(m['mesa_largo_mm']), mesaAncho: _d(m['mesa_ancho_mm']), mesaAlto: _d(m['mesa_alto_mm']),
      remocionCm3Min: _d(m['remocion_cm3_min']), impresionCm3H: _d(m['impresion_cm3_h']));
  }

  static Future<void> guardarMaquina(String id, Map<String, dynamic> datos) async {
    await _sb.from('maquinaria').update(datos).eq('id', id);
  }

  // ── Taller ──
  static Future<Taller2> taller() async {
    try {
      final cfg = await _sb.from('empresa_config').select().eq('negocio_id', _neg).maybeSingle();
      if (cfg == null) return const Taller2();
      double op = 0;
      try {
        final ops = await _sb.from('mano_obra').select().eq('negocio_id', _neg).eq('activo', true);
        final l = (ops as List).cast<Map<String, dynamic>>();
        if (l.isNotEmpty) op = l.map(CostosService.costoHoraOperador).reduce((a, b) => a + b) / l.length;
      } catch (_) {}
      return Taller2(
        costoHoraOperador: op,
        gastosFijosHora: CostosService.costoHoraTaller(cfg),
        margenPct: _d(cfg['margen_recomendado'], 35), margenMinPct: _d(cfg['margen_minimo'], 20),
        ivaPct: _d(cfg['iva_pct'], 16), markupMaterialPct: _d(cfg['markup_material_pct'], 20),
        manejoMinPieza: _d(cfg['manejo_min_pieza'], 1),
        mercadoM2: _d(cfg['mercado_m2']), mercadoHora: _d(cfg['mercado_hora']), mercadoCm3: _d(cfg['mercado_cm3']));
    } catch (_) { return const Taller2(); }
  }

  static Future<void> guardarTaller(Map<String, dynamic> datos) async {
    final rows = await _sb.from('empresa_config').select('id').eq('negocio_id', _neg).limit(1);
    if ((rows as List).isEmpty) {
      await _sb.from('empresa_config').insert({'negocio_id': _neg, ...datos});
    } else {
      await _sb.from('empresa_config').update(datos).eq('id', rows.first['id']);
    }
  }

  // ── Materiales (inventario) ──
  static Future<List<Material2>> materiales({double mermaDefault = 15}) async {
    try {
      final rows = await _sb.from('inventario_bodega').select().eq('activo', true).order('nombre');
      final l = (rows as List).cast<Map<String, dynamic>>().map((m) => materialDeFila(m, mermaDefault)).toList();
      // Retazos primero: lo que ya se pagó se usa antes que una hoja nueva
      l.sort((a, b) {
        if (a.esRetazo != b.esRetazo) return a.esRetazo ? -1 : 1;
        return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });
      return l;
    } catch (_) { return []; }
  }

  static Material2 materialDeFila(Map<String, dynamic> m, double mermaDefault) {
    final nombre = (m['nombre'] ?? '').toString();
    final tipo = (m['tipo_material'] as String?) ?? adivinarTipoMaterial(nombre) ?? 'mdf';
    final esp = _d(m['espesor_mm']);
    final unidadRaw = (m['unidad'] ?? 'pzas').toString().toLowerCase();
    final unidad = unidadRaw.startsWith('kg') ? 'kg' : unidadRaw.startsWith('g') ? 'g' : unidadRaw.startsWith('m') && !unidadRaw.startsWith('mm') ? 'm' : 'hoja';
    final tm = tipoMaterialPorClave(tipo);
    return Material2(
      id: m['id'] as String?, nombre: nombre, tipo: tipo,
      espesorMm: esp > 0 ? esp : adivinarEspesor(nombre),
      precio: _d(m['costo_unitario']), unidad: unidad,
      hojaLargo: _d(m['largo_mm']), hojaAncho: _d(m['ancho_mm']),
      mermaPct: m['merma_pct'] != null ? _d(m['merma_pct']) : mermaDefault,
      densidad: m['densidad_g_cm3'] != null ? _d(m['densidad_g_cm3']) : (tm?.densidad ?? 0),
      esRetazo: m['es_retazo'] == true, stock: _d(m['stock_actual']));
  }

  /// Completa en el inventario lo que el simulador necesita (tipo, espesor,
  /// medida de hoja). Se ignora si la base no tiene esas columnas.
  static Future<void> completarMaterial(String id, Map<String, dynamic> datos) async {
    try { await _sb.from('inventario_bodega').update(datos).eq('id', id); } catch (_) {}
  }

  // ── Velocidades ──
  static List<Map<String, dynamic>>? _velCache;

  static Future<void> cargarVelocidades() async {
    try {
      final rows = await _sb.from('sim2_velocidades').select().eq('negocio_id', _neg);
      _velCache = (rows as List).cast<Map<String, dynamic>>();
    } catch (_) { _velCache = []; }
  }

  /// La velocidad de ESTA máquina con ESTE material: primero la del taller
  /// (sim2_velocidades), si no, la sugerida por HETNA.
  static Velocidad2 velocidad(Maquina2 maq, Material2 mat) {
    final esp = mat.espesorMm;
    Map<String, dynamic>? fila;
    for (final v in _velCache ?? const <Map<String, dynamic>>[]) {
      if (v['maquina_id'] == maq.id && v['tipo_material'] == mat.tipo && (_d(v['espesor_mm']) - esp).abs() < 0.26) { fila = v; break; }
    }
    if (fila != null) {
      return Velocidad2(
        corteMMin: _d(fila['velocidad_corte_m_min']), grabadoCm2Min: _d(fila['velocidad_grabado_cm2_min']),
        remocionCm3Min: _d(fila['remocion_cm3_min']), impresionCm3H: _d(fila['impresion_cm3_h']),
        sugerido: fila['sugerido'] == true, origen: (fila['origen'] ?? 'taller').toString());
    }
    final tipoVel = maq.tipo == 'router_3d' ? 'router' : maq.tipo;
    final corte = velocidadCorteSugerida(tipoVel, mat.tipo, esp);
    final grab = velocidadGrabadoSugerida(tipoVel, mat.tipo);
    final rem = remocionSugerida(maq.tipo, mat.tipo);
    final imp = maq.tipo == 'impresora_3d' ? impresionSugerida(mat.tipo) : 0.0;
    final hay = corte > 0 || grab > 0 || rem > 0 || imp > 0;
    return Velocidad2(corteMMin: corte, grabadoCm2Min: grab, remocionCm3Min: rem, impresionCm3H: imp,
      sugerido: true, origen: hay ? 'hetna' : 'ninguno');
  }

  static int muestras(Maquina2 maq, Material2 mat) {
    for (final v in _velCache ?? const <Map<String, dynamic>>[]) {
      if (v['maquina_id'] == maq.id && v['tipo_material'] == mat.tipo && (_d(v['espesor_mm']) - mat.espesorMm).abs() < 0.26) {
        return (v['muestras'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  /// Guarda/actualiza la velocidad del taller para máquina + material + espesor.
  static Future<void> guardarVelocidad({required Maquina2 maq, required Material2 mat, required Velocidad2 vel,
      String origen = 'taller', int? muestras}) async {
    final datos = {
      'negocio_id': _neg, 'maquina_id': maq.id, 'tipo_material': mat.tipo, 'espesor_mm': mat.espesorMm,
      'velocidad_corte_m_min': vel.corteMMin > 0 ? vel.corteMMin : null,
      'velocidad_grabado_cm2_min': vel.grabadoCm2Min > 0 ? vel.grabadoCm2Min : null,
      'remocion_cm3_min': vel.remocionCm3Min > 0 ? vel.remocionCm3Min : null,
      'impresion_cm3_h': vel.impresionCm3H > 0 ? vel.impresionCm3H : null,
      'sugerido': false, 'origen': origen, 'updated_at': DateTime.now().toIso8601String(),
      if (muestras != null) 'muestras': muestras,
    };
    await _sb.from('sim2_velocidades').upsert(datos, onConflict: 'negocio_id,maquina_id,tipo_material,espesor_mm');
    await cargarVelocidades();
  }

  // ── Acabados ──
  static Future<List<Acabado2>> acabados() async {
    try {
      final rows = await _sb.from('sim2_acabados').select().eq('negocio_id', _neg).eq('activo', true).order('orden');
      return (rows as List).cast<Map<String, dynamic>>().map((a) => Acabado2(
        id: a['id'] as String, nombre: (a['nombre'] ?? '').toString(),
        precioPieza: _d(a['precio_pieza']), precioM2: _d(a['precio_m2']), minutosPieza: _d(a['minutos_pieza']))).toList();
    } catch (_) { return []; }
  }

  static Future<void> guardarAcabado({String? id, required String nombre, required double precioPieza,
      required double precioM2, required double minutosPieza}) async {
    final datos = {'negocio_id': _neg, 'nombre': nombre, 'precio_pieza': precioPieza, 'precio_m2': precioM2, 'minutos_pieza': minutosPieza};
    if (id == null) { await _sb.from('sim2_acabados').insert(datos); }
    else { await _sb.from('sim2_acabados').update(datos).eq('id', id); }
  }

  static Future<void> borrarAcabado(String id) async {
    await _sb.from('sim2_acabados').update({'activo': false}).eq('id', id);
  }

  // ── Historial ──
  static Future<void> guardarHistorial({required Resultado2 r, required Pieza2 pieza, required Maquina2 maq,
      required Material2 mat, String? clienteId, String? clienteNombre}) async {
    try {
      await _sb.from('sim2_historial').insert({
        'negocio_id': _neg, 'cliente_id': clienteId, 'cliente_nombre': clienteNombre,
        'archivo': pieza.nombre, 'servicio': r.servicio.name, 'maquina_id': maq.id.startsWith('ref_') ? null : maq.id,
        'tipo_material': mat.tipo, 'espesor_mm': mat.espesorMm,
        'largo_mm': pieza.largo, 'ancho_mm': pieza.ancho, 'alto_mm': pieza.alto,
        'metros_corte': pieza.metrosCorte, 'volumen_cm3': pieza.volumenCm3,
        'cantidad': r.cantidad, 'tiempo_min': r.tiempoMaquinaMinPieza,
        'costo_pieza': r.costoTotal / r.cantidad, 'precio_pieza': r.precioPieza, 'margen_pct': r.margenPct,
      });
    } catch (_) {}
  }

  /// "Ya cotizaste algo parecido": mismo material/espesor y medidas ±20 %.
  static Future<List<Map<String, dynamic>>> parecidos(Pieza2 pieza, Material2 mat) async {
    try {
      final rows = await _sb.from('sim2_historial').select()
        .eq('negocio_id', _neg).eq('tipo_material', mat.tipo)
        .gte('largo_mm', pieza.largo * 0.8).lte('largo_mm', pieza.largo * 1.2)
        .gte('ancho_mm', pieza.ancho * 0.8).lte('ancho_mm', pieza.ancho * 1.2)
        .order('created_at', ascending: false).limit(5);
      return (rows as List).cast<Map<String, dynamic>>()
        .where((h) => (_d(h['espesor_mm']) - mat.espesorMm).abs() < 0.6).toList();
    } catch (_) { return []; }
  }
}
