import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:PTK/engine.dart';
import 'package:PTK/models/server_watcher.dart';
import 'package:PTK/models/server_telemetry.dart';
import 'package:PTK/pages/support/elements.dart';

/// Page for creating a new server watcher or editing an existing one.
class ServerEditorPage extends StatefulWidget {
  final ServerWatcher? existing;
  const ServerEditorPage({super.key, this.existing});

  @override
  State<ServerEditorPage> createState() => _ServerEditorPageState();
}

class _ServerEditorPageState extends State<ServerEditorPage> {
  late TextEditingController _nameCtrl;
  late TextEditingController _urlCtrl;

  bool get _isEditing => widget.existing != null;

  bool _validating = false;
  bool? _aioDetected;

  bool _overrideDefaults = false;
  GraphStat?  _graphStat;
  ServerStat? _textStat1;
  ServerStat? _textStat2;
  List<DetailGraph>? _graphOrder;
  bool? _bgMonitor;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _nameCtrl   = TextEditingController(text: s?.name ?? '');
    _urlCtrl    = TextEditingController(text: s?.url  ?? '');

    if (s != null) {
      _overrideDefaults = s.graphStat != null || s.graphOrder != null || s.textStat1 != null || s.textStat2 != null;
      _graphStat    = s.graphStat;
      _textStat1    = s.textStat1;
      _textStat2    = s.textStat2;
      _graphOrder   = s.graphOrder != null ? List.of(s.graphOrder!) : null;
      _aioDetected  = s.isAio ? true : null;
      _bgMonitor    = s.bgMonitor;
    }

    _urlCtrl.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _urlCtrl.removeListener(_onUrlChanged);
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  // ── Debounced URL check ───────────────────────────────────
  void _onUrlChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && _urlCtrl.text.trim().isNotEmpty) {
        _validateUrl();
      }
    });
  }

  Future<void> _validateUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() { _validating = true; _aioDetected = null; });
    final engine = Provider.of<AppEngine>(context, listen: false);
    final isAio  = await engine.validateAio(url);
    if (mounted) {
      setState(() { _validating = false; _aioDetected = isAio; });
      // Auto-save stat preferences when AIO is first detected
      if (isAio && _isEditing) _autoSaveStats();
    }
  }

  // ── Auto-save stat/graph preferences ─────────────────────
  Future<void> _autoSaveStats() async {
    if (!_isEditing) return;
    final engine  = Provider.of<AppEngine>(context, listen: false);
    final updated = widget.existing!.copyWith(
      graphStat:  _overrideDefaults ? _graphStat : null,
      textStat1:  _overrideDefaults ? _textStat1 : null,
      textStat2:  _overrideDefaults ? _textStat2 : null,
      graphOrder: _overrideDefaults ? _graphOrder : null,
    );
    await engine.updateServer(updated);
  }

  // ── Save (name + URL only) ────────────────────────────────
  Future<void> _save() async {
    final engine = Provider.of<AppEngine>(context, listen: false);
    final name   = _nameCtrl.text.trim();
    final url    = _urlCtrl.text.trim();

    if (name.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(engine.dict.value('fill_all_fields'))),
      );
      return;
    }

    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        name:       name,
        url:        url,
        isAio:      _aioDetected ?? widget.existing!.isAio,
        graphStat:  _overrideDefaults ? _graphStat : null,
        textStat1:  _overrideDefaults ? _textStat1 : null,
        textStat2:  _overrideDefaults ? _textStat2 : null,
        graphOrder: _overrideDefaults ? _graphOrder : null,
        bgMonitor:  _bgMonitor,
      );
      await engine.updateServer(updated);
    } else {
      final id = 'srv_${DateTime.now().millisecondsSinceEpoch}';
      await engine.addServer(ServerWatcher(
        id:         id,
        name:       name,
        url:        url,
        isAio:      _aioDetected ?? false,
        order:      engine.servers.length,
        graphStat:  _overrideDefaults ? _graphStat : null,
        textStat1:  _overrideDefaults ? _textStat1 : null,
        textStat2:  _overrideDefaults ? _textStat2 : null,
        graphOrder: _overrideDefaults ? _graphOrder : null,
        bgMonitor:  _bgMonitor,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  // ── Delete ────────────────────────────────────────────────
  Future<void> _confirmDelete() async {
    final engine    = Provider.of<AppEngine>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(engine.dict.value('delete_server')),
        content: Text(engine.dict.value('delete_server_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(engine.dict.value('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(engine.dict.value('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await engine.deleteServer(widget.existing!.id);
      if (mounted) {
        Navigator.of(context).popUntil((route) {
          final name = route.settings.name;
          return name != 'ServerDetailPage' && name != 'ServerEditorPage';
        });
      }
    }
  }

  // ── Bottom modal stat picker ──────────────────────────────
  void _showStatPicker({
    required String titleKey,
    required ServerStat? current,
    required void Function(ServerStat?) onSelect,
    bool includeNothing = true,
  }) {
    final engine = Provider.of<AppEngine>(context, listen: false);
    final telem  = engine.telemetryFor(widget.existing?.id ?? '');
    final scheme = Theme.of(context).colorScheme;
    final cards  = Cards(context: context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                engine.dict.value(titleKey),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  cards.cardGroup([
                    // "Nothing" option
                    if (includeNothing)
                      _StatOption(
                        title: engine.dict.value('nothing'),
                        subtitle: engine.dict.value('nothing_subtitle'),
                        isSelected: current == null,
                        scheme: scheme,
                        onTap: () {
                          onSelect(null);
                          _autoSaveStats();
                          Navigator.pop(sheetCtx);
                        },
                      ),
                    // All stat options
                    ...ServerStat.values.map((stat) {
                      final example = engine.statString(stat, telem);
                      return _StatOption(
                        title: stat.label,
                        subtitle: '${engine.dict.value('example_prefix')}$example',
                        isSelected: current == stat,
                        scheme: scheme,
                        onTap: () {
                          onSelect(stat);
                          _autoSaveStats();
                          Navigator.pop(sheetCtx);
                        },
                      );
                    }),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGraphPicker() {
    final engine = Provider.of<AppEngine>(context, listen: false);
    final telem  = engine.telemetryFor(widget.existing?.id ?? '');
    final scheme = Theme.of(context).colorScheme;
    final cards  = Cards(context: context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                engine.dict.value('card_graph'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  cards.cardGroup([
                    ...GraphStat.values.map((stat) {
                      // Build a quick example value
                      String example;
                      switch (stat) {
                        case GraphStat.ping:    example = '${telem.lastPing.toStringAsFixed(0)} ms'; break;
                        case GraphStat.cpuLoad: example = '${telem.cpuLoad.toStringAsFixed(1)}%'; break;
                        case GraphStat.cpuTemp: example = '${telem.cpuTemp.toStringAsFixed(1)} °C'; break;
                        case GraphStat.ramPct:  example = '${(telem.memPct * 100).toStringAsFixed(1)}%'; break;
                        case GraphStat.netIn:   example = engine.formatBytes(telem.netIn, isThroughput: true); break;
                        case GraphStat.netOut:  example = engine.formatBytes(telem.netOut, isThroughput: true); break;
                      }
                      return _StatOption(
                        title: stat.label,
                        subtitle: '${engine.dict.value('example_prefix')}$example',
                        isSelected: _graphStat == stat,
                        scheme: scheme,
                        onTap: () {
                          setState(() => _graphStat = stat);
                          _autoSaveStats();
                          Navigator.pop(sheetCtx);
                        },
                      );
                    }),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<AppEngine>(builder: (context, engine, _) {
      final scheme   = Theme.of(context).colorScheme;
      final telem    = engine.telemetryFor(widget.existing?.id ?? '');
      final showAio  = _aioDetected == true;

      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              surfaceTintColor: Colors.transparent,
              pinned: true,
              leading: Padding(
                padding: const EdgeInsetsDirectional.only(start: 5),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              title: Text(_isEditing
                  ? engine.dict.value('edit_server_title')
                  : engine.dict.value('add_server_title')),
              actions: [
                if (_isEditing)
                  IconButton(
                    icon: Icon(Icons.delete_rounded, color: scheme.error),
                    tooltip: engine.dict.value('delete_server'),
                    onPressed: _confirmDelete,
                  ),
                  IconButton(
                    icon: Icon(Icons.save_rounded),
                    tooltip: _isEditing
                        ? engine.dict.value('save_changes')
                        : engine.dict.value('add_server'),
                    onPressed: _save,
                  ),

              ],
            ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Server info fields (outside cards for proper MD3 label) ──
                  Category.settings(title: engine.dict.value('server_info'), context: context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        hintText: engine.dict.value('display_name'),
                        filled: true,
                        fillColor: scheme.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: scheme.primary, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: TextField(
                      controller: _urlCtrl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: engine.dict.value('server_url_label'),
                        filled: true,
                        fillColor: scheme.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: scheme.primary, width: 2),
                        ),
                        suffixIcon: _validating
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : _aioDetected != null
                                ? Icon(
                                    _aioDetected!
                                        ? Icons.check_circle_rounded
                                        : Icons.wifi_rounded,
                                    color: _aioDetected! ? scheme.primary : scheme.onSurfaceVariant,
                                  )
                                : null,
                      ),
                    ),
                  ),

                  if (!_isEditing) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        child: Wrap(
                          spacing: 8,
                          clipBehavior: Clip.none,
                          direction: Axis.horizontal,
                          children: (engine.dict.demoData['servers'] as List? ?? []).map((item) {
                            return ActionChip(
                              avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                              label: Text(item['name'] ?? ''),
                              onPressed: () {
                                _nameCtrl.text = item['name'] ?? '';
                                _urlCtrl.text = item['link'] ?? '';
                                _validateUrl();
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // ── AIO status info panel ────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _aioDetected == null
                        ? Padding(
                      key: const ValueKey('hint'),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: TextPart.infoShort(
                        title: engine.dict.value('server_url_explainer'),
                        subtitle: engine.dict.value('get_aio_link'),
                        action: () => launchUrl(
                          Uri.parse('https://github.com/Puzzak/AIO-Monitor'),
                          mode: LaunchMode.externalApplication,
                        ),
                        context: context,
                      ),
                    )
                        : _aioDetected!
                    // AIO detected → show live data panel
                        ? _AioInfoPanel(telem: telem, engine: engine, key: const ValueKey('aio'))
                    // Not AIO → show hint with link
                        : Padding(
                      key: const ValueKey('no_aio'),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: TextPart.infoShort(
                        title: engine.dict.value('aio_not_found'),
                        subtitle: engine.dict.value('get_aio_link'),
                        action: () => launchUrl(
                          Uri.parse('https://github.com/Puzzak/AIO-Monitor'),
                          mode: LaunchMode.externalApplication,
                        ),
                        context: context,
                      ),
                    ),
                  ),

                  Category.settings(title: engine.dict.value('settings'), context: context),

          Cards(context: context).cardGroup([
                  // ── Background Monitoring toggle ─────────────
                  if (engine.bgMonitorEnabled) ...[
                      CardContents.turn(
                        title: engine.dict.value('bg_per_entity_monitor'),
                        subtitle: _bgMonitor == null
                            ? '${engine.dict.value('bg_per_entity_default')} (${engine.bgMonitorDefault ? engine.dict.value('bg_monitoring_active') : engine.dict.value('bg_monitoring_inactive')})'
                            : (_bgMonitor! ? engine.dict.value('bg_monitoring_active') : engine.dict.value('bg_monitoring_inactive')),
                        value: _bgMonitor ?? true,
                        action: () {
                          setState(() {
                            if (_bgMonitor == null) {
                              _bgMonitor = false;
                            } else if (_bgMonitor == false) {
                              _bgMonitor = null;
                            } else {
                              _bgMonitor = false;
                            }
                          });
                          if (_isEditing) _autoSaveStats();
                        },
                        switcher: (val) {
                          setState(() => _bgMonitor = val ? null : false);
                          if (_isEditing) _autoSaveStats();
                        },
                      ),
                  ],
            if (showAio) ...[
              CardContents.turn(
                title: engine.dict.value('override_defaults'),
                subtitle: engine.dict.value('override_defaults_hint'),
                value: _overrideDefaults,
                action: () {
                  setState(() {
                    _overrideDefaults = !_overrideDefaults;
                    if (_overrideDefaults) {
                      _graphStat ??= engine.defaultGraphStat;
                      _textStat1 ??= engine.defaultTextStat1;
                      _textStat2 ??= engine.defaultTextStat2;
                      _graphOrder ??= List.of(engine.defaultGraphOrder);
                    }
                  });
                  _autoSaveStats();
                },
                switcher: (val) {
                  setState(() {
                    _overrideDefaults = val;
                    if (val) {
                      _graphStat ??= engine.defaultGraphStat;
                      _textStat1 ??= engine.defaultTextStat1;
                      _textStat2 ??= engine.defaultTextStat2;
                      _graphOrder ??= List.of(engine.defaultGraphOrder);
                    }
                  });
                  _autoSaveStats();
                },
              ),
            ],

          ]),
                  // ── Configuration Overrides (AIO only) ──────────


                  // ── Card display pickers (AIO only, one group) ──
                  if (showAio && _overrideDefaults) ...[
                    Category.settings(title: engine.dict.value('card_display'), context: context),
                    Cards(context: context).cardGroup([
                      CardContents.tapIcon(
                        title: engine.dict.value('card_graph'),
                        subtitle: _graphStat?.label ?? '',
                        action: _showGraphPicker,
                        icon: Icons.show_chart_rounded,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                        colorBG: Theme.of(context).colorScheme.tertiaryContainer,
                      ),
                      CardContents.tapIcon(
                        title: engine.dict.value('card_stat_1'),
                        subtitle: _textStat1?.label ?? engine.dict.value('nothing'),
                        action: () => _showStatPicker(
                          titleKey: 'card_stat_1',
                          current:  _textStat1,
                          onSelect: (v) => setState(() => _textStat1 = v),
                        ),
                        icon: Icons.align_horizontal_left,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                        colorBG: Theme.of(context).colorScheme.tertiaryContainer,
                      ),
                      CardContents.tapIcon(
                        title: engine.dict.value('card_stat_2'),
                        subtitle: _textStat2?.label ?? engine.dict.value('nothing'),
                        action: () => _showStatPicker(
                          titleKey: 'card_stat_2',
                          current:  _textStat2,
                          onSelect: (v) => setState(() => _textStat2 = v),
                        ),
                        icon: Icons.align_horizontal_right_rounded,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                        colorBG: Theme.of(context).colorScheme.tertiaryContainer,
                      ),
                    ]),
                  ],

                  // ── Graph order reorderable list (AIO only) ──
                  if (showAio && _overrideDefaults) ...[
                    Category.settings(title: engine.dict.value('graph_order'), context: context),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorder: (oldIdx, newIdx) {
                          setState(() {
                            if (newIdx > oldIdx) newIdx--;
                            final item = _graphOrder!.removeAt(oldIdx);
                            _graphOrder!.insert(newIdx, item);
                          });
                          _autoSaveStats();
                        },
                        proxyDecorator: (child, _, animation) => Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          child: child,
                        ),
                        children: [
                          if (_graphOrder != null)
                            for (int i = 0; i < _graphOrder!.length; i++)
                              _GraphOrderTile(
                                key: ValueKey(_graphOrder![i]),
                                graph: _graphOrder![i],
                                index: i,
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextPart.info(
                      title: engine.dict.value('graph_order_hint'),
                      subtitle: '',
                      action: (){},
                      context: context
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── Stat option row (PAIOS-style with dot) ─────────────────

class _StatOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _StatOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            // PAIOS-style selection dot
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

// ── AIO info panel (live data shown when AIO is detected) ──

class _AioInfoPanel extends StatelessWidget {
  final ServerTelemetry telem;
  final AppEngine engine;

  const _AioInfoPanel({super.key, required this.telem, required this.engine});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Card(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.monitor_heart_rounded, color: scheme.onPrimaryContainer, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    engine.dict.value('aio_detected'),
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 6,
                children: [
                  _InfoChip(label: 'CPU', value: '${telem.cpuLoad.toStringAsFixed(1)}%', scheme: scheme),
                  _InfoChip(label: 'Temp', value: '${telem.cpuTemp.toStringAsFixed(1)} °C', scheme: scheme),
                  _InfoChip(label: 'RAM', value: '${(telem.memPct * 100).toStringAsFixed(0)}%', scheme: scheme),
                  _InfoChip(label: 'Ping', value: '${telem.lastPing.toStringAsFixed(0)} ms', scheme: scheme),
                  _InfoChip(label: 'Up', value: telem.uptime, scheme: scheme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme scheme;

  const _InfoChip({required this.label, required this.value, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.onPrimaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ── Graph order list tile ─────────────────────────────────

class _GraphOrderTile extends StatelessWidget {
  final DetailGraph graph;
  final int index;

  const _GraphOrderTile({super.key, required this.graph, required this.index});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.bar_chart_rounded, color: scheme.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                graph.label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_handle_rounded, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
