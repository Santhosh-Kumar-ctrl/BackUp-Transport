import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../design/design.dart';
import '../data/tracking_api.dart';
import '../widgets/live_map.dart';

/// Transport office: every running bus on one map, with a list to pick one to follow.
class AdminLiveMapScreen extends ConsumerStatefulWidget {
  const AdminLiveMapScreen({super.key});

  @override
  ConsumerState<AdminLiveMapScreen> createState() => _AdminLiveMapScreenState();
}

class _AdminLiveMapScreenState extends ConsumerState<AdminLiveMapScreen> {
  int? _focus;
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    // "Last seen" ages move on even when no fix arrives.
    _clock = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(allLiveTripsProvider);
    return ColoredBox(
      color: TransitColors.enamel,
      child: AsyncBody(
        value: live,
        onRetry: () => ref.invalidate(allLiveTripsProvider),
        builder: (trips) {
          final header = SignHeader(
            title: 'Live map',
            subtitle: switch (trips.length) {
              0 => 'No buses running',
              1 => '1 bus running',
              final n => '$n buses running',
            },
          );
          if (trips.isEmpty) {
            return ListView(
              children: [
                header,
                const SignNotice(
                  title: 'No buses are running right now',
                  body: 'Buses appear here as soon as a driver starts a trip and their phone shares its location.',
                ),
              ],
            );
          }
          final focus = trips.any((t) => t.tripId == _focus) ? _focus : null;
          final shown = focus == null ? trips : trips.where((t) => t.tripId == focus).toList();
          final list = _BusList(
            trips: trips,
            focus: focus,
            onTap: (id) => setState(() => _focus = id == _focus ? null : id),
          );
          return LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 900;
              final map = Padding(
                padding: const EdgeInsets.all(Space.gutter),
                child: LiveMap(
                  key: ValueKey(focus), // refit the camera when the selection changes
                  trips: shown,
                  followTripId: focus,
                  height: wide ? c.maxHeight - 120 : 380,
                ),
              );
              if (wide) {
                return Column(
                  children: [
                    header,
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: map),
                          SizedBox(width: 340, child: SingleChildScrollView(child: list)),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return ListView(children: [header, map, list]);
            },
          );
        },
      ),
    );
  }
}

class _BusList extends StatelessWidget {
  const _BusList({required this.trips, required this.focus, required this.onTap});

  final List<LiveTrip> trips;
  final int? focus;
  final void Function(int tripId) onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.gutter, Space.gutter, Space.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          focus == null ? 'Tap a bus to follow it' : 'Following one bus. Tap it again to see all.',
          style: TransitType.small.copyWith(color: TransitColors.inkSoft),
        ),
        const SizedBox(height: Space.s),
        for (final t in trips) _BusRow(trip: t, selected: t.tripId == focus, onTap: () => onTap(t.tripId)),
      ],
    ),
  );
}

class _BusRow extends StatelessWidget {
  const _BusRow({required this.trip, required this.selected, required this.onTap});

  final LiveTrip trip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final next = t.stops.where((s) => s.sequence == t.nextStopSequence).firstOrNull;
    final fix = t.position;
    final (seen, tone) = switch (fix) {
      null => ('No location yet', Tone.neutral),
      _ when DateTime.now().difference(fix.recordedAt) > staleAfter => (
        'Last seen ${relative(fix.recordedAt)}',
        Tone.caution,
      ),
      _ => ('Live', Tone.go),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Material(
        color: TransitColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.signAll,
          side: BorderSide(color: selected ? t.route.color : TransitColors.white, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.signAll,
          child: Padding(
            padding: const EdgeInsets.all(Space.m),
            child: Row(
              children: [
                RouteBadge(code: t.route.code, color: t.route.color, size: 40),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NumberPlate(t.busRegistration, dense: true),
                      const SizedBox(height: Space.xs),
                      Text(
                        [
                          if (next != null) 'Next: ${next.name}' else 'At the last stop',
                          if (t.delayMin >= 1) delayLabel(t.delayMin),
                        ].join(' · '),
                        style: TransitType.small,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusPlate(seen, tone: tone),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
