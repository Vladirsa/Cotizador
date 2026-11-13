// Genera una cotización profesional de prueba con una pieza 2D y revisa que el PDF salga.
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hetna_cnc/models/models.dart';
import 'package:hetna_cnc/services/pdf_service.dart';

List<List<double>> arco(double cx, double cy, double r, double a0, double a1, int n) =>
  [for (int i = 0; i <= n; i++) [cx + r * math.cos(a0 + (a1 - a0) * i / n), cy + r * math.sin(a0 + (a1 - a0) * i / n)]];

void main() {
  testWidgets('PDF profesional con cotas', (tester) async {
    await tester.runAsync(() => initializeDateFormatting());
    final placa = <List<double>>[[10, 0], [110, 0], ...arco(110, 10, 10, -math.pi / 2, 0, 12).skip(1), [120, 70],
      ...arco(110, 70, 10, 0, math.pi / 2, 12).skip(1), [10, 80], ...arco(10, 70, 10, math.pi / 2, math.pi, 12).skip(1), [0, 10],
      ...arco(10, 10, 10, math.pi, 1.5 * math.pi, 12).skip(1)];
    final geo = [placa, arco(30, 40, 4, 0, 2 * math.pi, 36), arco(90, 40, 6, 0, 2 * math.pi, 36), [[50.0, 20.0], [70.0, 20.0]]];
    final c = Cotizacion(tipo: 'profesional', folio: 'T-1', datosPro: {
      'archivo_info': {'nombre': 'placa.dxf', 'tipo': 'dxf', 'unidades': 'mm', 'largo': 120, 'ancho': 80, 'alto': 0, 'longitud_corte': 520, 'contornos': 3, 'barrenos': 2, 'area_pieza': 9500},
      'archivo_geo': geo,
      'material_principal': {'material': 'MDF', 'espesor': '18', 'mat_l': '2440', 'mat_a': '1220', 'sep': '6', 'piezas': '50'},
      'otras_piezas': [
        {'info': {'nombre': 'PIEZA 2.dxf', 'tipo': 'dxf', 'largo': 120, 'ancho': 150}, 'material': {'material': 'Acrílico', 'espesor': '6'}, 'geo': [[[0.0, 0.0], [120.0, 0.0], [120.0, 150.0], [90.0, 150.0], [90.0, 110.0], [30.0, 110.0], [30.0, 150.0], [0.0, 150.0], [0.0, 0.0]]]},
        {'info': {'nombre': 'PIEZA 3.dxf', 'tipo': 'dxf', 'largo': 80, 'ancho': 110}, 'material': {'material': 'Pino', 'espesor': '40', 'mat_l': '2400', 'mat_a': '100', 'sep': '10', 'piezas': '320'}, 'geo': [[[0.0, 0.0], [80.0, 0.0], [80.0, 110.0], [60.0, 110.0], ...arco(40, 110, 20, 0, -math.pi, 16).skip(1), [0.0, 110.0], [0.0, 0.0]]]},
      ],
    });
    final bytes = await tester.runAsync(() => PdfService.generarCotizacionProfesional(cotizacion: c, empresa: {'nombre': 'Taller de prueba'}, ingles: false));
    expect(bytes, isNotNull);
    File(Platform.environment['SALIDA_PDF'] ?? '/tmp/cotas.pdf').writeAsBytesSync(bytes!);
  });
}
