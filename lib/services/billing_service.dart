// lib/services/billing_service.dart
// HETNA CNC — Google Play Billing (suscripción Premium)
//
// ⚠️ IMPORTANTE — antes de que esto funcione de verdad necesitas:
// 1. Tener la app subida a Google Play Console (mínimo Prueba interna)
// 2. Crear ahí un producto de SUSCRIPCIÓN con el ID exacto que pongas
//    abajo en `idProductoPremium` (ej. "hetna_premium_mensual")
// 3. Publicar el producto (aunque sea en modo prueba)
//
// Sin esos 3 pasos, `queryProductDetails` no va a encontrar el
// producto y el botón de comprar no hará nada — es normal, no es
// un bug, es que Google todavía no sabe que ese producto existe.

import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import '../i18n/tr.dart';

class BillingService {
  // 👉 Cambia esto por el ID real que configures en Play Console
  static const String idProductoPremium = 'hetna_premium_mensual';

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static ProductDetails? productoPremium;
  static bool disponible = false;

  static void Function(String mensaje)? onError;
  static void Function()? onCompraExitosa;

  // Llamar una vez al iniciar la app (ej. en main.dart, sin bloquear
  // el arranque — usar sin "await" o dentro de un try/catch)
  static Future<void> inicializar() async {
    // Google Play Billing solo existe en Android — en Web/iOS no aplica
    if (!Platform.isAndroid) return;

    try {
      disponible = await _iap.isAvailable();
      if (!disponible) return;

      _subscription = _iap.purchaseStream.listen(
        _procesarCompras,
        onError: (e) => onError?.call(trf('Error de compra: {0}', [e])),
      );

      final respuesta = await _iap.queryProductDetails({idProductoPremium});
      if (respuesta.notFoundIDs.isNotEmpty) {
        print('BillingService: producto no encontrado en Play Console: '
          '${respuesta.notFoundIDs} — revisa que ya lo hayas creado y publicado.');
      }
      if (respuesta.productDetails.isNotEmpty) {
        productoPremium = respuesta.productDetails.first;
      }
    } catch (e) {
      print('BillingService.inicializar error: $e');
    }
  }

  // Iniciar el flujo de compra (abre el diálogo nativo de Google Play)
  static Future<void> comprarPremium() async {
    if (!disponible || productoPremium == null) {
      onError?.call(tr('La suscripción todavía no está disponible. Intenta más tarde.'));
      return;
    }
    final param = PurchaseParam(productDetails: productoPremium!);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  // Restaurar compras (para cuando alguien reinstala la app o cambia
  // de teléfono, pero ya había pagado antes)
  static Future<void> restaurarCompras() async {
    if (!disponible) return;
    await _iap.restorePurchases();
  }

  static Future<void> _procesarCompras(List<PurchaseDetails> compras) async {
    for (final compra in compras) {
      if (compra.status == PurchaseStatus.pending) {
        continue; // esperando confirmación del usuario/Google
      }

      if (compra.status == PurchaseStatus.error) {
        onError?.call(compra.error?.message ?? tr('Error al procesar la compra'));
      }

      if (compra.status == PurchaseStatus.purchased ||
          compra.status == PurchaseStatus.restored) {
        // ⚠️ NOTA DE SEGURIDAD: esto actualiza el plan confiando en
        // el resultado local del teléfono. Para producción real (con
        // dinero de verdad), lo correcto es verificar el "purchaseToken"
        // contra la API de Google Play desde el servidor (una Supabase
        // Edge Function) antes de dar acceso — así nadie puede fingir
        // una compra. Por ahora, para probar el flujo, se actualiza
        // directo. Avísame cuando quieras que blindemos esta parte.
        await _activarPremium();
        onCompraExitosa?.call();
      }

      if (compra.pendingCompletePurchase) {
        await _iap.completePurchase(compra);
      }
    }
  }

  static Future<void> _activarPremium() async {
    final negId = AuthService.negocioId;
    if (negId == null) return;
    try {
      await Supabase.instance.client.from('negocios').update({
        'plan': 'premium',
      }).eq('id', negId);
      await AuthService.refrescarPerfil();
    } catch (e) {
      print('BillingService: error activando premium: $e');
    }
  }

  static void dispose() {
    _subscription?.cancel();
  }
}
