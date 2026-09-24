import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/session.dart';
import '../../../design/design.dart';
import '../../auth/data/people_api.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../master_data/data/master_data_api.dart';
import '../data/trips_api.dart';

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String daysLabel(List<int> days) {
  if (days.length == 7) return 'Every day';
  if (days.toSet().containsAll([1, 2, 3, 4, 5]) && days.length == 5) return 'Weekdays';
  if (days.toSet().containsAll([1, 2, 3, 4, 5, 6]) && days.length == 6) return 'Mon to Sat';
  return days.map((d) => _dayNames[d - 1]).join(', ');
}

/// The timetable: which bus and driver run each route, when.
class AdminSchedulesScreen extends ConsumerWidget {
  const AdminSchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(schedulesProvider);
    final routes = ref.watch(routesProvider);
    final buses = ref.watch(busesProvider);
    final drivers = ref.watch(peopleProvider((role: Role.driver, q: '')));

    return Column(
      children: [
        SignHeader(
          title: 'Schedules',
          subtitle: 'Trips are created from these every day',
          trailing: SignButton(
            label: 'Add schedule',
            icon: Icons.add,
            kind: SignButtonKind.onDark,
            height: 44,
            onPressed: () async {
              if (await showDialog<bool>(context: context, builder: (_) => const _ScheduleDialog()) == true) {
                ref.invalidate(schedulesProvider);
              }
            },
          ),
        ),
        Expanded(
          child: AsyncBody(
            value: schedules,
            onRetry: () => ref.invalidate(schedulesProvider),
            builder: (list) {
              final rmap = {for (final r in routes.asData?.value ?? <TransitRoute>[]) r.id: r};
              final bmap = {for (final b in buses.asData?.value ?? <Bus>[]) b.id: b};
              final dmap = {for (final d in drivers.asData?.value ?? <Person>[]) d.id: d};
              if (list.isEmpty) {
                return const SignNotice(
                  title: 'No schedules yet',
                  body: 'Add a schedule to put a bus and driver on a route.',
                );
              }
              final sorted = [...list]
                ..sort(
                  (a, b) =>
                      (rmap[a.routeId]?.code ?? '').compareTo(rmap[b.routeId]?.code ?? '') * 10 +
                      a.departureTime.compareTo(b.departureTime).sign,
                );
              return ListView.separated(
                padding: const EdgeInsets.all(Space.gutter),
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (_, i) {
                  final s = sorted[i];
                  final r = rmap[s.routeId];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.m),
                    child: Opacity(
                      opacity: s.isActive ? 1 : 0.5,
                      child: Row(
                        children: [
                          if (r != null) RouteBadge(code: r.code, color: r.color, size: 40),
                          const SizedBox(width: Space.m),
                          SizedBox(
                            width: 72,
                            child: Text(s.departureHm, style: TransitType.figure.copyWith(fontSize: 22)),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${s.direction == 'pickup' ? 'Pickup' : 'Drop'}, ${daysLabel(s.days)}',
                                  style: TransitType.subheading.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  dmap[s.driverId]?.fullName ?? 'Driver #${s.driverId}',
                                  style: TransitType.small.copyWith(color: TransitColors.inkSoft),
                                ),
                              ],
                            ),
                          ),
                          if (bmap[s.busId] != null) NumberPlate(bmap[s.busId]!.registration, dense: true),
                          const SizedBox(width: Space.s),
                          TextButton(
                            onPressed: () async {
                              await ref.read(tripActionsProvider).updateSchedule(s.id, {'is_active': !s.isActive});
                              ref.invalidate(schedulesProvider);
                            },
                            child: Text(s.isActive ? 'Pause' : 'Resume'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ScheduleDialog extends ConsumerStatefulWidget {
  const _ScheduleDialog();

  @override
  ConsumerState<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends ConsumerState<_ScheduleDialog> {
  int? _route;
  int? _bus;
  int? _driver;
  var _direction = 'pickup';
  var _time = const TimeOfDay(hour: 7, minute: 30);
  final _days = {1, 2, 3, 4, 5, 6};
  String? _error;
  var _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      String two(int n) => n.toString().padLeft(2, '0');
      await ref.read(tripActionsProvider).createSchedule({
        'route_id': _route,
        'bus_id': _bus,
        'driver_id': _driver,
        'direction': _direction,
        'departure_time': '${two(_time.hour)}:${two(_time.minute)}:00',
        'days_of_week': _days.toList()..sort(),
      });
      // Today's trip appears on the board straight away if the schedule runs today.
      await ref.read(tripActionsProvider).generateToday();
      ref.invalidate(adminDashboardProvider);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(routesProvider).asData?.value ?? [];
    final buses = (ref.watch(busesProvider).asData?.value ?? []).where((b) => b.status != 'retired').toList();
    final drivers = ref.watch(peopleProvider((role: Role.driver, q: ''))).asData?.value ?? [];
    return AlertDialog(
      title: const Text('Add schedule', style: TransitType.heading),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _route,
                decoration: const InputDecoration(labelText: 'Route'),
                items: [for (final r in routes) DropdownMenuItem(value: r.id, child: Text('${r.code}  ${r.name}'))],
                onChanged: (v) => setState(() => _route = v),
              ),
              const SizedBox(height: Space.m),
              DropdownButtonFormField<int>(
                initialValue: _bus,
                decoration: const InputDecoration(labelText: 'Bus'),
                items: [
                  for (final b in buses)
                    DropdownMenuItem(
                      value: b.id,
                      child: Text(
                        '${NumberPlate.format(b.registration)}, ${b.capacity} seats'
                        '${b.driverName != null ? ', ${b.driverName}' : ''}',
                      ),
                    ),
                ],
                // Picking a bus pre-selects its regular driver; the admin can still change it.
                onChanged: (v) => setState(() {
                  _bus = v;
                  _driver = buses.where((b) => b.id == v).firstOrNull?.driverId ?? _driver;
                }),
              ),
              const SizedBox(height: Space.m),
              DropdownButtonFormField<int>(
                key: ValueKey('driver-$_driver'), // rebuild when pre-filled from the bus
                initialValue: _driver,
                decoration: const InputDecoration(labelText: 'Driver'),
                items: [
                  for (final d in drivers.where((d) => d.isActive))
                    DropdownMenuItem(value: d.id, child: Text(d.fullName)),
                ],
                onChanged: (v) => setState(() => _driver = v),
              ),
              const SizedBox(height: Space.l),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pickup', label: Text('Pickup, to campus')),
                  ButtonSegment(value: 'drop', label: Text('Drop, from campus')),
                ],
                selected: {_direction},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _direction = s.first),
              ),
              const SizedBox(height: Space.l),
              Row(
                children: [
                  const Text('Departs', style: TransitType.subheading),
                  const SizedBox(width: Space.m),
                  SignButton(
                    label: _time.format(context),
                    kind: SignButtonKind.quiet,
                    height: 42,
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _time);
                      if (t != null) setState(() => _time = t);
                    },
                  ),
                ],
              ),
              const SizedBox(height: Space.l),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(_dayNames[d - 1]),
                      selected: _days.contains(d),
                      showCheckmark: false,
                      shape: const RoundedRectangleBorder(borderRadius: Radii.signAll),
                      onSelected: (on) => setState(() => on ? _days.add(d) : _days.remove(d)),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: Space.m),
                Text(_error!, style: TransitType.body.copyWith(color: TransitColors.late)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        SignButton(
          label: 'Add schedule',
          height: 44,
          busy: _busy,
          onPressed: _route == null || _bus == null || _driver == null || _days.isEmpty ? null : _save,
        ),
      ],
    );
  }
}
