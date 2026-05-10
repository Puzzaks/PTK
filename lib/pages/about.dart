import 'package:flutter/material.dart';
import 'package:PTK/pages/support/elements.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            pinned: true,
            title: Text("About the app"),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Category.settings(title: "Project", context: context),
                Cards(context: context).cardGroup([
                  CardContents.static(
                    title: "Puzzak's ToolKit (PTK)",
                    subtitle: "A simple dashboard for monitoring server health. It uses the AIO.php script to fetch real-time telemetry.",
                  ),
                ]),

                Category.settings(title: "Features", context: context),
                Cards(context: context).cardGroup([
                  CardContents.static(title: "Real-time Monitoring", subtitle: "CPU load, temperature, RAM usage, and network throughput."),
                  CardContents.static(title: "Ping Monitoring", subtitle: "Track latency to your API endpoint."),
                  CardContents.static(title: "Server Uptime", subtitle: "View how long your server has been running."),
                  CardContents.static(title: "Material You", subtitle: "Modern MD3 design with dynamic color support."),
                ]),

                Category.settings(title: "Developer", context: context),
                Cards(context: context).cardGroup([
                  CardContents.tapIcon(
                    title: "Puzzak",
                    subtitle: "Main Developer",
                    icon: Icons.person_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryFixed,
                    colorBG: Theme.of(context).colorScheme.primaryFixedDim,
                    action: () => launchUrl(Uri.parse("https://github.com/Puzzak")),
                  ),
                  CardContents.tap(
                    title: "Visit Website",
                    subtitle: "https://puzzak.page",
                    action: () => launchUrl(Uri.parse("https://puzzak.page")),
                  ),
                ]),

                Category.settings(title: "System Information", context: context),
                Cards(context: context).cardGroup([
                  CardContents.static(
                    title: "Version",
                    subtitle: "0.0.3+3 (Modernized)",
                  ),
                  CardContents.static(
                    title: "Build Framework",
                    subtitle: "Flutter 3.41.6",
                  ),
                ]),

                text.info(
                  title: "Designed and developed by Puzzak. All rights reserved.",
                  subtitle: "GitHub Repository",
                  action: () => launchUrl(Uri.parse("https://github.com/Puzzak/PTK")),
                  context: context,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
