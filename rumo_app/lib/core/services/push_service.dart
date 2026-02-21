import 'dart:io';

import 'package:flutter/material.dart' show debugPrint, Color;
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
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
  static const _passengerChannelId = 'rumo_driver_accepted';
  static const _passengerChannelName = 'Motorista aceitou';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _forPassenger = false;

  /// Inicializa FCM e local notifications.
  /// [forPassenger] true = app passageiro (push quando motorista aceita), false = motorista (push nova corrida).
  Future<void> init({bool forPassenger = false}) async {
    if (_initialized) return;
    if (!Platform.isAndroid) return; // iOS precisa de config adicional

    try {
      _forPassenger = forPassenger;
      await Firebase.initializeApp();
      await _setupLocalNotifications(forPassenger);
      await _setupFcm(forPassenger);
      _initialized = true;
    } catch (e) {
      // Firebase não configurado (ex: falta google-services.json)
      debugPrint('PushService init skipped: $e');
    }
  }

  Future<void> _setupLocalNotifications(bool forPassenger) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    final id = forPassenger ? _passengerChannelId : _channelId;
    final channel = AndroidNotificationChannel(
      id,
      forPassenger ? _passengerChannelName : _channelName,
      description: forPassenger ? 'Aviso quando motorista aceita' : 'Avisos de novas corridas disponíveis',
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

  Future<void> _setupFcm(bool forPassenger) async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Android 13+: pedir permissão de notificação em runtime
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    // Registra token mesmo se negado (Android <13 pode funcionar; backend precisa do token)
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('PushService: permissão de notificação negada');
    }

    // Foreground: mostrar notificação local com som
    FirebaseMessaging.onMessage.listen((m) => _onForegroundMessage(m, forPassenger));

    await _registerToken(forPassenger);
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _registerToken(forPassenger));
  }

  void _onForegroundMessage(RemoteMessage message, bool forPassenger) {
    final notif = message.notification;
    if (notif == null) return;

    final channelId = forPassenger ? _passengerChannelId : _channelId;
    final channelName = forPassenger ? _passengerChannelName : _channelName;
    final title = notif.title ?? (forPassenger ? 'Motorista aceitou' : 'Nova corrida');
    final body = notif.body ?? (forPassenger ? 'Acompanhe sua corrida' : 'Uma nova corrida está disponível.');

    _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Avisos de novas corridas',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
        ),
      ),
    );
  }

  Future<void> _registerToken([bool? forPassenger]) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || !AuthService().isLoggedIn) return;

    final isPassenger = forPassenger ?? _forPassenger;
    try {
      if (isPassenger) {
        await ApiService().registerPassengerFcmToken(token);
      } else {
        await ApiService().registerFcmToken(token);
      }
      debugPrint('PushService: token FCM registrado (${isPassenger ? "passageiro" : "motorista"})');
    } catch (e) {
      debugPrint('PushService: falha ao registrar token: $e');
    }
  }

  /// Chame quando o motorista fizer login ou ficar online para garantir token atualizado.
  Future<void> ensureTokenRegistered() async {
    if (!_initialized) return;
    await _registerToken();
  }
}
