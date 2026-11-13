import 'dart:async';
import 'dart:io';
import 'package:m3x_mesh/m3x_mesh.dart';
import 'package:ptk/engine.dart';
import 'package:ptk/models/server_watcher.dart';
import 'package:ptk/models/status_page.dart';

/// Service implementing Puzzak Mesh tool calling capabilities for PTK.
class PtkMeshService {
  final AppEngine engine;

  PtkMeshService(this.engine);

  /// Registers all 7 PTK mesh tools into the local [client] registry.
  void registerTools(M3xMeshClient client) {
    for (final tool in tools) {
      client.localRegistry.register(tool);
    }
  }

  /// Declares all tools exposed by PTK to sibling mesh applications.
  List<M3xTool> get tools => [
        M3xTool(
          name: 'ptk_list_statuspages',
          app: 'ptk',
          description:
              'Lists all configured status pages monitored by PTK with overall health indicators and active incident counts.',
          parameters: const <String, dynamic>{
            'type': 'object',
            'properties': <String, dynamic>{},
          },
          handler: listStatusPages,
        ),
        M3xTool(
          name: 'ptk_get_statuspage_details',
          app: 'ptk',
          description:
              'Returns operational summary, status breakdown, degraded components, and active incidents for a specified StatusPage ID, name, or slug (e.g. "cloudflare").',
          parameters: const <String, dynamic>{
            'type': 'object',
            'properties': {
              'statuspage_id': {
                'type': 'string',
                'description':
                    'StatusPage identifier, name, or partial slug (e.g. "cloudflare").',
              },
              'include_all_components': {
                'type': 'boolean',
                'description':
                    'Optional (default false). Set true to include a capped component sample in addition to degraded components.',
              },
            },
            'required': ['statuspage_id'],
          },
          handler: getStatusPageDetails,
        ),
        M3xTool(
          name: 'ptk_list_incidents',
          app: 'ptk',
          description:
              "Returns paginated incidents with update descriptions truncated to 180 characters. statuspage_id is optional: omit or pass 'all' to check ALL statuspages at once. Never guess placeholder IDs like 'statuspage-1'.",
          parameters: const <String, dynamic>{
            'type': 'object',
            'properties': {
              'statuspage_id': {
                'type': 'string',
                'description':
                    "Optional. Omit or pass 'all' to check ALL statuspages at once. Never guess placeholder IDs like 'statuspage-1'.",
              },
              'status': {
                'type': 'string',
                'enum': ['active', 'all'],
                'description': 'Filter by status: "active" (default) or "all".',
              },
              'page': {
                'type': 'integer',
                'description': 'Page number (1-based, default 1).',
              },
              'offset': {
                'type': 'integer',
                'description': 'Optional 0-based item offset (overrides page if provided).',
              },
              'limit': {
                'type': 'integer',
                'description': 'Max items to return (default 5, max 10).',
              },
            },
          },
          handler: listIncidents,
        ),
        M3xTool(
          name: 'ptk_get_incident_details',
          app: 'ptk',
          description:
              'Returns full chronological update timeline and affected components for the specified incident.',
          parameters: const <String, dynamic>{
            'type': 'object',
            'properties': {
              'statuspage_id': {
                'type': 'string',
                'description':
                    'Optional StatusPage ID, name, or slug. Omit or pass "all" to search all monitored status pages.',
              },
              'incident_id': {
                'type': 'string',
                'description': 'Unique identifier of the incident.',
              },
            },
            'required': ['incident_id'],
          },
          handler: getIncidentDetails,
        ),
        M3xTool(
          name: 'ptk_ping',
          app: 'ptk',
          description:
              'Runs unprivileged TCP/Socket latency checks to a destination host and port.',
          parameters: const <String, dynamic>{
            'type': 'object',
            'properties': {
              'host': {
                'type': 'string',
                'description': 'Target hostname or IP address.',
              },
              'port': {
                'type': 'integer',
                'description': 'Target port (default 443).',
              },
              'count': {
                'type': 'integer',
                'description': 'Number of ping probes (default 3).',
              },
            },
            'required': ['host'],
          },
          handler: ping,
        ),
        M3xTool(
          name: 'ptk_list_servers',
          app: 'ptk',
          description:
              'Lists all monitored server endpoints in PTK with connection status and last ping latency.',
          parameters: const <String, dynamic>{
            'type': 'object',
            'properties': <String, dynamic>{},
          },
          handler: listServers,
        ),
        M3xTool(
          name: 'ptk_get_server_telemetry',
          app: 'ptk',
          description:
              'Returns scalar metrics for a specified server (CPU load/temp, RAM used/total, net throughput, uptime).',
          parameters: const <String, dynamic>{
            'type': 'object',
            'properties': {
              'server_id': {
                'type': 'string',
                'description': 'Server identifier, name, or partial hostname.',
              },
            },
            'required': ['server_id'],
          },
          handler: getServerTelemetry,
        ),
      ];

  StatusPage? _resolveStatusPage(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;

    // 1. Exact ID (case-insensitive)
    for (final sp in engine.statusPages) {
      if (sp.id.toLowerCase() == q) return sp;
    }
    // 2. Exact name (case-insensitive)
    for (final sp in engine.statusPages) {
      if (sp.name.trim().toLowerCase() == q) return sp;
    }
    // 3. Partial match against id, name, or url (e.g. "cloudflare" -> "seed_cloudflare_...")
    for (final sp in engine.statusPages) {
      final idLow = sp.id.toLowerCase();
      final nameLow = sp.name.toLowerCase();
      final urlLow = sp.url.toLowerCase();
      if (idLow.contains(q) || nameLow.contains(q) || urlLow.contains(q)) {
        return sp;
      }
    }
    return null;
  }

  ServerWatcher? _resolveServer(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;

    for (final s in engine.servers) {
      if (s.id.toLowerCase() == q) return s;
    }
    for (final s in engine.servers) {
      if (s.name.trim().toLowerCase() == q) return s;
    }
    for (final s in engine.servers) {
      if (s.id.toLowerCase().contains(q) ||
          s.name.toLowerCase().contains(q) ||
          s.url.toLowerCase().contains(q)) {
        return s;
      }
    }
    return null;
  }

  List<Map<String, String>> _availableStatusPagesSummary() {
    return engine.statusPages
        .map((s) => <String, String>{'id': s.id, 'name': s.name})
        .toList();
  }

  Map<String, dynamic> _statusPageNotFound(String idArg) {
    return <String, dynamic>{
      'found': false,
      'error': idArg.isEmpty
          ? 'statuspage_id is required.'
          : "StatusPage '$idArg' not found in PTK.",
      'available_statuspages': _availableStatusPagesSummary(),
    };
  }

  Future<void> _ensureDetailsFetched(StatusPage sp) async {
    final data = engine.spDataFor(sp.id);
    if (data.isDetailedFetched) return;
    try {
      await engine
          .fetchStatusPageDetails(sp)
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  /// Reads `engine.statusPages`, returns `List<{id, name, url, indicator, active_incidents}>`.
  Future<Map<String, dynamic>> listStatusPages(Map<String, dynamic> args) async {
    // If running headless/cold with no cached summary yet, perform a quick bounded refresh.
    final needsInitialFetch = engine.statusPages.where((sp) {
      final d = engine.spDataFor(sp.id);
      return d.updatedAt == null && d.components.isEmpty && d.incidents.isEmpty;
    }).toList();
    if (needsInitialFetch.isNotEmpty) {
      await Future.wait(
        needsInitialFetch.map(
          (sp) => engine
              .fetchStatusPageSummary(sp)
              .timeout(const Duration(seconds: 4), onTimeout: () {}),
        ),
      );
    }

    final list = engine.statusPages.map((sp) {
      final data = engine.spDataFor(sp.id);
      final activeIncidents = data.incidents
          .where((i) =>
              i.status != IncidentStatus.resolved &&
              i.status != IncidentStatus.postmortem)
          .length;
      return <String, dynamic>{
        'id': sp.id,
        'name': sp.name,
        'url': sp.url,
        'indicator': data.indicator.name,
        'active_incidents': activeIncidents,
      };
    }).toList();

    return <String, dynamic>{
      'statuspages': list,
      'count': list.length,
    };
  }

  static String _componentStatusKey(ComponentStatus status) {
    switch (status) {
      case ComponentStatus.operational:
        return 'operational';
      case ComponentStatus.degradedPerformance:
        return 'degraded_performance';
      case ComponentStatus.partialOutage:
        return 'partial_outage';
      case ComponentStatus.majorOutage:
        return 'major_outage';
      case ComponentStatus.underMaintenance:
        return 'under_maintenance';
    }
  }

  /// Returns status summary, breakdown, non-operational components, and active incidents from `engine.spDataFor(id)`.
  Future<Map<String, dynamic>> getStatusPageDetails(Map<String, dynamic> args) async {
    final idArg = args['statuspage_id']?.toString().trim() ?? '';
    if (idArg.isEmpty) {
      return _statusPageNotFound(idArg);
    }

    final sp = _resolveStatusPage(idArg);
    if (sp == null) {
      return _statusPageNotFound(idArg);
    }

    final data = engine.spDataFor(sp.id);
    if (data.components.isEmpty && !data.isDetailedFetched) {
      await _ensureDetailsFetched(sp);
    }

    final includeAll = args['include_all_components'] == true ||
        args['include_all_components']?.toString().toLowerCase() == 'true';

    final activeIncidentsList = data.incidents
        .where((i) =>
            i.status != IncidentStatus.resolved &&
            i.status != IncidentStatus.postmortem)
        .toList();

    final statusBreakdown = <String, int>{};
    int operationalCount = 0;
    final nonOperational = <SPComponent>[];
    for (final c in data.components) {
      final key = _componentStatusKey(c.status);
      statusBreakdown[key] = (statusBreakdown[key] ?? 0) + 1;
      if (c.status == ComponentStatus.operational) {
        operationalCount++;
      } else {
        nonOperational.add(c);
      }
    }

    const int maxDegraded = 25;
    final bool truncatedDegraded = nonOperational.length > maxDegraded;
    final degradedComponents = nonOperational.take(maxDegraded).map((c) => <String, dynamic>{
          'id': c.id,
          'name': c.name,
          'status': _componentStatusKey(c.status),
          'group': c.group,
          if (c.groupId != null) 'group_id': c.groupId,
          if (c.description != null && c.description!.isNotEmpty) 'description': c.description,
        }).toList();

    final activeIncidentsSummary = activeIncidentsList.map((i) {
      final updatedAt = i.updates.isNotEmpty
          ? i.updates.map((u) => u.createdAt).reduce((a, b) => a.isAfter(b) ? a : b)
          : i.createdAt;
      return <String, dynamic>{
        'id': i.id,
        'name': i.name,
        'impact': i.impact.name,
        'status': i.status.name,
        'updated_at': updatedAt.toIso8601String(),
      };
    }).toList();

    const int maxAllComponents = 50;
    final bool truncatedAll = includeAll && data.components.length > maxAllComponents;

    return <String, dynamic>{
      'updated_at': data.updatedAt?.toIso8601String(),
      'summary': <String, dynamic>{
        'name': sp.name,
        'id': sp.id,
        'url': sp.url,
        'indicator': data.indicator.name,
        'description': data.statusDescription,
        'total_components': data.components.length,
        'operational_components': operationalCount,
        'degraded_components_count': nonOperational.length,
        'active_incidents_count': activeIncidentsList.length,
        'scheduled_maintenances': data.maintenances.length,
      },
      'status_breakdown': statusBreakdown,
      'degraded_components': degradedComponents,
      if (truncatedDegraded) 'truncated_degraded_components': true,
      'active_incidents': activeIncidentsSummary,
      if (includeAll) ...<String, dynamic>{
        'components': data.components.take(maxAllComponents).map((c) => <String, dynamic>{
              'id': c.id,
              'name': c.name,
              'status': _componentStatusKey(c.status),
              'group': c.group,
            }).toList(),
        if (truncatedAll) 'truncated_all_components': true,
      },
    };
  }

  /// Returns paginated list of incidents (either for a single statuspage or aggregated across all).
  Future<Map<String, dynamic>> listIncidents(Map<String, dynamic> args) async {
    final idArg = args['statuspage_id']?.toString().trim() ?? '';
    final bool aggregateAll = idArg.isEmpty || idArg.toLowerCase() == 'all' || idArg == '*';

    final List<StatusPage> targetPages;
    if (aggregateAll) {
      targetPages = List<StatusPage>.from(engine.statusPages);
    } else {
      final sp = _resolveStatusPage(idArg);
      if (sp == null) {
        return _statusPageNotFound(idArg);
      }
      targetPages = [sp];
    }

    await Future.wait(targetPages.map(_ensureDetailsFetched));

    final statusFilter = (args['status']?.toString() ?? 'active').toLowerCase().trim();
    final int page = (args['page'] is int)
        ? (args['page'] as int)
        : int.tryParse(args['page']?.toString() ?? '1') ?? 1;
    final int? explicitOffset = args.containsKey('offset') && args['offset'] != null
        ? ((args['offset'] is int)
            ? (args['offset'] as int)
            : int.tryParse(args['offset'].toString()))
        : null;
    final int rawLimit = (args['limit'] is int)
        ? (args['limit'] as int)
        : int.tryParse(args['limit']?.toString() ?? '5') ?? 5;

    final safePage = page < 1 ? 1 : page;
    final safeLimit = rawLimit.clamp(1, 10);
    final effectiveOffset = (explicitOffset ?? ((safePage - 1) * safeLimit)).clamp(0, 100000);

    final List<({StatusPage page, SPIncident incident})> matched = [];
    for (final sp in targetPages) {
      final data = engine.spDataFor(sp.id);
      for (final inc in data.incidents) {
        final isActive = inc.status != IncidentStatus.resolved &&
            inc.status != IncidentStatus.postmortem;
        if (statusFilter == 'all' || isActive) {
          matched.add((page: sp, incident: inc));
        }
      }
    }

    matched.sort((a, b) => b.incident.createdAt.compareTo(a.incident.createdAt));

    final startIndex = effectiveOffset.clamp(0, matched.length);
    final endIndex = (startIndex + safeLimit).clamp(0, matched.length);
    final paged = matched.sublist(startIndex, endIndex);

    return <String, dynamic>{
      'statuspage_id': aggregateAll ? 'all' : targetPages.first.id,
      if (!aggregateAll) 'statuspage_name': targetPages.first.name,
      'statuspages_checked': targetPages.length,
      'status_filter': statusFilter,
      'total': matched.length,
      'page': safePage,
      'offset': startIndex,
      'limit': safeLimit,
      'incidents': paged.map((entry) {
        final i = entry.incident;
        final body = i.updates.isNotEmpty ? i.updates.first.body : '';
        final truncated = body.length > 180 ? '${body.substring(0, 180)}...' : body;
        return <String, dynamic>{
          'statuspage_id': entry.page.id,
          'statuspage_name': entry.page.name,
          'id': i.id,
          'name': i.name,
          'status': i.status.name,
          'impact': i.impact.name,
          'created_at': i.createdAt.toIso8601String(),
          if (i.resolvedAt != null) 'resolved_at': i.resolvedAt!.toIso8601String(),
          'body': truncated,
          'updates_count': i.updates.length,
        };
      }).toList(),
    };
  }

  /// Returns full chronological update timeline for the specified incident.
  Future<Map<String, dynamic>> getIncidentDetails(Map<String, dynamic> args) async {
    final spIdArg = args['statuspage_id']?.toString().trim() ?? '';
    final incIdArg = args['incident_id']?.toString().trim() ?? '';

    if (incIdArg.isEmpty) {
      return <String, dynamic>{
        'found': false,
        'error': 'incident_id is required.',
        'available_statuspages': _availableStatusPagesSummary(),
      };
    }

    final bool searchAll = spIdArg.isEmpty || spIdArg.toLowerCase() == 'all' || spIdArg == '*';
    final List<StatusPage> searchPages;
    if (searchAll) {
      searchPages = List<StatusPage>.from(engine.statusPages);
    } else {
      final sp = _resolveStatusPage(spIdArg);
      if (sp == null) {
        return _statusPageNotFound(spIdArg);
      }
      searchPages = [sp];
    }

    await Future.wait(searchPages.map(_ensureDetailsFetched));

    StatusPage? matchedPage;
    SPIncident? matchedIncident;
    final List<Map<String, String>> availableIncidents = [];

    for (final sp in searchPages) {
      final data = engine.spDataFor(sp.id);
      for (final inc in data.incidents) {
        if (inc.id == incIdArg || inc.id.toLowerCase() == incIdArg.toLowerCase()) {
          matchedPage = sp;
          matchedIncident = inc;
          break;
        }
        if (availableIncidents.length < 10) {
          availableIncidents.add(<String, String>{
            'statuspage_id': sp.id,
            'id': inc.id,
            'name': inc.name,
            'status': inc.status.name,
          });
        }
      }
      if (matchedIncident != null) break;
    }

    if (matchedIncident == null || matchedPage == null) {
      return <String, dynamic>{
        'found': false,
        'error': "Incident '$incIdArg' not found.",
        'available_incidents': availableIncidents,
      };
    }

    final chronologicalUpdates = List<SPIncidentUpdate>.from(matchedIncident.updates)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return <String, dynamic>{
      'statuspage_id': matchedPage.id,
      'statuspage_name': matchedPage.name,
      'incident_id': matchedIncident.id,
      'name': matchedIncident.name,
      'status': matchedIncident.status.name,
      'impact': matchedIncident.impact.name,
      'created_at': matchedIncident.createdAt.toIso8601String(),
      if (matchedIncident.resolvedAt != null)
        'resolved_at': matchedIncident.resolvedAt!.toIso8601String(),
      'timeline': chronologicalUpdates.map((u) => <String, dynamic>{
        'id': u.id,
        'status': u.status,
        'body': u.body,
        'created_at': u.createdAt.toIso8601String(),
        'affected_components': u.affectedComponents.map((c) => <String, dynamic>{
          'code': c.code,
          'name': c.name,
          'old_status': c.oldStatus.name,
          'new_status': c.newStatus.name,
        }).toList(),
      }).toList(),
    };
  }

  /// Runs unprivileged `Socket.connect` latency checks, returns `{host, port, success, min_ms, avg_ms, max_ms, packet_loss}`.
  Future<Map<String, dynamic>> ping(Map<String, dynamic> args) async {
    final rawHost = args['host']?.toString().trim() ?? '';
    if (rawHost.isEmpty) {
      return <String, dynamic>{
        'success': false,
        'error': 'host is required',
      };
    }

    var port = (args['port'] is int)
        ? (args['port'] as int)
        : int.tryParse(args['port']?.toString() ?? '443') ?? 443;
    final count = (args['count'] is int)
        ? (args['count'] as int)
        : int.tryParse(args['count']?.toString() ?? '3') ?? 3;

    String host = rawHost;
    if (host.startsWith('http://') || host.startsWith('https://')) {
      final parsed = Uri.tryParse(host);
      if (parsed != null && parsed.host.isNotEmpty) {
        if (parsed.hasPort) {
          port = parsed.port;
        } else if (parsed.scheme == 'http' && port == 443) {
          port = 80;
        }
        host = parsed.host;
      }
    }

    final latencies = <double>[];
    int successful = 0;
    final safeCount = count.clamp(1, 10);

    for (int i = 0; i < safeCount; i++) {
      final sw = Stopwatch()..start();
      try {
        final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 4));
        sw.stop();
        socket.destroy();
        latencies.add(sw.elapsedMicroseconds / 1000.0);
        successful++;
      } catch (_) {
        sw.stop();
      }
    }

    final bool success = successful > 0;
    final double packetLoss = safeCount > 0 ? ((safeCount - successful) / safeCount) * 100.0 : 100.0;
    final double minMs = latencies.isNotEmpty ? latencies.reduce((a, b) => a < b ? a : b) : 0.0;
    final double maxMs = latencies.isNotEmpty ? latencies.reduce((a, b) => a > b ? a : b) : 0.0;
    final double avgMs = latencies.isNotEmpty ? latencies.reduce((a, b) => a + b) / latencies.length : 0.0;

    return <String, dynamic>{
      'host': host,
      'port': port,
      'count': safeCount,
      'transmitted': safeCount,
      'received': successful,
      'success': success,
      'min_ms': double.parse(minMs.toStringAsFixed(2)),
      'avg_ms': double.parse(avgMs.toStringAsFixed(2)),
      'max_ms': double.parse(maxMs.toStringAsFixed(2)),
      'packet_loss': double.parse(packetLoss.toStringAsFixed(1)),
    };
  }

  /// Reads `engine.servers`, returns `List<{id, name, url, is_online, last_ping_ms, is_aio}>`.
  Future<Map<String, dynamic>> listServers(Map<String, dynamic> args) async {
    final list = engine.servers.map((s) {
      final telem = engine.telemetryFor(s.id);
      return <String, dynamic>{
        'id': s.id,
        'name': s.name,
        'url': s.url,
        'is_online': !telem.isDisconnected,
        'last_ping_ms': telem.lastPing,
        'is_aio': s.isAio,
      };
    }).toList();

    return <String, dynamic>{
      'servers': list,
      'count': list.length,
    };
  }

  /// Returns scalar metrics for that server (CPU load/temp, RAM used/total, net throughput, uptime).
  Future<Map<String, dynamic>> getServerTelemetry(Map<String, dynamic> args) async {
    final serverId = args['server_id']?.toString().trim() ?? '';
    if (serverId.isEmpty) {
      return <String, dynamic>{
        'found': false,
        'error': 'server_id is required.',
        'available_servers': engine.servers
            .map((s) => {'id': s.id, 'name': s.name})
            .toList(),
      };
    }

    final server = _resolveServer(serverId);
    if (server == null) {
      return <String, dynamic>{
        'found': false,
        'error': "Server '$serverId' not found in PTK.",
        'available_servers': engine.servers
            .map((s) => {'id': s.id, 'name': s.name})
            .toList(),
      };
    }

    final telem = engine.telemetryFor(server.id);

    return <String, dynamic>{
      'server_id': server.id,
      'name': server.name,
      'url': server.url,
      'is_online': !telem.isDisconnected,
      'is_aio': server.isAio,
      'last_ping_ms': telem.lastPing,
      'cpu_load': telem.cpuLoad,
      'cpu_temp': telem.cpuTemp,
      'ram_used': telem.memUsed,
      'ram_total': telem.memTotal,
      'ram_pct': double.parse((telem.memPct * 100.0).toStringAsFixed(1)),
      'net_in': telem.netIn,
      'net_out': telem.netOut,
      'uptime': telem.uptime,
    };
  }
}
