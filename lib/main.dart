import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:PTK/engine.dart';
import 'package:PTK/pages/home.dart';
import 'package:PTK/pages/settings.dart';
import 'package:PTK/pages/about.dart';
import 'package:PTK/pages/support/elements.dart';

// ---------------------------------------------------------------------------
// PTK — Entry Point
// ---------------------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  }

  @override
  Widget build(BuildContext context) {
    final defaultLightColorScheme = ColorScheme.fromSwatch(primarySwatch: Colors.teal);
    final defaultDarkColorScheme = defaultLightColorScheme.copyWith(brightness: Brightness.dark);

    ThemeData themeData(colorScheme) {
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
        theme: themeData(lightColorScheme ?? defaultLightColorScheme),
        darkTheme: themeData(darkColorScheme ?? defaultDarkColorScheme),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: kDebugMode,
        initialRoute: 'HomePage',
        onGenerateRoute: (settings) {
          Widget page;
          switch (settings.name) {
            case 'HomePage':
              page = const HomePage();
              break;
            case 'SettingsPage':
              page = const SettingsPage();
              break;
            case 'AboutPage':
              page = const AboutPage();
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

                    return AnimatedCrossFade(
                      alignment: Alignment.center,
                      duration: const Duration(milliseconds: 500),
                      firstChild: SizedBox(
                        height: constraints.maxHeight,
                        width: constraints.maxWidth,
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
