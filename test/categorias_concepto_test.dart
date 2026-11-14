// Categorías de conceptos: se adivinan por el nombre, se respetan si se eligen,
// y el PDF profesional sale agrupado con subtotales.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hetna_cnc/models/models.dart';
import 'package:hetna_cnc/services/categorias_concepto.dart';
import 'package:hetna_cnc/services/pdf_service.dart';

CotizacionItem it(String n, double p, {String? cat, String? medidas, String? desc}) =>
    CotizacionItem(nombreProducto: n, precioUnitario: p, categoria: cat, medidas: medidas, descripcion: desc);

void main() {
  test('adivina la categoría por el nombre', () {
    expect(categoriaDe(it('Envío por paquetería', 250)), 'transporte');
    expect(categoriaDe(it('Pintura electrostática', 80)), 'acabados');
    expect(categoriaDe(it('Programación CAM', 300)), 'programacion');
    expect(categoriaDe(it('Diseño del logotipo', 500)), 'diseno');
    expect(categoriaDe(it('Lámina de acero 2 mm', 900)), 'material');
    expect(categoriaDe(it('Reporte dimensional', 400)), 'inspeccion');
    expect(categoriaDe(it('Embalaje en tarima', 150)), 'empaque');
    // Una pieza con medidas es fabricación aunque su descripción hable de material
    expect(categoriaDe(it('Placa base', 45, medidas: '120 × 80 mm', desc: 'Material: MDF · Acabado: Barniz')), 'fabricacion');
    expect(categoriaDe(it('Servicio', 100)), 'fabricacion');
    // La elegida manda
    expect(categoriaDe(it('Envío', 100, cat: 'otros')), 'otros');
  });

  test('agrupa en el orden del catálogo con subtotales', () {
    final g = agruparPorCategoria([it('Envío', 200), it('Placa', 50, medidas: '10 × 10'), it('Pintura', 30), it('Soporte', 20, medidas: '5 × 5')]);
    expect(g.map((x) => x.clave).toList(), ['fabricacion', 'acabados', 'transporte']);
    expect(g.first.subtotal, 70);
    expect(it('x', 1, cat: 'material').toJson('c')['categoria'], 'material');
    expect(it('x', 1).toJson('c').containsKey('categoria'), isFalse);
  });

  testWidgets('PDF profesional agrupado por categoría', (tester) async {
    await tester.runAsync(() => initializeDateFormatting());
    final c = Cotizacion(tipo: 'profesional', folio: 'T-2', items: [
      CotizacionItem(nombreProducto: 'Placa de montaje', cantidad: 50, precioUnitario: 45, medidas: '120 × 80 mm'),
      CotizacionItem(nombreProducto: 'Soporte lateral', cantidad: 50, precioUnitario: 30, medidas: '60 × 40 mm'),
      it('Programación CAM', 600),
      it('Anodizado natural', 1200),
      it('Reporte dimensional', 450),
      it('Empaque individual', 300),
      it('Envío por paquetería', 380),
    ], datosPro: {'proyecto': 'Soportes', 'tiempo_entrega': '10 días hábiles'}, ivaPct: 16);
    final bytes = await tester.runAsync(() => PdfService.generarCotizacionProfesional(cotizacion: c, empresa: {'nombre_comercial': 'HetNa CNC'}, ingles: false));
    expect(bytes, isNotNull);
    final salida = Platform.environment['SALIDA_PDF_CAT'];
    if (salida != null) File(salida).writeAsBytesSync(bytes!);
  });
}
