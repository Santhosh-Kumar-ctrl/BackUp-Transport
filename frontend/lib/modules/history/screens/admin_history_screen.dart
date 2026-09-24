import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../design/design.dart';
import '../data/history_api.dart';

/// Operational history: per-trip reports and attendance, one day at a time.
class AdminHistoryScreen extends ConsumerStatefulWidget {
  const AdminHistoryScreen({super.key});

  @override
  ConsumerState<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends ConsumerState<AdminHistoryScreen> {
  var _day = DateUtils.dateOnly(DateTime.now());
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_day, DateTime.now());
    return Column(
      children: [
        SignHeader(
          title: 'Reports',
          subtitle: 'Trips and attendance by day',
          bottom: Row(
            children: [
              IconButton(
                tooltip: 'Previous day',
                icon: const Icon(Icons.chevron_left, color: TransitColors.white),
                onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 1))),
              ),
              Text(
                isToday ? 'Today, ${dayLabel(_day)}' : dayLabel(_day),
                style: TransitType.heading.copyWith(color: TransitColors.white),
              ),
              IconButton(
                tooltip: 'Next day',
                icon: Icon(Icons.chevron_right, color: TransitColors.white.withValues(alpha: isToday ? 0.3 : 1)),
                onPressed: isToday ? null : () => setState(() => _day = _day.add(const Duration(days: 1))),
              ),
              const Spacer(),
              _Tab('Trips', _tab == 0, () => setState(() => _tab = 0)),
              const SizedBox(width: Space.s),
              _Tab('Attendance', _tab == 1, () => setState(() => _tab = 1)),
            ],
          ),
        ),
        Expanded(
          child: _tab == 0 ? _Trips(day: _day) : _Attendance(day: _day),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(this.label, this.selected, this.onTap);

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? TransitColors.white : Colors.transparent,
        borderRadius: Radii.signAll,
        border: Border.all(color: TransitColors.white, width: 1.5),
      ),
      child: Text(
        label,
        style: TransitType.subheading.copyWith(
          color: selected ? TransitColors.signBlue : TransitColors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _Trips extends ConsumerWidget {
  const _Trips({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(tripReportsProvider(day));
    return AsyncBody(
      value: reports,
      onRetry: () => ref.invalidate(tripReportsProvider(day)),
      builder: (list) => list.isEmpty
          ? const SignNotice(title: 'No trips this day', body: 'Pick another day, or check the schedules.')
          : ListView.separated(
              padding: const EdgeInsets.all(Space.gutter),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (_, i) {
                final t = list[i];
                final (label, tone) = switch (t.status) {
                  'completed' => (
                    t.maxDelay >= 5 ? 'Late ${t.maxDelay} min' : 'On time',
                    t.maxDelay >= 5 ? Tone.late : Tone.go,
                  ),
                  'cancelled' => ('Cancelled', Tone.late),
                  'in_progress' => ('Running', Tone.info),
                  _ => ('Scheduled', Tone.neutral),
                };
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.m),
                  child: Row(
                    children: [
                      RouteBadge(code: t.routeCode, color: TransitColors.parseHex(t.routeColor), size: 40),
                      const SizedBox(width: Space.m),
                      SizedBox(width: 64, child: Text(hm(t.scheduledDeparture), style: TransitType.figure)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${t.direction == 'pickup' ? 'Pickup' : 'Drop'}, ${t.driverName}',
                              style: TransitType.subheading.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${t.boarded} boarded, ${t.present} present, ${t.absent} missed'
                              '${t.alerts > 0 ? ', ${t.alerts} delay alert${t.alerts == 1 ? '' : 's'}' : ''}',
                              style: TransitType.small.copyWith(color: TransitColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      NumberPlate(t.registration, dense: true),
                      const SizedBox(width: Space.m),
                      StatusPlate(label, tone: tone),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _Attendance extends ConsumerWidget {
  const _Attendance({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(attendanceProvider(day));
    return AsyncBody(
      value: rows,
      onRetry: () => ref.invalidate(attendanceProvider(day)),
      builder: (list) {
        if (list.isEmpty) {
          return const SignNotice(title: 'No attendance this day', body: 'Attendance is recorded when each trip ends.');
        }
        final missed = list.where((r) => r.status == 'absent').length;
        return ListView(
          padding: const EdgeInsets.all(Space.gutter),
          children: [
            Text('${list.length - missed} rode, $missed missed', style: TransitType.heading),
            const SizedBox(height: Space.xs),
            Text(
              'CSV export: GET /history/attendance?format=csv',
              style: TransitType.small.copyWith(color: TransitColors.inkSoft),
            ),
            const SizedBox(height: Space.m),
            for (final r in list) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s),
                child: Row(
                  children: [
                    SizedBox(width: 44, child: Text(r.routeCode, style: TransitType.figure)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.studentName, style: TransitType.subheading.copyWith(fontWeight: FontWeight.w800)),
                          Text(
                            [
                              r.rollNo ?? '',
                              r.direction == 'pickup' ? 'pickup' : 'drop',
                              if (r.boardedAt != null) 'boarded ${hm(r.boardedAt!)}',
                            ].where((x) => x.isNotEmpty).join(', '),
                            style: TransitType.small.copyWith(color: TransitColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    StatusPlate(
                      switch (r.status) {
                        'present' => 'Rode',
                        'present_unallocated' => 'Rode, not allocated',
                        _ => 'Missed',
                      },
                      tone: switch (r.status) {
                        'present' => Tone.go,
                        'present_unallocated' => Tone.caution,
                        _ => Tone.late,
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
            ],
          ],
        );
      },
    );
  }
}
