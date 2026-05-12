import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:PTK/engine.dart';
import 'package:PTK/models/status_page.dart';
import 'package:timeago/timeago.dart' as timeago;

class StatusPageIncidentsPage extends StatelessWidget {
  final String title;
  final List<SPIncident> incidents;

  const StatusPageIncidentsPage({
    super.key,
    required this.title,
    required this.incidents,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        itemCount: incidents.length,
        itemBuilder: (context, i) {
          final inc = incidents[i];
          final latestUpdate = inc.updates.isNotEmpty ? inc.updates.first : null;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, 'StatusPageUpdatesPage', arguments: {
                  'title': inc.name,
                  'updates': inc.updates,
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            inc.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getImpactColor(inc.impact).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            inc.impact.name.toUpperCase(),
                            style: TextStyle(
                              color: _getImpactColor(inc.impact),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      inc.status.name.toUpperCase(),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (latestUpdate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        latestUpdate.body,
                        style: TextStyle(color: scheme.onSurface, fontSize: 14),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        timeago.format(latestUpdate.createdAt),
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getImpactColor(IncidentImpact impact) {
    switch (impact) {
      case IncidentImpact.none:
        return Colors.green;
      case IncidentImpact.minor:
        return Colors.yellow.shade700;
      case IncidentImpact.major:
        return Colors.orange;
      case IncidentImpact.critical:
        return Colors.red;
    }
  }
}

class StatusPageMaintenancesPage extends StatelessWidget {
  final String title;
  final List<SPMaintenance> maintenances;

  const StatusPageMaintenancesPage({
    super.key,
    required this.title,
    required this.maintenances,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final engine = Provider.of<AppEngine>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        itemCount: maintenances.length,
        itemBuilder: (context, i) {
          final maint = maintenances[i];
          final latestUpdate = maint.updates.isNotEmpty ? maint.updates.first : null;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, 'StatusPageUpdatesPage', arguments: {
                  'title': maint.name,
                  'updates': maint.updates,
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      maint.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${engine.dict.value('sp_scheduled_for')} ${maint.scheduledFor.day>=10?maint.scheduledFor.day:"0${maint.scheduledFor.day}"}.${maint.scheduledFor.month>=10?maint.scheduledFor.month:"0${maint.scheduledFor.month}"}.${maint.scheduledFor.year}',
                          style: TextStyle(color: scheme.primary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          maint.status.name.toUpperCase().replaceAll('_', ' '),
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (latestUpdate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        latestUpdate.body,
                        style: TextStyle(color: scheme.onSurface, fontSize: 14),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
