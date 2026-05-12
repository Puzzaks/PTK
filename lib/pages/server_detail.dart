import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:PTK/engine.dart';
import 'package:PTK/models/server_watcher.dart';
import 'package:PTK/models/server_telemetry.dart';
import 'package:PTK/pages/server_editor.dart';

/// Full telemetry dashboard for a single [ServerWatcher].
class ServerDetailPage extends StatelessWidget {
  final ServerWatcher server;
  const ServerDetailPage({super.key, required this.server});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppEngine>(builder: (context, engine, _) {
      final current = engine.servers.firstWhere(
        (s) => s.id == server.id,
        orElse: () => server,
      );
      final telem       = engine.telemetryFor(current.id);
      final primaryColor = Theme.of(context).colorScheme.primary;
      final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

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
              title: Text(current.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  tooltip: engine.dict.value('edit_server'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServerEditorPage(existing: current),
                      settings: const RouteSettings(name: 'ServerEditorPage'),
                    ),
                  ),
                ),
              ],
            ),

            // Disconnected banner
            if (telem.isDisconnected)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  child: Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              color: Theme.of(context).colorScheme.onErrorContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  engine.dict.value('disconnected'),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  current.url,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Ping-only info banner
            if (!current.isAio && !telem.isDisconnected)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  child: Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        engine.dict.value('aio_only_hint'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Uptime (AIO only)
            if (current.isAio)
              SliverToBoxAdapter(
                child: _StatCard(
                  title: engine.dict.value('server_uptime'),
                  value: telem.uptime,
                  icon: Icons.timer_outlined,
                ),
              ),

            // Telemetry grid — ordered by user's graphOrder
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isLandscape ? 2 : 1,
                  mainAxisExtent: 140,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                ),
                delegate: SliverChildListDelegate(
                  _buildCards(context, engine, current, telem, primaryColor),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      );
    });
  }

  List<Widget> _buildCards(
    BuildContext context,
    AppEngine engine,
    ServerWatcher server,
    ServerTelemetry telem,
    Color color,
  ) {
    // Always show ping
    final allCards = <DetailGraph, Widget>{
      DetailGraph.ping: _TelemetryCard(
        title: engine.dict.value('ping'),
        value: '${telem.lastPing.toStringAsFixed(0)} ms',
        data:  telem.pings,
        color: color,
      ),
    };

    if (server.isAio) {
      allCards[DetailGraph.cpuLoad] = _TelemetryCard(
        title: engine.dict.value('cpu_load'),
        value: '${telem.cpuLoad.toStringAsFixed(1)}%',
        data:  telem.loads,
        color: color,
        minY: 0, maxY: 100,
      );
      allCards[DetailGraph.cpuTemp] = _TelemetryCard(
        title: engine.dict.value('temperature'),
        value: '${telem.cpuTemp.toStringAsFixed(1)} °C',
        data:  telem.temps,
        color: color,
        minY: 0, maxY: 100,
      );
      allCards[DetailGraph.ram] = _TelemetryCard(
        title: engine.dict.value('ram_usage'),
        value: '${engine.formatBytes(telem.memUsed)} / ${engine.formatBytes(telem.memTotal)}',
        subValue: '${(telem.memPct * 100).toStringAsFixed(1)}%',
        progress: telem.memPct,
        data:  telem.mems,
        color: color,
        minY: 0,
        maxY: telem.memTotal > 0 ? telem.memTotal : 100,
      );
      allCards[DetailGraph.netIn] = _TelemetryCard(
        title: '${engine.dict.value('network')} (In)',
        value: engine.formatBytes(telem.netIn, isThroughput: true),
        data:  telem.netIns,
        color: color,
      );
      allCards[DetailGraph.netOut] = _TelemetryCard(
        title: '${engine.dict.value('network')} (Out)',
        value: engine.formatBytes(telem.netOut, isThroughput: true),
        data:  telem.netOuts,
        color: color,
      );
    }

    // Build in user-defined order, skip non-AIO graphs if non-AIO
    final resolvedGraphOrder = engine.resolveGraphOrder(server);
    final ordered = <Widget>[];
    for (final g in resolvedGraphOrder) {
      final card = allCards[g];
      if (card != null) ordered.add(card);
    }
    // Fallback: if nothing matched (e.g. all AIO-only on non-AIO) show ping
    if (ordered.isEmpty) ordered.add(allCards[DetailGraph.ping]!);
    return ordered;
  }
}

// ── Stat header card ──────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overlay telemetry card ────────────────────────────────

class _TelemetryCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subValue;
  final double? progress;
  final List<TelemetryData> data;
  final Color color;
  final double? minY;
  final double? maxY;

  const _TelemetryCard({
    required this.title,
    required this.value,
    this.subValue,
    this.progress,
    required this.data,
    required this.color,
    this.minY,
    this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    double actualMaxY = maxY ??
        (data.isNotEmpty
            ? data.map((e) => e.value).reduce(max)
            : 10);
    if (actualMaxY == 0) actualMaxY = 10;
    final buffer = actualMaxY * 0.08;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned.fill(
            top: 40,
            child: Opacity(
              opacity: 0.4,
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: LineChart(
                  LineChartData(
                    gridData:   const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minY: -buffer,
                    maxY: actualMaxY,
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
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                  duration: Duration.zero,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          )),
                          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                          if (subValue != null)
                            Text(subValue!, style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            )),
                        ],
                      ),
                    ),
                    if (progress != null)
                      SizedBox(
                        width: 32, height: 32,
                        child: CircularProgressIndicator(
                          value: progress,
                          backgroundColor: color.withValues(alpha: 0.1),
                          strokeCap: StrokeCap.round,
                          strokeWidth: 4,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
