// lib/simulador2/visor_pieza.dart
// HETNA CNC — Visor de la pieza dentro del simulador.
//
//   VisorPieza   2D: los trazos del DXF/SVG con cuadrícula y cotas.
//                3D: la malla del STL/OBJ girando con el dedo (sombreado
//                plano, sin paquetes: se dibuja con Canvas.drawVertices).
//   VisorHoja    cómo quedan acomodadas las piezas en la hoja y qué retazo sobra.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/archivo_cad_service.dart';
import 'motor.dart';

class VisorPieza extends StatefulWidget {
  final GeoCad geo;
  final double alto;
  final bool oscuro;
  const VisorPieza({super.key, required this.geo, this.alto = 220, this.oscuro = true});
  @override
  State<VisorPieza> createState() => _VisorPiezaState();
}

class _VisorPiezaState extends State<VisorPieza> {
  double _rx = -1.0, _rz = 0.6; // radianes
  double _zoom = 1;
  double _zoomBase = 1;

  @override
  Widget build(BuildContext context) {
    final g = widget.geo;
    final fondo = widget.oscuro ? const Color(0xFF0f172a) : Colors.white;
    final es3D = g.es3D && g.malla != null && g.malla!.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: widget.alto, width: double.infinity, color: fondo,
        child: Stack(children: [
          Positioned.fill(child: es3D
            ? GestureDetector(
                onScaleStart: (_) => _zoomBase = _zoom,
                onScaleUpdate: (d) => setState(() {
                  _zoom = (_zoomBase * d.scale).clamp(0.3, 6);
                  if (d.pointerCount == 1) { _rz += d.focalPointDelta.dx * 0.01; _rx += d.focalPointDelta.dy * 0.01; }
                }),
                child: CustomPaint(painter: _Malla3DPainter(g.malla!, _rx, _rz, _zoom, widget.oscuro, g.largo, g.ancho, g.alto)))
            : CustomPaint(painter: _Trazos2DPainter(g, widget.oscuro))),
          Positioned(left: 10, bottom: 8, child: Text(
            es3D
              ? '${g.largo.toStringAsFixed(0)} × ${g.ancho.toStringAsFixed(0)} × ${g.alto.toStringAsFixed(0)} mm · ${g.volumenCm3.toStringAsFixed(1)} cm³'
              : '${g.largo.toStringAsFixed(0)} × ${g.ancho.toStringAsFixed(0)} mm · ${(g.longitudCorte / 1000).toStringAsFixed(2)} m de corte · ${g.contornos} contornos · ${g.barrenos} barrenos',
            style: TextStyle(fontSize: 10.5, color: widget.oscuro ? Colors.white70 : AppColors.textoSecundario, fontWeight: FontWeight.w600))),
          if (es3D) Positioned(right: 10, top: 8, child: Row(children: [
            _btn(Icons.refresh, () => setState(() { _rx = -1.0; _rz = 0.6; _zoom = 1; })),
          ])),
          if (es3D) Positioned(right: 10, bottom: 8, child: Text('arrastra para girar · pellizca para acercar',
            style: TextStyle(fontSize: 9.5, color: widget.oscuro ? Colors.white38 : AppColors.textoSecundario))),
        ])));
  }

  Widget _btn(IconData i, VoidCallback f) => InkWell(onTap: f, child: Container(
    padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
    child: Icon(i, size: 16, color: widget.oscuro ? Colors.white70 : AppColors.azul)));
}

/// Dibuja la pieza en un PNG (para la cotización en PDF): 2D con trazos y
/// cotas, 3D con la malla sombreada en vista isométrica. Fondo blanco.
Future<Uint8List?> renderPiezaPng(GeoCad g, {int ancho = 720, int alto = 440}) async {
  try {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final size = Size(ancho.toDouble(), alto.toDouble());
    c.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final es3D = g.es3D && g.malla != null && g.malla!.isNotEmpty;
    if (es3D) {
      _Malla3DPainter(g.malla!, -1.0, 0.6, 1, false, g.largo, g.ancho, g.alto).paint(c, size);
    } else {
      _Trazos2DPainter(g, false).paint(c, size);
    }
    final img = await rec.endRecording().toImage(ancho, alto);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  } catch (_) { return null; }
}

// ── 2D ────────────────────────────────────────────────────────────────
class _Trazos2DPainter extends CustomPainter {
  final GeoCad g; final bool oscuro;
  _Trazos2DPainter(this.g, this.oscuro);

  @override
  void paint(Canvas c, Size s) {
    if (g.trazos.isEmpty || g.largo <= 0 || g.ancho <= 0) {
      final tp = TextPainter(text: TextSpan(text: 'Sin dibujo', style: TextStyle(color: oscuro ? Colors.white38 : Colors.black38, fontSize: 12)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset((s.width - tp.width) / 2, (s.height - tp.height) / 2));
      return;
    }
    double minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final p in g.trazos) { for (final q in p) {
      if (q[0] < minX) minX = q[0]; if (q[0] > maxX) maxX = q[0];
      if (q[1] < minY) minY = q[1]; if (q[1] > maxY) maxY = q[1];
    } }
    if (!minX.isFinite) return;
    const pad = 28.0;
    final w = maxX - minX, h = maxY - minY;
    final esc = math.min((s.width - pad * 2) / (w > 0 ? w : 1), (s.height - pad * 2) / (h > 0 ? h : 1));
    final ox = (s.width - w * esc) / 2, oy = (s.height - h * esc) / 2;
    Offset pt(List<double> q) => Offset(ox + (q[0] - minX) * esc, s.height - oy - (q[1] - minY) * esc);

    // Cuadrícula de 10 mm (o 50/100 si la pieza es grande)
    final paso = w > 1500 ? 100.0 : w > 400 ? 50.0 : 10.0;
    final grid = Paint()..color = (oscuro ? Colors.white : Colors.black).withOpacity(0.07)..strokeWidth = 0.6;
    for (double x = 0; x <= w + 0.01; x += paso) { final px = ox + x * esc; c.drawLine(Offset(px, oy), Offset(px, s.height - oy), grid); }
    for (double y = 0; y <= h + 0.01; y += paso) { final py = s.height - oy - y * esc; c.drawLine(Offset(ox, py), Offset(s.width - ox, py), grid); }

    // Trazos
    final pen = Paint()..color = oscuro ? const Color(0xFF7dd3fc) : AppColors.azul..strokeWidth = 1.3..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round;
    for (final p in g.trazos) {
      if (p.length < 2) continue;
      final path = Path()..moveTo(pt(p[0]).dx, pt(p[0]).dy);
      for (int i = 1; i < p.length; i++) { final o = pt(p[i]); path.lineTo(o.dx, o.dy); }
      c.drawPath(path, pen);
    }

    // Cotas
    final cota = Paint()..color = (oscuro ? Colors.white54 : AppColors.textoSecundario)..strokeWidth = 0.8;
    final y0 = s.height - oy + 12, x0 = ox - 12;
    c.drawLine(Offset(ox, y0), Offset(s.width - ox, y0), cota);
    c.drawLine(Offset(x0, oy), Offset(x0, s.height - oy), cota);
    _texto(c, '${w.toStringAsFixed(w < 10 ? 1 : 0)} mm', Offset(s.width / 2, y0 + 2), oscuro, centrado: true);
    c.save(); c.translate(x0 - 4, s.height / 2); c.rotate(-math.pi / 2);
    _texto(c, '${h.toStringAsFixed(h < 10 ? 1 : 0)} mm', const Offset(0, -12), oscuro, centrado: true);
    c.restore();
  }

  void _texto(Canvas c, String t, Offset o, bool oscuro, {bool centrado = false}) {
    final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(fontSize: 10, color: oscuro ? Colors.white70 : AppColors.textoSecundario, fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, centrado ? Offset(o.dx - tp.width / 2, o.dy) : o);
  }

  @override
  bool shouldRepaint(_Trazos2DPainter old) => old.g != g || old.oscuro != oscuro;
}

// ── 3D ────────────────────────────────────────────────────────────────
class _Malla3DPainter extends CustomPainter {
  final Float32List m; final double rx, rz, zoom; final bool oscuro;
  final double largo, ancho, alto;
  _Malla3DPainter(this.m, this.rx, this.rz, this.zoom, this.oscuro, this.largo, this.ancho, this.alto);

  @override
  void paint(Canvas c, Size s) {
    final n = m.length ~/ 9;
    if (n == 0) return;
    final radio = math.sqrt(largo * largo + ancho * ancho + alto * alto) / 2;
    final esc = (math.min(s.width, s.height) * 0.42 / (radio > 0 ? radio : 1)) * zoom;
    final cx = s.width / 2, cy = s.height / 2;
    final cosZ = math.cos(rz), sinZ = math.sin(rz), cosX = math.cos(rx), sinX = math.sin(rx);
    // luz desde arriba-izquierda-frente
    const lx = -0.4, ly = -0.5, lz = 0.77;
    final base = oscuro ? const Color(0xFF60a5fa) : AppColors.azul;

    final depth = Float32List(n);
    final sx = Float32List(n * 3), sy = Float32List(n * 3);
    final sombra = Float32List(n);
    for (int t = 0; t < n; t++) {
      double zsum = 0;
      final px = List<double>.filled(3, 0), py = List<double>.filled(3, 0), pz = List<double>.filled(3, 0);
      for (int v = 0; v < 3; v++) {
        final i = t * 9 + v * 3;
        final x0 = m[i], y0 = m[i + 1], z0 = m[i + 2];
        // giro en Z, luego en X
        final x1 = x0 * cosZ - y0 * sinZ, y1 = x0 * sinZ + y0 * cosZ;
        final y2 = y1 * cosX - z0 * sinX, z2 = y1 * sinX + z0 * cosX;
        px[v] = x1; py[v] = y2; pz[v] = z2;
        sx[t * 3 + v] = cx + x1 * esc; sy[t * 3 + v] = cy - y2 * esc;
        zsum += z2;
      }
      depth[t] = zsum;
      final ax = px[1] - px[0], ay = py[1] - py[0], az = pz[1] - pz[0];
      final bx = px[2] - px[0], by = py[2] - py[0], bz = pz[2] - pz[0];
      double nx = ay * bz - az * by, ny = az * bx - ax * bz, nz = ax * by - ay * bx;
      final len = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (len > 0) { nx /= len; ny /= len; nz /= len; }
      double l = (nx * lx + ny * ly + nz * lz).abs();
      sombra[t] = 0.35 + 0.65 * l;
    }
    // Pintor: de atrás hacia adelante
    final orden = List<int>.generate(n, (i) => i)..sort((a, b) => depth[a].compareTo(depth[b]));
    final pos = Float32List(n * 6);
    final cols = Int32List(n * 3);
    int k = 0, kc = 0;
    for (final t in orden) {
      final f = sombra[t];
      final col = Color.fromARGB(255, (base.red * f).round().clamp(0, 255), (base.green * f).round().clamp(0, 255), (base.blue * f).round().clamp(0, 255)).value;
      for (int v = 0; v < 3; v++) {
        pos[k++] = sx[t * 3 + v]; pos[k++] = sy[t * 3 + v];
        cols[kc++] = col;
      }
    }
    final verts = ui.Vertices.raw(ui.VertexMode.triangles, pos, colors: cols);
    c.drawVertices(verts, BlendMode.srcOver, Paint());

    // Ejes chiquitos en la esquina
    final o = Offset(28, s.height - 28);
    void eje(double x, double y, double z, Color col, String nom) {
      final x1 = x * cosZ - y * sinZ, y1 = x * sinZ + y * cosZ;
      final y2 = y1 * cosX - z * sinX;
      final p = Offset(o.dx + x1 * 18, o.dy - y2 * 18);
      c.drawLine(o, p, Paint()..color = col..strokeWidth = 1.5);
      final tp = TextPainter(text: TextSpan(text: nom, style: TextStyle(fontSize: 9, color: col)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, p + const Offset(2, -10));
    }
    eje(1, 0, 0, Colors.redAccent, 'X'); eje(0, 1, 0, Colors.greenAccent, 'Y'); eje(0, 0, 1, Colors.lightBlueAccent, 'Z');
  }

  @override
  bool shouldRepaint(_Malla3DPainter old) => old.m != m || old.rx != rx || old.rz != rz || old.zoom != zoom || old.oscuro != oscuro;
}

// ── Hoja anidada ────────────────────────────────────────────────────
class VisorHoja extends StatelessWidget {
  final Anidado anidado;
  final double hojaLargo, hojaAncho;
  final String titulo;
  const VisorHoja({super.key, required this.anidado, required this.hojaLargo, required this.hojaAncho, this.titulo = ''});

  @override
  Widget build(BuildContext context) {
    if (!anidado.cabe || hojaLargo <= 0 || hojaAncho <= 0) return const SizedBox.shrink();
    final ratio = hojaLargo / hojaAncho;
    return LayoutBuilder(builder: (ctx, cons) {
      final w = cons.maxWidth;
      final h = (w / ratio).clamp(60.0, 220.0);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (titulo.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(titulo, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textoSecundario))),
        SizedBox(width: w, height: h, child: CustomPaint(painter: _HojaPainter(anidado, hojaLargo, hojaAncho))),
      ]);
    });
  }
}

class _HojaPainter extends CustomPainter {
  final Anidado a; final double hl, ha;
  _HojaPainter(this.a, this.hl, this.ha);
  @override
  void paint(Canvas c, Size s) {
    final esc = math.min(s.width / hl, s.height / ha);
    final w = hl * esc, h = ha * esc;
    final r = Rect.fromLTWH(0, 0, w, h);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), Paint()..color = const Color(0xFFf3e8d2));
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), Paint()..color = const Color(0xFFc9b48c)..style = PaintingStyle.stroke..strokeWidth = 1);
    // Retazo
    if (a.retazoLargo > 0 && a.retazoAncho > 0) {
      final rr = a.retazoLargo >= hl - 1
        ? Rect.fromLTWH(0, h - a.retazoAncho * esc, w, a.retazoAncho * esc)
        : Rect.fromLTWH(w - a.retazoLargo * esc, 0, a.retazoLargo * esc, h);
      c.drawRect(rr, Paint()..color = AppColors.ambar.withOpacity(0.18));
      final tp = TextPainter(text: TextSpan(text: 'retazo ${a.retazoLargo.round()}×${a.retazoAncho.round()}', style: const TextStyle(fontSize: 9, color: AppColors.naranja, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout(maxWidth: math.max(20, rr.width));
      if (rr.width > 40 && rr.height > 12) tp.paint(c, Offset(rr.left + 3, rr.top + 2));
    }
    final fill = Paint()..color = AppColors.azul.withOpacity(0.55);
    final borde = Paint()..color = AppColors.azul..style = PaintingStyle.stroke..strokeWidth = 0.8;
    for (final p in a.posiciones) {
      final pr = Rect.fromLTWH(p[0] * esc, p[1] * esc, p[2] * esc, p[3] * esc);
      c.drawRect(pr, fill); c.drawRect(pr, borde);
    }
  }
  @override
  bool shouldRepaint(_HojaPainter old) => old.a != a || old.hl != hl || old.ha != ha;
}
