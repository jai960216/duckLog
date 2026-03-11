import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 백그라운드 메시지 핸들러 (top-level function 필수)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class FcmService {
  FcmService._();
  static final instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'ducklog_notifications';
  static const _channelName = 'DuckLog 알림';

  /// FCM 초기화
  Future<void> initialize() async {
    // flutter_local_notifications 초기화
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Android 알림 채널 생성
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: '덕로그 푸시 알림',
              importance: Importance.high,
            ),
          );
    }

    // iOS 포그라운드 알림 표시
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 알림 권한 요청 (Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // 현재 토큰 저장
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    // 토큰 갱신 시 자동 저장
    _messaging.onTokenRefresh.listen(_saveToken);

    // 포그라운드 메시지 → 로컬 알림으로 표시
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 알림 탭으로 앱 열었을 때
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // 앱 종료 상태에서 알림 탭으로 열었을 때
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }

    // Hive 알림 설정에 따라 토픽 구독
    await _syncTopicSubscriptions();
  }

  /// Supabase에 FCM 토큰 저장
  Future<void> _saveToken(String token) async {
    debugPrint('[FCM] Token: ${token.substring(0, 20)}...');
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('fcm_tokens').upsert({
        'user_id': user.id,
        'token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('[FCM] Token save failed: $e');
    }
  }

  /// 로그아웃 시 FCM 토큰 삭제
  Future<void> clearToken() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client
            .from('fcm_tokens')
            .delete()
            .eq('user_id', user.id);
      } catch (e) {
        debugPrint('[FCM] Token delete failed: $e');
      }
    }
    await _messaging.deleteToken();
  }

  /// Hive 알림 설정 → FCM 토픽 구독 동기화
  Future<void> _syncTopicSubscriptions() async {
    try {
      final box = await Hive.openBox('notification_prefs');
      final friendRequest = box.get('friend_request', defaultValue: true);
      final like = box.get('like', defaultValue: true);
      final calendar = box.get('calendar', defaultValue: true);

      await _setTopic('friend_request', friendRequest);
      await _setTopic('like', like);
      await _setTopic('calendar', calendar);
    } catch (e) {
      debugPrint('[FCM] Topic sync failed: $e');
    }
  }

  /// 개별 토픽 구독/해제
  Future<void> updateTopic(String topic, bool subscribe) async {
    await _setTopic(topic, subscribe);
  }

  Future<void> _setTopic(String topic, bool subscribe) async {
    if (subscribe) {
      await _messaging.subscribeToTopic(topic);
    } else {
      await _messaging.unsubscribeFromTopic(topic);
    }
  }

  /// 포그라운드 메시지 → 로컬 알림으로 직접 표시
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground: ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// 알림 탭 처리
  void _handleMessageTap(RemoteMessage message) {
    debugPrint('[FCM] Tapped: ${message.data}');
  }
}
