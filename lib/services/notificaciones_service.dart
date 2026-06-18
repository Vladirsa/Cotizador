// ============================================
// lib/services/notificaciones_service.dart
// Alertas push locales en Android
// ============================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificacionesService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inicializado = false;

  static Future<void> inicializar() async {
    if (_inicializado) return;
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        // Navegar a la pantalla de alertas cuando toca la notificación
      },
    );

    // Crear canal de notificaciones
    const canal = AndroidNotificationChannel(
      'hetna_cnc_alertas',
      'Alertas HETNA CNC',
      description: 'Seguimientos de cotizaciones y pedidos',
      importance: Importance.high,
      playSound: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(canal);

    _inicializado = true;
  }

  // ─── PROGRAMAR ALERTA DÍA 3 ─────────────────
  static Future<void> programarSeguimientoDia3({
    required int id,
    required String clienteNombre,
    required String folio,
    required DateTime fechaEnvio,
  }) async {
    await _programar(
      id: id * 100 + 3,
      titulo: '📋 Seguimiento cotización',
      cuerpo: '$clienteNombre — $folio · 3 días sin respuesta',
      fecha: fechaEnvio.add(const Duration(days: 3)),
    );
  }

  // ─── PROGRAMAR ALERTA DÍA 5 ─────────────────
  static Future<void> programarSeguimientoDia5({
    required int id,
    required String clienteNombre,
    required String folio,
    required DateTime fechaEnvio,
  }) async {
    await _programar(
      id: id * 100 + 5,
      titulo: '⚠️ Cotización por vencer',
      cuerpo: '$clienteNombre — $folio · Envía mensaje urgente',
      fecha: fechaEnvio.add(const Duration(days: 5)),
    );
  }

  // ─── PROGRAMAR CUPÓN DÍA 7 ──────────────────
  static Future<void> programarCuponDia7({
    required int id,
    required String clienteNombre,
    required String folio,
    required DateTime fechaEnvio,
  }) async {
    await _programar(
      id: id * 100 + 7,
      titulo: '🎟 Envía cupón de cierre',
      cuerpo: '$clienteNombre — $folio · Descuento especial disponible',
      fecha: fechaEnvio.add(const Duration(days: 7)),
    );
  }

  // ─── ALERTA INMEDIATA (AVANCE DE PEDIDO) ────
  static Future<void> alertaAvancePedido({
    required String folio,
    required String etapa,
    required String clienteNombre,
  }) async {
    await _mostrarInmediata(
      titulo: '🚀 Notifica avance a tu cliente',
      cuerpo: '$folio · $etapa → $clienteNombre',
    );
  }

  // ─── ALERTA POST-ENTREGA ─────────────────────
  static Future<void> alertaPostEntrega({
    required String folio,
    required String clienteNombre,
  }) async {
    await _mostrarInmediata(
      titulo: '🎉 Envía redes sociales',
      cuerpo: '$folio entregado · Manda tus redes a $clienteNombre',
    );
  }

  // ─── FUNCIONES BASE ──────────────────────────
  static Future<void> _programar({
    required int id,
    required String titulo,
    required String cuerpo,
    required DateTime fecha,
  }) async {
    final tzFecha = tz.TZDateTime.from(fecha, tz.local);
    if (tzFecha.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id,
      titulo,
      cuerpo,
      tzFecha,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'hetna_cnc_alertas',
          'Alertas HETNA CNC',
          channelDescription: 'Seguimientos de cotizaciones y pedidos',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> _mostrarInmediata({
    required String titulo,
    required String cuerpo,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.hashCode,
      titulo,
      cuerpo,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'hetna_cnc_alertas',
          'Alertas HETNA CNC',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> cancelarAlertas(int cotizacionId) async {
    await _plugin.cancel(cotizacionId * 100 + 3);
    await _plugin.cancel(cotizacionId * 100 + 5);
    await _plugin.cancel(cotizacionId * 100 + 7);
  }
}
