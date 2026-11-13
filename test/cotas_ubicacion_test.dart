// Ubicación de barrenos desde la esquina inferior izquierda y distancia entre barrenos alineados.
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:hetna_cnc/services/cotas_service.dart';

List<List<double>> circulo(double cx, double cy, double r) => [for (int i = 0; i <= 36; i++) [cx + r * math.cos(2 * math.pi * i / 36), cy + r * math.sin(2 * math.pi * i / 36)]];

void main() {
  test('barrenos en fila y columna', () {
    final marco = [[0.0, 0.0], [200.0, 0.0], [200.0, 100.0], [0.0, 100.0], [0.0, 0.0]];
    final cs = cotasDe([marco, circulo(20, 20, 4), circulo(100, 20, 4), circulo(180, 20, 4), circulo(20, 80, 5)]);
    final barrenos = cs.where((c) => c.tipo == TipoCota.diametro).toList();
    expect(barrenos.map((c) => c.ubicacion), ['X 20 · Y 20', 'X 100 · Y 20', 'X 180 · Y 20', 'X 20 · Y 80']);
    expect(barrenos.last.texto, 'Ø10');
    final entre = cs.where((c) => c.tipo == TipoCota.distancia).map((c) => fmtMm(c.valor)).toList();
    expect(entre, ['80', '80', '60']);
  });
}
