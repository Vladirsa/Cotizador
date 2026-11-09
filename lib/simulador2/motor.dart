// lib/simulador2/motor.dart
// HETNA CNC — Motor del Simulador 2.0. Dart puro, sin Flutter ni Supabase,
// para poder probarlo solo.
//
// Una sola fórmula para todos los servicios:
//
//   PRECIO = (MATERIAL + MÁQUINA + OPERADOR + PREPARACIÓN + ACABADOS + GASTOS FIJOS) ÷ (1 − margen)
//
//   MATERIAL    = hojas (o kg) que se usan × precio × (1 + merma) × (1 + ganancia material)
//   MÁQUINA     = tiempo de máquina × $/hora de ESA máquina
//   OPERADOR    = (tiempo de máquina + manejo + acabados) × $/hora del operador
//   PREPARACIÓN = minutos de preparación × ($/h máquina + $/h operador), UNA vez por pedido
//   ACABADOS    = precio por pieza o por m² de cada acabado elegido
//   GASTOS FIJOS= tiempo total × gastos fijos del mes ÷ horas productivas del mes
//
// El tiempo de máquina sale del archivo:
//   corte 2D       metros de corte ÷ velocidad (m/min) + perforaciones × seg
//   grabado        área a grabar ÷ velocidad de grabado (cm²/min)
//   relieve 3D     volumen a quitar ÷ tasa de remoción (cm³/min)
//   impresión 3D   volumen × (relleno + cáscara) ÷ velocidad (cm³/h)
//   torno          (cilindro − pieza) ÷ tasa de remoción
//
// Si falta un dato (velocidad, $/hora…), el motor NO inventa un número: lo
// pone en `faltantes` y la pantalla ofrece capturarlo ahí mismo.
import 'dart:math' as math;

enum Servicio2 { corte2D, grabado, relieve3D, impresion3D, torno }

String nombreServicio2(Servicio2 s) {
  switch (s) {
    case Servicio2.corte2D: return 'Corte 2D';
    case Servicio2.grabado: return 'Grabado';
    case Servicio2.relieve3D: return 'Relieve / 3D';
    case Servicio2.impresion3D: return 'Impresión 3D';
    case Servicio2.torno: return 'Torneado';
  }
}

/// Qué servicios puede hacer cada tipo de máquina.
List<Servicio2> serviciosDeMaquina(String tipo) {
  switch (tipo) {
    case 'router': return [Servicio2.corte2D, Servicio2.grabado, Servicio2.relieve3D];
    case 'router_3d': return [Servicio2.relieve3D, Servicio2.corte2D];
    case 'laser_co2': return [Servicio2.corte2D, Servicio2.grabado];
    case 'laser_fibra': return [Servicio2.corte2D, Servicio2.grabado];
    case 'plasma': return [Servicio2.corte2D];
    case 'impresora_3d': return [Servicio2.impresion3D];
    case 'torno': return [Servicio2.torno];
    default: return [Servicio2.corte2D];
  }
}

class Maquina2 {
  final String id, nombre, tipo, emoji;
  final double costoHora;       // $/h ya calculado (o manual)
  final double preparacionMin;  // una vez por pedido
  final double perforacionSeg;  // por entrada/perforación
  final double mesaLargo, mesaAncho, mesaAlto; // mm (0 = sin dato)
  final double remocionCm3Min;  // 3D
  final double impresionCm3H;   // impresora
  const Maquina2({required this.id, required this.nombre, required this.tipo, this.emoji = '⚙️',
    required this.costoHora, this.preparacionMin = 15, this.perforacionSeg = 2,
    this.mesaLargo = 0, this.mesaAncho = 0, this.mesaAlto = 0,
    this.remocionCm3Min = 0, this.impresionCm3H = 0});
}

class Material2 {
  final String? id;             // fila de inventario_bodega (null = a mano)
  final String nombre;
  final String tipo;            // clave de velocidades_hetna (mdf, acrilico…)
  final double espesorMm;
  final double precio;          // por unidad de compra (hoja, kg, pza, m)
  final String unidad;          // hoja | kg | pza | m | g
  final double hojaLargo, hojaAncho; // mm (0 si no es hoja)
  final double mermaPct;        // 15 = 15 %
  final double densidad;        // g/cm³
  final bool esRetazo;
  final double stock;
  const Material2({this.id, required this.nombre, required this.tipo, this.espesorMm = 0,
    required this.precio, this.unidad = 'hoja', this.hojaLargo = 0, this.hojaAncho = 0,
    this.mermaPct = 15, this.densidad = 0, this.esRetazo = false, this.stock = 0});
  bool get esHoja => hojaLargo > 0 && hojaAncho > 0;
  bool get porPeso => unidad == 'kg' || unidad == 'g';
}

class Taller2 {
  final double costoHoraOperador;
  final double gastosFijosHora;   // gastos fijos del mes ÷ horas productivas
  final double margenPct;         // margen normal (35)
  final double margenMinPct;      // debajo de éste se pinta rojo (20)
  final double ivaPct;
  final double markupMaterialPct; // ganancia sobre el material (20)
  final double manejoMinPieza;    // quitar, limpiar, empacar por pieza
  final double mercadoM2, mercadoHora, mercadoCm3; // referencia, 0 = sin dato
  const Taller2({this.costoHoraOperador = 0, this.gastosFijosHora = 0, this.margenPct = 35,
    this.margenMinPct = 20, this.ivaPct = 16, this.markupMaterialPct = 20, this.manejoMinPieza = 1,
    this.mercadoM2 = 0, this.mercadoHora = 0, this.mercadoCm3 = 0});
}

class Acabado2 {
  final String id, nombre;
  final double precioPieza, precioM2, minutosPieza;
  const Acabado2({required this.id, required this.nombre, this.precioPieza = 0, this.precioM2 = 0, this.minutosPieza = 0});
}

/// Velocidades de ESTA máquina con ESTE material/espesor.
class Velocidad2 {
  final double corteMMin, grabadoCm2Min, remocionCm3Min, impresionCm3H;
  final double acabadoCm2Min; // relieve 3D: superficie por minuto en el acabado (0 = estimación fija)
  final bool sugerido;  // true = valor de HETNA sin confirmar
  final String origen;  // hetna | receta | taller | tiempo_real | ninguno
  const Velocidad2({this.corteMMin = 0, this.grabadoCm2Min = 0, this.remocionCm3Min = 0,
    this.impresionCm3H = 0, this.acabadoCm2Min = 0, this.sugerido = true, this.origen = 'ninguno'});
}

/// La pieza (del archivo o de medidas a mano). Todo en mm salvo volumen.
class Pieza2 {
  final String nombre;
  final double largo, ancho, alto;
  final double metrosCorte;      // m (perímetros + interiores)
  final int perforaciones;       // entradas de la herramienta
  final double areaMm2;          // área del contorno (0 → largo × ancho)
  final double volumenCm3;       // 3D
  final double areaGrabadoMm2;   // grabado (0 = todo el rectángulo)
  final bool es3D;
  const Pieza2({required this.nombre, required this.largo, required this.ancho, this.alto = 0,
    this.metrosCorte = 0, this.perforaciones = 0, this.areaMm2 = 0, this.volumenCm3 = 0,
    this.areaGrabadoMm2 = 0, this.es3D = false});

  double get areaRectMm2 => largo * ancho;
  double get areaM2 => areaRectMm2 / 1e6;

  /// Sin archivo: estimar metros de corte por el "tanto corte" que lleva.
  /// sencillo = sólo contorno, normal = ×2.5, calado = ×8.
  static Pieza2 aMano({required double largo, required double ancho, double alto = 0,
      String complejidad = 'normal', bool es3D = false}) {
    final perim = 2 * (largo + ancho) / 1000;
    final f = complejidad == 'sencillo' ? 1.0 : complejidad == 'calado' ? 8.0 : 2.5;
    final perf = complejidad == 'sencillo' ? 1 : complejidad == 'calado' ? 20 : 4;
    return Pieza2(nombre: 'Pieza ${largo.round()}×${ancho.round()}${alto > 0 ? '×${alto.round()}' : ''} mm',
      largo: largo, ancho: ancho, alto: alto, metrosCorte: perim * f, perforaciones: perf,
      areaMm2: largo * ancho, volumenCm3: es3D ? largo * ancho * alto / 1000 * 0.6 : 0, es3D: es3D);
  }
}

/// Dónde queda cada pieza en la hoja (para dibujarlo) y qué sobra.
class Anidado {
  final int piezasPorHoja;
  final double hojasUsadas;    // fraccional (10 piezas ÷ 14 por hoja = 0.71)
  final int hojasCompra;       // enteras
  final bool rotada;           // la pieza va girada 90°
  final List<List<double>> posiciones; // [x, y, w, h] en mm de las piezas de la ÚLTIMA hoja
  final double retazoLargo, retazoAncho; // sobrante más grande de la última hoja (mm)
  final bool cabe;             // false si la pieza no cabe en la hoja
  const Anidado({required this.piezasPorHoja, required this.hojasUsadas, required this.hojasCompra,
    required this.rotada, required this.posiciones, required this.retazoLargo, required this.retazoAncho,
    required this.cabe});
  static const nada = Anidado(piezasPorHoja: 0, hojasUsadas: 0, hojasCompra: 0, rotada: false,
    posiciones: [], retazoLargo: 0, retazoAncho: 0, cabe: false);
}

/// Anidado en filas (rectángulos envolventes, con separación entre piezas y
/// margen al borde). Prueba la pieza derecha y girada y se queda con la que
/// más piezas mete. No es un anidado real de CAM, pero da cuántas hojas y
/// qué retazo sobra con error chico para piezas más o menos rectangulares.
Anidado anidar({required double hojaLargo, required double hojaAncho, required double piezaLargo,
    required double piezaAncho, required int cantidad, double separacion = 6, double margen = 10}) {
  if (hojaLargo <= 0 || hojaAncho <= 0 || piezaLargo <= 0 || piezaAncho <= 0 || cantidad <= 0) return Anidado.nada;
  final utilL = hojaLargo - 2 * margen, utilA = hojaAncho - 2 * margen;
  int cols(double pl) => ((utilL + separacion) / (pl + separacion)).floor();
  int rows(double pa) => ((utilA + separacion) / (pa + separacion)).floor();
  final cA = cols(piezaLargo), rA = rows(piezaAncho);
  final cB = cols(piezaAncho), rB = rows(piezaLargo);
  final nA = math.max(0, cA) * math.max(0, rA), nB = math.max(0, cB) * math.max(0, rB);
  if (nA <= 0 && nB <= 0) return Anidado.nada;
  final rot = nB > nA;
  final c = rot ? cB : cA, r = rot ? rB : rA;
  final pl = rot ? piezaAncho : piezaLargo, pa = rot ? piezaLargo : piezaAncho;
  final porHoja = c * r;
  final hojasUsadas = cantidad / porHoja;
  final hojasCompra = hojasUsadas.ceil();
  // Última hoja: cuántas piezas lleva y dónde
  int enUltima = cantidad - (hojasCompra - 1) * porHoja;
  final pos = <List<double>>[];
  int filasUsadas = 0, colsUltimaFila = 0;
  for (int i = 0; i < enUltima; i++) {
    final fila = i ~/ c, col = i % c;
    pos.add([margen + col * (pl + separacion), margen + fila * (pa + separacion), pl, pa]);
    filasUsadas = fila + 1;
    colsUltimaFila = col + 1;
  }
  // Sobrante: la franja de abajo (todo el largo) o la de la derecha
  final abajoAlto = hojaAncho - margen - filasUsadas * (pa + separacion);
  final derechaAncho = hojaLargo - margen - c * (pl + separacion);
  double rl = 0, ra = 0;
  if (abajoAlto * hojaLargo >= derechaAncho * hojaAncho) { rl = hojaLargo; ra = math.max(0, abajoAlto); }
  else { rl = math.max(0, derechaAncho); ra = hojaAncho; }
  // Si la última fila no está llena, a su derecha sobra otro bloque; se
  // reporta el mayor de los tres
  if (filasUsadas > 0 && colsUltimaFila < c) {
    final bl = hojaLargo - margen - colsUltimaFila * (pl + separacion);
    final ba = pa + separacion;
    if (bl * ba > rl * ra) { rl = bl; ra = ba; }
  }
  return Anidado(piezasPorHoja: porHoja, hojasUsadas: hojasUsadas, hojasCompra: hojasCompra, rotada: rot,
    posiciones: pos, retazoLargo: rl, retazoAncho: ra, cabe: true);
}

class Desglose2 {
  final double material, maquina, operador, preparacion, acabados, fijos;
  const Desglose2({this.material = 0, this.maquina = 0, this.operador = 0, this.preparacion = 0, this.acabados = 0, this.fijos = 0});
  double get costo => material + maquina + operador + preparacion + acabados + fijos;
}

class Resultado2 {
  final Servicio2 servicio;
  final int cantidad;
  final double tiempoMaquinaMinPieza; // por pieza
  final double tiempoTotalMin;        // máquina × n + preparación + manejo
  final Desglose2 desglose;           // del pedido completo
  final double margenPct;
  final double costoTotal, precioTotal, precioPieza, utilidad;
  final double mercadoTotal;          // 0 = sin referencia
  final Anidado anidado;
  final double unidadesMaterial;      // hojas o kg que se usan (fraccional)
  final double gramos;                // impresión 3D
  final List<String> faltantes;       // datos que no se tienen
  final List<String> avisos;          // advertencias (no cabe en la mesa…)
  final String explicacionTiempo;     // "11.3 m ÷ 2.5 m/min + 20 perf × 2 s"
  const Resultado2({required this.servicio, required this.cantidad, required this.tiempoMaquinaMinPieza,
    required this.tiempoTotalMin, required this.desglose, required this.margenPct, required this.costoTotal,
    required this.precioTotal, required this.precioPieza, required this.utilidad, required this.mercadoTotal,
    required this.anidado, required this.unidadesMaterial, required this.gramos, required this.faltantes,
    required this.avisos, required this.explicacionTiempo});
  bool get completo => faltantes.isEmpty;
  double get tiempoHoras => tiempoTotalMin / 60;
}

String _f(double v, [int d = 1]) => v.toStringAsFixed(d);

/// Tiempo de máquina de UNA pieza, en minutos, y cómo se calculó.
({double min, String como, List<String> faltantes}) tiempoPieza({
  required Servicio2 servicio, required Pieza2 pieza, required Maquina2 maquina,
  required Material2 material, required Velocidad2 vel, double rellenoPct = 20,
}) {
  final falt = <String>[];
  switch (servicio) {
    case Servicio2.corte2D:
      if (vel.corteMMin <= 0) {
        falt.add('Velocidad de corte de ${material.nombre} en ${maquina.nombre}');
        return (min: 0.0, como: '', faltantes: falt);
      }
      final corte = pieza.metrosCorte / vel.corteMMin;
      final perf = pieza.perforaciones * maquina.perforacionSeg / 60;
      return (min: corte + perf,
        como: '${_f(pieza.metrosCorte, 2)} m ÷ ${_f(vel.corteMMin, 2)} m/min${pieza.perforaciones > 0 ? ' + ${pieza.perforaciones} perf × ${_f(maquina.perforacionSeg, 0)} s' : ''}',
        faltantes: falt);
    case Servicio2.grabado:
      if (vel.grabadoCm2Min <= 0) {
        falt.add('Velocidad de grabado de ${material.nombre} en ${maquina.nombre}');
        return (min: 0.0, como: '', faltantes: falt);
      }
      final areaCm2 = (pieza.areaGrabadoMm2 > 0 ? pieza.areaGrabadoMm2 : pieza.areaRectMm2) / 100;
      final grab = areaCm2 / vel.grabadoCm2Min;
      // Si además trae contorno, se corta
      final corte = vel.corteMMin > 0 && pieza.metrosCorte > 0 ? pieza.metrosCorte / vel.corteMMin : 0.0;
      return (min: grab + corte,
        como: '${_f(areaCm2, 0)} cm² ÷ ${_f(vel.grabadoCm2Min, 0)} cm²/min${corte > 0 ? ' + contorno ${_f(pieza.metrosCorte, 2)} m' : ''}',
        faltantes: falt);
    case Servicio2.relieve3D:
      final rem = vel.remocionCm3Min > 0 ? vel.remocionCm3Min : maquina.remocionCm3Min;
      if (rem <= 0) {
        falt.add('Tasa de remoción (cm³/min) de ${material.nombre} en ${maquina.nombre}');
        return (min: 0.0, como: '', faltantes: falt);
      }
      final cajaCm3 = pieza.largo * pieza.ancho * (pieza.alto > 0 ? pieza.alto : material.espesorMm) / 1000;
      final quitar = math.max(0.0, cajaCm3 - pieza.volumenCm3);
      // Acabado: superficie ÷ (paso lateral × avance) de la receta; si no hay, ~0.6 min por 100 cm²
      final acabado = vel.acabadoCm2Min > 0 ? pieza.areaRectMm2 / 100 / vel.acabadoCm2Min : pieza.areaRectMm2 / 100 * 0.006;
      return (min: quitar / rem + acabado,
        como: '${_f(quitar, 0)} cm³ a quitar ÷ ${_f(rem, 1)} cm³/min + acabado ${_f(acabado, 0)} min',
        faltantes: falt);
    case Servicio2.impresion3D:
      final imp = vel.impresionCm3H > 0 ? vel.impresionCm3H : maquina.impresionCm3H;
      if (imp <= 0) {
        falt.add('Velocidad de impresión (cm³/h) de ${material.nombre} en ${maquina.nombre}');
        return (min: 0.0, como: '', faltantes: falt);
      }
      // Volumen real de plástico: relleno + cáscara (paredes y tapas ≈ 25 %)
      final factor = math.min(1.0, rellenoPct / 100 + 0.25);
      final vol = pieza.volumenCm3 * factor;
      return (min: vol / imp * 60,
        como: '${_f(pieza.volumenCm3, 1)} cm³ × ${(factor * 100).round()} % (relleno ${rellenoPct.round()} % + cáscara) ÷ ${_f(imp, 0)} cm³/h',
        faltantes: falt);
    case Servicio2.torno:
      final rem = vel.remocionCm3Min > 0 ? vel.remocionCm3Min : maquina.remocionCm3Min;
      if (rem <= 0) {
        falt.add('Tasa de remoción (cm³/min) de ${material.nombre} en ${maquina.nombre}');
        return (min: 0.0, como: '', faltantes: falt);
      }
      final d = math.max(pieza.ancho, pieza.alto), l = pieza.largo;
      final cil = math.pi * (d / 2) * (d / 2) * l / 1000;
      final quitar = math.max(0.0, cil - pieza.volumenCm3);
      return (min: quitar / rem + 2, como: 'barra Ø${_f(d, 0)} × ${_f(l, 0)} mm: ${_f(quitar, 0)} cm³ ÷ ${_f(rem, 1)} cm³/min',
        faltantes: falt);
  }
}

/// Material que usa el pedido completo: unidades (hojas, kg…), gramos y anidado.
({double unidades, double gramos, Anidado anidado, List<String> faltantes, List<String> avisos}) materialPedido({
  required Servicio2 servicio, required Pieza2 pieza, required Material2 material, required int cantidad,
  double rellenoPct = 20, double separacion = 6,
}) {
  final falt = <String>[], avisos = <String>[];
  if (material.precio <= 0) falt.add('Precio de ${material.nombre}');
  if (servicio == Servicio2.impresion3D) {
    final dens = material.densidad > 0 ? material.densidad : 1.24;
    final factor = math.min(1.0, rellenoPct / 100 + 0.25);
    final g = pieza.volumenCm3 * factor * dens * cantidad * 1.05; // 5 % de purga y soportes
    final unidades = material.unidad == 'g' ? g : g / 1000; // kg
    return (unidades: unidades, gramos: g, anidado: Anidado.nada, faltantes: falt, avisos: avisos);
  }
  if (material.porPeso) {
    // Metal por kg: caja envolvente × densidad
    final dens = material.densidad > 0 ? material.densidad : 7.85;
    final alto = pieza.alto > 0 ? pieza.alto : material.espesorMm;
    final g = pieza.largo * pieza.ancho * alto / 1000 * dens * cantidad;
    return (unidades: material.unidad == 'g' ? g : g / 1000, gramos: g, anidado: Anidado.nada, faltantes: falt, avisos: avisos);
  }
  if (material.esHoja) {
    final an = anidar(hojaLargo: material.hojaLargo, hojaAncho: material.hojaAncho,
      piezaLargo: pieza.largo, piezaAncho: pieza.ancho, cantidad: cantidad, separacion: separacion);
    if (!an.cabe) {
      avisos.add('La pieza (${pieza.largo.round()}×${pieza.ancho.round()} mm) no cabe en la hoja de ${material.nombre} (${material.hojaLargo.round()}×${material.hojaAncho.round()} mm)');
      return (unidades: cantidad.toDouble(), gramos: 0, anidado: an, faltantes: falt, avisos: avisos);
    }
    return (unidades: an.hojasUsadas, gramos: 0, anidado: an, faltantes: falt, avisos: avisos);
  }
  // Por pieza/metro sin medida de hoja: una unidad por pieza
  if (material.hojaLargo <= 0) avisos.add('${material.nombre} no tiene medida de hoja: se cobra 1 unidad por pieza');
  return (unidades: cantidad.toDouble(), gramos: 0, anidado: Anidado.nada, faltantes: falt, avisos: avisos);
}

/// La fórmula completa para un pedido de `cantidad` piezas.
Resultado2 calcular({
  required Servicio2 servicio, required Pieza2 pieza, required Maquina2 maquina,
  required Material2 material, required Velocidad2 vel, required Taller2 taller,
  required int cantidad, double? margenPct, List<Acabado2> acabados = const [],
  double rellenoPct = 20, double? tiempoMinManual,
}) {
  final n = math.max(1, cantidad);
  final margen = (margenPct ?? taller.margenPct).clamp(0, 95).toDouble();
  final faltantes = <String>[], avisos = <String>[];

  // Tiempo
  final t = tiempoPieza(servicio: servicio, pieza: pieza, maquina: maquina, material: material, vel: vel, rellenoPct: rellenoPct);
  double tPieza = tiempoMinManual ?? t.min;
  String como = tiempoMinManual != null ? 'tiempo ajustado a mano' : t.como;
  if (tiempoMinManual == null) faltantes.addAll(t.faltantes);
  if (maquina.costoHora <= 0) faltantes.add('Costo por hora de ${maquina.nombre}');
  if (taller.costoHoraOperador <= 0) avisos.add('No hay \$/hora de operador: la mano de obra sale en \$0');
  if (vel.sugerido && (t.min > 0)) avisos.add('Velocidad sugerida por HETNA, sin confirmar con tus tiempos');
  if (maquina.mesaLargo > 0 && maquina.mesaAncho > 0) {
    final cabe = (pieza.largo <= maquina.mesaLargo && pieza.ancho <= maquina.mesaAncho) ||
                 (pieza.ancho <= maquina.mesaLargo && pieza.largo <= maquina.mesaAncho);
    if (!cabe) avisos.add('La pieza no cabe en la mesa de ${maquina.nombre} (${maquina.mesaLargo.round()}×${maquina.mesaAncho.round()} mm)');
  }

  // Material
  final m = materialPedido(servicio: servicio, pieza: pieza, material: material, cantidad: n, rellenoPct: rellenoPct);
  faltantes.addAll(m.faltantes); avisos.addAll(m.avisos);
  final merma = 1 + material.mermaPct / 100;
  final markup = 1 + taller.markupMaterialPct / 100;
  final costoMaterial = m.unidades * material.precio * merma * markup;

  // Tiempos del pedido
  final tMaquina = tPieza * n;
  final minAcabados = acabados.fold(0.0, (s, a) => s + a.minutosPieza) * n;
  final tManejo = taller.manejoMinPieza * n + minAcabados;
  final tPrep = maquina.preparacionMin;
  final tTotal = tMaquina + tManejo + tPrep;

  final costoMaquina = tMaquina / 60 * maquina.costoHora;
  final costoOperador = (tMaquina + tManejo) / 60 * taller.costoHoraOperador;
  final costoPrep = tPrep / 60 * (maquina.costoHora + taller.costoHoraOperador);
  final areaM2 = pieza.areaM2;
  final costoAcabados = acabados.fold(0.0, (s, a) => s + a.precioPieza * n + a.precioM2 * areaM2 * n);
  final costoFijos = tTotal / 60 * taller.gastosFijosHora;

  final d = Desglose2(material: costoMaterial, maquina: costoMaquina, operador: costoOperador,
    preparacion: costoPrep, acabados: costoAcabados, fijos: costoFijos);
  final costo = d.costo;
  final precio = margen >= 95 ? costo : costo / (1 - margen / 100);

  // Referencia de mercado
  double mercado = 0;
  if (servicio == Servicio2.impresion3D && taller.mercadoCm3 > 0) mercado = pieza.volumenCm3 * n * taller.mercadoCm3;
  else if ((servicio == Servicio2.corte2D || servicio == Servicio2.grabado) && taller.mercadoM2 > 0) mercado = areaM2 * n * taller.mercadoM2;
  else if (taller.mercadoHora > 0) mercado = tTotal / 60 * taller.mercadoHora;

  return Resultado2(servicio: servicio, cantidad: n, tiempoMaquinaMinPieza: tPieza, tiempoTotalMin: tTotal,
    desglose: d, margenPct: margen, costoTotal: costo, precioTotal: precio, precioPieza: precio / n,
    utilidad: precio - costo, mercadoTotal: mercado, anidado: m.anidado, unidadesMaterial: m.unidades,
    gramos: m.gramos, faltantes: faltantes, avisos: avisos, explicacionTiempo: como);
}

/// Precio por volumen: la misma pieza a 1, 10, 50, 100 (y la cantidad pedida).
List<Resultado2> tablaVolumen({
  required Servicio2 servicio, required Pieza2 pieza, required Maquina2 maquina,
  required Material2 material, required Velocidad2 vel, required Taller2 taller,
  required int cantidad, double? margenPct, List<Acabado2> acabados = const [],
  double rellenoPct = 20, double? tiempoMinManual,
}) {
  final cants = <int>{1, 10, 50, 100, cantidad}.toList()..sort();
  return cants.map((c) => calcular(servicio: servicio, pieza: pieza, maquina: maquina, material: material,
    vel: vel, taller: taller, cantidad: c, margenPct: margenPct, acabados: acabados,
    rellenoPct: rellenoPct, tiempoMinManual: tiempoMinManual)).toList();
}

/// Aprendizaje: con el tiempo real de un pedido, qué velocidad habría dado
/// ese tiempo. Devuelve la velocidad corregida (m/min, cm³/min o cm³/h según
/// el servicio) y el factor real/estimado, o null si no hay datos.
({double velocidadNueva, double factor})? velocidadDesdeTiempoReal({
  required double velocidadActual, required double tiempoEstimadoMin, required double tiempoRealMin,
}) {
  if (velocidadActual <= 0 || tiempoEstimadoMin <= 0 || tiempoRealMin <= 0) return null;
  final factor = tiempoRealMin / tiempoEstimadoMin;
  if (factor < 0.3 || factor > 4) return null; // dato raro (olvidaron escanear): no aprender de eso
  return (velocidadNueva: velocidadActual / factor, factor: factor);
}

/// Promedio ponderado: la velocidad guardada pesa `muestras`, la nueva pesa 1.
double velocidadPonderada(double actual, int muestras, double nueva) {
  if (muestras <= 0) return nueva;
  return (actual * muestras + nueva) / (muestras + 1);
}
