// En un celular angosto (320 px) "Mis cotizaciones" se ve completo en la pestaña.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('las pestañas de Cotizar caben en 320 px', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: DefaultTabController(length: 3, child: Scaffold(appBar: AppBar(
      bottom: TabBar(
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        tabs: [
          for (final t in ['Nueva', 'Mis cotizaciones', 'Catálogo'])
            Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text(t, maxLines: 1, softWrap: false))),
        ]))))));
    // El texto completo se dibuja dentro de su pestaña (no se corta ni se desborda)
    final texto = tester.getRect(find.text('Mis cotizaciones'));
    final tab = tester.getRect(find.ancestor(of: find.text('Mis cotizaciones'), matching: find.byType(Tab)));
    expect(texto.left >= tab.left - 0.5 && texto.right <= tab.right + 0.5, isTrue);
    expect(tester.takeException(), isNull);
  });
}
