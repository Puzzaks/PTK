import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as md;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:PTK/pages/support/elements.dart';
import 'package:PTK/parts/translator.dart';
import 'package:PTK/storage/analytics_service.dart';

class TelemetryData {
  final DateTime time;
  final double value;
  TelemetryData(this.time, this.value);
}

class AppEngine with md.ChangeNotifier {
  late Cards cards;

  Dictionary dict = Dictionary(
    path: "assets/translations",
    url: "",
  );

  bool appStarted = false;
  late final AnalyticsService logger;

  AppEngine() {
    logger = AnalyticsService(notifyEngine: genericRefresh);
  }

  List<Map> get logs => logger.logs;

  // Telemetry State
  String _loc = "https://api.puzzak.page/AIO.php";
  String get loc => _loc;
  set loc(String v) {
    _loc = v;
    _saveSettings();
    notifyListeners();
  }

  int _updateRate = 1;
  int get updateRate => _updateRate;
  set updateRate(int v) {
    _updateRate = v;
    _saveSettings();
    _startTimer();
    notifyListeners();
  }

  bool _isAutoUpdate = true;
  bool get isAutoUpdate => _isAutoUpdate;
  set isAutoUpdate(bool v) {
    _isAutoUpdate = v;
    _saveSettings();
    _startTimer();
    notifyListeners();
  }

  bool _useBits = false;
  bool get useBits => _useBits;
  set useBits(bool v) {
    _useBits = v;
    _saveSettings();
    notifyListeners();
  }

  double cpuload = 0;
  double cpuTemp = 0;
  double memused = 0;
  double memtotal = 0;
  String uptime = "0";
  double netIn = 0;
  double netOut = 0;
  bool isDisconnected = false;

  List<TelemetryData> pings = [];
  List<TelemetryData> loads = [];
  List<TelemetryData> temps = [];
  List<TelemetryData> mems = [];
  List<TelemetryData> netIns = [];
  List<TelemetryData> netOuts = [];

  Timer? _timer;

  Future<void> start() async {
    await Hive.initFlutter();
    await Hive.openBox('app_storage');

    await logger.initFromHive();
    await _loadSettings();
    await dict.setup(log: logger.log);

    await fetchData();
    _startTimer();

    await logger.log("init", "info", "App started");
    appStarted = true;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_isAutoUpdate) {
      _timer = Timer.periodic(Duration(seconds: _updateRate), (timer) {
        fetchData();
      });
    }
  }

  Future<void> fetchData() async {
    try {
      final startTime = DateTime.now();
      final response = await http.get(Uri.parse(_loc)).timeout(const Duration(seconds: 5));
      final endTime = DateTime.now();
      final ping = endTime.difference(startTime).inMilliseconds.toDouble();

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        cpuload = (data["util"] ?? 0).toDouble();
        cpuTemp = (data["temp"] ?? 0).toDouble();
        
        // Memory parsing (memo["total"], memo["avail"] as strings in KB)
        var memo = data["memo"] ?? {};
        memtotal = (double.tryParse(memo["total"]?.toString() ?? "0") ?? 0) * 1024;
        double memavail = (double.tryParse(memo["avail"]?.toString() ?? "0") ?? 0) * 1024;
        memused = memtotal - memavail;

        // Format Uptime
        int uptimeRaw = (data["uptime"] ?? 0).toInt();
        if (uptimeRaw > 1000000000) { // Likely a timestamp
           DateTime start = DateTime.fromMillisecondsSinceEpoch(uptimeRaw * 1000);
           Duration diff = DateTime.now().difference(start);
           uptime = _formatDuration(diff);
        } else {
           uptime = _formatDuration(Duration(seconds: uptimeRaw));
        }

        // Network parsing (netspd["in"], netspd["out"])
        var netspd = data["netspd"] ?? {};
        netIn = (netspd["in"] ?? 0).toDouble(); // Keep raw bytes/s
        netOut = (netspd["out"] ?? 0).toDouble(); 
        isDisconnected = false;

        if (kDebugMode) {
          print("Telemetry: CPU=$cpuload, Temp=$cpuTemp, MEM=$memused/$memtotal, Net=$netIn/$netOut");
        }

        final now = DateTime.now();
        _addDataPoint(pings, TelemetryData(now, ping));
        _addDataPoint(loads, TelemetryData(now, cpuload));
        _addDataPoint(temps, TelemetryData(now, cpuTemp));
        _addDataPoint(mems, TelemetryData(now, memused));
        _addDataPoint(netIns, TelemetryData(now, netIn));
        _addDataPoint(netOuts, TelemetryData(now, netOut));
      } else {
        isDisconnected = true;
      }
    } catch (e) {
      isDisconnected = true;
      logger.log("fetch", "error", "Failed to fetch data: $e");
    }
    notifyListeners();
  }

  String formatBytes(double bytes, {bool isThroughput = false}) {
    double value = bytes;
    String unit = isThroughput ? (useBits ? "b/s" : "B/s") : "B";
    
    if (useBits && isThroughput) {
      value = value * 8;
    }

    const units = ["", "k", "M", "G", "T"];
    int unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    String prefix = units[unitIndex];
    if (useBits && isThroughput) prefix = prefix.toLowerCase();
    
    return "${value.toStringAsFixed(2)} $prefix$unit";
  }

  String _formatDuration(Duration d) {
    String days = d.inDays > 0 ? "${d.inDays}d " : "";
    String hours = (d.inHours % 24).toString().padLeft(2, '0');
    String minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$days$hours:$minutes:$seconds";
  }

  void _addDataPoint(List<TelemetryData> list, TelemetryData data) {
    list.add(data);
    if (list.length > 50) {
      list.removeAt(0);
    }
  }

  void genericRefresh() => notifyListeners();

  Future<void> log(String name, String type, String message) =>
      logger.log(name, type, message);

  Future<void> _saveSettings() async {
    final box = Hive.box('app_storage');
    await box.put('loc', _loc);
    await box.put('updateRate', _updateRate);
    await box.put('isAutoUpdate', _isAutoUpdate);
    await box.put('useBits', _useBits);
  }

  Future<void> _loadSettings() async {
    final box = Hive.box('app_storage');
    _loc = box.get('loc', defaultValue: "https://api.puzzak.page/AIO.php");
    _updateRate = box.get('updateRate', defaultValue: 1);
    _isAutoUpdate = box.get('isAutoUpdate', defaultValue: true);
    _useBits = box.get('useBits', defaultValue: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
