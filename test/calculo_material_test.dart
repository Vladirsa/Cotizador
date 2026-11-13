// La calculadora de material con el ejemplo del tablón: 20 piezas por tablón, 16 tablones para 320 piezas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hetna_cnc/services/aprovechamiento.dart';
import 'package:hetna_cnc/widgets/calculo_material.dart';

void main() {
  test('tablón 100 × 2400 mm, pieza 80 × 110 mm, 10 mm de separación', () {
    final r = calcularMaterial(pzL: 80, pzA: 110, matL: 2400, matA: 100, sep: 10, piezas: 320, precio: 330);
    expect(r.porUnidad, 20);
    expect(r.unidades, 16);
    expect(r.costoTotal, 5280);
    expect(r.costoPorPieza, closeTo(16.5, 0.001));
  });

  test('hoja 1220 × 2440: se compran hojas completas', () {
    final r = calcularMaterial(pzL: 300, pzA: 300, matL: 2440, matA: 1220, sep: 10, piezas: 40, precio: 620);
    expect(r.porUnidad, 21); // 7 a lo largo × 3 a lo ancho (4 × 300 + 3 × 10 = 1230 > 1220)
    expect(r.unidades, 2);
    expect(r.costoTotal, 1240);
  });

  testWidgets('la pantalla muestra piezas por tablón y costo por pieza', (tester) async {
    Map<String, dynamic>? aplicado;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: CalculoMaterial(
      pzLargo: 80, pzAncho: 110,
      datos: const {'mat_l': '2400', 'mat_a': '100', 'sep': '10', 'orilla': '0', 'piezas': '320', 'precio': '330'},
      onCambio: (_) {},
      onAplicar: (r, d) => aplicado = {'piezas': r.piezas, 'desc': d},
    )))));
    expect(find.textContaining('20 piezas por tablón'), findsOneWidget);
    expect(find.textContaining('16 tablones completos'), findsOneWidget);
    expect(find.textContaining('16.50'), findsOneWidget);
    await tester.tap(find.text('Usar en el producto'));
    expect(aplicado?['piezas'], 320);
    expect(aplicado?['desc'], contains('16 tablones de 2400 × 100 mm (20 pz por tablón)'));
  });
}
