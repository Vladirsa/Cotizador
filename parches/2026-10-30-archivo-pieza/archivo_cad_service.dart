// lib/services/archivo_cad_service.dart
// HETNA CNC — Lectura de archivos de la pieza (DXF, SVG, STL, OBJ) para la
// cotización profesional: medidas totales, longitud de corte, contornos,
// barrenos, área, volumen y un dibujo simplificado (trazos) que el PDF usa
// para el croquis acotado. Todo en Dart puro, sin paquetes extra: corre en
// web, Android e iOS. Los resultados son ilustrativos: sirven para cotizar,
// no sustituyen al CAM.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

class GeoCad {
  String nombre;
  String tipo; // dxf | svg | stl | obj
  String unidades; // mm | in | px | cm | m (unidades detectadas en el archivo)
  // Medidas totales en mm (caja envolvente)
  double largo, ancho, alto;
  // 2D
  double longitudCorte; // mm
  int contornos; // trazos cerrados
  int barrenos; // círculos (o contornos circulares) cerrados
  double areaPieza; // mm² del contorno exterior más grande (0 si no hay cerrado)
  // 3D
  int triangulos;
  double volumenCm3;
  double areaSuperficialCm2;
  // Dibujo: polilíneas en mm, origen en (0,0), Y hacia arriba
  List<List<List<double>>> trazos;
  List<String> avisos;

  GeoCad({
    required this.nombre, required this.tipo, this.unidades = 'mm',
    this.largo = 0, this.ancho = 0, this.alto = 0,
    this.longitudCorte = 0, this.contornos = 0, this.barrenos = 0, this.areaPieza = 0,
    this.triangulos = 0, this.volumenCm3 = 0, this.areaSuperficialCm2 = 0,
    List<List<List<double>>>? trazos, List<String>? avisos,
  }) : trazos = trazos ?? [], avisos = avisos ?? [];

  bool get es3D => tipo == 'stl' || tipo == 'obj';

  // Lo que se guarda en datos_pro['archivo_info'] (jsonb)
  Map<String, dynamic> toInfo() => {
    'nombre': nombre, 'tipo': tipo, 'unidades': unidades,
    'largo': _r(largo), 'ancho': _r(ancho), 'alto': _r(alto),
    'longitud_corte': _r(longitudCorte), 'contornos': contornos,
    'barrenos': barrenos, 'area_pieza': _r(areaPieza),
    'triangulos': triangulos, 'volumen_cm3': _r(volumenCm3, 2),
    'area_superficial_cm2': _r(areaSuperficialCm2, 1),
    'avisos': avisos,
  };

  static double _r(double v, [int d = 1]) {
    final f = math.pow(10, d).toDouble();
    return (v * f).round() / f;
  }

  // Trazos compactos para datos_pro['archivo_geo']: [[[x,y],...],...] con 2 decimales
  List<dynamic> geoJson() => trazos
    .map((p) => p.map((q) => [_r(q[0], 2), _r(q[1], 2)]).toList()).toList();

  static List<List<List<double>>> geoDeJson(dynamic g) {
    final out = <List<List<double>>>[];
    if (g is! List) return out;
    for (final p in g) {
      if (p is! List) continue;
      final pts = <List<double>>[];
      for (final q in p) {
        if (q is List && q.length >= 2) {
          pts.add([(q[0] as num).toDouble(), (q[1] as num).toDouble()]);
        }
      }
      if (pts.length >= 2) out.add(pts);
    }
    return out;
  }
}

class ArchivoCadService {
  static const extensiones = ['dxf', 'svg', 'stl', 'obj'];
  static const int maxBytes = 40 * 1024 * 1024;
  static const int maxPuntosDibujo = 4000;

  static GeoCad leer(String nombre, Uint8List bytes) {
    final ext = nombre.contains('.') ? nombre.split('.').last.toLowerCase() : '';
    if (bytes.length > maxBytes) throw Exception('El archivo pesa más de 40 MB');
    switch (ext) {
      case 'dxf': return _leerDxf(nombre, _texto(bytes));
      case 'svg': return _leerSvg(nombre, _texto(bytes));
      case 'stl': return _leerStl(nombre, bytes);
      case 'obj': return _leerObj(nombre, _texto(bytes));
      default: throw Exception('Formato no soportado: .$ext (usa DXF, SVG, STL u OBJ)');
    }
  }

  static String _texto(Uint8List b) {
    try { return utf8.decode(b, allowMalformed: true); } catch (_) { return latin1.decode(b); }
  }

  // ──────────────────────────────────────────────
  // Utilidades 2D
  // ──────────────────────────────────────────────
  static double _len(List<List<double>> p) {
    double s = 0;
    for (int i = 1; i < p.length; i++) {
      s += math.sqrt(math.pow(p[i][0] - p[i - 1][0], 2) + math.pow(p[i][1] - p[i - 1][1], 2));
    }
    return s;
  }

  static bool _cerrado(List<List<double>> p) {
    if (p.length < 3) return false;
    final a = p.first, b = p.last;
    return math.sqrt(math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2)) < 0.05;
  }

  static double _areaPoligono(List<List<double>> p) {
    double a = 0;
    for (int i = 0; i < p.length - 1; i++) a += p[i][0] * p[i + 1][1] - p[i + 1][0] * p[i][1];
    return a.abs() / 2;
  }

  // ¿Es un círculo? (todos los puntos a la misma distancia del centro)
  static bool _esCirculo(List<List<double>> p) {
    if (!_cerrado(p) || p.length < 8) return false;
    double cx = 0, cy = 0;
    for (final q in p) { cx += q[0]; cy += q[1]; }
    cx /= p.length; cy /= p.length;
    double rmin = double.infinity, rmax = 0;
    for (final q in p) {
      final r = math.sqrt(math.pow(q[0] - cx, 2) + math.pow(q[1] - cy, 2));
      if (r < rmin) rmin = r;
      if (r > rmax) rmax = r;
    }
    return rmax > 0 && (rmax - rmin) / rmax < 0.06;
  }

  static List<List<double>> _arco(double cx, double cy, double r, double a0, double a1, {bool horario = false}) {
    // ángulos en radianes; DXF/SVG: antihorario de a0 a a1 (si horario, al revés)
    double sweep = horario ? a0 - a1 : a1 - a0;
    while (sweep <= 0) sweep += 2 * math.pi;
    final n = math.max(8, (sweep / (2 * math.pi) * 48).ceil());
    final pts = <List<double>>[];
    for (int i = 0; i <= n; i++) {
      final a = horario ? a0 - sweep * i / n : a0 + sweep * i / n;
      pts.add([cx + r * math.cos(a), cy + r * math.sin(a)]);
    }
    return pts;
  }

  // Termina: normaliza (origen 0,0 y Y arriba), mide y decima los trazos
  static void _terminar2D(GeoCad g, List<List<List<double>>> trazos, double escala, {bool yAbajo = false}) {
    if (trazos.isEmpty) throw Exception('No se encontraron líneas en el archivo');
    double minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final p in trazos) {
      for (final q in p) {
        q[0] *= escala; q[1] *= escala;
        if (q[0] < minX) minX = q[0]; if (q[0] > maxX) maxX = q[0];
        if (q[1] < minY) minY = q[1]; if (q[1] > maxY) maxY = q[1];
      }
    }
    for (final p in trazos) {
      for (final q in p) {
        q[0] -= minX;
        q[1] = yAbajo ? (maxY - q[1]) : (q[1] - minY);
      }
    }
    g.largo = maxX - minX;
    g.ancho = maxY - minY;
    double lon = 0, areaMax = 0;
    int cerrados = 0, circ = 0;
    for (final p in trazos) {
      lon += _len(p);
      if (_cerrado(p)) {
        cerrados++;
        if (_esCirculo(p)) circ++;
        final a = _areaPoligono(p);
        if (a > areaMax) areaMax = a;
      }
    }
    g.longitudCorte = lon;
    g.contornos = cerrados;
    g.barrenos = circ;
    g.areaPieza = areaMax;
    if (cerrados > 0 && circ == cerrados && cerrados > 1) {
      // todo círculos: el "exterior" también es círculo, no lo contemos como barreno
      g.barrenos = cerrados - 1;
    } else if (cerrados > 1 && circ > 0) {
      // si el contorno más grande es un círculo, tampoco es barreno
      for (final p in trazos) {
        if (_cerrado(p) && _esCirculo(p) && _areaPoligono(p) == areaMax) { g.barrenos = circ - 1; break; }
      }
    }
    g.trazos = _decimar(trazos);
    if (g.largo <= 0 || g.ancho <= 0) throw Exception('El dibujo no tiene medidas (todo en un punto)');
  }

  static List<List<List<double>>> _decimar(List<List<List<double>>> trazos) {
    int total = 0;
    for (final p in trazos) total += p.length;
    if (total <= maxPuntosDibujo) return trazos;
    final k = (total / maxPuntosDibujo).ceil();
    final out = <List<List<double>>>[];
    for (final p in trazos) {
      if (p.length <= 3) { out.add(p); continue; }
      final q = <List<double>>[];
      for (int i = 0; i < p.length; i += k) q.add(p[i]);
      if (q.last != p.last) q.add(p.last);
      out.add(q);
    }
    return out;
  }

  // ──────────────────────────────────────────────
  // DXF (ASCII, sección ENTITIES)
  // ──────────────────────────────────────────────
  static GeoCad _leerDxf(String nombre, String txt) {
    final g = GeoCad(nombre: nombre, tipo: 'dxf');
    final lines = txt.split(RegExp(r'\r\n|\r|\n'));
    // pares (código, valor)
    final codes = <int>[];
    final vals = <String>[];
    for (int i = 0; i + 1 < lines.length; i += 2) {
      final c = int.tryParse(lines[i].trim());
      if (c == null) continue;
      codes.add(c); vals.add(lines[i + 1].trim());
    }
    double escala = 1;
    g.unidades = 'mm';
    bool enEntities = false, enHeader = false;
    final trazos = <List<List<double>>>[];
    int insertsIgnorados = 0;
    int i = 0;
    double n(String s) => double.tryParse(s) ?? 0;
    while (i < codes.length) {
      final c = codes[i], v = vals[i];
      if (c == 2 && i > 0 && codes[i - 1] == 0 && vals[i - 1] == 'SECTION') {
        enHeader = v == 'HEADER'; enEntities = v == 'ENTITIES';
        i++; continue;
      }
      if (c == 0 && v == 'ENDSEC') { enHeader = false; enEntities = false; i++; continue; }
      if (enHeader && c == 9 && v == r'$INSUNITS') {
        if (i + 1 < codes.length && codes[i + 1] == 70) {
          switch (int.tryParse(vals[i + 1]) ?? 0) {
            case 1: escala = 25.4; g.unidades = 'in'; break;
            case 2: escala = 304.8; g.unidades = 'ft'; break;
            case 5: escala = 10; g.unidades = 'cm'; break;
            case 6: escala = 1000; g.unidades = 'm'; break;
            default: escala = 1; g.unidades = 'mm';
          }
        }
        i++; continue;
      }
      if (!enEntities || c != 0) { i++; continue; }
      // entidad: leer sus grupos hasta el siguiente código 0
      final tipo = v;
      int j = i + 1;
      final grupos = <(int, String)>[];
      while (j < codes.length && codes[j] != 0) { grupos.add((codes[j], vals[j])); j++; }
      String? gv(int code) { for (final gr in grupos) { if (gr.$1 == code) return gr.$2; } return null; }
      switch (tipo) {
        case 'LINE': {
          trazos.add([[n(gv(10) ?? '0'), n(gv(20) ?? '0')], [n(gv(11) ?? '0'), n(gv(21) ?? '0')]]);
          break;
        }
        case 'CIRCLE': {
          trazos.add(_arco(n(gv(10) ?? '0'), n(gv(20) ?? '0'), n(gv(40) ?? '0'), 0, 2 * math.pi));
          break;
        }
        case 'ARC': {
          final a0 = n(gv(50) ?? '0') * math.pi / 180, a1 = n(gv(51) ?? '360') * math.pi / 180;
          trazos.add(_arco(n(gv(10) ?? '0'), n(gv(20) ?? '0'), n(gv(40) ?? '0'), a0, a1));
          break;
        }
        case 'ELLIPSE': {
          final cx = n(gv(10) ?? '0'), cy = n(gv(20) ?? '0');
          final mx = n(gv(11) ?? '1'), my = n(gv(21) ?? '0');
          final ratio = n(gv(40) ?? '1');
          final t0 = n(gv(41) ?? '0'), t1 = n(gv(42) ?? '6.283185');
          final a = math.sqrt(mx * mx + my * my), b = a * ratio, rot = math.atan2(my, mx);
          double sweep = t1 - t0; while (sweep <= 0) sweep += 2 * math.pi;
          final k = math.max(12, (sweep / (2 * math.pi) * 64).ceil());
          final pts = <List<double>>[];
          for (int s = 0; s <= k; s++) {
            final t = t0 + sweep * s / k;
            final x = a * math.cos(t), y = b * math.sin(t);
            pts.add([cx + x * math.cos(rot) - y * math.sin(rot), cy + x * math.sin(rot) + y * math.cos(rot)]);
          }
          trazos.add(pts);
          break;
        }
        case 'LWPOLYLINE': {
          final pts = <List<double>>[];
          final bulges = <double>[];
          double? x;
          for (final gr in grupos) {
            if (gr.$1 == 10) x = n(gr.$2);
            else if (gr.$1 == 20 && x != null) { pts.add([x, n(gr.$2)]); bulges.add(0); x = null; }
            else if (gr.$1 == 42 && bulges.isNotEmpty) bulges[bulges.length - 1] = n(gr.$2);
          }
          final cerrado = ((int.tryParse(gv(70) ?? '0') ?? 0) & 1) == 1;
          trazos.add(_polilineaConBulges(pts, bulges, cerrado));
          break;
        }
        case 'POLYLINE': {
          final cerrado = ((int.tryParse(gv(70) ?? '0') ?? 0) & 1) == 1;
          final pts = <List<double>>[];
          final bulges = <double>[];
          // vértices hasta SEQEND
          int k2 = j;
          while (k2 < codes.length) {
            if (codes[k2] == 0) {
              if (vals[k2] == 'SEQEND') { k2++; break; }
              if (vals[k2] == 'VERTEX') {
                double? vx, vy; double bu = 0;
                int m = k2 + 1;
                while (m < codes.length && codes[m] != 0) {
                  if (codes[m] == 10) vx = n(vals[m]);
                  if (codes[m] == 20) vy = n(vals[m]);
                  if (codes[m] == 42) bu = n(vals[m]);
                  m++;
                }
                if (vx != null && vy != null) { pts.add([vx, vy]); bulges.add(bu); }
                k2 = m; continue;
              }
            }
            k2++;
          }
          j = k2;
          if (pts.length >= 2) trazos.add(_polilineaConBulges(pts, bulges, cerrado));
          break;
        }
        case 'SPLINE': {
          // puntos de ajuste (11/21) si hay; si no, puntos de control (10/20)
          final fit = <List<double>>[]; final ctl = <List<double>>[];
          double? fx, cx2;
          for (final gr in grupos) {
            if (gr.$1 == 11) fx = n(gr.$2);
            else if (gr.$1 == 21 && fx != null) { fit.add([fx, n(gr.$2)]); fx = null; }
            else if (gr.$1 == 10) cx2 = n(gr.$2);
            else if (gr.$1 == 20 && cx2 != null) { ctl.add([cx2, n(gr.$2)]); cx2 = null; }
          }
          final src = fit.length >= 2 ? fit : ctl;
          if (src.length >= 2) {
            final cerrado = ((int.tryParse(gv(70) ?? '0') ?? 0) & 1) == 1;
            final pts = _suavizar(src, cerrado);
            trazos.add(pts);
          }
          break;
        }
        case 'INSERT': {
          insertsIgnorados++;
          break;
        }
        default:
          break;
      }
      i = j;
    }
    if (insertsIgnorados > 0) g.avisos.add('El DXF tiene $insertsIgnorados bloque(s) insertados que no se dibujan; explótalos (EXPLODE) en tu CAD para que cuenten en el corte.');
    if (escala != 1) g.avisos.add('Unidades del DXF: ${g.unidades}; se convirtieron a mm.');
    _terminar2D(g, trazos, escala);
    return g;
  }

  // Curva suave (Catmull-Rom) por los puntos dados
  static List<List<double>> _suavizar(List<List<double>> p, bool cerrado) {
    if (p.length < 3) return List.of(p);
    final pts = <List<double>>[];
    final src = cerrado ? [...p, p.first] : p;
    for (int i = 0; i < src.length - 1; i++) {
      final p0 = src[i == 0 ? (cerrado ? src.length - 2 : 0) : i - 1];
      final p1 = src[i], p2 = src[i + 1];
      final p3 = src[i + 2 < src.length ? i + 2 : (cerrado ? 1 : src.length - 1)];
      for (int s = 0; s < 6; s++) {
        final t = s / 6;
        final t2 = t * t, t3 = t2 * t;
        final x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3);
        final y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3);
        pts.add([x, y]);
      }
    }
    pts.add(List.of(src.last));
    return pts;
  }

  // Polilínea DXF con "bulges" (arcos entre vértices)
  static List<List<double>> _polilineaConBulges(List<List<double>> pts, List<double> bulges, bool cerrado) {
    if (pts.length < 2) return pts;
    final out = <List<double>>[];
    final n = pts.length;
    final segs = cerrado ? n : n - 1;
    for (int i = 0; i < segs; i++) {
      final a = pts[i], b = pts[(i + 1) % n];
      final bu = i < bulges.length ? bulges[i] : 0.0;
      if (out.isEmpty) out.add([a[0], a[1]]);
      if (bu.abs() < 1e-9) { out.add([b[0], b[1]]); continue; }
      // arco por bulge: ángulo = 4·atan(bulge)
      final theta = 4 * math.atan(bu);
      final dx = b[0] - a[0], dy = b[1] - a[1];
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < 1e-9) continue;
      final r = d / (2 * math.sin(theta.abs() / 2));
      final mx = (a[0] + b[0]) / 2, my = (a[1] + b[1]) / 2;
      final h = math.sqrt(math.max(0, r * r - d * d / 4));
      final sgn = bu > 0 ? 1 : -1;
      final cx = mx - sgn * h * dy / d, cy = my + sgn * h * dx / d;
      final a0 = math.atan2(a[1] - cy, a[0] - cx);
      final k = math.max(4, (theta.abs() / (2 * math.pi) * 48).ceil());
      for (int s = 1; s <= k; s++) {
        final ang = a0 + theta * s / k;
        out.add([cx + r * math.cos(ang), cy + r * math.sin(ang)]);
      }
    }
    return out;
  }

  // ──────────────────────────────────────────────
  // SVG (path, rect, circle, ellipse, line, polyline, polygon)
  // ──────────────────────────────────────────────
  static GeoCad _leerSvg(String nombre, String txt) {
    final g = GeoCad(nombre: nombre, tipo: 'svg');
    // unidades: width/height con unidad y viewBox
    double escala = 25.4 / 96; // px → mm por defecto
    g.unidades = 'px';
    final svgTag = RegExp(r'<svg\b[^>]*>', caseSensitive: false).firstMatch(txt)?.group(0) ?? '';
    String? attr(String tag, String name) =>
      RegExp('\\b$name\\s*=\\s*"([^"]*)"', caseSensitive: false).firstMatch(tag)?.group(1)
      ?? RegExp("\\b$name\\s*=\\s*'([^']*)'", caseSensitive: false).firstMatch(tag)?.group(1);
    final w = attr(svgTag, 'width');
    final vb = attr(svgTag, 'viewBox');
    if (w != null) {
      final m = RegExp(r'([\d.]+)\s*(mm|cm|in|pt|px)?').firstMatch(w);
      if (m != null) {
        final val = double.tryParse(m.group(1)!) ?? 0;
        final u = (m.group(2) ?? 'px').toLowerCase();
        double mmAncho;
        switch (u) {
          case 'mm': mmAncho = val; g.unidades = 'mm'; break;
          case 'cm': mmAncho = val * 10; g.unidades = 'cm'; break;
          case 'in': mmAncho = val * 25.4; g.unidades = 'in'; break;
          case 'pt': mmAncho = val * 25.4 / 72; g.unidades = 'pt'; break;
          default: mmAncho = val * 25.4 / 96; g.unidades = 'px';
        }
        if (vb != null) {
          final parts = vb.trim().split(RegExp(r'[\s,]+')).map((s) => double.tryParse(s) ?? 0).toList();
          if (parts.length == 4 && parts[2] > 0) escala = mmAncho / parts[2];
        } else if (val > 0) {
          escala = mmAncho / val;
        }
      }
    }
    final trazos = <List<List<double>>>[];
    double n(String? s) => double.tryParse(s ?? '') ?? 0;
    int transformadas = 0;
    for (final m in RegExp(r'<(path|rect|circle|ellipse|line|polyline|polygon)\b[^>]*>', caseSensitive: false).allMatches(txt)) {
      final tag = m.group(0)!;
      final el = m.group(1)!.toLowerCase();
      if (attr(tag, 'transform') != null) transformadas++;
      switch (el) {
        case 'rect': {
          final x = n(attr(tag, 'x')), y = n(attr(tag, 'y')), rw = n(attr(tag, 'width')), rh = n(attr(tag, 'height'));
          if (rw > 0 && rh > 0) trazos.add([[x, y], [x + rw, y], [x + rw, y + rh], [x, y + rh], [x, y]]);
          break;
        }
        case 'circle': {
          trazos.add(_arco(n(attr(tag, 'cx')), n(attr(tag, 'cy')), n(attr(tag, 'r')), 0, 2 * math.pi));
          break;
        }
        case 'ellipse': {
          final cx = n(attr(tag, 'cx')), cy = n(attr(tag, 'cy')), rx = n(attr(tag, 'rx')), ry = n(attr(tag, 'ry'));
          final pts = <List<double>>[];
          for (int s = 0; s <= 48; s++) { final t = 2 * math.pi * s / 48; pts.add([cx + rx * math.cos(t), cy + ry * math.sin(t)]); }
          trazos.add(pts);
          break;
        }
        case 'line': {
          trazos.add([[n(attr(tag, 'x1')), n(attr(tag, 'y1'))], [n(attr(tag, 'x2')), n(attr(tag, 'y2'))]]);
          break;
        }
        case 'polyline':
        case 'polygon': {
          final nums = RegExp(r'-?[\d.]+(?:e-?\d+)?', caseSensitive: false).allMatches(attr(tag, 'points') ?? '').map((x) => double.tryParse(x.group(0)!) ?? 0).toList();
          final pts = <List<double>>[];
          for (int k = 0; k + 1 < nums.length; k += 2) pts.add([nums[k], nums[k + 1]]);
          if (el == 'polygon' && pts.length >= 2) pts.add(List.of(pts.first));
          if (pts.length >= 2) trazos.add(pts);
          break;
        }
        case 'path': {
          final d = attr(tag, 'd');
          if (d != null) trazos.addAll(_svgPath(d));
          break;
        }
      }
    }
    if (transformadas > 0) g.avisos.add('$transformadas elemento(s) del SVG tienen "transform" (rotación/escala) que no se aplica: las medidas pueden variar. Exporta el SVG "aplanado".');
    if (g.unidades == 'px') g.avisos.add('El SVG no trae unidades físicas: se asumieron píxeles a 96 DPI (25.4 mm = 96 px). Revisa las medidas.');
    _terminar2D(g, trazos, escala, yAbajo: true);
    return g;
  }

  // Trazos de un atributo d de <path>
  static List<List<List<double>>> _svgPath(String d) {
    final out = <List<List<double>>>[];
    final tokens = RegExp(r'[MmLlHhVvCcSsQqTtAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?', caseSensitive: false).allMatches(d).map((m) => m.group(0)!).toList();
    List<List<double>> cur = [];
    double x = 0, y = 0, sx = 0, sy = 0;
    double? cpx, cpy; // último control (para S/T)
    String cmd = '';
    int i = 0;
    double next() => i < tokens.length ? (double.tryParse(tokens[i++]) ?? 0) : 0;
    bool esNum(String t) => double.tryParse(t) != null;
    void cerrarActual() { if (cur.length >= 2) out.add(cur); cur = []; }
    void cubica(double x1, double y1, double x2, double y2, double x3, double y3) {
      for (int s = 1; s <= 10; s++) {
        final t = s / 10, u = 1 - t;
        cur.add([u*u*u*x + 3*u*u*t*x1 + 3*u*t*t*x2 + t*t*t*x3, u*u*u*y + 3*u*u*t*y1 + 3*u*t*t*y2 + t*t*t*y3]);
      }
      cpx = x2; cpy = y2; x = x3; y = y3;
    }
    void cuadratica(double x1, double y1, double x2, double y2) {
      for (int s = 1; s <= 8; s++) {
        final t = s / 8, u = 1 - t;
        cur.add([u*u*x + 2*u*t*x1 + t*t*x2, u*u*y + 2*u*t*y1 + t*t*y2]);
      }
      cpx = x1; cpy = y1; x = x2; y = y2;
    }
    void arco(double rx, double ry, double rot, bool large, bool sweep, double x2, double y2) {
      // conversión de parámetros de arco SVG a centro (W3C apéndice)
      if (rx == 0 || ry == 0) { cur.add([x2, y2]); x = x2; y = y2; return; }
      rx = rx.abs(); ry = ry.abs();
      final phi = rot * math.pi / 180;
      final cosP = math.cos(phi), sinP = math.sin(phi);
      final dx = (x - x2) / 2, dy = (y - y2) / 2;
      final x1p = cosP * dx + sinP * dy, y1p = -sinP * dx + cosP * dy;
      final lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
      if (lam > 1) { rx *= math.sqrt(lam); ry *= math.sqrt(lam); }
      final numer = rx*rx*ry*ry - rx*rx*y1p*y1p - ry*ry*x1p*x1p;
      final den = rx*rx*y1p*y1p + ry*ry*x1p*x1p;
      double coef = den == 0 ? 0 : math.sqrt(math.max(0, numer / den));
      if (large == sweep) coef = -coef;
      final cxp = coef * rx * y1p / ry, cyp = -coef * ry * x1p / rx;
      final cx = cosP * cxp - sinP * cyp + (x + x2) / 2, cy = sinP * cxp + cosP * cyp + (y + y2) / 2;
      double ang(double ux, double uy, double vx, double vy) {
        final dot = ux * vx + uy * vy, l = math.sqrt((ux*ux + uy*uy) * (vx*vx + vy*vy));
        double a = math.acos((dot / l).clamp(-1.0, 1.0));
        if (ux * vy - uy * vx < 0) a = -a;
        return a;
      }
      final t0 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
      double dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry);
      if (!sweep && dt > 0) dt -= 2 * math.pi;
      if (sweep && dt < 0) dt += 2 * math.pi;
      final k = math.max(6, (dt.abs() / (2 * math.pi) * 48).ceil());
      for (int s = 1; s <= k; s++) {
        final t = t0 + dt * s / k;
        final ex = rx * math.cos(t), ey = ry * math.sin(t);
        cur.add([cosP * ex - sinP * ey + cx, sinP * ex + cosP * ey + cy]);
      }
      x = x2; y = y2; cpx = null; cpy = null;
    }
    while (i < tokens.length) {
      final t = tokens[i];
      if (!esNum(t)) { cmd = t; i++; if (cmd == 'Z' || cmd == 'z') { if (cur.isNotEmpty) { cur.add([sx, sy]); } cerrarActual(); x = sx; y = sy; cur = [[x, y]]; } continue; }
      final rel = cmd == cmd.toLowerCase();
      switch (cmd.toUpperCase()) {
        case 'M': {
          cerrarActual();
          final nx = next(), ny = next();
          x = rel ? x + nx : nx; y = rel ? y + ny : ny;
          sx = x; sy = y; cur = [[x, y]];
          cmd = rel ? 'l' : 'L';
          break;
        }
        case 'L': {
          final nx = next(), ny = next();
          x = rel ? x + nx : nx; y = rel ? y + ny : ny; cur.add([x, y]); cpx = null; break;
        }
        case 'H': {
          final nx = next(); x = rel ? x + nx : nx; cur.add([x, y]); cpx = null; break;
        }
        case 'V': {
          final ny = next(); y = rel ? y + ny : ny; cur.add([x, y]); cpx = null; break;
        }
        case 'C': {
          final a1 = next(), b1 = next(), a2 = next(), b2 = next(), a3 = next(), b3 = next();
          if (rel) cubica(x + a1, y + b1, x + a2, y + b2, x + a3, y + b3); else cubica(a1, b1, a2, b2, a3, b3);
          break;
        }
        case 'S': {
          final a2 = next(), b2 = next(), a3 = next(), b3 = next();
          final x1 = cpx != null ? 2 * x - cpx! : x, y1 = cpy != null ? 2 * y - cpy! : y;
          if (rel) cubica(x1, y1, x + a2, y + b2, x + a3, y + b3); else cubica(x1, y1, a2, b2, a3, b3);
          break;
        }
        case 'Q': {
          final a1 = next(), b1 = next(), a2 = next(), b2 = next();
          if (rel) cuadratica(x + a1, y + b1, x + a2, y + b2); else cuadratica(a1, b1, a2, b2);
          break;
        }
        case 'T': {
          final a2 = next(), b2 = next();
          final x1 = cpx != null ? 2 * x - cpx! : x, y1 = cpy != null ? 2 * y - cpy! : y;
          if (rel) cuadratica(x1, y1, x + a2, y + b2); else cuadratica(x1, y1, a2, b2);
          break;
        }
        case 'A': {
          final rx = next(), ry = next(), rot = next(), large = next() != 0, sweep = next() != 0, ex = next(), ey = next();
          arco(rx, ry, rot, large, sweep, rel ? x + ex : ex, rel ? y + ey : ey);
          break;
        }
        default:
          i++; // token suelto
      }
    }
    cerrarActual();
    return out;
  }

  // ──────────────────────────────────────────────
  // STL (binario o ASCII) y OBJ
  // ──────────────────────────────────────────────
  static GeoCad _leerStl(String nombre, Uint8List bytes) {
    final g = GeoCad(nombre: nombre, tipo: 'stl');
    final tris = <List<double>>[]; // cada uno: 9 números
    final head = bytes.length >= 5 ? ascii.decode(bytes.sublist(0, 5), allowInvalid: true) : '';
    bool binario = true;
    if (head.toLowerCase() == 'solid' && bytes.length >= 84) {
      final n = ByteData.sublistView(bytes, 80, 84).getUint32(0, Endian.little);
      binario = bytes.length == 84 + n * 50;
    } else if (head.toLowerCase() == 'solid') {
      binario = false;
    }
    if (binario) {
      if (bytes.length < 84) throw Exception('STL vacío');
      final bd = ByteData.sublistView(bytes);
      final n = bd.getUint32(80, Endian.little);
      int off = 84;
      for (int t = 0; t < n && off + 50 <= bytes.length; t++) {
        final tri = <double>[];
        for (int v = 0; v < 3; v++) {
          final o = off + 12 + v * 12;
          tri.add(bd.getFloat32(o, Endian.little));
          tri.add(bd.getFloat32(o + 4, Endian.little));
          tri.add(bd.getFloat32(o + 8, Endian.little));
        }
        tris.add(tri);
        off += 50;
      }
    } else {
      final txt = _texto(bytes);
      final re = RegExp(r'vertex\s+(-?[\d.eE+-]+)\s+(-?[\d.eE+-]+)\s+(-?[\d.eE+-]+)');
      final vs = <double>[];
      for (final m in re.allMatches(txt)) {
        vs.add(double.tryParse(m.group(1)!) ?? 0);
        vs.add(double.tryParse(m.group(2)!) ?? 0);
        vs.add(double.tryParse(m.group(3)!) ?? 0);
        if (vs.length == 9) { tris.add(List.of(vs)); vs.clear(); }
      }
    }
    _terminar3D(g, tris);
    return g;
  }

  static GeoCad _leerObj(String nombre, String txt) {
    final g = GeoCad(nombre: nombre, tipo: 'obj');
    final verts = <List<double>>[];
    final tris = <List<double>>[];
    for (final raw in txt.split(RegExp(r'\r\n|\r|\n'))) {
      final line = raw.trim();
      if (line.startsWith('v ')) {
        final p = line.substring(2).trim().split(RegExp(r'\s+'));
        if (p.length >= 3) verts.add([double.tryParse(p[0]) ?? 0, double.tryParse(p[1]) ?? 0, double.tryParse(p[2]) ?? 0]);
      } else if (line.startsWith('f ')) {
        final idx = <int>[];
        for (final tok in line.substring(2).trim().split(RegExp(r'\s+'))) {
          final s = tok.split('/').first;
          var k = int.tryParse(s) ?? 0;
          if (k < 0) k = verts.length + 1 + k;
          if (k >= 1 && k <= verts.length) idx.add(k - 1);
        }
        for (int t = 1; t + 1 < idx.length; t++) {
          tris.add([...verts[idx[0]], ...verts[idx[t]], ...verts[idx[t + 1]]]);
        }
      }
    }
    _terminar3D(g, tris);
    return g;
  }

  static void _terminar3D(GeoCad g, List<List<double>> tris) {
    if (tris.isEmpty) throw Exception('El archivo no tiene triángulos');
    double minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;
    double area = 0, vol = 0;
    for (final t in tris) {
      for (int v = 0; v < 3; v++) {
        final x = t[v * 3], y = t[v * 3 + 1], z = t[v * 3 + 2];
        if (x < minX) minX = x; if (x > maxX) maxX = x;
        if (y < minY) minY = y; if (y > maxY) maxY = y;
        if (z < minZ) minZ = z; if (z > maxZ) maxZ = z;
      }
      final ax = t[3] - t[0], ay = t[4] - t[1], az = t[5] - t[2];
      final bx = t[6] - t[0], by = t[7] - t[1], bz = t[8] - t[2];
      final cx = ay * bz - az * by, cy = az * bx - ax * bz, cz = ax * by - ay * bx;
      area += 0.5 * math.sqrt(cx * cx + cy * cy + cz * cz);
      vol += (t[0] * (t[4] * t[8] - t[5] * t[7]) - t[1] * (t[3] * t[8] - t[5] * t[6]) + t[2] * (t[3] * t[7] - t[4] * t[6])) / 6;
    }
    g.largo = maxX - minX; g.ancho = maxY - minY; g.alto = maxZ - minZ;
    g.triangulos = tris.length;
    g.areaSuperficialCm2 = area / 100;
    g.volumenCm3 = vol.abs() / 1000;
    g.unidades = 'mm';
    if (g.largo < 5 && g.ancho < 5 && g.alto < 5) {
      g.avisos.add('El modelo mide menos de 5 mm: puede estar en pulgadas o centímetros. Revisa las unidades de exportación.');
    }
    if (g.largo <= 0 || g.ancho <= 0) throw Exception('El modelo no tiene medidas');
    // Dibujo: vista superior (XY) con una muestra de aristas
    final maxTris = 1200;
    final paso = tris.length <= maxTris ? 1 : (tris.length / maxTris).ceil();
    final trazos = <List<List<double>>>[];
    for (int i = 0; i < tris.length; i += paso) {
      final t = tris[i];
      trazos.add([[t[0] - minX, t[1] - minY], [t[3] - minX, t[4] - minY], [t[6] - minX, t[7] - minY], [t[0] - minX, t[1] - minY]]);
    }
    g.trazos = trazos;
  }
}
