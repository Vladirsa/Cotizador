// lib/services/woocommerce_service.dart
// HETNA CNC — Sincronizar catálogo desde una tienda WooCommerce
//
// Funciona con CUALQUIER taller que tenga WooCommerce — no está
// atado a hetnacnc.com. Cada taller configura su propia URL y
// claves en Configuración.
//
// Cómo obtener las claves (cualquier usuario de WooCommerce):
// WordPress → WooCommerce → Ajustes → Avanzado → API REST →
// "Agregar clave" → Permisos: "Lectura" es suficiente.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';

class WooCommerceService {
  static final _sb = Supabase.instance.client;

  // URL de la función que recibe la autorización automática
  //
  // ⚠️ El slug real de la función desplegada es "clever-worker", NO
  // "woocommerce-callback". El dashboard de Supabase permite cambiar
  // el nombre VISUAL de una función sin cambiar la ruta real de
  // invocación — por eso en el dashboard se ve como
  // "woocommerce-callback" pero la URL sigue siendo /clever-worker.
  // Si en algún momento se vuelve a desplegar esta función con el
  // nombre correcto de carpeta (woocommerce-callback), hay que
  // actualizar esta constante de vuelta.
  //
  // ⚠️ TAMBIÉN VERIFICAR: confirma el Project URL exacto en
  // Supabase → Settings → API antes de compilar. El de abajo es el
  // que aparecía en el código original — solo lo dejé igual porque
  // aún no confirmas si el ID de proyecto es correcto.
  static const _callbackUrl =
    'https://ldfmkfbhcbsbecfbzsny.supabase.co/functions/v1/woocommerce-callback';

  // ── CONEXIÓN AUTOMÁTICA (sin copiar/pegar claves) ──────
  //
  // 1. Genera un código de un solo uso y lo guarda ligado a este taller
  // 2. Abre el navegador en la tienda del usuario, donde solo tiene
  //    que iniciar sesión y apretar "Aprobar"
  // 3. WooCommerce manda las claves directo a nuestra función, sin
  //    que el usuario las vea ni las copie
  static Future<String?> iniciarAutorizacion(String storeUrl) async {
    final negId = AuthService.negocioId;
    if (negId == null) return null;

    final urlLimpia = storeUrl.trim().replaceAll(RegExp(r'/$'), '');
    final token = const Uuid().v4();

    try {
      await _sb.from('woocommerce_auth_tokens').insert({
        'token': token,
        'negocio_id': negId,
        'store_url': urlLimpia,
      });
    } catch (e) {
      return null;
    }

    final authUrl = Uri.parse('$urlLimpia/wc-auth/v1/authorize').replace(
      queryParameters: {
        'app_name': 'HETNA CNC Cotizador',
        'scope': 'read',
        'user_id': token,
        'return_url': urlLimpia,
        'callback_url': _callbackUrl,
      });

    final abierto = await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    return abierto ? token : null;
  }

  // Revisa si el usuario ya aprobó la conexión (se llama cuando
  // regresa a la app y toca "Ya aprobé, verificar")
  static Future<bool> verificarAutorizacion(String token) async {
    try {
      final data = await _sb.from('woocommerce_auth_tokens')
        .select('usado').eq('token', token).maybeSingle();
      return data?['usado'] == true;
    } catch (_) {
      return false;
    }
  }

  // Trae la configuración guardada del taller actual
  static Future<Map<String, dynamic>?> obtenerConfig() async {
    final negId = AuthService.negocioId;
    if (negId == null) return null;
    try {
      final data = await _sb.from('configuracion_empresa')
        .select('woocommerce_url, woocommerce_consumer_key, woocommerce_consumer_secret')
        .eq('negocio_id', negId).limit(1);
      final list = data as List;
      if (list.isEmpty) return null;
      return list.first as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> guardarConfig({
    required String url,
    required String consumerKey,
    required String consumerSecret,
  }) async {
    final negId = AuthService.negocioId;
    if (negId == null) return 'Sin negocio activo';
    try {
      final urlLimpia = url.trim().replaceAll(RegExp(r'/$'), ''); // sin / al final
      final existing = await _sb.from('configuracion_empresa')
        .select('id').eq('negocio_id', negId).limit(1);
      final list = existing as List;
      final datos = {
        'woocommerce_url': urlLimpia,
        'woocommerce_consumer_key': consumerKey.trim(),
        'woocommerce_consumer_secret': consumerSecret.trim(),
      };
      if (list.isNotEmpty) {
        await _sb.from('configuracion_empresa').update(datos)
          .eq('id', (list.first as Map)['id']);
      } else {
        await _sb.from('configuracion_empresa').insert({...datos, 'negocio_id': negId});
      }
      return null;
    } catch (e) {
      return 'Error al guardar: $e';
    }
  }

  // Prueba la conexión sin sincronizar nada — solo confirma que
  // las claves funcionan (trae 1 producto de prueba)
  static Future<String?> probarConexion({
    required String url,
    required String consumerKey,
    required String consumerSecret,
  }) async {
    try {
      final urlLimpia = url.trim().replaceAll(RegExp(r'/$'), '');
      final uri = Uri.parse('$urlLimpia/wp-json/wc/v3/products').replace(
        queryParameters: {
          'consumer_key': consumerKey.trim(),
          'consumer_secret': consumerSecret.trim(),
          'per_page': '1',
        });
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return null; // sin error = conexión OK
      if (res.statusCode == 401) return 'Claves incorrectas — revisa el Consumer Key/Secret';
      return 'Error ${res.statusCode}: no se pudo conectar';
    } catch (e) {
      return 'No se pudo conectar: $e';
    }
  }

  // Trae TODOS los productos de WooCommerce y los guarda/actualiza
  // en tu catálogo interno. Devuelve un mensaje con el resultado.
  static Future<String> sincronizar({
    void Function(int traidos, int total)? onProgreso,
  }) async {
    final negId = AuthService.negocioId;
    if (negId == null) return 'Sin negocio activo';

    final config = await obtenerConfig();
    if (config == null || config['woocommerce_url'] == null ||
        (config['woocommerce_url'] as String).isEmpty) {
      return 'Primero configura tu tienda WooCommerce en Configuración';
    }

    final url = config['woocommerce_url'] as String;
    final key = config['woocommerce_consumer_key'] as String? ?? '';
    final secret = config['woocommerce_consumer_secret'] as String? ?? '';

    try {
      int pagina = 1;
      int totalSincronizados = 0;
      List<dynamic> categoriasCache = [];

      while (true) {
        final uri = Uri.parse('$url/wp-json/wc/v3/products').replace(
          queryParameters: {
            'consumer_key': key,
            'consumer_secret': secret,
            'per_page': '50',
            'page': '$pagina',
            'status': 'publish',
          });

        final res = await http.get(uri).timeout(const Duration(seconds: 30));
        if (res.statusCode != 200) {
          return 'Error al traer productos (código ${res.statusCode})';
        }

        final productos = jsonDecode(res.body) as List;
        if (productos.isEmpty) break; // ya no hay más páginas

        for (final p in productos) {
          await _guardarProducto(p as Map<String, dynamic>, negId);
          totalSincronizados++;
          onProgreso?.call(totalSincronizados, totalSincronizados);
        }

        if (productos.length < 50) break; // última página
        pagina++;
        if (pagina > 20) break; // límite de seguridad (1000 productos)
      }

      return '✅ $totalSincronizados productos sincronizados';
    } catch (e) {
      return 'Error al sincronizar: $e';
    }
  }

  // Guarda o actualiza UN producto de WooCommerce en tu catálogo
  static Future<void> _guardarProducto(Map<String, dynamic> p, String negId) async {
    try {
      final wooId = p['id'] as int?;
      if (wooId == null) return;

      final nombre = (p['name'] as String?)?.trim() ?? 'Producto sin nombre';
      final precioTexto = (p['price'] as String?) ?? '0';
      final precio = double.tryParse(precioTexto) ?? 0;
      final sku = p['sku'] as String?;

      // Categoría (WooCommerce trae una lista; tomamos la primera)
      String? categoriaNombre;
      final cats = p['categories'] as List?;
      if (cats != null && cats.isNotEmpty) {
        categoriaNombre = (cats.first as Map)['name'] as String?;
      }
      String? categoriaId;
      if (categoriaNombre != null) {
        categoriaId = await _obtenerOCrearCategoria(categoriaNombre, negId);
      }

      // Imagen principal (si tiene)
      String? imagenUrl;
      final imgs = p['images'] as List?;
      if (imgs != null && imgs.isNotEmpty) {
        imagenUrl = (imgs.first as Map)['src'] as String?;
      }

      final activo = (p['status'] as String?) == 'publish';
      final stock = (p['stock_quantity'] as num?)?.toInt() ?? 0;

      // ¿Ya existe este producto (por woocommerce_id)?
      final existente = await _sb.from('productos')
        .select('id')
        .eq('negocio_id', negId)
        .eq('woocommerce_id', wooId)
        .limit(1);
      final list = existente as List;

      final datos = {
        'negocio_id': negId,
        'nombre': nombre,
        'precio_venta': precio,
        'sku': sku,
        'categoria_id': categoriaId,
        'imagen_url': imagenUrl,
        'activo': activo,
        'stock_disponible': stock,
        'woocommerce_id': wooId,
        'unidad_medida': 'Pieza',
        'costo': 0,
      };

      if (list.isNotEmpty) {
        await _sb.from('productos').update(datos).eq('id', (list.first as Map)['id']);
      } else {
        await _sb.from('productos').insert(datos);
      }
    } catch (e) {
      print('Error guardando producto WooCommerce: $e');
    }
  }

  static Future<String?> _obtenerOCrearCategoria(String nombre, String negId) async {
    try {
      final existente = await _sb.from('categorias_producto')
        .select('id').eq('negocio_id', negId).eq('nombre', nombre).limit(1);
      final list = existente as List;
      if (list.isNotEmpty) return (list.first as Map)['id'] as String;

      final nueva = await _sb.from('categorias_producto')
        .insert({'negocio_id': negId, 'nombre': nombre}).select().single();
      return nueva['id'] as String;
    } catch (_) {
      return null;
    }
  }
}
