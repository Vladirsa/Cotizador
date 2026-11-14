// Categorías de los conceptos de una cotización profesional. Cada partida cae
// en una (la elige el taller o se adivina por su nombre) y el PDF las agrupa
// con su subtotal y un resumen por categoría.
import '../models/models.dart';

class CategoriaConcepto {
  final String clave;
  final String nombre;
  const CategoriaConcepto(this.clave, this.nombre);
}

const categoriasConcepto = <CategoriaConcepto>[
  CategoriaConcepto('fabricacion', 'Fabricación'),
  CategoriaConcepto('material', 'Material'),
  CategoriaConcepto('programacion', 'Programación CNC'),
  CategoriaConcepto('diseno', 'Diseño e ingeniería'),
  CategoriaConcepto('acabados', 'Acabados'),
  CategoriaConcepto('inspeccion', 'Inspección y calidad'),
  CategoriaConcepto('empaque', 'Empaque'),
  CategoriaConcepto('transporte', 'Transporte'),
  CategoriaConcepto('otros', 'Otros'),
];

String nombreCategoria(String clave) =>
    categoriasConcepto.firstWhere((c) => c.clave == clave, orElse: () => categoriasConcepto.last).nombre;

String _sinAcentos(String s) => s.toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a').replaceAll(RegExp('[éè]'), 'e').replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o').replaceAll(RegExp('[úùü]'), 'u').replaceAll('ñ', 'n');

// Orden importa: lo más específico primero. Sólo se mira el NOMBRE de la
// partida (la descripción de una pieza dice "Material: MDF · Acabado: ..." y
// confundiría a una pieza con material o acabado).
const _pistas = <String, List<String>>{
  'transporte': ['envio', 'flete', 'transporte', 'paqueteria', 'entrega a domicilio', 'shipping', 'freight'],
  'empaque': ['empaque', 'embalaje', 'emplayado', 'caja de carton', 'tarima', 'packaging'],
  'inspeccion': ['inspeccion', 'medicion', 'reporte dimensional', 'control de calidad', 'certificado', 'inspection'],
  'acabados': ['pintura', 'anodizado', 'acabado', 'pulido', 'lijado', 'galvaniz', 'cromado', 'electrostatic', 'barniz', 'laca', 'sellador', 'finish'],
  'programacion': ['programacion', 'codigo g', 'g-code', 'gcode', 'cam ', 'trayectorias', 'post procesado', 'programming'],
  'diseno': ['diseno', 'modelado', 'dibujo', 'render', 'ingenieria', 'vectoriz', 'design'],
  'material': ['material', 'lamina', 'placa de', 'hoja de', 'tablon', 'barra', 'solera', 'perfil', 'tablero'],
};

/// La categoría elegida o, si no la tiene, la que sugiere su nombre.
/// Las piezas con dibujo o medidas son fabricación.
String categoriaDe(CotizacionItem it) {
  final c = it.categoria;
  if (c != null && categoriasConcepto.any((x) => x.clave == c)) return c;
  if ((it.imagenPng ?? '').isNotEmpty || (it.medidas ?? '').isNotEmpty) return 'fabricacion';
  final n = ' ${_sinAcentos(it.nombreProducto)} ';
  for (final e in _pistas.entries) {
    if (e.value.any(n.contains)) return e.key;
  }
  return 'fabricacion';
}

/// Partidas agrupadas por categoría, en el orden del catálogo, con su subtotal.
List<({String clave, String nombre, List<CotizacionItem> items, double subtotal})> agruparPorCategoria(List<CotizacionItem> items) {
  final out = <({String clave, String nombre, List<CotizacionItem> items, double subtotal})>[];
  for (final cat in categoriasConcepto) {
    final del = items.where((i) => categoriaDe(i) == cat.clave).toList();
    if (del.isEmpty) continue;
    out.add((clave: cat.clave, nombre: cat.nombre, items: del, subtotal: del.fold(0.0, (s, i) => s + i.subtotal)));
  }
  return out;
}
