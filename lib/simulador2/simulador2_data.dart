// lib/simulador2/simulador2_data.dart
// HETNA CNC — Datos del Simulador 2.0: máquinas, materiales (del inventario),
// costos del taller, velocidades por máquina/material, acabados e historial.
// Si la base todavía no tiene las columnas de simulador2.sql, todo sigue
// funcionando con valores por defecto (nunca truena por una columna que falta).
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/archivo_cad_service.dart';
import '../services/auth_service.dart';
import '../services/costos_service.dart';
import 'motor.dart';
import 'velocidades_hetna.dart';
import 'recetas.dart';
import '../services/pais.dart';

/// Lo que regresa el simulador a la cotización.
class Partida2 {
  final String emoji, servicio, descripcion;
  final int cantidad;
  final double precioUnitario, total, costoTotal, tiempoMin, tiempoHoras;
  final String? materialId, maquinaId, tipoMaterial;
  final double materialUnidades, espesorMm;
  // La pieza leída del archivo y su dibujo (PNG) para la cotización en PDF
  final GeoCad? geo;
  final Uint8List? imagenPng;
  final String medidas;
  const Partida2({required this.emoji, required this.servicio, required this.descripcion, required this.cantidad,
    required this.precioUnitario, required this.total, required this.costoTotal, required this.tiempoMin,
    this.materialId, this.maquinaId, this.tipoMaterial, this.materialUnidades = 0, this.espesorMm = 0, this.geo, this.imagenPng, this.medidas = ''})
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

  // Datos para las recetas (potencia, RPM, avance máx.) por máquina
  static final Map<String, MaquinaReceta> _datosReceta = {};
  static MaquinaReceta datosReceta(Maquina2 m) => _datosReceta[m.id] ?? MaquinaReceta(tipo: m.tipo);

  // La Fase 4 (mantenimiento) guardó el tipo en `tipo_maquina` (router, laser,
  // plasma, fibra, impresora3d, otra); el simulador usa `tipo`. Se leen los dos
  // y se escriben los dos para que mantenimiento y simulador coincidan.
  static const _deFase4 = {'laser': 'laser_co2', 'fibra': 'laser_fibra', 'impresora3d': 'impresora_3d', 'otra': 'otro', 'router': 'router', 'plasma': 'plasma'};
  static const aFase4 = {'laser_co2': 'laser', 'laser_fibra': 'fibra', 'impresora_3d': 'impresora3d', 'otro': 'otra', 'router': 'router', 'router_3d': 'router', 'plasma': 'plasma', 'torno': 'otra'};

  static Maquina2 maquinaDeFila(Map<String, dynamic> m) {
    String tipo = (m['tipo'] ?? '').toString();
    if (tipo.isEmpty || (tipo == 'router' && m['tipo_maquina'] != null && m['tipo_maquina'] != 'router')) {
      tipo = _deFase4[(m['tipo_maquina'] ?? 'router').toString()] ?? 'router';
    }
    _datosReceta[m['id'] as String] = MaquinaReceta(tipo: tipo, potencia: _d(m['potencia']), rpmMax: _d(m['rpm_max']), rpmMin: _d(m['rpm_min']), avanceMax: _d(m['avance_max']));
    return Maquina2(
      id: m['id'] as String, nombre: (m['nombre'] ?? 'Máquina').toString(), tipo: tipo,
      emoji: (m['emoji'] ?? emojiTipoMaquina[tipo] ?? '⚙️').toString(),
      costoHora: costoHoraDeFila(m),
      preparacionMin: _d(m['preparacion_min'], 15), perforacionSeg: _d(m['perforacion_seg'], 2),
      mesaLargo: _d(m['mesa_largo_mm']), mesaAncho: _d(m['mesa_ancho_mm']), mesaAlto: _d(m['mesa_alto_mm']),
      remocionCm3Min: _d(m['remocion_cm3_min']), impresionCm3H: _d(m['impresion_cm3_h']));
  }

  static Future<void> guardarMaquina(String id, Map<String, dynamic> datos) async {
    if (datos['tipo'] != null) datos = {...datos, 'tipo_maquina': aFase4[datos['tipo']] ?? 'otra'};
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

  /// Materiales de referencia HETNA (precio típico en México, convertido a la
  /// moneda del taller) para cuando no tiene en su inventario material de ese
  /// tipo de máquina.
  static List<Material2> materialesReferencia(String tipoMaquina) {
    // tabla = tablón de madera sólida de 8 pies × 12" (2440 × 300 mm)
    const hoja = [1220.0, 2440.0], acr = [1220.0, 1830.0], tabla = [2440.0, 300.0];
    Material2 h(String tipo, String nombre, double esp, double precio, [List<double> dim = hoja]) => Material2(
      id: 'ref_${tipo}_${esp.toStringAsFixed(1)}', nombre: '$nombre (referencia)', tipo: tipo, espesorMm: esp, precio: Pais.refMaterial(precio),
      unidad: 'hoja', hojaLargo: dim[0], hojaAncho: dim[1], mermaPct: 15, densidad: tipoMaterialPorClave(tipo)?.densidad ?? 0);
    Material2 kg(String tipo, String nombre, double esp, double precio) => Material2(
      id: 'ref_${tipo}_${esp.toStringAsFixed(1)}', nombre: '$nombre (referencia)', tipo: tipo, espesorMm: esp, precio: Pais.refMaterial(precio),
      unidad: 'kg', mermaPct: 15, densidad: tipoMaterialPorClave(tipo)?.densidad ?? 1);
    final tablas = [
      h('mdf', 'MDF 3 mm', 3, 190), h('mdf', 'MDF 6 mm', 6, 270), h('mdf', 'MDF 9 mm', 9, 340), h('mdf', 'MDF 12 mm', 12, 430), h('mdf', 'MDF 15 mm', 15, 530), h('mdf', 'MDF 18 mm', 18, 620),
      h('triplay', 'Triplay 6 mm', 6, 420), h('triplay', 'Triplay 12 mm', 12, 700), h('triplay', 'Triplay 18 mm', 18, 980),
      h('melamina', 'Melamina 16 mm', 16, 760, [1830, 2440]),
      // Madera sólida: se vende en tablas, no en hojas; precio por tabla de 2440 × 300 mm
      h('madera', 'Pino tabla 12 mm', 12, 230, tabla), h('madera', 'Pino tabla 19 mm (3/4")', 19, 330, tabla), h('madera', 'Pino tabla 25 mm (1")', 25, 430, tabla),
      h('madera', 'Cedro tabla 19 mm', 19, 1100, tabla), h('madera', 'Encino tabla 19 mm', 19, 950, tabla), h('madera', 'Parota tabla 25 mm', 25, 1250, tabla),
      h('madera', 'Triplay de pino 3 mm (laser)', 3, 260),
      h('acrilico', 'Acrílico 3 mm', 3, 1150, acr), h('acrilico', 'Acrílico 6 mm', 6, 2200, acr), h('acrilico', 'Acrílico 10 mm', 10, 3600, acr),
      h('pvc', 'PVC espumado 3 mm', 3, 720), h('pvc', 'PVC espumado 6 mm', 6, 1250),
      h('policarbonato', 'Policarbonato 3 mm', 3, 1400, acr), h('policarbonato', 'Policarbonato 6 mm', 6, 2600, acr),
      h('hdpe', 'HDPE / Celorón 12 mm', 12, 2900),
      h('espuma', 'Espuma alta densidad 50 mm', 50, 900),
      h('carton', 'Cartón 3 mm', 3, 60, [1000, 700]), h('cuero', 'Piel 2 mm', 2, 900, [1500, 1000]),
    ];
    final metales = [
      kg('acero', 'Acero cal. 14 (1.9 mm)', 1.9, 34), kg('acero', 'Acero 3 mm (1/8")', 3.2, 34), kg('acero', 'Acero 6 mm (1/4")', 6.4, 34), kg('acero', 'Acero 10 mm (3/8")', 9.5, 34), kg('acero', 'Acero 12 mm (1/2")', 12.7, 34),
      kg('inox', 'Inoxidable 1.5 mm', 1.5, 110), kg('inox', 'Inoxidable 3 mm', 3, 110), kg('inox', 'Inoxidable 6 mm', 6, 110),
      kg('aluminio', 'Aluminio 3 mm', 3, 95), kg('aluminio', 'Aluminio 6 mm', 6, 95),
    ];
    final filamentos = [kg('pla', 'PLA', 0, 450), kg('petg', 'PETG', 0, 520), kg('abs', 'ABS / ASA', 0, 520), kg('tpu', 'TPU flexible', 0, 750), kg('resina', 'Resina', 0, 950)];
    switch (tipoMaquina) {
      case 'impresora_3d': return filamentos;
      case 'plasma': case 'laser_fibra': return metales;
      case 'torno': return [...metales, h('hdpe', 'Nylon / HDPE barra', 0, 400)];
      // PVC suelta cloro; policarbonato y HDPE se funden y amarillean con CO₂
      case 'laser_co2': return tablas.where((m) => !const {'pvc', 'melamina', 'policarbonato', 'hdpe'}.contains(m.tipo) && m.espesorMm <= 12).toList();
      case 'router_3d': return tablas.where((m) => m.espesorMm >= 12).toList();
      default: return [...tablas.where((m) => m.tipo != 'carton' && m.tipo != 'cuero'), kg('aluminio', 'Aluminio 3 mm', 3, 95)];
    }
  }

  static bool esReferenciaMaterial(Material2 m) => (m.id ?? '').startsWith('ref_');

  /// Agrega un material de referencia al inventario del taller (para que lo
  /// ajuste a su precio real).
  static Future<String?> agregarMaterialAlInventario(Material2 m) async {
    try {
      final res = await _sb.from('inventario_bodega').insert({
        'negocio_id': _neg, 'nombre': m.nombre.replaceAll(' (referencia)', ''), 'tipo_material': m.tipo, 'espesor_mm': m.espesorMm > 0 ? m.espesorMm : null,
        'costo_unitario': m.precio, 'unidad': m.unidad == 'hoja' ? 'hojas' : m.unidad, 'largo_mm': m.hojaLargo > 0 ? m.hojaLargo : null, 'ancho_mm': m.hojaAncho > 0 ? m.hojaAncho : null,
        'stock_actual': 0, 'stock_minimo': 0, 'activo': true, 'categoria': 'Material',
      }).select('id').single();
      return res['id'] as String?;
    } catch (_) { return null; }
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

  // ── Recetas del taller ──
  static List<Map<String, dynamic>>? _recCache;
  static Future<void> cargarRecetas() async {
    try {
      final rows = await _sb.from('sim2_recetas').select().eq('negocio_id', _neg);
      _recCache = (rows as List).cast<Map<String, dynamic>>();
    } catch (_) { _recCache = []; }
  }

  static Map<String, double> ajustesReceta(Maquina2 maq, Material2 mat, String operacion) {
    for (final r in _recCache ?? const <Map<String, dynamic>>[]) {
      if (r['maquina_id'] == maq.id && r['tipo_material'] == mat.tipo && (_d(r['espesor_mm']) - mat.espesorMm).abs() < 0.26 && r['operacion'] == operacion) {
        final a = r['ajustes'];
        if (a is Map) return a.map((k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0));
      }
    }
    return const {};
  }

  static Future<void> guardarReceta({required Maquina2 maq, required Material2 mat, required String operacion,
      required Map<String, double> ajustes, String? nota}) async {
    await _sb.from('sim2_recetas').upsert({
      'negocio_id': _neg, 'maquina_id': maq.id, 'tipo_material': mat.tipo, 'espesor_mm': mat.espesorMm,
      'operacion': operacion, 'ajustes': ajustes, 'nota': nota, 'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'negocio_id,maquina_id,tipo_material,espesor_mm,operacion');
    await cargarRecetas();
  }

  static Future<void> borrarReceta(Maquina2 maq, Material2 mat, String operacion) async {
    await _sb.from('sim2_recetas').delete().eq('negocio_id', _neg).eq('maquina_id', maq.id)
      .eq('tipo_material', mat.tipo).eq('espesor_mm', mat.espesorMm).eq('operacion', operacion);
    await cargarRecetas();
  }

  /// La receta del trabajo (HETNA + los ajustes guardados del taller).
  static Receta receta(Maquina2 maq, Material2 mat, String servicio, {double rellenoPct = 20}) {
    final op = operacionDe(maq.tipo, servicio);
    final ajustes = maq.id.startsWith('ref_') ? const <String, double>{} : ajustesReceta(maq, mat, op);
    return recetaPara(tipoMaquina: maq.tipo, servicio: servicio, material: mat.tipo, espesor: mat.espesorMm,
      maq: datosReceta(maq), ajustes: ajustes, rellenoPct: rellenoPct);
  }

  static String operacionDe(String tipoMaquina, String servicio) {
    switch (tipoMaquina) {
      case 'laser_co2': return servicio == 'grabado' ? 'laser_grabado' : 'laser_corte';
      case 'plasma': return 'plasma';
      case 'laser_fibra': return 'fibra';
      case 'impresora_3d': return 'impresion';
      case 'torno': return 'relieve';
      default: return servicio == 'relieve3D' ? 'relieve' : servicio == 'grabado' ? 'grabado_v' : 'perfil';
    }
  }

  /// Velocidad2 que sale de la receta (para el motor de precio).
  static Velocidad2 velocidadDeReceta(Receta r, {required bool tallerLaEdito}) => Velocidad2(
    corteMMin: r.corteMMin, grabadoCm2Min: r.grabadoCm2Min, remocionCm3Min: r.remocionCm3Min,
    acabadoCm2Min: r.acabadoCm2Min, impresionCm3H: r.impresionCm3H,
    sugerido: !tallerLaEdito, origen: tallerLaEdito ? 'receta' : 'hetna');

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
      required Material2 mat, String? clienteId, String? clienteNombre, Map<String, double>? ajustes, String? acabados}) async {
    try {
      await _sb.from('sim2_historial').insert({
        'negocio_id': _neg, 'cliente_id': clienteId, 'cliente_nombre': clienteNombre,
        'archivo': pieza.nombre, 'servicio': r.servicio.name, 'maquina_id': maq.id.startsWith('ref_') ? null : maq.id,
        'maquina_nombre': maq.nombre, 'ajustes': ajustes, 'acabados': acabados,
        'tipo_material': mat.tipo, 'espesor_mm': mat.espesorMm,
        'largo_mm': pieza.largo, 'ancho_mm': pieza.ancho, 'alto_mm': pieza.alto,
        'metros_corte': pieza.metrosCorte, 'volumen_cm3': pieza.volumenCm3,
        'cantidad': r.cantidad, 'tiempo_min': r.tiempoMaquinaMinPieza,
        'costo_pieza': r.costoTotal / r.cantidad, 'precio_pieza': r.precioPieza, 'margen_pct': r.margenPct,
      });
    } catch (_) {}
  }

  /// "Ya lo hiciste antes": primero el mismo archivo (por nombre), luego mismo
  /// material/espesor con medidas ±20 %. Cada fila trae `igual` = true si es
  /// el mismo archivo.
  static Future<List<Map<String, dynamic>>> parecidos(Pieza2 pieza, Material2 mat) async {
    try {
      final out = <Map<String, dynamic>>[];
      final vistos = <String>{};
      final nombre = pieza.nombre.trim();
      if (nombre.isNotEmpty && !nombre.startsWith('Pieza ')) {
        final mismos = await _sb.from('sim2_historial').select().eq('negocio_id', _neg).eq('archivo', nombre)
          .order('created_at', ascending: false).limit(5);
        for (final h in (mismos as List).cast<Map<String, dynamic>>()) {
          if (vistos.add(h['id'].toString())) out.add({...h, 'igual': true});
        }
      }
      final rows = await _sb.from('sim2_historial').select()
        .eq('negocio_id', _neg).eq('tipo_material', mat.tipo)
        .gte('largo_mm', pieza.largo * 0.8).lte('largo_mm', pieza.largo * 1.2)
        .gte('ancho_mm', pieza.ancho * 0.8).lte('ancho_mm', pieza.ancho * 1.2)
        .order('created_at', ascending: false).limit(8);
      for (final h in (rows as List).cast<Map<String, dynamic>>()) {
        if ((_d(h['espesor_mm']) - mat.espesorMm).abs() >= 0.6) continue;
        if (vistos.add(h['id'].toString())) out.add({...h, 'igual': false});
      }
      return out.take(6).toList();
    } catch (_) { return []; }
  }

  /// Liga el último registro del historial con la cotización guardada (para
  /// saber a quién se le cotizó).
  static Future<void> ligarHistorial({required String archivo, required String cotizacionId, String? clienteNombre}) async {
    try {
      final r = await _sb.from('sim2_historial').select('id').eq('negocio_id', _neg).eq('archivo', archivo)
        .is_('cotizacion_id', null).order('created_at', ascending: false).limit(1);
      if ((r as List).isEmpty) return;
      await _sb.from('sim2_historial').update({'cotizacion_id': cotizacionId, if (clienteNombre != null) 'cliente_nombre': clienteNombre}).eq('id', r.first['id']);
    } catch (_) {}
  }
}
