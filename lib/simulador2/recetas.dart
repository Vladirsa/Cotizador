// lib/simulador2/recetas.dart
// HETNA CNC — Receta técnica: la "inteligencia" del simulador.
//
// Para cada trabajo (máquina + material + espesor + operación) arma la receta
// con la que se haría en el taller y, DE ESA RECETA, saca el tiempo:
//
//   Router    fresa (tipo, diámetro, filos), RPM por velocidad de corte,
//             avance por carga de viruta, entrada, profundidad por pasada,
//             pasadas, paso lateral; potencia del spindle como límite.
//   Láser CO2 velocidad (mm/s) y potencia (%) por espesor y watts del tubo,
//             pasadas, foco, aire, kerf; grabado por intervalo de línea.
//   Plasma    velocidad por tabla de amperaje, boquilla, altura de corte y
//             perforación, retardo, voltaje de arco, presión de aire, kerf.
//   Fibra     velocidad por kW y espesor, gas, foco, boquilla.
//   Relieve   desbaste (fresa plana, stepdown, stepover, avance → cm³/min) y
//             acabado (punta bola, stepover, avance → cm²/min).
//   Impresión capa, boquilla, velocidad, temperaturas → cm³/h.
//
// Es el mismo conocimiento de la Calculadora CNC de hetnacnc.com
// (lib/copiloto/motor.ts), traído a Dart para que funcione sin internet y
// para que el taller pueda corregir los valores y guardarlos como suyos.
import 'dart:math' as math;

// ─────────────────────────── tipos ───────────────────────────
class Parametro {
  final String clave, nombre, valor;
  final String? unidad, nota;
  final bool editable;
  const Parametro(this.clave, this.nombre, this.valor, {this.unidad, this.nota, this.editable = false});
}

class Receta {
  final String titulo;            // "Router · perfilado · MDF 18 mm"
  final String operacion;         // perfil | cajeado | grabado_v | relieve | laser_corte | laser_grabado | plasma | fibra | impresion
  final List<Parametro> parametros;
  final List<String> avisos;
  final List<String> faltan;      // datos de la máquina que no están
  // Lo que usa el motor de precio
  final double corteMMin;         // velocidad EFECTIVA de corte 2D (ya con pasadas y aceleraciones)
  final double grabadoCm2Min;
  final double remocionCm3Min;    // desbaste 3D
  final double acabadoCm2Min;     // acabado 3D (área superficial por minuto)
  final double impresionCm3H;
  final double segPorEntrada;     // tiempo por perforación/entrada
  // Valores que el taller puede editar (clave → número)
  final Map<String, double> ajustables;
  const Receta({required this.titulo, required this.operacion, required this.parametros, this.avisos = const [], this.faltan = const [],
    this.corteMMin = 0, this.grabadoCm2Min = 0, this.remocionCm3Min = 0, this.acabadoCm2Min = 0, this.impresionCm3H = 0,
    this.segPorEntrada = 2, this.ajustables = const {}});
}

/// Datos de la máquina que las recetas necesitan (vienen de maquinaria).
class MaquinaReceta {
  final String tipo;        // router | laser_co2 | plasma | laser_fibra | router_3d | impresora_3d | torno
  final double potencia;    // kW spindle / W tubo / A fuente / kW fibra / — impresora
  final double rpmMax, rpmMin, avanceMax; // router
  const MaquinaReceta({required this.tipo, this.potencia = 0, this.rpmMax = 0, this.rpmMin = 0, this.avanceMax = 0});
}

String _f(num v, [int d = 0]) {
  if (d == 0) return v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return v.toStringAsFixed(d);
}
double _clamp(double v, double a, double b) => v < a ? a : v > b ? b : v;

double _interp(List<List<double>> t, double x, {int col = 1, bool log = false}) {
  if (x <= t.first[0]) return t.first[col];
  final u = t.last;
  if (x >= u[0]) return u[col];
  for (int i = 1; i < t.length; i++) {
    final a = t[i - 1], b = t[i];
    if (x <= b[0]) {
      final f = (x - a[0]) / (b[0] - a[0]);
      if (log && a[col] > 0 && b[col] > 0) return math.exp(math.log(a[col]) + f * (math.log(b[col]) - math.log(a[col])));
      return a[col] + f * (b[col] - a[col]);
    }
  }
  return u[col];
}

// ─────────────────────────── ROUTER ───────────────────────────
class _MatRouter {
  final String nombre;
  final List<List<double>> cl; // [diámetro, carga mín, carga máx] mm/filo
  final double vcMin, vcMax;   // velocidad de corte m/min
  final double doc;            // profundidad por pasada en diámetros
  final double u;              // energía específica J/mm³
  final int filos;
  final double entrada;        // plunge como fracción del avance
  final String fresa;          // tipo recomendado
  final String nota;
  const _MatRouter(this.nombre, this.cl, this.vcMin, this.vcMax, this.doc, this.u, this.filos, this.entrada, this.fresa, this.nota);
}

const _ROUTER = <String, _MatRouter>{
  'mdf': _MatRouter('MDF', [[3, 0.10, 0.15], [6, 0.25, 0.30], [12, 0.45, 0.55]], 300, 900, 1.0, 0.06, 2, 0.35, 'compresion', 'Buena extracción de polvo. Fresa de compresión deja limpias las dos caras.'),
  'triplay': _MatRouter('Triplay', [[3, 0.08, 0.13], [6, 0.23, 0.28], [12, 0.43, 0.50]], 300, 900, 1.0, 0.06, 2, 0.35, 'compresion', 'Para no astillar las caras: compresión o downcut.'),
  'melamina': _MatRouter('Melamina', [[3, 0.08, 0.13], [6, 0.22, 0.28], [12, 0.40, 0.50]], 300, 900, 1.0, 0.07, 2, 0.35, 'compresion', 'La compresión evita que se desconche la cara de melamina.'),
  'madera': _MatRouter('Madera', [[3, 0.08, 0.13], [6, 0.20, 0.25], [12, 0.40, 0.48]], 300, 800, 0.75, 0.08, 2, 0.30, 'upcut', 'Si quema, no bajes el avance: baja RPM.'),
  'acrilico': _MatRouter('Acrílico', [[3, 0.08, 0.10], [6, 0.15, 0.20], [12, 0.25, 0.30]], 150, 350, 0.5, 0.10, 1, 0.30, 'un_filo', 'Fresa de 1 filo (O-flute). Si se derrite, sube avance o baja RPM.'),
  'pvc': _MatRouter('PVC espumado', [[3, 0.08, 0.13], [6, 0.18, 0.25], [12, 0.30, 0.38]], 150, 400, 1.0, 0.05, 1, 0.35, 'un_filo', 'Un filo para que la viruta salga y no se funda.'),
  'hdpe': _MatRouter('HDPE / Nylon', [[3, 0.08, 0.13], [6, 0.18, 0.25], [12, 0.30, 0.38]], 150, 400, 0.75, 0.05, 1, 0.30, 'un_filo', 'Plástico que se funde: carga de viruta alta y RPM moderadas.'),
  'policarbonato': _MatRouter('Policarbonato', [[3, 0.06, 0.09], [6, 0.12, 0.18], [12, 0.20, 0.26]], 150, 350, 0.5, 0.10, 1, 0.30, 'un_filo', 'Un filo, poca profundidad; se funde si va lento.'),
  'aluminio': _MatRouter('Aluminio', [[3, 0.025, 0.04], [6, 0.05, 0.08], [12, 0.08, 0.12]], 150, 400, 0.2, 0.70, 1, 0.20, 'un_filo', 'Fresa de 1 filo pulida, lubricación (alcohol/niebla) y entrada en rampa.'),
  'cobre': _MatRouter('Latón / cobre', [[3, 0.02, 0.03], [6, 0.04, 0.06], [12, 0.06, 0.09]], 100, 250, 0.15, 1.20, 2, 0.20, 'recta', 'Dos filos sin recubrimiento agresivo.'),
  'acero': _MatRouter('Acero', [[3, 0.01, 0.02], [6, 0.02, 0.04], [12, 0.04, 0.06]], 60, 120, 0.05, 2.50, 4, 0.15, 'recta', 'Un router de madera NO tiene rigidez para acero: es para fresadora con refrigerante.'),
  'espuma': _MatRouter('Espuma', [[3, 0.15, 0.25], [6, 0.30, 0.50], [12, 0.50, 0.80]], 300, 1000, 2.0, 0.005, 2, 0.50, 'upcut', 'Profundo y rápido; el límite es el avance máximo de la máquina.'),
};

const nombresFresa = <String, String>{
  'recta': 'Recta', 'upcut': 'Espiral ascendente (upcut)', 'downcut': 'Espiral descendente (downcut)',
  'compresion': 'Compresión', 'un_filo': 'Un filo (O-flute)', 'bola': 'Punta de bola', 'v': 'Punta en V', 'planeadora': 'Planeadora',
};

/// Diámetro de fresa recomendado según espesor y detalle de la pieza.
double fresaRecomendada(double espesorMm, {double detalleMinMm = 0}) {
  double d = espesorMm <= 4 ? 3 : espesorMm <= 10 ? 4 : espesorMm <= 20 ? 6 : 8;
  if (detalleMinMm > 0 && detalleMinMm < d) d = detalleMinMm >= 3 ? 3 : detalleMinMm >= 2 ? 2 : 1.5;
  return d;
}

/// Router 2D: perfilado (atravesar) o cajeado; también grabado en V.
Receta recetaRouter({
  required String material, required double espesor, required MaquinaReceta maq,
  String operacion = 'perfil', double? diametro, int? filos, String? tipoFresa, double? rpm, double? avance, int? pasadas,
}) {
  final M = _ROUTER[material] ?? _ROUTER['mdf']!;
  final avisos = <String>[], faltan = <String>[];
  if (!_ROUTER.containsKey(material)) avisos.add('No conozco "$material" en router; usé valores de MDF.');
  final rpmMax = maq.rpmMax > 0 ? maq.rpmMax : 24000.0;
  if (maq.rpmMax <= 0) faltan.add('RPM máximas del spindle');
  final rpmMin = maq.rpmMin > 0 ? maq.rpmMin : math.min(6000.0, rpmMax * 0.25);
  final avMax = maq.avanceMax > 0 ? maq.avanceMax : 6000.0;
  if (maq.avanceMax <= 0) faltan.add('Avance máximo de la máquina (mm/min)');
  final P = maq.potencia; // kW
  if (P <= 0) faltan.add('Potencia del spindle (kW)');

  final D = diametro ?? (operacion == 'grabado_v' ? 6.0 : fresaRecomendada(espesor));
  int Z = filos ?? (operacion == 'grabado_v' ? 2 : M.filos);
  final tipo = tipoFresa ?? (operacion == 'grabado_v' ? 'v' : M.fresa);

  // Carga de viruta
  double clMin = _interp(M.cl, D, col: 1), clMax = _interp(M.cl, D, col: 2);
  if (D < M.cl.first[0]) { clMin = M.cl.first[1] * D / M.cl.first[0]; clMax = M.cl.first[2] * D / M.cl.first[0]; }
  double factor = 1;
  if (operacion == 'grabado_v' || tipo == 'v') factor *= 0.5;
  if (Z >= 3 && M.u < 0.5) factor *= 0.85;
  clMin *= factor; clMax *= factor;
  final cl = (clMin + clMax) / 2;

  // RPM y avance
  final vcMedia = (M.vcMin + M.vcMax) / 2;
  double rpmCalc = _clamp(vcMedia * 1000 / (math.pi * D), rpmMin, rpmMax);
  double avCalc = rpmCalc * Z * cl;
  if (avCalc > avMax) {
    final rpm2 = avMax / (Z * cl);
    if (rpm2 >= rpmMin) { rpmCalc = rpm2; avCalc = avMax; avisos.add('Tu máquina llega a ${_f(avMax)} mm/min: bajé las RPM a ${_f(rpm2)} para no quemar la fresa.'); }
    else { rpmCalc = rpmMin; avCalc = avMax; avisos.add('Ni a ${_f(rpmMin)} RPM alcanza el avance ideal: la fresa puede calentarse; considera una de menos filos.'); }
  }
  final rpmU = rpm ?? (rpmCalc / 100).round() * 100.0;
  final avU = avance ?? (avCalc / 10).round() * 10.0;

  // Profundidad por pasada
  double doc = D * M.doc, ae = D;
  if (operacion == 'cajeado') { ae = D * 0.4; }
  if (operacion == 'grabado_v') { ae = D * 0.5; doc = math.min(espesor > 0 ? espesor : 2, D * 0.3); }
  if (tipo == 'downcut' && operacion == 'perfil' && M.u < 0.5) doc = math.min(doc, D * 0.5);
  if (tipo == 'compresion' && operacion == 'perfil' && espesor > 0) avisos.add('Con compresión la primera pasada debe ser más profunda que la parte ascendente de la fresa (≈ ${_f(D * 0.8, 1)} mm).');
  double potW = ae * doc * avU / 60 * M.u;
  double? potDisp;
  if (P > 0) {
    potDisp = P * 1000 * math.min(1, rpmU / rpmMax);
    if (potW > potDisp * 0.8) { final f = potDisp * 0.8 / potW; doc *= f; potW *= f; avisos.add('El spindle pasaría del 80 % de su potencia: bajé la profundidad por pasada a ${_f(doc, 2)} mm.'); }
  }
  int pasadasU;
  double docReal;
  if (operacion == 'grabado_v') { pasadasU = 1; docReal = doc; }
  else {
    pasadasU = pasadas ?? math.max(1, (espesor / doc - 1e-9).ceil());
    docReal = espesor > 0 ? espesor / pasadasU : doc;
  }
  final entrada = (avU * M.entrada / 10).round() * 10.0;
  final mrr = ae * docReal * avU / 1000;

  // Velocidad efectiva: avance ÷ pasadas, menos 15 % por aceleraciones y esquinas
  final efectiva = avU / 1000 / pasadasU / 1.15;
  final grab = operacion == 'grabado_v' ? ae * avU / 100 / 1.25 : 0.0; // cm²/min en grabado V por área

  final params = <Parametro>[
    Parametro('tipo_fresa', 'Fresa', nombresFresa[tipo] ?? tipo, nota: M.filos == 1 && Z > 2 ? 'conviene 1 filo en este material' : null, editable: true),
    Parametro('diametro', 'Diámetro', _f(D, D % 1 == 0 ? 0 : 1), unidad: 'mm', editable: true),
    Parametro('filos', 'Filos', '$Z', editable: true),
    Parametro('rpm', 'RPM', _f(rpmU), nota: 'vc ${_f(math.pi * D * rpmU / 1000)} m/min', editable: true),
    Parametro('avance', 'Avance', _f(avU), unidad: 'mm/min', nota: 'carga de viruta ${cl.toStringAsFixed(3)} mm/filo', editable: true),
    Parametro('entrada', 'Entrada (plunge)', _f(entrada), unidad: 'mm/min', nota: M.u > 0.5 ? 'en rampa' : null),
    Parametro('prof_pasada', 'Profundidad por pasada', _f(docReal, 2), unidad: 'mm'),
    if (operacion != 'grabado_v') Parametro('pasadas', 'Pasadas', '$pasadasU', nota: espesor > 0 ? 'para ${_f(espesor, 1)} mm' : null, editable: true),
    if (operacion != 'perfil') Parametro('stepover', 'Paso lateral', _f(ae, 2), unidad: 'mm', nota: '${_f(ae / D * 100)} % del ∅'),
    Parametro('mrr', 'Material removido', _f(mrr, 1), unidad: 'cm³/min'),
    if (potDisp != null) Parametro('potencia', 'Potencia usada', _f(potW / 1000, 2), unidad: 'kW', nota: '${_f(potW / potDisp * 100)} % de la disponible')
    else Parametro('potencia', 'Potencia estimada', _f(potW / 1000, 2), unidad: 'kW'),
    if (operacion == 'perfil') const Parametro('tabs', 'Puentes (tabs)', '3–4 por pieza, 3 × 1 mm', nota: 'para que no se mueva al terminar el corte'),
  ];
  avisos.add(M.nota);
  return Receta(
    titulo: '${operacion == 'perfil' ? 'Perfilado' : operacion == 'cajeado' ? 'Cajeado' : 'Grabado en V'} · ${M.nombre}${espesor > 0 ? ' ${_f(espesor, espesor % 1 == 0 ? 0 : 1)} mm' : ''}',
    operacion: operacion, parametros: params, avisos: avisos, faltan: faltan,
    corteMMin: efectiva, grabadoCm2Min: grab, segPorEntrada: docReal > 0 ? _clamp(docReal / (entrada / 60) * pasadasU + 1, 1, 8) : 2,
    ajustables: {'diametro': D, 'filos': Z.toDouble(), 'rpm': rpmU, 'avance': avU, 'pasadas': pasadasU.toDouble()});
}

/// Relieve 3D en router: desbaste + acabado.
Receta recetaRelieve({
  required String material, required double espesor, required MaquinaReceta maq,
  double? fresaDesbaste, double? fresaAcabado, double? stepoverAcabadoPct, double? avanceDesbaste, double? avanceAcabado,
}) {
  final M = _ROUTER[material] ?? _ROUTER['mdf']!;
  final faltan = <String>[];
  if (maq.potencia <= 0) faltan.add('Potencia del spindle (kW)');
  final avMax = maq.avanceMax > 0 ? maq.avanceMax : 6000.0;
  final rpmMax = maq.rpmMax > 0 ? maq.rpmMax : 24000.0;
  // Desbaste: fresa plana 6 mm (o 4 en materiales duros), stepdown 50 % D, stepover 40 % D
  final Dd = fresaDesbaste ?? (M.u > 0.5 ? 4.0 : 6.0);
  final clD = (_interp(M.cl, Dd, col: 1) + _interp(M.cl, Dd, col: 2)) / 2;
  final rpmD = _clamp((M.vcMin + M.vcMax) / 2 * 1000 / (math.pi * Dd), 8000, rpmMax);
  final avD = avanceDesbaste ?? math.min(avMax, (rpmD * M.filos * clD / 10).round() * 10.0);
  final stepdown = Dd * M.doc * 0.5, stepoverD = Dd * 0.4;
  final mrr = stepdown * stepoverD * avD / 1000 * 0.7; // 30 % de aire y retrocesos
  // Acabado: punta de bola 3 mm (fino) o 6 mm (grande), stepover 8–10 %
  final Da = fresaAcabado ?? (espesor > 25 ? 6.0 : 3.0);
  final soPct = stepoverAcabadoPct ?? 10.0;
  final stepoverA = Da * soPct / 100;
  final clA = (_interp(M.cl, Da, col: 1) + _interp(M.cl, Da, col: 2)) / 2 * 0.8;
  final rpmA = _clamp((M.vcMin + M.vcMax) / 2 * 1000 / (math.pi * Da), 12000, rpmMax);
  final avA = avanceAcabado ?? math.min(avMax, (rpmA * 2 * clA / 10).round() * 10.0);
  final acabadoCm2Min = stepoverA * avA / 100 * 0.8; // cm²/min, 20 % de retrocesos
  final params = <Parametro>[
    const Parametro('sep1', '— Desbaste —', ''),
    Parametro('fresa_desbaste', 'Fresa plana', '∅ ${_f(Dd)} mm · ${M.filos} filos', editable: true),
    Parametro('rpm_d', 'RPM', _f(rpmD)),
    Parametro('avance_desbaste', 'Avance', _f(avD), unidad: 'mm/min', editable: true),
    Parametro('stepdown', 'Profundidad por pasada', _f(stepdown, 1), unidad: 'mm'),
    Parametro('stepover_d', 'Paso lateral', _f(stepoverD, 1), unidad: 'mm', nota: '40 % del ∅'),
    Parametro('mrr', 'Material removido', _f(mrr, 1), unidad: 'cm³/min', nota: 'ya con retrocesos'),
    const Parametro('sep2', '— Acabado —', ''),
    Parametro('fresa_acabado', 'Punta de bola', '∅ ${_f(Da)} mm', editable: true),
    Parametro('rpm_a', 'RPM', _f(rpmA)),
    Parametro('avance_acabado', 'Avance', _f(avA), unidad: 'mm/min', editable: true),
    Parametro('stepover_acabado_pct', 'Paso lateral', '${_f(soPct)} %', nota: '${_f(stepoverA, 2)} mm · menos % = más fino y más lento', editable: true),
    Parametro('acabado_cm2', 'Superficie por minuto', _f(acabadoCm2Min, 1), unidad: 'cm²/min'),
    const Parametro('estrategia', 'Estrategia', 'Desbaste en Z constante con 0.5 mm de sobrematerial; acabado en paralelo o ráster a 45°'),
  ];
  return Receta(titulo: 'Relieve 3D · ${M.nombre}', operacion: 'relieve', parametros: params, faltan: faltan,
    avisos: ['Sujeta bien la pieza: en relieve la fresa trabaja horas. Revisa el cero en Z después del desbaste.', M.nota],
    remocionCm3Min: mrr, acabadoCm2Min: acabadoCm2Min,
    ajustables: {'fresa_desbaste': Dd, 'fresa_acabado': Da, 'stepover_acabado_pct': soPct, 'avance_desbaste': avD, 'avance_acabado': avA});
}

// ─────────────────────────── LÁSER CO2 ───────────────────────────
class _MatLaser {
  final String nombre;
  final List<List<double>>? corte; // [espesor, mm/s con 100 W]
  final List<double> grabado;      // [vel min, vel max mm/s, pot min %, pot max %]
  final String? aviso;
  final bool prohibido;
  const _MatLaser(this.nombre, this.corte, this.grabado, {this.aviso, this.prohibido = false});
}

const _LASER = <String, _MatLaser>{
  'mdf': _MatLaser('MDF', [[3, 20], [6, 8], [9, 4], [12, 2.5], [15, 1.5], [18, 0.9]], [250, 450, 15, 30]),
  'triplay': _MatLaser('Triplay', [[3, 22], [6, 10], [9, 5], [12, 3]], [250, 450, 15, 30], aviso: 'El pegamento del triplay varía por lote: prueba en una esquina.'),
  'madera': _MatLaser('Madera', [[2, 30], [3, 20], [6, 9], [10, 4]], [250, 450, 15, 30]),
  'melamina': _MatLaser('Melamina', [[12, 2.5], [16, 1.5]], [250, 450, 15, 30], aviso: 'La cara de melamina se quema: mejor router.'),
  'acrilico': _MatLaser('Acrílico', [[2, 28], [3, 20], [5, 12], [6, 10], [8, 6], [10, 4], [15, 2], [20, 1]], [300, 500, 20, 35], aviso: 'Para canto pulido usa acrílico fundido (cast).'),
  'carton': _MatLaser('Cartón', [[1, 60], [3, 35], [5, 20]], [400, 600, 10, 20], aviso: 'Vigila la flama; nunca dejes la máquina sola.'),
  'cuero': _MatLaser('Piel / tela', [[1, 40], [2, 25], [3, 15], [4, 10]], [300, 500, 15, 30], aviso: 'Sólo piel natural; la sintética puede ser PVC.'),
  'espuma': _MatLaser('Espuma EVA', [[3, 40], [6, 20], [10, 10]], [400, 600, 10, 20]),
  'pvc': _MatLaser('PVC', null, [0, 0, 0, 0], prohibido: true, aviso: 'NO CORTES PVC CON LÁSER: suelta cloro, tóxico y corrosivo para ti y la máquina.'),
  'policarbonato': _MatLaser('Policarbonato', [[1, 15], [2, 8]], [300, 500, 15, 25], aviso: 'Corta mal con CO2 (se amarillea, flama). Mejor router.'),
};

Receta recetaLaserCo2({
  required String material, required double espesor, required MaquinaReceta maq, bool grabado = false,
  double? velocidadMmS, double? potenciaPct, int? pasadas,
}) {
  final M = _LASER[material] ?? _LASER['mdf']!;
  final avisos = <String>[], faltan = <String>[];
  final W = maq.potencia > 0 ? maq.potencia : 80.0;
  if (maq.potencia <= 0) faltan.add('Potencia del tubo (W)');
  if (M.prohibido) {
    return Receta(titulo: 'Láser CO2 · ${M.nombre}', operacion: 'laser_corte', parametros: const [Parametro('r', 'Resultado', 'NO apto para láser')], avisos: [M.aviso!], faltan: faltan);
  }
  if (!grabado) {
    if (M.corte == null) return Receta(titulo: 'Láser CO2 · ${M.nombre}', operacion: 'laser_corte', parametros: const [Parametro('r', 'Corte', 'No se corta con CO2')], avisos: [M.aviso ?? ''], faltan: faltan);
    final escala = W / 100;
    final tabla = M.corte!;
    final espMax = (tabla.last[0] * math.pow(escala, 0.8)).toDouble();
    double v = _interp(tabla, espesor, log: true) * escala;
    if (espesor > tabla.last[0]) v = (tabla.last[1] * math.pow(tabla.last[0] / espesor, 2) * escala).toDouble();
    final vU = velocidadMmS ?? double.parse(v.toStringAsFixed(1));
    final potU = potenciaPct ?? (W >= 100 ? 80.0 : 85.0);
    final pasU = pasadas ?? (espesor > espMax * 0.8 ? 2 : 1);
    final efectiva = vU * 60 / 1000 / pasU / 1.2; // m/min efectivos
    final params = <Parametro>[
      Parametro('velocidad', 'Velocidad de corte', _f(vU, 1), unidad: 'mm/s', nota: '${_f(vU * 60)} mm/min', editable: true),
      Parametro('potencia_pct', 'Potencia', _f(potU), unidad: '%', nota: 'no uses el tubo al 100 %', editable: true),
      Parametro('pasadas', 'Pasadas', '$pasU', editable: true),
      Parametro('foco', 'Enfoque', espesor >= 6 ? 'a ${_f(espesor / 2, 1)} mm dentro del material' : 'en la superficie'),
      const Parametro('aire', 'Aire (air assist)', 'encendido, fuerte'),
      Parametro('kerf', 'Ancho de corte (kerf)', _f(0.1 + espesor * 0.015, 2), unidad: 'mm'),
      Parametro('tubo', 'Tubo', '${_f(W)} W'),
    ];
    if (espesor > espMax) avisos.add('${_f(espesor, 1)} mm está arriba de lo que un tubo de ${_f(W)} W corta bien en ${M.nombre} (≈ ${_f(espMax, 1)} mm): canto quemado o no atraviesa. Considera router.');
    if (M.aviso != null) avisos.add(M.aviso!);
    avisos.add('Prueba en un retazo: la potencia real cambia con la edad del tubo, el foco y la limpieza de espejos.');
    return Receta(titulo: 'Corte láser · ${M.nombre} ${_f(espesor, espesor % 1 == 0 ? 0 : 1)} mm', operacion: 'laser_corte', parametros: params, avisos: avisos, faltan: faltan,
      corteMMin: efectiva, segPorEntrada: 0.5, ajustables: {'velocidad': vU, 'potencia_pct': potU, 'pasadas': pasU.toDouble()});
  }
  final g = M.grabado;
  final f = math.pow(80 / W, 0.7).toDouble();
  final pmin = _clamp(g[2] * f, 5, 90), pmax = _clamp(g[3] * f, 8, 95);
  final vU = velocidadMmS ?? (g[0] + g[1]) / 2;
  final potU = potenciaPct ?? (pmin + pmax) / 2;
  const intervalo = 0.1;
  final cm2min = vU * intervalo * 60 / 100 / 1.25;
  final params = <Parametro>[
    Parametro('velocidad', 'Velocidad de grabado', _f(vU), unidad: 'mm/s', nota: 'rango ${_f(g[0])}–${_f(g[1])}', editable: true),
    Parametro('potencia_pct', 'Potencia', _f(potU), unidad: '%', nota: 'rango ${_f(pmin)}–${_f(pmax)}', editable: true),
    const Parametro('intervalo', 'Intervalo de línea', '0.08–0.10 mm', nota: '≈ 250–320 DPI'),
    const Parametro('aire', 'Aire', 'bajo'),
    Parametro('cm2', 'Área por minuto', _f(cm2min, 1), unidad: 'cm²/min'),
  ];
  if (M.aviso != null) avisos.add(M.aviso!);
  return Receta(titulo: 'Grabado láser · ${M.nombre}', operacion: 'laser_grabado', parametros: params, avisos: avisos, faltan: faltan,
    grabadoCm2Min: cm2min, ajustables: {'velocidad': vU, 'potencia_pct': potU});
}

// ─────────────────────────── PLASMA ───────────────────────────
const _PLASMA = <int, List<List<double>>>{
  30: [[1.5, 5000], [3, 2000], [6, 600], [8, 350]],
  45: [[1.5, 8000], [3, 5500], [6, 2200], [10, 900], [12, 600], [16, 350]],
  65: [[3, 8000], [6, 3600], [10, 1900], [12, 1400], [16, 900], [20, 600], [25, 300]],
  85: [[3, 9000], [6, 5000], [10, 2800], [12, 2100], [16, 1400], [20, 1000], [25, 600], [32, 380]],
  105: [[6, 6000], [10, 3500], [12, 2800], [16, 1900], [20, 1400], [25, 900], [32, 550], [38, 380]],
};
// boquilla (orificio) y voltaje de arco típicos por amperaje
const _PLASMA_CONS = <int, List<String>>{
  30: ['0.8 mm (30 A)', '95–110 V'], 45: ['1.0 mm (45 A)', '115–130 V'], 65: ['1.2 mm (65 A)', '125–135 V'],
  85: ['1.4 mm (85 A)', '130–140 V'], 105: ['1.6 mm (105 A)', '135–150 V'],
};
const _PLASMA_MAT = <String, List<double>>{'acero': [1, 1], 'inox': [0.75, 0.8], 'aluminio': [1.1, 0.8], 'cobre': [0.6, 0.7]};

Receta recetaPlasma({required String material, required double espesor, required MaquinaReceta maq, double? amperaje, double? velocidad}) {
  final avisos = <String>[], faltan = <String>[];
  final A = amperaje ?? (maq.potencia > 0 ? maq.potencia : 45.0);
  if (maq.potencia <= 0 && amperaje == null) faltan.add('Amperaje de tu fuente de plasma (A)');
  final m = _PLASMA_MAT[material] ?? _PLASMA_MAT['acero']!;
  final claves = _PLASMA.keys.toList()..sort();
  final clave = claves.reduce((a, b) => (a - A).abs() <= (b - A).abs() ? a : b);
  final tabla = _PLASMA[clave]!;
  final espEq = espesor / m[1];
  final maxCalidad = tabla.last[0] * m[1];
  double v = _interp(tabla, espEq, log: true) * m[0];
  if (espEq > tabla.last[0]) v = (tabla.last[1] * math.pow(tabla.last[0] / espEq, 1.5) * m[0]).toDouble();
  final vU = velocidad ?? (v / 10).round() * 10.0;
  final retardo = espesor <= 3 ? 0.1 : espesor <= 6 ? 0.3 : espesor <= 10 ? 0.5 : espesor <= 16 ? 0.8 : 1.2;
  final cons = _PLASMA_CONS[clave]!;
  final params = <Parametro>[
    Parametro('amperaje', 'Amperaje', _f(A), unidad: 'A', nota: clave != A.round() ? 'tabla de $clave A' : null, editable: true),
    Parametro('boquilla', 'Boquilla / tip', cons[0], nota: 'consumibles del amperaje que usas'),
    Parametro('velocidad', 'Velocidad de corte', _f(vU), unidad: 'mm/min', nota: 'ajusta ±15 % según la escoria', editable: true),
    Parametro('arco', 'Voltaje de arco (THC)', cons[1], nota: 'el real lo marca tu antorcha'),
    const Parametro('altura_corte', 'Altura de corte', '1.5', unidad: 'mm'),
    const Parametro('altura_perf', 'Altura de perforación', '3.8', unidad: 'mm', nota: '≈ 2.5 × la de corte'),
    Parametro('retardo', 'Retardo de perforación', _f(retardo, 1), unidad: 's'),
    const Parametro('aire', 'Presión de aire', '5.5–6 bar (80–90 psi)', nota: 'seco y sin aceite'),
    Parametro('kerf', 'Kerf', _f(1.2 + espesor * 0.05, 1), unidad: 'mm', nota: 'compénsalo en el CAM'),
  ];
  if (espesor > maxCalidad) avisos.add('${_f(espesor)} mm pasa del corte de calidad para $clave A (≈ ${_f(maxCalidad)} mm): será corte de separación con escoria y bisel. Empieza desde el borde.');
  if (espesor > maxCalidad * 0.5) avisos.add('Grueso: perfora en zona de desperdicio; perforar grueso gasta rápido los consumibles.');
  avisos.add('Escoria en bolitas abajo: vas lento. Escoria dura con chispa adelante: vas rápido. Bisel: revisa altura y consumibles.');
  final efectiva = vU / 1000 / 1.1;
  return Receta(titulo: 'Plasma · ${material == 'inox' ? 'Inoxidable' : material == 'aluminio' ? 'Aluminio' : 'Acero'} ${_f(espesor, espesor % 1 == 0 ? 0 : 1)} mm',
    operacion: 'plasma', parametros: params, avisos: avisos, faltan: faltan,
    corteMMin: efectiva, segPorEntrada: retardo + 1.5, ajustables: {'amperaje': A, 'velocidad': vU});
}

// ─────────────────────────── FIBRA ───────────────────────────
const _FIBRA = <String, Map<int, List<List<double>>>>{
  'acero': {1: [[1, 10], [2, 5], [3, 3.5], [4, 2.6], [6, 1.5], [8, 1]], 2: [[1, 20], [2, 8], [3, 5], [6, 2.2], [8, 1.5], [10, 1.1], [12, 0.9]], 3: [[1, 30], [3, 5.5], [6, 2.6], [10, 1.4], [12, 1.1], [16, 0.8], [20, 0.6]], 6: [[3, 6], [6, 3], [10, 2], [16, 1.2], [20, 0.9], [25, 0.6]]},
  'inox': {1: [[1, 18], [2, 6], [3, 2.5], [4, 1.2]], 2: [[1, 25], [2, 12], [3, 6], [5, 2.5], [6, 1.5]], 3: [[1, 35], [3, 10], [5, 4], [8, 1.5], [10, 1]], 6: [[3, 25], [6, 8], [10, 3], [12, 2], [16, 1]]},
  'aluminio': {1: [[1, 12], [2, 4], [3, 1.5]], 2: [[1, 20], [2, 8], [3, 4], [5, 1.5]], 3: [[1, 28], [3, 7], [5, 3], [8, 1.2]], 6: [[3, 20], [6, 6], [10, 2], [12, 1.4]]},
};

Receta recetaFibra({required String material, required double espesor, required MaquinaReceta maq, double? velocidadMMin}) {
  final avisos = <String>[], faltan = <String>[];
  final kw = maq.potencia > 0 ? maq.potencia : 2.0;
  if (maq.potencia <= 0) faltan.add('Potencia de la fuente de fibra (kW)');
  final tablas = _FIBRA[material] ?? _FIBRA['acero']!;
  final claves = tablas.keys.toList()..sort();
  final c = claves.reduce((a, b) => (a - kw).abs() <= (b - kw).abs() ? a : b);
  final t = tablas[c]!;
  final v = (espesor > t.last[0] ? t.last[1] * math.pow(t.last[0] / espesor, 2) : _interp(t, espesor, log: true)).toDouble();
  final vU = velocidadMMin ?? double.parse(v.toStringAsFixed(2));
  final gas = material == 'acero' ? (espesor <= 3 && c >= 3 ? 'Nitrógeno o aire (delgado); oxígeno si quieres más espesor' : 'Oxígeno') : 'Nitrógeno';
  final params = <Parametro>[
    Parametro('velocidad', 'Velocidad de corte', _f(vU, 2), unidad: 'm/min', nota: 'tabla de $c kW', editable: true),
    Parametro('gas', 'Gas', gas),
    Parametro('presion', 'Presión', material == 'acero' && gas.startsWith('Ox') ? '0.5–1 bar' : '10–16 bar'),
    Parametro('boquilla', 'Boquilla', espesor <= 3 ? 'simple 1.0–1.5 mm' : 'doble 2.0–3.0 mm'),
    Parametro('foco', 'Foco', material == 'acero' ? 'positivo, sobre la superficie' : 'negativo, dentro del material'),
    const Parametro('altura', 'Altura de boquilla', '0.5–1.0', unidad: 'mm'),
    Parametro('kerf', 'Kerf', _f(0.1 + espesor * 0.02, 2), unidad: 'mm'),
  ];
  if (espesor > t.last[0]) avisos.add('${_f(espesor)} mm pasa del espesor de producción para $c kW (≈ ${_f(t.last[0])} mm).');
  avisos.add('Las tablas de proceso de tu máquina (cabezal, boquilla, gas) mandan.');
  return Receta(titulo: 'Láser de fibra · ${material == 'inox' ? 'Inoxidable' : material == 'aluminio' ? 'Aluminio' : 'Acero'} ${_f(espesor, espesor % 1 == 0 ? 0 : 1)} mm',
    operacion: 'fibra', parametros: params, avisos: avisos, faltan: faltan, corteMMin: vU / 1.2, segPorEntrada: 0.3, ajustables: {'velocidad': vU});
}

// ─────────────────────────── IMPRESIÓN 3D ───────────────────────────
const _IMP = <String, List<String>>{
  'pla': ['PLA', '200–215 °C', '55–60 °C'], 'petg': ['PETG', '230–245 °C', '70–85 °C'], 'abs': ['ABS / ASA', '240–255 °C', '95–110 °C (cerrada)'],
  'tpu': ['TPU', '220–235 °C', '40–60 °C'], 'resina': ['Resina', '—', '—'],
};

Receta recetaImpresion({required String material, double? capa, double? boquilla, double? velocidad, double rellenoPct = 20}) {
  final m = _IMP[material] ?? _IMP['pla']!;
  if (material == 'resina') {
    return Receta(titulo: 'Impresión 3D · Resina', operacion: 'impresion', parametros: const [
      Parametro('capa', 'Altura de capa', '0.05', unidad: 'mm', editable: true), Parametro('exp', 'Exposición', '2–3', unidad: 's'),
      Parametro('cm3h', 'Volumen por hora', '≈ 20', unidad: 'cm³/h', nota: 'depende de la altura, no del número de piezas'),
    ], avisos: const ['Guantes y ventilación; lava con alcohol isopropílico y cura con UV.'], impresionCm3H: 20, ajustables: const {'capa': 0.05});
  }
  final c = capa ?? 0.2, b = boquilla ?? 0.4, v = velocidad ?? (material == 'tpu' ? 30.0 : 60.0);
  final flujo = c * b * 1.1 * v * 0.55; // mm³/s reales
  final cm3h = flujo * 3.6;
  final params = <Parametro>[
    Parametro('boquilla', 'Boquilla', _f(b, 1), unidad: 'mm', editable: true),
    Parametro('capa', 'Altura de capa', _f(c, 2), unidad: 'mm', editable: true),
    Parametro('velocidad', 'Velocidad', _f(v), unidad: 'mm/s', editable: true),
    Parametro('relleno', 'Relleno', '${_f(rellenoPct)} %', nota: '3 perímetros, 4 capas arriba/abajo'),
    Parametro('temp', 'Temperatura', m[1]), Parametro('cama', 'Cama', m[2]),
    Parametro('cm3h', 'Volumen por hora', _f(cm3h, 1), unidad: 'cm³/h', nota: 'ya con viajes y aceleraciones'),
  ];
  return Receta(titulo: 'Impresión 3D · ${m[0]}', operacion: 'impresion', parametros: params,
    avisos: ['El laminador (Cura, Prusa, Orca) da el tiempo exacto; esto es para cotizar.'],
    impresionCm3H: cm3h, ajustables: {'capa': c, 'boquilla': b, 'velocidad': v});
}

// ─────────────────────────── despacho ───────────────────────────
/// Arma la receta para el trabajo. `ajustes` son los valores que el taller
/// guardó (clave → número) y se aplican encima de la sugerencia HETNA.
Receta recetaPara({
  required String tipoMaquina, required String servicio, // corte2D | grabado | relieve3D | impresion3D | torno
  required String material, required double espesor, required MaquinaReceta maq,
  Map<String, double> ajustes = const {}, double rellenoPct = 20,
}) {
  double? a(String k) => ajustes[k];
  switch (tipoMaquina) {
    case 'laser_co2':
      return recetaLaserCo2(material: material, espesor: espesor, maq: maq, grabado: servicio == 'grabado',
        velocidadMmS: a('velocidad'), potenciaPct: a('potencia_pct'), pasadas: a('pasadas')?.round());
    case 'plasma':
      return recetaPlasma(material: material, espesor: espesor, maq: maq, amperaje: a('amperaje'), velocidad: a('velocidad'));
    case 'laser_fibra':
      return recetaFibra(material: material, espesor: espesor, maq: maq, velocidadMMin: a('velocidad'));
    case 'impresora_3d':
      return recetaImpresion(material: material, capa: a('capa'), boquilla: a('boquilla'), velocidad: a('velocidad'), rellenoPct: rellenoPct);
    case 'torno':
      // Torneado: se trata como desbaste con remoción fija por material
      return recetaRelieve(material: material, espesor: espesor, maq: maq, fresaDesbaste: a('fresa_desbaste'), avanceDesbaste: a('avance_desbaste'));
    default: // router, router_3d
      if (servicio == 'relieve3D') {
        return recetaRelieve(material: material, espesor: espesor, maq: maq, fresaDesbaste: a('fresa_desbaste'), fresaAcabado: a('fresa_acabado'),
          stepoverAcabadoPct: a('stepover_acabado_pct'), avanceDesbaste: a('avance_desbaste'), avanceAcabado: a('avance_acabado'));
      }
      return recetaRouter(material: material, espesor: espesor, maq: maq, operacion: servicio == 'grabado' ? 'grabado_v' : 'perfil',
        diametro: a('diametro'), filos: a('filos')?.round(), rpm: a('rpm'), avance: a('avance'), pasadas: a('pasadas')?.round());
  }
}
