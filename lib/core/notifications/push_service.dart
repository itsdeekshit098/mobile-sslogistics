import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../network/dio_client.dart';
import '../constants/api_constants.dart';
import '../router/app_router.dart';
import '../../features/notifications/providers/notification_provider.dart';
import 'notification_routes.dart';

/// Wraps Firebase Cloud Messaging setup: permission request, token
/// registration with the backend, and foreground/background message
/// handling. Requires a Firebase project's platform config files
/// (google-services.json / GoogleService-Info.plist) to actually deliver
/// push — those are external prerequisites the user must supply; this
/// service fails soft (logs and no-ops) if Firebase isn't configured, so
/// the rest of the app (in-app notifications via SSE) keeps working
/// regardless.
class PushService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static String? _currentToken;
  static bool _initialized = false;

  /// Must match the Android raw resource name (res/raw/notification.mp3,
  /// no extension) and the backend's android.notification.channelId.
  static const String _channelId = 'vehicle_alerts';

  static Future<void> init() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      // No Firebase config shipped yet (google-services.json /
      // GoogleService-Info.plist missing) — push is unavailable, but the
      // rest of the app must keep working.
      // ignore: avoid_print
      print('PushService: Firebase not configured, push disabled ($e)');
      return;
    }

    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        final data = jsonDecode(payload) as Map<String, dynamic>;
        _markReadFromData(data);
        final type = data['type'] as String?;
        final route = type != null ? mobileRouteForNotification(type, data) : null;
        if (route != null) {
          rootNavigatorKey.currentContext?.push(route);
        }
      },
    );

    // Android channel sound is fixed at creation time, so this must be a
    // distinct channel id from the old default ('notifications') — existing
    // installs otherwise keep their already-created, sound-less channel.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Vehicle Alerts',
            importance: Importance.high,
            sound: RawResourceAndroidNotificationSound('notification'),
          ),
        );

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null) await _registerToken(token);

    messaging.onTokenRefresh.listen(_registerToken);

    // Foreground messages don't show a system banner on their own —
    // present them manually via flutter_local_notifications.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Vehicle Alerts',
            importance: Importance.high,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound('notification'),
          ),
          iOS: DarwinNotificationDetails(sound: 'notification.caf'),
        ),
        payload: jsonEncode(message.data),
      );
    });

    // Tapping a push while the app was backgrounded (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _markReadFromData(message.data);
      final type = message.data['type'] as String?;
      final route =
          type != null ? mobileRouteForNotification(type, message.data) : null;
      if (route != null) {
        rootNavigatorKey.currentContext?.push(route);
      }
    });

    // Tapping a push that launched the app from a fully terminated state.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _markReadFromData(initialMessage.data);
      final type = initialMessage.data['type'] as String?;
      final route = type != null
          ? mobileRouteForNotification(type, initialMessage.data)
          : null;
      if (route != null) {
        rootNavigatorKey.currentContext?.push(route);
      }
    }
  }

  /// Marks the notification the user just tapped as read in-app, so the
  /// list/badge reflect it immediately instead of waiting on the next SSE
  /// reconnect. Best-effort: the backend only started sending
  /// `notificationId` in the push payload once this landed, so older/queued
  /// pushes may not carry it.
  static void _markReadFromData(Map<String, dynamic> data) {
    final idStr = data['notificationId'] as String?;
    if (idStr == null) return;
    final id = int.tryParse(idStr);
    if (id == null) return;

    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    ProviderScope.containerOf(context, listen: false)
        .read(notificationListProvider.notifier)
        .markRead(id);
  }

  /// Re-attempts registering the current device token — call after a
  /// successful login, since the initial [init] registration attempt may
  /// have run (and silently failed) before the user was authenticated.
  static Future<void> registerCurrentToken() async {
    final token = _currentToken;
    if (token != null) await _registerToken(token);
  }

  static Future<void> _registerToken(String token) async {
    _currentToken = token;
    try {
      await DioClient.dio.post(
        ApiConstants.notificationsRegisterDevice,
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
    } catch (e, st) {
      // Best-effort — retried on next app start/token refresh — but report
      // it so a persistent registration failure (backend, not just offline)
      // is visible instead of silently disabling push for that device.
      await Sentry.captureException(e, stackTrace: st);
    }
  }

  /// Call on sign-out, while the session is still valid, so the token is
  /// no longer associated with this (now logged-out) user.
  static Future<void> unregister() async {
    final token = _currentToken;
    if (token == null) return;
    try {
      await DioClient.dio.delete(
        ApiConstants.notificationsRegisterDevice,
        queryParameters: {'token': token},
      );
    } catch (e, st) {
      // Best-effort, but surface it — a failed unregister means this
      // device keeps receiving pushes for a logged-out user.
      await Sentry.captureException(e, stackTrace: st);
    }
  }
}
