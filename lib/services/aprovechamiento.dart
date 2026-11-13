// lib/services/aprovechamiento.dart
// HETNA CNC — Cuántas piezas salen de un tablón o de una hoja, cuánto material
// se compra y cuánto cuesta el material de cada pieza. Dart puro.
//
//   piezas por fila = (ancho útil + separación) ÷ (ancho de la pieza + separación), hacia abajo
//   (igual a lo largo), probando la pieza derecha y girada 90°; con lo que sobra
//   de un lado se intenta una franja con la pieza en el otro sentido.
//   Material: se compran tablones u hojas COMPLETOS (no medias hojas).
import 'dart:math' as math;

class ResultadoMaterial {
  final int porUnidad; // piezas por tablón u hoja
  final int unidades; // tablones u hojas que hay que comprar (completos)
  final int piezas; // piezas que se piden
  final int sobranEnUltima; // lugares libres en la última hoja o tablón
  final double costoTotal; // unidades × precio
  final double costoPorPieza; // costoTotal ÷ piezas
  final double aprovechamientoPct; // área de piezas ÷ área comprada
  final bool girada; // la mayoría de las piezas van giradas 90°
  final int filas, columnas; // acomodo principal
  final int extraFranja; // piezas que entran en la franja sobrante (sentido contrario)
  const ResultadoMaterial({required this.porUnidad, required this.unidades, required this.piezas, required this.sobranEnUltima,
    required this.costoTotal, required this.costoPorPieza, required this.aprovechamientoPct, required this.girada,
    required this.filas, required this.columnas, required this.extraFranja});
  bool get cabe => porUnidad > 0;
}

int _cuantas(double disponible, double pieza, double sep) {
  if (pieza <= 0 || disponible < pieza) return 0;
  return ((disponible + sep) / (pieza + sep)).floor();
}

/// [pzL]×[pzA]: medidas de la pieza (mm). [matL]×[matA]: tablón u hoja (mm).
/// [sep]: separación entre piezas (mm, la que deja la fresa o el láser).
/// [orilla]: margen en las orillas del material (mm).
ResultadoMaterial calcularMaterial({
  required double pzL, required double pzA, required double matL, required double matA,
  double sep = 0, double orilla = 0, required int piezas, double precio = 0,
}) {
  final uL = matL - 2 * orilla, uA = matA - 2 * orilla;
  ({int total, int filas, int cols, int franja, bool girada}) acomodo(double l, double a, bool girada) {
    final cols = _cuantas(uL, l, sep), filas = _cuantas(uA, a, sep);
    var total = cols * filas;
    int franja = 0;
    if (total > 0) {
      // Franja que sobra a lo largo, con la pieza en el otro sentido
      final sobraL = uL - (cols * (l + sep));
      final f1 = _cuantas(sobraL, a, sep) * _cuantas(uA, l, sep);
      // Franja que sobra a lo ancho
      final sobraA = uA - (filas * (a + sep));
      final f2 = _cuantas(uL, a, sep) * _cuantas(sobraA, l, sep);
      franja = math.max(f1, f2);
      total += franja;
    }
    return (total: total, filas: filas, cols: cols, franja: franja, girada: girada);
  }
  final a = acomodo(pzL, pzA, false), b = acomodo(pzA, pzL, true);
  final mejor = b.total > a.total ? b : a;
  final por = mejor.total;
  final n = math.max(0, piezas);
  final unidades = por > 0 ? (n / por).ceil() : 0;
  final sobran = por > 0 && unidades > 0 ? unidades * por - n : 0;
  final costo = unidades * precio;
  final areaComprada = unidades * matL * matA;
  return ResultadoMaterial(
    porUnidad: por, unidades: unidades, piezas: n, sobranEnUltima: sobran,
    costoTotal: costo, costoPorPieza: n > 0 ? costo / n : 0,
    aprovechamientoPct: areaComprada > 0 ? (n * pzL * pzA) / areaComprada * 100 : 0,
    girada: mejor.girada, filas: mejor.filas, columnas: mejor.cols, extraFranja: mejor.franja);
}
