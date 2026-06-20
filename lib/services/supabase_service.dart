// ============================================
// lib/services/supabase_service.dart
// CRUD completo - versión corregida
// ============================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  static final _db = Supabase.instance.client;

  // ═══════════════════════════════════════════
  // CONFIGURACIÓN
  // ═══════════════════════════════════════════
  static Future<Map<String, dynamic>> getConfiguracion() async {
    try {
      final res = await _db.from('configuracion_empresa').select().limit(1);
      final list = res as List;
      if (list.isEmpty) {
        await _db.from('configuracion_empresa').insert({'nombre_comercial': 'HETNA CNC'});
        final res2 = await _db.from('configuracion_empresa').select().limit(1);
        return (res2 as List).first as Map<String, dynamic>;
      }
      return list.first as Map<String, dynamic>;
    } catch (e) {
      return {'nombre_comercial': 'HETNA CNC'};
    }
  }

  static Future<void> guardarConfiguracion(Map<String, dynamic> datos) async {
    try {
      final res = await _db.from('configuracion_empresa').select('id').limit(1);
      final list = res as List;
      if (list.isNotEmpty) {
        final id = (list.first as Map<String, dynamic>)['id'];
        await _db.from('configuracion_empresa')
            .update({...datos, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', id);
      } else {
        await _db.from('configuracion_empresa').insert(datos);
      }
    } catch (e) {
      rethrow;
    }
  }

  // ═══════════════════════════════════════════
  // CLIENTES
  // ═══════════════════════════════════════════
  static Future<List<Cliente>> getClientes({String? busqueda}) async {
    final res = await _db.from('clientes').select().eq('activo', true).order('nombre');
    final list = res as List;
    var clientes = list.map((j) => Cliente.fromJson(j as Map<String, dynamic>)).toList();
    if (busqueda != null && busqueda.isNotEmpty) {
      final b = busqueda.toLowerCase();
      clientes = clientes.where((c) =>
        c.nombre.toLowerCase().contains(b) ||
        (c.empresa?.toLowerCase().contains(b) ?? false) ||
        (c.telefono?.contains(b) ?? false)).toList();
    }
    return clientes;
  }

  static Future<Cliente> crearCliente(Cliente cliente) async {
    final res = await _db.from('clientes').insert(cliente.toJson()).select().single();
    return Cliente.fromJson(res as Map<String, dynamic>);
  }

  static Future<Cliente> actualizarCliente(Cliente cliente) async {
    final res = await _db.from('clientes')
        .update({...cliente.toJson(), 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', cliente.id!).select().single();
    return Cliente.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> eliminarCliente(String id) async {
    await _db.from('clientes').update({'activo': false}).eq('id', id);
  }

  // ═══════════════════════════════════════════
  // CATEGORÍAS
  // ═══════════════════════════════════════════
  static Future<List<CategoriaProducto>> getCategorias() async {
    final res = await _db.from('categorias_producto').select().order('orden');
    final list = res as List;
    return list.map((j) => CategoriaProducto.fromJson(j as Map<String, dynamic>)).toList();
  }

  // ═══════════════════════════════════════════
  // PRODUCTOS
  // ═══════════════════════════════════════════
  static Future<List<Producto>> getProductos({
    String? categoriaId,
    String? busqueda,
    bool soloActivos = true,
  }) async {
    var query = _db.from('productos').select('*, categorias_producto(nombre, color_hex)');
    if (soloActivos) {
      final res = await query.eq('activo', true).order('nombre');
      final list = res as List;
      var productos = list.map((j) => Producto.fromJson(j as Map<String, dynamic>)).toList();
      if (categoriaId != null) {
        productos = productos.where((p) => p.categoriaId == categoriaId).toList();
      }
      if (busqueda != null && busqueda.isNotEmpty) {
        final b = busqueda.toLowerCase();
        productos = productos.where((p) =>
          p.nombre.toLowerCase().contains(b) ||
          (p.sku?.toLowerCase().contains(b) ?? false)).toList();
      }
      return productos;
    } else {
      final res = await query.order('nombre');
      final list = res as List;
      return list.map((j) => Producto.fromJson(j as Map<String, dynamic>)).toList();
    }
  }

  static Future<Producto> crearProducto(Producto producto) async {
    final res = await _db.from('productos').insert(producto.toJson())
        .select('*, categorias_producto(nombre, color_hex)').single();
    return Producto.fromJson(res as Map<String, dynamic>);
  }

  static Future<Producto> actualizarProducto(Producto producto) async {
    final res = await _db.from('productos')
        .update({...producto.toJson(), 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', producto.id!)
        .select('*, categorias_producto(nombre, color_hex)').single();
    return Producto.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> eliminarProducto(String id) async {
    await _db.from('productos').update({'activo': false}).eq('id', id);
  }

  // ═══════════════════════════════════════════
  // PDFS CATÁLOGO
  // ═══════════════════════════════════════════
  static Future<List<PdfCatalogo>> getPdfs() async {
    final res = await _db.from('pdfs_catalogo').select().eq('activo', true)
        .order('created_at', ascending: false);
    final list = res as List;
    return list.map((j) => PdfCatalogo.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<PdfCatalogo> subirPdf({
    required String nombre,
    required String url,
    String? categoria,
    double? tamanoMb,
  }) async {
    final res = await _db.from('pdfs_catalogo').insert({
      'nombre': nombre, 'url': url, 'categoria': categoria, 'tamano_mb': tamanoMb,
    }).select().single();
    return PdfCatalogo.fromJson(res as Map<String, dynamic>);
  }

  // ═══════════════════════════════════════════
  // COTIZACIONES
  // ═══════════════════════════════════════════
  static Future<String> generarFolio() async {
    try {
      final res = await _db.rpc('generar_folio_cotizacion');
      return res as String;
    } catch (_) {
      return 'COT-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  static Future<Cotizacion> crearCotizacion(
      Cotizacion cotizacion, List<CotizacionItem> items) async {
    final folio = await generarFolio();
    final resCot = await _db.from('cotizaciones').insert({
      'folio': folio,
      'cliente_id': cotizacion.clienteId ?? cotizacion.cliente?.id,
      'estado': cotizacion.estado,
      'subtotal': cotizacion.subtotal,
      'descuento_pct': cotizacion.descuentoPct,
      'descuento_fijo': cotizacion.descuentoFijo,
      'iva_pct': cotizacion.ivaPct,
      'iva_monto': cotizacion.montoIva,
      'costo_envio': cotizacion.costoEnvio,
      'total': cotizacion.total,
      'metodo_pago': cotizacion.metodoPago,
      'condicion_entrega': cotizacion.condicionEntrega,
      'fecha_entrega': cotizacion.fechaEntrega?.toIso8601String().split('T')[0],
      'dias_habiles': cotizacion.diasHabiles,
      'vigencia_dias': cotizacion.vigenciaDias,
      'notas': cotizacion.notas,
    }).select().single();

    final cotId = (resCot as Map<String, dynamic>)['id'] as String;
    if (items.isNotEmpty) {
      await _db.from('cotizacion_items').insert(
        items.map((i) => i.toJson(cotId)).toList(),
      );
    }
    return Cotizacion.fromJson(resCot);
  }

  static Future<List<Cotizacion>> getCotizaciones({
    String? estado,
    String? clienteId,
  }) async {
    if (estado != null && clienteId != null) {
      final res = await _db.from('cotizaciones')
          .select('*, clientes(nombre, empresa, whatsapp)')
          .eq('estado', estado).eq('cliente_id', clienteId)
          .order('created_at', ascending: false);
      return (res as List).map((j) => Cotizacion.fromJson(j as Map<String, dynamic>)).toList();
    } else if (estado != null) {
      final res = await _db.from('cotizaciones')
          .select('*, clientes(nombre, empresa, whatsapp)')
          .eq('estado', estado).order('created_at', ascending: false);
      return (res as List).map((j) => Cotizacion.fromJson(j as Map<String, dynamic>)).toList();
    } else if (clienteId != null) {
      final res = await _db.from('cotizaciones')
          .select('*, clientes(nombre, empresa, whatsapp)')
          .eq('cliente_id', clienteId).order('created_at', ascending: false);
      return (res as List).map((j) => Cotizacion.fromJson(j as Map<String, dynamic>)).toList();
    } else {
      final res = await _db.from('cotizaciones')
          .select('*, clientes(nombre, empresa, whatsapp)')
          .order('created_at', ascending: false);
      return (res as List).map((j) => Cotizacion.fromJson(j as Map<String, dynamic>)).toList();
    }
  }

  static Future<void> cambiarEstadoCotizacion(String id, String nuevoEstado) async {
    await _db.from('cotizaciones').update({
      'estado': nuevoEstado,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<Pedido> convertirEnPedido(Cotizacion cotizacion) async {
    await cambiarEstadoCotizacion(cotizacion.id!, 'Pedido');
    final folioPedido = 'PED-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final res = await _db.from('pedidos').insert({
      'folio': folioPedido,
      'cotizacion_id': cotizacion.id,
      'cliente_id': cotizacion.clienteId ?? cotizacion.cliente?.id,
      'estado': 'Pedido',
      'total': cotizacion.total,
      'fecha_entrega_estimada': cotizacion.fechaEntrega?.toIso8601String().split('T')[0],
    }).select().single();
    return Pedido.fromJson(res as Map<String, dynamic>);
  }

  // ═══════════════════════════════════════════
  // PEDIDOS
  // ═══════════════════════════════════════════
  static Future<List<Pedido>> getPedidos({String? estado}) async {
    if (estado != null) {
      final res = await _db.from('pedidos')
          .select('*, clientes(nombre, empresa, whatsapp)')
          .eq('estado', estado).order('created_at', ascending: false);
      return (res as List).map((j) => Pedido.fromJson(j as Map<String, dynamic>)).toList();
    } else {
      final res = await _db.from('pedidos')
          .select('*, clientes(nombre, empresa, whatsapp)')
          .order('created_at', ascending: false);
      return (res as List).map((j) => Pedido.fromJson(j as Map<String, dynamic>)).toList();
    }
  }

  static Future<void> actualizarEtapaPedido(
      String pedidoId, String nuevaEtapa, {String? descripcion}) async {
    await _db.from('pedidos').update({
      'estado': nuevaEtapa,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', pedidoId);
    await _db.from('pedido_avances').insert({
      'pedido_id': pedidoId, 'etapa': nuevaEtapa, 'descripcion': descripcion,
    });
  }

  // ═══════════════════════════════════════════
  // ALERTAS
  // ═══════════════════════════════════════════
  static Future<List<Alerta>> getAlertasPendientes() async {
    try {
      final res = await _db.from('v_alertas_pendientes').select();
      final list = res as List;
      return list.map((j) => Alerta.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> marcarAlertaCompletada(String alertaId) async {
    await _db.from('alertas').update({
      'completada': true,
      'fecha_completada': DateTime.now().toIso8601String(),
    }).eq('id', alertaId);
  }

  static Future<int> countAlertasPendientes() async {
    try {
      final res = await _db.from('alertas').select('id')
          .eq('completada', false)
          .lte('fecha_programada', DateTime.now().toIso8601String());
      return (res as List).length;
    } catch (_) {
      return 0;
    }
  }

  // ═══════════════════════════════════════════
  // ESTADÍSTICAS
  // ═══════════════════════════════════════════
  static Future<Map<String, dynamic>> getEstadisticasMes() async {
    try {
      final res = await _db.from('v_estadisticas_mes').select().limit(1);
      final list = res as List;
      if (list.isNotEmpty) return list.first as Map<String, dynamic>;
      return {'solicitudes_elaboradas': 0, 'pedidos_entregados': 0, 'alertas_pendientes': 0, 'ventas_mes': 0};
    } catch (_) {
      return {'solicitudes_elaboradas': 0, 'pedidos_entregados': 0, 'alertas_pendientes': 0, 'ventas_mes': 0};
    }
  }
  // ═══════════════════════════════════════════
  // GASTOS
  // ═══════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getGastos({String? periodo}) async {
    try {
      DateTime desde;
      final ahora = DateTime.now();
      switch (periodo) {
        case 'Hoy':
          desde = DateTime(ahora.year, ahora.month, ahora.day);
          break;
        case 'Esta semana':
          desde = ahora.subtract(Duration(days: ahora.weekday - 1));
          break;
        case 'Mes anterior':
          desde = DateTime(ahora.year, ahora.month - 1, 1);
          break;
        default: // Este mes
          desde = DateTime(ahora.year, ahora.month, 1);
      }
      final res = await _db.from('gastos').select()
          .gte('fecha', desde.toIso8601String())
          .order('fecha', ascending: false);
      return (res as List).map((j) => j as Map<String, dynamic>).toList();
    } catch (_) { return []; }
  }

  static Future<void> registrarGasto(Map<String, dynamic> gasto) async {
    await _db.from('gastos').insert(gasto);
  }

  static Future<void> eliminarGasto(String id) async {
    await _db.from('gastos').delete().eq('id', id);
  }

  // ═══════════════════════════════════════════
  // INVENTARIO BODEGA
  // ═══════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getMateriales() async {
    try {
      final res = await _db.from('inventario_bodega').select()
          .eq('activo', true).order('categoria').order('nombre');
      return (res as List).map((j) => j as Map<String, dynamic>).toList();
    } catch (_) { return []; }
  }

  static Future<void> registrarMovimiento({
    required String materialId,
    required String tipo,
    required int cantidad,
    String? motivo,
  }) async {
    await _db.from('movimientos_inventario').insert({
      'material_id': materialId,
      'tipo': tipo,
      'cantidad': cantidad,
      'motivo': motivo,
      'fecha': DateTime.now().toIso8601String(),
    });
    final material = await _db.from('inventario_bodega').select('stock_actual').eq('id', materialId).single();
    final stockActual = (material as Map<String, dynamic>)['stock_actual'] as int;
    final nuevoStock = tipo == 'entrada' ? stockActual + cantidad : (stockActual - cantidad).clamp(0, 99999);
    await _db.from('inventario_bodega').update({'stock_actual': nuevoStock, 'updated_at': DateTime.now().toIso8601String()}).eq('id', materialId);
  }

  static Future<void> agregarMaterial(Map<String, dynamic> material) async {
    await _db.from('inventario_bodega').insert(material);
  }
}
