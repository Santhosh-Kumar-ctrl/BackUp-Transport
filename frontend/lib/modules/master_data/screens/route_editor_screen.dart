import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../design/design.dart';
import '../data/master_data_api.dart';
import 'admin_network_screen.dart';

class _Draft {
  _Draft(this.stop, this.offset);

  final Stop stop;
  int offset;
}

/// Edit a route's ordered stops. The last stop is the campus; offsets are minutes
/// after departure from the first stop, and never decrease.
class RouteEditorScreen extends ConsumerStatefulWidget {
  const RouteEditorScreen({super.key, required this.routeId});

  final int routeId;

  @override
  ConsumerState<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends ConsumerState<RouteEditorScreen> {
  List<_Draft>? _draft;
  var _dirty = false;
  var _saving = false;
  String? _error;

  void _init(TransitRoute r) {
    _draft ??= [for (final s in r.stops) _Draft(s.stop, s.offsetMin)];
  }

  void _move(int i, int by) => setState(() {
    final d = _draft!.removeAt(i);
    _draft!.insert(i + by, d);
    _dirty = true;
  });

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(masterDataActionsProvider).setStops(widget.routeId, [
        for (final d in _draft!) (stopId: d.stop.id, offsetMin: d.offset),
      ]);
      ref.invalidate(routeProvider(widget.routeId));
      ref.invalidate(routesProvider);
      setState(() => _dirty = false);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addStop() async {
    final all = await ref.read(stopsProvider.future);
    if (!mounted) return;
    final used = _draft!.map((d) => d.stop.id).toSet();
    final picked = await showDialog<Stop>(
      context: context,
      builder: (_) => _StopPicker(options: all.where((s) => !used.contains(s.id)).toList()),
    );
    if (picked == null) return;
    setState(() {
      final lastOffset = _draft!.isEmpty ? 0 : _draft!.last.offset;
      _draft!.add(_Draft(picked, _draft!.isEmpty ? 0 : lastOffset + 5));
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(routeProvider(widget.routeId));
    return AsyncBody(
      value: route,
      onRetry: () => ref.invalidate(routeProvider(widget.routeId)),
      builder: (r) {
        _init(r);
        final d = _draft!;
        final editor = ListView(
          padding: const EdgeInsets.all(Space.gutter),
          children: [
            Row(
              children: [
                const Expanded(child: Text('Stops in order', style: TransitType.heading)),
                SignButton(
                  label: 'Add stop',
                  icon: Icons.add,
                  kind: SignButtonKind.quiet,
                  height: 40,
                  onPressed: _addStop,
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(
              'Minutes are counted from the first stop. End the route at the campus.',
              style: TransitType.small.copyWith(color: TransitColors.inkSoft),
            ),
            const SizedBox(height: Space.m),
            for (var i = 0; i < d.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: Space.s),
                padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
                decoration: BoxDecoration(
                  color: TransitColors.white,
                  borderRadius: Radii.signAll,
                  border: Border(left: BorderSide(color: r.color, width: 6)),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 28, child: Text('${i + 1}', style: TransitType.figure)),
                    Expanded(
                      child: Text(d[i].stop.name, style: TransitType.subheading.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    SizedBox(
                      width: 92,
                      child: TextFormField(
                        key: ValueKey('off-${d[i].stop.id}'),
                        initialValue: '${d[i].offset}',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'min', isDense: true),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null) {
                            d[i].offset = n;
                            setState(() => _dirty = true);
                          }
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Move up',
                      onPressed: i == 0 ? null : () => _move(i, -1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Move down',
                      onPressed: i == d.length - 1 ? null : () => _move(i, 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    IconButton(
                      tooltip: 'Remove from route',
                      onPressed: () => setState(() {
                        d.removeAt(i);
                        _dirty = true;
                      }),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.s),
                child: Text(_error!, style: TransitType.body.copyWith(color: TransitColors.late)),
              ),
            const SizedBox(height: Space.l),
            SignButton(label: _dirty ? 'Save stop order' : 'Saved', busy: _saving, onPressed: _dirty ? _save : null),
          ],
        );
        final preview = ListView(
          padding: const EdgeInsets.fromLTRB(0, Space.gutter, Space.gutter, Space.gutter),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: Space.gutter, bottom: Space.s),
              child: Text('How riders see it', style: TransitType.heading),
            ),
            LineDiagram(
              color: r.color,
              stops: [
                for (var i = 0; i < d.length; i++)
                  LineStop(name: d[i].stop.name, note: d[i].stop.landmark, isTerminus: i == d.length - 1),
              ],
              trailingFor: (i, _) =>
                  Text('+${d[i].offset} min', style: TransitType.small.copyWith(color: TransitColors.inkSoft)),
            ),
          ],
        );
        return Column(
          children: [
            SignHeader(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Back to network',
                    icon: const Icon(Icons.arrow_back, color: TransitColors.white),
                    onPressed: () => context.go('/admin/network'),
                  ),
                  RouteBadge(code: r.code, color: r.color, rim: true),
                ],
              ),
              title: r.name,
              subtitle: r.isActive ? 'Active route' : 'Inactive route',
              trailing: SignButton(
                label: 'Colour',
                kind: SignButtonKind.onDark,
                height: 40,
                onPressed: () => _editColor(r),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  if (c.maxWidth < 900) return editor;
                  return Row(
                    children: [
                      Expanded(flex: 3, child: editor),
                      Expanded(flex: 2, child: preview),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editColor(TransitRoute r) async {
    var color = r.colorHex.toUpperCase();
    final picked = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Line colour', style: TransitType.heading),
          content: ColorPicker(value: color, onChanged: (v) => set(() => color = v)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            SignButton(label: 'Use colour', height: 44, onPressed: () => Navigator.pop(c, color)),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref.read(masterDataActionsProvider).updateRoute(r.id, {'color': picked});
    ref.invalidate(routeProvider(r.id));
    ref.invalidate(routesProvider);
  }
}

class _StopPicker extends ConsumerStatefulWidget {
  const _StopPicker({required this.options});

  final List<Stop> options;

  @override
  ConsumerState<_StopPicker> createState() => _StopPickerState();
}

class _StopPickerState extends ConsumerState<_StopPicker> {
  var _q = '';
  final _newName = TextEditingController();
  final _landmark = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final matches = widget.options.where((s) => s.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return AlertDialog(
      title: const Text('Add stop', style: TransitType.heading),
      content: SizedBox(
        width: 420,
        height: 440,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Find an existing stop'),
              onChanged: (v) => setState(() => _q = v),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final s in matches)
                    ListTile(
                      title: Text(s.name, style: TransitType.subheading),
                      subtitle: s.landmark == null ? null : Text(s.landmark!, style: TransitType.small),
                      onTap: () => Navigator.pop(context, s),
                    ),
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: Space.s),
            TextField(
              controller: _newName,
              decoration: const InputDecoration(labelText: 'Or create a new stop'),
            ),
            const SizedBox(height: Space.s),
            TextField(
              controller: _landmark,
              decoration: const InputDecoration(labelText: 'Landmark (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        SignButton(
          label: 'Create stop',
          height: 44,
          onPressed: () async {
            if (_newName.text.trim().isEmpty) return;
            final s = await ref
                .read(masterDataActionsProvider)
                .createStop(
                  _newName.text.trim(),
                  landmark: _landmark.text.trim().isEmpty ? null : _landmark.text.trim(),
                );
            ref.invalidate(stopsProvider);
            if (context.mounted) Navigator.pop(context, s);
          },
        ),
      ],
    );
  }
}
