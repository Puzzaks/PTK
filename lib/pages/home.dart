import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:PTK/engine.dart';
import 'package:PTK/models/server_watcher.dart';
import 'package:PTK/models/server_telemetry.dart';
import 'package:PTK/pages/server_detail.dart';
import 'package:PTK/pages/server_editor.dart';
import 'package:PTK/pages/statuspage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final engine = Provider.of<AppEngine>(context, listen: false);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: engine.defaultTab,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppEngine>(builder: (context, engine, _) {
      return Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          title: Text(engine.dict.value('app_name')),
          actions: [
            if (_tabController.index == 1)
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: engine.dict.value('add_statuspage'),
                onPressed: () => Navigator.pushNamed(context, 'StatusPageEditorPage'),
              ),
            if (_tabController.index == 0)
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: engine.dict.value('add_server'),
                onPressed: () => Navigator.pushNamed(context, 'ServerEditorPage'),
              ),
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => Navigator.pushNamed(context, 'SettingsPage'),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(icon: _tabController.index == 1 ? const Icon(Icons.dns_outlined) : const Icon(Icons.dns_rounded), text: engine.dict.value('servers')),
              Tab(icon: _tabController.index == 0 ?  const Icon(Icons.cloud_done_outlined) : const Icon(Icons.cloud_done_rounded),   text: engine.dict.value('status_pages')),
            ],
          ),
        ),
        body: Column(
          children: [
            // Offline banner
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: engine.isOnline
                  ? const SizedBox.shrink()
                  : MaterialBanner(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Icon(Icons.wifi_off_rounded,
                          color: Theme.of(context).colorScheme.onErrorContainer),
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                      content: Text(
                        engine.dict.value('offline_banner'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      actions: const [SizedBox.shrink()],
                    ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _ServerListTab(),
                  StatuspagePage(),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── Tab 1: Server list ─────────────────────────────────────

class _ServerListTab extends StatelessWidget {
  const _ServerListTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppEngine>(builder: (context, engine, _) {
      final servers = engine.servers;

      if (servers.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.dns_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 20),
              Text(
                engine.dict.value('no_servers'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  engine.dict.value('no_servers_hint'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ServerEditorPage(),
                    settings: const RouteSettings(name: 'ServerEditorPage'),
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(engine.dict.value('add_server')),
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        itemCount: servers.length + 1,
        itemBuilder: (context, index) {
          if (index == servers.length) return const SizedBox(height: 80);
          final server = servers[index];
          return _ServerCard(key: ValueKey(server.id), server: server);
        },
      );
    });
  }
}

// ── Server card ───────────────────────────────────────────

class _ServerCard extends StatefulWidget {
  final ServerWatcher server;
  const _ServerCard({super.key, required this.server});

  @override
  State<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<_ServerCard> {
  bool _isVisible = false;

  @override
  void dispose() {
    if (_isVisible) {
      Provider.of<AppEngine>(context, listen: false)
          .setServerVisible(widget.server.id, false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine    = Provider.of<AppEngine>(context);
    final server    = engine.servers.firstWhere(
      (s) => s.id == widget.server.id,
      orElse: () => widget.server,
    );
    final telem     = engine.telemetryFor(server.id);
    final color     = Theme.of(context).colorScheme.primary;
    final scheme    = Theme.of(context).colorScheme;
    final resolvedGraphStat = engine.resolveGraphStat(server);
    final graphData = engine.graphData(resolvedGraphStat, telem);

    return VisibilityDetector(
      key: ValueKey('vis_${server.id}'),
      onVisibilityChanged: (info) {
        final nowVisible = info.visibleFraction > 0.1;
        if (nowVisible != _isVisible) {
          _isVisible = nowVisible;
          engine.setServerVisible(server.id, nowVisible);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Card(
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ServerDetailPage(server: server),
                settings: const RouteSettings(name: 'ServerDetailPage'),
              ),
            ),
            child: SizedBox(
              height: 160,
              child: Stack(
                children: [
                  // ── Background graph — pointer-absorbing so card stays tappable ──
                  Positioned.fill(
                    child: AbsorbPointer(
                      child: Opacity(
                        opacity: 0.35,
                        child: graphData.isEmpty
                            ? const SizedBox.shrink()
                            : _buildGraph(graphData, color, telem, server, engine),
                      ),
                    ),
                  ),

                  // ── Foreground content ────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + status dot
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                server.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: telem.isDisconnected
                                    ? scheme.error
                                    : scheme.primary,
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Stat slots
                        if (!server.isAio) ...[
                          Text(
                            '${telem.lastPing.toStringAsFixed(0)} ms',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                          Text(
                            engine.dict.value('ping'),
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              engine.dict.value('install_aio_hint'),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              if (engine.resolveTextStat1(server) != null)
                                Expanded(child: _StatSlot(
                                  label: engine.resolveTextStat1(server)!.label,
                                  value: engine.statString(engine.resolveTextStat1(server)!, telem),
                                )),
                              if (engine.resolveTextStat1(server) != null && engine.resolveTextStat2(server) != null)
                                const SizedBox(width: 12),
                              if (engine.resolveTextStat2(server) != null)
                                Expanded(child: _StatSlot(
                                  label: engine.resolveTextStat2(server)!.label,
                                  value: engine.statString(engine.resolveTextStat2(server)!, telem),
                                )),
                              // If both are null, show ping as fallback
                              if (engine.resolveTextStat1(server) == null && engine.resolveTextStat2(server) == null)
                                _StatSlot(
                                  label: engine.dict.value('ping'),
                                  value: '${telem.lastPing.toStringAsFixed(0)} ms',
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGraph(
    List<TelemetryData> data,
    Color color,
    ServerTelemetry telem,
    ServerWatcher server,
    AppEngine engine,
  ) {
    double maxY = data.isNotEmpty
        ? data.map((e) => e.value).reduce(max)
        : 10;
    if (maxY == 0) maxY = 10;

    final resolvedGraphStat = engine.resolveGraphStat(server);
    if (resolvedGraphStat == GraphStat.cpuLoad ||
        resolvedGraphStat == GraphStat.cpuTemp ||
        resolvedGraphStat == GraphStat.ramPct) {
      maxY = 100;
    }

    return LineChart(
      LineChartData(
        gridData:   const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: -(maxY * 0.08),
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                .toList(),
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.25)),
          ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}

// ── Stat slot ─────────────────────────────────────────────

class _StatSlot extends StatelessWidget {
  final String label;
  final String value;
  const _StatSlot({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
