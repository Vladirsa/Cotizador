// lib/services/hetna_api.dart
// HETNA CNC — Conexión de la app con hetnacnc.com
//
// - Calculadora CNC: mismo motor que el Copiloto de la web (/api/app/calculadora)
// - Envíos HETNA: cotización con todas las paqueterías, margen incluido (/api/app/envios)
// - Enlaces del ecosistema: tienda, foro, laboratorio CAM, licitaciones
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../i18n/tr.dart';

class HetnaApi {
  static const base = 'https://hetnacnc.com';
  static const _region = 'mx';
  static const whatsappHetna = '522461217072';

  // ── Enlaces del ecosistema ──
  static const urlTienda       = '$base/$_region';
  static const urlForo         = '$base/$_region/foro-cnc';
  static const urlLaboratorio  = '$base/$_region/cam';
  static const urlLicitaciones = '$base/$_region/cotizar';
  static const urlEnviosWeb    = '$base/$_region/servicios/envios-hetna';
  static const urlPlanes       = '$base/$_region/servicios/cotizador-cnc#planes';
  static const urlTalleres     = '$base/$_region/talleres';

  static const _timeout = Duration(seconds: 25);

  static Map<String, dynamic> _leer(http.Response r) {
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      return d is Map<String, dynamic> ? d : {};
    } catch (_) {
      return {};
    }
  }

  static String _error(Map<String, dynamic> d, String porDefecto) =>
    (d['message'] as String?)?.trim().isNotEmpty == true ? d['message'] as String : porDefecto;

  // ═══════════════ Calculadora CNC ═══════════════
  static List<CalcDef>? _cache;

  static Future<List<CalcDef>> calculadoras() async {
    if (_cache != null) return _cache!;
    final r = await http.get(Uri.parse('$base/api/app/calculadora')).timeout(_timeout);
    final d = _leer(r);
    if (r.statusCode != 200) throw HetnaError(_error(d, tr('No se pudo cargar la calculadora.')));
    _cache = ((d['calculadoras'] as List?) ?? [])
      .map((j) => CalcDef.fromJson(j as Map<String, dynamic>)).toList();
    return _cache!;
  }

  static Future<CalcResultado> calcular(String id, Map<String, dynamic> entrada) async {
    final r = await http.post(Uri.parse('$base/api/app/calculadora'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': id, 'entrada': entrada})).timeout(_timeout);
    final d = _leer(r);
    if (r.statusCode != 200) throw HetnaError(_error(d, tr('No se pudo calcular.')));
    return CalcResultado.fromJson((d['resultado'] as Map<String, dynamic>?) ?? {});
  }

  // ═══════════════ Envíos HETNA ═══════════════
  static Future<InfoCP> codigoPostal(String cp) async {
    final r = await http.get(Uri.parse('$base/api/app/envios?cp=$cp')).timeout(_timeout);
    final d = _leer(r);
    if (r.statusCode != 200) throw HetnaError(_error(d, tr('No encontramos ese código postal.')));
    return InfoCP.fromJson(d);
  }

  static Future<CotizacionEnvio> cotizarEnvio({
    required String cpOrigen, required String coloniaOrigen,
    required String cpDestino, required String coloniaDestino,
    required String tipo, required double peso,
    required double largo, required double ancho, required double alto,
  }) async {
    final r = await http.post(Uri.parse('$base/api/app/envios'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cp_origen': cpOrigen, 'colonia_origen': coloniaOrigen,
        'cp_destino': cpDestino, 'colonia_destino': coloniaDestino,
        'tipo': tipo, 'peso': peso, 'largo': largo, 'ancho': ancho, 'alto': alto,
      })).timeout(_timeout);
    final d = _leer(r);
    if (r.statusCode != 200) throw HetnaError(_error(d, tr('No pudimos cotizar el envío.')));
    return CotizacionEnvio.fromJson(d);
  }

  // Liga para que el cliente (o el taller) compre la guía en la web con la
  // cotización ya hecha.
  static String urlSolicitarEnvio(String cotizacionId, String tarifaId) =>
    '$base/$_region/servicios/envios-hetna/solicitar?c=${Uri.encodeComponent(cotizacionId)}&t=${Uri.encodeComponent(tarifaId)}';
}

// ═══════════════ Suscripción con Mercado Pago o PayPal ═══════════════
// El backend de hetnacnc.com crea la suscripción y, cuando Mercado Pago o
// PayPal confirman el pago, cambia el plan del taller. La app sólo abre el enlace.
class SuscripcionApi {
  static const _ruta = '${HetnaApi.base}/api/cotizador-suscripcion';

  static Future<Map<String, dynamic>> _post(String ruta, String token, [Map<String, dynamic>? cuerpo]) async {
    final r = await http.post(Uri.parse(ruta),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(cuerpo ?? {})).timeout(const Duration(seconds: 30));
    Map<String, dynamic> d = {};
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map<String, dynamic>) d = j;
    } catch (_) {}
    if (r.statusCode != 200) {
      throw HetnaError((d['error'] ?? d['message'] ?? tr('No se pudo completar. Intenta de nuevo.')).toString());
    }
    return d;
  }

  /// Precios (MXN con Mercado Pago, USD con PayPal) y qué formas de pago están activas:
  /// { planes: { taller: { mxn, usd }, ... }, mercadopago: bool, paypal: bool }
  static Future<Map<String, dynamic>> precios() async {
    final r = await http.get(Uri.parse(_ruta)).timeout(const Duration(seconds: 15));
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode != 200 || j is! Map<String, dynamic>) throw HetnaError(tr('No se pudieron cargar los precios.'));
    return j;
  }

  /// Devuelve el enlace para pagar el plan.
  /// proveedor: 'mercadopago' (México, MXN) o 'paypal' (USD).
  static Future<String> crear(String token, String plan, String correoPago, {String proveedor = 'mercadopago'}) async {
    final d = await _post(_ruta, token, {'plan': plan, 'correo_pago': correoPago, 'proveedor': proveedor});
    final url = d['url'] as String?;
    if (url == null || url.isEmpty) {
      throw HetnaError(trf('{0} no devolvió el enlace de pago.', [(proveedor == 'paypal' ? tr('PayPal') : tr('Mercado Pago'))]));
    }
    return url;
  }

  /// Revisa en Mercado Pago si ya se pagó y actualiza el plan del taller.
  static Future<Map<String, dynamic>> verificar(String token) => _post('$_ruta/verificar', token);

  /// Cancela la suscripción; el plan sigue hasta el fin del periodo pagado.
  static Future<Map<String, dynamic>> cancelar(String token) => _post('$_ruta/cancelar', token);

  /// Vincula este taller con la cuenta de hetnacnc.com con el código de 6
  /// dígitos que se saca en hetnacnc.com → Mi cuenta. Devuelve { ok, taller }.
  static Future<Map<String, dynamic>> vincular(String token, String codigo) =>
    _post('$_ruta/vincular', token, {'codigo': codigo});
}

class HetnaError implements Exception {
  final String mensaje;
  HetnaError(this.mensaje);
  @override
  String toString() => mensaje;
}

// ── Modelos de la calculadora (mismo formato que lib/copiloto/motor.ts) ──
class CalcOpcion {
  final String v, t;
  CalcOpcion(this.v, this.t);
}

class CalcCampo {
  final String k, etiqueta, tipo;
  final String? unidad, ayuda;
  final bool req;
  final double? min, max;
  final List<CalcOpcion> opciones;
  CalcCampo({required this.k, required this.etiqueta, required this.tipo,
    this.unidad, this.ayuda, this.req = false, this.min, this.max, this.opciones = const []});
  factory CalcCampo.fromJson(Map<String, dynamic> j) => CalcCampo(
    k: j['k'] as String, etiqueta: j['etiqueta'] as String, tipo: j['tipo'] as String? ?? 'numero',
    unidad: j['unidad'] as String?, ayuda: j['ayuda'] as String?, req: j['req'] == true,
    min: (j['min'] as num?)?.toDouble(), max: (j['max'] as num?)?.toDouble(),
    opciones: ((j['opciones'] as List?) ?? [])
      .map((o) => CalcOpcion(o['v'] as String, o['t'] as String)).toList());
}

class CalcDef {
  final String id, nombre, maquina, resumen;
  final List<CalcCampo> campos;
  CalcDef({required this.id, required this.nombre, required this.maquina, required this.resumen, required this.campos});
  factory CalcDef.fromJson(Map<String, dynamic> j) => CalcDef(
    id: j['id'] as String, nombre: j['nombre'] as String, maquina: j['maquina'] as String? ?? '',
    resumen: j['resumen'] as String? ?? '',
    campos: ((j['campos'] as List?) ?? []).map((c) => CalcCampo.fromJson(c as Map<String, dynamic>)).toList());
}

class CalcFila {
  final String etiqueta, valor;
  final String? nota;
  CalcFila(this.etiqueta, this.valor, this.nota);
}

class CalcResultado {
  final String titulo;
  final List<CalcFila> filas;
  final List<String> avisos, faltan, supuestos;
  final Map<String, dynamic> datos;
  CalcResultado({required this.titulo, required this.filas, required this.avisos,
    required this.faltan, required this.supuestos, required this.datos});
  factory CalcResultado.fromJson(Map<String, dynamic> j) {
    List<String> l(String k) => ((j[k] as List?) ?? []).map((e) => e.toString()).toList();
    return CalcResultado(
      titulo: j['titulo'] as String? ?? '',
      filas: ((j['filas'] as List?) ?? []).map((f) =>
        CalcFila(f['etiqueta'].toString(), f['valor'].toString(), f['nota'] as String?)).toList(),
      avisos: l('avisos'), faltan: l('faltan'), supuestos: l('supuestos'),
      datos: (j['datos'] as Map<String, dynamic>?) ?? {});
  }
}

// ── Modelos de envíos ──
class InfoCP {
  final String cp, estado, municipio;
  final List<String> colonias;
  InfoCP({required this.cp, required this.estado, required this.municipio, required this.colonias});
  factory InfoCP.fromJson(Map<String, dynamic> j) => InfoCP(
    cp: j['cp']?.toString() ?? '', estado: j['estado'] as String? ?? '',
    municipio: j['municipio'] as String? ?? '',
    colonias: ((j['colonias'] as List?) ?? []).map((c) => c['nombre'].toString()).toList());
}

class OpcionEnvio {
  final String tarifaId, paqueteria, servicio;
  final int? dias;
  final double precio;
  final bool recoleccion, entregaDomicilio;
  OpcionEnvio({required this.tarifaId, required this.paqueteria, required this.servicio,
    this.dias, required this.precio, this.recoleccion = false, this.entregaDomicilio = true});
  factory OpcionEnvio.fromJson(Map<String, dynamic> j) => OpcionEnvio(
    tarifaId: j['tarifa_id'].toString(), paqueteria: j['paqueteria']?.toString() ?? '',
    servicio: j['servicio']?.toString() ?? '', dias: (j['dias'] as num?)?.toInt(),
    precio: (j['precio'] as num?)?.toDouble() ?? 0, recoleccion: j['recoleccion'] == true,
    entregaDomicilio: j['entrega_domicilio'] != false);
}

class CotizacionEnvio {
  final String? id;
  final List<OpcionEnvio> opciones;
  final double? pesoCobrado;
  final String? aviso;
  CotizacionEnvio({this.id, required this.opciones, this.pesoCobrado, this.aviso});
  factory CotizacionEnvio.fromJson(Map<String, dynamic> j) => CotizacionEnvio(
    id: j['cotizacion_id'] as String?,
    opciones: ((j['opciones'] as List?) ?? []).map((o) => OpcionEnvio.fromJson(o as Map<String, dynamic>)).toList(),
    pesoCobrado: (j['peso_cobrado'] as num?)?.toDouble(),
    aviso: j['message'] as String?);
}
