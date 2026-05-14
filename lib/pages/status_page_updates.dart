import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:PTK/engine.dart';
import 'package:PTK/models/status_page.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

class StatusPageUpdatesPage extends StatelessWidget {
  final String title;
  final List<SPIncidentUpdate> updates;

  const StatusPageUpdatesPage({
    super.key,
    required this.title,
    required this.updates,
  });

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<AppEngine>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(engine.dict.value('incident_updates')),
        surfaceTintColor: Colors.transparent,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final update = updates[i];
                  return _buildUpdateTimelineItem(context, update, i == 0, i == updates.length - 1);
                },
                childCount: updates.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  Widget _buildUpdateTimelineItem(BuildContext context, SPIncidentUpdate update, bool isFirst, bool isLast) {
    final scheme = Theme.of(context).colorScheme;
    final engine = Provider.of<AppEngine>(context, listen: false);

    // Filter components that actually changed status
    final changedComponents = update.affectedComponents
        .where((c) => c.oldStatus != c.newStatus)
        .toList();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 20,
                  color: isFirst ? Colors.transparent : scheme.outlineVariant,
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isFirst ? scheme.primary : scheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isFirst ? scheme.primary : scheme.outline,
                      width: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : scheme.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          update.status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            timeago.format(update.createdAt),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${update.createdAt.day.toString().padLeft(2, '0')}.${update.createdAt.month.toString().padLeft(2, '0')}.${update.createdAt.year} ${update.createdAt.hour.toString().padLeft(2, '0')}:${update.createdAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  MarkdownBody(
                    data: update.body,
                    selectable: true,
                    shrinkWrap: true,
                    onTapLink: (String text, String? href, String title) async {
                      await launchUrl(
                          Uri.parse(href!),
                          mode: LaunchMode.externalApplication
                      );
                    },
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (changedComponents.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        height: 32,
                        child: Wrap(
                          spacing: 8,
                          direction: Axis.horizontal,
                          children: changedComponents.map((c) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: scheme.outlineVariant),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    c.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_rounded, size: 12, color: scheme.onSurfaceVariant),
                                  const SizedBox(width: 6),
                                  Text(
                                    _getComponentStatusLabel(c.newStatus, engine),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: c.newStatus == ComponentStatus.operational
                                          ? Colors.green
                                          : scheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getComponentStatusLabel(ComponentStatus status, AppEngine engine) {
    switch (status) {
      case ComponentStatus.operational: return engine.dict.value('sp_operational');
      case ComponentStatus.degradedPerformance: return engine.dict.value('sp_degraded');
      case ComponentStatus.partialOutage: return engine.dict.value('sp_partial_outage');
      case ComponentStatus.majorOutage: return engine.dict.value('sp_major_outage');
      case ComponentStatus.underMaintenance: return engine.dict.value('sp_under_maintenance');
    }
  }
}
