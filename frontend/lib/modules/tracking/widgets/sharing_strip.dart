import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../design/design.dart';
import '../state/position_reporter.dart';

/// Driver's run screen: is the phone sharing the bus's location, and what to do if not.
class LocationSharingStrip extends ConsumerWidget {
  const LocationSharingStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(positionReporterProvider);
    final (plate, tone, text, action) = switch (s.status) {
      ReporterStatus.off || ReporterStatus.starting => ('Location', Tone.neutral, 'Starting GPS…', null),
      ReporterStatus.sharing => (
        'Sharing',
        Tone.go,
        s.lastSentAt == null
            ? 'Waiting for the first GPS fix'
            : 'Riders see the bus. Stops check in automatically. Sent ${relative(s.lastSentAt!)}.',
        null,
      ),
      ReporterStatus.offline => (
        'No signal',
        Tone.caution,
        '${s.pending} positions saved. They send when the network returns.',
        null,
      ),
      ReporterStatus.denied => (
        'Blocked',
        Tone.late,
        "Riders can't see the bus. Allow location for this app.",
        'Allow location',
      ),
      ReporterStatus.unavailable => (
        'No GPS',
        Tone.caution,
        "This device can't share the bus location. Tap Arrived at each stop.",
        null,
      ),
      ReporterStatus.serviceOff => (
        'Location off',
        Tone.late,
        "Riders can't see the bus. Turn on the phone's location.",
        'Turn on',
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.s),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: TransitColors.boardLine)),
        ),
        child: Row(
          children: [
            StatusPlate(plate, tone: tone),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(text, style: TransitType.small.copyWith(color: TransitColors.white.withValues(alpha: 0.8))),
            ),
            if (action != null)
              SignButton(
                label: action,
                kind: SignButtonKind.onDark,
                height: 40,
                onPressed: () => ref.read(positionReporterProvider.notifier).fixSettings(),
              ),
          ],
        ),
      ),
    );
  }
}
