// Pieza de muestra para quien sólo quiere ver cómo cotiza HETNA: una placa de
// 300 × 200 mm con 4 barrenos de 10 mm y un círculo central de 60 mm. Se abre
// en el Simulador 2.0 como si se hubiera subido un DXF.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/archivo_cad_service.dart';
import 'simulador2_screen.dart';

GeoCad piezaEjemplo() {
  List<List<double>> circulo(double cx, double cy, double r) =>
    List.generate(49, (i) { final a = i / 48 * 2 * math.pi; return [cx + r * math.cos(a), cy + r * math.sin(a)]; });
  final trazos = <List<List<double>>>[
    [[0, 0], [300, 0], [300, 200], [0, 200], [0, 0]],
    circulo(20, 20, 5), circulo(280, 20, 5), circulo(280, 180, 5), circulo(20, 180, 5),
    circulo(150, 100, 30),
  ];
  final corte = 1000.0 + 4 * 2 * math.pi * 5 + 2 * math.pi * 30;
  return GeoCad(
    nombre: 'ejemplo-placa-300x200.dxf', tipo: 'dxf', unidades: 'mm',
    largo: 300, ancho: 200, alto: 0,
    longitudCorte: corte, contornos: 6, barrenos: 5, areaPieza: 60000.0,
    trazos: trazos, avisos: ['Pieza de ejemplo de HETNA. Sube tu propio archivo cuando quieras.'],
  );
}

void abrirPiezaEjemplo(BuildContext context) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => Simulador2Screen(geoInicial: piezaEjemplo())));
}
