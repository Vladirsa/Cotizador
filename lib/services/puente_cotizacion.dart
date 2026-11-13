// lib/services/puente_cotizacion.dart
// HETNA CNC — Lleva lo calculado en el simulador a la cotización que está
// abierta en la pestaña Cotizar, en lugar de abrir una cotización nueva.
//
// La cotización de la pestaña se registra al abrirse; el inicio registra cómo
// cambiar a esa pestaña. El simulador llama a enviar(): si hay cotización
// abierta, deja las partidas, avisa y cambia de pestaña.
import 'package:flutter/foundation.dart';

class PuenteCotizacion {
  PuenteCotizacion._();
  static final ValueNotifier<int> cambios = ValueNotifier(0);
  static final List<Object> _pendientes = [];
  static int _abiertas = 0;
  static VoidCallback? irACotizacion; // lo pone la pantalla de inicio

  static void registrarCotizacion() => _abiertas++;
  static void quitarCotizacion() { if (_abiertas > 0) _abiertas--; }
  static bool get hayCotizacionAbierta => _abiertas > 0;

  /// true si las partidas se mandaron a la cotización abierta.
  static bool enviar(List<Object> partidas) {
    if (!hayCotizacionAbierta || partidas.isEmpty) return false;
    _pendientes.addAll(partidas);
    cambios.value++;
    irACotizacion?.call();
    return true;
  }

  static List<Object> tomar() {
    final l = List<Object>.of(_pendientes);
    _pendientes.clear();
    return l;
  }
}
