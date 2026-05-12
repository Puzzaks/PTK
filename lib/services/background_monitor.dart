import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ── Top-level callback (must be top-level or static) ──────
@pragma('vm:entry-point')
void startMonitorCallback() {
  FlutterForegroundTask.setTaskHandler(MonitorTaskHandler());
}

/// Background monitoring task handler.
/// Runs in its own isolate — no access to AppEngine or UI.
/// Reads config directly from Hive and uses FlutterForegroundTask storage.
class MonitorTaskHandler extends TaskHandler {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Previous states for change detection
  Map<String, bool> _serverStates = {}; // serverId -> wasOnline
  Map<String, List<String>> _spIncidentIds = {}; // spId -> [incidentIds]

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Initialize Hive in background isolate
    await Hive.initFlutter();
    if (!Hive.isBoxOpen('app_storage')) {
      await Hive.openBox('app_storage');
    }

    // Initialize notifications in background isolate
    const androidSettings = AndroidInitializationSettings('@drawable/ic_launcher_foreground');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);

    // Load previous states
    await _loadStates();

    // Run first tick immediately
    await _runTick();
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    await _runTick();
  }

  Future<void> _runTick() async {
    try {
      // Step 1: Internet check
      final online = await _checkInternet();
      if (!online) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'PTK Monitoring',
          notificationText: 'No internet — monitoring paused',
          notificationIcon: const NotificationIcon(
            metaDataName: 'page.puzzak.ptk.NOTIFICATION_ICON',
          ),
        );
        return;
      }

      // Step 2: Reload config from Hive & Task Data
      final box = Hive.box('app_storage');
      
      // Try task data first (most recent), then Hive
      final serversRaw = await FlutterForegroundTask.getData<String>(key: 'servers') ?? 
                        box.get('servers_v2') as String?;
      final pagesRaw   = await FlutterForegroundTask.getData<String>(key: 'status_pages') ?? 
                        box.get('status_pages_v1') as String?;
      
      final bgEnabled  = await FlutterForegroundTask.getData<bool>(key: 'bg_enabled') ?? 
                        box.get('bg_monitor_enabled', defaultValue: false) as bool;
      final bgDefault  = await FlutterForegroundTask.getData<bool>(key: 'bg_default') ?? 
                        box.get('bg_monitor_default', defaultValue: true) as bool;

      if (!bgEnabled) return;

      final servers = _parseList(serversRaw);
      final statusPages = _parseList(pagesRaw);

      int serversMonitored = 0;
      int pagesMonitored = 0;
      int serversOffline = 0;
      int activeIncidents = 0;

      // Step 3: Server monitoring
      for (final server in servers) {
        final shouldMonitor = server['bgMonitor'] ?? bgDefault;
        if (shouldMonitor != true) continue;
        serversMonitored++;

        final serverId = server['id'] as String;
        final serverName = server['name'] as String;
        final serverUrl = server['url'] as String;

        final isOnline = await _pingServer(serverUrl);
        final wasOnline = _serverStates[serverId] ?? true; // assume online initially

        if (wasOnline && !isOnline) {
          await _showServerOffline(serverId, serverName);
        } else if (!wasOnline && isOnline) {
          await _showServerOnline(serverId, serverName);
        }
        
        if (!isOnline) serversOffline++;
        _serverStates[serverId] = isOnline;
      }

      // Step 4: Statuspage monitoring
      for (final sp in statusPages) {
        final shouldMonitor = sp['bgMonitor'] ?? bgDefault;
        if (shouldMonitor != true) continue;
        pagesMonitored++;

        final spId = sp['id'] as String;
        final spName = sp['name'] as String;
        final spUrl = sp['url'] as String;

        try {
          final incidents = await _fetchUnresolvedIncidents(spUrl);
          final previousIds = _spIncidentIds[spId] ?? [];
          final currentIds = incidents.map((i) => i['id'] as String).toList();

          for (final incident in incidents) {
            final incId = incident['id'] as String;
            if (!previousIds.contains(incId)) {
              await _showIncidentAlert(spId, spName, incId, incident['name'] as String);
            }
          }

          for (final oldId in previousIds) {
            if (!currentIds.contains(oldId)) {
              await _showIncidentResolved(spId, spName, oldId, 'Incident resolved');
            }
          }

          _spIncidentIds[spId] = currentIds;
          activeIncidents += currentIds.length;
        } catch (_) {}
      }

      // Step 5: Update persistent notification
      final parts = <String>[];
      parts.add('$serversMonitored servers, $pagesMonitored pages');
      if (serversOffline > 0 || activeIncidents > 0) {
        final issues = <String>[];
        if (serversOffline > 0) issues.add('$serversOffline offline');
        if (activeIncidents > 0) issues.add('$activeIncidents incidents');
        parts.add('⚠ ${issues.join(', ')}');
      } else {
        parts.add('All OK');
      }

      await FlutterForegroundTask.updateService(
        notificationTitle: 'PTK Monitoring',
        notificationText: parts.join(' • '),
        notificationIcon: const NotificationIcon(
          metaDataName: 'page.puzzak.ptk.NOTIFICATION_ICON',
        ),
      );

      await _saveStates();
    } catch (e) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'PTK Monitoring',
        notificationText: 'Error: ${e.toString().substring(0, 50)}',
        notificationIcon: const NotificationIcon(
          metaDataName: 'page.puzzak.ptk.NOTIFICATION_ICON',
        ),
      );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _saveStates();
  }

  @override
  void onReceiveData(Object data) {
    // Could receive config updates from main isolate if needed
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationDismissed() {}

  // ── Helper methods ──────────────────────────────────────

  Future<bool> _checkInternet() async {
    try {
      final socket = await Socket.connect('8.8.8.8', 53,
          timeout: const Duration(seconds: 5));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _pingServer(String rawUrl) async {
    try {
      final uri = Uri.parse(rawUrl);
      final host = uri.host;
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 5));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  String _normalizeSpUrl(String url) {
    var u = url.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (!u.startsWith('http')) u = 'https://$u';
    return u;
  }

  Future<List<Map<String, dynamic>>> _fetchUnresolvedIncidents(String url) async {
    final u = _normalizeSpUrl(url);
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse('$u/api/v2/incidents/unresolved.json'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        final incidents = data['incidents'] as List? ?? [];
        return incidents.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    } finally {
      client.close();
    }
  }

  // ── Notification helpers ─────────────────────────────────

  Future<void> _showServerOffline(String serverId, String serverName) async {
    await _notifications.show(
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

  Future<void> _showServerOnline(String serverId, String serverName) async {
    await _notifications.show(
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

  Future<void> _showIncidentAlert(
    String spId, String spName, String incidentId, String incidentName,
  ) async {
    await _notifications.show(
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

  Future<void> _showIncidentResolved(
    String spId, String spName, String incidentId, String incidentName,
  ) async {
    await _notifications.show(
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

  // ── Hive data reading ────────────────────────────────────

  List<Map<String, dynamic>> _parseList(String? raw) {
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── State persistence ────────────────────────────────────

  Future<void> _loadStates() async {
    final raw1 = await FlutterForegroundTask.getData<String>(key: 'bg_server_states');
    if (raw1 != null) {
      try {
        final map = jsonDecode(raw1) as Map<String, dynamic>;
        _serverStates = map.map((k, v) => MapEntry(k, v as bool));
      } catch (_) {}
    }
    final raw2 = await FlutterForegroundTask.getData<String>(key: 'bg_sp_incident_ids');
    if (raw2 != null) {
      try {
        final map = jsonDecode(raw2) as Map<String, dynamic>;
        _spIncidentIds = map.map((k, v) =>
            MapEntry(k, (v as List).cast<String>()));
      } catch (_) {}
    }
  }

  Future<void> _saveStates() async {
    await FlutterForegroundTask.saveData(
      key: 'bg_server_states',
      value: jsonEncode(_serverStates),
    );
    await FlutterForegroundTask.saveData(
      key: 'bg_sp_incident_ids',
      value: jsonEncode(_spIncidentIds),
    );
  }
}
