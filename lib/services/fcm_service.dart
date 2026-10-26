// lib/services/fcm_service.dart
// HETNA CNC — Firebase Cloud Messaging
// Push notifications cuando la app está cerrada
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../i18n/tr.dart';

// ── Handler para mensajes en segundo plano ──────────────
// DEBE estar fuera de cualquier clase (función top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('FCM background: ${message.messageId}');
  // Mostrar notificación local cuando app está en background
  await FcmService._mostrarNotificacionLocal(message);
}

// ══════════════════════════════════════════════════════
// SERVICIO FCM
// ══════════════════════════════════════════════════════
class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotif = FlutterLocalNotificationsPlugin();
  static final _sb = Supabase.instance.client;

  // Canal de notificaciones Android
  static const _channel = AndroidNotificationChannel(
    'hetna_cnc_alerts',
    'Alertas HETNA CNC',
    description: 'Notificaciones de cotizaciones, pedidos y alertas',
    importance: Importance.high,
    playSound: true,
  );

  // ── INICIALIZAR ──────────────────────────────────────
  static Future<void> inicializar() async {
    // Handler para mensajes en background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Solicitar permisos
    final settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
      provisional: false);

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('FCM: permisos denegados');
      return;
    }

    // Crear canal Android
    await _localNotif
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);

    // Inicializar notificaciones locales
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotif.initialize(initSettings,
      onDidReceiveNotificationResponse: _onNotificacionTocada);

    // Guardar token FCM en Supabase
    await _guardarToken();

    // Escuchar token refresh
    _messaging.onTokenRefresh.listen(_onTokenRefresh);

    // Mensajes cuando la app está en PRIMER PLANO
    FirebaseMessaging.onMessage.listen(_onMensajePrimerPlano);

    // App abierta desde notificación (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen(_onMensajeAbierto);

    // Verificar si la app fue abierta desde una notificación (terminated)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _onMensajeAbierto(initialMessage);
    }

    print('FCM inicializado correctamente');
  }

  // ── GUARDAR TOKEN EN SUPABASE ────────────────────────
  static Future<void> _guardarToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      final userId = _sb.auth.currentUser?.id;
      if (userId == null) return;

      // Guardar en tabla usuarios_negocio
      await _sb.from('usuarios_negocio')
        .update({'fcm_token': token})
        .eq('user_id', userId);

      print('FCM token guardado: ${token.substring(0, 20)}...');
    } catch (e) {
      print('Error guardando FCM token: $e');
    }
  }

  static Future<void> _onTokenRefresh(String token) async {
    await _guardarToken();
  }

  // ── MENSAJE EN PRIMER PLANO ──────────────────────────
  static Future<void> _onMensajePrimerPlano(RemoteMessage message) async {
    print('FCM foreground: ${message.notification?.title}');
    await _mostrarNotificacionLocal(message);
  }

  // ── MOSTRAR NOTIFICACIÓN LOCAL ───────────────────────
  static Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;

    final tipo = message.data['tipo'] ?? 'general';
    final iconoColor = _colorPorTipo(tipo);

    await _localNotif.show(
      message.hashCode,
      notif.title ?? tr('HETNA CNC'),
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id, _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: iconoColor,
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(notif.body ?? ''),
          groupKey: 'hetna_cnc_group',
        )),
      payload: jsonEncode(message.data));
  }

  // ── APP ABIERTA DESDE NOTIFICACIÓN ───────────────────
  static void _onMensajeAbierto(RemoteMessage message) {
    print('FCM abierto desde notificación: ${message.data}');
    // Aquí puedes navegar a la pantalla correcta según el tipo
    final tipo = message.data['tipo'];
    final id = message.data['id'];
    // TODO: navegar según tipo (cotizacion, pedido, alerta)
  }

  // ── NOTIFICACIÓN LOCAL TOCADA ────────────────────────
  static void _onNotificacionTocada(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!);
      print('Notificación tocada: $data');
      // TODO: navegar según data['tipo']
    } catch (_) {}
  }

  // ── COLOR POR TIPO ───────────────────────────────────
  static Color _colorPorTipo(String tipo) {
    switch (tipo) {
      case 'cotizacion':   return const Color(0xFF1a3a5c);
      case 'pedido':       return const Color(0xFF7c3aed);
      case 'pago':         return const Color(0xFF1d9e75);
      case 'alerta':       return const Color(0xFFef9f27);
      case 'seguimiento':  return const Color(0xFFe24b4a);
      default:             return const Color(0xFF1a3a5c);
    }
  }

  // ── SUSCRIBIR A TOPIC ────────────────────────────────
  // Para notificaciones grupales (ej: todos los admins de un negocio)
  static Future<void> suscribirTopic(String negocioId) async {
    await _messaging.subscribeToTopic('negocio_$negocioId');
    print('FCM suscrito a topic: negocio_$negocioId');
  }

  static Future<void> desuscribirTopic(String negocioId) async {
    await _messaging.unsubscribeFromTopic('negocio_$negocioId');
  }

  // ── ENVIAR NOTIFICACIÓN DESDE APP ────────────────────
  // Para notificar a otros usuarios del mismo negocio
  static Future<void> enviarNotificacion({
    required String titulo,
    required String cuerpo,
    required String tipo,
    String? id,
    String? negocioId,
  }) async {
    try {
      // Llamar a Supabase Edge Function que envía FCM
      await _sb.functions.invoke('send-push-notification', body: {
        'titulo': titulo,
        'cuerpo': cuerpo,
        'tipo': tipo,
        'id': id,
        'negocio_id': negocioId,
      });
    } catch (e) {
      print('Error enviando notificación: $e');
    }
  }
}
