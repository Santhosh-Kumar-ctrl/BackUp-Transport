import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/session.dart';
import '../../../core/format.dart';
import '../../../core/realtime/realtime.dart';
import '../../../design/design.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../data/trip_models.dart';
import '../data/trips_api.dart';

/// Driver's day: each run as a large block with one obvious action.
class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(driverDashboardProvider);
    final user = ref.watch(sessionProvider)?.user;
    listenLive(
      ref,
      (_) => ref.invalidate(driverDashboardProvider),
      events: {'TripsGenerated', 'TripCancelled', 'StudentBoarded', 'TripDelayed', 'BusRunsReassigned', 'notification'},
    );

    return Column(
      children: [
        SignHeader(
          color: TransitColors.board,
          title: 'Today, ${user?.firstName ?? ''}',
          subtitle: dayLabel(DateTime.now()),
          trailing: IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout, color: TransitColors.white),
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
          ),
        ),
        Expanded(
          child: AsyncBody(
            value: dash,
            onDark: true,
            onRetry: () => ref.invalidate(driverDashboardProvider),
            builder: (d) => d.trips.isEmpty
                ? const SignNotice(
                    title: 'No runs today',
                    body: 'You have no trips scheduled today. The transport office assigns runs.',
                  )
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(driverDashboardProvider),
                    child: ListView(
                      padding: const EdgeInsets.all(Space.gutter),
                      children: [for (final t in d.trips) _RunBlock(run: t)],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _RunBlock extends ConsumerStatefulWidget {
  const _RunBlock({required this.run});

  final DriverTrip run;

  @override
  ConsumerState<_RunBlock> createState() => _RunBlockState();
}

class _RunBlockState extends ConsumerState<_RunBlock> {
  var _busy = false;

  Future<void> _start() async {
    final trip = widget.run.trip;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Start route ${trip.route.code}?', style: TransitType.heading),
        content: Text(
          'Students on this route are told the bus has left ${trip.stops.first.stopName}.',
          style: TransitType.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not yet')),
          SignButton(label: 'Start trip', kind: SignButtonKind.go, height: 44, onPressed: () => Navigator.pop(c, true)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(tripActionsProvider).start(trip.id);
      ref.invalidate(driverDashboardProvider);
      if (mounted) context.push('/driver/trip/${trip.id}');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.run;
    final t = r.trip;
    final done = t.status == TripStatus.completed || t.status == TripStatus.cancelled;
    final white = TransitColors.white.withValues(alpha: done ? 0.5 : 1);
    final soft = TransitColors.white.withValues(alpha: done ? 0.4 : 0.65);
    final status = switch (t.status) {
      TripStatus.scheduled => 'Departs ${hm(t.scheduledDeparture)} from ${t.stops.first.stopName}',
      TripStatus.inProgress => 'Running, ${delayLabel(r.delayMin).toLowerCase()}',
      TripStatus.completed => 'Finished ${t.endedAt != null ? hm(t.endedAt!) : ''}, ${r.boarded} boarded',
      TripStatus.cancelled => 'Cancelled${t.cancelReason != null ? ': ${t.cancelReason}' : ''}',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: Space.m),
      decoration: BoxDecoration(
        border: Border.all(color: t.running ? TransitColors.led : TransitColors.boardLine, width: t.running ? 2 : 1),
        borderRadius: Radii.signAll,
      ),
      padding: const EdgeInsets.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Opacity(
                opacity: done ? 0.5 : 1,
                child: RouteBadge(code: t.route.code, color: t.route.color, size: 52, rim: true),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.isPickup ? 'Morning pickup' : 'Evening drop',
                      style: TransitType.heading.copyWith(color: white),
                    ),
                    Text(t.headline, style: TransitType.body.copyWith(color: soft)),
                  ],
                ),
              ),
              Text(hm(t.scheduledDeparture), style: TransitType.display.copyWith(color: white, fontSize: 34)),
            ],
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              NumberPlate(t.busRegistration, dense: true),
              const SizedBox(width: Space.m),
              Expanded(
                child: Text(status, style: TransitType.body.copyWith(color: soft)),
              ),
            ],
          ),
          if (!done) ...[
            const SizedBox(height: Space.l),
            if (t.status == TripStatus.scheduled)
              SignButton(
                label: 'Start trip',
                kind: SignButtonKind.go,
                expand: true,
                height: 60,
                busy: _busy,
                onPressed: _start,
              )
            else
              SignButton(
                label: 'Continue trip',
                kind: SignButtonKind.primary,
                expand: true,
                height: 60,
                onPressed: () => context.push('/driver/trip/${t.id}'),
              ),
          ],
        ],
      ),
    );
  }
}
