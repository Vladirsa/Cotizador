// lib/screens/simulador_screen.dart
// HETNA CNC — Simulador v5 completo con motor de costos real
// Fórmula: PV = (CM + CMO + CMaq + CC + CA + CI) ÷ (1 - Margen)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'cotizar_screen.dart';

const _negId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

// ══════════════════════════════════════════════════════
// MODELOS
// ══════════════════════════════════════════════════════
class SimServicio {
  final String id, nombre, emoji;
  final String? descripcion;
  final bool activo;
  final int orden;
  SimServicio({required this.id, required this.nombre, required this.emoji,
    this.descripcion, this.activo = true, this.orden = 0});
  factory SimServicio.fromJson(Map<String, dynamic> j) => SimServicio(
    id: j['id'], nombre: j['nombre'], emoji: j['emoji'] ?? '🔧',
    descripcion: j['descripcion'], activo: j['activo'] ?? true,
    orden: j['orden'] ?? 0);
}

class SimTipoTrabajo {
  final String id, nombre;
  final String formula;
  final double factor;
  final bool necesitaLargo, necesitaAncho, necesitaAlto;
  final bool necesitaPeso, necesitaMetros, necesitaHoras, necesitaMinutos;
  final String? descripcionFormula;

  SimTipoTrabajo({required this.id, required this.nombre,
    this.formula = 'por_area', this.factor = 1.0,
    this.necesitaLargo = true, this.necesitaAncho = true,
    this.necesitaAlto = false, this.necesitaPeso = false,
    this.necesitaMetros = false, this.necesitaHoras = false,
    this.necesitaMinutos = false, this.descripcionFormula});

  factory SimTipoTrabajo.fromJson(Map<String, dynamic> j) {
    final nombre = (j['nombre'] as String? ?? '').toLowerCase();
    String formula = j['formula'] as String? ?? _inferirFormula(nombre);
    return SimTipoTrabajo(
      id: j['id'], nombre: j['nombre'],
      formula: formula,
      factor: (j['factor_complejidad'] as num? ?? j['factor'] as num?)?.toDouble() ?? 1.0,
      necesitaLargo: j['necesita_largo'] ?? _nLargo(formula),
      necesitaAncho: j['necesita_ancho'] ?? _nAncho(formula),
      necesitaAlto: j['necesita_alto'] ?? _nAlto(formula, nombre),
      necesitaPeso: j['necesita_peso'] ?? (formula == 'por_kg'),
      necesitaMetros: j['necesita_metros'] ?? (formula == 'por_metro'),
      necesitaHoras: j['necesita_horas'] ?? (formula == 'por_hora'),
      necesitaMinutos: j['necesita_minutos'] ?? (formula == 'por_minuto'),
      descripcionFormula: j['descripcion_formula'] ?? _descFormula(formula));
  }

  static String _inferirFormula(String n) {
    if (n.contains('diseño') || n.contains('diseno') || n.contains('vectori') || n.contains('model')) return 'por_diseno';
    if (n.contains('impresion') || n.contains('impresión') || n.contains('3d print') || n.contains('fdm')) return 'por_hora';
    if (n.contains('grabado') || n.contains('laser') || n.contains('láser') || n.contains('fibra')) return 'por_minuto';
    if (n.contains('metro') || n.contains('lineal') || n.contains('herrer') || n.contains('carpint')) return 'por_metro';
    if (n.contains('pieza') || n.contains('pza') || n.contains('promo')) return 'por_pieza';
    if (n.contains('3d') || n.contains('relieve') || n.contains('talla') || n.contains('escultura') || n.contains('rotativo')) return 'por_volumen';
    return 'por_area';
  }
  static bool _nLargo(String f) => f != 'por_diseno' && f != 'precio_fijo' && f != 'por_pieza';
  static bool _nAncho(String f) => f == 'por_area' || f == 'por_volumen';
  static bool _nAlto(String f, String n) => f == 'por_volumen' || n.contains('3d') || n.contains('relieve') || n.contains('escultura');
  static String _descFormula(String f) {
    switch(f) {
      case 'por_area': return 'Largo × Ancho → m² × Tarifa';
      case 'por_volumen': return 'L × A × Alto × Factor → Precio por complejidad';
      case 'por_hora': return 'Horas × Tarifa/hora';
      case 'por_minuto': return 'Minutos × Tarifa/minuto';
      case 'por_metro': return 'Metros × Tarifa/metro';
      case 'por_kg': return 'Peso × Tarifa/kg';
      case 'por_pieza': return 'Cantidad × Precio/pieza';
      case 'por_diseno': return 'Simple / Media / Alta / Premium';
      case 'precio_fijo': return 'Precio fijo negociado';
      default: return 'Largo × Ancho → m² × Tarifa';
    }
  }
}

class SimTarifa {
  final String id, clave, nombre;
  double valor;
  final String? unidad;
  SimTarifa({required this.id, required this.clave, required this.nombre,
    required this.valor, this.unidad});
  factory SimTarifa.fromJson(Map<String, dynamic> j) => SimTarifa(
    id: j['id'], clave: j['clave'], nombre: j['nombre'],
    valor: (j['valor'] as num?)?.toDouble() ?? 0,
    unidad: j['unidad']);
}

class SimRango {
  final String id;
  final double desde, hasta, precio;
  SimRango({required this.id, required this.desde, required this.hasta, required this.precio});
  factory SimRango.fromJson(Map<String, dynamic> j) => SimRango(
    id: j['id'],
    desde: (j['indice_desde'] as num? ?? j['desde'] as num?)?.toDouble() ?? 0,
    hasta: (j['indice_hasta'] as num? ?? j['hasta'] as num?)?.toDouble() ?? 999999,
    precio: (j['precio'] as num?)?.toDouble() ?? 0);
}

class SimExtra {
  final String id, nombre;
  final double precio;
  bool seleccionado;
  SimExtra({required this.id, required this.nombre, required this.precio, this.seleccionado = false});
  factory SimExtra.fromJson(Map<String, dynamic> j) => SimExtra(
    id: j['id'], nombre: j['nombre'],
    precio: (j['precio'] as num?)?.toDouble() ?? 0);
}

class SimAcabado {
  final String id, nombre;
  final double precio;
  SimAcabado({required this.id, required this.nombre, required this.precio});
  factory SimAcabado.fromJson(Map<String, dynamic> j) => SimAcabado(
    id: j['id'], nombre: j['nombre'],
    precio: (j['precio'] as num?)?.toDouble() ?? 0);
}

class SimConfig {
  final SimServicio servicio;
  final List<SimTipoTrabajo> tipos;
  final Map<String, SimTarifa> tarifas;
  final List<SimRango> rangos;
  final List<SimExtra> extras;
  final List<SimAcabado> acabados;

  SimConfig({required this.servicio, required this.tipos,
    required this.tarifas, required this.rangos,
    required this.extras, required this.acabados});

  double getTarifa(String clave) => tarifas[clave]?.valor ?? 0;

  double calcularPrecioRango(double indice) {
    for (final r in rangos) {
      if (indice >= r.desde && indice <= r.hasta) return r.precio;
    }
    return rangos.isNotEmpty ? rangos.last.precio : 0;
  }
}

class CostosTaller {
  final double costoHoraTaller;
  final double costoHoraMaquina;
  final double costoHoraOperador;
  final double margenRecomendado;
  final double margenMinimo;
  final double ivaPct;

  CostosTaller({this.costoHoraTaller = 0, this.costoHoraMaquina = 0,
    this.costoHoraOperador = 0, this.margenRecomendado = 35,
    this.margenMinimo = 20, this.ivaPct = 16});

  double get costoHoraTotal => costoHoraTaller + costoHoraMaquina + costoHoraOperador;
}

class ResultadoPrecio {
  final String etiqueta, emoji, descripcion;
  final double costo, precio, utilidad, margen;
  final Color color;
  final bool esRecomendado;

  ResultadoPrecio({required this.etiqueta, required this.emoji,
    required this.descripcion, required this.costo, required this.precio,
    required this.utilidad, required this.margen,
    required this.color, this.esRecomendado = false});
}

class ResultadoSimulador {
  final String servicio, emoji, descripcion;
  final double total, subtotal, iva, costoTotal;
  final double pvMinimo, pvRecomendado, pvPremium;
  final double utilidad, margenReal, gananciaHora, tiempoHoras;
  final double cm, cmo, cmaq, cc, ca, ci;
  final Map<String, double> costosDesglose;
  final bool incluyeIva;
  final String? materialNombre;
  // Para compatibilidad con cotizacion
  final double maquila, extras, acabado, costoMaterial;

  ResultadoSimulador({
    required this.servicio, required this.emoji, required this.descripcion,
    required this.total, required this.subtotal, this.iva = 0,
    required this.costoTotal, required this.pvMinimo,
    required this.pvRecomendado, required this.pvPremium,
    required this.utilidad, required this.margenReal,
    required this.gananciaHora, required this.tiempoHoras,
    required this.cm, required this.cmo, required this.cmaq,
    required this.cc, required this.ca, required this.ci,
    required this.costosDesglose, this.incluyeIva = false,
    this.materialNombre, this.maquila = 0, this.extras = 0,
    this.acabado = 0, this.costoMaterial = 0});
}

// ══════════════════════════════════════════════════════
// DATA SERVICE
// ══════════════════════════════════════════════════════
class SimuladorDataService {
  static final _sb = Supabase.instance.client;

  static Future<List<SimServicio>> getServicios() async {
    final data = await _sb.from('sim_servicios').select()
      .eq('activo', true).order('orden');
    return (data as List).map((j) => SimServicio.fromJson(j)).toList();
  }

  static Future<SimConfig> getConfig(String servicioId) async {
    final svcData = await _sb.from('sim_servicios')
      .select().eq('id', servicioId).maybeSingle();
    if (svcData == null) throw Exception('Servicio no encontrado');
    final servicio = SimServicio.fromJson(svcData);

    List tiposData = [];
    try { tiposData = await _sb.from('sim_tipos_trabajo')
      .select().eq('servicio_id', servicioId).eq('activo', true).order('orden'); } catch (_) {}
    if (tiposData.isEmpty) {
      try { tiposData = await _sb.from('sim_tipos_trabajo')
        .select().eq('servicio_id', servicioId).order('nombre'); } catch (_) {}
    }

    List tarifasData = [];
    try { tarifasData = await _sb.from('sim_tarifas')
      .select().eq('servicio_id', servicioId); } catch (_) {}

    List rangosData = [], extrasData = [], acabadosData = [];
    try { rangosData = await _sb.from('sim_rangos')
      .select().eq('servicio_id', servicioId).order('desde'); } catch (_) {}
    try { extrasData = await _sb.from('sim_extras')
      .select().eq('servicio_id', servicioId); } catch (_) {}
    try { acabadosData = await _sb.from('sim_acabados')
      .select().eq('servicio_id', servicioId); } catch (_) {}

    final tipos = tiposData.map((j) => SimTipoTrabajo.fromJson(j as Map<String,dynamic>)).toList();
    final tarifasMap = <String, SimTarifa>{};
    for (final j in tarifasData) {
      final t = SimTarifa.fromJson(j as Map<String,dynamic>);
      tarifasMap[t.clave] = t;
    }

    return SimConfig(
      servicio: servicio, tipos: tipos, tarifas: tarifasMap,
      rangos: rangosData.map((j) => SimRango.fromJson(j as Map<String,dynamic>)).toList(),
      extras: extrasData.map((j) => SimExtra.fromJson(j as Map<String,dynamic>)).toList(),
      acabados: acabadosData.map((j) => SimAcabado.fromJson(j as Map<String,dynamic>)).toList());
  }

  static Future<CostosTaller> getCostosTaller() async {
    try {
      final cfg = await _sb.from('empresa_config')
        .select().eq('negocio_id', _negId).maybeSingle();
      final horasDia = (cfg?['horas_dia'] as num?)?.toDouble() ?? 8;
      final costoFijo = (cfg?['costo_fijo_mensual'] as num?)?.toDouble() ?? 0;
      final costoHoraTaller = costoFijo > 0 ? costoFijo / (30 * horasDia) : 0;
      final margenRec = (cfg?['margen_recomendado'] as num?)?.toDouble() ?? 35;
      final margenMin = (cfg?['margen_minimo'] as num?)?.toDouble() ?? 20;
      final ivaPct = (cfg?['iva_pct'] as num?)?.toDouble() ?? 16;

      double costoHoraMaq = 0;
      final maqList = await _sb.from('maquinaria')
        .select().eq('negocio_id', _negId).eq('activo', true).limit(1);
      if ((maqList as List).isNotEmpty) {
        final m = maqList.first as Map<String,dynamic>;
        final v = (m['valor_adquisicion'] as num?)?.toDouble() ?? 0;
        final vida = (m['vida_util_años'] as num?)?.toDouble() ?? 10;
        final hrs = (m['horas_mes'] as num?)?.toDouble() ?? 160;
        final kwh = (m['consumo_kwh'] as num?)?.toDouble() ?? 0;
        final ckwh = (m['costo_kwh'] as num?)?.toDouble() ?? 2.5;
        final mant = (m['mantenimiento_mes'] as num?)?.toDouble() ?? 0;
        final cons = (m['consumibles_hora'] as num?)?.toDouble() ?? 0;
        costoHoraMaq = (vida > 0 && hrs > 0 ? v/(vida*12*hrs) : 0) + (kwh*ckwh) + (hrs>0 ? mant/hrs : 0) + cons;
      }

      double costoHoraOp = 0;
      final opList = await _sb.from('mano_obra')
        .select().eq('negocio_id', _negId).eq('activo', true).limit(1);
      if ((opList as List).isNotEmpty) {
        final o = opList.first as Map<String,dynamic>;
        final sal = (o['salario_mes'] as num?)?.toDouble() ?? 0;
        final prest = (o['prestaciones_pct'] as num?)?.toDouble() ?? 35;
        final hrs = (o['horas_mes'] as num?)?.toDouble() ?? 192;
        costoHoraOp = hrs > 0 ? sal*(1+prest/100)/hrs : 0;
      }

      return CostosTaller(costoHoraTaller: costoHoraTaller.toDouble(),
        costoHoraMaquina: costoHoraMaq.toDouble(), costoHoraOperador: costoHoraOp.toDouble(),
        margenRecomendado: margenRec.toDouble(), margenMinimo: margenMin.toDouble(),
        ivaPct: ivaPct.toDouble());
    } catch (_) { return CostosTaller(); }
  }

  static Future<List<Map<String,dynamic>>> getMaterialesInventario() async {
    try {
      final data = await _sb.from('inventario_bodega')
        .select('id,nombre,costo_unitario,unidad,stock_actual')
        .eq('activo', true).order('nombre');
      return (data as List).cast<Map<String,dynamic>>();
    } catch (_) { return []; }
  }

  static Future<void> actualizarTarifa(String id, double valor) async {
    await _sb.from('sim_tarifas').update({'valor': valor}).eq('id', id);
  }

  static Future<void> crearServicio(Map<String,dynamic> datos) async {
    await _sb.from('sim_servicios').insert(datos);
  }

  static Future<void> crearTipoTrabajo(Map<String,dynamic> datos) async {
    await _sb.from('sim_tipos_trabajo').insert(datos);
  }
}

// ══════════════════════════════════════════════════════
// MOTOR DE CÁLCULO
// ══════════════════════════════════════════════════════
class MotorCalculo {
  static ResultadoSimulador calcular({
    required SimConfig cfg,
    required CostosTaller costos,
    required SimTipoTrabajo tipo,
    required String nombreServicio,
    required String emojiServicio,
    required double largo, required double ancho, required double alto,
    required double peso, required double metros,
    required double horas, required double minutos,
    required int cantidad, required String complejidad,
    required bool clienteTreMaterial,
    required bool usarInventario,
    required Map<String,dynamic>? materialInv,
    required String materialLibreNombre,
    required double materialLibrePrecio,
    required SimAcabado? acabado,
    required bool aplicarIva,
    required List<SimExtra> extrasSeleccionados,
    required String descripcionEditable,
    // Extras Diseño Digital
    bool clienteTraeArchivo = false,
    bool archivoEsVector = false,
    bool entregaUrgente = false,
    int revisionesExtra = 0,
    bool archivoEditableAlCliente = false,
    // Extras Router 2D
    double horasLijado = 0,
    double horasBarnizado = 0,
    bool llevaDiseno = false,
    // Plasma CNC
    String calibre = 'Cal 14',
    String material = 'acero_negro',
    bool llevaLimpieza = false,
    bool llevaFlete = false,
    String tamanoFlete = 'mediano',
    bool llevaDisenoPlasma = false,
    bool clienteTraeArchivoDXF = false,
    double horasDisenoPlasma = 1.0,
    // Láser CO₂
    String materialLaser = 'mdf_fino',
    String densidadLaser = 'normal',
    String tipoLaser = 'corte',
    // Láser Fibra
    bool llevaPlantilla = false,
    bool llevaRotativo = false,
    // Impresión 3D
    String materialImpresion = 'pla',
    String calidadImpresion = 'normal',
  }) {
    final fmt = NumberFormat(r'$#,##0.00', 'es_MX');
    final formula = tipo.formula;
    final desglose = <String, double>{};

    // ── CÁLCULO POR FÓRMULA ──────────────────────────
    double precioMaquila = 0;  // precio directo de maquila
    double tiempoHoras = 0;

    switch (formula) {

      // ── ROUTER 2D / PLASMA CNC: Por área × tarifa ──────
      case 'por_area':
        final areaM2 = (largo/100) * (ancho/100);
        final esCelosia = tipo.nombre.toLowerCase().contains('celosia') ||
                          tipo.nombre.toLowerCase().contains('celosía') ||
                          tipo.nombre.toLowerCase().contains('calado');
        // Detectar Plasma por sus tarifas específicas
        final esPlasma = cfg.getTarifa('tarifa_m2_delgado') > 0;
        double tarifaM2;
        if (esPlasma) {
          final calibresDelgados = ['Cal 20','Cal 18','Cal 16','Cal 14','Cal 12'];
          final esDelgado = calibresDelgados.contains(calibre);
          final tarifaBase = esDelgado
            ? (cfg.getTarifa('tarifa_m2_delgado') > 0 ? cfg.getTarifa('tarifa_m2_delgado') : 480)
            : (cfg.getTarifa('tarifa_m2_medio')   > 0 ? cfg.getTarifa('tarifa_m2_medio')   : 680);
          final factorMat = material == 'inox'
            ? (cfg.getTarifa('factor_inox') > 0 ? cfg.getTarifa('factor_inox') : 1.4)
            : material == 'aluminio'
              ? (cfg.getTarifa('factor_aluminio') > 0 ? cfg.getTarifa('factor_aluminio') : 1.3)
              : 1.0;
          tarifaM2 = tarifaBase * factorMat * (esCelosia ? tipo.factor : 1.0);
          desglose['material_factor'] = factorMat.toDouble();
          // Mínimo apertura solo si pieza pequeña
          final umbral = cfg.getTarifa('umbral_minimo_m2') > 0 ? cfg.getTarifa('umbral_minimo_m2') : 0.09;
          final minAp = cfg.getTarifa('minimo_apertura') > 0 ? cfg.getTarifa('minimo_apertura') : 150;
          if (areaM2 < umbral) {
            desglose['minimo_apertura'] = minAp.toDouble();
          }
        } else {
          tarifaM2 = esCelosia
            ? (cfg.getTarifa('tarifa_m2_celosia') > 0 ? cfg.getTarifa('tarifa_m2_celosia') : 450)
            : (cfg.getTarifa('tarifa_m2_normal')  > 0 ? cfg.getTarifa('tarifa_m2_normal')  : 350);
        }
        precioMaquila = areaM2 * tarifaM2 * cantidad;
        if (esPlasma) {
          final umbral2 = cfg.getTarifa('umbral_minimo_m2') > 0 ? cfg.getTarifa('umbral_minimo_m2') : 0.09;
          final minAp2 = cfg.getTarifa('minimo_apertura') > 0 ? cfg.getTarifa('minimo_apertura') : 150;
          if (areaM2 < umbral2 && precioMaquila < minAp2) precioMaquila = minAp2.toDouble();
        }
        desglose['area_m2'] = areaM2;
        desglose['tarifa_m2'] = tarifaM2.toDouble();
        // Extras Router 2D
        if (horasLijado > 0) {
          final tl = cfg.getTarifa('costo_lijado_hora') > 0 ? cfg.getTarifa('costo_lijado_hora') : 150;
          desglose['mano_obra_lijado'] = (horasLijado * tl * cantidad).toDouble();
        }
        if (horasBarnizado > 0) {
          final tb = cfg.getTarifa('costo_barnizado') > 0 ? cfg.getTarifa('costo_barnizado') : 200;
          desglose['mano_obra_barnizado'] = (horasBarnizado * tb * cantidad).toDouble();
        }
        if (llevaDiseno) {
          final td = cfg.getTarifa('costo_diseno') > 0 ? cfg.getTarifa('costo_diseno') : 300;
          desglose['diseno_adicional'] = td.toDouble();
        }
        tiempoHoras = areaM2 * 0.5 * cantidad; break;

      // ── ROUTER 3D / IMPRESIÓN 3D / CARPINTERÍA ─────────
      case 'por_volumen':
        final volumen = largo * ancho * alto;

        // Impresión 3D: calcular por gramos y tiempo
        final esImpresion = cfg.getTarifa('factor_rapida') > 0 || cfg.getTarifa('costo_pla') > 0;
        // Carpintería: cajas por volumen
        final esCarpinteria = cfg.getTarifa('material_mdf_m2') > 0;

        if (esImpresion) {
          final relleno = cfg.getTarifa('relleno_pct') > 0 ? cfg.getTarifa('relleno_pct') / 100 : 0.20;
          final volEfectivo = volumen * relleno;
          // Densidad según material
          final densidades = {'pla': 1.24, 'abs': 1.04, 'petg': 1.27, 'tpu': 1.20};
          final densidad = densidades[materialImpresion] ?? 1.24;
          final gramos = volEfectivo * densidad;
          // Costo material
          final costoGrClaves = {'pla': 'costo_pla', 'abs': 'costo_abs',
            'petg': 'costo_petg', 'tpu': 'costo_tpu'};
          final claveGr = costoGrClaves[materialImpresion] ?? 'costo_pla';
          final costoGr = cfg.getTarifa(claveGr) > 0 ? cfg.getTarifa(claveGr) : 0.35;
          cm = gramos * costoGr * cantidad;
          // Tiempo según calidad (factor del tipo)
          final factorCalidad = tipo.factor; // rapida=0.8, normal=1.2, alta=2.0
          final minutos3D = volEfectivo * factorCalidad;
          tiempoHoras = minutos3D / 60 * cantidad;
          final tarifaHr3D = cfg.getTarifa('tarifa_hora') > 0 ? cfg.getTarifa('tarifa_hora') : 80;
          precioMaquila = tiempoHoras * tarifaHr3D;
          desglose['volumen_cm3'] = volumen.toDouble();
          desglose['gramos_estimados'] = gramos.toDouble();
          desglose['tiempo_min'] = minutos3D.toDouble();
          // Mínimo
          final minImp = cfg.getTarifa('minimo') > 0 ? cfg.getTarifa('minimo') : 200;
          if (precioMaquila + cm < minImp) {
            precioMaquila = minImp.toDouble();
            desglose['precio_minimo'] = minImp.toDouble();
          }
        } else {
          // Router 3D: precio por tabla de rangos
          double precioRango = cfg.calcularPrecioRango(volumen);
          if (precioRango == 0 && volumen > 0) precioRango = 580;
          precioMaquila = precioRango * tipo.factor * cantidad;
          desglose['volumen_cm3'] = volumen.toDouble();
          desglose['precio_rango_base'] = precioRango.toDouble();
          desglose['factor_tipo'] = tipo.factor.toDouble();
          tiempoHoras = volumen * 0.003 * tipo.factor * cantidad;
          if (tiempoHoras < 0.5 && volumen > 0) tiempoHoras = 0.5;
        }
        break;

      // ── DISEÑO DIGITAL ────────────────────────────────
      case 'por_diseno':
        // Si cliente trae vector listo → solo setup
        if (clienteTraeArchivo && archivoEsVector) {
          precioMaquila = cfg.getTarifa('tarifa_setup') > 0
            ? cfg.getTarifa('tarifa_setup') : 75;
          tiempoHoras = 0.25;
          desglose['setup_montaje'] = precioMaquila.toDouble();
        } else {
          // Determinar tarifa por hora según tipo
          double tarifaHr;
          if (tipo.nombre.contains('3D') || tipo.nombre.contains('3d')) {
            tarifaHr = cfg.getTarifa('tarifa_hora_3d') > 0 ? cfg.getTarifa('tarifa_hora_3d') : 500;
          } else if (tipo.nombre.toUpperCase().contains('CAM')) {
            tarifaHr = cfg.getTarifa('tarifa_hora_cam') > 0 ? cfg.getTarifa('tarifa_hora_cam') : 400;
          } else {
            tarifaHr = cfg.getTarifa('tarifa_hora_2d') > 0 ? cfg.getTarifa('tarifa_hora_2d') : 300;
          }
          // Horas = factor del tipo (ya incluye complejidad)
          tiempoHoras = tipo.factor;
          precioMaquila = tiempoHoras * tarifaHr;
          desglose['horas_diseno'] = tiempoHoras.toDouble();
          desglose['tarifa_hora'] = tarifaHr.toDouble();

          // Si cliente trae imagen (JPG) → precio normal
          // Si diseña desde cero → precio normal
          if (clienteTraeArchivo && !archivoEsVector) {
            desglose['vectorizacion_imagen'] = precioMaquila.toDouble();
          }
        }

        // Cargo urgente
        if (entregaUrgente) {
          final pctUrgente = cfg.getTarifa('cargo_urgente') > 0
            ? cfg.getTarifa('cargo_urgente') : 40;
          final cargoUrgente = precioMaquila * pctUrgente / 100;
          precioMaquila += cargoUrgente;
          desglose['cargo_urgente'] = cargoUrgente.toDouble();
        }

        // Revisiones extra
        if (revisionesExtra > 0) {
          final cargoRev = cfg.getTarifa('cargo_revision') > 0
            ? cfg.getTarifa('cargo_revision') : 150;
          final totalRev = cargoRev * revisionesExtra;
          precioMaquila += totalRev;
          desglose['revisiones_extra'] = totalRev.toDouble();
        }

        // Archivo editable al cliente
        if (archivoEditableAlCliente) {
          final pctArch = cfg.getTarifa('cargo_archivo_editable') > 0
            ? cfg.getTarifa('cargo_archivo_editable') : 200;
          final cargoArch = precioMaquila * pctArch / 100;
          precioMaquila += cargoArch;
          desglose['archivo_editable'] = cargoArch.toDouble();
        }
        break;

      case 'por_hora':
        tiempoHoras = horas > 0 ? horas : 1.0;
        final tarifaHr = cfg.getTarifa('tarifa_hora') > 0
          ? cfg.getTarifa('tarifa_hora') : costos.costoHoraTotal * 1.5;
        precioMaquila = tiempoHoras * tarifaHr * cantidad;
        // Herrería: agregar material estimado
        if (cfg.getTarifa('material_hora') > 0 && !clienteTreMaterial) {
          final matHr = cfg.getTarifa('material_hora');
          precioMaquila += matHr * tiempoHoras * cantidad;
          desglose['material_estimado'] = (matHr * tiempoHoras * cantidad).toDouble();
        }
        tiempoHoras *= cantidad;
        break;

      case 'por_minuto':
        final areaM2min = (largo/100) * (ancho/100);
        double minEst = 0;

        // Láser CO₂: cálculo real por velocidad y tipo
        final tieneVelLaser = cfg.getTarifa('vel_mdf_fino') > 0;
        if (tieneVelLaser) {
          double velCorte;
          switch (materialLaser) {
            case 'mdf_fino':  velCorte = cfg.getTarifa('vel_mdf_fino') > 0 ? cfg.getTarifa('vel_mdf_fino') : 30; break;
            case 'mdf_medio': velCorte = cfg.getTarifa('vel_mdf_medio') > 0 ? cfg.getTarifa('vel_mdf_medio') : 21; break;
            default:          velCorte = cfg.getTarifa('vel_otros') > 0 ? cfg.getTarifa('vel_otros') : 15;
          }
          final velGrab = cfg.getTarifa('vel_grabado') > 0 ? cfg.getTarifa('vel_grabado') : 190;
          final intervalo = densidadLaser == 'ligero'
            ? (cfg.getTarifa('intervalo_ligero') > 0 ? cfg.getTarifa('intervalo_ligero') : 0.2)
            : densidadLaser == 'denso'
              ? (cfg.getTarifa('intervalo_denso') > 0 ? cfg.getTarifa('intervalo_denso') : 0.1)
              : (cfg.getTarifa('intervalo_normal') > 0 ? cfg.getTarifa('intervalo_normal') : 0.15);
          final perimetro = 2 * (largo + ancho) * 10;
          final minCorte = perimetro / velCorte / 60;
          final areaGrab = largo * ancho;
          final minGrabado = (areaGrab * 100) / (intervalo * velGrab * 60);
          switch (tipoLaser) {
            case 'grabado': minEst = minGrabado; break;
            case 'ambos':   minEst = (minCorte + minGrabado) * tipo.factor; break;
            default:        minEst = minCorte;
          }
          final costoTubo = cfg.getTarifa('costo_tubo_min') > 0 ? cfg.getTarifa('costo_tubo_min') : 0.80;
          desglose['desgaste_tubo'] = (minEst * costoTubo * cantidad).toDouble();
        } else {
          minEst = minutos > 0 ? minutos : areaM2min * 60 * tipo.factor;
        }

        final tieneMinFibra = cfg.getTarifa('tarifa_min_marcado') > 0;
        double tarifaMinuto;
        if (tieneMinFibra) {
          final esProfundo = tipo.nombre.toLowerCase().contains('profundo');
          tarifaMinuto = esProfundo
            ? (cfg.getTarifa('tarifa_min_profundo') > 0 ? cfg.getTarifa('tarifa_min_profundo') : 18)
            : (cfg.getTarifa('tarifa_min_marcado') > 0 ? cfg.getTarifa('tarifa_min_marcado') : 12);
        } else {
          tarifaMinuto = cfg.getTarifa('tarifa_min') > 0 ? cfg.getTarifa('tarifa_min') : 10;
        }
        tiempoHoras = minEst / 60 * cantidad;
        precioMaquila = minEst * tarifaMinuto * cantidad;
        desglose['minutos_estimados'] = (minEst * cantidad).toDouble();
        desglose['tarifa_min'] = tarifaMinuto.toDouble();
        break;


      case 'por_metro':
        final tieneMetroPlasma = cfg.getTarifa('tarifa_metro_delgado') > 0;
        double tarifaMt;
        if (tieneMetroPlasma) {
          final calibresD = ['Cal 20','Cal 18','Cal 16','Cal 14','Cal 12'];
          final esD = calibresD.contains(calibre);
          final tarifaBaseM = esD
            ? (cfg.getTarifa('tarifa_metro_delgado') > 0 ? cfg.getTarifa('tarifa_metro_delgado') : 80.0)
            : (cfg.getTarifa('tarifa_metro_medio')   > 0 ? cfg.getTarifa('tarifa_metro_medio')   : 150.0);
          final fMat = material == 'inox'
            ? (cfg.getTarifa('factor_inox') > 0 ? cfg.getTarifa('factor_inox') : 1.4)
            : material == 'aluminio'
              ? (cfg.getTarifa('factor_aluminio') > 0 ? cfg.getTarifa('factor_aluminio') : 1.3)
              : 1.0;
          tarifaMt = (tarifaBaseM * fMat).toDouble();
        } else {
          tarifaMt = cfg.getTarifa('tarifa_metro') > 0 ? cfg.getTarifa('tarifa_metro').toDouble() : 100.0;
        }
        precioMaquila = metros * tarifaMt * cantidad;
        tiempoHoras = metros * 0.1 * cantidad;
        desglose['metros'] = metros;
        desglose['tarifa_metro'] = tarifaMt;
        break;

      case 'por_kg':
        final tarifaKg = cfg.getTarifa('tarifa_kg') > 0
          ? cfg.getTarifa('tarifa_kg') : 50;
        precioMaquila = peso * tarifaKg * cantidad;
        tiempoHoras = peso * 0.05 * cantidad;
        break;

      case 'por_pieza':
        // Láser Fibra: precio escalonado por cantidad
        final tienePrecioEscalonado = cfg.getTarifa('precio_1_10') > 0;
        double tarifaPza;
        if (tienePrecioEscalonado) {
          if (cantidad <= 10)       tarifaPza = cfg.getTarifa('precio_1_10');
          else if (cantidad <= 50)  tarifaPza = cfg.getTarifa('precio_11_50');
          else if (cantidad <= 200) tarifaPza = cfg.getTarifa('precio_51_200');
          else                      tarifaPza = cfg.getTarifa('precio_200_mas');
          // Factor del tipo (Profundo × 1.5, Recocido × 1.3)
          tarifaPza *= tipo.factor;
          desglose['tarifa_por_pieza'] = tarifaPza.toDouble();
          // Extras Fibra
          if (llevaPlantilla) {
            final pPlant = cfg.getTarifa('setup_plantilla') > 0 ? cfg.getTarifa('setup_plantilla') : 150;
            desglose['plantilla_sujecion'] = pPlant.toDouble();
            precioMaquila += pPlant;
          }
          if (llevaRotativo) {
            final pRot = cfg.getTarifa('cargo_rotativo') > 0 ? cfg.getTarifa('cargo_rotativo') : 25;
            desglose['eje_rotativo'] = (pRot * cantidad).toDouble();
            precioMaquila += pRot * cantidad;
          }
          // Mínimo apertura
          final minAp = cfg.getTarifa('minimo_apertura') > 0 ? cfg.getTarifa('minimo_apertura') : 150;
          if (tarifaPza * cantidad < minAp) {
            desglose['minimo_apertura'] = minAp.toDouble();
          }
        } else {
          tarifaPza = cfg.getTarifa('tarifa_pieza') > 0 ? cfg.getTarifa('tarifa_pieza') : 100;
        }
        precioMaquila += tarifaPza * cantidad;
        if (tienePrecioEscalonado) {
          final minAp2 = cfg.getTarifa('minimo_apertura') > 0 ? cfg.getTarifa('minimo_apertura') : 150;
          if (precioMaquila < minAp2) precioMaquila = minAp2.toDouble();
        }
        tiempoHoras = tipo.factor * cantidad / 60;
        break;

      case 'precio_fijo':
        precioMaquila = cfg.getTarifa('precio_fijo') * cantidad;
        tiempoHoras = 1.0;
        break;

      default:
        tiempoHoras = 1.0;
    }

    // Agregar extras Router 2D al desglose
    final moLijado = desglose['mano_obra_lijado'] ?? 0;
    final moBarniz = desglose['mano_obra_barnizado'] ?? 0;
    final moDis = desglose['diseno_adicional'] ?? 0;
    final extrasRouter = moLijado + moBarniz + moDis;

    // Extras Plasma CNC
    double extrasPlasma = 0;
    if (llevaLimpieza) {
      final costoLimp = cfg.getTarifa('limpieza_pieza') > 0 ? cfg.getTarifa('limpieza_pieza') : 80;
      extrasPlasma += costoLimp * cantidad;
      desglose['limpieza_pieza'] = (costoLimp * cantidad).toDouble();
    }
    if (llevaFlete) {
      final areaTotal = (largo/100) * (ancho/100) * cantidad;
      double costoFlete = 0;
      if (areaTotal < 1.0) { costoFlete = 0; }
      else if (areaTotal <= 3.0) {
        costoFlete = cfg.getTarifa('flete_mediano') > 0 ? cfg.getTarifa('flete_mediano') : 350;
      } else {
        costoFlete = cfg.getTarifa('flete_grande') > 0 ? cfg.getTarifa('flete_grande') : 800;
      }
      if (costoFlete > 0) {
        extrasPlasma += costoFlete;
        desglose['flete_maniobra'] = costoFlete.toDouble();
      }
    }
    if (llevaDisenoPlasma) {
      if (clienteTraeArchivoDXF) {
        final setupDXF = cfg.getTarifa('setup_archivo') > 0 ? cfg.getTarifa('setup_archivo') : 75;
        extrasPlasma += setupDXF;
        desglose['setup_dxf'] = setupDXF.toDouble();
      } else {
        final tarifaDis = cfg.getTarifa('tarifa_diseno_hora') > 0 ? cfg.getTarifa('tarifa_diseno_hora') : 250;
        final costoDis = tarifaDis * horasDisenoPlasma;
        extrasPlasma += costoDis;
        desglose['diseno_plasma'] = costoDis.toDouble();
      }
    }

    // ── COSTOS DIRECTOS ─────────────────────────────
    // CM - Material
    double cm = 0;
    String? materialNombre;
    if (!clienteTreMaterial) {
      if (usarInventario && materialInv != null) {
        cm = ((materialInv['costo_unitario'] as num?)?.toDouble() ?? 0) * cantidad;
        // Agregar merma 15%
        cm *= 1.15;
        materialNombre = materialInv['nombre'] as String?;
      } else if (!usarInventario && materialLibrePrecio > 0) {
        cm = materialLibrePrecio * cantidad * 1.15; // +15% merma
        materialNombre = materialLibreNombre.isNotEmpty ? materialLibreNombre : 'Material';
      }
    }

    // CMaq - Máquina
    double cmaq = costos.costoHoraMaquina * tiempoHoras;

    // CMO - Mano de obra
    double cmo = costos.costoHoraOperador * tiempoHoras;

    // CC - Consumibles (de tarifa o estimado)
    double cc = 0;
    final tarifaCons = cfg.getTarifa('consumibles_hora');
    if (tarifaCons > 0) {
      cc = tarifaCons * tiempoHoras;
    } else {
      // Default: $25/hr de consumibles
      cc = 25 * tiempoHoras;
    }

    // CA - Acabado
    double ca = (acabado?.precio ?? 0) * cantidad;

    // CI - Costo indirecto del taller
    double ci = costos.costoHoraTaller * tiempoHoras;

    // Extras
    double extrasTotal = 0;
    for (final e in extrasSeleccionados) {
      extrasTotal += e.precio * cantidad;
    }

    // ── COSTO TOTAL ─────────────────────────────────
    // Para Router y Diseño: el precioMaquila YA incluye la ganancia
    // Solo sumamos materiales y acabados como costo adicional
    double costoTotal;
    if (precioMaquila > 0) {
      // Modo directo: maquila + material + acabado + extras
      costoTotal = precioMaquila + cm + ca + extrasTotal + extrasRouter + extrasPlasma;
      // Registrar en desglose
      if (precioMaquila > 0) {
        final desglMap = {'Maquila/Producción': precioMaquila};
        if (cm > 0) desglMap['Material'] = cm;
        if (ca > 0) desglMap['Acabado'] = ca;
        if (extrasRouter > 0) desglMap['Mano de obra'] = extrasRouter;
        if (extrasTotal > 0) desglMap['Extras'] = extrasTotal;
      }
    } else {
      // Modo costo real: suma todos los componentes
      costoTotal = cm + cmaq + cmo + cc + ca + ci + extrasTotal;
    }

    // ── 3 PRECIOS CON MARGEN ─────────────────────────
    // Para Diseño y Láser de Fibra por pieza, usar tarifas directas si están configuradas
    double baseMin, baseRec, basePrem;

    // ── 3 PRECIOS ────────────────────────────────────
    // Para Router/Diseño: el precio de maquila ya está calculado
    // Solo aplicamos márgenes sobre el costo total
    final mMin  = costos.margenMinimo / 100;
    final mRec  = costos.margenRecomendado / 100;
    final mPrem = (costos.margenRecomendado + 15) / 100;

    if (precioMaquila > 0) {
      // El precio recomendado = maquila + material + acabados
      baseRec  = costoTotal;
      baseMin  = costoTotal * (1 - (mRec - mMin));
      basePrem = costoTotal * (1 + (mPrem - mRec));
    } else {
      // Fórmula maestra: PV = Costo ÷ (1 - Margen)
      baseMin  = costoTotal > 0 ? costoTotal / (1 - mMin)  : 0;
      baseRec  = costoTotal > 0 ? costoTotal / (1 - mRec)  : 0;
      basePrem = costoTotal > 0 ? costoTotal / (1 - mPrem) : 0;
    }

    // IVA
    final iva = aplicarIva ? baseRec * (costos.ivaPct / 100) : 0.0;
    final pvConIva = baseRec + iva;

    // Análisis
    final utilidad = baseRec - costoTotal;
    final margenReal = baseRec > 0 ? (utilidad / baseRec) * 100 : 0;
    final gananciaHora = tiempoHoras > 0 ? utilidad / tiempoHoras : 0;

    return ResultadoSimulador(
      servicio: nombreServicio, emoji: emojiServicio,
      descripcion: descripcionEditable,
      total: pvConIva, subtotal: baseRec, iva: iva,
      costoTotal: costoTotal,
      pvMinimo: baseMin, pvRecomendado: baseRec, pvPremium: basePrem,
      utilidad: utilidad,
      margenReal: margenReal.toDouble(),
      gananciaHora: gananciaHora.toDouble(),
      tiempoHoras: tiempoHoras,
      cm: cm, cmo: cmo, cmaq: cmaq, cc: cc, ca: ca, ci: ci,
      costosDesglose: {
        'Material': cm, 'Máquina': cmaq, 'Operador': cmo,
        'Consumibles': cc, 'Acabado': ca, 'Taller (CI)': ci,
        'Extras': extrasTotal,
      },
      incluyeIva: aplicarIva,
      materialNombre: materialNombre,
      maquila: baseRec, costoMaterial: cm, acabado: ca, extras: extrasTotal);
  }
}

// ══════════════════════════════════════════════════════
// PANTALLA PRINCIPAL
// ══════════════════════════════════════════════════════
class SimuladorScreen extends StatefulWidget {
  const SimuladorScreen({super.key});
  @override
  State<SimuladorScreen> createState() => _SimuladorScreenState();
}

class _SimuladorScreenState extends State<SimuladorScreen> {
  List<SimServicio> _servicios = [];
  bool _cargando = true;
  final List<ResultadoSimulador> _carrito = [];
  final _fmt = NumberFormat(r'$#,##0', 'es_MX');

  double get _totalCarrito => _carrito.fold(0, (s, r) => s + r.total);

  @override
  void initState() {
    super.initState();
    // Listeners para sincronizar controllers con variables
    _largoCtrl.addListener(() => setState(() {
      _largo = double.tryParse(_largoCtrl.text) ?? 0; _resultado = null; }));
    _anchoCtrl.addListener(() => setState(() {
      _ancho = double.tryParse(_anchoCtrl.text) ?? 0; _resultado = null; }));
    _altoCtrl.addListener(() => setState(() {
      _alto = double.tryParse(_altoCtrl.text) ?? 0; _resultado = null; }));
    _pesoPCtrl.addListener(() => setState(() {
      _peso = double.tryParse(_pesoPCtrl.text) ?? 0; _resultado = null; }));
    _metrosCtrl.addListener(() => setState(() {
      _metros = double.tryParse(_metrosCtrl.text) ?? 0; _resultado = null; }));
    _horasCtrl.addListener(() => setState(() {
      _horas = double.tryParse(_horasCtrl.text) ?? 0; _resultado = null; }));
    _minutosCtrl.addListener(() => setState(() {
      _minutos = double.tryParse(_minutosCtrl.text) ?? 0; _resultado = null; }));
    _cantCtrl.addListener(() => setState(() {
      _cantidad = int.tryParse(_cantCtrl.text) ?? 1; _resultado = null; }));
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final s = await SimuladorDataService.getServicios();
      if (mounted) setState(() { _servicios = s; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  void _agregarAlCarrito(ResultadoSimulador r) {
    setState(() => _carrito.add(r));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ ${r.servicio} agregado — ${_fmt.format(r.total)}'),
      backgroundColor: AppColors.verde,
      duration: const Duration(seconds: 2)));
  }

  void _cotizar() {
    if (_carrito.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CotizarScreen(carritoSimulador: _carrito)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Simulador de costos',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.azul), onPressed: _cargar),
          IconButton(icon: const Icon(Icons.add, color: AppColors.azul), onPressed: _nuevoServicio),
        ]),
      body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            if (_carrito.isNotEmpty) _bannerCarrito(),
            Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.azul, Color(0xFF2d5a8e)]),
                  borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Calcula el costo real de cualquier trabajo',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text('Selecciona el servicio y llena las variables.',
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
                  if (_carrito.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _cotizar,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.naranja,
                          borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.description_outlined, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text('Cotizar ${_carrito.length} servicio${_carrito.length > 1 ? "s" : ""} — ${_fmt.format(_totalCarrito)}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ]))),
                  ],
                ])),
              const SizedBox(height: 14),

              // Grid de servicios
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: 1.4,
                  crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: _servicios.length + 1,
                itemBuilder: (_, i) {
                  if (i == _servicios.length) return _cardAgregar();
                  return _cardServicio(_servicios[i]);
                }),

              // Carrito
              if (_carrito.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('CARRITO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textoSecundario, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                ..._carrito.asMap().entries.map((e) => _cardCarrito(e.key, e.value)),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _cotizar,
                    icon: const Icon(Icons.description_outlined, color: Colors.white),
                    label: Text('Crear cotización — ${_fmt.format(_totalCarrito)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.naranja,
                      padding: const EdgeInsets.symmetric(vertical: 14)))),
              ],
            ])),
          ]));
  }

  Widget _bannerCarrito() => Container(
    color: AppColors.naranja,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text('${_carrito.length} servicio${_carrito.length > 1?"s":""} — ${_fmt.format(_totalCarrito)}',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      GestureDetector(onTap: _cotizar,
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: const Text('Cotizar', style: TextStyle(color: AppColors.naranja,
            fontWeight: FontWeight.w700, fontSize: 12)))),
    ]));

  Widget _cardServicio(SimServicio s) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => _PantallaServicio(servicio: s, onAgregar: _agregarAlCarrito))),
    child: Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(s.emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text(s.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: AppColors.azul), textAlign: TextAlign.center),
        if (s.descripcion != null) Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(s.descripcion!, style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario),
            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
      ])));

  Widget _cardAgregar() => GestureDetector(
    onTap: _nuevoServicio,
    child: Container(
      decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.azul.withOpacity(0.3))),
      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add_circle_outline, size: 32, color: AppColors.azul),
        SizedBox(height: 8),
        Text('Nuevo servicio', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul)),
        Text('Para tu negocio', style: TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
      ])));

  Widget _cardCarrito(int idx, ResultadoSimulador r) {
    final fmt = NumberFormat(r'$#,##0', 'es_MX');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Row(children: [
        Text(r.emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.servicio, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          Text(r.descripcion, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmt.format(r.total), style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.w800, color: AppColors.azul)),
          GestureDetector(onTap: () => setState(() => _carrito.removeAt(idx)),
            child: const Text('Quitar', style: TextStyle(fontSize: 10, color: AppColors.rojo))),
        ]),
      ]));
  }

  void _nuevoServicio() {
    final nombreCtrl = TextEditingController();
    String emojiSel = '🔧';
    final emojis = ['🔧','🪵','⚙️','🔴','🖨️','✏️','🔩','🪛','🏭','🛠️','📐','📏','🎨','🪚',
      '⚡','🔥','❄️','🌊','🎯','💡','🍞','🌽','🍕','🪟','🪞','🔲','🏗️','📦','🎁','💎','🌿','⚒️'];
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (_, setS) => Container(
        height: MediaQuery.of(ctx).size.height * 0.65,
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16,16,16,12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Nuevo servicio', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close)),
            ])),
          const Divider(height: 1),
          Expanded(child: SingleChildScrollView(
            padding: EdgeInsets.only(left:16, right:16, top:16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(children: [
              Wrap(spacing: 8, runSpacing: 8,
                children: emojis.map((e) => GestureDetector(
                  onTap: () => setS(() => emojiSel = e),
                  child: Container(width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: emojiSel == e ? AppColors.azulClaro : AppColors.gris,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: emojiSel == e ? AppColors.azul : AppColors.grisBorde)),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 22)))))).toList()),
              const SizedBox(height: 16),
              TextFormField(controller: nombreCtrl, textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre del servicio *',
                  hintText: 'Ej: Router CNC, Panadería, Cancelería...',
                  border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (nombreCtrl.text.trim().isEmpty) return;
                    final negId = Supabase.instance.client.auth.currentUser?.id ?? _negId;
                    await SimuladorDataService.crearServicio({
                      'negocio_id': negId, 'nombre': nombreCtrl.text.trim(),
                      'emoji': emojiSel, 'activo': true, 'orden': _servicios.length + 1});
                    if (mounted) { Navigator.pop(ctx); _cargar(); }
                  },
                  icon: const Icon(Icons.save_outlined, color: Colors.white),
                  label: const Text('Crear servicio',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul,
                    padding: const EdgeInsets.symmetric(vertical: 13)))),
            ]))),
        ]))));
  }
}

// ══════════════════════════════════════════════════════
// PANTALLA DE CÁLCULO POR SERVICIO
// ══════════════════════════════════════════════════════
class _PantallaServicio extends StatefulWidget {
  final SimServicio servicio;
  final void Function(ResultadoSimulador) onAgregar;
  const _PantallaServicio({required this.servicio, required this.onAgregar});
  @override
  State<_PantallaServicio> createState() => _PantallaServicioState();
}

class _PantallaServicioState extends State<_PantallaServicio> {
  SimConfig? _config;
  CostosTaller? _costosTaller;
  bool _cargando = true;
  ResultadoSimulador? _resultado;
  bool _mostrarTarifas = false;

  // Inputs Diseño Digital
  bool _clienteTraeArchivo = false;
  bool _archivoEsVector = false;
  bool _entregaUrgente = false;
  int _revisionesExtra = 0;
  bool _archivoEditableAlCliente = false;

  // Inputs Router 2D
  double _horasLijado = 0;
  double _horasBarnizado = 0;
  bool _llevaDiseno = false;

  // Inputs Plasma CNC
  String _calibre = 'Cal 14';
  String _material = 'acero_negro';
  bool _llevaLimpieza = false;
  bool _llevaFlete = false;
  String _tamanoFlete = 'mediano';
  bool _llevaDisenoPlasma = false;
  bool _clienteTraeArchivoDXF = false;
  double _horasDisenoPlasma = 1.0;

  // Inputs
  SimTipoTrabajo? _tipoSel;
  SimAcabado? _acabadoSel;
  bool _aplicarIva = false;
  bool _clienteTreMaterial = false;
  bool _usarInventario = true;
  int _tabActual = 0;
  String _materialLaser = 'mdf_fino';
  String _densidadLaser = 'normal';
  String _tipoLaser = 'corte'; // corte, grabado, ambos
  // Láser Fibra
  bool _llevaPlantilla = false;
  bool _llevaRotativo = false;
  bool _llevaDisenoFibra = false;
  // Impresión 3D
  String _materialImpresion = 'pla';
  String _calidadImpresion = 'normal';
  bool _llevaDisenyo3D = false;
  bool _llevaPostProceso = false;
  // Herrería
  String _materialHerreria = 'cuadrado_1';
  String _acabadoHerreria = 'sin_acabado';
  bool _llevaInstalacion = false;
  double _horasInstalacion = 1.0;
  // Carpintería
  String _materialCarpinteria = 'mdf';
  String _acabadoCarpinteria = 'sin_acabado';
  bool _llevaHerrajes = false;
  bool _llevaInstalacionCarp = false;
  double _horasInstalacionCarp = 1.0;

  // Controllers para campos de medida (fix bug teclado)
  final _largoCtrl   = TextEditingController();
  final _anchoCtrl   = TextEditingController();
  final _altoCtrl    = TextEditingController();
  final _pesoPCtrl   = TextEditingController();
  final _metrosCtrl  = TextEditingController();
  final _horasCtrl   = TextEditingController();
  final _minutosCtrl = TextEditingController();
  final _cantCtrl    = TextEditingController(text: '1');
  Map<String,dynamic>? _materialInvSel;
  String _materialLibreNombre = '';
  double _materialLibrePrecio = 0;
  List<Map<String,dynamic>> _materialesInv = [];

  double _largo = 0, _ancho = 0, _alto = 0;
  double _peso = 0, _metros = 0, _horas = 0, _minutos = 0;
  int _cantidad = 1;
  String _complejidad = 'media';
  String _descripcionEditable = '';

  final Map<String,TextEditingController> _tarifasCtrls = {};
  final _fmt = NumberFormat(r'$#,##0', 'es_MX');

  @override
  void initState() {
    super.initState();
    // Listeners para sincronizar controllers con variables
    _largoCtrl.addListener(() => setState(() {
      _largo = double.tryParse(_largoCtrl.text) ?? 0; _resultado = null; }));
    _anchoCtrl.addListener(() => setState(() {
      _ancho = double.tryParse(_anchoCtrl.text) ?? 0; _resultado = null; }));
    _altoCtrl.addListener(() => setState(() {
      _alto = double.tryParse(_altoCtrl.text) ?? 0; _resultado = null; }));
    _pesoPCtrl.addListener(() => setState(() {
      _peso = double.tryParse(_pesoPCtrl.text) ?? 0; _resultado = null; }));
    _metrosCtrl.addListener(() => setState(() {
      _metros = double.tryParse(_metrosCtrl.text) ?? 0; _resultado = null; }));
    _horasCtrl.addListener(() => setState(() {
      _horas = double.tryParse(_horasCtrl.text) ?? 0; _resultado = null; }));
    _minutosCtrl.addListener(() => setState(() {
      _minutos = double.tryParse(_minutosCtrl.text) ?? 0; _resultado = null; }));
    _cantCtrl.addListener(() => setState(() {
      _cantidad = int.tryParse(_cantCtrl.text) ?? 1; _resultado = null; }));
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _tarifasCtrls.values) c.dispose();
    for (final c in _medidaCtrls.values) c.dispose();
    _largoCtrl.dispose(); _anchoCtrl.dispose(); _altoCtrl.dispose();
    _pesoPCtrl.dispose(); _metrosCtrl.dispose(); _horasCtrl.dispose();
    _minutosCtrl.dispose(); _cantCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final cfg = await SimuladorDataService.getConfig(widget.servicio.id);
      final inv = await SimuladorDataService.getMaterialesInventario();
      final costos = await SimuladorDataService.getCostosTaller();
      if (mounted) setState(() {
        _config = cfg; _costosTaller = costos; _materialesInv = inv;
        _cargando = false;
        if (cfg.tipos.isNotEmpty) _tipoSel = cfg.tipos.first;
        if (cfg.acabados.isNotEmpty) _acabadoSel = cfg.acabados.first;
        for (final t in cfg.tarifas.values) {
          _tarifasCtrls[t.id] = TextEditingController(text: t.valor.toStringAsFixed(2));
        }
      });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  void _calcular() {
    final cfg = _config;
    final costos = _costosTaller ?? CostosTaller();
    if (cfg == null || _tipoSel == null) return;

    // Generar descripción automática
    final descParts = <String>[_tipoSel!.nombre];
    if (_tipoSel!.necesitaLargo && _largo > 0 && _ancho > 0) {
      descParts.add('Medidas: ${_largo}×${_ancho}${_alto > 0 ? "×${_alto}" : ""} cm');
    }
    if (_peso > 0) descParts.add('Peso: ${_peso} kg');
    if (_metros > 0) descParts.add('${_metros} metros lineales');
    if (_materialInvSel != null && !_clienteTreMaterial && _usarInventario) {
      descParts.add('Material: ${_materialInvSel!['nombre']}');
    } else if (_materialLibreNombre.isNotEmpty && !_clienteTreMaterial) {
      descParts.add('Material: $_materialLibreNombre');
    }
    if (_clienteTreMaterial) descParts.add('Cliente trae el material');
    if (_acabadoSel != null && _acabadoSel!.nombre != 'Sin acabado') {
      descParts.add('Acabado: ${_acabadoSel!.nombre}');
    }
    if (_cantidad > 1) descParts.add('Cantidad: $_cantidad piezas');
    final desc = _descripcionEditable.isNotEmpty
      ? _descripcionEditable : descParts.join('\n');

    final r = MotorCalculo.calcular(
      cfg: cfg, costos: costos, tipo: _tipoSel!,
      nombreServicio: widget.servicio.nombre,
      emojiServicio: widget.servicio.emoji,
      largo: _largo, ancho: _ancho, alto: _alto,
      peso: _peso, metros: _metros, horas: _horas, minutos: _minutos,
      cantidad: _cantidad, complejidad: _complejidad,
      clienteTreMaterial: _clienteTreMaterial,
      usarInventario: _usarInventario,
      materialInv: _materialInvSel,
      materialLibreNombre: _materialLibreNombre,
      materialLibrePrecio: _materialLibrePrecio,
      acabado: _acabadoSel,
      aplicarIva: _aplicarIva,
      extrasSeleccionados: cfg.extras.where((e) => e.seleccionado).toList(),
      descripcionEditable: desc,
      clienteTraeArchivo: _clienteTraeArchivo,
      archivoEsVector: _archivoEsVector,
      entregaUrgente: _entregaUrgente,
      revisionesExtra: _revisionesExtra,
      archivoEditableAlCliente: _archivoEditableAlCliente,
      horasLijado: _horasLijado,
      horasBarnizado: _horasBarnizado,
      llevaDiseno: _llevaDiseno,
      calibre: _calibre,
      material: _material,
      llevaLimpieza: _llevaLimpieza,
      llevaFlete: _llevaFlete,
      llevaDisenoPlasma: _llevaDisenoPlasma,
      clienteTraeArchivoDXF: _clienteTraeArchivoDXF,
      horasDisenoPlasma: _horasDisenoPlasma,
      materialLaser: _materialLaser,
      densidadLaser: _densidadLaser,
      tipoLaser: _tipoLaser,
      llevaPlantilla: _llevaPlantilla,
      llevaRotativo: _llevaRotativo,
      materialImpresion: _materialImpresion,
      calidadImpresion: _calidadImpresion);

    setState(() { _resultado = r; _descripcionEditable = desc; });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_config == null) return const Scaffold(body: Center(child: Text('Error cargando')));

    final cfg = _config!;
    final esPlasma = cfg.getTarifa('tarifa_m2_delgado') > 0;
    final esLaser  = cfg.getTarifa('tarifa_minuto') > 0 || cfg.getTarifa('tarifa_min') > 0;

    // Definir tabs según servicio
    final tabs = _getTabs(esPlasma, esLaser);

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.gris,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: Row(children: [
            Text(widget.servicio.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.servicio.nombre, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.azul),
              overflow: TextOverflow.ellipsis)),
          ]),
          bottom: TabBar(
            onTap: (i) => setState(() => _tabActual = i),
            labelColor: AppColors.azul,
            unselectedLabelColor: AppColors.textoSecundario,
            indicatorColor: AppColors.azul,
            isScrollable: true,
            tabs: tabs.map((t) => Tab(text: t)).toList())),
        body: Column(children: [
          // Contenido de cada tab
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              _buildTabContent(_tabActual, esPlasma, esLaser),
              const SizedBox(height: 40),
            ]))),
          // Botón calcular siempre visible
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(children: [
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _calcular,
                  icon: const Icon(Icons.calculate_outlined, color: Colors.white),
                  label: const Text('Calcular precio',
                    style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azul,
                    padding: const EdgeInsets.symmetric(vertical: 14)))),
              if (_resultado != null) ...[
                const SizedBox(height: 10),
                _widgetResultado(_resultado!),
              ],
            ])),
        ])));
  }

  List<String> _getTabs(bool esPlasma, bool esLaser) {
    if (esPlasma) return ['Tipo', 'Calibre', 'Material', 'Medidas', 'Extras'];
    if (esLaser) {
      // Detectar Fibra por sus tarifas específicas
      final esFibra = _config2.getTarifa('precio_1_10') > 0;
      if (esFibra) return ['Tipo', 'Material', 'Medidas', 'Extras'];
      return ['Tipo', 'Material', 'Densidad', 'Medidas', 'Extras'];
    }
    // Detectar otros módulos
    if (_config != null) {
      if (_config!.getTarifa('factor_rapida') > 0)
        return ['Tipo', 'Material', 'Dimensiones', 'Extras'];
      if (_config!.getTarifa('material_hora') > 0 && _config!.getTarifa('factor_rapida') == 0)
        return ['Tipo', 'Material', 'Medidas', 'Extras'];
      if (_config!.getTarifa('material_mdf_m2') > 0)
        return ['Tipo', 'Material', 'Medidas', 'Extras'];
    }
    return ['Tipo', 'Medidas', 'Material', 'Acabados', 'Extras'];
  }

  Widget _buildTabContent(int tab, bool esPlasma, bool esLaser) {
    if (esPlasma) {
      switch (tab) {
        case 0: return _seccionCard('Tipo de trabajo', _buildTipos());
        case 1: return _seccionCard('Calibre del material', _buildCalibre());
        case 2: return _seccionCard('Tipo de material', _buildMaterialPlasma());
        case 3: return _seccionCard('Medidas', _buildMedidas());
        case 4: return _seccionCard('Extras', _buildExtrasPlasma());
        default: return const SizedBox();
      }
    }
    if (esLaser) {
      final esFibra = _config!.getTarifa('precio_1_10') > 0;
      if (esFibra) {
        switch (tab) {
          case 0: return _seccionCard('Tipo de trabajo', _buildTipos());
          case 1: return _seccionCard('Material del grabado', _buildMaterialFibra());
          case 2: return _seccionCard('Medidas del área', _buildMedidas());
          case 3: return _seccionCard('Extras', _buildExtrasFibra());
          default: return const SizedBox();
        }
      }
      switch (tab) {
        case 0: return _seccionCard('Tipo de trabajo', _buildTipos());
        case 1: return _seccionCard('Material', _buildMaterialLaser());
        case 2: return _seccionCard('Densidad del grabado', _buildDensidadLaser());
        case 3: return _seccionCard('Medidas', _buildMedidas());
        case 4: return _seccionCard('Extras', _buildExtras());
        default: return const SizedBox();
      }
    }
    // Detectar módulo por tarifas
    final esImpresion3D = _config!.getTarifa('factor_rapida') > 0;
    final esHerreria = _config!.getTarifa('material_hora') > 0 && !esImpresion3D;
    final esCarpinteria = _config!.getTarifa('material_mdf_m2') > 0;

    if (esImpresion3D) {
      switch (tab) {
        case 0: return _seccionCard('Tipo / Calidad', _buildTipos());
        case 1: return _seccionCard('Material', _buildMaterialImpresion());
        case 2: return _seccionCard('Dimensiones', _buildMedidas());
        case 3: return _seccionCard('Acabados y extras', _buildExtrasImpresion());
        default: return const SizedBox();
      }
    }
    if (esHerreria) {
      switch (tab) {
        case 0: return _seccionCard('Tipo de trabajo', _buildTipos());
        case 1: return _seccionCard('Material y acabado', _buildMaterialHerreria());
        case 2: return _seccionCard('Medidas', _buildMedidas());
        case 3: return _seccionCard('Instalación y extras', _buildExtrasHerreria());
        default: return const SizedBox();
      }
    }
    if (esCarpinteria) {
      switch (tab) {
        case 0: return _seccionCard('Tipo de trabajo', _buildTipos());
        case 1: return _seccionCard('Material y acabado', _buildMaterialCarpinteria());
        case 2: return _seccionCard('Medidas', _buildMedidas());
        case 3: return _seccionCard('Extras', _buildExtrasCarpinteria());
        default: return const SizedBox();
      }
    }
    // Router y genérico
    switch (tab) {
      case 0: return _seccionCard('Tipo de trabajo', _buildTipos());
      case 1: return _seccionCard('Medidas y variables', _buildVariables());
      case 2: return _seccionCard('Material', _buildMaterial());
      case 3: return _seccionCard('Acabados', _buildAcabadosRouter());
      case 4: return _seccionCard('Extras', _buildExtras());
      default: return const SizedBox();
    }
  }


  // ── TAB: MEDIDAS (genérico con controllers) ──────
  Widget _buildMedidas() {
    final tipo = _tipoSel;
    if (tipo == null) return const Text('Selecciona un tipo de trabajo primero');
    final formula = tipo.formula;
    return Column(children: [
      if (tipo.necesitaLargo && formula != 'por_minuto') ...[
        _campoMedida('Largo (cm)', _largo, (v) => setState(() { _largo = v; _resultado = null; })),
        const SizedBox(height: 10),
      ],
      if (tipo.necesitaAncho && formula != 'por_minuto') ...[
        _campoMedida('Ancho (cm)', _ancho, (v) => setState(() { _ancho = v; _resultado = null; })),
        const SizedBox(height: 10),
      ],
      if (tipo.necesitaAlto || formula == 'por_volumen') ...[
        _campoMedida('Alto / Profundidad (cm)', _alto,
          (v) => setState(() { _alto = v; _resultado = null; })),
        const SizedBox(height: 10),
      ],
      if (tipo.necesitaHoras || formula == 'por_hora') ...[
        _campoMedida('Horas de trabajo', _horas,
          (v) => setState(() { _horas = v; _resultado = null; })),
        const SizedBox(height: 10),
      ],
      if (tipo.necesitaMinutos || formula == 'por_minuto') ...[
        _campoMedida('Minutos estimados', _minutos,
          (v) => setState(() { _minutos = v; _resultado = null; })),
        const SizedBox(height: 10),
      ],
      if (tipo.necesitaMetros || formula == 'por_metro') ...[
        _campoMedida('Metros lineales', _metros,
          (v) => setState(() { _metros = v; _resultado = null; })),
        const SizedBox(height: 10),
      ],
      if (tipo.necesitaPeso || formula == 'por_kg') ...[
        _campoMedida('Peso (kg)', _peso,
          (v) => setState(() { _peso = v; _resultado = null; })),
        const SizedBox(height: 10),
      ],
      // Cantidad
      Row(children: [
        const Text('Cantidad:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(
          onPressed: () => setState(() { if (_cantidad > 1) { _cantidad--; _resultado = null; } }),
          icon: const Icon(Icons.remove_circle_outline, color: AppColors.azul)),
        Text('$_cantidad', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        IconButton(
          onPressed: () => setState(() { _cantidad++; _resultado = null; }),
          icon: const Icon(Icons.add_circle_outline, color: AppColors.azul)),
      ]),
    ]);
  }

  // ── TAB: CALIBRE (Plasma) ─────────────────────────
  Widget _buildCalibre() => Wrap(spacing: 8, runSpacing: 8,
    children: ['Cal 20','Cal 18','Cal 16','Cal 14','Cal 12',
                'Cal 10','Cal 8','Cal 6','1/4"','3/8"','1/2"+']
      .map((c) => GestureDetector(
        onTap: () => setState(() { _calibre = c; _resultado = null; }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _calibre == c ? AppColors.azul : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _calibre == c ? AppColors.azul : AppColors.grisBorde)),
          child: Column(children: [
            Text(c, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: _calibre == c ? Colors.white : AppColors.textoPrincipal)),
            Text(_calibre == c
              ? (['Cal 20','Cal 18','Cal 16','Cal 14','Cal 12'].contains(c) ? 'Delgado' : 'Medio/Grueso')
              : '',
              style: const TextStyle(fontSize: 9, color: Colors.white70)),
          ])))).toList());

  // ── TAB: MATERIAL PLASMA ──────────────────────────
  Widget _buildMaterialPlasma() => Column(children: [
    Row(children: [
      _chipMaterial('acero_negro', '⚙️ Acero negro', 'Tarifa base'),
      const SizedBox(width: 8),
      _chipMaterial('inox', '✨ Inoxidable', '×1.4'),
      const SizedBox(width: 8),
      _chipMaterial('aluminio', '🔵 Aluminio', '×1.3'),
    ]),
    const SizedBox(height: 12),
    Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        const Icon(Icons.info_outline, size: 14, color: AppColors.azul),
        const SizedBox(width: 6),
        Expanded(child: Text(
          'Los factores de Inox y Aluminio son editables en la sección de Tarifas.',
          style: const TextStyle(fontSize: 11, color: AppColors.azul))),
      ])),
  ]);

  // ── TAB: MATERIAL LÁSER ───────────────────────────
  Widget _buildMaterialLaser() => Wrap(spacing: 8, runSpacing: 8,
    children: [
      {'v':'mdf_fino',    'l':'MDF 2.5mm', 'v2':'30 mm/s'},
      {'v':'mdf_medio',   'l':'MDF 3-5mm', 'v2':'21 mm/s'},
      {'v':'mdf_grueso',  'l':'MDF 6mm+',  'v2':'editable'},
      {'v':'acrilico',    'l':'Acrílico',   'v2':'editable'},
      {'v':'cuero',       'l':'Cuero',      'v2':'editable'},
      {'v':'papel',       'l':'Papel',      'v2':'editable'},
      {'v':'piedra',      'l':'Piedra',     'v2':'editable'},
      {'v':'metal',       'l':'Metal',      'v2':'editable'},
    ].map((m) => GestureDetector(
      onTap: () => setState(() { _materialLaser = m['v']!; _resultado = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _materialLaser == m['v'] ? AppColors.azul : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _materialLaser == m['v'] ? AppColors.azul : AppColors.grisBorde)),
        child: Column(children: [
          Text(m['l']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: _materialLaser == m['v'] ? Colors.white : AppColors.textoPrincipal)),
          Text(m['v2']!, style: TextStyle(fontSize: 9,
            color: _materialLaser == m['v'] ? Colors.white70 : AppColors.textoSecundario)),
        ])))).toList());

  // ── TAB: DENSIDAD LÁSER ───────────────────────────
  Widget _buildDensidadLaser() {
    final tipo = _tipoSel;
    final formula = tipo?.formula ?? '';
    final esGrabado = tipo?.nombre.toLowerCase().contains('grab') == true ||
                      tipo?.nombre.toLowerCase().contains('delin') == true;
    if (!esGrabado) {
      return Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(8)),
        child: const Text('La densidad aplica solo para grabado. Selecciona un tipo de grabado.',
          style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)));
    }
    return Column(children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        _chipDensidad('ligero', 'Ligero', 'Intervalo 0.2mm\n180 mm/s'),
        _chipDensidad('normal', 'Normal', 'Intervalo 0.15mm\n190 mm/s'),
        _chipDensidad('denso', 'Denso', 'Intervalo 0.1mm\n200 mm/s'),
      ]),
    ]);
  }

  Widget _chipDensidad(String val, String titulo, String sub) {
    final sel = _densidadLaser == val;
    return GestureDetector(
      onTap: () => setState(() { _densidadLaser = val; _resultado = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppColors.azul : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde)),
        child: Column(children: [
          Text(titulo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: sel ? Colors.white : AppColors.textoPrincipal)),
          Text(sub, textAlign: TextAlign.center, style: TextStyle(fontSize: 10,
            color: sel ? Colors.white70 : AppColors.textoSecundario)),
        ])));
  }

  // ── TAB: ACABADOS ROUTER ──────────────────────────
  Widget _buildAcabadosRouter() {
    final cfg = _config!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (cfg.acabados.isNotEmpty) ...[
        const Text('Acabado:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8,
          children: cfg.acabados.map((a) => GestureDetector(
            onTap: () => setState(() { _acabadoSel = a; _resultado = null; }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _acabadoSel?.id == a.id ? AppColors.azul : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _acabadoSel?.id == a.id ? AppColors.azul : AppColors.grisBorde)),
              child: Text('${a.nombre} ${a.precio > 0 ? "(+\$${a.precio.toStringAsFixed(0)})" : ""}',
                style: TextStyle(fontSize: 11,
                  color: _acabadoSel?.id == a.id ? Colors.white : AppColors.textoPrincipal))))).toList()),
        const SizedBox(height: 12),
      ],
      _toggleOpcion('🪚 Lleva lijado', _horasLijado > 0,
        (v) => setState(() { _horasLijado = v ? 1.0 : 0; _resultado = null; })),
      if (_horasLijado > 0) ...[
        const SizedBox(height: 6),
        _campoMedida('Horas de lijado', _horasLijado,
          (v) => setState(() { _horasLijado = v; _resultado = null; })),
      ],
      const SizedBox(height: 6),
      _toggleOpcion('🖌️ Lleva barnizado/pintado', _horasBarnizado > 0,
        (v) => setState(() { _horasBarnizado = v ? 1.0 : 0; _resultado = null; })),
      if (_horasBarnizado > 0) ...[
        const SizedBox(height: 6),
        _campoMedida('Horas de barnizado', _horasBarnizado,
          (v) => setState(() { _horasBarnizado = v; _resultado = null; })),
      ],
      const SizedBox(height: 6),
      _toggleOpcion('✏️ Requiere diseño adicional', _llevaDiseno,
        (v) => setState(() { _llevaDiseno = v; _resultado = null; })),
      const Divider(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('IVA 16%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Switch(value: _aplicarIva,
          onChanged: (v) => setState(() { _aplicarIva = v; _resultado = null; }),
          activeColor: AppColors.azul),
      ]),
    ]);
  }

  // ── TAB: EXTRAS PLASMA ────────────────────────────
  Widget _buildExtrasPlasma() => Column(children: [
    _toggleOpcion('🧹 Limpieza de pieza', _llevaLimpieza,
      (v) => setState(() { _llevaLimpieza = v; _resultado = null; })),
    _toggleOpcion('🚚 Flete / Maniobra', _llevaFlete,
      (v) => setState(() { _llevaFlete = v; _resultado = null; })),
    _toggleOpcion('✏️ Diseño adicional', _llevaDisenoPlasma,
      (v) => setState(() { _llevaDisenoPlasma = v; _resultado = null; })),
    if (_llevaDisenoPlasma) ...[
      const SizedBox(height: 8),
      _toggleOpcion('📁 Cliente trae archivo DXF', _clienteTraeArchivoDXF,
        (v) => setState(() { _clienteTraeArchivoDXF = v; _resultado = null; })),
      if (!_clienteTraeArchivoDXF) ...[
        const SizedBox(height: 8),
        _campoMedida('Horas de diseño', _horasDisenoPlasma,
          (v) => setState(() { _horasDisenoPlasma = v; _resultado = null; })),
      ],
    ],
    const Divider(height: 16),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('IVA 16%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      Switch(value: _aplicarIva,
        onChanged: (v) => setState(() { _aplicarIva = v; _resultado = null; }),
        activeColor: AppColors.azul),
    ]),
  ]);


  // ── MATERIAL FIBRA ────────────────────────────────
  Widget _buildMaterialFibra() => Wrap(spacing: 8, runSpacing: 8,
    children: [
      {'v':'acero_inox','l':'Acero Inox','d':'Marcado negro'},
      {'v':'acero_negro','l':'Acero negro','d':'Marcado gris'},
      {'v':'aluminio','l':'Aluminio','d':'Marcado oscuro'},
      {'v':'laton','l':'Latón','d':'Grabado dorado'},
      {'v':'cobre','l':'Cobre','d':'Grabado cobre'},
      {'v':'titanio','l':'Titanio','d':'Coloración'},
    ].map((m) => GestureDetector(
      onTap: () => setState(() { _material = m['v']!; _resultado = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _material == m['v'] ? AppColors.azul : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _material == m['v'] ? AppColors.azul : AppColors.grisBorde)),
        child: Column(children: [
          Text(m['l']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: _material == m['v'] ? Colors.white : AppColors.textoPrincipal)),
          Text(m['d']!, style: TextStyle(fontSize: 9,
            color: _material == m['v'] ? Colors.white70 : AppColors.textoSecundario)),
        ])))).toList());

  // ── EXTRAS FIBRA ─────────────────────────────────
  Widget _buildExtrasFibra() => Column(children: [
    _toggleOpcion('🔧 Plantilla de sujeción (+\$150)', _llevaPlantilla,
      (v) => setState(() { _llevaPlantilla = v; _resultado = null; })),
    _toggleOpcion('🔄 Eje rotativo (+\$25/pza)', _llevaRotativo,
      (v) => setState(() { _llevaRotativo = v; _resultado = null; })),
    _toggleOpcion('✏️ Diseño/Setup', _llevaDisenoFibra,
      (v) => setState(() { _llevaDisenoFibra = v; _resultado = null; })),
    const Divider(height: 16),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('IVA 16%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      Switch(value: _aplicarIva,
        onChanged: (v) => setState(() { _aplicarIva = v; _resultado = null; }),
        activeColor: AppColors.azul),
    ]),
  ]);

  // ── IMPRESIÓN 3D: Material ────────────────────────
  Widget _buildMaterialImpresion() => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Material:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: [
      {'v':'pla', 'l':'PLA', 'd':'Básico'},
      {'v':'abs', 'l':'ABS', 'd':'Resistente'},
      {'v':'petg','l':'PETG','d':'Semi-flex'},
      {'v':'tpu', 'l':'TPU', 'd':'Flexible'},
    ].map((m) => GestureDetector(
      onTap: () => setState(() { _materialImpresion = m['v']!; _resultado = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _materialImpresion == m['v'] ? AppColors.azul : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _materialImpresion == m['v'] ? AppColors.azul : AppColors.grisBorde)),
        child: Column(children: [
          Text(m['l']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: _materialImpresion == m['v'] ? Colors.white : AppColors.textoPrincipal)),
          Text(m['d']!, style: TextStyle(fontSize: 9,
            color: _materialImpresion == m['v'] ? Colors.white70 : AppColors.textoSecundario)),
        ])))).toList()),
    const SizedBox(height: 14),
    const Text('Calidad de impresión:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    Row(children: [
      _chipCalidad('rapida', '⚡ Rapida', 'Menor detalle / Mas barata'),
      const SizedBox(width: 8),
      _chipCalidad('normal', '⚖️ Normal', 'Equilibrio calidad-precio'),
      const SizedBox(width: 8),
      _chipCalidad('alta', '💎 Alta', 'Maximo detalle / Mas tiempo'),
    ]),
  ]);

  Widget _chipCalidad(String val, String titulo, String sub) {
    final sel = _calidadImpresion == val;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() { _calidadImpresion = val; _resultado = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppColors.azul : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde)),
        child: Column(children: [
          Text(titulo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: sel ? Colors.white : AppColors.textoPrincipal), textAlign: TextAlign.center),
          Text(sub, style: TextStyle(fontSize: 9, color: sel ? Colors.white70 : AppColors.textoSecundario),
            textAlign: TextAlign.center),
        ]))));
  }

  // ── HERRERÍA: Material ────────────────────────────
  Widget _buildMaterialHerreria() => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Material:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: [
      'Cuadrado 1"', 'Cuadrado 3/4"', 'Ángulo',
      'Placa', 'Redondo', 'Cliente trae',
    ].map((m) => GestureDetector(
      onTap: () => setState(() { _materialHerreria = m; _clienteTreMaterial = m == 'Cliente trae'; _resultado = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _materialHerreria == m ? AppColors.azul : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _materialHerreria == m ? AppColors.azul : AppColors.grisBorde)),
        child: Text(m, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: _materialHerreria == m ? Colors.white : AppColors.textoPrincipal))))).toList()),
    const SizedBox(height: 12),
    const Text('Acabado:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: [
      'Sin acabado', 'Anticorrosivo', 'Pintura epóxica', 'Galvanizado',
    ].map((a) => GestureDetector(
      onTap: () => setState(() { _acabadoHerreria = a; _resultado = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _acabadoHerreria == a ? AppColors.naranja : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _acabadoHerreria == a ? AppColors.naranja : AppColors.grisBorde)),
        child: Text(a, style: TextStyle(fontSize: 11,
          color: _acabadoHerreria == a ? Colors.white : AppColors.textoPrincipal))))).toList()),
  ]);

  // ── CARPINTERÍA: Material ─────────────────────────
  Widget _buildMaterialCarpinteria() => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Material:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: [
      {'v':'mdf','l':'MDF','d':'\$320/m²'},
      {'v':'triplay','l':'Triplay','d':'\$450/m²'},
      {'v':'cedro','l':'Cedro','d':'\$800+/m²'},
      {'v':'parota','l':'Parota','d':'\$1,000+/m²'},
      {'v':'caoba','l':'Caoba','d':'\$900+/m²'},
      {'v':'cliente','l':'Cliente trae','d':'Sin costo'},
    ].map((m) => GestureDetector(
      onTap: () => setState(() {
        _materialCarpinteria = m['v']!;
        _clienteTreMaterial = m['v'] == 'cliente';
        _resultado = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _materialCarpinteria == m['v'] ? AppColors.azul : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _materialCarpinteria == m['v'] ? AppColors.azul : AppColors.grisBorde)),
        child: Column(children: [
          Text(m['l']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: _materialCarpinteria == m['v'] ? Colors.white : AppColors.textoPrincipal)),
          Text(m['d']!, style: TextStyle(fontSize: 9,
            color: _materialCarpinteria == m['v'] ? Colors.white70 : AppColors.textoSecundario)),
        ])))).toList()),
    const SizedBox(height: 12),
    const Text('Acabado:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: [
      'Sin acabado', 'Barniz', 'Pintura', 'Sellador', 'Laminado',
    ].map((a) => GestureDetector(
      onTap: () => setState(() { _acabadoCarpinteria = a; _resultado = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _acabadoCarpinteria == a ? AppColors.naranja : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _acabadoCarpinteria == a ? AppColors.naranja : AppColors.grisBorde)),
        child: Text(a, style: TextStyle(fontSize: 11,
          color: _acabadoCarpinteria == a ? Colors.white : AppColors.textoPrincipal))))).toList()),
  ]);


  Widget _buildExtrasImpresion() => Column(children: [
    _toggleOpcion('🎨 Incluir modelado 3D', _llevaDisenyo3D,
      (v) => setState(() { _llevaDisenyo3D = v; _resultado = null; })),
    _toggleOpcion('✨ Post-proceso (lijado/pintura)', _llevaPostProceso,
      (v) => setState(() { _llevaPostProceso = v; _resultado = null; })),
    const Divider(height: 16),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('IVA 16%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      Switch(value: _aplicarIva,
        onChanged: (v) => setState(() { _aplicarIva = v; _resultado = null; }),
        activeColor: AppColors.azul),
    ]),
  ]);

  Widget _buildExtrasHerreria() => Column(children: [
    _toggleOpcion('🔧 Incluir instalación', _llevaInstalacion,
      (v) => setState(() { _llevaInstalacion = v; _resultado = null; })),
    if (_llevaInstalacion) ...[
      const SizedBox(height: 8),
      _campoMedida('Horas de instalación', _horasInstalacion,
        (v) => setState(() { _horasInstalacion = v; _resultado = null; })),
    ],
    const Divider(height: 16),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('IVA 16%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      Switch(value: _aplicarIva,
        onChanged: (v) => setState(() { _aplicarIva = v; _resultado = null; }),
        activeColor: AppColors.azul),
    ]),
  ]);

  Widget _buildExtrasCarpinteria() => Column(children: [
    _toggleOpcion('🔩 Incluir herrajes', _llevaHerrajes,
      (v) => setState(() { _llevaHerrajes = v; _resultado = null; })),
    _toggleOpcion('🔧 Incluir instalación', _llevaInstalacionCarp,
      (v) => setState(() { _llevaInstalacionCarp = v; _resultado = null; })),
    if (_llevaInstalacionCarp) ...[
      const SizedBox(height: 8),
      _campoMedida('Horas de instalación', _horasInstalacionCarp,
        (v) => setState(() { _horasInstalacionCarp = v; _resultado = null; })),
    ],
    const Divider(height: 16),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('IVA 16%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      Switch(value: _aplicarIva,
        onChanged: (v) => setState(() { _aplicarIva = v; _resultado = null; }),
        activeColor: AppColors.azul),
    ]),
  ]);
  // ── TIPOS DE TRABAJO ─────────────────────────────
  Widget _buildTipos() {
    final cfg = _config!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8,
        children: cfg.tipos.map((t) {
          final sel = _tipoSel?.id == t.id;
          return GestureDetector(
            onTap: () => setState(() { _tipoSel = t; _resultado = null; }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppColors.azul : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.nombre, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppColors.textoPrincipal)),
                if (t.descripcionFormula != null) Text(t.descripcionFormula!,
                  style: TextStyle(fontSize: 9, color: sel ? Colors.white70 : AppColors.textoSecundario)),
              ])));
        }).toList()),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _nuevoModo,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.azul.withOpacity(0.3))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add, size: 14, color: AppColors.azul),
            SizedBox(width: 4),
            Text('Agregar modo', style: TextStyle(fontSize: 11, color: AppColors.azul, fontWeight: FontWeight.w600)),
          ]))),
    ]);
  }

  // ── TARIFAS EDITABLES ────────────────────────────
  Widget _seccionTarifas() {
    final cfg = _config!;
    if (cfg.tarifas.isEmpty) return const SizedBox();
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grisBorde, width: 0.5)),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _mostrarTarifas = !_mostrarTarifas),
          child: Padding(padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.tune_outlined, size: 18, color: AppColors.azul),
              const SizedBox(width: 8),
              Expanded(child: Text('Tarifas de ${_tipoSel?.nombre ?? "este modo"}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.azul))),
              Icon(_mostrarTarifas ? Icons.expand_less : Icons.expand_more, color: AppColors.azul),
            ]))),
        if (_mostrarTarifas) ...[
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(14), child: Column(children: [
            ...cfg.tarifas.values.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.nombre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  if (t.unidad != null) Text(t.unidad!,
                    style: const TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
                ])),
                const SizedBox(width: 10),
                SizedBox(width: 100, child: TextFormField(
                  controller: _tarifasCtrls[t.id],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(isDense: true, filled: true,
                    fillColor: AppColors.gris, prefixText: r'$',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
              ]))),
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _guardarTarifas,
                icon: const Icon(Icons.save_outlined, size: 16, color: AppColors.verde),
                label: const Text('Guardar tarifas',
                  style: TextStyle(color: AppColors.verde, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.verde)))),
          ])),
        ],
      ]));
  }

  Future<void> _guardarTarifas() async {
    final cfg = _config!;
    for (final t in cfg.tarifas.values) {
      final val = double.tryParse(_tarifasCtrls[t.id]?.text ?? '');
      if (val != null && val != t.valor) {
        await SimuladorDataService.actualizarTarifa(t.id, val);
        t.valor = val;
      }
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('✅ Tarifas guardadas'), backgroundColor: AppColors.verde));
  }

  // ── VARIABLES SEGÚN FÓRMULA ──────────────────────
  Widget _buildVariables() {
    final tipo = _tipoSel!;
    final formula = tipo.formula;

    if (formula == 'por_diseno') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ¿El cliente trae archivo?
        const Text('Estado del archivo:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _chipArchivo(false, false, '🎨 Diseñar desde cero')),
          const SizedBox(width: 6),
          Expanded(child: _chipArchivo(true, false, '🖼️ Cliente trae imagen')),
          const SizedBox(width: 6),
          Expanded(child: _chipArchivo(true, true, '✅ Trae vector listo')),
        ]),
        const SizedBox(height: 12),

        // Si no trae vector listo, mostrar tipos
        if (!(_clienteTraeArchivo && _archivoEsVector)) ...[
          const Text('El tipo de trabajo ya determina el precio:',
            style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(8)),
            child: Text(
              '${_tipoSel?.nombre ?? ""} — ${_tipoSel?.descripcionFormula ?? ""}',
              style: const TextStyle(fontSize: 12, color: AppColors.azul, fontWeight: FontWeight.w600))),
          const SizedBox(height: 12),
        ],

        // Opciones adicionales
        const Text('Opciones:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _toggleOpcion('🚀 Entrega urgente (+40%)', _entregaUrgente,
          (v) => setState(() { _entregaUrgente = v; _resultado = null; })),
        _toggleOpcion('📁 Entregar archivo editable (.AI/.DXF) (+200%)',
          _archivoEditableAlCliente,
          (v) => setState(() { _archivoEditableAlCliente = v; _resultado = null; })),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Revisiones extra (+\$150 c/u):', style: TextStyle(fontSize: 12)),
          const Spacer(),
          IconButton(
            onPressed: () => setState(() { if (_revisionesExtra > 0) { _revisionesExtra--; _resultado = null; } }),
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.azul, size: 20)),
          Text('$_revisionesExtra', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          IconButton(
            onPressed: () => setState(() { _revisionesExtra++; _resultado = null; }),
            icon: const Icon(Icons.add_circle_outline, color: AppColors.azul, size: 20)),
        ]),
      ]);
    }

    if (formula == 'precio_fijo') {
      return Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(8)),
        child: const Text('Precio fijo negociado. Edita la tarifa "precio_fijo" arriba.',
          style: TextStyle(fontSize: 12, color: AppColors.azul)));
    }

    // Detectar si es Plasma
    final _config2 = _config!;
    final esPlasmaScreen = _config2.getTarifa('tarifa_m2_delgado') > 0 ||
                           _config2.getTarifa('tarifa_metro_delgado') > 0;
    final esRouter2D = formula == 'por_area' && !esPlasmaScreen;

    // ── PLASMA: Selector calibre y material ──────────
    if (esPlasmaScreen) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Calibre
        const Text('Calibre del material:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6,
          children: ['Cal 20','Cal 18','Cal 16','Cal 14','Cal 12','Cal 10','Cal 8','Cal 6','1/4"','3/8"','1/2"+']
            .map((c) => GestureDetector(
              onTap: () => setState(() { _calibre = c; _resultado = null; }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _calibre == c ? AppColors.azul : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _calibre == c ? AppColors.azul : AppColors.grisBorde)),
                child: Text(c, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: _calibre == c ? Colors.white : AppColors.textoPrincipal))))).toList()),

        const SizedBox(height: 12),

        // Material
        const Text('Material:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          _chipMaterial('acero_negro', '⚙️ Acero negro', 'Tarifa base'),
          const SizedBox(width: 8),
          _chipMaterial('inox', '✨ Inoxidable', '×1.4'),
          const SizedBox(width: 8),
          _chipMaterial('aluminio', '🔵 Aluminio', '×1.3'),
        ]),

        const SizedBox(height: 12),

        // Dimensiones según tipo
        if (formula == 'por_area' || formula == 'por_metro') ...[
          if (tipo.necesitaLargo) ...[
            _campoMedida('Largo (cm)', _largo, (v) => setState(() { _largo = v; _resultado = null; })),
            const SizedBox(height: 10),
          ],
          if (tipo.necesitaAncho) ...[
            _campoMedida('Ancho (cm)', _ancho, (v) => setState(() { _ancho = v; _resultado = null; })),
            const SizedBox(height: 10),
          ],
          if (tipo.necesitaMetros) ...[
            _campoMedida('Metros lineales', _metros, (v) => setState(() { _metros = v; _resultado = null; })),
            const SizedBox(height: 10),
          ],
        ],

        const Divider(height: 16),

        // Adicionales Plasma
        const Text('Adicionales:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _toggleOpcion('🧹 Incluir limpieza de pieza', _llevaLimpieza,
          (v) => setState(() { _llevaLimpieza = v; _resultado = null; })),
        _toggleOpcion('🚚 Incluir flete/maniobra', _llevaFlete,
          (v) => setState(() { _llevaFlete = v; _resultado = null; })),
        _toggleOpcion('✏️ Incluir diseño', _llevaDisenoPlasma,
          (v) => setState(() { _llevaDisenoPlasma = v; _resultado = null; })),
        if (_llevaDisenoPlasma) ...[
          const SizedBox(height: 8),
          _toggleOpcion('📁 Cliente trae archivo DXF', _clienteTraeArchivoDXF,
            (v) => setState(() { _clienteTraeArchivoDXF = v; _resultado = null; })),
          if (!_clienteTraeArchivoDXF) ...[
            const SizedBox(height: 8),
            _campoMedida('Horas de diseño', _horasDisenoPlasma,
              (v) => setState(() { _horasDisenoPlasma = v; _resultado = null; })),
          ],
        ],
      ]);
    }

    return Column(children: [
      if (tipo.necesitaLargo && formula != 'por_minuto') ...[
        _campoMedida('Largo (cm)', _largo, (v) => setState(() { _largo = v; _resultado = null; })),
        const SizedBox(height: 10),
      ],
      if (tipo.necesitaAncho && formula != 'por_minuto') ...[
        _campoMedida('Ancho (cm)', _ancho, (v) => setState(() { _ancho = v; _resultado = null; })),
        const SizedBox(height: 10),
      ],
      if (tipo.necesitaAlto || formula == 'por_volumen') ...[
        _campoMedida('Alto / Profundidad (cm)', _alto,
          (v) => setState(() { _alto = v; _resultado = null; })),
        const SizedBox(height: 10),
      ],
      if (tipo.necesitaHoras || formula == 'por_hora') ...[
        _campoMedida('Horas de trabajo', _horas,
          (v) => setState(() { _horas = v; _resultado = null; })),
        const SizedBox(height: 10),
      ],
      if (tipo.necesitaMinutos || formula == 'por_minuto') ...[
        _campoMedida('Minutos estimados', _minutos,
          (v) => setState(() { _minutos = v; _resultado = null; })),
        const SizedBox(height: 10),
        if (formula == 'por_minuto' && _largo > 0 && _ancho > 0 && _minutos == 0)
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(8)),
            child: const Text('💡 Si no sabes los minutos exactos, '
              'deja en 0 y el sistema estimará según el área.',
              style: TextStyle(fontSize: 11, color: AppColors.azul))),
      ],
      if (tipo.necesitaMetros || formula == 'por_metro') ...[
        _campoMedida('Metros lineales', _metros,
          (v) => setState(() { _metros = v; _resultado = null; })),
        const SizedBox(height: 10),
      ],
      if (tipo.necesitaPeso || formula == 'por_kg') ...[
        _campoMedida('Peso (kg)', _peso,
          (v) => setState(() { _peso = v; _resultado = null; })),
        const SizedBox(height: 10),
      ],
      // Opciones adicionales Router 2D
      if (esRouter2D) ...[
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),
        const Text('Acabado manual (opcional):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _toggleOpcion('🪚 Lleva lijado', _horasLijado > 0,
          (v) => setState(() { _horasLijado = v ? 1.0 : 0; _resultado = null; })),
        if (_horasLijado > 0) ...[
          const SizedBox(height: 6),
          _campoMedida('Horas de lijado', _horasLijado,
            (v) => setState(() { _horasLijado = v; _resultado = null; })),
        ],
        const SizedBox(height: 8),
        _toggleOpcion('🖌️ Lleva barnizado/pintado', _horasBarnizado > 0,
          (v) => setState(() { _horasBarnizado = v ? 1.0 : 0; _resultado = null; })),
        if (_horasBarnizado > 0) ...[
          const SizedBox(height: 6),
          _campoMedida('Horas de barnizado', _horasBarnizado,
            (v) => setState(() { _horasBarnizado = v; _resultado = null; })),
        ],
        const SizedBox(height: 8),
        _toggleOpcion('✏️ Requiere diseño adicional', _llevaDiseno,
          (v) => setState(() { _llevaDiseno = v; _resultado = null; })),
      ],

      // Complejidad para volumétrico
      if (formula == 'por_volumen') ...[
        const Text('Complejidad del tallado:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8,
          children: [
            _chipComp('simple', 'Simple', 'Relieve bajo < 1cm'),
            _chipComp('media', 'Media', 'Relieve normal 1-2cm'),
            _chipComp('alta', 'Alta', 'Escultura > 2cm'),
            _chipComp('premium', 'Premium', 'Escultura compleja'),
          ]),
      ],
    ]);
  }

  Widget _chipMaterial(String val, String titulo, String sub) {
    final sel = _material == val;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() { _material = val; _resultado = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.azul : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde)),
        child: Column(children: [
          Text(titulo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: sel ? Colors.white : AppColors.textoPrincipal)),
          Text(sub, style: TextStyle(fontSize: 9,
            color: sel ? Colors.white70 : AppColors.textoSecundario)),
        ]))));
  }

  Widget _chipArchivo(bool trae, bool esVector, String label) {
    final sel = _clienteTraeArchivo == trae && _archivoEsVector == esVector;
    return GestureDetector(
      onTap: () => setState(() {
        _clienteTraeArchivo = trae;
        _archivoEsVector = esVector;
        _resultado = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.azul : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde)),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: sel ? Colors.white : AppColors.textoPrincipal))));
  }

  Widget _toggleOpcion(String label, bool val, void Function(bool) onChange) =>
    GestureDetector(
      onTap: () => onChange(!val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: val ? AppColors.azulClaro : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: val ? AppColors.azul : AppColors.grisBorde)),
        child: Row(children: [
          Icon(val ? Icons.check_box_outlined : Icons.check_box_outline_blank,
            size: 18, color: val ? AppColors.azul : AppColors.grisBorde),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 12,
            color: val ? AppColors.azul : AppColors.textoPrincipal,
            fontWeight: val ? FontWeight.w600 : FontWeight.normal))),
        ])));

  Widget _chipComp(String val, String titulo, String sub) {
    final sel = _complejidad == val;
    return GestureDetector(
      onTap: () => setState(() { _complejidad = val; _resultado = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.azul : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? AppColors.azul : AppColors.grisBorde)),
        child: Column(children: [
          Text(titulo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: sel ? Colors.white : AppColors.textoPrincipal)),
          Text(sub, style: TextStyle(fontSize: 9, color: sel ? Colors.white70 : AppColors.textoSecundario)),
        ])));
  }

  // ── MATERIAL ─────────────────────────────────────
  Widget _buildMaterial() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Cliente trae el material', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text('No suma costo de material', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
      ]),
      Switch(value: _clienteTreMaterial,
        onChanged: (v) => setState(() { _clienteTreMaterial = v; _resultado = null; }),
        activeColor: AppColors.verde),
    ]),
    if (!_clienteTreMaterial) ...[
      const SizedBox(height: 12),
      const Divider(height: 1),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => setState(() => _usarInventario = true),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _usarInventario ? AppColors.azul : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _usarInventario ? AppColors.azul : AppColors.grisBorde)),
            child: Column(children: [
              Icon(Icons.warehouse_outlined, size: 16,
                color: _usarInventario ? Colors.white : AppColors.textoSecundario),
              Text('Del inventario', style: TextStyle(fontSize: 11,
                color: _usarInventario ? Colors.white : AppColors.textoSecundario,
                fontWeight: FontWeight.w600)),
            ])))),
        const SizedBox(width: 8),
        Expanded(child: GestureDetector(
          onTap: () => setState(() => _usarInventario = false),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: !_usarInventario ? AppColors.azul : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: !_usarInventario ? AppColors.azul : AppColors.grisBorde)),
            child: Column(children: [
              Icon(Icons.edit_outlined, size: 16,
                color: !_usarInventario ? Colors.white : AppColors.textoSecundario),
              Text('Captura manual', style: TextStyle(fontSize: 11,
                color: !_usarInventario ? Colors.white : AppColors.textoSecundario,
                fontWeight: FontWeight.w600)),
            ])))),
      ]),
      const SizedBox(height: 12),
      if (_usarInventario) ...[
        if (_materialesInv.isEmpty)
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(8)),
            child: const Text('Sin materiales en inventario. Usa captura manual.',
              style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)))
        else
          DropdownButtonFormField<String>(
            value: _materialInvSel?['id'] as String?,
            decoration: const InputDecoration(labelText: 'Material del inventario',
              border: OutlineInputBorder(), isDense: true,
              prefixIcon: Icon(Icons.search, size: 18)),
            items: [
              const DropdownMenuItem<String>(value: null,
                child: Text('Sin material', style: TextStyle(fontSize: 13))),
              ..._materialesInv.map((m) => DropdownMenuItem<String>(
                value: m['id'] as String,
                child: Row(children: [
                  Expanded(child: Text(m['nombre'] ?? '', style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis)),
                  Text('\$${((m['costo_unitario'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.verde, fontWeight: FontWeight.w700)),
                ]))),
            ],
            onChanged: (id) => setState(() {
              _materialInvSel = id == null ? null
                : _materialesInv.firstWhere((m) => m['id'] == id);
              _resultado = null;
            })),
        if (_materialInvSel != null) ...[
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.verde.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8)),
            child: Text('Stock: ${_materialInvSel!['stock_actual']} ${_materialInvSel!['unidad'] ?? 'pzas'}  '
              '|  Costo: \$${((_materialInvSel!['costo_unitario'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}/pza '
              '(+15% merma incluida)',
              style: const TextStyle(fontSize: 11))),
        ],
      ] else ...[
        Row(children: [
          Expanded(child: TextFormField(
            initialValue: _materialLibreNombre,
            decoration: const InputDecoration(labelText: 'Nombre del material',
              hintText: 'Ej: Cedro, MDF 15mm, Acrílico...',
              border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => setState(() { _materialLibreNombre = v; _resultado = null; }),
            style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: TextFormField(
            initialValue: _materialLibrePrecio > 0 ? _materialLibrePrecio.toStringAsFixed(2) : '',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: const InputDecoration(labelText: 'Precio', prefixText: r'$',
              border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => setState(() {
              _materialLibrePrecio = double.tryParse(v) ?? 0; _resultado = null; }),
            style: const TextStyle(fontSize: 13))),
        ]),
        const SizedBox(height: 4),
        const Text('Se agrega automáticamente +15% de merma.',
          style: TextStyle(fontSize: 10, color: AppColors.textoSecundario)),
      ],
    ],
  ]);

  // ── CANTIDAD Y EXTRAS ────────────────────────────
  Widget _buildExtras() {
    final cfg = _config!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Cantidad:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(
          onPressed: () => setState(() { if (_cantidad > 1) { _cantidad--; _resultado = null; } }),
          icon: const Icon(Icons.remove_circle_outline, color: AppColors.azul)),
        Text('$_cantidad', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        IconButton(
          onPressed: () => setState(() { _cantidad++; _resultado = null; }),
          icon: const Icon(Icons.add_circle_outline, color: AppColors.azul)),
      ]),
      if (cfg.acabados.isNotEmpty) ...[
        const Divider(height: 16),
        const Text('Acabado:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8,
          children: cfg.acabados.map((a) => GestureDetector(
            onTap: () => setState(() { _acabadoSel = a; _resultado = null; }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _acabadoSel?.id == a.id ? AppColors.azul : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _acabadoSel?.id == a.id ? AppColors.azul : AppColors.grisBorde)),
              child: Text('${a.nombre} ${a.precio > 0 ? "(+\$${a.precio.toStringAsFixed(0)})" : ""}',
                style: TextStyle(fontSize: 11,
                  color: _acabadoSel?.id == a.id ? Colors.white : AppColors.textoPrincipal))))).toList()),
      ],
      if (cfg.extras.isNotEmpty) ...[
        const Divider(height: 16),
        const Text('Extras:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ...cfg.extras.map((e) => CheckboxListTile(
          value: e.seleccionado,
          onChanged: (v) => setState(() { e.seleccionado = v ?? false; _resultado = null; }),
          title: Text(e.nombre, style: const TextStyle(fontSize: 13)),
          subtitle: Text('+${_fmt.format(e.precio)}',
            style: const TextStyle(fontSize: 11, color: AppColors.verde)),
          activeColor: AppColors.azul, dense: true, contentPadding: EdgeInsets.zero)),
      ],
      const Divider(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Incluir IVA 16%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('Para clientes con factura', style: TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ]),
        Switch(value: _aplicarIva,
          onChanged: (v) => setState(() { _aplicarIva = v; _resultado = null; }),
          activeColor: AppColors.azul),
      ]),
    ]);
  }

  // ── RESULTADO CON 3 PRECIOS Y GRÁFICAS ───────────
  Widget _widgetResultado(ResultadoSimulador r) {
    final fmt = NumberFormat(r'$#,##0', 'es_MX');

    final precios = [
      ResultadoPrecio(
        etiqueta: 'PRECIO MÍNIMO', emoji: '🟡',
        descripcion: 'Cubre costos, margen mínimo.\n⚠️ Úsalo solo en casos especiales o clientes frecuentes.',
        costo: r.costoTotal, precio: r.pvMinimo,
        utilidad: r.pvMinimo - r.costoTotal,
        margen: r.costoTotal > 0 ? ((r.pvMinimo - r.costoTotal)/r.pvMinimo*100) : 0,
        color: AppColors.ambar),
      ResultadoPrecio(
        etiqueta: 'PRECIO RECOMENDADO', emoji: '🟢',
        descripcion: 'Precio competitivo y rentable.\n✅ Recomendado para la mayoría de trabajos.',
        costo: r.costoTotal, precio: r.pvRecomendado,
        utilidad: r.pvRecomendado - r.costoTotal,
        margen: r.costoTotal > 0 ? ((r.pvRecomendado - r.costoTotal)/r.pvRecomendado*100) : 0,
        color: AppColors.verde, esRecomendado: true),
      ResultadoPrecio(
        etiqueta: 'PRECIO PREMIUM', emoji: '🔵',
        descripcion: 'Para clientes de alto valor o trabajos urgentes.\n💎 Aumenta la rentabilidad del negocio.',
        costo: r.costoTotal, precio: r.pvPremium,
        utilidad: r.pvPremium - r.costoTotal,
        margen: r.costoTotal > 0 ? ((r.pvPremium - r.costoTotal)/r.pvPremium*100) : 0,
        color: AppColors.azul),
    ];

    int precioSelIdx = 1; // Recomendado por default

    return StatefulBuilder(builder: (ctx, setS) => Column(children: [

      // ── 3 PRECIOS ──────────────────────────────
      ...precios.asMap().entries.map((entry) {
        final i = entry.key; final p = entry.value;
        final sel = precioSelIdx == i;
        return GestureDetector(
          onTap: () => setS(() => precioSelIdx = i),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: sel ? p.color.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? p.color : AppColors.grisBorde,
                width: sel ? 2 : 0.5)),
            child: Column(children: [
              Row(children: [
                Text(p.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.etiqueta, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: p.color, letterSpacing: 0.5)),
                  Row(children: [
                    Text(fmt.format(p.precio),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.color)),
                    if (r.incluyeIva) ...[
                      const SizedBox(width: 8),
                      Text('+IVA: ${fmt.format(p.precio * 0.16)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                    ],
                  ]),
                ])),
                if (p.esRecomendado) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.verde,
                    borderRadius: BorderRadius.circular(20)),
                  child: const Text('✓ MEJOR', style: TextStyle(fontSize: 9,
                    color: Colors.white, fontWeight: FontWeight.w700))),
                if (sel && !p.esRecomendado) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: p.color,
                    borderRadius: BorderRadius.circular(20)),
                  child: const Text('ELEGIDO', style: TextStyle(fontSize: 9,
                    color: Colors.white, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _kpiPrecio('Costo', fmt.format(p.costo), AppColors.textoSecundario),
                _kpiPrecio('Utilidad', fmt.format(p.utilidad), p.color),
                _kpiPrecio('Margen', '${p.margen.toStringAsFixed(1)}%', p.color),
                _kpiPrecio('Gan/hr', fmt.format(r.gananciaHora), AppColors.textoSecundario),
              ]),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.gris, borderRadius: BorderRadius.circular(8)),
                child: Text(p.descripcion, style: const TextStyle(fontSize: 11, color: AppColors.textoPrincipal))),
            ])));
      }),

      // ── GRÁFICA DE DESGLOSE ─────────────────────
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DESGLOSE DE COSTOS', style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w700, color: AppColors.textoSecundario, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          ...r.costosDesglose.entries
            .where((e) => e.value > 0)
            .map((e) {
              final pct = r.costoTotal > 0 ? e.value / r.costoTotal : 0.0;
              final color = _colorCosto(e.key);
              return Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(e.key, style: const TextStyle(fontSize: 12)),
                  Row(children: [
                    Text('${(pct*100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                    const SizedBox(width: 8),
                    Text(fmt.format(e.value),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                  ]),
                ]),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: pct.toDouble(), backgroundColor: AppColors.gris,
                  valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6,
                  borderRadius: BorderRadius.circular(3)),
              ]));
            }),
          const Divider(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('COSTO TOTAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text(fmt.format(r.costoTotal),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.rojo)),
          ]),
        ])),

      // ── OBSERVACIONES AUTOMÁTICAS ───────────────
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.azulClaro, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.azul.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.lightbulb_outline, size: 16, color: AppColors.azul),
            SizedBox(width: 6),
            Text('Observaciones financieras', style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w700, color: AppColors.azul)),
          ]),
          const SizedBox(height: 10),
          ..._generarObservaciones(r, fmt),
        ])),

      // ── DESCRIPCIÓN EDITABLE ─────────────────────
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grisBorde, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Descripción para cotización:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textoSecundario)),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _descripcionEditable,
            maxLines: 4, minLines: 2,
            onChanged: (v) => setState(() => _descripcionEditable = v),
            decoration: InputDecoration(hintText: 'Descripción del trabajo...',
              filled: true, fillColor: AppColors.gris,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            style: const TextStyle(fontSize: 12)),
        ])),

      // ── BOTONES ─────────────────────────────────
      const SizedBox(height: 14),
      SizedBox(width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            final rFinal = _resultadoConPrecio(r, precioSelIdx);
            widget.onAgregar(rFinal);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.add_shopping_cart_outlined, color: Colors.white, size: 16),
          label: const Text('Agregar al carrito',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde,
            padding: const EdgeInsets.symmetric(vertical: 12)))),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            final rFinal = _resultadoConPrecio(r, precioSelIdx);
            widget.onAgregar(rFinal);
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => CotizarScreen(carritoSimulador: [rFinal])));
          },
          icon: const Icon(Icons.description_outlined, color: Colors.white, size: 16),
          label: const Text('Cotizar ahora',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.naranja,
            padding: const EdgeInsets.symmetric(vertical: 12)))),
    ]));
  }

  ResultadoSimulador _resultadoConPrecio(ResultadoSimulador r, int idx) {
    final precios = [r.pvMinimo, r.pvRecomendado, r.pvPremium];
    final precio = precios[idx];
    final iva = r.incluyeIva ? precio * 0.16 : 0.0;
    return ResultadoSimulador(
      servicio: r.servicio, emoji: r.emoji,
      descripcion: _descripcionEditable.isNotEmpty ? _descripcionEditable : r.descripcion,
      total: precio + iva, subtotal: precio, iva: iva,
      costoTotal: r.costoTotal, pvMinimo: r.pvMinimo,
      pvRecomendado: r.pvRecomendado, pvPremium: r.pvPremium,
      utilidad: precio - r.costoTotal,
      margenReal: precio > 0 ? ((precio - r.costoTotal)/precio*100) : 0,
      gananciaHora: r.tiempoHoras > 0 ? (precio - r.costoTotal)/r.tiempoHoras : 0,
      tiempoHoras: r.tiempoHoras,
      cm: r.cm, cmo: r.cmo, cmaq: r.cmaq, cc: r.cc, ca: r.ca, ci: r.ci,
      costosDesglose: r.costosDesglose, incluyeIva: r.incluyeIva,
      materialNombre: r.materialNombre, maquila: precio,
      costoMaterial: r.cm, acabado: r.ca, extras: r.extras);
  }

  List<Widget> _generarObservaciones(ResultadoSimulador r, NumberFormat fmt) {
    final obs = <Widget>[];

    // Observación margen
    if (r.margenReal < 20) {
      obs.add(_obs('⚠️ Margen bajo (${r.margenReal.toStringAsFixed(1)}%)',
        'Este trabajo apenas cubre costos. Considera aumentar el precio o reducir el material.', AppColors.rojo));
    } else if (r.margenReal >= 40) {
      obs.add(_obs('✅ Excelente margen (${r.margenReal.toStringAsFixed(1)}%)',
        'Este trabajo es muy rentable. Mantén este precio como referencia.', AppColors.verde));
    } else {
      obs.add(_obs('👍 Margen saludable (${r.margenReal.toStringAsFixed(1)}%)',
        'El precio recomendado es competitivo y cubre bien los costos.', AppColors.azul));
    }

    // Observación material
    final pctMat = r.costoTotal > 0 ? (r.cm / r.costoTotal * 100) : 0;
    if (pctMat > 40) {
      obs.add(_obs('📦 Material: ${pctMat.toStringAsFixed(0)}% del costo',
        'El material es el mayor costo. Busca precio de mayoreo con tu proveedor.', AppColors.naranja));
    }

    // Observación tiempo
    if (r.tiempoHoras > 0) {
      obs.add(_obs('⏱️ Tiempo estimado: ${r.tiempoHoras.toStringAsFixed(1)} horas',
        'Ganancia por hora: ${fmt.format(r.gananciaHora)}. '
        '${r.gananciaHora > 200 ? "Trabajo muy rentable." : r.gananciaHora > 100 ? "Rentabilidad aceptable." : "Considera ajustar el precio."}',
        AppColors.azul));
    }

    // Observación costos taller
    final pctCI = r.costoTotal > 0 ? (r.ci / r.costoTotal * 100) : 0;
    if (pctCI < 5 && (_costosTaller?.costoHoraTaller ?? 0) < 1) {
      obs.add(_obs('💡 Configura tus costos fijos',
        'Ve a "Costos del taller" y agrega renta, luz y salarios para calcular el precio real.',
        AppColors.ambar));
    }

    return obs;
  }

  Widget _obs(String titulo, String detalle, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 3, height: 40, color: color, margin: const EdgeInsets.only(right: 8, top: 2)),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        Text(detalle, style: const TextStyle(fontSize: 11, color: AppColors.textoPrincipal)),
      ])),
    ]));

  Color _colorCosto(String key) {
    switch (key) {
      case 'Material': return AppColors.naranja;
      case 'Máquina': return AppColors.azul;
      case 'Operador': return AppColors.verde;
      case 'Consumibles': return const Color(0xFF7c3aed);
      case 'Acabado': return const Color(0xFF0891b2);
      case 'Taller (CI)': return AppColors.rojo;
      default: return AppColors.textoSecundario;
    }
  }

  Widget _kpiPrecio(String label, String val, Color color) =>
    Expanded(child: Column(children: [
      Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textoSecundario)),
    ]));

  // ── HELPERS ──────────────────────────────────────
  Widget _seccionCard(String titulo, Widget child) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.grisBorde, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(14,12,14,8),
        child: Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.azul))),
      const Divider(height: 1),
      Padding(padding: const EdgeInsets.all(14), child: child),
    ]));

  // Mapa de controllers por label para reutilizar
  final Map<String, TextEditingController> _medidaCtrls = {};

  TextEditingController _ctrlForMedida(String label, double val) {
    if (!_medidaCtrls.containsKey(label)) {
      _medidaCtrls[label] = TextEditingController(
        text: val > 0 ? val.toStringAsFixed(val % 1 == 0 ? 0 : 1) : '');
    }
    return _medidaCtrls[label]!;
  }

  Widget _campoMedida(String label, double val, void Function(double) onChange) {
    final ctrl = _ctrlForMedida(label, val);
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true),
      onChanged: (v) => onChange(double.tryParse(v) ?? 0),
      style: const TextStyle(fontSize: 13));
  }

  void _nuevoModo() {
    final nombreCtrl = TextEditingController();
    String formula = 'por_area';
    final formulas = [
      {'v':'por_area','l':'Por m²','d':'Largo × Ancho × Tarifa/m²'},
      {'v':'por_volumen','l':'Por volumen','d':'L×A×Alto × Factor → Precio'},
      {'v':'por_hora','l':'Por hora','d':'Horas × Tarifa/hora'},
      {'v':'por_minuto','l':'Por minuto','d':'Minutos × Tarifa/minuto'},
      {'v':'por_metro','l':'Por metro','d':'Metros × Tarifa/metro'},
      {'v':'precio_fijo','l':'Precio fijo','d':'Monto fijo negociado'},
      {'v':'por_kg','l':'Por kg','d':'Peso × Tarifa/kg'},
      {'v':'por_pieza','l':'Por pieza','d':'Cantidad × Precio/pieza'},
      {'v':'por_diseno','l':'Diseño','d':'Simple/Media/Alta/Premium'},
    ];
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (_, setS) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16,16,16,12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Nuevo modo de trabajo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close)),
            ])),
          const Divider(height: 1),
          Expanded(child: SingleChildScrollView(
            padding: EdgeInsets.only(left:16, right:16, top:12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(controller: nombreCtrl, textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre del modo *',
                  hintText: 'Ej: Corte 2D, Talla 3D, Grabado...',
                  border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 16),
              const Text('¿Cómo se cobra?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...formulas.map((f) => GestureDetector(
                onTap: () => setS(() => formula = f['v']!),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: formula == f['v'] ? AppColors.azulClaro : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: formula == f['v'] ? AppColors.azul : AppColors.grisBorde)),
                  child: Row(children: [
                    Icon(formula == f['v'] ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: formula == f['v'] ? AppColors.azul : AppColors.grisBorde, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f['l']!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: formula == f['v'] ? AppColors.azul : AppColors.textoPrincipal)),
                      Text(f['d']!, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                    ])),
                  ])))),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (nombreCtrl.text.trim().isEmpty) return;
                    final negId2 = Supabase.instance.client.auth.currentUser?.id ?? _negId;
                    final f = formulas.firstWhere((f) => f['v'] == formula);
                    await SimuladorDataService.crearTipoTrabajo({
                      'negocio_id': negId2,
                      'servicio_id': widget.servicio.id,
                      'nombre': nombreCtrl.text.trim(),
                      'formula': formula,
                      'factor_complejidad': 1.0,
                      'necesita_largo': formula != 'por_diseno' && formula != 'precio_fijo' && formula != 'por_pieza',
                      'necesita_ancho': formula == 'por_area' || formula == 'por_volumen',
                      'necesita_alto': formula == 'por_volumen',
                      'necesita_horas': formula == 'por_hora',
                      'necesita_minutos': formula == 'por_minuto',
                      'necesita_metros': formula == 'por_metro',
                      'necesita_peso': formula == 'por_kg',
                      'descripcion_formula': f['d'],
                      'activo': true,
                    });
                    if (mounted) { Navigator.pop(ctx); _cargar(); }
                  },
                  icon: const Icon(Icons.save_outlined, color: Colors.white),
                  label: const Text('Crear modo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.azul,
                    padding: const EdgeInsets.symmetric(vertical: 13)))),
            ]))),
        ]))));
  }
}
