import 'package:ptk/pages/support/elements.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ptk/engine.dart';
import 'package:ptk/models/status_page.dart';

class StatusPagesManagerPage extends StatelessWidget {
  const StatusPagesManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppEngine>(builder: (context, engine, child) {
      final scheme = Theme.of(context).colorScheme;
      final pages = engine.statusPages;

      return Scaffold(
        body: CustomScrollView(
          slivers: [
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
              title: Text(engine.dict.value('manage_statuspages')),
            ),
            
            if (pages.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hub_rounded, size: 64, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        engine.dict.value('no_statuspages_tap'),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        engine.dict.value('no_statuspages_tap_hint'),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      child: ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorder: engine.reorderStatusPages,
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            elevation: 6,
                            color: Colors.transparent,
                            shadowColor: scheme.shadow.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            child: child,
                          );
                        },
                        children: [
                          for (int i = 0; i < pages.length; i++)
                            _StatusPageListTile(
                              key: ValueKey(pages[i].id),
                              page: pages[i],
                              index: i,
                              engine: engine,
                            ),
                        ],
                      ),
                    ),
                    TextPart.info(
                      title: engine.dict.value('servers_drag_hint'),
                      subtitle: '',
                      action: (){},
                      context: context
                    ),
                    const SizedBox(height: 80), // Padding for FAB
                  ],
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, 'StatusPageEditorPage'),
          icon: const Icon(Icons.add_rounded),
          label: Text(engine.dict.value('add_statuspage')),
        ),
      );
    });
  }
}

class _StatusPageListTile extends StatelessWidget {
  final StatusPage page;
  final int index;
  final AppEngine engine;

  const _StatusPageListTile({
    super.key,
    required this.page,
    required this.index,
    required this.engine,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          'StatusPageEditorPage',
          arguments: page,
        ),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.hub_rounded, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      page.url,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Icon(Icons.drag_handle_rounded, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
