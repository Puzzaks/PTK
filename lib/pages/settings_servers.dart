import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:PTK/engine.dart';
import 'package:PTK/pages/servers.dart';
import 'package:PTK/pages/support/elements.dart';
import 'package:PTK/models/server_watcher.dart';

class SettingsServersPage extends StatelessWidget {
  const SettingsServersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppEngine>(builder: (context, engine, _) {
      final cards = engine.cards;
      final count = engine.servers.length;
      final countStr = count == 1
          ? '1 ${engine.dict.value('servers_configured')}'
          : '$count ${engine.dict.value('servers_configured_plural')}';

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
              title: Text(engine.dict.value('settings_servers')),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Category.settings(title: engine.dict.value('servers'), context: context),
                  cards.cardGroup([
                    CardContents.tapIcon(
                      title: engine.dict.value('server_manager'),
                      subtitle: countStr,
                      icon: Icons.dns_rounded,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      colorBG: Theme.of(context).colorScheme.tertiaryContainer,
                      action: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ServersPage(),
                          settings: const RouteSettings(name: 'ServersPage'),
                        ),
                      ),
                    ),
                  ]),

                  Category.settings(title: engine.dict.value('network'), context: context),
                  cards.cardGroup([
                    CardContents.addretract(
                      title: engine.dict.value('update_interval'),
                      subtitle: engine.updateRateLabel,
                      actionAdd: () => engine.stepUpdateRate(1),
                      actionRetract: () => engine.stepUpdateRate(-1),
                    ),
                    CardContents.turn(
                      title: engine.dict.value('use_bits'),
                      subtitle: engine.dict.value('use_bits_hint'),
                      value: engine.useBits,
                      action: () => engine.useBits = !engine.useBits,
                      switcher: (v) => engine.useBits = v,
                    ),
                  ]),

                  Category.settings(title: engine.dict.value('default_server_card_stats'), context: context),
                  cards.cardGroup([
                    CardContents.tapIcon(
                      title: engine.dict.value('card_graph'),
                      subtitle: engine.defaultGraphStat.label,
                      icon: Icons.area_chart_rounded,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      colorBG: Theme.of(context).colorScheme.tertiaryContainer,
                      action: () => _showGraphPicker(context, engine),
                    ),
                    CardContents.tapIcon(
                      title: engine.dict.value('card_stat1'),
                      subtitle: engine.defaultTextStat1?.label ?? engine.dict.value('nothing'),
                      icon: Icons.align_horizontal_left_rounded,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      colorBG: Theme.of(context).colorScheme.tertiaryContainer,
                      action: () => _showStatPicker(context, engine, 'card_stat1', engine.defaultTextStat1, (s) {
                        engine.defaultTextStat1 = s;
                        _save(engine);
                      }),
                    ),
                    CardContents.tapIcon(
                      title: engine.dict.value('card_stat2'),
                      subtitle: engine.defaultTextStat2?.label ?? engine.dict.value('nothing'),
                      icon: Icons.align_horizontal_right_rounded,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      colorBG: Theme.of(context).colorScheme.tertiaryContainer,
                      action: () => _showStatPicker(context, engine, 'card_stat2', engine.defaultTextStat2, (s) {
                        engine.defaultTextStat2 = s;
                        _save(engine);
                      }),
                    ),
                  ]),

                  Category.settings(title: engine.dict.value('default_server_graph_order'), context: context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        final item = engine.defaultGraphOrder.removeAt(oldIndex);
                        engine.defaultGraphOrder.insert(newIndex, item);
                        _save(engine);
                      },
                      proxyDecorator: (child, _, __) => Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      ),
                      children: [
                        for (int i = 0; i < engine.defaultGraphOrder.length; i++)
                          _GraphOrderTile(
                            key: ValueKey(engine.defaultGraphOrder[i]),
                            graph: engine.defaultGraphOrder[i],
                            index: i,
                          ),
                      ],
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

  void _save(AppEngine engine) {
    // Engine persistence doesn't explicitly expose save for these yet, we will just call a generic reload or directly trigger box save.
    // Wait, let's add a public save method or just use engine.useBits to trigger a save...
    // Actually, `engine.notifyListeners()` alone doesn't save default graph orders.
    // I need to add `engine.saveSettings()` to engine.dart. I will do that next.
    engine.saveDefaults();
  }

  void _showStatPicker(BuildContext context, AppEngine engine, String titleKey, ServerStat? current, void Function(ServerStat?) onSelect) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(engine.dict.value(titleKey)),
        content: SingleChildScrollView(
          child: engine.cards.cardGroup([
            CardContents.halfTap(
              title: engine.dict.value('nothing'),
              subtitle: '',
              action: () { onSelect(null); Navigator.pop(ctx); },
            ),
            ...ServerStat.values.map((stat) => CardContents.halfTap(
              title: stat.label,
              subtitle: '',
              action: () { onSelect(stat); Navigator.pop(ctx); },
            )),
          ]),
        ),
      ),
    );
  }

  void _showGraphPicker(BuildContext context, AppEngine engine) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(engine.dict.value('card_graph')),
        content: SingleChildScrollView(
          child: Container(
            child: engine.cards.cardGroup(
              GraphStat.values.map((stat) => CardContents.halfTap(
                title: stat.label,
                subtitle: '',
                action: () {
                  engine.defaultGraphStat = stat;
                  _save(engine);
                  Navigator.pop(ctx);
                },
              )).toList().cast<Widget>(),
            ),
          ),
        ),
      ),
    );
  }
}

class _GraphOrderTile extends StatelessWidget {
  final DetailGraph graph;
  final int index;

  const _GraphOrderTile({super.key, required this.graph, required this.index});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                graph.label,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: scheme.onSurface),
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
