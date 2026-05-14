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
  bool _bgMonitoring = false;

  final Set<int> _selectedServers = {};
  final Set<int> _selectedStatusPages = {};

  static const _totalPages = 6;

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

    // Add selected services from the proposals list
    final List servers = engine.dict.demoData['servers'] ?? [];
    for (int idx in _selectedServers) {
      if (idx < servers.length) {
        await engine.addDemoService(servers[idx], true);
      }
    }

    final List statusPages = engine.dict.demoData['statuspages'] ?? [];
    for (int idx in _selectedStatusPages) {
      if (idx < statusPages.length) {
        await engine.addDemoService(statusPages[idx], false);
      }
    }

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
    final engine = Provider.of<AppEngine>(context);
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
                  _buildProposalsPage(scheme, textTheme),
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
                          child: Text(engine.dict.value('intro_skip')),
                        )
                      : const SizedBox(width: 72),

                  // Next / Get Started button
                  _currentPage < _totalPages - 1
                      ? FilledButton(
                          onPressed: _nextPage,
                          child: Text(engine.dict.value('intro_next')),
                        )
                      : FilledButton.icon(
                          onPressed: _finish,
                          icon: const Icon(Icons.check_rounded),
                          label: Text(engine.dict.value('intro_get_started')),
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
    final engine = Provider.of<AppEngine>(context, listen: false);
    return _SlideLayout(
      icon: Icons.hub_rounded,
      icons: [Icons.network_ping_rounded, Icons.insights_rounded, Icons.hub_rounded],
      iconColor: Colors.transparent,
      title: engine.dict.value('intro_welcome_title'),
      description: engine.dict.value('intro_welcome_desc'),
    );
  }

  Widget _buildPingPage(ColorScheme scheme, TextTheme textTheme) {
    final engine = Provider.of<AppEngine>(context, listen: false);
    return _SlideLayout(
      icon: Icons.network_ping_rounded,
      icons: [Icons.hub_rounded],
      iconColor: scheme.primary,
      title: engine.dict.value('intro_ping_title'),
      description: engine.dict.value('intro_ping_desc'),
    );
  }

  Widget _buildAioPage(ColorScheme scheme, TextTheme textTheme) {
    final engine = Provider.of<AppEngine>(context, listen: false);
    return _SlideLayout(
      icon: Icons.insights_rounded,
      icons: [Icons.hub_rounded],
      iconColor: scheme.primary,
      title: engine.dict.value('intro_aio_title'),
      description: engine.dict.value('intro_aio_desc'),
    );
  }

  Widget _buildStatusPagePage(ColorScheme scheme, TextTheme textTheme) {
    final engine = Provider.of<AppEngine>(context, listen: false);
    return _SlideLayout(
      icon: Icons.hub_rounded,
      icons: [Icons.hub_rounded],
      iconColor: scheme.primary,
      title: engine.dict.value('intro_statuspage_title'),
      description: engine.dict.value('intro_statuspage_desc'),
    );
  }

  Widget _buildBgMonitorPage(ColorScheme scheme, TextTheme textTheme) {
    final engine = Provider.of<AppEngine>(context, listen: false);

    return Padding(
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
            engine.dict.value('intro_bg_title'),
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            engine.dict.value('intro_bg_subtitle'),
            style: textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Choice cards
          _ChoiceCard(
            icon: Icons.phone_android_rounded,
            title: engine.dict.value('intro_bg_inapp'),
            subtitle: engine.dict.value('intro_bg_inapp_desc'),
            selected: !_bgMonitoring,
            onTap: () => setState(() => _bgMonitoring = false),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            icon: Icons.notifications_active_rounded,
            title: engine.dict.value('intro_bg_background'),
            subtitle: engine.dict.value('intro_bg_background_desc'),
            selected: _bgMonitoring,
            onTap: () => setState(() => _bgMonitoring = true),
          ),
          const SizedBox(height: 12),

          Text(
            engine.dict.value('intro_bg_tip'),
            style: textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProposalsPage(ColorScheme scheme, TextTheme textTheme) {
    final engine = Provider.of<AppEngine>(context);
    final List servers = engine.dict.demoData['servers'] ?? [];
    final List statusPages = engine.dict.demoData['statuspages'] ?? [];

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          expandedHeight: MediaQuery.of(context).size.height * 0.45,
          pinned: true,
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: true,
          elevation: 0,
          title: Text(
            engine.dict.value('intro_demo_hero')
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 72, color: scheme.primary),
                    const SizedBox(height: 24),
                    Text(
                      engine.dict.value('intro_demo_title'),
                      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      engine.dict.value('intro_demo_desc'),
                      style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (servers.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    engine.dict.value('servers').toUpperCase(),
                    style: textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                ...List.generate(servers.length, (index) {
                  final item = servers[index];
                  final name = item['name'] ?? 'Server';
                  final url = item['link'] ?? '';
                  return CheckboxListTile(
                    value: _selectedServers.contains(index),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedServers.add(index);
                        } else {
                          _selectedServers.remove(index);
                        }
                      });
                    },
                    title: Text(name),
                    subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    secondary: const Icon(Icons.dns_rounded),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  );
                }),
              ],
              if (statusPages.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    engine.dict.value('status_pages').toUpperCase(),
                    style: textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                ...List.generate(statusPages.length, (index) {
                  final item = statusPages[index];
                  final name = item['name'] ?? 'Status Page';
                  final url = item['link'] ?? '';
                  return CheckboxListTile(
                    value: _selectedStatusPages.contains(index),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedStatusPages.add(index);
                        } else {
                          _selectedStatusPages.remove(index);
                        }
                      });
                    },
                    title: Text(name),
                    subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    secondary: const Icon(Icons.hub_rounded),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  );
                }),
              ],
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── Reusable slide layout ────────────────────────────────

class _SlideLayout extends StatelessWidget {
  final IconData icon;
  final List<IconData> icons;
  final Color iconColor;
  final String title;
  final String description;

  const _SlideLayout({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.icons,
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
          icons.length == 1
           ? Icon(icon, size: 72, color: iconColor)
           : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(icons.length, (index) {
              return Icon(icons[index], size: 72, color: iconColor);
            }),
          ),
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
              const SizedBox(width: 16),
              selected
                ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                : Icon(Icons.check_circle_rounded, color: Colors.transparent),
            ],
          ),
        ),
      ),
    );
  }
}
