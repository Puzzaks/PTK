import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:PTK/engine.dart';
import 'package:PTK/models/server_watcher.dart';
import 'package:PTK/pages/support/elements.dart';
import 'package:PTK/pages/server_editor.dart';

class ServersPage extends StatefulWidget {
  const ServersPage({super.key});

  @override
  State<ServersPage> createState() => _ServersPageState();
}

class _ServersPageState extends State<ServersPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppEngine>(builder: (context, engine, _) {
      final servers = engine.servers;

      return Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'servers_fab',
          icon: const Icon(Icons.add_rounded),
          label: Text(engine.dict.value('add_server')),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ServerEditorPage(),
              settings: const RouteSettings(name: 'ServerEditorPage'),
            ),
          ),
        ),
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
              title: Text(engine.dict.value('server_manager')),
            ),

            if (servers.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Cards(context: context).cardGroup([
                    CardContents.tapIcon(
                      title: engine.dict.value('no_servers_tap'),
                      subtitle: engine.dict.value('no_servers_tap_hint'),
                      icon: Icons.list_alt_rounded,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      colorBG: Theme.of(context).colorScheme.tertiaryContainer,
                      action: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ServerEditorPage(),
                          settings: const RouteSettings(name: 'ServerEditorPage'),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),

            if (servers.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Category.settings(
                      title: engine.dict.value('servers'),
                      context: context,
                    ),
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) =>
                          engine.reorderServers(oldIndex, newIndex),
                      proxyDecorator: (child, index, animation) => Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(20),
                        child: child,
                      ),
                      children: [
                        for (int i = 0; i < servers.length; i++)
                          _ServerListTile(
                            key: ValueKey(servers[i].id),
                            server: servers[i],
                            isFirst: i == 0,
                            isLast:  i == servers.length - 1,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextPart.infoShort(
                  title: engine.dict.value('servers_drag_hint'),
                  subtitle: '',
                  action: () {},
                  context: context,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      );
    });
  }
}

class _ServerListTile extends StatelessWidget {
  final ServerWatcher server;
  final bool isFirst;
  final bool isLast;

  const _ServerListTile({
    super.key,
    required this.server,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final engine    = Provider.of<AppEngine>(context, listen: false);
    const cardROuter = Radius.circular(20);
    const cardRInner = Radius.circular(5);
    final scheme    = Theme.of(context).colorScheme;

    final BorderRadius radius;
    if (isFirst && isLast) {
      radius = const BorderRadius.all(cardROuter);
    } else if (isFirst) {
      radius = const BorderRadius.only(topLeft: cardROuter, topRight: cardROuter, bottomLeft: cardRInner, bottomRight: cardRInner);
    } else if (isLast) {
      radius = const BorderRadius.only(topLeft: cardRInner, topRight: cardRInner, bottomLeft: cardROuter, bottomRight: cardROuter);
    } else {
      radius = const BorderRadius.all(cardRInner);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServerEditorPage(existing: server),
              settings: const RouteSettings(name: 'ServerEditorPage'),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  server.isAio ? Icons.dns_rounded : Icons.monitor_heart_rounded,
                  color: server.isAio ? scheme.primary : scheme.onSurfaceVariant,
                  size: 26,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        server.url,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ReorderableDragStartListener(
                  index: 0,
                  child: Icon(Icons.drag_handle_rounded, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
