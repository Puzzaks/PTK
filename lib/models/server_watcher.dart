// ─────────────────────────────────────────────────────────
// ServerWatcher — one configured server entry
// ServerStat    — what to display on the server card
// ─────────────────────────────────────────────────────────

/// All stat types that can be displayed as text on a server card.
/// Combined variants are only meaningful for AIO-enabled servers.
/// null means "nothing" (empty slot).
enum ServerStat {
  ping,            // "32 ms"
  cpuLoad,         // "47.3%"
  cpuTemp,         // "62.1 °C"
  ramPct,          // "57%"
  ramUsed,         // "4.6 GB"
  ramUsedPct,      // "4.6 GB (57%)"
  ramUsedTotal,    // "4.6 GB / 8 GB"
  ramAll,          // "4.6 GB / 8 GB (57%)"
  netIn,           // "1.2 MB/s"
  netOut,          // "340 KB/s"
  netCombined,     // "↑ 1.2 MB/s  ↓ 340 KB/s"
  uptime,          // "2d 03:14:07"
}

/// Subset of stats that can be used as the background graph line.
/// Must be a single numeric series — combined / text-only stats excluded.
enum GraphStat {
  ping,
  cpuLoad,
  cpuTemp,
  ramPct,
  netIn,
  netOut,
}

/// Names of all graphs shown in the detail view (for ordering).
enum DetailGraph {
  ping,
  cpuLoad,
  cpuTemp,
  ram,
  netIn,
  netOut,
}

extension DetailGraphLabel on DetailGraph {
  String get label {
    switch (this) {
      case DetailGraph.ping:    return 'Ping';
      case DetailGraph.cpuLoad: return 'CPU Load';
      case DetailGraph.cpuTemp: return 'SoC Temperature';
      case DetailGraph.ram:     return 'RAM Usage';
      case DetailGraph.netIn:   return 'Throughput (In)';
      case DetailGraph.netOut:  return 'Throughput (Out)';
    }
  }
}

extension ServerStatLabel on ServerStat {
  String get label {
    switch (this) {
      case ServerStat.ping:         return 'Ping';
      case ServerStat.cpuLoad:      return 'CPU Load';
      case ServerStat.cpuTemp:      return 'SoC Temp';
      case ServerStat.ramPct:       return 'RAM %';
      case ServerStat.ramUsed:      return 'RAM Used';
      case ServerStat.ramUsedPct:   return 'RAM Used + %';
      case ServerStat.ramUsedTotal: return 'RAM Used + Total';
      case ServerStat.ramAll:       return 'RAM Used + Total + %';
      case ServerStat.netIn:        return 'Net In';
      case ServerStat.netOut:       return 'Net Out';
      case ServerStat.netCombined:  return 'Net Combined';
      case ServerStat.uptime:       return 'Uptime';
    }
  }
}

extension GraphStatLabel on GraphStat {
  String get label {
    switch (this) {
      case GraphStat.ping:    return 'Ping';
      case GraphStat.cpuLoad: return 'CPU Load';
      case GraphStat.cpuTemp: return 'SoC Temp';
      case GraphStat.ramPct:  return 'RAM %';
      case GraphStat.netIn:   return 'Net In';
      case GraphStat.netOut:  return 'Net Out';
    }
  }
}

/// Default graph order for new AIO servers.
const List<DetailGraph> kDefaultGraphOrder = [
  DetailGraph.ping,
  DetailGraph.cpuLoad,
  DetailGraph.cpuTemp,
  DetailGraph.ram,
  DetailGraph.netIn,
  DetailGraph.netOut,
];

class ServerWatcher {
  final String id;
  String name;
  String url;
  bool isAio;
  int order;

  /// Which stat to draw as the background graph on the list card. null = app default
  GraphStat? graphStat;

  /// First text stat overlay on the list card. null = app default
  ServerStat? textStat1;

  /// Second text stat overlay on the list card. null = app default
  ServerStat? textStat2;

  /// Ordered list of graphs to show on the detail page (AIO only). null = app default
  List<DetailGraph>? graphOrder;

  /// Background monitoring override. null = use global default, true/false = override
  bool? bgMonitor;

  ServerWatcher({
    required this.id,
    required this.name,
    required this.url,
    this.isAio = false,
    required this.order,
    this.graphStat,
    this.textStat1,
    this.textStat2,
    this.graphOrder,
    this.bgMonitor,
  });

  // ── JSON serialisation ──────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id':         id,
        'name':       name,
        'url':        url,
        'isAio':      isAio,
        'order':      order,
        'graphStat':  graphStat?.index,
        'textStat1':  textStat1?.index,
        'textStat2':  textStat2?.index,
        'graphOrder': graphOrder?.map((g) => g.index).toList(),
        'bgMonitor':  bgMonitor,
      };

  factory ServerWatcher.fromJson(Map<dynamic, dynamic> json) {
    final goRaw = json['graphOrder'] as List?;
    final goList = goRaw?.map((i) => DetailGraph.values[(i as int).clamp(0, DetailGraph.values.length - 1)]).toList();

    final gsRaw = json['graphStat'];
    final ts1Raw = json['textStat1'];
    final ts2Raw = json['textStat2'];

    return ServerWatcher(
      id:         json['id']   as String,
      name:       json['name'] as String,
      url:        json['url']  as String,
      isAio:      json['isAio'] as bool? ?? false,
      order:      json['order'] as int,
      graphStat:  gsRaw != null ? GraphStat.values[(gsRaw as int).clamp(0, GraphStat.values.length - 1)] : null,
      textStat1:  ts1Raw != null ? ServerStat.values[(ts1Raw as int).clamp(0, ServerStat.values.length - 1)] : null,
      textStat2:  ts2Raw != null ? ServerStat.values[(ts2Raw as int).clamp(0, ServerStat.values.length - 1)] : null,
      graphOrder: goList,
      bgMonitor:  json['bgMonitor'] as bool?,
    );
  }

  ServerWatcher copyWith({
    String? name,
    String? url,
    bool? isAio,
    int? order,
    Object? graphStat = _sentinel,
    Object? textStat1 = _sentinel,
    Object? textStat2 = _sentinel,
    Object? graphOrder = _sentinel,
    Object? bgMonitor = _sentinel,
  }) =>
      ServerWatcher(
        id:         id,
        name:       name       ?? this.name,
        url:        url        ?? this.url,
        isAio:      isAio      ?? this.isAio,
        order:      order      ?? this.order,
        graphStat:  graphStat == _sentinel ? this.graphStat : (graphStat as GraphStat?),
        textStat1:  textStat1 == _sentinel ? this.textStat1 : (textStat1 as ServerStat?),
        textStat2:  textStat2 == _sentinel ? this.textStat2 : (textStat2 as ServerStat?),
        graphOrder: graphOrder == _sentinel ? this.graphOrder : (graphOrder as List<DetailGraph>?),
        bgMonitor:  bgMonitor == _sentinel ? this.bgMonitor : (bgMonitor as bool?),
      );
}

const Object _sentinel = Object();
