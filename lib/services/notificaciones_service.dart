// lib/services/notificaciones_service.dart
// HETNA CNC — Notificaciones locales con polling automático
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';
import '../i18n/tr.dart';

class NotificacionesService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inicializado = false;

  // ── Estado interno para polling ──
  static Timer? _timer;
  static final Set<String> _alertasNotificadas = {};
  static int _contadorAlertas = 0;

  // ── Callback para que home_screen actualice el badge en NavigationBar ──
  static void Function(int count)? onBadgeUpdate;

  // ════════════════════════════════════════
  // INICIALIZAR
  // ════════════════════════════════════════
  static Future<void> inicializar() async {
    if (_inicializado) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificacionTocada,
    );
    _inicializado = true;

    // Solicitar permiso en Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ════════════════════════════════════════
  // POLLING AUTOMÁTICO — revisar alertas cada 5 min
  // ════════════════════════════════════════
  static void iniciarPolling() {
    _timer?.cancel();
    // Verificar inmediatamente al iniciar
    _verificarAlertas();
    // Luego cada 5 minutos
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _verificarAlertas());
  }

  static void detenerPolling() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _verificarAlertas() async {
    try {
      final alertas = await SupabaseService.getAlertasPendientes();
      final nuevas = alertas.where((a) =>
        a.id != null && !_alertasNotificadas.contains(a.id)).toList();

      for (final alerta in nuevas) {
        _alertasNotificadas.add(alerta.id!);

        // Solo notificar alertas vencidas o próximas (fecha <= ahora + 30 min)
        final ahora = DateTime.now();
        final limite = ahora.add(const Duration(minutes: 30));
        if (alerta.fechaProgramada != null &&
            alerta.fechaProgramada!.isAfter(limite)) continue;

        final nombre = alerta.clienteNombre ?? '';
        final tipo = alerta.tipo;

        if (tipo.startsWith('seguimiento')) {
          await alertaSeguimiento(
            nombreCliente: nombre,
            tipo: tipo,
            folio: alerta.cotizacionFolio);
        } else if (tipo.startsWith('pago')) {
          await alertaPago(
            nombreCliente: nombre,
            tipo: tipo);
        } else if (tipo == 'recordatorio_cita') {
          await alertaCita(nombreCliente: nombre);
        } else {
          await _mostrar(
            id: _idDesdeAlerta(alerta.id!),
            titulo: alerta.titulo ?? tr('🔔 Alerta HETNA CNC'),
            cuerpo: nombre.isNotEmpty ? 'Cliente: $nombre' : tr('Tienes una alerta pendiente'),
            canal: 'alertas',
            nombreCanal: tr('Alertas generales'));
        }
      }

      // Actualizar badge con total de alertas pendientes
      _contadorAlertas = alertas.length;
      onBadgeUpdate?.call(_contadorAlertas);

    } catch (e) {
      print('NotificacionesService._verificarAlertas error: $e');
    }
  }

  /// Convierte un UUID en un int estable para usar como notification ID
  static int _idDesdeAlerta(String id) {
    return id.hashCode.abs() % 100000;
  }

  static void _onNotificacionTocada(NotificationResponse response) {
    // Aquí se puede navegar a AlertasScreen cuando se toque la notificación
    // Por ahora solo registramos
    print('Notificación tocada: ${response.payload}');
  }

  // ════════════════════════════════════════
  // OBTENER CONTADOR (para badge manual)
  // ════════════════════════════════════════
  static int get contadorAlertas => _contadorAlertas;

  static Future<int> refrescarContador() async {
    try {
      final alertas = await SupabaseService.getAlertasPendientes();
      _contadorAlertas = alertas.length;
      onBadgeUpdate?.call(_contadorAlertas);
      return _contadorAlertas;
    } catch (_) {
      return _contadorAlertas;
    }
  }

  // ════════════════════════════════════════
  // NOTIFICACIONES ESPECÍFICAS
  // ════════════════════════════════════════

  static Future<void> nuevaCotizacion({
    required String nombreCliente,
    required double total,
    String? folio,
  }) async {
    await _vibrar();
    await _mostrar(
      id: 1,
      titulo: trf('🎉 Nueva cotización — {0}', [nombreCliente]),
      cuerpo: folio != null
          ? '$folio · \$${total.toStringAsFixed(0)}'
          : '\$${total.toStringAsFixed(0)}',
      canal: 'cotizaciones',
      nombreCanal: tr('Cotizaciones'));
  }

  static Future<void> nuevoPedido({
    required String nombreCliente,
    required double total,
    String? folio,
  }) async {
    await _vibrar(fuerte: true);
    await _mostrar(
      id: 2,
      titulo: tr('📦 Nuevo pedido confirmado'),
      cuerpo: '$nombreCliente — \$${total.toStringAsFixed(0)}',
      canal: 'pedidos',
      nombreCanal: tr('Pedidos'));
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
      titulo: titulos[tipo] ?? tr('📋 Alerta de seguimiento'),
      cuerpo: 'Cliente: $nombreCliente${folio != null ? " · $folio" : ""}',
      canal: 'alertas',
      nombreCanal: tr('Alertas de seguimiento'));
  }

  static Future<void> alertaPago({
    required String nombreCliente,
    required String tipo,
    String? folio,
  }) async {
    await _vibrar(fuerte: true);
    final titulos = {
      'pago_anticipo_pendiente': '💰 Anticipo pendiente',
      'pago_final_pendiente'   : '💰 Pago final pendiente',
    };
    await _mostrar(
      id: 4,
      titulo: titulos[tipo] ?? tr('💰 Alerta de pago'),
      cuerpo: 'Cliente: $nombreCliente${folio != null ? " · $folio" : ""}',
      canal: 'pagos',
      nombreCanal: tr('Alertas de pago'));
  }

  static Future<void> alertaCita({
    required String nombreCliente,
    String? hora,
  }) async {
    await _vibrar();
    await _mostrar(
      id: 5,
      titulo: tr('📅 Cita próxima'),
      cuerpo: trf('Con {0}{1}', [nombreCliente, (hora != null ? trf(' a las {0}', [hora]) : "")]),
      canal: 'citas',
      nombreCanal: tr('Recordatorios de cita'));
  }

  static Future<void> cambioPedido({
    required String nombreCliente,
    required String nuevoEstado,
    String? folio,
  }) async {
    await _vibrar();
    final emojis = {
      'Pago50'      : '💵',
      'Produccion'  : '🔧',
      'Pruebas'     : '🔍',
      'PagoCompleto': '✅',
      'Entrega'     : '🚚',
      'Entregado'   : '🎉',
    };
    final emoji = emojis[nuevoEstado] ?? '📋';
    await _mostrar(
      id: 6,
      titulo: trf('{0} Pedido avanzó — {1}', [emoji, nuevoEstado]),
      cuerpo: '$nombreCliente${folio != null ? " · $folio" : ""}',
      canal: 'pedidos',
      nombreCanal: tr('Pedidos'));
  }

  // ════════════════════════════════════════
  // NOTIFICACIÓN DE PRUEBA
  // ════════════════════════════════════════
  static Future<void> probar() async {
    await _vibrar(fuerte: true);
    await _mostrar(
      id: 99,
      titulo: tr('✅ HETNA CNC — Notificaciones activas'),
      cuerpo: tr('Las alertas y pedidos te llegarán aquí 🔔'),
      canal: 'alertas',
      nombreCanal: tr('Alertas de seguimiento'));
  }

  // ════════════════════════════════════════
  // PRIVADOS
  // ════════════════════════════════════════
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
    String? payload,
  }) async {
    if (!_inicializado) await inicializar();
    final androidDetails = AndroidNotificationDetails(
      canal,
      nombreCanal,
      channelDescription: tr('Notificaciones HETNA CNC'),
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
      icon: '@mipmap/ic_launcher',
      styleInformation: const BigTextStyleInformation(''),
    );
    await _plugin.show(
      id, titulo, cuerpo,
      NotificationDetails(android: androidDetails),
      payload: payload);
  }
}
