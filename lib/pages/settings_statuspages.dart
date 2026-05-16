import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ptk/engine.dart';
import 'package:ptk/models/status_page.dart';
import 'package:ptk/pages/status_pages_manager.dart';
import 'package:ptk/pages/support/elements.dart';

class SettingsStatuspagesPage extends StatelessWidget {
  const SettingsStatuspagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppEngine>(builder: (context, engine, _) {
      final cards = engine.cards;
      
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              surfaceTintColor: Colors.transparent,
              leading: Padding(
                padding: const EdgeInsetsDirectional.only(start: 5),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              pinned: true,
              title: Text(engine.dict.value('settings_statuspages')),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Category.settings(title: engine.dict.value('statuspage_title'), context: context),
                  cards.cardGroup([
                    CardContents.tapIcon(
                      icon: Icons.hub_rounded,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      colorBG: Theme.of(context).colorScheme.tertiaryContainer,
                      title: engine.dict.value('manage_statuspages'),
                      subtitle: engine.statusPages.length == 1
                          ? '1 ${engine.dict.value('statuspages_configured')}'
                          : '${engine.statusPages.length} ${engine.dict.value('statuspages_configured_plural')}',
                      action: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StatusPagesManagerPage(),
                          settings: const RouteSettings(name: 'StatusPagesManagerPage'),
                        ),
                      ),
                    ),
                    CardContents.addretract(
                      title: engine.dict.value('sp_upcoming_window'),
                      subtitle: '${engine.spUpcomingDays} ${engine.spUpcomingDays == 1 ? engine.dict.value('sp_upcoming_day') : engine.dict.value('sp_upcoming_days')}',
                      actionAdd: () => engine.setSpUpcomingDays(engine.spUpcomingDays + 1),
                      actionRetract: () => engine.setSpUpcomingDays(engine.spUpcomingDays - 1),
                    ),
                  ]),

                  Category.settings(title: engine.dict.value('sp_section_order'), context: context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: engine.reorderSpSections,
                      proxyDecorator: (child, _, __) => Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      ),
                      children: [
                        for (int i = 0; i < engine.spSectionOrder.length; i++)
                          _SpSectionTile(
                            key: ValueKey(engine.spSectionOrder[i]),
                            section: engine.spSectionOrder[i],
                            index: i,
                            engine: engine,
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Text(
                      engine.dict.value('sp_section_order_hint'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _SpSectionTile extends StatelessWidget {
  final DetailSection section;
  final int index;
  final AppEngine engine;

  const _SpSectionTile({
    super.key,
    required this.section,
    required this.index,
    required this.engine,
  });

  String _getSectionTitle() {
    switch (section) {
      case DetailSection.currentIncidents: return engine.dict.value('sp_section_current_incidents');
      case DetailSection.currentMaintenances: return engine.dict.value('sp_section_current_maintenances');
      case DetailSection.upcomingMaintenances: return engine.dict.value('sp_section_upcoming_maintenances');
      case DetailSection.allScheduledMaintenances: return engine.dict.value('sp_section_all_maintenances');
      case DetailSection.allIncidents: return engine.dict.value('sp_section_all_incidents');
      case DetailSection.components: return engine.dict.value('sp_section_components');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEnabled = !engine.spSectionsDisabled.contains(section);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Switch(
              value: isEnabled,
              onChanged: (val) => engine.toggleSpSection(section, val),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _getSectionTitle(),
                style: TextStyle(
                  fontWeight: FontWeight.w600, 
                  fontSize: 16,
                  color: isEnabled ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_handle_rounded, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
