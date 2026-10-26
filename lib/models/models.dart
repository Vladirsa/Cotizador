// ============================================
// lib/models/models.dart
// ============================================

// ─── CLIENTE ────────────────────────────────
class Cliente {
  final String? id;
  final String nombre;
  final String? empresa;
  final String? rfc;
  final String? domicilio;
  final String? ciudad;
  final String? estado;
  final String? codigoPostal;
  final String? telefono;
  final String? whatsapp;
  final String? correo;
  final String tipoCliente;
  final String? notas;
  final DateTime? createdAt;

  Cliente({
    this.id,
    required this.nombre,
    this.empresa,
    this.rfc,
    this.domicilio,
    this.ciudad,
    this.estado,
    this.codigoPostal,
    this.telefono,
    this.whatsapp,
    this.correo,
    this.tipoCliente = 'Cliente potencial',
    this.notas,
    this.createdAt,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
        id: json['id'],
        nombre: json['nombre'] ?? '',
        empresa: json['empresa'],
        rfc: json['rfc'],
        domicilio: json['domicilio'],
        ciudad: json['ciudad'],
        estado: json['estado'],
        codigoPostal: json['codigo_postal'],
        telefono: json['telefono'],
        whatsapp: json['whatsapp'],
        correo: json['correo'],
        tipoCliente: json['tipo_cliente'] ?? 'Cliente potencial',
        notas: json['notas'],
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'nombre': nombre,
        'empresa': empresa,
        'rfc': rfc,
        'domicilio': domicilio,
        'ciudad': ciudad,
        'estado': estado,
        'codigo_postal': codigoPostal,
        'telefono': telefono,
        'whatsapp': whatsapp,
        'correo': correo,
        'tipo_cliente': tipoCliente,
        'notas': notas,
      };

  String get nombreCompleto =>
      empresa != null && empresa!.isNotEmpty ? '$nombre — $empresa' : nombre;

  String get whatsappNumero =>
      (whatsapp ?? telefono ?? '').replaceAll(RegExp(r'[^0-9]'), '');
}

// ─── CATEGORÍA DE PRODUCTO ──────────────────
class CategoriaProducto {
  final String? id;
  final String nombre;
  final String colorHex;
  final String icono;

  CategoriaProducto({
    this.id,
    required this.nombre,
    this.colorHex = '#185fa5',
    this.icono = 'box',
  });

  factory CategoriaProducto.fromJson(Map<String, dynamic> json) =>
      CategoriaProducto(
        id: json['id'],
        nombre: json['nombre'],
        colorHex: json['color_hex'] ?? '#185fa5',
        icono: json['icono'] ?? 'box',
      );
}

// ─── PRODUCTO ────────────────────────────────
class Producto {
  final String? id;
  final String? sku;
  final String nombre;
  final String? descripcion;
  final String? categoriaId;
  final String? categoriaNombre;
  final String? marca;
  final double costo;
  final double precioVenta;
  final double? precioDistribuidor;
  final bool aplicaIva;
  final String unidadMedida;
  final int stockDisponible;
  final int stockMinimo;
  final String? imagenUrl;
  final String? pdfUrl;
  final String? ubicacionFisica;
  final bool activo;

  Producto({
    this.id,
    this.sku,
    required this.nombre,
    this.descripcion,
    this.categoriaId,
    this.categoriaNombre,
    this.marca,
    this.costo = 0,
    required this.precioVenta,
    this.precioDistribuidor,
    this.aplicaIva = true,
    this.unidadMedida = 'Pieza',
    this.stockDisponible = 0,
    this.stockMinimo = 1,
    this.imagenUrl,
    this.pdfUrl,
    this.ubicacionFisica,
    this.activo = true,
  });

  factory Producto.fromJson(Map<String, dynamic> json) => Producto(
        id: json['id'],
        sku: json['sku'],
        nombre: json['nombre'],
        descripcion: json['descripcion'],
        categoriaId: json['categoria_id'],
        categoriaNombre: json['categorias_producto']?['nombre'],
        marca: json['marca'],
        costo: (json['costo'] ?? 0).toDouble(),
        precioVenta: (json['precio_venta'] ?? 0).toDouble(),
        precioDistribuidor: json['precio_distribuidor']?.toDouble(),
        aplicaIva: json['aplica_iva'] ?? true,
        unidadMedida: json['unidad_medida'] ?? 'Pieza',
        stockDisponible: json['stock_disponible'] ?? 0,
        stockMinimo: json['stock_minimo'] ?? 1,
        imagenUrl: json['imagen_url'],
        pdfUrl: json['pdf_url'],
        ubicacionFisica: json['ubicacion_fisica'],
        activo: json['activo'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'sku': sku,
        'nombre': nombre,
        'descripcion': descripcion,
        'categoria_id': categoriaId,
        'marca': marca,
        'costo': costo,
        'precio_venta': precioVenta,
        'precio_distribuidor': precioDistribuidor,
        'aplica_iva': aplicaIva,
        'unidad_medida': unidadMedida,
        'stock_disponible': stockDisponible,
        'stock_minimo': stockMinimo,
        'imagen_url': imagenUrl,
        'pdf_url': pdfUrl,
        'activo': activo,
      };

  bool get stockBajo => stockDisponible <= stockMinimo;
}

// ─── ITEM DE COTIZACIÓN ──────────────────────
class CotizacionItem {
  final String? id;
  final String? productoId;
  String nombreProducto;
  String? descripcion;
  final String? sku;
  int cantidad;
  double precioUnitario;
  double descuentoItemPct;

  CotizacionItem({
    this.id,
    this.productoId,
    required this.nombreProducto,
    this.descripcion,
    this.sku,
    this.cantidad = 1,
    required this.precioUnitario,
    this.descuentoItemPct = 0,
  });

  double get subtotal {
    final base = cantidad * precioUnitario;
    return base - (base * descuentoItemPct / 100);
  }

  factory CotizacionItem.fromProducto(Producto p) => CotizacionItem(
        productoId: p.id,
        nombreProducto: p.nombre,
        descripcion: p.descripcion,
        sku: p.sku,
        precioUnitario: p.precioVenta,
      );

  factory CotizacionItem.fromJson(Map<String, dynamic> json) => CotizacionItem(
        id: json['id'],
        productoId: json['producto_id'],
        nombreProducto: json['nombre_producto'] ?? '',
        descripcion: json['descripcion'],
        sku: json['sku'],
        cantidad: json['cantidad'] ?? 1,
        precioUnitario: (json['precio_unitario'] ?? 0).toDouble(),
        descuentoItemPct: (json['descuento_item_pct'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson(String cotizacionId) => {
        if (id != null) 'id': id,
        'cotizacion_id': cotizacionId,
        'producto_id': productoId,
        'nombre_producto': nombreProducto,
        'descripcion': descripcion,
        'sku': sku,
        'cantidad': cantidad,
        'precio_unitario': precioUnitario,
        'descuento_item_pct': descuentoItemPct,
        'subtotal': subtotal,
      };
}

// ─── COTIZACIÓN ──────────────────────────────
class Cotizacion {
  final String? id;
  final String? folio;
  final Cliente? cliente;
  final String? clienteId;
  String estado;
  List<CotizacionItem> items;
  double descuentoPct;
  double descuentoFijo;
  double ivaPct;
  double costoEnvio;
  String? metodoPago;
  String? condicionEntrega;
  DateTime? fechaEntrega;
  int? diasHabiles;
  int vigenciaDias;
  String? notas;
  String? pdfUrl;
  final DateTime? createdAt;
  final double? totalBd; // total guardado en BD
  // 'sencilla' (la de siempre) o 'profesional' (formato internacional).
  String tipo;
  // Datos técnicos de la cotización profesional (proyecto, alcance,
  // material, tolerancias, proceso, calidad...). Vacío en la sencilla.
  Map<String, dynamic> datosPro;

  bool get esProfesional => tipo == 'profesional';

  Cotizacion({
    this.id,
    this.folio,
    this.cliente,
    this.clienteId,
    this.estado = 'Borrador',
    this.items = const [],
    this.descuentoPct = 0,
    this.descuentoFijo = 0,
    this.ivaPct = 16,
    this.costoEnvio = 0,
    this.metodoPago,
    this.condicionEntrega,
    this.fechaEntrega,
    this.diasHabiles,
    this.vigenciaDias = 7,
    this.notas,
    this.pdfUrl,
    this.createdAt,
    this.totalBd,
    this.tipo = 'sencilla',
    Map<String, dynamic>? datosPro,
  }) : datosPro = datosPro ?? {};

  // La misma cotización con sus partidas cargadas (conserva tipo y datos técnicos)
  Cotizacion copiaConItems(List<CotizacionItem> nuevos) => Cotizacion(
    id: id, folio: folio, cliente: cliente, clienteId: clienteId,
    estado: estado, items: nuevos,
    descuentoPct: descuentoPct, descuentoFijo: descuentoFijo,
    ivaPct: ivaPct, costoEnvio: costoEnvio,
    metodoPago: metodoPago, condicionEntrega: condicionEntrega,
    fechaEntrega: fechaEntrega, diasHabiles: diasHabiles,
    vigenciaDias: vigenciaDias, notas: notas,
    pdfUrl: pdfUrl, createdAt: createdAt, totalBd: totalBd,
    tipo: tipo, datosPro: datosPro);

  double get subtotal => items.fold(0, (s, i) => s + i.subtotal);
  double get montoDescuento => (subtotal * descuentoPct / 100) + descuentoFijo;
  double get baseIva => subtotal - montoDescuento;
  double get montoIva => baseIva * ivaPct / 100;
  // Si hay items los calculamos; si no, usamos el total guardado en BD
  double get total => items.isNotEmpty
      ? baseIva + montoIva + costoEnvio
      : (totalBd ?? 0);

  factory Cotizacion.fromJson(Map<String, dynamic> json) {
    // Parsear cliente del join
    Cliente? clienteObj;
    if (json['clientes'] != null && json['clientes'] is Map) {
      final cl = json['clientes'] as Map<String, dynamic>;
      clienteObj = Cliente(
        id: json['cliente_id'],
        nombre: cl['nombre'] ?? '',
        whatsapp: cl['whatsapp'],
        empresa: cl['empresa'],
        tipoCliente: 'Cliente activo',
      );
    }
    // Parsear items
    List<CotizacionItem> itemsList = [];
    if (json['cotizacion_items'] != null) {
      itemsList = (json['cotizacion_items'] as List)
          .map((i) => CotizacionItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }
    return Cotizacion(
      id: json['id'],
      folio: json['folio'],
      clienteId: json['cliente_id'],
      cliente: clienteObj,
      estado: json['estado'] ?? 'Borrador',
      descuentoPct: (json['descuento_pct'] as num?)?.toDouble() ?? 0,
      descuentoFijo: (json['descuento_fijo'] as num?)?.toDouble() ?? 0,
      ivaPct: (json['iva_pct'] as num?)?.toDouble() ?? 16,
      costoEnvio: (json['costo_envio'] as num?)?.toDouble() ?? 0,
      metodoPago: json['metodo_pago'],
      condicionEntrega: json['condicion_entrega'],
      fechaEntrega: json['fecha_entrega'] != null
          ? DateTime.tryParse(json['fecha_entrega']) : null,
      diasHabiles: json['dias_habiles'],
      vigenciaDias: json['vigencia_dias'] ?? 7,
      notas: json['notas'],
      pdfUrl: json['pdf_url'],
      items: itemsList,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) : null,
      totalBd: (json['total'] as num?)?.toDouble(),
      tipo: (json['tipo'] as String?) ?? 'sencilla',
      datosPro: json['datos_pro'] is Map
          ? Map<String, dynamic>.from(json['datos_pro'] as Map) : null,
    );
  }
}

// ─── PEDIDO ──────────────────────────────────
class Pedido {
  final String? id;
  final String folio;
  final String? cotizacionId;
  final String? clienteId;
  final Cliente? cliente;
  String estado;
  final double? total;
  DateTime? fechaEntregaEstimada;
  DateTime? fechaEntregado;
  String? notasInternas;
  bool redesEnviadas;
  bool cuponSeguidorEnviado;
  final DateTime? createdAt;

  Pedido({
    this.id,
    required this.folio,
    this.cotizacionId,
    this.clienteId,
    this.cliente,
    this.estado = 'Pedido',
    this.total,
    this.fechaEntregaEstimada,
    this.fechaEntregado,
    this.notasInternas,
    this.redesEnviadas = false,
    this.cuponSeguidorEnviado = false,
    this.createdAt,
  });

  int get porcentajeAvance {
    const etapas = ['Pedido','Pago','Produccion','Pruebas','Entrega','Entregado'];
    final idx = etapas.indexOf(estado);
    return idx < 0 ? 0 : ((idx + 1) * 100 ~/ etapas.length);
  }

  factory Pedido.fromJson(Map<String, dynamic> json) {
    Cliente? clienteObj;
    if (json['clientes'] != null && json['clientes'] is Map) {
      final cl = json['clientes'] as Map<String, dynamic>;
      clienteObj = Cliente(
        id: json['cliente_id'],
        nombre: cl['nombre'] ?? '',
        whatsapp: cl['whatsapp'],
        empresa: cl['empresa'],
        tipoCliente: 'Cliente activo',
      );
    }
    return Pedido(
      id: json['id'],
      folio: json['folio'] ?? '',
      cotizacionId: json['cotizacion_id'],
      clienteId: json['cliente_id'],
      cliente: clienteObj,
      estado: json['estado'] ?? 'Pedido',
      total: (json['total'] as num?)?.toDouble(),
      fechaEntregaEstimada: json['fecha_entrega_estimada'] != null
          ? DateTime.tryParse(json['fecha_entrega_estimada']) : null,
      fechaEntregado: json['fecha_entregado'] != null
          ? DateTime.tryParse(json['fecha_entregado']) : null,
      notasInternas: json['notas_internas'],
      redesEnviadas: json['redes_enviadas'] ?? false,
      cuponSeguidorEnviado: json['cupon_seguidor_enviado'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}

// ─── ALERTA ──────────────────────────────────
class Alerta {
  final String? id;
  final String tipo;
  final String titulo;
  final String? mensajeWa;
  final String? clienteNombre;
  final String? clienteEmpresa;
  final String? clienteWhatsapp;
  final String? cotizacionFolio;
  final double? cotizacionTotal;
  final DateTime? fechaProgramada;
  bool completada;

  Alerta({
    this.id,
    required this.tipo,
    required this.titulo,
    this.mensajeWa,
    this.clienteNombre,
    this.clienteEmpresa,
    this.clienteWhatsapp,
    this.cotizacionFolio,
    this.cotizacionTotal,
    this.fechaProgramada,
    this.completada = false,
  });

  factory Alerta.fromJson(Map<String, dynamic> json) => Alerta(
        id: json['id'],
        tipo: json['tipo'] ?? 'default',
        titulo: json['titulo'] ?? '',
        mensajeWa: json['mensaje_wa'],
        clienteNombre: json['cliente_nombre'],
        clienteEmpresa: json['cliente_empresa'],
        clienteWhatsapp: json['cliente_whatsapp'],
        cotizacionFolio: json['cotizacion_folio'],
        cotizacionTotal: (json['cotizacion_total'] as num?)?.toDouble(),
        fechaProgramada: json['fecha_programada'] != null
            ? DateTime.tryParse(json['fecha_programada']) : null,
        completada: json['completada'] ?? false,
      );
}

// ─── PDF CATÁLOGO ────────────────────────────
class PdfCatalogo {
  final String? id;
  final String nombre;
  final String? descripcion;
  final String url;
  final double? tamanoMb;
  final String? categoria;
  final DateTime? createdAt;

  PdfCatalogo({
    this.id,
    required this.nombre,
    this.descripcion,
    required this.url,
    this.tamanoMb,
    this.categoria,
    this.createdAt,
  });

  factory PdfCatalogo.fromJson(Map<String, dynamic> json) => PdfCatalogo(
        id: json['id'],
        nombre: json['nombre'],
        descripcion: json['descripcion'],
        url: json['url'],
        tamanoMb: json['tamano_mb']?.toDouble(),
        categoria: json['categoria'],
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at']) : null,
      );

  String get tamanoTexto =>
      tamanoMb != null ? '${tamanoMb!.toStringAsFixed(1)} MB' : '';
}


// ─── GASTO (con campos fiscales SAT) ─────────
class Gasto {
  final String? id;
  final String concepto;
  final double monto;
  final String categoria;
  final String tipo; // directo | indirecto
  final String? proveedor;
  final DateTime? fecha;

  // Campos fiscales SAT
  final bool tieneFactura;
  final String? rfcProveedor;
  final String? folioFactura;
  final double ivaFactura;     // IVA real de la factura
  final bool esDeducible;
  final String tipoGastoSat;  // materiales, servicios, renta, etc.
  final String? comprobanteUrl;

  final DateTime? createdAt;

  Gasto({
    this.id,
    required this.concepto,
    required this.monto,
    required this.categoria,
    this.tipo = 'directo',
    this.proveedor,
    this.fecha,
    this.tieneFactura = false,
    this.rfcProveedor,
    this.folioFactura,
    this.ivaFactura = 0,
    this.esDeducible = true,
    this.tipoGastoSat = 'materiales',
    this.comprobanteUrl,
    this.createdAt,
  });

  // Monto sin IVA (base)
  double get montoBase => tieneFactura && ivaFactura > 0
    ? monto - ivaFactura : monto;

  // IVA acreditable (solo si tiene factura y es deducible)
  double get ivaAcreditable => (tieneFactura && esDeducible)
    ? ivaFactura : 0;

  factory Gasto.fromJson(Map<String, dynamic> j) => Gasto(
    id: j['id'],
    concepto: j['concepto'] ?? '',
    monto: (j['monto'] as num?)?.toDouble() ?? 0,
    categoria: j['categoria'] ?? 'otros',
    tipo: j['tipo'] ?? 'directo',
    proveedor: j['proveedor'],
    fecha: j['fecha'] != null ? DateTime.tryParse(j['fecha']) : null,
    tieneFactura: j['tiene_factura'] ?? false,
    rfcProveedor: j['rfc_proveedor'],
    folioFactura: j['folio_factura'],
    ivaFactura: (j['iva_factura'] as num?)?.toDouble() ?? 0,
    esDeducible: j['es_deducible'] ?? true,
    tipoGastoSat: j['tipo_gasto_sat'] ?? 'materiales',
    comprobanteUrl: j['comprobante_url'],
    createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'concepto': concepto,
    'monto': monto,
    'categoria': categoria,
    'tipo': tipo,
    'proveedor': proveedor,
    'fecha': fecha?.toIso8601String().substring(0, 10),
    'tiene_factura': tieneFactura,
    'rfc_proveedor': rfcProveedor,
    'folio_factura': folioFactura,
    'iva_factura': ivaFactura,
    'es_deducible': esDeducible,
    'tipo_gasto_sat': tipoGastoSat,
    'comprobante_url': comprobanteUrl,
  };

  static const tiposGastoSat = [
    'materiales',
    'servicios',
    'renta',
    'equipo',
    'transporte',
    'publicidad',
    'telefonia',
    'nomina',
    'otros',
  ];

  static const etiquetasTipoSat = {
    'materiales':  'Materiales y suministros',
    'servicios':   'Servicios profesionales',
    'renta':       'Renta y arrendamiento',
    'equipo':      'Equipo y herramientas',
    'transporte':  'Transporte y fletes',
    'publicidad':  'Publicidad y marketing',
    'telefonia':   'Telefonía e internet',
    'nomina':      'Nómina y honorarios',
    'otros':       'Otros gastos',
  };
}

// ─── HISTORIAL DE CLIENTE ─────────────────────
class HistorialCliente {
  final List<Cotizacion> cotizaciones;
  final List<Pedido> pedidos;

  HistorialCliente({
    required this.cotizaciones,
    required this.pedidos,
  });

  double get totalCotizado => cotizaciones.fold(0, (s, c) => s + c.total);
  double get totalPedidos => pedidos.fold(0, (s, p) => s + (p.total ?? 0));
  double get totalEntregado => pedidos
    .where((p) => p.estado == 'Entregado')
    .fold(0, (s, p) => s + (p.total ?? 0));
  int get pedidosActivos => pedidos
    .where((p) => p.estado != 'Entregado').length;
}
