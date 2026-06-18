// ============================================
// lib/services/supabase_service.dart
// CRUD completo para todas las entidades
// ============================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  static final _db = Supabase.instance.client;

  // ═══════════════════════════════════════════
  // CONFIGURACIÓN
  // ═══════════════════════════════════════════
  static Future<Map<String, dynamic>> getConfiguracion() async {
    final res = await _db.from('configuracion_empresa').select().single();
    return res;
  }

  static Future<void> guardarConfiguracion(Map<String, dynamic> datos) async {
    final cfg = await _db.from('configuracion_empresa').select('id').single();
    await _db
        .from('configuracion_empresa')
        .update({...datos, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', cfg['id']);
  }

  // ═══════════════════════════════════════════
  // CLIENTES
  // ═══════════════════════════════════════════
  static Future<List<Cliente>> getClientes({String? busqueda}) async {
    var query = _db
        .from('clientes')
        .select()
        .eq('activo', true)
        .order('nombre');

    final res = await query;
    var clientes = res.map((j) => Cliente.fromJson(j)).toList();

    if (busqueda != null && busqueda.isNotEmpty) {
      final b = busqueda.toLowerCase();
      clientes = clientes.where((c) {
        return c.nombre.toLowerCase().contains(b) ||
            (c.empresa?.toLowerCase().contains(b) ?? false) ||
            (c.telefono?.contains(b) ?? false) ||
            (c.whatsapp?.contains(b) ?? false);
      }).toList();
    }

    return clientes;
  }

  static Future<Cliente> crearCliente(Cliente cliente) async {
    final res = await _db
        .from('clientes')
        .insert(cliente.toJson())
        .select()
        .single();
    return Cliente.fromJson(res);
  }

  static Future<Cliente> actualizarCliente(Cliente cliente) async {
    final res = await _db
        .from('clientes')
        .update({...cliente.toJson(), 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', cliente.id!)
        .select()
        .single();
    return Cliente.fromJson(res);
  }

  static Future<void> eliminarCliente(String id) async {
    await _db.from('clientes').update({'activo': false}).eq('id', id);
  }

  // ═══════════════════════════════════════════
  // CATEGORÍAS
  // ═══════════════════════════════════════════
  static Future<List<CategoriaProducto>> getCategorias() async {
    final res = await _db
        .from('categorias_producto')
        .select()
        .order('orden');
    return res.map((j) => CategoriaProducto.fromJson(j)).toList();
  }

  // ═══════════════════════════════════════════
  // PRODUCTOS
  // ═══════════════════════════════════════════
  static Future<List<Producto>> getProductos({
    String? categoriaId,
    String? busqueda,
    bool soloActivos = true,
  }) async {
    var query = _db
        .from('productos')
        .select('*, categorias_producto(nombre, color_hex)');

    if (soloActivos) query = query.eq('activo', true) as dynamic;
    if (categoriaId != null) query = query.eq('categoria_id', categoriaId) as dynamic;

    final res = await query.order('nombre');
    var productos = res.map((j) => Producto.fromJson(j)).toList();

    if (busqueda != null && busqueda.isNotEmpty) {
      final b = busqueda.toLowerCase();
      productos = productos.where((p) =>
          p.nombre.toLowerCase().contains(b) ||
          (p.sku?.toLowerCase().contains(b) ?? false) ||
          (p.categoriaNombre?.toLowerCase().contains(b) ?? false)).toList();
    }

    return productos;
  }

  static Future<Producto> crearProducto(Producto producto) async {
    final res = await _db
        .from('productos')
        .insert(producto.toJson())
        .select('*, categorias_producto(nombre, color_hex)')
        .single();
    return Producto.fromJson(res);
  }

  static Future<Producto> actualizarProducto(Producto producto) async {
    final res = await _db
        .from('productos')
        .update({...producto.toJson(), 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', producto.id!)
        .select('*, categorias_producto(nombre, color_hex)')
        .single();
    return Producto.fromJson(res);
  }

  static Future<void> eliminarProducto(String id) async {
    await _db.from('productos').update({'activo': false}).eq('id', id);
  }

  // ═══════════════════════════════════════════
  // PDFS CATÁLOGO
  // ═══════════════════════════════════════════
  static Future<List<PdfCatalogo>> getPdfs() async {
    final res = await _db
        .from('pdfs_catalogo')
        .select()
        .eq('activo', true)
        .order('created_at', ascending: false);
    return res.map((j) => PdfCatalogo.fromJson(j)).toList();
  }

  static Future<PdfCatalogo> subirPdf({
    required String nombre,
    required String url,
    String? categoria,
    double? tamanoMb,
  }) async {
    final res = await _db.from('pdfs_catalogo').insert({
      'nombre': nombre,
      'url': url,
      'categoria': categoria,
      'tamano_mb': tamanoMb,
    }).select().single();
    return PdfCatalogo.fromJson(res);
  }

  static Future<void> eliminarPdf(String id) async {
    await _db.from('pdfs_catalogo').update({'activo': false}).eq('id', id);
  }

  // ═══════════════════════════════════════════
  // COTIZACIONES
  // ═══════════════════════════════════════════
  static Future<String> generarFolio() async {
    final res = await _db.rpc('generar_folio_cotizacion');
    return res as String;
  }

  static Future<Cotizacion> crearCotizacion(
      Cotizacion cotizacion, List<CotizacionItem> items) async {
    final folio = await generarFolio();

    final resCot = await _db.from('cotizaciones').insert({
      'folio': folio,
      'cliente_id': cotizacion.clienteId,
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

    // Insertar items
    await _db.from('cotizacion_items').insert(
      items.map((i) => i.toJson(resCot['id'])).toList(),
    );

    return getCotizacion(resCot['id']);
  }

  static Future<Cotizacion> getCotizacion(String id) async {
    final res = await _db
        .from('cotizaciones')
        .select('*, clientes(*), cotizacion_items(*)')
        .eq('id', id)
        .single();

    final cot = Cotizacion.fromJson(res);
    if (res['clientes'] != null) {
      // Adjuntar cliente
    }
    if (res['cotizacion_items'] != null) {
      cot.items.addAll(
        (res['cotizacion_items'] as List)
            .map((i) => CotizacionItem.fromJson(i))
            .toList(),
      );
    }
    return cot;
  }

  static Future<List<Cotizacion>> getCotizaciones({
    String? estado,
    String? clienteId,
  }) async {
    var query = _db
        .from('cotizaciones')
        .select('*, clientes(nombre, empresa, whatsapp)')
        .order('created_at', ascending: false);

    if (estado != null) query = query.eq('estado', estado) as dynamic;
    if (clienteId != null) query = query.eq('cliente_id', clienteId) as dynamic;

    final res = await query;
    return res.map((j) => Cotizacion.fromJson(j)).toList();
  }

  static Future<void> cambiarEstadoCotizacion(
      String id, String nuevoEstado) async {
    await _db.from('cotizaciones').update({
      'estado': nuevoEstado,
      'updated_at': DateTime.now().toIso8601String(),
      if (nuevoEstado == 'Enviada')
        'fecha_envio_wa': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ─── CONVERTIR COTIZACIÓN EN PEDIDO ─────────
  static Future<Pedido> convertirEnPedido(Cotizacion cotizacion) async {
    // Cambiar estado cotización
    await cambiarEstadoCotizacion(cotizacion.id!, 'Pedido');

    // Generar folio pedido
    final folioPedido = 'PED-${DateTime.now().year}-${cotizacion.folio!.split('-').last}';

    final res = await _db.from('pedidos').insert({
      'folio': folioPedido,
      'cotizacion_id': cotizacion.id,
      'cliente_id': cotizacion.clienteId,
      'estado': 'Pedido',
      'total': cotizacion.total,
      'fecha_entrega_estimada':
          cotizacion.fechaEntrega?.toIso8601String().split('T')[0],
    }).select().single();

    // Registrar avance inicial
    await _db.from('pedido_avances').insert({
      'pedido_id': res['id'],
      'etapa': 'Pedido',
      'descripcion': 'Pedido creado a partir de cotización ${cotizacion.folio}',
    });

    return Pedido.fromJson(res);
  }

  // ═══════════════════════════════════════════
  // PEDIDOS
  // ═══════════════════════════════════════════
  static Future<List<Pedido>> getPedidos({String? estado}) async {
    var query = _db
        .from('pedidos')
        .select('*, clientes(nombre, empresa, whatsapp)')
        .order('created_at', ascending: false);

    if (estado != null) query = query.eq('estado', estado) as dynamic;

    final res = await query;
    return res.map((j) => Pedido.fromJson(j)).toList();
  }

  static Future<void> actualizarEtapaPedido(
      String pedidoId, String nuevaEtapa, {String? descripcion}) async {
    await _db.from('pedidos').update({
      'estado': nuevaEtapa,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', pedidoId);

    await _db.from('pedido_avances').insert({
      'pedido_id': pedidoId,
      'etapa': nuevaEtapa,
      'descripcion': descripcion,
    });
  }

  // ═══════════════════════════════════════════
  // ALERTAS
  // ═══════════════════════════════════════════
  static Future<List<Alerta>> getAlertasPendientes() async {
    final res = await _db.from('v_alertas_pendientes').select();
    return res.map((j) => Alerta.fromJson(j)).toList();
  }

  static Future<void> marcarAlertaCompletada(String alertaId) async {
    await _db.from('alertas').update({
      'completada': true,
      'fecha_completada': DateTime.now().toIso8601String(),
    }).eq('id', alertaId);
  }

  static Future<int> countAlertasPendientes() async {
    final res = await _db
        .from('alertas')
        .select('id')
        .eq('completada', false)
        .lte('fecha_programada', DateTime.now().toIso8601String());
    return (res as List).length;
  }

  // ═══════════════════════════════════════════
  // ESTADÍSTICAS
  // ═══════════════════════════════════════════
  static Future<Map<String, dynamic>> getEstadisticasMes() async {
    final res = await _db.from('v_estadisticas_mes').select().single();
    return res;
  }

  static Future<List<Map<String, dynamic>>> getVentasPorMes() async {
    final res = await _db.rpc('ventas_por_mes');
    return List<Map<String, dynamic>>.from(res);
  }
}
