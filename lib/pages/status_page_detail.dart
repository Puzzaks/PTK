import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ptk/engine.dart';
import 'package:ptk/models/status_page.dart';
import 'package:ptk/pages/support/elements.dart';
import 'package:timeago/timeago.dart' as timeago;

class StatusPageDetailPage extends StatefulWidget {
  final StatusPage page;
  const StatusPageDetailPage({super.key, required this.page});

  @override
  State<StatusPageDetailPage> createState() => _StatusPageDetailPageState();
}

class _StatusPageDetailPageState extends State<StatusPageDetailPage> {
  @override
  void initState() {
    super.initState();
    // Fetch details (incidents and maintenances) when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final engine = Provider.of<AppEngine>(context, listen: false);
      if (!engine.spDataFor(widget.page.id).isDetailedFetched) {
        engine.fetchStatusPageDetails(widget.page);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppEngine>(builder: (context, engine, _) {
      final scheme = Theme.of(context).colorScheme;
      final data = engine.spDataFor(widget.page.id);

      // ── Filter Data ──────────────────────────────────────
      final now = DateTime.now();
      final upcomingWindow = now.add(Duration(days: engine.spUpcomingDays));

      final currentIncidents = data.incidents.where((i) => 
          i.status != IncidentStatus.resolved && i.status != IncidentStatus.postmortem).toList();
      
      final currentMaintenances = data.maintenances.where((m) => 
          m.status == MaintenanceStatus.inProgress || m.status == MaintenanceStatus.verifying).toList();
      
      final upcomingMaintenances = data.maintenances.where((m) => 
          m.status == MaintenanceStatus.scheduled && m.scheduledFor.isBefore(upcomingWindow)).toList();
      
      final allMaintenances = data.maintenances;
      final allIncidents = data.incidents;
      final components = data.components;

      // ── Build Sections ───────────────────────────────────
      List<Widget> slivers = [
        SliverAppBar.large(
          surfaceTintColor: Colors.transparent,
          pinned: true,
          leading: Padding(
            padding: const EdgeInsetsDirectional.only(start: 5),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          title: Text(
            widget.page.name,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: engine.dict.value('edit_statuspage_title'),
              onPressed: () => Navigator.pushNamed(
                context, 
                'StatusPageEditorPage', 
                arguments: widget.page,
              ),
            ),
          ],
        ),

        // Overall Status Banner
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 8, 15, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: data.indicator.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: data.indicator.color.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: data.indicator.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      data.statusDescription.isNotEmpty ? data.statusDescription : engine.dict.value('sp_checking'),
                      style: TextStyle(
                        color: data.indicator.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (data.isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: data.indicator.color,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ];

      // Build dynamic sections based on user preferences
      final resolvedOrder = engine.resolveSpSectionOrder(widget.page);
      final resolvedDisabled = engine.resolveSpSectionsDisabled(widget.page);

      for (final section in resolvedOrder) {
        if (resolvedDisabled.contains(section)) continue;

        switch (section) {
          case DetailSection.currentIncidents:
            final title = engine.dict.value('sp_section_current_incidents');
            slivers.add(SliverToBoxAdapter(child: Category.settings(title: title, context: context)));
            if (currentIncidents.isNotEmpty) {
              slivers.addAll(_buildIncidentList(currentIncidents, title, scheme, engine));
            } else {
              slivers.add(
                  SliverToBoxAdapter(
                  child: engine.cards.cardGroup([
                    CardContents.tapIcon(
                      title: engine.dict.value('sp_no_incidents'),
                      subtitle: "",
                      action: (){},
                      icon: Icons.check_circle_outline_rounded,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      colorBG: Theme.of(context).colorScheme.tertiaryContainer,
                    )
                  ]),
                )
              );
            }
            break;

          case DetailSection.currentMaintenances:
            final title = engine.dict.value('sp_section_current_maintenances');
            slivers.add(SliverToBoxAdapter(child: Category.settings(title: title, context: context)));
            if (currentMaintenances.isNotEmpty) {
              slivers.addAll(_buildMaintenanceList(currentMaintenances, title, scheme, engine));
            } else {
              slivers.add(
                  SliverToBoxAdapter(
                    child: engine.cards.cardGroup([
                      CardContents.tapIcon(
                        title: engine.dict.value('sp_no_maintenance_now'),
                        subtitle: "",
                        action: (){},
                        icon: Icons.check_circle_outline_rounded,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                        colorBG: Theme.of(context).colorScheme.tertiaryContainer,
                      )
                    ]),
                  )
              );
            }
            break;

          case DetailSection.upcomingMaintenances:
            final title = engine.dict.value('sp_section_upcoming_maintenances');
            slivers.add(SliverToBoxAdapter(child: Category.settings(title: title, context: context)));
            if (upcomingMaintenances.isNotEmpty) {
              slivers.addAll(_buildMaintenanceList(upcomingMaintenances, title, scheme, engine));
            } else {
              String emptyText = engine.dict.value('sp_no_upcoming_maintenances').replaceAll('@days', engine.spUpcomingDays.toString());
              slivers.add(
                  SliverToBoxAdapter(
                    child: engine.cards.cardGroup([
                      CardContents.tapIcon(
                        title: engine.dict.value('sp_no_upcoming_maintenances_title'),
                        subtitle: emptyText,
                        action: (){},
                        icon: Icons.check_circle_outline_rounded,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                        colorBG: Theme.of(context).colorScheme.tertiaryContainer,
                      )
                    ]),
                  )
              );
            }
            break;

          case DetailSection.allScheduledMaintenances:
            final title = engine.dict.value('sp_section_all_maintenances');
            slivers.add(SliverToBoxAdapter(child: Category.settings(title: title, context: context)));
            if (allMaintenances.isNotEmpty) {
              slivers.addAll(_buildMaintenanceList(allMaintenances, title, scheme, engine));
            } else {
              slivers.add(_buildEmptyCard(engine.dict.value('sp_no_maintenance'), context, Icons.event_available_rounded, engine));
            }
            break;

          case DetailSection.allIncidents:
            final title = engine.dict.value('sp_section_all_incidents');
            slivers.add(SliverToBoxAdapter(child: Category.settings(title: title, context: context)));
            if (allIncidents.isNotEmpty) {
              slivers.addAll(_buildIncidentList(allIncidents, title, scheme, engine));
            } else {
              slivers.add(_buildEmptyCard(engine.dict.value('sp_no_incidents'), context, Icons.check_circle_outline_rounded, engine));
            }
            break;

          case DetailSection.components:
            if (components.isNotEmpty) {
              slivers.add(SliverToBoxAdapter(child: Category.settings(title: engine.dict.value('sp_section_components'), context: context)));
              slivers.add(
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  sliver: SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: components.map((comp) {
                          final isOperational = comp.status == ComponentStatus.operational;
                          Widget chip = Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isOperational ? Colors.green : scheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  comp.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (comp.description != null && comp.description!.trim().isNotEmpty) {
                            return Tooltip(
                              message: comp.description!.trim(),
                              preferBelow: false,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              showDuration: const Duration(seconds: 4),
                              textStyle: TextStyle(
                                color: scheme.onInverseSurface,
                                fontSize: 14,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.inverseSurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              triggerMode: TooltipTriggerMode.tap,
                              child: chip,
                            );
                          }
                          return chip;
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              );
            }
            break;
        }
      }

      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 50)));

      return Scaffold(
        body: CustomScrollView(slivers: slivers),
      );
    });
  }

  Widget _buildEmptyCard(String text, BuildContext context, IconData icon, AppEngine engine) {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        child: engine.cards.cardGroup([
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 38,
                    height: 38,
                    color: scheme.surfaceContainerHighest,
                    child: Icon(
                      icon,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _buildIncidentList(List<SPIncident> incidents, String title, ColorScheme scheme, AppEngine engine) {
    final showMore = incidents.length > 1;
    final displayList = incidents.take(1).toList();

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final inc = displayList[i];
              final latestUpdate = inc.updates.isNotEmpty ? inc.updates.first : null;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(context, 'StatusPageUpdatesPage', arguments: {
                      'title': inc.name,
                      'updates': inc.updates,
                    });
                  },
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        SizedBox(width: 8,),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getImpactColor(inc.impact).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getImpactLabel(inc.impact, engine),
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
                      _getIncidentStatusLabel(inc.status, engine),
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
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurface, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            timeago.format(latestUpdate.createdAt),
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                          Text(
                            engine.dict.value("sp_section_current_incidents_more"),
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      )
                    ],
                  ],
                ),
              ),
            ),
          );
        },
            childCount: displayList.length,
          ),
        ),
      ),
      if (showMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(left: 15, right: 15, bottom: 12),
            child: FilledButton.tonal(
              onPressed: () {
                Navigator.pushNamed(context, 'StatusPageIncidentsPage', arguments: {
                  'title': title,
                  'incidents': incidents,
                });
              },
              child: Text(engine.dict.value('show_more')),
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildMaintenanceList(List<SPMaintenance> maintenances, String title, ColorScheme scheme, AppEngine engine) {
    final showMore = maintenances.length > 1;
    final displayList = maintenances.take(1).toList();

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final maint = displayList[i];
              final latestUpdate = maint.updates.isNotEmpty ? maint.updates.first : null;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(context, 'StatusPageUpdatesPage', arguments: {
                      'title': maint.name,
                      'updates': maint.updates,
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          maint.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                              _getMaintenanceStatusLabel(maint.status, engine),
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        if (latestUpdate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            latestUpdate.body,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: scheme.onSurface, fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
            childCount: displayList.length,
          ),
        ),
      ),
      if (showMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(left: 15, right: 15, bottom: 12),
            child: FilledButton.tonal(
              onPressed: () {
                Navigator.pushNamed(context, 'StatusPageMaintenancesPage', arguments: {
                  'title': title,
                  'maintenances': maintenances,
                });
              },
              child: Text(engine.dict.value('show_more')),
            ),
          ),
        ),
    ];
  }

  // ── Labels & Colors ────────────────────────────────────────



  String _getIncidentStatusLabel(IncidentStatus status, AppEngine engine) {
    // We can capitalize the enum name for now or add dict keys
    return status.name.toUpperCase(); 
  }

  String _getMaintenanceStatusLabel(MaintenanceStatus status, AppEngine engine) {
    switch (status) {
      case MaintenanceStatus.scheduled: return 'SCHEDULED';
      case MaintenanceStatus.inProgress: return 'IN PROGRESS';
      case MaintenanceStatus.verifying: return 'VERIFYING';
      case MaintenanceStatus.completed: return 'COMPLETED';
    }
  }

  String _getImpactLabel(IncidentImpact impact, AppEngine engine) {
    return impact.name.toUpperCase();
  }

  Color _getImpactColor(IncidentImpact impact) {
    switch (impact) {
      case IncidentImpact.none: return Colors.green;
      case IncidentImpact.minor: return Colors.yellow.shade700;
      case IncidentImpact.major: return Colors.orange;
      case IncidentImpact.critical: return Colors.red;
    }
  }
}
