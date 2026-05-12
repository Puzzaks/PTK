import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:PTK/engine.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});
  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _addDemoServer = true;
  bool _addDemoStatusPage = true;
  bool _bgMonitoring = false;

  static const _totalPages = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    final engine = Provider.of<AppEngine>(context, listen: false);

    // Add demo services if selected
    if (_addDemoServer) await engine.addDemoServer();
    if (_addDemoStatusPage) await engine.addDemoStatusPage();

    // Enable bg monitoring if selected
    if (_bgMonitoring) {
      // Request permissions
      final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
      if (notifPerm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      if (Platform.isAndroid) {
        if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        }
      }
      await engine.setBgMonitorEnabled(true);
    }

    engine.introCompleted = true;

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('HomePage');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                physics: const ClampingScrollPhysics(),
                children: [
                  _buildWelcomePage(scheme, textTheme),
                  _buildPingPage(scheme, textTheme),
                  _buildAioPage(scheme, textTheme),
                  _buildStatusPagePage(scheme, textTheme),
                  _buildBgMonitorPage(scheme, textTheme),
                ],
              ),
            ),

            // Page indicator dots
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentPage == i
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                  );
                }),
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Skip button (hidden on last page)
                  _currentPage < _totalPages - 1
                      ? TextButton(
                          onPressed: () => _pageController.animateToPage(
                            _totalPages - 1,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          ),
                          child: const Text('Skip'),
                        )
                      : const SizedBox(width: 72),

                  // Next / Get Started button
                  _currentPage < _totalPages - 1
                      ? FilledButton(
                          onPressed: _nextPage,
                          child: const Text('Next'),
                        )
                      : FilledButton.icon(
                          onPressed: _finish,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Get Started'),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Slide builders ──────────────────────────────────────

  Widget _buildWelcomePage(ColorScheme scheme, TextTheme textTheme) {
    return _SlideLayout(
      icon: Icons.monitor_heart_rounded,
      iconColor: scheme.primary,
      title: 'Welcome to PTK',
      description: 'Your server and service monitoring toolkit.\n\n'
          'PTK lets you keep an eye on your servers, track their performance, '
          'and monitor the status of cloud services — all from your phone.',
    );
  }

  Widget _buildPingPage(ColorScheme scheme, TextTheme textTheme) {
    return _SlideLayout(
      icon: Icons.network_ping_rounded,
      iconColor: Colors.teal,
      title: 'Ping Monitoring',
      description: 'PTK monitors your servers using TCP pings — lightweight '
          'network probes that measure latency and availability.\n\n'
          'No installation needed on your server. Just add the URL and PTK '
          'will start tracking response times and online status in real time.',
    );
  }

  Widget _buildAioPage(ColorScheme scheme, TextTheme textTheme) {
    return _SlideLayout(
      icon: Icons.insights_rounded,
      iconColor: Colors.deepOrange,
      title: 'Full Telemetry with AIO',
      description: 'Install the AIO.php script on your server to unlock '
          'full telemetry:\n\n'
          '• CPU load & temperature\n'
          '• RAM usage\n'
          '• Network throughput\n'
          '• System uptime\n\n'
          'All metrics are displayed in real-time charts with history.',
    );
  }

  Widget _buildStatusPagePage(ColorScheme scheme, TextTheme textTheme) {
    return _SlideLayout(
      icon: Icons.cloud_done_rounded,
      iconColor: Colors.blue,
      title: 'Status Pages',
      description: 'Monitor Atlassian-powered status pages for your cloud '
          'services.\n\n'
          'Get instant visibility into incidents, scheduled maintenance, '
          'and component health for services like GitHub, Cloudflare, '
          'Discord, and thousands more.',
    );
  }

  Widget _buildBgMonitorPage(ColorScheme scheme, TextTheme textTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.notifications_active_rounded,
            size: 72,
            color: scheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Background Monitoring',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Choose how you want PTK to monitor your services:',
            style: textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Choice cards
          _ChoiceCard(
            icon: Icons.phone_android_rounded,
            title: 'In-App Only',
            subtitle: 'Monitor only while the app is open',
            selected: !_bgMonitoring,
            onTap: () => setState(() => _bgMonitoring = false),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            icon: Icons.notifications_active_rounded,
            title: 'Background + Notifications',
            subtitle: 'Continuous monitoring with instant alerts, even when the app is closed',
            selected: _bgMonitoring,
            onTap: () => setState(() => _bgMonitoring = true),
          ),

          const SizedBox(height: 32),

          // Demo services section
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'Add demo services?',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Explore the app with sample data',
            style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _addDemoServer,
            onChanged: (v) => setState(() => _addDemoServer = v ?? true),
            title: const Text('Demo Server (puzzak.page)'),
            subtitle: const Text('AIO-enabled server with full telemetry'),
            secondary: const Icon(Icons.dns_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          CheckboxListTile(
            value: _addDemoStatusPage,
            onChanged: (v) => setState(() => _addDemoStatusPage = v ?? true),
            title: const Text('Demo Status Page (GitHub)'),
            subtitle: const Text('Track GitHub service incidents'),
            secondary: const Icon(Icons.cloud_done_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Reusable slide layout ────────────────────────────────

class _SlideLayout extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _SlideLayout({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: iconColor),
          const SizedBox(height: 32),
          Text(
            title,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Choice card for bg monitoring selection ──────────────

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: selected ? 4 : 1,
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: selected ? scheme.onPrimaryContainer : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected
                            ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
