import 'dart:typed_data';
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
            .update(datos)
            .eq('id', id);
      } else {
        await _db.from('configuracion_empresa').insert(datos);
      }
    } catch (e) {
      // Ignorar errores de schema cache — los datos se guardan igual
      print('guardarConfiguracion: $e');
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
        items.map((i) => i.toJson(cotId)).toList());
    }
    return Cotizacion.fromJson(resCot);
  }

  static Future<void> eliminarCliente(String id) async {
    // Borrar en orden correcto por foreign keys
    try { await _db.from('cola_mensajes_wa').delete().eq('cliente_id', id); } catch(_) {}
    try { await _db.from('cliente_etiquetas').delete().eq('cliente_id', id); } catch(_) {}
    try { await _db.from('interacciones_wa').delete().eq('cliente_id', id); } catch(_) {}
    try { await _db.from('alertas').delete().eq('cliente_id', id); } catch(_) {}
    try { await _db.from('facturas').delete().eq('cliente_id', id); } catch(_) {}
    // Borrar pedidos y sus cotizaciones
    final pedidos = await _db.from('pedidos').select('id').eq('cliente_id', id);
    for (final p in (pedidos as List)) {
      await _db.from('facturas').delete().eq('pedido_id', p['id']);
    }
    await _db.from('pedidos').delete().eq('cliente_id', id);
    // Borrar cotizaciones
    final cots = await _db.from('cotizaciones').select('id').eq('cliente_id', id);
    for (final c in (cots as List)) {
      await _db.from('cotizacion_items').delete().eq('cotizacion_id', c['id']);
    }
    await _db.from('cotizaciones').delete().eq('cliente_id', id);
    // Finalmente borrar el cliente
    await _db.from('clientes').delete().eq('id', id);
  }

  static Future<void> eliminarPedidoPorCotizacion(String cotizacionId) async {
    try {
      // Primero eliminar referencias en tablas hijas del pedido
      final pedidos = await _db.from('pedidos').select('id').eq('cotizacion_id', cotizacionId);
      for (final p in (pedidos as List)) {
        final pid = p['id'] as String;
        await _db.from('facturas').delete().eq('pedido_id', pid);
        await _db.from('cola_mensajes_wa').delete().eq('cliente_id', pid);
      }
      await _db.from('pedidos').delete().eq('cotizacion_id', cotizacionId);
    } catch (_) {}
  }

  static Future<void> eliminarCotizacion(String id) async {
    await _db.from('cotizacion_items').delete().eq('cotizacion_id', id);
    await _db.from('cotizaciones').delete().eq('id', id);
  }

  static Future<List<Cotizacion>> getCotizaciones({
    String? estado,
    String? clienteId,
  }) async {
    const sel = '*, clientes(nombre, empresa, whatsapp, telefono), cotizacion_items(*)';
    if (estado != null && clienteId != null) {
      final res = await _db.from('cotizaciones').select(sel)
          .eq('estado', estado).eq('cliente_id', clienteId)
          .order('created_at', ascending: false);
      return (res as List).map((j) => Cotizacion.fromJson(j as Map<String, dynamic>)).toList();
    } else if (estado != null) {
      final res = await _db.from('cotizaciones').select(sel)
          .eq('estado', estado).order('created_at', ascending: false);
      return (res as List).map((j) => Cotizacion.fromJson(j as Map<String, dynamic>)).toList();
    } else if (clienteId != null) {
      final res = await _db.from('cotizaciones').select(sel)
          .eq('cliente_id', clienteId).order('created_at', ascending: false);
      return (res as List).map((j) => Cotizacion.fromJson(j as Map<String, dynamic>)).toList();
    } else {
      final res = await _db.from('cotizaciones').select(sel)
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

  static Future<List<CotizacionItem>> getCotizacionItems(String cotizacionId) async {
    try {
      final res = await _db.from('cotizacion_items')
          .select()
          .eq('cotizacion_id', cotizacionId)
          .order('created_at');
      return (res as List).map((j) => CotizacionItem.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  static Future<void> actualizarCotizacion(
      Cotizacion cotizacion, List<CotizacionItem> items) async {
    await _db.from('cotizaciones').update({
      'estado': cotizacion.estado,
      'descuento_pct': cotizacion.descuentoPct,
      'iva_pct': cotizacion.ivaPct,
      'iva_monto': cotizacion.montoIva,
      'costo_envio': cotizacion.costoEnvio,
      'subtotal': cotizacion.subtotal,
      'total': cotizacion.total,
      'metodo_pago': cotizacion.metodoPago,
      'condicion_entrega': cotizacion.condicionEntrega,
      'notas': cotizacion.notas,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', cotizacion.id!);
    await _db.from('cotizacion_items').delete().eq('cotizacion_id', cotizacion.id!);
    if (items.isNotEmpty) {
      await _db.from('cotizacion_items').insert(
        items.map((i) => i.toJson(cotizacion.id!)).toList());
    }
  }

  static Future<Pedido> convertirEnPedido(Cotizacion cotizacion) async {
    await cambiarEstadoCotizacion(cotizacion.id!, 'Pedido');
    // Verificar si ya existe un pedido para esta cotizacion
    final existente = await _db.from('pedidos')
        .select().eq('cotizacion_id', cotizacion.id!).limit(1);
    if ((existente as List).isNotEmpty) {
      // Ya existe — solo actualizar el total y retornar
      final pedidoId = (existente.first as Map<String, dynamic>)['id'];
      await _db.from('pedidos').update({
        'total': cotizacion.total,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', pedidoId);
      final res = await _db.from('pedidos').select('*, clientes(nombre, empresa, whatsapp)')
          .eq('id', pedidoId).single();
      return Pedido.fromJson(res as Map<String, dynamic>);
    }
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
    } catch (_) { return []; }
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
    } catch (_) { return 0; }
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
        default:
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
    final material = await _db.from('inventario_bodega')
        .select('stock_actual').eq('id', materialId).single();
    final stockActual = (material as Map<String, dynamic>)['stock_actual'] as int;
    final nuevoStock = tipo == 'entrada'
        ? stockActual + cantidad
        : (stockActual - cantidad).clamp(0, 99999);
    await _db.from('inventario_bodega').update({
      'stock_actual': nuevoStock,
      'updated_at': DateTime.now().toIso8601String()
    }).eq('id', materialId);
  }

  static Future<void> agregarMaterial(Map<String, dynamic> material) async {
    await _db.from('inventario_bodega').insert(material);
  }

  // ═══════════════════════════════════════════
  // CATÁLOGOS PERSONALIZADOS
  // ═══════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getCatalogosPersonalizados() async {
    try {
      final res = await _db.from('catalogos_personalizados').select()
          .eq('activo', true).order('created_at', ascending: false);
      return (res as List).map((j) => j as Map<String, dynamic>).toList();
    } catch (_) { return []; }
  }

  static Future<Map<String, dynamic>> crearCatalogoPersonalizado({
    required String nombre,
    String? descripcion,
    required List<String> productoIds,
  }) async {
    final res = await _db.from('catalogos_personalizados').insert({
      'nombre': nombre,
      'descripcion': descripcion,
      'producto_ids': productoIds,
      'activo': true,
    }).select().single();
    return res as Map<String, dynamic>;
  }

  static Future<void> eliminarCatalogoPersonalizado(String id) async {
    await _db.from('catalogos_personalizados').update({'activo': false}).eq('id', id);
  }

  static Future<PdfCatalogo> subirPdfCatalogo({
    required String nombre,
    required Uint8List bytes,
    String? categoria,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$nombre.pdf';
    await _db.storage.from('catalogos').uploadBinary(fileName, bytes,
        fileOptions: const FileOptions(contentType: 'application/pdf'));
    final url = _db.storage.from('catalogos').getPublicUrl(fileName);
    final tamanoMb = bytes.length / (1024 * 1024);
    final res = await _db.from('pdfs_catalogo').insert({
      'nombre': nombre, 'url': url, 'categoria': categoria,
      'tamano_mb': tamanoMb, 'activo': true,
    }).select().single();
    return PdfCatalogo.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> eliminarPdf(String id, String url) async {
    try {
      final fileName = Uri.parse(url).pathSegments.last;
      await _db.storage.from('catalogos').remove([fileName]);
    } catch (_) {}
    await _db.from('pdfs_catalogo').update({'activo': false}).eq('id', id);
  }

  // ═══════════════════════════════════════════
  // CATEGORÍAS DE PRODUCTOS
  // ═══════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getCategoriasMap() async {
    try {
      final res = await _db.from('categorias_producto').select()
          .order('nombre', ascending: true);
      return (res as List).map((j) => j as Map<String, dynamic>).toList();
    } catch (_) { return []; }
  }

  static Future<void> crearCategoria(Map<String, dynamic> datos) async {
    await _db.from('categorias_producto').insert(datos);
  }

  static Future<void> actualizarCategoria(String id, Map<String, dynamic> datos) async {
    await _db.from('categorias_producto').update(datos).eq('id', id);
  }

  static Future<void> eliminarCategoria(String id) async {
    // Desasociar productos antes de eliminar
    await _db.from('productos').update({'categoria_id': null}).eq('categoria_id', id);
    await _db.from('categorias_producto').delete().eq('id', id);
  }

  // ═══════════════════════════════════════════
  // FACTURACIÓN
  // ═══════════════════════════════════════════
  static Future<Map<String, dynamic>> getDatosFiscalesCliente(String clienteId) async {
    try {
      final res = await _db.from('clientes')
        .select('rfc_fiscal, razon_social, regimen_fiscal, uso_cfdi, cp_fiscal')
        .eq('id', clienteId).single();
      return res as Map<String, dynamic>;
    } catch (_) { return {}; }
  }

  static Future<void> guardarDatosFiscalesCliente({
    required String clienteId,
    required Map<String, dynamic> datos,
  }) async {
    await _db.from('clientes').update(datos).eq('id', clienteId);
  }

  static Future<void> crearFacturaPendiente(Map<String, dynamic> datos) async {
    await _db.from('facturas').insert({
      ...datos,
      'estado': 'pendiente',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getFacturasPedido(String pedidoId) async {
    try {
      final res = await _db.from('facturas')
        .select().eq('pedido_id', pedidoId)
        .order('created_at', ascending: false);
      return (res as List).map((j) => j as Map<String, dynamic>).toList();
    } catch (_) { return []; }
  }

  // ═══════════════════════════════════════════
  // MARKETING — PLANTILLAS WA
  // ═══════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getPlantillasWA() async {
    try {
      final res = await _db.from('plantillas_wa').select()
          .eq('activo', true).order('categoria').order('titulo');
      return (res as List).map((j) => j as Map<String, dynamic>).toList();
    } catch (_) { return []; }
  }

  static Future<void> guardarPlantillaWA(Map<String, dynamic> datos) async {
    if (datos['id'] != null) {
      await _db.from('plantillas_wa')
          .update({...datos, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', datos['id']);
    } else {
      await _db.from('plantillas_wa').insert(datos);
    }
  }

  static Future<void> eliminarPlantillaWA(String id) async {
    await _db.from('plantillas_wa').update({'activo': false}).eq('id', id);
  }

  // ═══════════════════════════════════════════
  // MARKETING — ETIQUETAS CLIENTES
  // ═══════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getEtiquetas() async {
    try {
      final res = await _db.from('etiquetas_cliente').select()
          .order('nombre');
      return (res as List).map((j) => j as Map<String, dynamic>).toList();
    } catch (_) { return []; }
  }

  static Future<List<String>> getEtiquetasCliente(String clienteId) async {
    try {
      final res = await _db.from('cliente_etiquetas')
          .select('etiqueta_id, etiquetas_cliente(nombre)')
          .eq('cliente_id', clienteId);
      return (res as List).map((j) {
        final et = j['etiquetas_cliente'];
        return et is Map ? (et['nombre'] as String? ?? '') : '';
      }).where((s) => s.isNotEmpty).toList();
    } catch (_) { return []; }
  }

  static Future<void> setEtiquetasCliente(String clienteId, List<String> etiquetaIds) async {
    await _db.from('cliente_etiquetas').delete().eq('cliente_id', clienteId);
    if (etiquetaIds.isNotEmpty) {
      await _db.from('cliente_etiquetas').insert(
        etiquetaIds.map((eid) => {'cliente_id': clienteId, 'etiqueta_id': eid}).toList());
    }
  }

  // ═══════════════════════════════════════════
  // MARKETING — COLA DE MENSAJES
  // ═══════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getColaMensajesHoy() async {
    try {
      final hoy = DateTime.now().toIso8601String().split('T')[0];
      final res = await _db.from('cola_mensajes_wa')
          .select('*, clientes(nombre, whatsapp, telefono)')
          .eq('estado', 'pendiente')
          .eq('fecha_programada', hoy)
          .order('created_at');
      return (res as List).map((j) => j as Map<String, dynamic>).toList();
    } catch (_) { return []; }
  }

  static Future<List<Map<String, dynamic>>> getColaMensajesHistorial() async {
    try {
      final res = await _db.from('cola_mensajes_wa')
          .select('*, clientes(nombre)')
          .neq('estado', 'pendiente')
          .order('created_at', ascending: false)
          .limit(50);
      return (res as List).map((j) => j as Map<String, dynamic>).toList();
    } catch (_) { return []; }
  }

  static Future<void> marcarMensajeEnviado(String id) async {
    await _db.from('cola_mensajes_wa').update({
      'estado': 'enviado',
      'enviado_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> marcarMensajeOmitido(String id) async {
    await _db.from('cola_mensajes_wa').update({'estado': 'omitido'}).eq('id', id);
  }

  static Future<int> countMensajesEnviadosHoy() async {
    try {
      final hoy = DateTime.now().toIso8601String().split('T')[0];
      final res = await _db.from('cola_mensajes_wa')
          .select().eq('estado', 'enviado').eq('fecha_programada', hoy);
      return (res as List).length;
    } catch (_) { return 0; }
  }

  static Future<void> agregarAColaMarketing({
    required String clienteId,
    required String mensajeFinal,
    String? plantillaId,
    String? campana,
    DateTime? fechaProgramada,
  }) async {
    final fecha = (fechaProgramada ?? DateTime.now()).toIso8601String().split('T')[0];
    await _db.from('cola_mensajes_wa').insert({
      'cliente_id'       : clienteId,
      'plantilla_id'     : plantillaId,
      'mensaje_final'    : mensajeFinal,
      'campana'          : campana,
      'fecha_programada' : fecha,
      'estado'           : 'pendiente',
    });
  }

  // Segmentos automáticos
  static Future<List<Cliente>> getClientesPorSegmento(String segmento) async {
    try {
      switch (segmento) {
        case 'activos':
          final res = await _db.from('clientes').select()
              .eq('tipo_cliente', 'Cliente activo').order('nombre');
          return (res as List).map((j) => Cliente.fromJson(j as Map<String, dynamic>)).toList();
        case 'potenciales':
          final res = await _db.from('clientes').select()
              .eq('tipo_cliente', 'Cliente potencial').order('nombre');
          return (res as List).map((j) => Cliente.fromJson(j as Map<String, dynamic>)).toList();
        case 'frecuentes':
          final res = await _db.from('clientes').select()
              .eq('tipo_cliente', 'Cliente frecuente').order('nombre');
          return (res as List).map((j) => Cliente.fromJson(j as Map<String, dynamic>)).toList();
        case 'cotizaciones_pendientes':
          // Clientes con cotizaciones enviadas sin respuesta
          final res = await _db.from('cotizaciones')
              .select('cliente_id, clientes(id, nombre, whatsapp, telefono, tipo_cliente)')
              .eq('estado', 'Enviada').order('created_at');
          final Set<String> seen = {};
          final List<Cliente> lista = [];
          for (final row in (res as List)) {
            final cl = row['clientes'];
            if (cl == null) continue;
            final id = cl['id'] as String? ?? '';
            if (seen.add(id)) {
              lista.add(Cliente(id: id, nombre: cl['nombre'] ?? '',
                whatsapp: cl['whatsapp'], telefono: cl['telefono'],
                tipoCliente: cl['tipo_cliente'] ?? ''));
            }
          }
          return lista;
        default:
          final res = await _db.from('clientes').select()
              .not('whatsapp', 'is', null).order('nombre').limit(50);
          return (res as List).map((j) => Cliente.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (_) { return []; }
  }

  // ═══════════════════════════════════════════
  // WHATSAPP BUSINESS API
  // ═══════════════════════════════════════════

  // Buscar cliente por número de WhatsApp
  static Future<Cliente?> getClientePorWA(String numero) async {
    try {
      // Normalizar número
      String n = numero.replaceAll(RegExp(r'[^0-9]'), '');
      if (n.length == 10) n = '521$n';
      else if (n.startsWith('52') && n.length == 12) n = '521${n.substring(2)}';

      final res = await _db.from('clientes')
          .select().eq('whatsapp', n).maybeSingle();
      if (res == null) return null;
      return Cliente.fromJson(res as Map<String, dynamic>);
    } catch (_) { return null; }
  }

  // Crear cliente rápido desde WhatsApp
  static Future<Cliente> crearClienteRapidoWA({
    required String numero,
    String? nombre,
  }) async {
    String n = numero.replaceAll(RegExp(r'[^0-9]'), '');
    if (n.length == 10) n = '521$n';
    else if (n.startsWith('52') && n.length == 12) n = '521${n.substring(2)}';

    final res = await _db.from('clientes').insert({
      'nombre'      : nombre ?? 'Contacto WA ${n.substring(n.length - 4)}',
      'whatsapp'    : n,
      'telefono'    : n,
      'tipo_cliente': 'Cliente potencial',
      'notas'       : 'Agregado desde WhatsApp',
    }).select().single();
    return Cliente.fromJson(res as Map<String, dynamic>);
  }

  // Obtener interacciones de WA de un cliente
  static Future<List<Map<String, dynamic>>> getInteraccionesWA(String clienteId) async {
    try {
      final res = await _db.from('interacciones_wa')
          .select().eq('cliente_id', clienteId)
          .order('created_at', ascending: false).limit(20);
      return (res as List).map((j) => j as Map<String, dynamic>).toList();
    } catch (_) { return []; }
  }

  // Alertas de nuevos contactos WA
  static Future<List<Map<String, dynamic>>> getAlertasNuevosContactosWA() async {
    try {
      final res = await _db.from('alertas')
          .select('*, clientes(nombre, whatsapp)')
          .eq('tipo', 'nuevo_contacto_wa')
          .eq('completada', false)
          .order('created_at', ascending: false);
      return (res as List).map((j) => j as Map<String, dynamic>).toList();
    } catch (_) { return []; }
  }

  // Configuración de WhatsApp
  static Future<Map<String, dynamic>?> getConfigWA() async {
    try {
      final res = await _db.from('config_whatsapp')
          .select().eq('activo', true).maybeSingle();
      return res as Map<String, dynamic>?;
    } catch (_) { return null; }
  }

  static Future<void> guardarConfigWA(Map<String, dynamic> datos) async {
    final existing = await _db.from('config_whatsapp').select().limit(1);
    if ((existing as List).isEmpty) {
      await _db.from('config_whatsapp').insert(datos);
    } else {
      await _db.from('config_whatsapp').update(datos).eq('activo', true);
    }
  }
}
