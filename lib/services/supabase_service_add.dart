// AGREGAR estos métodos al final de supabase_service.dart (antes del último })

  // ═══════════════════════════════════════════
  // OBTENER ITEMS DE UNA COTIZACIÓN
  // ═══════════════════════════════════════════
  static Future<List<CotizacionItem>> getCotizacionItems(String cotizacionId) async {
    try {
      final res = await _db.from('cotizacion_items')
          .select()
          .eq('cotizacion_id', cotizacionId)
          .order('created_at');
      return (res as List).map((j) => CotizacionItem.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════
  // ACTUALIZAR COTIZACIÓN EXISTENTE
  // ═══════════════════════════════════════════
  static Future<void> actualizarCotizacion(
      Cotizacion cotizacion, List<CotizacionItem> items) async {
    // Actualizar datos de la cotización
    await _db.from('cotizaciones').update({
      'estado': cotizacion.estado,
      'descuento_pct': cotizacion.descuentoPct,
      'descuento_fijo': cotizacion.descuentoFijo,
      'iva_pct': cotizacion.ivaPct,
      'iva_monto': cotizacion.montoIva,
      'costo_envio': cotizacion.costoEnvio,
      'subtotal': cotizacion.subtotal,
      'total': cotizacion.total,
      'metodo_pago': cotizacion.metodoPago,
      'condicion_entrega': cotizacion.condicionEntrega,
      'fecha_entrega': cotizacion.fechaEntrega?.toIso8601String().split('T')[0],
      'notas': cotizacion.notas,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', cotizacion.id!);

    // Eliminar items anteriores y reinsertar
    await _db.from('cotizacion_items').delete().eq('cotizacion_id', cotizacion.id!);
    if (items.isNotEmpty) {
      await _db.from('cotizacion_items').insert(
        items.map((i) => i.toJson(cotizacion.id!)).toList());
    }
  }
