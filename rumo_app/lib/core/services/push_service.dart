import 'dart:io';

import 'package:flutter/material.dart' show debugPrint, Color;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';
import 'auth_service.dart';

/// Push notifications para motorista: nova corrida com som, inclusive em background.
/// Requer Firebase configurado (google-services.json no Android).
///
/// Para setup:
/// 1. Crie projeto no Firebase Console
/// 2. Adicione app Android com package com.rumo.motorista
/// 3. Baixe google-services.json em android/app/
/// 4. No backend: FIREBASE_SERVICE_ACCOUNT_PATH apontando para o JSON da service account
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Em background, o sistema mostra a notificação automaticamente
  // O payload já inclui título e corpo para exibição
}

class PushService {
  static final PushService _instance = PushService._();
  factory PushService() => _instance;

  PushService._();

  static const _channelId = 'rumo_new_ride';
  static const _channelName = 'Nova corrida';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Inicializa FCM e local notifications. Chamar uma vez no main do motorista.
  Future<void> init() async {
    if (_initialized) return;
    if (!Platform.isAndroid) return; // iOS precisa de config adicional

    try {
      await Firebase.initializeApp();
      await _setupLocalNotifications();
      await _setupFcm();
      _initialized = true;
    } catch (e) {
      // Firebase não configurado (ex: falta google-services.json)
      debugPrint('PushService init skipped: $e');
    }
  }

  Future<void> _setupLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Avisos de novas corridas disponíveis',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 0, 217, 95),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Ao tocar na notificação, o app abre. A tela do motorista já mostra as corridas.
  }

  Future<void> _setupFcm() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Foreground: mostrar notificação local com som
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    await _registerToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _registerToken());
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;

    _localNotifications.show(
      message.hashCode,
      notif.title ?? 'Nova corrida',
      notif.body ?? 'Uma nova corrida está disponível.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Avisos de novas corridas',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
        ),
      ),
    );
  }

  Future<void> _registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || !AuthService().isLoggedIn) return;

    try {
      await ApiService().registerFcmToken(token);
    } catch (_) {}
  }

  /// Chame quando o motorista fizer login ou ficar online para garantir token atualizado.
  Future<void> ensureTokenRegistered() async {
    if (!_initialized) return;
    await _registerToken();
  }
}
