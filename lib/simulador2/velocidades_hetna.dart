// lib/simulador2/velocidades_hetna.dart
// HETNA CNC — Velocidades sugeridas por tipo de máquina, material y espesor.
//
// Son valores de arranque para que el taller cotice desde el primer día; se
// muestran como "sugerido" hasta que el taller los confirme o los corrija
// con sus tiempos reales (ver motor.dart → aprendizaje). Son velocidades
// EFECTIVAS de corte perimetral (ya con las pasadas que lleva ese espesor),
// no el avance del G-code.
//
// Fuente: tablas típicas de fabricantes y práctica de taller en México con
// router 2.2–3 kW y fresa de 6 mm, láser CO2 80–100 W, plasma de aire 40–60 A,
// láser de fibra 1–2 kW. Son aproximadas: cada máquina es distinta.

/// Tipos de material del simulador, con nombre bonito y densidad (g/cm³)
/// para impresión 3D y para estimar peso.
class TipoMaterial {
  final String clave, nombre, grupo; // grupo: madera | plastico | metal | otro | filamento
  final double densidad; // g/cm³
  const TipoMaterial(this.clave, this.nombre, this.grupo, this.densidad);
}

const tiposMaterial = <TipoMaterial>[
  TipoMaterial('mdf', 'MDF', 'madera', 0.75),
  TipoMaterial('triplay', 'Triplay / contrachapado', 'madera', 0.60),
  TipoMaterial('madera', 'Madera sólida', 'madera', 0.65),
  TipoMaterial('melamina', 'Melamina / aglomerado', 'madera', 0.68),
  TipoMaterial('acrilico', 'Acrílico', 'plastico', 1.19),
  TipoMaterial('pvc', 'PVC espumado (Sintra)', 'plastico', 0.55),
  TipoMaterial('hdpe', 'HDPE / Nylon / Celorón', 'plastico', 0.96),
  TipoMaterial('policarbonato', 'Policarbonato', 'plastico', 1.20),
  TipoMaterial('aluminio', 'Aluminio', 'metal', 2.70),
  TipoMaterial('acero', 'Acero al carbón', 'metal', 7.85),
  TipoMaterial('inox', 'Acero inoxidable', 'metal', 7.90),
  TipoMaterial('cobre', 'Cobre / latón', 'metal', 8.60),
  TipoMaterial('espuma', 'Espuma / unicel / EVA', 'otro', 0.05),
  TipoMaterial('carton', 'Cartón / papel', 'otro', 0.70),
  TipoMaterial('cuero', 'Cuero / tela', 'otro', 0.90),
  TipoMaterial('pla', 'PLA', 'filamento', 1.24),
  TipoMaterial('petg', 'PETG', 'filamento', 1.27),
  TipoMaterial('abs', 'ABS / ASA', 'filamento', 1.04),
  TipoMaterial('tpu', 'TPU flexible', 'filamento', 1.21),
  TipoMaterial('resina', 'Resina (SLA)', 'filamento', 1.10),
];

TipoMaterial? tipoMaterialPorClave(String? clave) {
  if (clave == null) return null;
  for (final t in tiposMaterial) { if (t.clave == clave) return t; }
  return null;
}

/// Adivina el tipo de material a partir del nombre que el taller puso en su
/// inventario ("MDF 18 mm natural" → mdf; "Acrílico cristal 6mm" → acrilico).
String? adivinarTipoMaterial(String nombre) {
  final n = nombre.toLowerCase();
  const pistas = <String, List<String>>{
    'mdf': ['mdf', 'fibracel'],
    'triplay': ['triplay', 'contrachap', 'plywood', 'multilaminado'],
    'melamina': ['melamina', 'aglomerado', 'mdp'],
    'madera': ['pino', 'encino', 'nogal', 'cedro', 'caoba', 'madera', 'tzalam', 'parota', 'maple'],
    'acrilico': ['acril', 'acryl', 'pmma'],
    'pvc': ['pvc', 'sintra', 'espumado', 'trovicel'],
    'hdpe': ['hdpe', 'nylon', 'celor', 'polietileno', 'delrin', 'pom'],
    'policarbonato': ['policarb', 'lexan'],
    'aluminio': ['alumin', 'alu '],
    'inox': ['inox', 'inoxid', 'stainless', '304', '316'],
    'acero': ['acero', 'lámina negra', 'lamina negra', 'hierro', 'placa', 'calibre', 'cal.'],
    'cobre': ['cobre', 'latón', 'laton', 'bronce'],
    'espuma': ['espuma', 'unicel', 'eva', 'foam', 'poliuretano'],
    'carton': ['cartón', 'carton', 'papel', 'cartulina'],
    'cuero': ['cuero', 'piel', 'tela', 'fieltro'],
    'pla': ['pla'],
    'petg': ['petg'],
    'abs': ['abs', 'asa'],
    'tpu': ['tpu', 'flex'],
    'resina': ['resina', 'resin'],
  };
  for (final e in pistas.entries) {
    for (final p in e.value) { if (n.contains(p)) return e.key; }
  }
  return null;
}

/// Adivina el espesor en mm del nombre ("MDF 18 mm", "acrílico 3mm", "cal 14").
double adivinarEspesor(String nombre) {
  final n = nombre.toLowerCase();
  final mm = RegExp(r'(\d+(?:[.,]\d+)?)\s*mm').firstMatch(n);
  if (mm != null) return double.tryParse(mm.group(1)!.replaceAll(',', '.')) ?? 0;
  final pulg = RegExp(r'(\d+)/(\d+)\s*(?:"|in|pulg)').firstMatch(n);
  if (pulg != null) {
    final a = double.parse(pulg.group(1)!), b = double.parse(pulg.group(2)!);
    return b > 0 ? a / b * 25.4 : 0;
  }
  final cal = RegExp(r'cal(?:ibre)?\.?\s*(\d+)').firstMatch(n);
  if (cal != null) {
    const calibres = {10: 3.4, 11: 3.0, 12: 2.7, 14: 1.9, 16: 1.5, 18: 1.2, 20: 0.9, 22: 0.75, 24: 0.6};
    return calibres[int.parse(cal.group(1)!)] ?? 0;
  }
  return 0;
}

/// Tabla: tipo de máquina → tipo de material → [(espesor mm, m/min)].
/// Se interpola entre espesores; fuera de la tabla se usa el extremo.
const _corte = <String, Map<String, List<List<double>>>>{
  'router': {
    'mdf':      [[3, 4.0], [6, 3.5], [9, 3.0], [12, 2.5], [15, 2.2], [18, 2.0], [25, 1.4], [30, 1.1]],
    'triplay':  [[3, 3.6], [6, 3.2], [9, 2.7], [12, 2.2], [15, 2.0], [18, 1.8], [25, 1.2]],
    'melamina': [[12, 2.4], [15, 2.1], [18, 1.9], [25, 1.3]],
    'madera':   [[6, 2.8], [12, 2.0], [18, 1.5], [25, 1.0], [38, 0.6]],
    'acrilico': [[3, 2.5], [6, 1.5], [10, 1.0], [12, 0.8], [18, 0.5], [25, 0.3]],
    'pvc':      [[3, 4.0], [6, 3.5], [10, 2.5], [19, 1.5], [25, 1.0]],
    'hdpe':     [[6, 2.0], [12, 1.2], [19, 0.8], [25, 0.6]],
    'policarbonato': [[3, 1.8], [6, 1.0], [10, 0.6]],
    'aluminio': [[1.5, 0.6], [3, 0.4], [6, 0.25], [10, 0.15], [12, 0.1]],
    'espuma':   [[25, 5.0], [50, 3.5], [100, 2.0]],
    'cobre':    [[1.5, 0.4], [3, 0.25], [6, 0.12]],
  },
  'laser_co2': {
    'mdf':      [[3, 1.2], [6, 0.6], [9, 0.35], [12, 0.2]],
    'triplay':  [[3, 1.0], [6, 0.5], [9, 0.3]],
    'acrilico': [[3, 0.8], [6, 0.4], [10, 0.2], [12, 0.15], [18, 0.08]],
    'carton':   [[1, 3.0], [3, 2.0], [5, 1.2]],
    'cuero':    [[1, 1.8], [2, 1.5], [3, 1.2]],
    'espuma':   [[3, 2.5], [10, 1.5], [20, 0.8]],
    'madera':   [[3, 0.9], [6, 0.45], [10, 0.25]],
  },
  'plasma': {
    'acero':    [[1.5, 3.5], [3, 2.5], [4.8, 1.8], [6, 1.3], [10, 0.8], [12, 0.6], [16, 0.4], [20, 0.3]],
    'inox':     [[1.5, 3.0], [3, 1.8], [6, 1.0], [10, 0.6], [12, 0.45]],
    'aluminio': [[1.5, 3.5], [3, 2.5], [6, 1.5], [10, 0.9], [12, 0.7]],
    'cobre':    [[1.5, 2.0], [3, 1.2], [6, 0.7]],
  },
  'laser_fibra': {
    'acero':    [[1, 10.0], [2, 6.0], [3, 4.0], [5, 2.0], [6, 1.5], [8, 1.0], [10, 0.7], [12, 0.5]],
    'inox':     [[1, 8.0], [2, 4.0], [3, 2.5], [5, 1.2], [6, 0.9], [8, 0.5]],
    'aluminio': [[1, 6.0], [2, 3.0], [3, 2.0], [5, 0.9], [6, 0.6]],
    'cobre':    [[1, 4.0], [2, 2.0], [3, 1.0]],
  },
};

/// Grabado por área (cm²/min): láser rasterizado, router con fresa V.
const _grabado = <String, Map<String, double>>{
  'laser_co2':   {'mdf': 60, 'triplay': 60, 'madera': 50, 'acrilico': 70, 'cuero': 80, 'carton': 90, 'espuma': 90},
  'laser_fibra': {'acero': 40, 'inox': 40, 'aluminio': 35, 'cobre': 30},
  'router':      {'mdf': 25, 'triplay': 22, 'madera': 18, 'acrilico': 15, 'pvc': 25, 'hdpe': 15, 'aluminio': 4},
};

/// Router 3D / relieve / torno: cm³ que quita por minuto (desbaste + acabado promediados).
const _remocion = <String, Map<String, double>>{
  'router_3d': {'mdf': 20, 'triplay': 18, 'melamina': 18, 'madera': 15, 'acrilico': 8, 'pvc': 25, 'hdpe': 12, 'policarbonato': 6, 'aluminio': 2.0, 'espuma': 60, 'cobre': 1.2},
  'router':    {'mdf': 20, 'triplay': 18, 'melamina': 18, 'madera': 15, 'acrilico': 8, 'pvc': 25, 'hdpe': 12, 'policarbonato': 6, 'aluminio': 2.0, 'espuma': 60, 'cobre': 1.2},
  'torno':     {'aluminio': 6, 'acero': 2.5, 'inox': 1.5, 'cobre': 4, 'hdpe': 10, 'madera': 25, 'acrilico': 8},
};

/// Impresora 3D: cm³ por hora (boquilla 0.4, capa 0.2, relleno 20 %).
const _impresion = <String, double>{
  'pla': 12, 'petg': 10, 'abs': 10, 'tpu': 5, 'resina': 20,
};

double _interpolar(List<List<double>> tabla, double espesor) {
  if (tabla.isEmpty) return 0;
  if (espesor <= tabla.first[0]) return tabla.first[1];
  if (espesor >= tabla.last[0]) return tabla.last[1] * (tabla.last[0] / espesor); // más grueso: proporcional
  for (int i = 0; i + 1 < tabla.length; i++) {
    final a = tabla[i], b = tabla[i + 1];
    if (espesor >= a[0] && espesor <= b[0]) {
      final f = (espesor - a[0]) / (b[0] - a[0]);
      return a[1] + (b[1] - a[1]) * f;
    }
  }
  return tabla.last[1];
}

/// Velocidad de corte sugerida (m/min) o 0 si HETNA no tiene dato.
double velocidadCorteSugerida(String tipoMaquina, String tipoMaterial, double espesorMm) {
  final t = _corte[tipoMaquina]?[tipoMaterial];
  if (t == null) return 0;
  return _interpolar(t, espesorMm <= 0 ? t.first[0] : espesorMm);
}

double velocidadGrabadoSugerida(String tipoMaquina, String tipoMaterial) =>
  _grabado[tipoMaquina]?[tipoMaterial] ?? 0;

double remocionSugerida(String tipoMaquina, String tipoMaterial) =>
  _remocion[tipoMaquina]?[tipoMaterial] ?? 0;

double impresionSugerida(String tipoMaterial) => _impresion[tipoMaterial] ?? 0;

/// Nombre bonito del tipo de máquina.
const nombresTipoMaquina = <String, String>{
  'router': 'Router CNC',
  'laser_co2': 'Láser CO2',
  'laser_fibra': 'Láser de fibra',
  'plasma': 'Plasma CNC',
  'router_3d': 'Router 3D / relieve',
  'impresora_3d': 'Impresora 3D',
  'torno': 'Torno CNC',
  'otro': 'Otra',
};

const emojiTipoMaquina = <String, String>{
  'router': '🪚', 'laser_co2': '🔦', 'laser_fibra': '⚡', 'plasma': '🔥',
  'router_3d': '🗿', 'impresora_3d': '🖨️', 'torno': '🔩', 'otro': '⚙️',
};

/// Qué materiales tiene sentido ofrecer para cada tipo de máquina.
List<TipoMaterial> materialesParaMaquina(String tipoMaquina) {
  switch (tipoMaquina) {
    case 'impresora_3d': return tiposMaterial.where((t) => t.grupo == 'filamento').toList();
    case 'plasma': return tiposMaterial.where((t) => t.grupo == 'metal').toList();
    case 'laser_fibra': return tiposMaterial.where((t) => t.grupo == 'metal').toList();
    case 'laser_co2': return tiposMaterial.where((t) => t.grupo != 'metal' && t.grupo != 'filamento').toList();
    case 'torno': return tiposMaterial.where((t) => t.grupo == 'metal' || t.clave == 'hdpe' || t.clave == 'madera' || t.clave == 'acrilico').toList();
    default: return tiposMaterial.where((t) => t.grupo != 'filamento' && t.clave != 'acero' && t.clave != 'inox').toList();
  }
}
