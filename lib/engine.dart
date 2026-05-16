import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart' as md;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ptk/pages/support/elements.dart';
import 'package:ptk/parts/translator.dart';
import 'package:ptk/parts/sp_shortener.dart';
import 'package:ptk/storage/analytics_service.dart';
import 'package:ptk/models/server_watcher.dart';
import 'package:ptk/models/server_telemetry.dart';
import 'package:ptk/models/status_page.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:ptk/services/background_monitor.dart';
import 'package:ptk/services/notification_service.dart';

// ─── TelemetryData (kept for chart compatibility) ────────
class TelemetryData {
  final DateTime time;
  final double value;
  TelemetryData(this.time, this.value);
}

// ─── Update-rate step list ────────────────────────────────
const List<double> kUpdateRateSteps = [
  0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9,
  1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0,
];

class AppEngine with md.ChangeNotifier {
  late Cards cards;

  Dictionary dict = Dictionary(
    path: 'assets/translations',
    url: 'https://raw.githubusercontent.com/Puzzaks/PTK/refs/heads/android',
  );
  
  ComponentShortener spShortener = ComponentShortener();

  bool appStarted = false;
  late final AnalyticsService logger;

  AppEngine() {
    logger = AnalyticsService(notifyEngine: genericRefresh);
  }

  List<Map> get logs => logger.logs;

  // ── Servers ───────────────────────────────────────────────
  List<ServerWatcher> _servers = [];
  List<ServerWatcher> get servers => List.unmodifiable(_servers);

  // Telemetry keyed by server id
  final Map<String, ServerTelemetry> _telemetry = {};
  ServerTelemetry telemetryFor(String id) =>
      _telemetry.putIfAbsent(id, ServerTelemetry.new);

  // ── Visibility tracking ───────────────────────────────────
  // Key: server id, Value: number of active viewers (cards, detail pages, etc)
  final Map<String, int> _serverVisibilityRefs = {};

  void setServerVisible(String id, bool visible) {
    final current = _serverVisibilityRefs[id] ?? 0;
    if (visible) {
      _serverVisibilityRefs[id] = current + 1;
    } else {
      _serverVisibilityRefs[id] = (current - 1).clamp(0, 1000);
    }
  }

  bool _isServerVisible(String id) => (_serverVisibilityRefs[id] ?? 0) > 0;

  // ── Status Pages ──────────────────────────────────────────
  List<StatusPage> _statusPages = [];
  List<StatusPage> get statusPages => List.unmodifiable(_statusPages);

  final Map<String, StatusPageData> _spData = {};
  StatusPageData spDataFor(String id) =>
      _spData.putIfAbsent(id, StatusPageData.new);

  // Default section order
  List<DetailSection> spSectionOrder = [
    DetailSection.currentIncidents,
    DetailSection.currentMaintenances,
    DetailSection.upcomingMaintenances,
    DetailSection.components,
    DetailSection.allScheduledMaintenances,
    DetailSection.allIncidents,
  ];

  Set<DetailSection> spSectionsDisabled = {};

  int spUpcomingDays = 3;

  void reorderSpSections(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = spSectionOrder.removeAt(oldIndex);
    spSectionOrder.insert(newIndex, item);
    _saveSPSettings();
    notifyListeners();
  }

  void toggleSpSection(DetailSection section, bool enable) {
    if (enable) {
      spSectionsDisabled.remove(section);
    } else {
      spSectionsDisabled.add(section);
    }
    _saveSPSettings();
    notifyListeners();
  }

  void setSpUpcomingDays(int days) {
    spUpcomingDays = days.clamp(1, 14);
    _saveSPSettings();
    notifyListeners();
  }

  // ── Settings ──────────────────────────────────────────────
  double _updateRate = 1.0;
  double get updateRate => _updateRate;

  // Server global defaults
  GraphStat defaultGraphStat = GraphStat.ping;
  ServerStat? defaultTextStat1 = ServerStat.ping;
  ServerStat? defaultTextStat2 = ServerStat.cpuLoad;
  List<DetailGraph> defaultGraphOrder = List.of(kDefaultGraphOrder);

  // Resolution Methods
  GraphStat resolveGraphStat(ServerWatcher s) => s.graphStat ?? defaultGraphStat;
  ServerStat? resolveTextStat1(ServerWatcher s) => s.textStat1 ?? defaultTextStat1;
  ServerStat? resolveTextStat2(ServerWatcher s) => s.textStat2 ?? defaultTextStat2;
  List<DetailGraph> resolveGraphOrder(ServerWatcher s) => s.graphOrder ?? defaultGraphOrder;

  List<DetailSection> resolveSpSectionOrder(StatusPage sp) => sp.customSectionOrder ?? spSectionOrder;
  Set<DetailSection> resolveSpSectionsDisabled(StatusPage sp) => sp.customSectionsDisabled ?? spSectionsDisabled;

  void stepUpdateRate(int direction) {
    final idx = kUpdateRateSteps.indexOf(_updateRate);
    int next;
    if (idx == -1) {
      next = kUpdateRateSteps.indexOf(1.0);
    } else {
      next = (idx + direction).clamp(0, kUpdateRateSteps.length - 1);
    }
    _updateRate = kUpdateRateSteps[next];
    _saveSettings();
    _startTimer();
    notifyListeners();
  }

  String get updateRateLabel {
    if (_updateRate < 1.0) return '${_updateRate.toStringAsFixed(1)}s';
    return '${_updateRate.toStringAsFixed(_updateRate == _updateRate.truncate() ? 0 : 1)}s';
  }

  bool _useBits = false;
  bool get useBits => _useBits;
  set useBits(bool v) {
    _useBits = v;
    _saveSettings();
    notifyListeners();
  }

  // Which tab to show first: 0 = servers, 1 = statuspages
  int _defaultTab = 0;
  int get defaultTab => _defaultTab;
  set defaultTab(int v) {
    _defaultTab = v;
    _saveSettings();
    notifyListeners();
  }

  // ── Background Monitoring ─────────────────────────────────
  bool _bgMonitorEnabled = false;
  bool get bgMonitorEnabled => _bgMonitorEnabled;

  bool bgMonitorDefault = true;

  bool resolveServerBgMonitor(ServerWatcher s) => s.bgMonitor ?? bgMonitorDefault;
  bool resolvePageBgMonitor(StatusPage p) => p.bgMonitor ?? bgMonitorDefault;

  // ── Intro ──────────────────────────────────────────────────
  bool _introCompleted = false;
  bool get introCompleted => _introCompleted;
  set introCompleted(bool v) {
    _introCompleted = v;
    Hive.box('app_storage').put('intro_completed', v);
    notifyListeners();
  }

  // ── Internet Connectivity ─────────────────────────────────
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  Timer? _connectivityTimer;

  Timer? _timer;
  Timer? _spTimer;

  // ── Init ──────────────────────────────────────────────────
  Future<void> start() async {
    await Hive.initFlutter();
    await Hive.openBox('app_storage');

    await logger.initFromHive();
    await _loadSettings();
    await _loadSPSettings();
    await _loadServers();
    await _loadStatusPages();
    await _loadSPData();
    await dict.setup(log: logger.log);
    await spShortener.setup(log: logger.log);

    // Load intro & bg monitoring state
    final box = Hive.box('app_storage');
    _introCompleted = box.get('intro_completed', defaultValue: false) as bool;
    _bgMonitorEnabled = box.get('bg_monitor_enabled', defaultValue: false) as bool;
    bgMonitorDefault = box.get('bg_monitor_default', defaultValue: true) as bool;

    // Kick off an immediate fetch for all servers
    await _fetchAll();
    await _fetchAllStatusPages();
    _startTimer();
    _startSpTimer();
    _startConnectivityTimer();

    // Restart bg monitor if it was enabled
    if (_bgMonitorEnabled) {
      _restartBgService();
    }

    // Initialize/refresh localized notification channels
    await refreshNotificationChannels();

    await logger.log('init', 'info', 'App started');
    appStarted = true;
    notifyListeners();
  }

  /// Updates the application language and refreshes all localized components.
  Future<void> updateLanguage(String langId) async {
    await dict.saveLanguage(langId);
    await refreshNotificationChannels();
    notifyListeners();
  }

  /// Refreshes the notification channels and background service metadata with the current language.
  Future<void> refreshNotificationChannels() async {
    // Update the notification service channels
    await NotificationService.instance.createChannels(
      serviceName:       dict.value('bg_notification_channel_service'),
      serviceDesc:       dict.value('bg_notification_channel_service_desc'),
      serverOfflineName: dict.value('bg_notification_channel_server_offline'),
      serverOfflineDesc: dict.value('bg_notification_channel_server_offline_desc'),
      serverOnlineName:  dict.value('bg_notification_channel_server_online'),
      serverOnlineDesc:  dict.value('bg_notification_channel_server_online_desc'),
      incidentName:      dict.value('bg_notification_channel_incidents'),
      incidentDesc:      dict.value('bg_notification_channel_incidents_desc'),
      resolvedName:      dict.value('bg_notification_channel_resolved'),
      resolvedDesc:      dict.value('bg_notification_channel_resolved_desc'),
    );

    // Sync localized strings to background task storage
    await FlutterForegroundTask.saveData(key: 'lang_notif_title', value: dict.value('app_name'));
    await FlutterForegroundTask.saveData(key: 'lang_notif_pause', value: dict.value('bg_monitoring_paused'));
    await FlutterForegroundTask.saveData(key: 'lang_notif_all_ok', value: dict.value('bg_monitoring_all_ok'));
    await FlutterForegroundTask.saveData(key: 'lang_notif_servers', value: dict.value('servers').toLowerCase());
    await FlutterForegroundTask.saveData(key: 'lang_notif_pages', value: dict.value('status_pages').toLowerCase());
    await FlutterForegroundTask.saveData(key: 'lang_notif_active_incidents', value: dict.value('bg_monitoring_active_incidents'));
    
    // Notification body templates
    await FlutterForegroundTask.saveData(key: 'lang_body_offline',  value: dict.value('bg_notification_server_offline'));
    await FlutterForegroundTask.saveData(key: 'lang_body_online',   value: dict.value('bg_notification_server_online'));
    await FlutterForegroundTask.saveData(key: 'lang_body_incident', value: dict.value('bg_notification_incident'));
    await FlutterForegroundTask.saveData(key: 'lang_body_resolved', value: dict.value('bg_notification_incident_resolved'));

    // Titles for specific alerts
    await FlutterForegroundTask.saveData(key: 'lang_title_offline', value: dict.value('bg_notification_title_server_offline'));
    await FlutterForegroundTask.saveData(key: 'lang_title_online',  value: dict.value('bg_notification_title_server_online'));
    await FlutterForegroundTask.saveData(key: 'lang_title_incident', value: dict.value('bg_notification_title_incident'));
    await FlutterForegroundTask.saveData(key: 'lang_title_resolved', value: dict.value('bg_notification_title_resolved'));

    // If service is running, it will pick up these changes on the next tick
  }

  // ── Demo seeding (called from intro) ──────────────────────
  Future<void> addDemoServer() async {
    final name = dict.data('servers.0.name') ?? 'puzzak.page';
    final url  = dict.data('servers.0.link') ?? 'https://puzzak.page/AIO.php';
    await addDemoService({'name': name, 'link': url}, true);
  }

  Future<void> addDemoStatusPage() async {
    final name = dict.data('statuspages.0.name') ?? 'GitHub Status';
    final url  = dict.data('statuspages.0.link') ?? 'https://www.githubstatus.com';
    await addDemoService({'name': name, 'link': url}, false);
  }

  Future<void> addDemoService(Map entry, bool isServer) async {
    final name = entry['name'] ?? 'Demo';
    final url  = entry['link'] ?? '';
    if (url.isEmpty) return;

    if (isServer) {
      if (_servers.any((s) => s.url == url)) return;
      _servers.add(ServerWatcher(
        id: 'seed_${name.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        url: url,
        order: _servers.length,
      ));
      await _saveServers();
    } else {
      if (_statusPages.any((sp) => sp.url == url)) return;
      _statusPages.add(StatusPage(
        id: 'seed_${name.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        url: url,
        order: _statusPages.length,
      ));
      await _saveStatusPages();
      fetchStatusPageSummary(_statusPages.last);
    }
    notifyListeners();
  }

  // ── Background Monitoring Control ──────────────────────────
  Future<void> setBgMonitorEnabled(bool enabled) async {
    _bgMonitorEnabled = enabled;
    final box = Hive.box('app_storage');
    await box.put('bg_monitor_enabled', enabled);

    if (enabled) {
      await _syncBackgroundData();
      await _initAndStartBgService();
    } else {
      await FlutterForegroundTask.stopService();
    }
    notifyListeners();
  }

  Future<void> _syncBackgroundData() async {
    final box = Hive.box('app_storage');
    // Using the same keys as the actual persistence
    final serversRaw = box.get('servers_v2') as String?;
    final pagesRaw = box.get('status_pages_v1') as String?;
    final bgEnabled = box.get('bg_monitor_enabled', defaultValue: false) as bool;
    final bgDefault = box.get('bg_monitor_default', defaultValue: true) as bool;

    await FlutterForegroundTask.saveData(key: 'servers', value: serversRaw ?? '[]');
    await FlutterForegroundTask.saveData(key: 'status_pages', value: pagesRaw ?? '[]');
    await FlutterForegroundTask.saveData(key: 'bg_enabled', value: bgEnabled);
    await FlutterForegroundTask.saveData(key: 'bg_default', value: bgDefault);
  }

  Future<void> setBgMonitorDefault(bool v) async {
    bgMonitorDefault = v;
    await Hive.box('app_storage').put('bg_monitor_default', v);
    await _syncBackgroundData();
    notifyListeners();
  }

  Future<void> _initAndStartBgService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'ptk_service',
        channelName: dict.value('bg_notification_channel_service'),
        channelDescription: 'Persistent notification while background monitoring is active',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'PTK Monitoring',
        notificationText: 'Starting monitoring...',
        callback: startMonitorCallback,
      );
    }
  }

  Future<void> _restartBgService() async {
    await _initAndStartBgService();
  }

  // ── Connectivity ──────────────────────────────────────────
  void _startConnectivityTimer() {
    _checkConnectivity(); // Immediate check
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkConnectivity(),
    );
  }

  Future<void> _checkConnectivity() async {
    try {
      final socket = await Socket.connect('8.8.8.8', 53,
          timeout: const Duration(seconds: 5));
      socket.destroy();
      if (!_isOnline) {
        _isOnline = true;
        notifyListeners();
      }
    } catch (_) {
      if (_isOnline) {
        _isOnline = false;
        notifyListeners();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: (_updateRate * 1000).round()),
      (_) => _fetchAll(),
    );
  }

  void _startSpTimer() {
    _spTimer?.cancel();
    _spTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _fetchAllStatusPages(),
    );
  }

  // ── Fetching ──────────────────────────────────────────────
  Future<void> _fetchAll() async {
    // Only fetch servers that have at least one active viewer
    final targets = _servers.where((s) => _isServerVisible(s.id)).toList();
    if (targets.isEmpty) return;

    await Future.wait(targets.map(fetchDataFor));
  }

  Future<void> _fetchAllStatusPages() async {
    await Future.wait(_statusPages.map(fetchStatusPageSummary));
  }

  Future<void> fetchDataFor(ServerWatcher server) async {
    final telem = telemetryFor(server.id);
    try {
      // ── Step 1: TCP ping (lightweight, no 429 risk) ───────
      final pingMs = await _tcpPing(server.url);
      if (pingMs != null) {
        telem.addPing(pingMs);
      }

      // ── Step 2: AIO fetch (only if AIO or first-time check) ─
      final response = await http
          .get(Uri.parse(server.url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data.containsKey('util')) {
            // Full AIO response
            telem.cpuLoad = (data['util'] ?? 0).toDouble();
            telem.cpuTemp = (data['temp'] ?? 0).toDouble();

            final memo = data['memo'] ?? {};
            telem.memTotal = (double.tryParse(memo['total']?.toString() ?? '0') ?? 0) * 1024;
            final memAvail = (double.tryParse(memo['avail']?.toString() ?? '0') ?? 0) * 1024;
            telem.memUsed  = telem.memTotal - memAvail;

            final netspd = data['netspd'] ?? {};
            telem.netIn  = (netspd['in']  ?? 0).toDouble();
            telem.netOut = (netspd['out'] ?? 0).toDouble();

            final uptimeRaw = (data['uptime'] ?? 0).toInt();
            if (uptimeRaw > 1000000000) {
              final start = DateTime.fromMillisecondsSinceEpoch(uptimeRaw * 1000);
              telem.uptime = _formatDuration(DateTime.now().difference(start));
            } else {
              telem.uptime = _formatDuration(Duration(seconds: uptimeRaw));
            }

            telem.addLoad(telem.cpuLoad);
            telem.addTemp(telem.cpuTemp);
            telem.addMem(telem.memUsed);
            telem.addNetIn(telem.netIn);
            telem.addNetOut(telem.netOut);

            // Confirm AIO if not already
            if (!server.isAio) {
              server.isAio = true;
              telem.isAioConfirmed = true;
              await _saveServers();
            }
          }
          // else: valid JSON but not AIO — ping-only
        } catch (_) {
          // Not JSON — ping-only
        }

        telem.markConnected();
      } else {
        telem.markDisconnected();
      }
    } catch (e) {
      telem.markDisconnected();
      logger.log('fetch', 'error', 'Failed to fetch ${server.name}: $e');
    }

    notifyListeners();
  }

  /// Try a URL, return true if it responds with a valid AIO JSON blob.
  Future<bool> validateAio(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      return data is Map && data.containsKey('util');
    } catch (_) {
      return false;
    }
  }

  /// Measure TCP connection latency to [url]'s host:port.
  /// Returns milliseconds, or null on failure.
  Future<double?> _tcpPing(String rawUrl) async {
    try {
      final uri  = Uri.parse(rawUrl);
      final host = uri.host;
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final sw   = Stopwatch()..start();
      final sock = await Socket.connect(host, port,
          timeout: const Duration(seconds: 5));
      sw.stop();
      sock.destroy();
      return sw.elapsedMilliseconds.toDouble();
    } catch (_) {
      return null;
    }
  }

  // ── Status Pages Fetching ───────────────────────────────────

  /// Normalizes URL to not have a trailing slash
  String _normalizeSpUrl(String url) {
    var u = url.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (!u.startsWith('http')) u = 'https://$u';
    return u;
  }

  Future<String?> validateStatusPage(String url) async {
    try {
      final u = _normalizeSpUrl(url);
      final response = await http.get(Uri.parse('$u/api/v2/status.json')).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('page') && data.containsKey('status')) {
        return data['page']['name'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> fetchStatusPageSummary(StatusPage sp) async {
    final dataObj = spDataFor(sp.id);
    dataObj.isLoading = true;
    notifyListeners();
    
    try {
      final u = _normalizeSpUrl(sp.url);
      final response = await http.get(Uri.parse('$u/api/v2/summary.json')).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        dataObj.pageName = data['page']['name'] ?? sp.name;
        dataObj.pageUrl = data['page']['url'] ?? u;
        dataObj.updatedAt = DateTime.tryParse(data['page']['updated_at'] ?? '');
        
        final statusInd = data['status']['indicator'] as String?;
        dataObj.indicator = _parseIndicator(statusInd);
        dataObj.statusDescription = data['status']['description'] ?? '';
        
        // Update components (always safe)
        dataObj.components = (data['components'] as List?)?.map((c) => SPComponent.fromJson(c)).toList() ?? [];

        // For incidents/maintenances: MERGE if we already have full details
        final newInc = (data['incidents'] as List?)?.map((i) => SPIncident.fromJson(i)).toList() ?? [];
        final newMaint = (data['scheduled_maintenances'] as List?)?.map((m) => SPMaintenance.fromJson(m)).toList() ?? [];

        if (dataObj.isDetailedFetched) {
          // Merge: Add new ones, update existing ones' statuses if changed
          _mergeIncidents(dataObj.incidents, newInc);
          _mergeMaintenances(dataObj.maintenances, newMaint);
        } else {
          dataObj.incidents = newInc;
          dataObj.maintenances = newMaint;
        }
        
        dataObj.error = null;
        _saveSPData();
      } else {
        dataObj.error = 'HTTP ${response.statusCode}';
      }
    } catch (e) {
      dataObj.error = e.toString();
    } finally {
      dataObj.isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStatusPageDetails(StatusPage sp) async {
    final dataObj = spDataFor(sp.id);
    dataObj.isLoading = true;
    notifyListeners();

    try {
      final u = _normalizeSpUrl(sp.url);
      
      // Fetch incidents & maintenances concurrently
      final futures = await Future.wait([
        http.get(Uri.parse('$u/api/v2/incidents.json')).timeout(const Duration(seconds: 10)),
        http.get(Uri.parse('$u/api/v2/scheduled-maintenances.json')).timeout(const Duration(seconds: 10)),
      ]);

      final incRes = futures[0];
      final maintRes = futures[1];

      if (incRes.statusCode == 200) {
        final data = jsonDecode(incRes.body);
        dataObj.incidents = (data['incidents'] as List?)?.map((i) => SPIncident.fromJson(i)).toList() ?? [];
      }
      
      if (maintRes.statusCode == 200) {
        final data = jsonDecode(maintRes.body);
        dataObj.maintenances = (data['scheduled_maintenances'] as List?)?.map((m) => SPMaintenance.fromJson(m)).toList() ?? [];
      }
      
      dataObj.isDetailedFetched = true;
      dataObj.error = null;
      _saveSPData();
    } catch (e) {
      dataObj.error = e.toString();
    } finally {
      dataObj.isLoading = false;
      notifyListeners();
    }
  }

  void _mergeIncidents(List<SPIncident> existing, List<SPIncident> incoming) {
    for (final inc in incoming) {
      final idx = existing.indexWhere((e) => e.id == inc.id);
      if (idx != -1) {
        existing[idx] = inc; // Update existing
      } else {
        existing.insert(0, inc); // Add new to top
      }
    }
  }

  void _mergeMaintenances(List<SPMaintenance> existing, List<SPMaintenance> incoming) {
    for (final maint in incoming) {
      final idx = existing.indexWhere((e) => e.id == maint.id);
      if (idx != -1) {
        existing[idx] = maint; // Update existing
      } else {
        existing.insert(0, maint); // Add new to top
      }
    }
  }

  StatusIndicator _parseIndicator(String? ind) {
    switch (ind) {
      case 'minor': return StatusIndicator.minor;
      case 'major': return StatusIndicator.major;
      case 'critical': return StatusIndicator.critical;
      case 'maintenance': return StatusIndicator.maintenance;
      default: return StatusIndicator.none;
    }
  }

  // ── Server CRUD ───────────────────────────────────────────
  Future<void> addServer(ServerWatcher server) async {
    server.order = _servers.length;
    _servers.add(server);
    await _saveServers();
    notifyListeners();
    // Kick off an immediate fetch
    fetchDataFor(server);
  }

  Future<void> updateServer(ServerWatcher updated) async {
    final idx = _servers.indexWhere((s) => s.id == updated.id);
    if (idx != -1) _servers[idx] = updated;
    await _saveServers();
    notifyListeners();
  }

  Future<void> deleteServer(String id) async {
    _servers.removeWhere((s) => s.id == id);
    _telemetry.remove(id);
    _serverVisibilityRefs.remove(id);
    // Re-index orders
    for (int i = 0; i < _servers.length; i++) {
      _servers[i].order = i;
    }
    await _saveServers();
    notifyListeners();
  }

  Future<void> reorderServers(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _servers.removeAt(oldIndex);
    _servers.insert(newIndex, item);
    for (int i = 0; i < _servers.length; i++) {
      _servers[i].order = i;
    }
    await _saveServers();
    notifyListeners();
  }

  // ── Status Page CRUD ────────────────────────────────────────
  Future<void> addStatusPage(StatusPage sp) async {
    sp.order = _statusPages.length;
    _statusPages.add(sp);
    await _saveStatusPages();
    notifyListeners();
    fetchStatusPageSummary(sp);
  }

  Future<void> updateStatusPage(StatusPage updated) async {
    final idx = _statusPages.indexWhere((s) => s.id == updated.id);
    if (idx != -1) _statusPages[idx] = updated;
    await _saveStatusPages();
    notifyListeners();
  }

  Future<void> deleteStatusPage(String id) async {
    _statusPages.removeWhere((s) => s.id == id);
    _spData.remove(id);
    for (int i = 0; i < _statusPages.length; i++) {
      _statusPages[i].order = i;
    }
    await _saveStatusPages();
    notifyListeners();
  }

  Future<void> reorderStatusPages(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _statusPages.removeAt(oldIndex);
    _statusPages.insert(newIndex, item);
    for (int i = 0; i < _statusPages.length; i++) {
      _statusPages[i].order = i;
    }
    await _saveStatusPages();
    notifyListeners();
  }

  // ── Formatting ────────────────────────────────────────────
  String formatBytes(double bytes, {bool isThroughput = false}) {
    double value = bytes;
    String unit = isThroughput ? (useBits ? 'b/s' : 'B/s') : 'B';

    if (useBits && isThroughput) value *= 8;

    const units = ['', 'k', 'M', 'G', 'T'];
    int unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    String prefix = units[unitIndex];
    if (useBits && isThroughput) prefix = prefix.toLowerCase();
    return '${value.toStringAsFixed(2)} $prefix$unit';
  }

  String _formatDuration(Duration d) {
    final days    = d.inDays > 0 ? '${d.inDays}d ' : '';
    final hours   = (d.inHours   % 24).toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$days$hours:$minutes:$seconds';
  }

  /// Build the display string for a given [ServerStat] from [telem].
  String statString(ServerStat stat, ServerTelemetry telem) {
    switch (stat) {
      case ServerStat.ping:
        return '${telem.lastPing.toStringAsFixed(0)} ms';
      case ServerStat.cpuLoad:
        return '${telem.cpuLoad.toStringAsFixed(1)}%';
      case ServerStat.cpuTemp:
        return '${telem.cpuTemp.toStringAsFixed(1)} °C';
      case ServerStat.ramPct:
        return '${(telem.memPct * 100).toStringAsFixed(1)}%';
      case ServerStat.ramUsed:
        return formatBytes(telem.memUsed);
      case ServerStat.ramUsedPct:
        return '${formatBytes(telem.memUsed)} (${(telem.memPct * 100).toStringAsFixed(1)}%)';
      case ServerStat.ramUsedTotal:
        return '${formatBytes(telem.memUsed)} / ${formatBytes(telem.memTotal)}';
      case ServerStat.ramAll:
        return '${formatBytes(telem.memUsed)} / ${formatBytes(telem.memTotal)} (${(telem.memPct * 100).toStringAsFixed(1)}%)';
      case ServerStat.netIn:
        return formatBytes(telem.netIn, isThroughput: true);
      case ServerStat.netOut:
        return formatBytes(telem.netOut, isThroughput: true);
      case ServerStat.netCombined:
        return '↑ ${formatBytes(telem.netIn, isThroughput: true)}  ↓ ${formatBytes(telem.netOut, isThroughput: true)}';
      case ServerStat.uptime:
        return telem.uptime;
    }
  }

  /// Which [TelemetryData] list corresponds to [GraphStat].
  List<TelemetryData> graphData(GraphStat stat, ServerTelemetry telem) {
    switch (stat) {
      case GraphStat.ping:    return telem.pings;
      case GraphStat.cpuLoad: return telem.loads;
      case GraphStat.cpuTemp: return telem.temps;
      case GraphStat.ramPct:  return telem.mems.map((d) =>
          TelemetryData(d.time, telem.memTotal > 0 ? (d.value / telem.memTotal) * 100 : 0)).toList();
      case GraphStat.netIn:   return telem.netIns;
      case GraphStat.netOut:  return telem.netOuts;
    }
  }

  // ── Persistence ───────────────────────────────────────────
  Future<void> _saveServers() async {
    final box = Hive.box('app_storage');
    final encoded = jsonEncode(_servers.map((s) => s.toJson()).toList());
    await box.put('servers_v2', encoded);
    if (_bgMonitorEnabled) await _syncBackgroundData();
  }

  Future<void> _loadServers() async {
    final box = Hive.box('app_storage');
    final raw = box.get('servers_v2') as String?;
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _servers = list.map((e) => ServerWatcher.fromJson(e as Map)).toList();
      _servers.sort((a, b) => a.order.compareTo(b.order));
    }
  }

  Future<void> _saveStatusPages() async {
    final box = Hive.box('app_storage');
    final encoded = jsonEncode(_statusPages.map((s) => s.toJson()).toList());
    await box.put('status_pages_v1', encoded);
    if (_bgMonitorEnabled) await _syncBackgroundData();
  }

  Future<void> _loadStatusPages() async {
    final box = Hive.box('app_storage');
    final raw = box.get('status_pages_v1') as String?;
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _statusPages = list.map((e) => StatusPage.fromJson(e as Map)).toList();
      _statusPages.sort((a, b) => a.order.compareTo(b.order));
    }
  }

  void saveDefaults() {
    _saveSettings();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final box = Hive.box('app_storage');
    await box.put('updateRate_v2', _updateRate);
    await box.put('useBits',       _useBits);
    await box.put('defaultTab',    _defaultTab);

    await box.put('defaultGraphStat', defaultGraphStat.index);
    await box.put('defaultTextStat1', defaultTextStat1?.index ?? -1);
    await box.put('defaultTextStat2', defaultTextStat2?.index ?? -1);
    await box.put('defaultGraphOrder', jsonEncode(defaultGraphOrder.map((g) => g.index).toList()));
  }

  Future<void> _loadSettings() async {
    final box = Hive.box('app_storage');
    _updateRate = (box.get('updateRate_v2', defaultValue: 1.0) as num).toDouble();
    _useBits    =  box.get('useBits',       defaultValue: false);
    _defaultTab =  box.get('defaultTab',    defaultValue: 0);

    defaultGraphStat = GraphStat.values[(box.get('defaultGraphStat', defaultValue: GraphStat.ping.index) as int).clamp(0, GraphStat.values.length - 1)];
    
    final ts1 = box.get('defaultTextStat1', defaultValue: ServerStat.ping.index) as int;
    defaultTextStat1 = ts1 == -1 ? null : ServerStat.values[ts1.clamp(0, ServerStat.values.length - 1)];
    
    final ts2 = box.get('defaultTextStat2', defaultValue: ServerStat.cpuLoad.index) as int;
    defaultTextStat2 = ts2 == -1 ? null : ServerStat.values[ts2.clamp(0, ServerStat.values.length - 1)];

    final rawOrder = box.get('defaultGraphOrder') as String?;
    if (rawOrder != null) {
      try {
        final list = jsonDecode(rawOrder) as List;
        defaultGraphOrder = list.map((i) => DetailGraph.values[(i as int).clamp(0, DetailGraph.values.length - 1)]).toList();
      } catch (_) {
        defaultGraphOrder = List.of(kDefaultGraphOrder);
      }
    } else {
      defaultGraphOrder = List.of(kDefaultGraphOrder);
    }
  }

  Future<void> _saveSPSettings() async {
    final box = Hive.box('app_storage');
    await box.put('sp_upcoming_days', spUpcomingDays);
    final orderIndices = spSectionOrder.map((s) => s.index).toList();
    await box.put('sp_section_order', jsonEncode(orderIndices));
    final disabledIndices = spSectionsDisabled.map((s) => s.index).toList();
    await box.put('sp_section_disabled', jsonEncode(disabledIndices));
  }

  Future<void> _loadSPSettings() async {
    final box = Hive.box('app_storage');
    spUpcomingDays = box.get('sp_upcoming_days', defaultValue: 3) as int;
    
    final rawOrder = box.get('sp_section_order') as String?;
    if (rawOrder != null) {
      try {
        final list = jsonDecode(rawOrder) as List;
        spSectionOrder = list.map((i) => DetailSection.values[(i as int).clamp(0, DetailSection.values.length - 1)]).toList();
        // Ensure all sections are present in case new ones were added
        for (final sec in DetailSection.values) {
          if (!spSectionOrder.contains(sec)) {
            spSectionOrder.add(sec);
          }
        }
      } catch (_) {
        // Fallback to default
      }
    }

    final rawDisabled = box.get('sp_section_disabled') as String?;
    if (rawDisabled != null) {
      try {
        final list = jsonDecode(rawDisabled) as List;
        spSectionsDisabled = list.map((i) => DetailSection.values[(i as int).clamp(0, DetailSection.values.length - 1)]).toSet();
      } catch (_) {}
    }
  }

  // ── Misc ──────────────────────────────────────────────────
  void genericRefresh() => notifyListeners();

  Future<void> log(String name, String type, String message) =>
      logger.log(name, type, message);

  @override
  void dispose() {
    _timer?.cancel();
    _spTimer?.cancel();
    _connectivityTimer?.cancel();
    super.dispose();
  }
  Future<void> _saveSPData() async {
    final box = Hive.box('app_storage');
    final Map<String, dynamic> encoded = {};
    _spData.forEach((key, value) {
      encoded[key] = value.toJson();
    });
    await box.put('sp_data_cache_v1', jsonEncode(encoded));
  }

  Future<void> _loadSPData() async {
    final box = Hive.box('app_storage');
    final raw = box.get('sp_data_cache_v1') as String?;
    if (raw != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        decoded.forEach((key, value) {
          _spData[key] = StatusPageData.fromJson(value as Map<String, dynamic>);
        });
      } catch (e) {
        logger.log('load_sp_data', 'error', e.toString());
      }
    }
  }
}
