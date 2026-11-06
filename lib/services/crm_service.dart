// lib/services/crm_service.dart
// HETNA CNC — CRM con seguimiento.
//
// Lo que hace vender: a quién hay que hablarle HOY, en qué va cada cliente
// (embudo), por qué se perdió una cotización y clientes que dejaron de
// comprar. Tablas: supabase/crm_seguimiento.sql.
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'auth_service.dart';

class TareaSeguimiento {
  final String tipo; // 'cotizacion' | 'paso' | 'dormido'
  final Cliente cliente;
  final String titulo;
  final String detalle;
  final Cotizacion? cotizacion;
  final int dias; // días de atraso o sin contacto
  TareaSeguimiento({required this.tipo, required this.cliente, required this.titulo, required this.detalle, this.cotizacion, this.dias = 0});
}

class Embudo {
  final List<Cliente> potenciales; // sin cotización
  final List<Cotizacion> cotizados; // Enviada
  final List<Cotizacion> ganadas; // Aprobada / Pedido (90 días)
  final List<Cotizacion> perdidas; // Rechazada / Vencida (90 días)
  Embudo(this.potenciales, this.cotizados, this.ganadas, this.perdidas);
  double get tasaCierre => (ganadas.length + perdidas.length) == 0 ? 0 : ganadas.length * 100 / (ganadas.length + perdidas.length);
  Map<String, int> get motivos {
    final m = <String, int>{};
    for (final c in perdidas) {
      final k = c.motivoPerdida ?? 'sin_motivo';
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }
}

class ContactoCliente {
  final String tipo;
  final String? nota;
  final String? quien;
  final DateTime? fecha;
  ContactoCliente(this.tipo, this.nota, this.quien, this.fecha);
}

class CrmService {
  static SupabaseClient get _db => Supabase.instance.client;

  static const motivosPerdida = {
    'precio': 'Precio',
    'tiempo': 'Tiempo de entrega',
    'otro_proveedor': 'Se fue con otro taller',
    'sin_respuesta': 'Nunca respondió',
    'cancelo': 'Canceló el proyecto',
    'otro': 'Otro',
  };

  static const tiposContacto = {
    'whatsapp': 'WhatsApp',
    'llamada': 'Llamada',
    'visita': 'Visita',
    'correo': 'Correo',
    'otro': 'Otro',
  };

  /// Días sin comprar para considerar a un cliente "dormido".
  static const diasDormido = 120;

  static const _selCot = '*, clientes(*), cotizacion_items(*)';

  /// La lista de hoy, ordenada por urgencia.
  static Future<List<TareaSeguimiento>> hoy() async {
    final tareas = <TareaSeguimiento>[];
    final ahora = DateTime.now();
    // 1. Cotizaciones enviadas sin respuesta (3+ días)
    final limite = ahora.subtract(const Duration(days: 3)).toIso8601String();
    final cots = await _db.from('cotizaciones').select(_selCot)
        .eq('estado', 'Enviada').lte('updated_at', limite).order('updated_at');
    for (final j in (cots as List)) {
      final c = Cotizacion.fromJson(j as Map<String, dynamic>);
      if (c.cliente == null) continue;
      final dias = ahora.difference(c.updatedAt ?? c.createdAt ?? ahora).inDays;
      tareas.add(TareaSeguimiento(tipo: 'cotizacion', cliente: c.cliente!, cotizacion: c, dias: dias,
        titulo: 'Cotización ${c.folio ?? ''} sin respuesta', detalle: 'Enviada hace $dias días · \$${c.total.toStringAsFixed(0)}'));
    }
    // 2. Próximos pasos vencidos o de hoy
    final hoyTxt = ahora.toIso8601String().substring(0, 10);
    final pasos = await _db.from('clientes').select().eq('activo', true)
        .not('proximo_paso_fecha', 'is', null).lte('proximo_paso_fecha', hoyTxt).order('proximo_paso_fecha');
    for (final j in (pasos as List)) {
      final c = Cliente.fromJson(j as Map<String, dynamic>);
      final f = c.proximoPasoFecha;
      final dias = f == null ? 0 : ahora.difference(f).inDays;
      tareas.add(TareaSeguimiento(tipo: 'paso', cliente: c, dias: dias,
        titulo: c.proximoPaso ?? 'Siguiente paso', detalle: dias > 0 ? 'Venció hace $dias días' : 'Para hoy'));
    }
    // 3. Clientes dormidos: compraron y no regresan
    final corte = ahora.subtract(const Duration(days: diasDormido)).toIso8601String().substring(0, 10);
    final peds = await _db.from('pedidos').select('cliente_id, fecha_entregado, clientes(*)')
        .eq('estado', 'Entregado').order('fecha_entregado', ascending: false);
    final vistos = <String>{};
    final ultimo = <String, DateTime>{};
    final datos = <String, Cliente>{};
    for (final j in (peds as List)) {
      final m = j as Map<String, dynamic>;
      final id = m['cliente_id'] as String?;
      if (id == null || m['clientes'] == null) continue;
      final f = DateTime.tryParse(m['fecha_entregado']?.toString() ?? '');
      if (f == null) continue;
      if (!ultimo.containsKey(id) || f.isAfter(ultimo[id]!)) {
        ultimo[id] = f;
        datos[id] = Cliente.fromJson(m['clientes'] as Map<String, dynamic>);
      }
    }
    ultimo.forEach((id, f) {
      if (f.toIso8601String().substring(0, 10).compareTo(corte) > 0) return;
      final c = datos[id]!;
      // si ya le hablamos después de su último pedido, no está dormido
      if (c.ultimoContacto != null && c.ultimoContacto!.isAfter(f)) return;
      if (!vistos.add(id)) return;
      final dias = ahora.difference(f).inDays;
      tareas.add(TareaSeguimiento(tipo: 'dormido', cliente: c, dias: dias,
        titulo: 'No ha vuelto a comprar', detalle: 'Último pedido hace $dias días'));
    });
    tareas.sort((a, b) {
      const peso = {'paso': 0, 'cotizacion': 1, 'dormido': 2};
      final p = peso[a.tipo]!.compareTo(peso[b.tipo]!);
      return p != 0 ? p : b.dias.compareTo(a.dias);
    });
    return tareas;
  }

  static Future<Embudo> embudo() async {
    final hace90 = DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
    final cots = await _db.from('cotizaciones').select(_selCot).gte('created_at', hace90).order('created_at', ascending: false);
    final lista = (cots as List).map((j) => Cotizacion.fromJson(j as Map<String, dynamic>)).toList();
    final conCot = lista.map((c) => c.clienteId).whereType<String>().toSet();
    final clientes = await _db.from('clientes').select().eq('activo', true).order('created_at', ascending: false);
    final potenciales = (clientes as List).map((j) => Cliente.fromJson(j as Map<String, dynamic>))
        .where((c) => c.id != null && !conCot.contains(c.id)).toList();
    return Embudo(
      potenciales,
      lista.where((c) => c.estado == 'Enviada').toList(),
      lista.where((c) => c.estado == 'Aprobada' || c.estado == 'Pedido').toList(),
      lista.where((c) => c.estado == 'Rechazada' || c.estado == 'Vencida').toList(),
    );
  }

  static Future<void> registrarContacto(String clienteId, String tipo, String? nota) async {
    await _db.from('contactos_cliente').insert({
      'cliente_id': clienteId,
      'negocio_id': AuthService.negocioId,
      'tipo': tipo,
      'nota': (nota ?? '').trim().isEmpty ? null : nota!.trim(),
      'hecho_por_nombre': AuthService.nombreUsuario,
    });
  }

  static Future<List<ContactoCliente>> contactos(String clienteId) async {
    try {
      final r = await _db.from('contactos_cliente').select().eq('cliente_id', clienteId).order('created_at', ascending: false).limit(50);
      return (r as List).map((j) {
        final m = j as Map<String, dynamic>;
        return ContactoCliente((m['tipo'] ?? 'otro').toString(), m['nota'] as String?, m['hecho_por_nombre'] as String?,
          DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal());
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> guardarProximoPaso(String clienteId, String? paso, DateTime? fecha) async {
    await _db.from('clientes').update({
      'proximo_paso': (paso ?? '').trim().isEmpty ? null : paso!.trim(),
      'proximo_paso_fecha': fecha?.toIso8601String().substring(0, 10),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', clienteId);
  }

  static Future<void> perder(String cotizacionId, String motivo, String? nota) async {
    await _db.from('cotizaciones').update({
      'estado': 'Rechazada',
      'motivo_perdida': motivo,
      'nota_perdida': (nota ?? '').trim().isEmpty ? null : nota!.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', cotizacionId);
  }

  /// Importa clientes de una lista de filas (de Excel o CSV). Salta los que
  /// ya existen por WhatsApp/teléfono o por nombre+empresa.
  static Future<({int nuevos, int repetidos})> importar(List<Cliente> lista) async {
    final existentes = await _db.from('clientes').select('nombre, empresa, whatsapp, telefono').eq('activo', true);
    final llaves = <String>{};
    String tel(String? s) => (s ?? '').replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^52(1)?'), '');
    for (final j in (existentes as List)) {
      final m = j as Map<String, dynamic>;
      final t = tel(m['whatsapp'] as String?);
      final t2 = tel(m['telefono'] as String?);
      if (t.length >= 10) llaves.add('t:$t');
      if (t2.length >= 10) llaves.add('t:$t2');
      llaves.add('n:${(m['nombre'] ?? '').toString().trim().toLowerCase()}|${(m['empresa'] ?? '').toString().trim().toLowerCase()}');
    }
    int nuevos = 0, repetidos = 0;
    final filas = <Map<String, dynamic>>[];
    for (final c in lista) {
      final t = tel(c.whatsapp);
      final t2 = tel(c.telefono);
      final kn = 'n:${c.nombre.trim().toLowerCase()}|${(c.empresa ?? '').trim().toLowerCase()}';
      if ((t.length >= 10 && llaves.contains('t:$t')) || (t2.length >= 10 && llaves.contains('t:$t2')) || llaves.contains(kn)) {
        repetidos++;
        continue;
      }
      if (t.length >= 10) llaves.add('t:$t');
      llaves.add(kn);
      filas.add({...c.toJson(), if (AuthService.negocioId != null) 'negocio_id': AuthService.negocioId});
      nuevos++;
    }
    for (var i = 0; i < filas.length; i += 100) {
      await _db.from('clientes').insert(filas.sublist(i, i + 100 > filas.length ? filas.length : i + 100));
    }
    return (nuevos: nuevos, repetidos: repetidos);
  }
}
