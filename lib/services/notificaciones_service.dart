// lib/services/notificaciones_service.dart
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class NotificacionesService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inicializado = false;
  static int _badgeCount = 0;

  static RealtimeChannel? _canalAlertas;
  static RealtimeChannel? _canalPedidos;

  static SupabaseClient get _db => Supabase.instance.client;

  // ─── INICIALIZAR ─────────────────────────
  static Future<void> inicializar() async {
    if (_inicializado) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    // Canales Android con alta prioridad
    const androidPlugin = AndroidFlutterLocalNotificationsPlugin();
    await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
      'cotizaciones', 'Cotizaciones',
      description: 'Nuevas cotizaciones recibidas',
      importance: Importance.high, playSound: true, enableVibration: true));
    await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
      'pedidos', 'Pedidos',
      description: 'Nuevos pedidos confirmados',
      importance: Importance.max, playSound: true, enableVibration: true));
    await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
      'alertas', 'Alertas de seguimiento',
      description: 'Recordatorios y seguimientos',
      importance: Importance.high, playSound: true, enableVibration: true));

    _inicializado = true;
  }

  // ─── REALTIME SUPABASE ────────────────────
  static void iniciarEscuchaRealtime() {
    _escucharNuevasCotizacionesWeb();
    _escucharCambiosPedidos();
  }

  static void _escucharNuevasCotizacionesWeb() {
    _canalAlertas?.unsubscribe();
    _canalAlertas = _db.channel('cotizaciones_web')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'cotizaciones',
        callback: (payload) async {
          final data = payload.newRecord;
          final fuente = data['fuente'] as String? ?? '';
          if (fuente == 'web' || fuente == 'woocommerce') {
            final total = (data['total'] as num?)?.toDouble() ?? 0;
            final folio = data['folio'] as String?;
            await nuevaCotizacion(
              nombreCliente: 'Pedido Web 🌐',
              total: total,
              folio: folio);
          }
        })
      .subscribe();
  }

  static void _escucharCambiosPedidos() {
    _canalPedidos?.unsubscribe();
    _canalPedidos = _db.channel('pedidos_cambios')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'pedidos',
        callback: (payload) async {
          final nuevo = payload.newRecord;
          final viejo = payload.oldRecord;
          final estadoNuevo = nuevo['estado'] as String? ?? '';
          final estadoViejo = viejo['estado'] as String? ?? '';
          if (estadoNuevo != estadoViejo &&
              (estadoNuevo == 'PagoCompleto' || estadoNuevo == 'Entregado')) {
            await _vibrar(fuerte: true);
            await _mostrar(
              id: 10,
              titulo: estadoNuevo == 'PagoCompleto'
                ? '💰 Pago completo recibido'
                : '✅ Pedido entregado',
              cuerpo: 'Pedido ${nuevo['folio'] ?? ''} — $estadoNuevo',
              canal: 'pedidos',
              nombreCanal: 'Pedidos');
          }
        })
      .subscribe();
  }

  static void detenerEscucha() {
    _canalAlertas?.unsubscribe();
    _canalPedidos?.unsubscribe();
    _canalAlertas = null;
    _canalPedidos = null;
  }

  // ─── BADGE (contador manual sin plugin externo) ───
  static int get badgeCount => _badgeCount;

  static void actualizarBadgeLocal(int n) {
    _badgeCount = n;
  }

  // ─── NOTIFICACIONES ──────────────────────
  static Future<void> nuevaCotizacion({
    required String nombreCliente,
    required double total,
    String? folio,
  }) async {
    await _vibrar();
    _badgeCount++;
    await _mostrar(
      id: 1,
      titulo: '🎉 Nueva cotización — $nombreCliente',
      cuerpo: folio != null
        ? '$folio · \$${total.toStringAsFixed(0)}'
        : '\$${total.toStringAsFixed(0)}',
      canal: 'cotizaciones',
      nombreCanal: 'Cotizaciones');
  }

  static Future<void> nuevoPedido({
    required String nombreCliente,
    required double total,
    String? folio,
  }) async {
    await _vibrar(fuerte: true);
    _badgeCount++;
    await _mostrar(
      id: 2,
      titulo: '📦 Nuevo pedido confirmado',
      cuerpo: '$nombreCliente — \$${total.toStringAsFixed(0)}',
      canal: 'pedidos',
      nombreCanal: 'Pedidos');
  }

  static Future<void> alertaSeguimiento({
    required String nombreCliente,
    required String tipo,
    String? folio,
  }) async {
    await _vibrar();
    _badgeCount++;
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
      canal: 'alertas',
      nombreCanal: 'Alertas de seguimiento');
  }

  // ─── VIBRAR ──────────────────────────────
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

  // ─── MOSTRAR NOTIFICACIÓN ────────────────
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
      vibrationPattern: Int64List.fromList([0, 300, 200, 300, 200, 300]),
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(cuerpo),
    );
    await _plugin.show(id, titulo, cuerpo, NotificationDetails(android: androidDetails));
  }

  // ─── PROBAR ──────────────────────────────
  static Future<void> probar() async {
    await _vibrar(fuerte: true);
    await _mostrar(
      id: 99,
      titulo: '✅ HETNA CNC — Notificaciones activas',
      cuerpo: 'Las alertas, pedidos y seguimientos te llegarán aquí 🔔',
      canal: 'alertas',
      nombreCanal: 'Alertas de seguimiento');
  }
}
