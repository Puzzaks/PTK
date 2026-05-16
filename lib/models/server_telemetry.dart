import 'package:ptk/engine.dart';

/// Rolling telemetry for a single server.
/// Capped at [maxPoints] data points to keep memory bounded.
class ServerTelemetry {
  static const int maxPoints = 50;

  // ── Current scalar values ───────────────────────────────
  double cpuLoad  = 0;
  double cpuTemp  = 0;
  double memUsed  = 0;
  double memTotal = 0;
  double netIn    = 0;
  double netOut   = 0;
  String uptime   = '—';
  double lastPing = 0;

  // ── Rolling history ─────────────────────────────────────
  List<TelemetryData> pings   = [];
  List<TelemetryData> loads   = [];
  List<TelemetryData> temps   = [];
  List<TelemetryData> mems    = [];
  List<TelemetryData> netIns  = [];
  List<TelemetryData> netOuts = [];

  // ── State flags ──────────────────────────────────────────
  bool isDisconnected = false;
  /// True once the first successful AIO fetch has completed.
  bool isAioConfirmed = false;

  // ── Helpers ──────────────────────────────────────────────
  double get memPct => memTotal > 0 ? memUsed / memTotal : 0;

  void addPing(double ms) {
    lastPing = ms;
    _add(pings, ms);
  }

  void addLoad(double v)   => _add(loads,   v);
  void addTemp(double v)   => _add(temps,   v);
  void addMem(double v)    => _add(mems,    v);
  void addNetIn(double v)  => _add(netIns,  v);
  void addNetOut(double v) => _add(netOuts, v);

  void _add(List<TelemetryData> list, double value) {
    list.add(TelemetryData(DateTime.now(), value));
    if (list.length > maxPoints) list.removeAt(0);
  }

  void markDisconnected() {
    isDisconnected = true;
  }

  void markConnected() {
    isDisconnected = false;
  }
}
