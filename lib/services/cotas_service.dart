// lib/services/cotas_service.dart
// HETNA CNC — Cotas de cada tramo del dibujo: largo de cada línea, radio de
// cada arco y diámetro de cada barreno. Dart puro (sin Flutter) para probarlo
// solo.
//
// Trabaja sobre las polilíneas que ya saca ArchivoCadService (los arcos y
// círculos del DXF/SVG llegan como muchos tramos cortos):
//   - un trazo cerrado casi circular       → barreno Ø
//   - tramos seguidos casi en línea recta  → una sola línea con su largo
//   - tramos cortos que giran parejo       → un arco con su radio
import 'dart:math' as math;

enum TipoCota { linea, arco, diametro, distancia }

class Cota {
  final int n; // número para la tabla y para el dibujo cuando no cabe el texto
  final TipoCota tipo;
  final double valor; // largo (línea), radio (arco) o diámetro (barreno), en mm
  final double largoArco; // sólo arcos: largo del arco en mm
  // Línea: extremos. Arco y barreno: centro y radio.
  final double x1, y1, x2, y2;
  final double cx, cy, r;
  // Dónde poner la etiqueta (mm, mismo sistema que los trazos)
  final double ex, ey;
  // Barrenos: ubicación del centro desde la esquina inferior izquierda de la pieza
  final double posX, posY;
  const Cota({required this.n, required this.tipo, required this.valor, this.largoArco = 0,
    this.x1 = 0, this.y1 = 0, this.x2 = 0, this.y2 = 0, this.cx = 0, this.cy = 0, this.r = 0,
    required this.ex, required this.ey, this.posX = 0, this.posY = 0});

  String get prefijo => tipo == TipoCota.diametro ? 'Ø' : tipo == TipoCota.arco ? 'R' : '';
  /// "120", "R5", "Ø8.5"
  String get texto => '$prefijo${fmtMm(valor)}';
  String get nombreTipo => tipo == TipoCota.linea ? 'Línea' : tipo == TipoCota.arco ? 'Arco' : tipo == TipoCota.diametro ? 'Barreno' : 'Entre barrenos';
  /// "X 30 · Y 40" para los barrenos
  String get ubicacion => tipo == TipoCota.diametro ? 'X ${fmtMm(posX)} · Y ${fmtMm(posY)}' : '';
}

String fmtMm(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
}

const double _gradosRecta = 2.0; // giro menor a esto entre tramos = misma línea
const double _gradosArcoMax = 35.0; // giro mayor = esquina, no arco
const double _tramoArcoMax = 0.25; // un tramo de arco es corto comparado con su radio aproximado

double _ang(double dx, double dy) => math.atan2(dy, dx);
double _giro(double a0, double a1) {
  var d = a1 - a0;
  while (d > math.pi) { d -= 2 * math.pi; }
  while (d < -math.pi) { d += 2 * math.pi; }
  return d;
}

bool _cerrado(List<List<double>> p) =>
  p.length > 2 && (p.first[0] - p.last[0]).abs() < 0.01 && (p.first[1] - p.last[1]).abs() < 0.01;

/// Centro y radio del círculo que pasa por tres puntos (null si están en línea).
({double cx, double cy, double r})? _circulo3(List<double> a, List<double> b, List<double> c) {
  final d = 2 * (a[0] * (b[1] - c[1]) + b[0] * (c[1] - a[1]) + c[0] * (a[1] - b[1]));
  if (d.abs() < 1e-9) return null;
  final a2 = a[0] * a[0] + a[1] * a[1], b2 = b[0] * b[0] + b[1] * b[1], c2 = c[0] * c[0] + c[1] * c[1];
  final cx = (a2 * (b[1] - c[1]) + b2 * (c[1] - a[1]) + c2 * (a[1] - b[1])) / d;
  final cy = (a2 * (c[0] - b[0]) + b2 * (a[0] - c[0]) + c2 * (b[0] - a[0])) / d;
  return (cx: cx, cy: cy, r: math.sqrt(math.pow(a[0] - cx, 2) + math.pow(a[1] - cy, 2)));
}

/// Todas las cotas del dibujo. [minMm]: tramos más cortos se ignoran (ruido del archivo).
List<Cota> cotasDe(List<List<List<double>>> trazos, {double minMm = 0.5}) {
  final out = <Cota>[];
  int n = 0;
  // Esquina inferior izquierda de la pieza: de ahí se miden las ubicaciones
  double minX = double.infinity, minY = double.infinity;
  for (final t in trazos) { for (final q in t) { if (q.length >= 2) { minX = math.min(minX, q[0]); minY = math.min(minY, q[1]); } } }
  if (!minX.isFinite) { minX = 0; minY = 0; }
  for (final t0 in trazos) {
    // Quita puntos repetidos
    final t = <List<double>>[];
    for (final q in t0) {
      if (q.length < 2) continue;
      if (t.isEmpty || (t.last[0] - q[0]).abs() > 1e-6 || (t.last[1] - q[1]).abs() > 1e-6) t.add(q);
    }
    if (t.length < 2) continue;

    // Barreno: trazo cerrado casi circular
    if (_cerrado(t) && t.length >= 9) {
      double cx = 0, cy = 0;
      for (int i = 0; i < t.length - 1; i++) { cx += t[i][0]; cy += t[i][1]; }
      cx /= (t.length - 1); cy /= (t.length - 1);
      double rmin = double.infinity, rmax = 0, rsum = 0;
      for (int i = 0; i < t.length - 1; i++) {
        final r = math.sqrt(math.pow(t[i][0] - cx, 2) + math.pow(t[i][1] - cy, 2));
        rmin = math.min(rmin, r); rmax = math.max(rmax, r); rsum += r;
      }
      if (rmax > 0 && (rmax - rmin) / rmax < 0.06) {
        final r = rsum / (t.length - 1);
        out.add(Cota(n: ++n, tipo: TipoCota.diametro, valor: 2 * r, cx: cx, cy: cy, r: r, ex: cx + r * 0.7071, ey: cy + r * 0.7071,
          posX: cx - minX, posY: cy - minY));
        continue;
      }
    }

    // Tramos con su dirección y largo
    final segs = <({List<double> a, List<double> b, double ang, double len})>[];
    for (int i = 0; i + 1 < t.length; i++) {
      final a = t[i], b = t[i + 1];
      final len = math.sqrt(math.pow(b[0] - a[0], 2) + math.pow(b[1] - a[1], 2));
      if (len < 1e-6) continue;
      segs.add((a: a, b: b, ang: _ang(b[0] - a[0], b[1] - a[1]), len: len));
    }
    int i = 0;
    while (i < segs.length) {
      // ¿Empieza aquí un arco? Al menos 3 tramos cortos que giran parejo hacia el mismo lado
      int j = i;
      double sentido = 0;
      while (j + 1 < segs.length) {
        final g = _giro(segs[j].ang, segs[j + 1].ang);
        final gg = g.abs() * 180 / math.pi;
        if (gg < _gradosRecta || gg > _gradosArcoMax) break;
        if (sentido != 0 && g.sign != sentido) break;
        // tramos parecidos de largo (los arcos discretizados son parejos)
        final rel = segs[j + 1].len / segs[j].len;
        if (rel < 0.5 || rel > 2.0) break;
        sentido = g.sign;
        j++;
      }
      if (j - i + 1 >= 3) {
        final pa = segs[i].a, pb = segs[j].b, pm = segs[(i + j) ~/ 2].b;
        final c = _circulo3(pa, pm, pb);
        double largo = 0;
        for (int k = i; k <= j; k++) { largo += segs[k].len; }
        if (c != null && segs[i].len / c.r <= _tramoArcoMax * 4 && largo >= minMm) {
          out.add(Cota(n: ++n, tipo: TipoCota.arco, valor: c.r, largoArco: largo, cx: c.cx, cy: c.cy, r: c.r, ex: pm[0], ey: pm[1]));
          i = j + 1;
          continue;
        }
      }
      // Línea: junta los tramos que siguen casi en la misma dirección
      int k = i;
      while (k + 1 < segs.length && (_giro(segs[k].ang, segs[k + 1].ang).abs() * 180 / math.pi) < _gradosRecta) { k++; }
      final a = segs[i].a, b = segs[k].b;
      final len = math.sqrt(math.pow(b[0] - a[0], 2) + math.pow(b[1] - a[1], 2));
      if (len >= minMm) {
        out.add(Cota(n: ++n, tipo: TipoCota.linea, valor: len, x1: a[0], y1: a[1], x2: b[0], y2: b[1], ex: (a[0] + b[0]) / 2, ey: (a[1] + b[1]) / 2));
      }
      i = k + 1;
    }
  }
  // Distancia entre barrenos que están en la misma fila o columna (centro a centro)
  final barrenos = out.where((c) => c.tipo == TipoCota.diametro).toList();
  void entre(List<Cota> grupo, bool horizontal) {
    grupo.sort((a, b) => horizontal ? a.cx.compareTo(b.cx) : a.cy.compareTo(b.cy));
    for (int k = 0; k + 1 < grupo.length; k++) {
      final a = grupo[k], b = grupo[k + 1];
      final d = horizontal ? (b.cx - a.cx).abs() : (b.cy - a.cy).abs();
      if (d < minMm) continue;
      out.add(Cota(n: ++n, tipo: TipoCota.distancia, valor: d, x1: a.cx, y1: a.cy, x2: b.cx, y2: b.cy,
        ex: (a.cx + b.cx) / 2, ey: (a.cy + b.cy) / 2));
    }
  }
  final usadosFila = <Cota>{}, usadosCol = <Cota>{};
  for (final c in barrenos) {
    if (!usadosFila.contains(c)) {
      final fila = barrenos.where((o) => (o.cy - c.cy).abs() < 0.5).toList();
      usadosFila.addAll(fila);
      if (fila.length > 1) entre(fila, true);
    }
    if (!usadosCol.contains(c)) {
      final col = barrenos.where((o) => (o.cx - c.cx).abs() < 0.5).toList();
      usadosCol.addAll(col);
      if (col.length > 1) entre(col, false);
    }
  }
  return out;
}

/// Resumen para mostrar: "24 cotas · 12 líneas · 4 arcos · 8 barrenos"
String resumenCotas(List<Cota> cs) {
  final l = cs.where((c) => c.tipo == TipoCota.linea).length;
  final a = cs.where((c) => c.tipo == TipoCota.arco).length;
  final d = cs.where((c) => c.tipo == TipoCota.diametro).length;
  final e = cs.where((c) => c.tipo == TipoCota.distancia).length;
  return [
    '${cs.length} cotas',
    if (l > 0) '$l ${l == 1 ? 'línea' : 'líneas'}',
    if (a > 0) '$a ${a == 1 ? 'arco' : 'arcos'}',
    if (d > 0) '$d ${d == 1 ? 'barreno' : 'barrenos'}',
    if (e > 0) '$e entre barrenos',
  ].join(' · ');
}
