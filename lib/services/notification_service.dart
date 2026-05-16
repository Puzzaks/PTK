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

    // Initial channel creation (will use defaults if not updated yet)
    await createChannels();

    // Check if app was launched from a notification (cold start)
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingPayload = launchDetails!.notificationResponse?.payload;
    }
  }

  Future<void> createChannels({
    String? serviceName,
    String? serviceDesc,
    String? serverOfflineName,
    String? serverOfflineDesc,
    String? serverOnlineName,
    String? serverOnlineDesc,
    String? incidentName,
    String? incidentDesc,
    String? resolvedName,
    String? resolvedDesc,
  }) async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    // Specific channels for different event types
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        'ptk_server_offline',
        serverOfflineName ?? 'Server Offline',
        description: serverOfflineDesc ?? 'Alerts when a monitored server goes offline',
        importance: Importance.high,
      ),
    );

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        'ptk_server_online',
        serverOnlineName ?? 'Server Online',
        description: serverOnlineDesc ?? 'Alerts when a monitored server comes back online',
        importance: Importance.low,
      ),
    );

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        'ptk_incidents',
        incidentName ?? 'Service Incidents',
        description: incidentDesc ?? 'Alerts for new incidents on monitored Statuspages',
        importance: Importance.high,
      ),
    );

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        'ptk_resolved',
        resolvedName ?? 'Incidents Resolved',
        description: resolvedDesc ?? 'Alerts when a Statuspage incident is resolved',
        importance: Importance.low,
      ),
    );

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        'ptk_service',
        serviceName ?? 'Background Service',
        description: serviceDesc ?? 'Persistent notification while background monitoring is active',
        importance: Importance.low,
      ),
    );
  }

  /// Call this after the navigator is ready (e.g. after first frame)
  void processPendingNavigation() {
    if (_pendingPayload != null) {
      _handlePayload(_pendingPayload!);
      _pendingPayload = null;
    }
  }

  // ── Notification display methods ──────────────────────────

  Future<void> showServerOfflineAlert(String serverId, String serverName, {String? title, String? body}) async {
    await _plugin.show(
      serverId.hashCode,
      title ?? '⚠ Server Offline',
      body ?? '$serverName is offline',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ptk_server_offline',
          'Server Offline',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_launcher_foreground',
        ),
      ),
      payload: 'server:$serverId',
    );
  }

  Future<void> showServerOnlineAlert(String serverId, String serverName, {String? title, String? body}) async {
    await _plugin.show(
      serverId.hashCode,
      title ?? '✓ Server Online',
      body ?? '$serverName is back online',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ptk_server_online',
          'Server Online',
          importance: Importance.low,
          priority: Priority.low,
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
    {String? title}
  ) async {
    await _plugin.show(
      '$spId:$incidentId'.hashCode,
      title ?? '⚠ Incident on $spName',
      incidentName,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ptk_incidents',
          'Service Incidents',
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
    {String? title}
  ) async {
    await _plugin.show(
      '$spId:$incidentId'.hashCode,
      title ?? '✓ Resolved on $spName',
      incidentName,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ptk_resolved',
          'Incidents Resolved',
          importance: Importance.low,
          priority: Priority.low,
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
