import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:PTK/engine.dart';
import 'package:PTK/pages/support/elements.dart';

import 'package:PTK/pages/settings_servers.dart';
import 'package:PTK/pages/settings_statuspages.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _openNotificationSettings() async {
    const platform = MethodChannel('page.puzzak.ptk/settings');
    try {
      await platform.invokeMethod('openNotificationSettings');
    } catch (_) {
      // Fallback: use Android intent via url_launcher or just ignore
    }
  }

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
              title: Text(engine.dict.value('settings')),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Category.settings(title: engine.dict.value('settings_app'), context: context),
                  cards.cardGroup([
                    CardContents.doubleTap(
                      title:       engine.dict.value('select_language'),
                      subtitle:    engine.dict.languages.firstWhere(
                              (e) => e['id'] == engine.dict.locale,
                          orElse: () => {'name': 'English'})['name'],
                      icon:        Icons.language_rounded,
                      action: () {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            contentPadding: const EdgeInsets.only(top: 10, bottom: 15),
                            titlePadding:   const EdgeInsets.only(top: 20, right: 20, left: 20),
                            title: Text(engine.dict.value('select_language')),
                            content: SingleChildScrollView(
                              child: cards.cardGroup(
                                engine.dict.languages.map((language) {
                                  return CardContents.halfTap(
                                    title:    language['origin'] ?? language['name'],
                                    subtitle: language['name'] == language['origin'] ? '' : language['name'],
                                    action: () async {
                                      final nav = Navigator.of(dialogContext);
                                      await engine.dict.saveLanguage(language['id']);
                                      engine.genericRefresh();
                                      nav.pop();
                                    },
                                  );
                                }).toList().cast<Widget>(),
                              ),
                            ),
                          ),
                        );
                      },
                      secondAction: () async {
                        await engine.dict.setSystemLanguage();
                        engine.genericRefresh();
                      },
                    ),
                    CardContents.turn(
                      title: engine.dict.value('default_tab'),
                      subtitle: engine.defaultTab == 0
                          ? engine.dict.value('default_tab_servers')
                          : engine.dict.value('default_tab_statuspages'),
                      value: engine.defaultTab == 1,
                      action: () => engine.defaultTab = engine.defaultTab == 0 ? 1 : 0,
                      switcher: (v) => engine.defaultTab = v ? 1 : 0,
                    ),
                    CardContents.turn(
                      title: engine.dict.value('bg_monitoring'),
                      subtitle: engine.bgMonitorEnabled
                          ? engine.dict.value('bg_monitoring_active')
                          : engine.dict.value('bg_monitoring_inactive'),
                      value: engine.bgMonitorEnabled,
                      action: () async {
                        final newVal = !engine.bgMonitorEnabled;
                        if (newVal) {
                          // Request permissions before enabling
                          final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
                          if (notifPerm != NotificationPermission.granted) {
                            await FlutterForegroundTask.requestNotificationPermission();
                          }
                          if (Platform.isAndroid) {
                            if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
                              await FlutterForegroundTask.requestIgnoreBatteryOptimization();
                            }
                          }
                        }
                        await engine.setBgMonitorEnabled(newVal);
                      },
                      switcher: (v) async {
                        if (v) {
                          final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
                          if (notifPerm != NotificationPermission.granted) {
                            await FlutterForegroundTask.requestNotificationPermission();
                          }
                          if (Platform.isAndroid) {
                            if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
                              await FlutterForegroundTask.requestIgnoreBatteryOptimization();
                            }
                          }
                        }
                        await engine.setBgMonitorEnabled(v);
                      },
                    ),
                    if (engine.bgMonitorEnabled)
                      CardContents.tapIcon(
                        title: engine.dict.value('bg_notification_settings'),
                        subtitle: '',
                        icon: Icons.notifications_rounded,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                        colorBG: Theme.of(context).colorScheme.tertiaryContainer,
                        action: () => _openNotificationSettings(),
                      ),
                  ]),
                  // ── Configuration ──────────────────────────────
                  Category.settings(title: engine.dict.value('settings'), context: context),
                  cards.cardGroup([
                    CardContents.tapIcon(
                      title: engine.dict.value('settings_servers'),
                      subtitle: engine.servers.length == 1
                          ? '1 ${engine.dict.value('servers_configured')}'
                          : '${engine.servers.length} ${engine.dict.value('servers_configured_plural')}',
                      icon: Icons.dns_rounded,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      colorBG: Theme.of(context).colorScheme.tertiaryContainer,
                      action: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsServersPage(),
                          settings: const RouteSettings(name: 'SettingsServersPage'),
                        ),
                      ),
                    ),
                    CardContents.tapIcon(
                      title: engine.dict.value('settings_statuspages'),
                      subtitle: engine.statusPages.length == 1
                        ? '1 ${engine.dict.value('statuspages_configured')}'
                            : '${engine.statusPages.length} ${engine.dict.value('statuspages_configured_plural')}',
                      icon: Icons.hub_rounded,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      colorBG: Theme.of(context).colorScheme.tertiaryContainer,
                      action: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsStatuspagesPage(),
                          settings: const RouteSettings(name: 'SettingsStatuspagesPage'),
                        ),
                      ),
                    ),
                  ]),
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


