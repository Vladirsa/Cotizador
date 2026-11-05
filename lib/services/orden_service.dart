// lib/services/orden_service.dart
// HETNA CNC — Orden de trabajo con QR.
//
// Cada pedido tiene un QR que se imprime en su hoja de orden y viaja con la
// pieza por el taller. Quien la tenga en la mano lo escanea con la app y ve
// cómo va el pedido; según su rol, la avanza:
//
//   Operador CNC     → "Empezar maquinado", "Maquinado terminado",
//                      "Pasó calidad" o "Regresar a maquinado"
//   Almacén y envíos → captura la guía y marca "Entregado"
//   Vendedor/Contador→ "Pago 100% recibido"
//   Administrador    → todo
//
// Cada movimiento queda en pedido_avances con quién lo hizo (columnas de
// supabase/orden_qr.sql). La liga del cliente (hetnacnc.com/c/<token>) lee el
// mismo pedido, así que se actualiza sola con la etapa y la guía.
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'auth_service.dart';

class PartidaOrden {
  final String nombre;
  final String? descripcion;
  final int cantidad;
  PartidaOrden(this.nombre, this.descripcion, this.cantidad);
}

class AvanceOrden {
  final String etapa;
  final String? descripcion;
  final String? quien;
  final String? rol;
  final DateTime? fecha;
  AvanceOrden(this.etapa, this.descripcion, this.quien, this.rol, this.fecha);
}

class OrdenDetalle {
  final Pedido pedido;
  final List<PartidaOrden> partidas;
  final List<AvanceOrden> avances;
  OrdenDetalle(this.pedido, this.partidas, this.avances);
}

/// Lo que un rol puede hacer con la orden en la etapa en que está.
class AccionOrden {
  final String id;
  final String etiqueta;
  final String? etapa; // a qué etapa la mueve (null = sólo captura datos)
  final bool pideGuia;
  final bool advertencia; // acción de regreso (se pinta en rojo)
  const AccionOrden(this.id, this.etiqueta, this.etapa, {this.pideGuia = false, this.advertencia = false});
}

class OrdenService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Lo que lleva el QR: la dirección de la orden en la app web. Con la
  /// cámara del teléfono abre la app; con el lector de la app, la orden.
  static const base = 'https://hetnacnc.com/cotizador/orden/';
  static String contenidoQr(String pedidoId) => '$base$pedidoId';

  static final _uuid = RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');

  /// Saca el id del pedido de lo que leyó la cámara (la dirección completa o
  /// sólo el id). null si no es un QR de orden.
  static String? pedidoIdDe(String? leido) {
    if (leido == null) return null;
    final m = _uuid.firstMatch(leido);
    return m?.group(0)?.toLowerCase();
  }

  static const etiquetas = {
    'Pedido': 'Pedido recibido',
    'Pago': 'Anticipo recibido',
    'Pago50': 'Anticipo recibido',
    'Produccion': 'En maquinado',
    'Pruebas': 'Control de calidad',
    'PagoCompleto': 'Pago 100% recibido',
    'Entrega': 'Listo para entrega',
    'Entregado': 'Entregado',
    'Cancelado': 'Cancelado',
  };

  static String etiqueta(String etapa) => etiquetas[etapa] ?? etapa;

  static String rolLegible(String? rol) {
    switch (rol) {
      case 'super_admin': return 'Super Admin';
      case 'administrador': return 'Administrador';
      case 'vendedor': return 'Vendedor';
      case 'operador_cnc': return 'Operador CNC';
      case 'almacenista': return 'Almacén y envíos';
      case 'contador': return 'Contador';
      default: return rol ?? '';
    }
  }

  static bool _rol(List<String> roles) => AuthService.esAdmin || roles.contains(AuthService.rol);

  /// Botones que ve este usuario para esta orden.
  static List<AccionOrden> accionesPara(Pedido p) {
    final e = p.estado;
    final antesDeMaquinar = e == 'Pedido' || e == 'Pago' || e == 'Pago50';
    final acciones = <AccionOrden>[];
    if (e == 'Entregado' || e == 'Cancelado') return acciones;
    // Taller (operador CNC)
    if (_rol(['operador_cnc'])) {
      if (antesDeMaquinar) acciones.add(const AccionOrden('empezar', 'Empezar maquinado', 'Produccion'));
      if (antesDeMaquinar || e == 'Produccion') acciones.add(const AccionOrden('maquinado', 'Maquinado terminado', 'Pruebas'));
      if (e == 'Pruebas') {
        acciones.add(const AccionOrden('calidad', 'Pasó calidad: listo para entregar', 'Entrega'));
        acciones.add(const AccionOrden('regresar', 'No pasó: regresar a maquinado', 'Produccion', advertencia: true));
      }
    }
    // Cobranza
    if (_rol(['vendedor', 'contador']) && (antesDeMaquinar || e == 'Produccion' || e == 'Pruebas')) {
      acciones.add(const AccionOrden('pagado', 'Pago 100% recibido', 'PagoCompleto'));
    }
    // Almacén y envíos
    if (_rol(['almacenista', 'vendedor'])) {
      if (e == 'Pruebas' || e == 'PagoCompleto' || e == 'Entrega') {
        acciones.add(AccionOrden('guia', (p.guia ?? '').isEmpty ? 'Capturar guía de envío' : 'Cambiar guía de envío', e == 'Entrega' ? null : 'Entrega', pideGuia: true));
      }
      if (e == 'Entrega' || e == 'PagoCompleto') acciones.add(const AccionOrden('entregado', 'Entregado al cliente', 'Entregado'));
    }
    // Sin duplicados (el admin cumple varios roles a la vez)
    final vistos = <String>{};
    return acciones.where((a) => vistos.add(a.id)).toList();
  }

  /// La orden con sus partidas e historial. null si no existe o no es de
  /// este taller (las reglas de seguridad de Supabase no la dejan ver).
  static Future<OrdenDetalle?> cargar(String pedidoId) async {
    final r = await _db.from('pedidos')
        .select('*, clientes(nombre, empresa, whatsapp)')
        .eq('id', pedidoId).maybeSingle();
    if (r == null) return null;
    final pedido = Pedido.fromJson(r);
    final partidas = <PartidaOrden>[];
    if (pedido.cotizacionId != null) {
      try {
        final items = await _db.from('cotizacion_items')
            .select('nombre_producto, descripcion, cantidad')
            .eq('cotizacion_id', pedido.cotizacionId!);
        for (final i in (items as List)) {
          final m = i as Map<String, dynamic>;
          partidas.add(PartidaOrden((m['nombre_producto'] ?? '').toString(), m['descripcion'] as String?,
            (m['cantidad'] as num?)?.toInt() ?? 1));
        }
      } catch (_) {}
    }
    final avances = <AvanceOrden>[];
    try {
      final h = await _db.from('pedido_avances').select()
          .eq('pedido_id', pedidoId).order('created_at', ascending: false).limit(40);
      for (final a in (h as List)) {
        final m = a as Map<String, dynamic>;
        avances.add(AvanceOrden((m['etapa'] ?? '').toString(), m['descripcion'] as String?,
          m['hecho_por_nombre'] as String?, m['rol'] as String?,
          m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString())?.toLocal() : null));
      }
    } catch (_) {}
    return OrdenDetalle(pedido, partidas, avances);
  }

  /// Mueve la orden de etapa y deja el registro de quién lo hizo.
  static Future<void> mover(String pedidoId, String etapa, {String? nota}) async {
    final cambios = <String, dynamic>{
      'estado': etapa,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (etapa == 'Entregado') cambios['fecha_entregado'] = DateTime.now().toIso8601String().substring(0, 10);
    await _db.from('pedidos').update(cambios).eq('id', pedidoId);
    await registrar(pedidoId, etapa, nota);
  }

  static Future<void> registrar(String pedidoId, String etapa, String? nota) async {
    final base = {
      'pedido_id': pedidoId,
      'etapa': etapa,
      'descripcion': (nota ?? '').trim().isEmpty ? null : nota!.trim(),
    };
    try {
      await _db.from('pedido_avances').insert({
        ...base,
        'hecho_por': AuthService.usuarioActual?.id,
        'hecho_por_nombre': AuthService.nombreUsuario,
        'rol': AuthService.rol,
      });
    } on PostgrestException {
      // Si todavía no se corre supabase/orden_qr.sql, se guarda sin "quién"
      await _db.from('pedido_avances').insert(base);
    }
  }
}
