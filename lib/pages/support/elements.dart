import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';


class Cards {
  double cardMarginV = 2;
  double cardMarginH = 15;
  Radius cardROuter = const Radius.circular(20);
  Radius cardRInner = const Radius.circular(5);
  Map<String,double> cardMargins = {"h":15, "v":2};
  late BuildContext context;

  double cardElevation = 3;

  Cards._internal(this.context);
  factory Cards({required BuildContext context}){
    return Cards._internal(context);
  }

  Color tintColor (context) {
    return Theme.of(context).colorScheme.primary;
  }

  Color cardColor (context) {
    return Theme.of(context).colorScheme.surfaceContainer;
  }

  Widget cardGroup(List<Widget> cards) {
    double width = (WidgetsBinding.instance.platformDispatcher.views.first.physicalSize / WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio).width;
    switch(cards.length){
      case 0: return Container();
      case 1: return Card(
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(cardROuter),
        ),
        surfaceTintColor: tintColor(context),
        color: cardColor(context),
        elevation: cardElevation,
        margin: EdgeInsets.symmetric(
            horizontal: cardMarginH,
            vertical: cardMarginV
        ),
        child: SizedBox(
          width: width - (cardMarginH * 2),
          child: cards[0],
        ),
      );
      case 2: return Column(
        children: [
          Card(
            clipBehavior: Clip.hardEdge,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  bottomRight: cardRInner,
                  topRight: cardROuter,
                  topLeft: cardROuter,
                  bottomLeft: cardRInner
              ),
            ),
            surfaceTintColor: tintColor(context),
            color: cardColor(context),
            elevation: cardElevation,
            margin: EdgeInsets.symmetric(
                horizontal: cardMarginH,
                vertical: cardMarginV
            ),
            child: cards[0],
          ),
          Card(
            clipBehavior: Clip.hardEdge,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  bottomRight: cardROuter,
                  topRight: cardRInner,
                  topLeft: cardRInner,
                  bottomLeft: cardROuter
              ),
            ),
            surfaceTintColor: tintColor(context),
            color: cardColor(context),
            elevation: cardElevation,
            margin: EdgeInsets.symmetric(
                horizontal: cardMarginH,
                vertical: cardMarginV
            ),
            child: cards[1],
          ),
        ],
      );
      default:
        List<Widget> cardsOut = [];
        cardsOut.add(
            Card(
              clipBehavior: Clip.hardEdge,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    bottomRight: cardRInner,
                    topRight: cardROuter,
                    topLeft: cardROuter,
                    bottomLeft: cardRInner
                ),
              ),
              surfaceTintColor: tintColor(context),
              color: cardColor(context),
              elevation: cardElevation,
              margin: EdgeInsets.symmetric(
                  horizontal: cardMarginH,
                  vertical: cardMarginV
              ),
              child: cards[0],
            )
        );
        for(int i = 1; i<cards.length - 1; i++){
          cardsOut.add(
              Card(
                clipBehavior: Clip.hardEdge,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                      bottomRight: cardRInner,
                      topRight: cardRInner,
                      topLeft: cardRInner,
                      bottomLeft: cardRInner
                  ),
                ),
                surfaceTintColor: tintColor(context),
                color: cardColor(context),
                elevation: cardElevation,
                margin: EdgeInsets.symmetric(
                    horizontal: cardMarginH,
                    vertical: cardMarginV
                ),
                child: cards[i],
              )
          );
        }
        cardsOut.add(
            Card(
              clipBehavior: Clip.hardEdge,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    bottomRight: cardROuter,
                    topRight: cardRInner,
                    topLeft: cardRInner,
                    bottomLeft: cardROuter

                ),
              ),
              surfaceTintColor: tintColor(context),
              color: cardColor(context),
              elevation: cardElevation,
              margin: EdgeInsets.symmetric(
                  horizontal: cardMarginH,
                  vertical: cardMarginV
              ),
              child: cards[cards.length - 1],
            )
        );
        return Column(children: cardsOut);
    }
  }
}

class CardContents {
  static Widget tap({
    required String title,
    required String subtitle,
    required VoidCallback action,
  }) {
    double width = (WidgetsBinding.instance.platformDispatcher.views.first.physicalSize / WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio).width;
    return InkWell(
      onTap: action,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 10
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (subtitle == "") const SizedBox(height: 10),
                SizedBox(
                  width: width - 70,
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                if (subtitle != "") ...[
                  const SizedBox(height: 2),
                  SizedBox(
                    width: width - 70,
                    child: Text(
                        subtitle
                    ),
                  ),
                ] else const SizedBox(height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
  static Widget halfTap({
    required String title,
    required String subtitle,
    required VoidCallback action,
  }) {
    double width = (WidgetsBinding.instance.platformDispatcher.views.first.physicalSize / WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio).width;
    return InkWell(
      onTap: action,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 10
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (subtitle == "") const SizedBox(height: 5),
                SizedBox(
                  width: width - 190,
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                if (subtitle != "") ...[
                  const SizedBox(height: 2),
                  SizedBox(
                    width: width - 190,
                    child: Text(
                        subtitle
                    ),
                  ),
                ] else const SizedBox(height: 5),
              ],
            ),
          ],
        ),
      ),
    );
  }
  static Widget tapIcon({
    required String title,
    required String subtitle,
    required VoidCallback action,
    required IconData icon,
    required Color color,
    required Color colorBG
  }) {
    double width = (WidgetsBinding.instance.platformDispatcher.views.first.physicalSize / WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio).width;
    return InkWell(
      onTap: action,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 10
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ClipRRect(
              clipBehavior: Clip.hardEdge,
              borderRadius: const BorderRadius.all(Radius.circular(35)),
              child: Container(
                height: 35,
                width: 35,
                color: colorBG,
                child: Icon(
                  icon,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 15,),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (subtitle == "") const SizedBox(height: 10),
                SizedBox(
                  width: width - 120,
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                if (subtitle != "") ...[
                  const SizedBox(height: 2),
                  SizedBox(
                    width: width - 120,
                    child: Text(
                        subtitle
                    ),
                  ),
                ] else const SizedBox(height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
  static Widget static({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 10
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (subtitle == "") const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != "") ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              overflow: TextOverflow.ellipsis,
            ),
          ] else const SizedBox(height: 10),
        ],
      ),
    );
  }
  static Widget progress({
    required String title,
    required String subtitle,
    required String subsubtitle,
    required double progress
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 10
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (subtitle != "")
              Text(
                subtitle,
                overflow: TextOverflow.ellipsis,
              ),
              if (subsubtitle != "")
              Text(
                subsubtitle,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: subtitle == ""?9:5
            ),
            child: LinearProgressIndicator(
              value: progress < 0 ? null : progress,
              borderRadius: BorderRadius.circular(20),
            ),
          )
        ],
      ),
    );
  }
  static Widget doubleTap({
    required String title,
    required String subtitle,
    required VoidCallback action,
    required VoidCallback secondAction,
    required IconData icon
  }) {
    double width = (WidgetsBinding.instance.platformDispatcher.views.first.physicalSize / WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio).width;

    return InkWell(
      onTap: action,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 10
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (subtitle == "") const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(
                      minWidth: 100,
                      maxWidth: width - 140
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subtitle != "") ...[
                  const SizedBox(height: 2),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        minWidth: 100,
                        maxWidth: width - 140
                    ),
                    child: Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else const SizedBox(height: 10),
              ],
            ),
            IntrinsicHeight(
              child: Row(
                children: [
                  const VerticalDivider(thickness: 3),
                  IconButton(
                    icon: Icon(
                      icon,
                      size: 32,
                    ),
                    onPressed: secondAction,
                  ),
                ],
              ),
            )

          ],
        ),
      ),
    );
  }
  static Widget longTap({
    required String title,
    required String subtitle,
    required VoidCallback action,
    required VoidCallback longAction,
  }) {
    double width = (WidgetsBinding.instance.platformDispatcher.views.first.physicalSize / WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio).width;
    return InkWell(
      onTap: action,
      onLongPress: longAction,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 10
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (subtitle == "") const SizedBox(height: 10),
                SizedBox(
                  width: width - 70,
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                if (subtitle != "") ...[
                  const SizedBox(height: 2),
                  SizedBox(
                    width: width - 70,
                    child: Text(
                        subtitle
                    ),
                  ),
                ] else const SizedBox(height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
  static Widget turn({
    required String title,
    required String subtitle,
    required VoidCallback action,
    required ValueChanged<bool> switcher,
    required bool value
  }) {
    double width = (WidgetsBinding.instance.platformDispatcher.views.first.physicalSize / WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio).width;
    return InkWell(
      onTap: action,
      child: Padding(
        padding: const EdgeInsets.only(
            top: 10,
            bottom: 10,
            right: 15,
            left: 20
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: width - 140
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    subtitle,
                  ),
                ],
              ),
            ),
            Switch(
              value: value, onChanged: switcher,
            ),
          ],
        ),
      ),
    );
  }
  static Widget addretract({
    required String title,
    required String subtitle,
    required VoidCallback actionAdd,
    required VoidCallback actionRetract,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
          top: 10,
          bottom: 10,
          right: 15,
          left: 20
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                subtitle,
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_rounded),
                onPressed: actionRetract,
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: actionAdd,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class Category {
  static Widget settings({
    required String title,
    required BuildContext context
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}



class text {
  static Widget info({
    required String title,
    required String subtitle,
    required VoidCallback action,
    required BuildContext context
  }) {
    double width = (WidgetsBinding.instance.platformDispatcher.views.first.physicalSize / WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio).width;
    return Padding(
      padding: const EdgeInsets.only(
          bottom: 50,
          left: 20,
          right: 20,
          top: 10
      ),
      child: SizedBox(
          width: width - 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (subtitle != "") ...[
                const SizedBox(height: 5),
                InkWell(
                  onTap: action,
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline
                    ),
                  ),
                )
              ]
            ],
          )
      ),
    );
  }
  static Widget infoShort({
    required String title,
    required String subtitle,
    required VoidCallback action,
    required BuildContext context
  }) {
    double width = (WidgetsBinding.instance.platformDispatcher.views.first.physicalSize / WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio).width;
    return Padding(
      padding: const EdgeInsets.only(
          bottom: 0,
          left: 20,
          right: 20,
          top: 10
      ),
      child: SizedBox(
          width: width - 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (subtitle != "") ...[
                const SizedBox(height: 5),
                InkWell(
                  onTap: action,
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline
                    ),
                  ),
                )
              ]
            ],
          )
      ),
    );
  }
}
