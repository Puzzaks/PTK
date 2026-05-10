import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:PTK/engine.dart';
import 'package:PTK/pages/support/elements.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppEngine>(builder: (context, engine, child) {
      final primaryColor = Theme.of(context).colorScheme.primary;
      final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              surfaceTintColor: Colors.transparent,
              pinned: true,
              title: const Text("PTK Dashboard"),
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () {
                    Navigator.pushNamed(context, 'AboutPage');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings_rounded),
                  onPressed: () {
                    Navigator.pushNamed(context, 'SettingsPage');
                  },
                ),
              ],
            ),
            if (engine.isDisconnected)
              SliverToBoxAdapter(
                child: engine.cards.cardGroup([
                  CardContents.static(
                    title: "Disconnected!",
                    subtitle: "Please check your API settings or internet connection.",
                  ),
                ]),
              ),
            SliverToBoxAdapter(
              child: _StatCard(
                title: "Server Uptime",
                value: engine.uptime,
                icon: Icons.timer_outlined,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isLandscape ? 2 : 1,
                  mainAxisExtent: 140, // Uniform height for most cards
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                ),
                delegate: SliverChildListDelegate([
                  _OverlayTelemetryCard(
                    title: "CPU Load",
                    value: "${engine.cpuload.toStringAsFixed(1)}%",
                    data: engine.loads,
                    color: primaryColor,
                    minY: 0,
                    maxY: 100,
                  ),
                  _OverlayTelemetryCard(
                    title: "SoC Temperature",
                    value: "${engine.cpuTemp.toStringAsFixed(1)}°C",
                    data: engine.temps,
                    color: primaryColor,
                    minY: 0,
                    maxY: 100,
                  ),
                  _OverlayTelemetryCard(
                    title: "RAM Usage",
                    value: "${engine.formatBytes(engine.memused)} / ${engine.formatBytes(engine.memtotal)}",
                    subValue: "${engine.memtotal > 0 ? ((engine.memused / engine.memtotal) * 100).toStringAsFixed(1) : 0}%",
                    progress: engine.memtotal > 0 ? engine.memused / engine.memtotal : 0,
                    data: engine.mems,
                    color: primaryColor,
                    minY: 0,
                    maxY: engine.memtotal > 0 ? engine.memtotal : 100,
                  ),
                  _OverlayTelemetryCard(
                    title: "Throughput (In)",
                    value: engine.formatBytes(engine.netIn, isThroughput: true),
                    data: engine.netIns,
                    color: primaryColor,
                  ),
                  _OverlayTelemetryCard(
                    title: "Throughput (Out)",
                    value: engine.formatBytes(engine.netOut, isThroughput: true),
                    data: engine.netOuts,
                    color: primaryColor,
                  ),
                  _OverlayTelemetryCard(
                    title: "Ping",
                    value: "${engine.pings.isNotEmpty ? engine.pings.last.value.toStringAsFixed(0) : 0} ms",
                    data: engine.pings,
                    color: primaryColor,
                  ),
                ]),
              ),
            ),

            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  text.info(
                    title: "PTK is monitoring your server in real-time. Data is fetched from your configured AIO.php endpoint.",
                    subtitle: "About this app",
                    action: () {
                      Navigator.pushNamed(context, 'AboutPage');
                    },
                    context: context,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

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
                mainAxisAlignment: MainAxisAlignment.center,
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

class _OverlayTelemetryCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subValue;
  final double? progress;
  final List<TelemetryData> data;
  final Color color;
  final double? minY;
  final double? maxY;

  const _OverlayTelemetryCard({
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
    double actualMaxY = maxY ?? (data.isNotEmpty ? data.map((e) => e.value).reduce((a, b) => a > b ? a : b) : 10);
    if (actualMaxY == 0) actualMaxY = 10;
    double buffer = actualMaxY * 0.08;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned.fill(
            top: 40,
            child: Opacity(
              opacity: 0.4,
              child: Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 0),
                child: LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (spot) => color.withOpacity(0.8),
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                          return touchedBarSpots.map((barSpot) {
                            final engine = Provider.of<AppEngine>(context, listen: false);
                            String formattedValue = title.contains("Throughput") 
                              ? engine.formatBytes(barSpot.y, isThroughput: true)
                              : title.contains("RAM")
                                ? engine.formatBytes(barSpot.y)
                                : barSpot.y.toStringAsFixed(2);
                            
                            return LineTooltipItem(
                              formattedValue,
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minY: -buffer,
                    maxY: actualMaxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                        isCurved: true,
                        color: color,
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withOpacity(0.2),
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
              mainAxisAlignment: MainAxisAlignment.start,
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
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          value: progress,
                          backgroundColor: color.withOpacity(0.1),
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
