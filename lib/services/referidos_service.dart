// Referidos: cada taller tiene su código y su liga
//   https://hetnacnc.com/cotizador/?ref=CODIGO
// El invitado que completa su arranque gana 1 mes y se lo gana también a
// quien lo invitó (supabase/referidos.sql). Los códigos de distribuidor
// (tabla codigos_promo) usan la misma puerta: aplicar_referido().
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReferidosService {
  static const _clave = 'hetna_ref_pendiente';
  static const base = 'https://hetnacnc.com/cotizador/';
  static String? _codigo;

  // Mi código (si ya se cargó). Lo usa el pie de los mensajes de WhatsApp.
  static String? get codigo => _codigo;
  static String liga([String? cod]) {
    final c = cod ?? _codigo;
    return c == null || c.isEmpty ? base : '$base?ref=$c';
  }

  // Al abrir la web con ?ref=XXXX se guarda el código: el registro pasa por
  // la tienda y regresa, y para entonces la liga ya no trae el parámetro.
  static Future<void> capturarDeLaLiga() async {
    if (!kIsWeb) return;
    try {
      final ref = (Uri.base.queryParameters['ref'] ?? '').trim().toUpperCase();
      if (!RegExp(r'^[A-Z0-9]{4,24}$').hasMatch(ref)) return;
      final p = await SharedPreferences.getInstance();
      await p.setString(_clave, ref);
    } catch (_) {}
  }

  // Ya con sesión: si quedó un código guardado, se aplica una sola vez.
  // Devuelve el mensaje para mostrar, o null si no había nada que hacer.
  static Future<String?> aplicarPendiente() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ref = p.getString(_clave);
      if (ref == null || ref.isEmpty) return null;
      await p.remove(_clave);
      final r = await aplicar(ref);
      return r['ok'] == true ? r['mensaje'] as String? : null; // si no aplica (taller viejo, código propio…) no se molesta
    } catch (_) { return null; }
  }

  static Future<Map<String, dynamic>> aplicar(String codigo) async {
    final r = await Supabase.instance.client.rpc('aplicar_referido', params: {'p_codigo': codigo.trim().toUpperCase()});
    return r is Map ? Map<String, dynamic>.from(r) : {'ok': false, 'mensaje': 'Sin respuesta'};
  }

  // { codigo, invitados, completaron, meses_a_favor, ya_referido, puede_aplicar }
  static Future<Map<String, dynamic>?> miCodigo() async {
    try {
      final r = await Supabase.instance.client.rpc('mi_codigo_referido');
      if (r is! Map || r['error'] != null) return null;
      final d = Map<String, dynamic>.from(r);
      _codigo = d['codigo'] as String?;
      return d;
    } catch (_) { return null; } // SQL sin correr
  }
}
