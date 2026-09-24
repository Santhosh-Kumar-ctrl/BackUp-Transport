import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../core/realtime/realtime.dart';
import '../../../design/design.dart';
import '../data/boarding_api.dart';

/// Who should be on this bus, in stop order, and who is. Manual boarding for students without a phone.
class DriverRosterScreen extends ConsumerWidget {
  const DriverRosterScreen({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(rosterProvider(tripId));
    listenLive(ref, (m) {
      if (m.data['trip_id'] == tripId) ref.invalidate(rosterProvider(tripId));
    }, events: {'boarding'});

    return Scaffold(
      backgroundColor: TransitColors.enamel,
      body: Column(
        children: [
          SignHeader(
            title: 'Riders',
            subtitle: roster.asData == null
                ? null
                : '${roster.asData!.value.boarded} boarded of ${roster.asData!.value.allocated} allocated, '
                      '${roster.asData!.value.capacity} seats',
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back, color: TransitColors.white),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: AsyncBody(
              value: roster,
              onRetry: () => ref.invalidate(rosterProvider(tripId)),
              builder: (r) => r.entries.isEmpty
                  ? const SignNotice(title: 'No riders allocated', body: 'No students are allocated to this route yet.')
                  : ListView.separated(
                      padding: const EdgeInsets.all(Space.gutter),
                      itemCount: r.entries.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (_, i) => _RiderRow(entry: r.entries[i], tripId: tripId),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderRow extends ConsumerStatefulWidget {
  const _RiderRow({required this.entry, required this.tripId});

  final RosterEntry entry;
  final int tripId;

  @override
  ConsumerState<_RiderRow> createState() => _RiderRowState();
}

class _RiderRowState extends ConsumerState<_RiderRow> {
  var _busy = false;

  Future<void> _board() async {
    setState(() => _busy = true);
    try {
      await ref.read(boardingActionsProvider).manual(widget.tripId, studentId: widget.entry.studentId);
      ref.invalidate(rosterProvider(widget.tripId));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: Row(
        children: [
          Icon(
            e.boarded ? Icons.check_box : Icons.check_box_outline_blank,
            color: e.boarded ? TransitColors.go : TransitColors.rule,
            size: 28,
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.fullName, style: TransitType.subheading.copyWith(fontWeight: FontWeight.w800)),
                Text(
                  [
                    e.rollNo ?? '',
                    e.stopName ?? 'Not allocated to this route',
                    if (e.boardedAt != null) 'boarded ${hm(e.boardedAt!)}${e.method == 'manual' ? ' by you' : ''}',
                  ].where((x) => x.isNotEmpty).join(', '),
                  style: TransitType.small.copyWith(color: TransitColors.inkSoft),
                ),
              ],
            ),
          ),
          if (!e.allocated) const StatusPlate('Check', tone: Tone.caution),
          if (!e.boarded)
            SignButton(label: 'Board', kind: SignButtonKind.quiet, height: 40, busy: _busy, onPressed: _board),
        ],
      ),
    );
  }
}
