// lib/services/inventario_pedido_service.dart
// HETNA CNC — Inventario conectado a los pedidos.
//
// Al empezar el maquinado se descuenta el material de la bodega (y queda
// como costo real del pedido) y al terminar se puede guardar el retazo que
// sobró. La lista de compra ya vive en inventario_screen.
// Tablas: supabase/inventario_pedidos.sql.
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'costos_service.dart';
import 'supabase_service.dart';

class MaterialPorDescontar {
  final String materialId;
  final String nombre;
  final String unidad;
  final double costoUnitario;
  final int stock;
  double cantidad;
  MaterialPorDescontar({required this.materialId, required this.nombre, required this.unidad, required this.costoUnitario, required this.stock, required this.cantidad});
}

class InventarioPedidoService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Lo que las partidas de la cotización del pedido dicen que se usa.
  /// Vacío si la cotización no trae material (se eligió a mano o es vieja).
  static Future<List<MaterialPorDescontar>> propuesta(String pedidoId) async {
    final p = await _db.from('pedidos').select('cotizacion_id, material_descontado').eq('id', pedidoId).maybeSingle();
    if (p == null || p['cotizacion_id'] == null) return [];
    final items = await _db.from('cotizacion_items')
        .select('material_id, material_cantidad, cantidad, inventario_bodega(id, nombre, unidad, costo_unitario, stock_actual)')
        .eq('cotizacion_id', p['cotizacion_id']).not('material_id', 'is', null);
    final porMaterial = <String, MaterialPorDescontar>{};
    for (final j in (items as List)) {
      final m = j as Map<String, dynamic>;
      final inv = m['inventario_bodega'] as Map<String, dynamic>?;
      if (inv == null) continue;
      final id = inv['id'] as String;
      final cant = (m['material_cantidad'] as num?)?.toDouble() ?? ((m['cantidad'] as num?)?.toDouble() ?? 1);
      if (porMaterial.containsKey(id)) {
        porMaterial[id]!.cantidad += cant;
      } else {
        porMaterial[id] = MaterialPorDescontar(materialId: id, nombre: (inv['nombre'] ?? '').toString(), unidad: (inv['unidad'] ?? 'pzas').toString(),
          costoUnitario: (inv['costo_unitario'] as num?)?.toDouble() ?? 0, stock: (inv['stock_actual'] as num?)?.toInt() ?? 0, cantidad: cant);
      }
    }
    return porMaterial.values.toList();
  }

  static Future<bool> yaDescontado(String pedidoId) async {
    try {
      final p = await _db.from('pedidos').select('material_descontado').eq('id', pedidoId).maybeSingle();
      return p?['material_descontado'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Da salida del inventario y lo registra como costo real del pedido.
  static Future<void> descontar(String pedidoId, String folio, List<MaterialPorDescontar> lista) async {
    for (final m in lista) {
      if (m.cantidad <= 0) continue;
      await CostosService.agregarCosto(pedidoId: pedidoId, folio: folio, tipo: 'material', concepto: m.nombre,
        cantidad: m.cantidad, costoUnitario: m.costoUnitario, materialId: m.materialId);
    }
    try {
      await _db.from('pedidos').update({'material_descontado': true}).eq('id', pedidoId);
    } catch (_) {}
  }

  /// Guarda un retazo como material nuevo en la bodega (stock 1), con costo
  /// proporcional al área que le queda respecto a la hoja original.
  static Future<void> guardarRetazo({
    required String materialPadreId, required String nombrePadre, required double costoPadre,
    required double largoMm, required double anchoMm, double? espesorMm, double? largoHojaMm, double? anchoHojaMm, String? folio,
  }) async {
    double costo = 0;
    if (largoHojaMm != null && anchoHojaMm != null && largoHojaMm > 0 && anchoHojaMm > 0) {
      costo = costoPadre * (largoMm * anchoMm) / (largoHojaMm * anchoHojaMm);
    }
    await _db.from('inventario_bodega').insert({
      if (AuthService.negocioId != null) 'negocio_id': AuthService.negocioId,
      'nombre': 'Retazo $nombrePadre ${largoMm.round()}×${anchoMm.round()} mm',
      'categoria': 'Retazo',
      'unidad': 'pza',
      'stock_actual': 1,
      'stock_minimo': 0,
      'costo_unitario': double.parse(costo.toStringAsFixed(2)),
      'es_retazo': true,
      'largo_mm': largoMm,
      'ancho_mm': anchoMm,
      'espesor_mm': espesorMm,
      'material_padre_id': materialPadreId,
      'activo': true,
    });
  }

  /// Materiales de la bodega (hojas) para elegir a mano.
  static Future<List<Map<String, dynamic>>> materiales() => SupabaseService.getMateriales();
}
