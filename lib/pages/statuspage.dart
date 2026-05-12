import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:PTK/engine.dart';
import 'package:PTK/models/status_page.dart';

class StatuspagePage extends StatelessWidget {
  const StatuspagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppEngine>(builder: (context, engine, _) {
      final scheme = Theme.of(context).colorScheme;
      final pages = engine.statusPages;

      if (pages.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hub_outlined,
                size: 72,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 20),
              Text(
                engine.dict.value('no_statuspages'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  engine.dict.value('no_statuspages_hint'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, 'StatusPageEditorPage'),
                icon: const Icon(Icons.add_rounded),
                label: Text(engine.dict.value('add_statuspage')),
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
      }

      return CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == pages.length) {
                    return const SizedBox(height: 80);
                  }
                  return _StatusPageCard(
                    page: pages[index],
                    engine: engine,
                  );
                },
                childCount: pages.length + 1,
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _StatusPageCard extends StatelessWidget {
  final StatusPage page;
  final AppEngine engine;

  const _StatusPageCard({
    required this.page,
    required this.engine,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = engine.spDataFor(page.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, 'StatusPageDetailPage', arguments: page),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: data.indicator.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      page.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (data.isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              if (data.statusDescription.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  data.statusDescription,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (data.error != null) ...[
                const SizedBox(height: 6),
                Text(
                  data.error!,
                  style: TextStyle(
                    color: scheme.error,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
