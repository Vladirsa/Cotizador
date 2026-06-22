// lib/services/notificaciones_service.dart
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';

class NotificacionesService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inicializado = false;

  static Future<void> inicializar() async {
    if (_inicializado) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    _inicializado = true;
  }

  static Future<void> nuevaCotizacion({
    required String nombreCliente,
    required double total,
    String? folio,
  }) async {
    await _vibrar();
    await _mostrar(
      id: 1,
      titulo: '🎉 Nueva cotización — $nombreCliente',
      cuerpo: folio != null ? '$folio · \$${total.toStringAsFixed(0)}' : '\$${total.toStringAsFixed(0)}',
      canal: 'cotizaciones', nombreCanal: 'Cotizaciones');
  }

  static Future<void> nuevoPedido({
    required String nombreCliente,
    required double total,
    String? folio,
  }) async {
    await _vibrar(fuerte: true);
    await _mostrar(
      id: 2,
      titulo: '📦 Nuevo pedido confirmado',
      cuerpo: '$nombreCliente — \$${total.toStringAsFixed(0)}',
      canal: 'pedidos', nombreCanal: 'Pedidos');
  }

  static Future<void> alertaSeguimiento({
    required String nombreCliente,
    required String tipo,
    String? folio,
  }) async {
    await _vibrar();
    final titulos = {
      'seguimiento_dia3': '⏰ Seguimiento día 3',
      'seguimiento_dia5': '🔴 Seguimiento día 5 — Urgente',
      'seguimiento_dia7': '⚠️ Último aviso — Día 7',
      'post_entrega'    : '✅ Recordatorio post entrega',
    };
    await _mostrar(
      id: 3,
      titulo: titulos[tipo] ?? '📋 Alerta de seguimiento',
      cuerpo: 'Cliente: $nombreCliente${folio != null ? " · $folio" : ""}',
      canal: 'alertas', nombreCanal: 'Alertas de seguimiento');
  }

  static Future<void> _vibrar({bool fuerte = false}) async {
    try {
      if (fuerte) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 200));
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 200));
        await HapticFeedback.heavyImpact();
      } else {
        await HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 150));
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }

  static Future<void> _mostrar({
    required int id,
    required String titulo,
    required String cuerpo,
    required String canal,
    required String nombreCanal,
  }) async {
    if (!_inicializado) await inicializar();
    final androidDetails = AndroidNotificationDetails(
      canal, nombreCanal,
      channelDescription: 'Notificaciones HETNA CNC',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
      icon: '@mipmap/ic_launcher',
    );
    await _plugin.show(id, titulo, cuerpo, NotificationDetails(android: androidDetails));
  }

  static Future<void> probar() async {
    await _vibrar(fuerte: true);
    await _mostrar(
      id: 99,
      titulo: '✅ HETNA CNC — Notificaciones activas',
      cuerpo: 'Las alertas y pedidos te llegarán aquí 🔔',
      canal: 'alertas', nombreCanal: 'Alertas de seguimiento');
  }
}
