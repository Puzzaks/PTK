import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:PTK/engine.dart';
import 'package:PTK/pages/support/elements.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _locController;

  @override
  void initState() {
    super.initState();
    final engine = Provider.of<AppEngine>(context, listen: false);
    _locController = TextEditingController(text: engine.loc);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppEngine>(builder: (context, engine, child) {
      Cards cards = engine.cards;

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
              title: Text(engine.dict.value("settings")),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Category.settings(title: "Connection", context: context),
                  cards.cardGroup([
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: TextField(
                        controller: _locController,
                        decoration: InputDecoration(
                          labelText: "API Endpoint URL",
                          hintText: "https://api.puzzak.page/AIO.php",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check_rounded),
                            onPressed: () {
                              engine.loc = _locController.text;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("API Endpoint saved")),
                              );
                            },
                          ),
                        ),
                        onSubmitted: (v) => engine.loc = v,
                      ),
                    ),
                    CardContents.tap(
                      title: "Reset to Default",
                      subtitle: "https://api.puzzak.page/AIO.php",
                      action: () {
                        _locController.text = "https://api.puzzak.page/AIO.php";
                        engine.loc = _locController.text;
                      },
                    ),
                  ]),

                  Category.settings(title: "Updates", context: context),
                  cards.cardGroup([
                    CardContents.turn(
                      title: "Auto Update",
                      subtitle: "Automatically fetch new data from the server",
                      value: engine.isAutoUpdate,
                      action: () => engine.isAutoUpdate = !engine.isAutoUpdate,
                      switcher: (v) => engine.isAutoUpdate = v,
                    ),
                    CardContents.addretract(
                      title: "Update Interval",
                      subtitle: "${engine.updateRate} seconds",
                      actionAdd: () => engine.updateRate++,
                      actionRetract: () {
                        if (engine.updateRate > 1) engine.updateRate--;
                      },
                    ),
                  ]),

                  Category.settings(title: "Network", context: context),
                  cards.cardGroup([
                    CardContents.turn(
                      title: "Use Bits",
                      subtitle: "Display network speed in bits per second (b/s)",
                      value: engine.useBits,
                      action: () => engine.useBits = !engine.useBits,
                      switcher: (v) => engine.useBits = v,
                    ),
                  ]),

                  Category.settings(title: engine.dict.value("settings_app"), context: context),
                  cards.cardGroup([
                    CardContents.doubleTap(
                      title:        engine.dict.value("select_language"),
                      subtitle:     engine.dict.languages.firstWhere((e) => e["id"] == engine.dict.locale, orElse: () => {"name": "English"})["name"],
                      icon:         Icons.language_rounded,
                      action: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) => AlertDialog(
                            contentPadding: const EdgeInsets.only(top: 10, bottom: 15),
                            titlePadding:   const EdgeInsets.only(top: 20, right: 20, left: 20),
                            title: Text(engine.dict.value("select_language")),
                            content: SingleChildScrollView(
                              child: cards.cardGroup(
                                engine.dict.languages.map((language) {
                                  return CardContents.halfTap(
                                    title:    language["origin"],
                                    subtitle: language["name"] == language["origin"]
                                        ? ""
                                        : language["name"],
                                    action: () async {
                                      await engine.dict.saveLanguage(language["id"]);
                                      engine.genericRefresh();
                                      Navigator.of(dialogContext).pop();
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
