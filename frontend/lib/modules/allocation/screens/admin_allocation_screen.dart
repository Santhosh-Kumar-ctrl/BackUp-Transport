import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/session.dart';
import '../../../design/design.dart';
import '../../auth/data/people_api.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../master_data/data/master_data_api.dart';
import '../data/allocation_api.dart';

/// Pick a route, see its stops as a line with the students waiting at each one,
/// and assign or move students.
class AdminAllocationScreen extends ConsumerStatefulWidget {
  const AdminAllocationScreen({super.key});

  @override
  ConsumerState<AdminAllocationScreen> createState() => _AdminAllocationScreenState();
}

class _AdminAllocationScreenState extends ConsumerState<AdminAllocationScreen> {
  int? _routeId;

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(routesProvider);
    return Column(
      children: [
        const SignHeader(title: 'Allocation', subtitle: 'Which route and stop each student rides'),
        Expanded(
          child: AsyncBody(
            value: routes,
            onRetry: () => ref.invalidate(routesProvider),
            builder: (list) {
              if (list.isEmpty) {
                return const SignNotice(
                  title: 'No routes yet',
                  body: 'Create routes in Network before allocating students.',
                );
              }
              final route = list.firstWhere((r) => r.id == _routeId, orElse: () => list.first);
              return Column(
                children: [
                  SizedBox(
                    height: 64,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.s),
                      children: [
                        for (final r in list)
                          Padding(
                            padding: const EdgeInsets.only(right: Space.s),
                            child: InkWell(
                              onTap: () => setState(() => _routeId = r.id),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                                decoration: BoxDecoration(
                                  color: TransitColors.white,
                                  borderRadius: Radii.signAll,
                                  border: Border.all(
                                    color: r.id == route.id ? TransitColors.ink : TransitColors.rule,
                                    width: r.id == route.id ? 2.5 : 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    RouteBadge(code: r.code, color: r.color, size: 36),
                                    const SizedBox(width: Space.s),
                                    Text(r.name, style: TransitType.subheading.copyWith(fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(child: _RouteAllocations(route: route)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RouteAllocations extends ConsumerWidget {
  const _RouteAllocations({required this.route});

  final TransitRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allocs = ref.watch(routeAllocationsProvider(route.id));
    return AsyncBody(
      value: allocs,
      onRetry: () => ref.invalidate(routeAllocationsProvider(route.id)),
      builder: (list) {
        final byStop = <int, List<Allocation>>{};
        for (final a in list) {
          byStop.putIfAbsent(a.stopId, () => []).add(a);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, Space.s, Space.gutter, Space.xxl),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: Space.gutter, bottom: Space.m),
              child: Row(
                children: [
                  Expanded(child: Text('${list.length} students on route ${route.code}', style: TransitType.heading)),
                  SignButton(
                    label: 'Assign student',
                    icon: Icons.person_add_alt,
                    height: 44,
                    onPressed: () => _assign(context, ref, route),
                  ),
                ],
              ),
            ),
            if (route.stops.isEmpty)
              const SignNotice(title: 'This route has no stops', body: 'Add stops in Network first.'),
            LineDiagram(
              color: route.color,
              stops: [
                for (var i = 0; i < route.stops.length; i++)
                  LineStop(
                    name: route.stops[i].stop.name,
                    note: _names(byStop[route.stops[i].stop.id]),
                    isTerminus: i == route.stops.length - 1,
                  ),
              ],
              trailingFor: (i, _) {
                final here = byStop[route.stops[i].stop.id] ?? const [];
                return here.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () => _manageStop(context, ref, route, route.stops[i].stop, here),
                        child: Text('${here.length}'),
                      );
              },
            ),
          ],
        );
      },
    );
  }

  static String? _names(List<Allocation>? list) {
    if (list == null || list.isEmpty) return null;
    final names = list.map((a) => a.studentName).toList();
    return names.length <= 4 ? names.join(', ') : '${names.take(4).join(', ')} and ${names.length - 4} more';
  }

  Future<void> _manageStop(BuildContext context, WidgetRef ref, TransitRoute route, Stop stop, List<Allocation> here) =>
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(stop.name, style: TransitType.heading),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final a in here)
                  ListTile(
                    title: Text(a.studentName, style: TransitType.subheading),
                    subtitle: a.rollNo == null ? null : Text(a.rollNo!, style: TransitType.small),
                    trailing: TextButton(
                      onPressed: () async {
                        await ref.read(allocationActionsProvider).unassign(a.studentId);
                        ref.invalidate(routeAllocationsProvider(route.id));
                        ref.invalidate(adminDashboardProvider);
                        if (c.mounted) Navigator.pop(c);
                      },
                      child: const Text('Remove'),
                    ),
                  ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
        ),
      );

  Future<void> _assign(BuildContext context, WidgetRef ref, TransitRoute route) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _AssignDialog(route: route),
    );
    if (done == true) {
      ref.invalidate(routeAllocationsProvider(route.id));
      ref.invalidate(adminDashboardProvider);
    }
  }
}

class _AssignDialog extends ConsumerStatefulWidget {
  const _AssignDialog({required this.route});

  final TransitRoute route;

  @override
  ConsumerState<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends ConsumerState<_AssignDialog> {
  var _q = '';
  Person? _student;
  int? _stopId;
  var _busy = false;
  String? _error;
  ApiException? _full;

  Future<void> _submit({bool force = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final out = await ref
          .read(allocationActionsProvider)
          .assign(studentId: _student!.id, routeId: widget.route.id, stopId: _stopId!, force: force);
      if (!mounted) return;
      Navigator.pop(context, true);
      if (out.warnings.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(out.warnings.join('\n'))));
      }
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        if (e.code == 'route_full') {
          _full = e;
        } else {
          _error = e.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.route;
    final people = ref.watch(peopleProvider((role: Role.student, q: _q)));
    final pickupStops = r.stops.length > 1 ? r.stops.sublist(0, r.stops.length - 1) : r.stops;
    return AlertDialog(
      title: Row(
        children: [
          RouteBadge(code: r.code, color: r.color, size: 34),
          const SizedBox(width: Space.m),
          const Text('Assign student', style: TransitType.heading),
        ],
      ),
      content: SizedBox(
        width: 460,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_student == null) ...[
              TextField(
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Search student by name or roll no'),
                onChanged: (v) => setState(() => _q = v.trim()),
              ),
              Expanded(
                child: AsyncBody(
                  value: people,
                  builder: (list) => ListView(
                    children: [
                      for (final p in list)
                        ListTile(
                          title: Text(p.fullName, style: TransitType.subheading),
                          subtitle: Text(
                            [p.rollNo, p.department].whereType<String>().join(', '),
                            style: TransitType.small,
                          ),
                          onTap: () => setState(() => _student = p),
                        ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Text(_student!.fullName, style: TransitType.heading),
              Text(_student!.rollNo ?? '', style: TransitType.small.copyWith(color: TransitColors.inkSoft)),
              const SizedBox(height: Space.l),
              const Text('Boards at', style: TransitType.subheading),
              const SizedBox(height: Space.s),
              Expanded(
                child: RadioGroup<int>(
                  groupValue: _stopId,
                  onChanged: (v) => setState(() => _stopId = v),
                  child: ListView(
                    children: [
                      for (final s in pickupStops)
                        RadioListTile<int>(
                          value: s.stop.id,
                          title: Text(s.stop.name, style: TransitType.subheading),
                          subtitle: s.stop.landmark == null ? null : Text(s.stop.landmark!, style: TransitType.small),
                        ),
                    ],
                  ),
                ),
              ),
              if (_full != null)
                Container(
                  padding: const EdgeInsets.all(Space.m),
                  decoration: const BoxDecoration(
                    color: TransitColors.white,
                    border: Border(left: BorderSide(color: TransitColors.caution, width: 5)),
                  ),
                  child: Text(
                    '${_full!.message}. Allocate anyway? Some students may have to stand.',
                    style: TransitType.body,
                  ),
                ),
              if (_error != null) Text(_error!, style: TransitType.body.copyWith(color: TransitColors.late)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        if (_student != null)
          SignButton(
            label: _full != null ? 'Allocate anyway' : 'Assign',
            height: 44,
            busy: _busy,
            kind: _full != null ? SignButtonKind.danger : SignButtonKind.primary,
            onPressed: _stopId == null ? null : () => _submit(force: _full != null),
          ),
      ],
    );
  }
}
