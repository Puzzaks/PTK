import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AnalyticsService {
  bool analyticsEnabled = false;
  bool analyticsDone = true;
  List<Map> logs = [];
  final VoidCallback notifyEngine;

  AnalyticsService({required this.notifyEngine});

  Future<void> startAnalytics() async {
    final box = Hive.box('app_storage');
    await box.put("analytics", true);
    analyticsEnabled = true;
    analyticsDone = true;
    
    await log("application", "info", "Enabling analytics (Logging only)");
  }

  Future<void> stopAnalytics() async {
    final box = Hive.box('app_storage');
    await box.put("analytics", false);
    analyticsEnabled = false;
    
    await log("application", "info", "Disabling analytics");
  }

  Future<void> log(String name, String type, String message) async {
    if (logs.isEmpty) {
      logs.add({
        "thread": name,
        "time": DateTime.now().millisecondsSinceEpoch,
        "type": type,
        "message": message,
      });
    } else {
      if (logs.last["thread"] == name &&
          logs.last["type"] == type &&
          logs.last["message"] == message) {
        logs.last["time"] = DateTime.now().millisecondsSinceEpoch;
        if (kDebugMode) {
          // print("Still alive, did the last thing said above");
        }
      } else {
        logs.add({
          "thread": name,
          "time": DateTime.now().millisecondsSinceEpoch,
          "type": type,
          "message": message,
        });
        if (kDebugMode) {
          print("${type}_$name: $message");
        }
      }
    }
    
    // Bubble up to engine so UI can see the new logs
    notifyEngine();
  }

  Future<void> initFromHive() async {
    final box = Hive.box('app_storage');
    if (box.containsKey("analytics")) {
      analyticsEnabled = box.get("analytics", defaultValue: false);
      if (analyticsEnabled) {
        await startAnalytics();
      }
    } else {
      // Keep it disabled by default in this refactor
      analyticsEnabled = false;
    }
  }
}
