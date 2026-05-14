import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:PTK/engine.dart';
import 'package:PTK/models/status_page.dart';
import 'package:PTK/pages/support/elements.dart';

class StatusPageEditorPage extends StatefulWidget {
  final StatusPage? existing;
  const StatusPageEditorPage({super.key, this.existing});

  @override
  State<StatusPageEditorPage> createState() => _StatusPageEditorPageState();
}

class _StatusPageEditorPageState extends State<StatusPageEditorPage> {
  late TextEditingController _urlCtrl;

  bool get _isEditing => widget.existing != null;

  bool _validating = false;
  String? _detectedName;

  bool _overrideDefaults = false;
  List<DetailSection>? _sectionOrder;
  Set<DetailSection>? _sectionsDisabled;
  bool? _bgMonitor;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _urlCtrl = TextEditingController(text: s?.url ?? '');
    _detectedName = s?.name;

    if (s != null) {
      _overrideDefaults = s.customSectionOrder != null || s.customSectionsDisabled != null;
      _sectionOrder = s.customSectionOrder != null ? List.of(s.customSectionOrder!) : null;
      _sectionsDisabled = s.customSectionsDisabled != null ? Set.of(s.customSectionsDisabled!) : null;
      _bgMonitor = s.bgMonitor;
    }

    _urlCtrl.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _urlCtrl.removeListener(_onUrlChanged);
    _urlCtrl.dispose();
    super.dispose();
  }

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
    
    // Prevent re-validation if the URL matches the existing and we already have the name
    if (_isEditing && url == widget.existing!.url && _detectedName != null) return;

    setState(() {
      _validating = true;
      _detectedName = null;
    });
    
    final engine = Provider.of<AppEngine>(context, listen: false);
    final detectedName = await engine.validateStatusPage(url);
    
    if (mounted) {
      setState(() {
        _validating = false;
        _detectedName = detectedName;
      });
    }
  }

  Future<void> _save() async {
    final engine = Provider.of<AppEngine>(context, listen: false);
    final url = _urlCtrl.text.trim();

    if (url.isEmpty || _detectedName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(engine.dict.value('fill_all_fields'))),
      );
      return;
    }

    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        name: _detectedName!,
        url: url,
        customSectionOrder: _overrideDefaults ? _sectionOrder : null,
        customSectionsDisabled: _overrideDefaults ? _sectionsDisabled : null,
        bgMonitor: _bgMonitor,
      );
      await engine.updateStatusPage(updated);
    } else {
      final id = 'sp_${DateTime.now().millisecondsSinceEpoch}';
      await engine.addStatusPage(StatusPage(
        id: id,
        name: _detectedName!,
        url: url,
        order: engine.statusPages.length,
        customSectionOrder: _overrideDefaults ? _sectionOrder : null,
        customSectionsDisabled: _overrideDefaults ? _sectionsDisabled : null,
        bgMonitor: _bgMonitor,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final engine = Provider.of<AppEngine>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(engine.dict.value('delete_statuspage')),
        content: Text(engine.dict.value('delete_statuspage_confirm')),
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
      await engine.deleteStatusPage(widget.existing!.id);
      if (mounted) {
        Navigator.of(context).popUntil((route) {
          final name = route.settings.name;
          return name != 'StatusPageDetailPage' && name != 'StatusPageEditorPage';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppEngine>(builder: (context, engine, _) {
      final scheme = Theme.of(context).colorScheme;

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
                  ? engine.dict.value('edit_statuspage_title')
                  : engine.dict.value('add_statuspage_title')),
              actions: [
                if (_isEditing)
                  IconButton(
                    icon: Icon(Icons.delete_rounded, color: scheme.error),
                    tooltip: engine.dict.value('delete_statuspage'),
                    onPressed: _confirmDelete,
                  ),
                IconButton(
                  icon: Icon(Icons.save_rounded),
                  tooltip: _isEditing
                      ? engine.dict.value('save_changes')
                      : engine.dict.value('add_statuspage'),
                  onPressed: _detectedName != null ? _save : null,
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Category.settings(title: engine.dict.value('server_info'), context: context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: TextField(
                      controller: _urlCtrl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: engine.dict.value('statuspage_url_label'),
                        hintText: engine.dict.value('statuspage_url_hint'),
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
                            : _detectedName != null
                                ? Icon(Icons.check_circle_rounded, color: scheme.primary)
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
                          children: (engine.dict.demoData['statuspages'] as List? ?? []).map((item) {
                            return ActionChip(
                              avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                              label: Text(item['name'] ?? ''),
                              onPressed: () {
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

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _detectedName != null
                        ? Padding(
                            key: const ValueKey('detected'),
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: Card(
                              color: scheme.primaryContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(Icons.hub_rounded, color: scheme.onPrimaryContainer),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            engine.dict.value('statuspage_detected'),
                                            style: TextStyle(
                                              color: scheme.onPrimaryContainer,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            _detectedName!,
                                            style: TextStyle(
                                              color: scheme.onPrimaryContainer,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : _urlCtrl.text.isNotEmpty && !_validating && _detectedName == null
                            ? Padding(
                                key: const ValueKey('not_found'),
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                child: TextPart.infoShort(
                                  title: engine.dict.value('statuspage_not_found'),
                                  subtitle: engine.dict.value('statuspage_url_explainer'),
                                  action: () {},
                                  context: context,
                                ),
                              )
                            : Padding(
                                key: const ValueKey('hint'),
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                child: TextPart.infoShort(
                                  title: engine.dict.value('statuspage_url_explainer'),
                                  subtitle: '',
                                  action: () {},
                                  context: context,
                                ),
                              ),
                  ),

                  Category.settings(title: engine.dict.value('settings'), context: context),
                  engine.cards.cardGroup([
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
                        },
                        switcher: (val) {
                          setState(() => _bgMonitor = val ? null : false);
                        },
                      ),
                    ],
                    CardContents.turn(
                      title: engine.dict.value('override_defaults'),
                      subtitle: engine.dict.value('override_defaults_hint'),
                      value: _overrideDefaults,
                      action: () {
                        setState(() {
                          _overrideDefaults = !_overrideDefaults;
                          if (_overrideDefaults) {
                            _sectionOrder ??= List.of(engine.spSectionOrder);
                            _sectionsDisabled ??= Set.of(engine.spSectionsDisabled);
                          }
                        });
                      },
                      switcher: (val) {
                        setState(() {
                          _overrideDefaults = val;
                          if (val) {
                            _sectionOrder ??= List.of(engine.spSectionOrder);
                            _sectionsDisabled ??= Set.of(engine.spSectionsDisabled);
                          }
                        });
                      },
                    ),
                  ]),



                  if (_overrideDefaults) ...[
                    Category.settings(title: engine.dict.value('sp_section_order'), context: context),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorder: (oldIdx, newIdx) {
                          setState(() {
                            if (newIdx > oldIdx) newIdx--;
                            final item = _sectionOrder!.removeAt(oldIdx);
                            _sectionOrder!.insert(newIdx, item);
                          });
                        },
                        proxyDecorator: (child, _, __) => Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          child: child,
                        ),
                        children: [
                          if (_sectionOrder != null)
                            for (int i = 0; i < _sectionOrder!.length; i++)
                              _SpSectionOverrideTile(
                                key: ValueKey(_sectionOrder![i]),
                                section: _sectionOrder![i],
                                index: i,
                                isEnabled: !_sectionsDisabled!.contains(_sectionOrder![i]),
                                onToggle: (val) {
                                  setState(() {
                                    if (val) {
                                      _sectionsDisabled!.remove(_sectionOrder![i]);
                                    } else {
                                      _sectionsDisabled!.add(_sectionOrder![i]);
                                    }
                                  });
                                },
                                engine: engine,
                              ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 50,)
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _SpSectionOverrideTile extends StatelessWidget {
  final DetailSection section;
  final int index;
  final bool isEnabled;
  final ValueChanged<bool> onToggle;
  final AppEngine engine;

  const _SpSectionOverrideTile({
    super.key,
    required this.section,
    required this.index,
    required this.isEnabled,
    required this.onToggle,
    required this.engine,
  });

  String _getSectionTitle() {
    switch (section) {
      case DetailSection.currentIncidents: return engine.dict.value('sp_section_current_incidents');
      case DetailSection.currentMaintenances: return engine.dict.value('sp_section_current_maintenances');
      case DetailSection.upcomingMaintenances: return engine.dict.value('sp_section_upcoming_maintenances');
      case DetailSection.allScheduledMaintenances: return engine.dict.value('sp_section_all_maintenances');
      case DetailSection.allIncidents: return engine.dict.value('sp_section_all_incidents');
      case DetailSection.components: return engine.dict.value('sp_section_components');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Switch(
              value: isEnabled,
              onChanged: onToggle,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _getSectionTitle(),
                style: TextStyle(
                  fontWeight: FontWeight.w600, 
                  fontSize: 16,
                  color: isEnabled ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
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
