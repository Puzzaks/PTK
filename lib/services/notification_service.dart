import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton notification service for PTK alert notifications.
/// Handles initialization, display, and deep-link navigation from taps.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Pending payload from cold-start launch (processed once navigator is ready)
  String? _pendingPayload;

  /// Initialize the notification plugin and channels.
  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    const androidSettings = AndroidInitializationSettings('@drawable/ic_launcher_foreground');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'ptk_alerts',
            'Monitoring Alerts',
            description: 'Notifications for server outages and service incidents',
            importance: Importance.high,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'ptk_service',
            'Background Service',
            description: 'Persistent notification while background monitoring is active',
            importance: Importance.low,
          ),
        );
      }
    }

    // Check if app was launched from a notification (cold start)
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingPayload = launchDetails!.notificationResponse?.payload;
    }
  }

  /// Call this after the navigator is ready (e.g. after first frame)
  void processPendingNavigation() {
    if (_pendingPayload != null) {
      _handlePayload(_pendingPayload!);
      _pendingPayload = null;
    }
  }

  // ── Notification display methods ──────────────────────────

  Future<void> showServerOfflineAlert(String serverId, String serverName) async {
    await _plugin.show(
      serverId.hashCode,
      '⚠ Server Offline',
      '$serverName is offline',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ptk_alerts',
          'Monitoring Alerts',
          channelDescription: 'Notifications for server outages and service incidents',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_launcher_foreground',
        ),
      ),
      payload: 'server:$serverId',
    );
  }

  Future<void> showServerOnlineAlert(String serverId, String serverName) async {
    await _plugin.show(
      serverId.hashCode,
      '✓ Server Online',
      '$serverName is back online',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ptk_alerts',
          'Monitoring Alerts',
          channelDescription: 'Notifications for server outages and service incidents',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@drawable/ic_launcher_foreground',
        ),
      ),
      payload: 'server:$serverId',
    );
  }

  Future<void> showIncidentAlert(
    String spId,
    String spName,
    String incidentId,
    String incidentName,
  ) async {
    await _plugin.show(
      '$spId:$incidentId'.hashCode,
      '⚠ Incident on $spName',
      incidentName,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ptk_alerts',
          'Monitoring Alerts',
          channelDescription: 'Notifications for server outages and service incidents',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_launcher_foreground',
        ),
      ),
      payload: 'statuspage:$spId',
    );
  }

  Future<void> showIncidentResolvedAlert(
    String spId,
    String spName,
    String incidentId,
    String incidentName,
  ) async {
    await _plugin.show(
      '$spId:$incidentId'.hashCode,
      '✓ Resolved on $spName',
      incidentName,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ptk_alerts',
          'Monitoring Alerts',
          channelDescription: 'Notifications for server outages and service incidents',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@drawable/ic_launcher_foreground',
        ),
      ),
      payload: 'statuspage:$spId',
    );
  }

  // ── Deep-link handling ───────────────────────────────────

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      _handlePayload(payload);
    }
  }

  void _handlePayload(String payload) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    if (payload.startsWith('server:')) {
      final serverId = payload.substring('server:'.length);
      navigator.pushNamed('ServerDetailFromNotification', arguments: serverId);
    } else if (payload.startsWith('statuspage:')) {
      final spId = payload.substring('statuspage:'.length);
      navigator.pushNamed('StatusPageDetailFromNotification', arguments: spId);
    }
  }
}
