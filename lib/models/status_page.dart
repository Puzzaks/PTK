// ─────────────────────────────────────────────────────────
// StatusPage models for Atlassian Statuspage API v2
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

enum StatusIndicator { none, minor, major, critical, maintenance }

extension StatusIndicatorColors on StatusIndicator {
  Color get color {
    switch (this) {
      case StatusIndicator.none:
        return Colors.green;
      case StatusIndicator.minor:
        return Colors.yellow.shade700;
      case StatusIndicator.major:
        return Colors.orange;
      case StatusIndicator.critical:
        return Colors.red;
      case StatusIndicator.maintenance:
        return Colors.blue;
    }
  }
}

enum ComponentStatus { operational, degradedPerformance, partialOutage, majorOutage, underMaintenance }

enum IncidentStatus { investigating, identified, monitoring, resolved, postmortem }

enum IncidentImpact { none, minor, major, critical }

enum MaintenanceStatus { scheduled, inProgress, verifying, completed }

enum DetailSection {
  currentIncidents,
  currentMaintenances,
  upcomingMaintenances,
  allScheduledMaintenances,
  allIncidents,
  components
}

class StatusPage {
  final String id;
  String name;
  String url;
  int order;
  
  List<DetailSection>? customSectionOrder;
  Set<DetailSection>? customSectionsDisabled;

  /// Background monitoring override. null = use global default, true/false = override
  bool? bgMonitor;

  StatusPage({
    required this.id,
    required this.name,
    required this.url,
    required this.order,
    this.customSectionOrder,
    this.customSectionsDisabled,
    this.bgMonitor,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'order': order,
        'customSectionOrder': customSectionOrder?.map((s) => s.index).toList(),
        'customSectionsDisabled': customSectionsDisabled?.map((s) => s.index).toList(),
        'bgMonitor': bgMonitor,
      };

  factory StatusPage.fromJson(Map<dynamic, dynamic> json) {
    final csoRaw = json['customSectionOrder'] as List?;
    final csdRaw = json['customSectionsDisabled'] as List?;

    return StatusPage(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      order: json['order'] as int,
      customSectionOrder: csoRaw?.map((i) => DetailSection.values[(i as int).clamp(0, DetailSection.values.length - 1)]).toList(),
      customSectionsDisabled: csdRaw?.map((i) => DetailSection.values[(i as int).clamp(0, DetailSection.values.length - 1)]).toSet(),
      bgMonitor: json['bgMonitor'] as bool?,
    );
  }

  StatusPage copyWith({
    String? name,
    String? url,
    int? order,
    Object? customSectionOrder = _sentinel,
    Object? customSectionsDisabled = _sentinel,
    Object? bgMonitor = _sentinel,
  }) {
    return StatusPage(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      order: order ?? this.order,
      customSectionOrder: customSectionOrder == _sentinel ? this.customSectionOrder : (customSectionOrder as List<DetailSection>?),
      customSectionsDisabled: customSectionsDisabled == _sentinel ? this.customSectionsDisabled : (customSectionsDisabled as Set<DetailSection>?),
      bgMonitor: bgMonitor == _sentinel ? this.bgMonitor : (bgMonitor as bool?),
    );
  }
}

const Object _sentinel = Object();

class StatusPageData {
  String pageName;
  String pageUrl;
  StatusIndicator indicator;
  String statusDescription;
  List<SPComponent> components;
  List<SPIncident> incidents;
  List<SPMaintenance> maintenances;
  DateTime? updatedAt;
  bool isLoading;
  bool isDetailedFetched;
  String? error;

  StatusPageData({
    this.pageName = '',
    this.pageUrl = '',
    this.indicator = StatusIndicator.none,
    this.statusDescription = '',
    this.components = const [],
    this.incidents = const [],
    this.maintenances = const [],
    this.updatedAt,
    this.isLoading = false,
    this.isDetailedFetched = false,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'pageName': pageName,
    'pageUrl': pageUrl,
    'indicator': indicator.index,
    'statusDescription': statusDescription,
    'components': components.map((c) => c.toJson()).toList(),
    'incidents': incidents.map((i) => i.toJson()).toList(),
    'maintenances': maintenances.map((m) => m.toJson()).toList(),
    'updatedAt': updatedAt?.toIso8601String(),
    'isDetailedFetched': isDetailedFetched,
  };

  factory StatusPageData.fromJson(Map<String, dynamic> json) {
    return StatusPageData(
      pageName: json['pageName'] ?? '',
      pageUrl: json['pageUrl'] ?? '',
      indicator: StatusIndicator.values[(json['indicator'] ?? 0) as int],
      statusDescription: json['statusDescription'] ?? '',
      components: (json['components'] as List?)?.map((c) => SPComponent.fromJson(c)).toList() ?? [],
      incidents: (json['incidents'] as List?)?.map((i) => SPIncident.fromJson(i)).toList() ?? [],
      maintenances: (json['maintenances'] as List?)?.map((m) => SPMaintenance.fromJson(m)).toList() ?? [],
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
      isDetailedFetched: json['isDetailedFetched'] ?? false,
    );
  }
}

class SPComponent {
  final String id;
  final String name;
  final ComponentStatus status;
  final bool group;
  final String? groupId;
  final String? description;

  SPComponent({
    required this.id,
    required this.name,
    required this.status,
    required this.group,
    this.groupId,
    this.description,
  });

  factory SPComponent.fromJson(Map<String, dynamic> json) {
    return SPComponent(
      id: json['id'],
      name: json['name'],
      status: _parseComponentStatus(json['status']),
      group: json['group'] ?? false,
      groupId: json['group_id'],
      description: json['description'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'status': status.name, // Will need to update _parseComponentStatus to handle this or use index
    'group': group,
    'group_id': groupId,
    'description': description,
  };
  
  static ComponentStatus _parseComponentStatus(String? status) {
    switch (status) {
      case 'degraded_performance': return ComponentStatus.degradedPerformance;
      case 'partial_outage': return ComponentStatus.partialOutage;
      case 'major_outage': return ComponentStatus.majorOutage;
      case 'under_maintenance': return ComponentStatus.underMaintenance;
      default: return ComponentStatus.operational;
    }
  }
}

class SPIncidentUpdate {
  final String id;
  final String body;
  final String status;
  final DateTime createdAt;
  final List<SPAffectedComponent> affectedComponents;

  SPIncidentUpdate({
    required this.id,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.affectedComponents,
  });

  factory SPIncidentUpdate.fromJson(Map<String, dynamic> json) {
    return SPIncidentUpdate(
      id: json['id'],
      body: json['body'] ?? '',
      status: json['status'] ?? 'unknown',
      createdAt: DateTime.parse(json['created_at']),
      affectedComponents: (json['affected_components'] as List?)
              ?.map((c) => SPAffectedComponent.fromJson(c))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'body': body,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'affected_components': affectedComponents.map((c) => c.toJson()).toList(),
  };
}

class SPIncident {
  final String id;
  final String name;
  final IncidentStatus status;
  final IncidentImpact impact;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final List<SPIncidentUpdate> updates;

  SPIncident({
    required this.id,
    required this.name,
    required this.status,
    required this.impact,
    required this.createdAt,
    this.resolvedAt,
    required this.updates,
  });

  factory SPIncident.fromJson(Map<String, dynamic> json) {
    return SPIncident(
      id: json['id'],
      name: json['name'],
      status: _parseIncidentStatus(json['status']),
      impact: _parseIncidentImpact(json['impact']),
      createdAt: DateTime.parse(json['created_at']),
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at']) : null,
      updates: (json['incident_updates'] as List?)?.map((u) => SPIncidentUpdate.fromJson(u)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'status': status.name,
    'impact': impact.name,
    'created_at': createdAt.toIso8601String(),
    'resolved_at': resolvedAt?.toIso8601String(),
    'incident_updates': updates.map((u) => u.toJson()).toList(),
  };

  static IncidentStatus _parseIncidentStatus(String? status) {
    switch (status) {
      case 'identified': return IncidentStatus.identified;
      case 'monitoring': return IncidentStatus.monitoring;
      case 'resolved': return IncidentStatus.resolved;
      case 'postmortem': return IncidentStatus.postmortem;
      default: return IncidentStatus.investigating;
    }
  }

  static IncidentImpact _parseIncidentImpact(String? impact) {
    switch (impact) {
      case 'minor': return IncidentImpact.minor;
      case 'major': return IncidentImpact.major;
      case 'critical': return IncidentImpact.critical;
      default: return IncidentImpact.none;
    }
  }
}

class SPMaintenance {
  final String id;
  final String name;
  final MaintenanceStatus status;
  final IncidentImpact impact;
  final DateTime scheduledFor;
  final DateTime scheduledUntil;
  final List<SPIncidentUpdate> updates;

  SPMaintenance({
    required this.id,
    required this.name,
    required this.status,
    required this.impact,
    required this.scheduledFor,
    required this.scheduledUntil,
    required this.updates,
  });

  factory SPMaintenance.fromJson(Map<String, dynamic> json) {
    return SPMaintenance(
      id: json['id'],
      name: json['name'],
      status: _parseMaintenanceStatus(json['status']),
      impact: SPIncident._parseIncidentImpact(json['impact']),
      scheduledFor: DateTime.parse(json['scheduled_for']),
      scheduledUntil: DateTime.parse(json['scheduled_until']),
      updates: (json['incident_updates'] as List?)?.map((u) => SPIncidentUpdate.fromJson(u)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'status': status.name,
    'impact': impact.name,
    'scheduled_for': scheduledFor.toIso8601String(),
    'scheduled_until': scheduledUntil.toIso8601String(),
    'incident_updates': updates.map((u) => u.toJson()).toList(),
  };

  static MaintenanceStatus _parseMaintenanceStatus(String? status) {
    switch (status) {
      case 'in_progress': return MaintenanceStatus.inProgress;
      case 'verifying': return MaintenanceStatus.verifying;
      case 'completed': return MaintenanceStatus.completed;
      default: return MaintenanceStatus.scheduled;
    }
  }
}

class SPAffectedComponent {
  final String code;
  final String name;
  final ComponentStatus oldStatus;
  final ComponentStatus newStatus;

  SPAffectedComponent({
    required this.code,
    required this.name,
    required this.oldStatus,
    required this.newStatus,
  });

  factory SPAffectedComponent.fromJson(Map<String, dynamic> json) {
    return SPAffectedComponent(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      oldStatus: SPComponent._parseComponentStatus(json['old_status']),
      newStatus: SPComponent._parseComponentStatus(json['new_status']),
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'old_status': oldStatus.name,
    'new_status': newStatus.name,
  };
}
