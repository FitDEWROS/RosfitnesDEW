import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../app_navigator.dart';
import 'api_service.dart';
import 'auth_service.dart';

const String _channelId = 'fitdew_notifications';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}

class PushService {
  static final PushService _instance = PushService._();
  PushService._();
  factory PushService() => _instance;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _ensureFirebase();
    await _initLocalNotifications();

    await FirebaseMessaging.instance.requestPermission();

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _registerToken(token);
    });

    FirebaseMessaging.onMessage.listen(_showLocalNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _handleOpen(initial);
    }
  }

  Future<void> refreshToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _registerToken(token);
    }
  }

  Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (_) => _openNotifications(),
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      'Оповещения',
      description: 'Оповещения приложения',
      importance: Importance.high,
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
  }

  Future<void> _registerToken(String token) async {
    final authToken = await AuthService().getToken();
    if (authToken == null || authToken.isEmpty) return;
    try {
      await ApiService().registerPushToken(
        token: token,
        platform: Platform.isAndroid ? 'android' : 'unknown',
      );
    } catch (_) {}
  }

  void _handleOpen(RemoteMessage message) {
    _openNotifications();
  }

  void _openNotifications() {
    AppNavigator.key.currentState?.pushNamed('/notifications');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'Оповещения',
      channelDescription: 'Оповещения приложения',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
