import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:PTK/engine.dart';
import 'package:PTK/services/notification_service.dart';
import 'package:PTK/pages/home.dart';
import 'package:PTK/pages/intro.dart';
import 'package:PTK/pages/settings.dart';
import 'package:PTK/pages/about.dart';
import 'package:PTK/pages/servers.dart';
import 'package:PTK/pages/server_editor.dart';
import 'package:PTK/pages/status_page_editor.dart';
import 'package:PTK/pages/status_page_detail.dart';
import 'package:PTK/pages/status_page_lists.dart';
import 'package:PTK/pages/status_page_updates.dart';
import 'package:PTK/pages/status_pages_manager.dart';
import 'package:PTK/pages/support/elements.dart';

// ---------------------------------------------------------------------------
// PTK v2 — Entry Point
// ---------------------------------------------------------------------------

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  await NotificationService.instance.init(navigatorKey);
  runApp(ChangeNotifierProvider(
    create: (context) => AppEngine(),
    child: const MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    Provider.of<AppEngine>(context, listen: false).start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.processPendingNavigation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final defaultLightColorScheme = ColorScheme.fromSwatch(primarySwatch: Colors.teal);
    final defaultDarkColorScheme  = defaultLightColorScheme.copyWith(brightness: Brightness.dark);

    ThemeData themeData(ColorScheme colorScheme) {
      return ThemeData(
        colorScheme: colorScheme,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          },
        ),
        cardTheme: CardThemeData(
          color: colorScheme.surfaceContainer,
          surfaceTintColor: colorScheme.primary,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.hardEdge,
        ),
        useMaterial3: true,
      );
    }

    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        navigatorKey: navigatorKey,
        theme:     themeData(lightColorScheme ?? defaultLightColorScheme),
        darkTheme: themeData(darkColorScheme  ?? defaultDarkColorScheme),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: kDebugMode,
        initialRoute: 'HomePage',
        onGenerateRoute: (settings) {
          Widget page;
          switch (settings.name) {
            case 'HomePage':
              page = const HomePage();
              break;
            case 'IntroPage':
              page = const IntroPage();
              break;
            case 'SettingsPage':
              page = const SettingsPage();
              break;
            case 'AboutPage':
              page = const AboutPage();
              break;
            case 'ServersPage':
              page = const ServersPage();
              break;
            case 'ServerEditorPage':
              // Editor can receive an existing ServerWatcher via arguments
              page = ServerEditorPage(
                existing: settings.arguments != null
                    ? settings.arguments as dynamic
                    : null,
              );
              break;
            case 'StatusPagesManagerPage':
              page = const StatusPagesManagerPage();
              break;
            case 'StatusPageEditorPage':
              page = StatusPageEditorPage(
                existing: settings.arguments != null
                    ? settings.arguments as dynamic
                    : null,
              );
              break;
            case 'StatusPageDetailPage':
              page = StatusPageDetailPage(
                page: settings.arguments as dynamic,
              );
              break;
            case 'StatusPageIncidentsPage':
              final args = settings.arguments as Map<String, dynamic>;
              page = StatusPageIncidentsPage(
                title: args['title'],
                incidents: args['incidents'],
              );
              break;
            case 'StatusPageMaintenancesPage':
              final args = settings.arguments as Map<String, dynamic>;
              page = StatusPageMaintenancesPage(
                title: args['title'],
                maintenances: args['maintenances'],
              );
              break;
            case 'StatusPageUpdatesPage':
              final args = settings.arguments as Map<String, dynamic>;
              page = StatusPageUpdatesPage(
                title: args['title'],
                updates: args['updates'],
              );
              break;
            // Deep-link from notification tap
            case 'ServerDetailFromNotification':
              final serverId = settings.arguments as String;
              page = _NotificationServerRedirect(serverId: serverId);
              break;
            case 'StatusPageDetailFromNotification':
              final spId = settings.arguments as String;
              page = _NotificationStatusPageRedirect(spId: spId);
              break;
            default:
              page = const HomePage();
          }

          return MaterialPageRoute(
            settings: settings,
            builder: (context) {
              return LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return Consumer<AppEngine>(builder: (context, engine, child) {
                    engine.cards = Cards(context: context);

                    // Gate: show intro if not completed
                    if (engine.appStarted && !engine.introCompleted &&
                        settings.name != 'IntroPage') {
                      return const IntroPage();
                    }

                    return AnimatedCrossFade(
                      alignment: Alignment.center,
                      duration: const Duration(milliseconds: 500),
                      firstChild: SizedBox(
                        height: constraints.maxHeight,
                        width:  constraints.maxWidth,
                        child: page,
                      ),
                      secondChild: const Center(
                        child: CircularProgressIndicator(strokeCap: StrokeCap.round),
                      ),
                      crossFadeState: engine.appStarted
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                    );
                  });
                },
              );
            },
          );
        },
      );
    });
  }
}

/// Redirect widget: finds the server by ID and opens the appropriate page
class _NotificationServerRedirect extends StatelessWidget {
  final String serverId;
  const _NotificationServerRedirect({required this.serverId});

  @override
  Widget build(BuildContext context) {
    // Just show the home page — the server detail is navigated to via
    // the notification service. For now, redirect to home.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final engine = Provider.of<AppEngine>(context, listen: false);
      final server = engine.servers.where((s) => s.id == serverId).firstOrNull;
      if (server != null) {
        Navigator.of(context).pushReplacementNamed('HomePage');
        // Server detail pages use the server object directly
        Navigator.of(context).pushNamed('ServerEditorPage', arguments: server);
      } else {
        Navigator.of(context).pushReplacementNamed('HomePage');
      }
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(strokeCap: StrokeCap.round)),
    );
  }
}

/// Redirect widget: finds the statuspage by ID and opens its detail page
class _NotificationStatusPageRedirect extends StatelessWidget {
  final String spId;
  const _NotificationStatusPageRedirect({required this.spId});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final engine = Provider.of<AppEngine>(context, listen: false);
      final sp = engine.statusPages.where((p) => p.id == spId).firstOrNull;
      if (sp != null) {
        Navigator.of(context).pushReplacementNamed('HomePage');
        Navigator.of(context).pushNamed('StatusPageDetailPage', arguments: sp);
      } else {
        Navigator.of(context).pushReplacementNamed('HomePage');
      }
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(strokeCap: StrokeCap.round)),
    );
  }
}
