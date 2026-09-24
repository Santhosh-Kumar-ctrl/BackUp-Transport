import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../tokens.dart';
import 'number_plate.dart';
import 'route_badge.dart';
import 'seat_blocks.dart';

/// One line of the departure board (dark board panel).
class DepartureRow extends StatelessWidget {
  const DepartureRow({
    super.key,
    required this.routeCode,
    required this.routeColor,
    required this.headline,
    required this.detail,
    required this.registration,
    required this.scheduled,
    required this.expected,
    required this.status,
    required this.statusColor,
    required this.taken,
    required this.capacity,
    this.dimmed = false,
    this.onTap,
  });

  final String routeCode;
  final Color routeColor;
  final String headline; // e.g. "To Main Gate (Campus)"
  final String detail; // e.g. "Next: Koyambedu Market · Murugan K"
  final String registration;
  final DateTime scheduled;
  final DateTime? expected;
  final String status;
  final Color statusColor;
  final int taken;
  final int capacity;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final white = TransitColors.white.withValues(alpha: dimmed ? 0.45 : 1);
    final soft = TransitColors.white.withValues(alpha: dimmed ? 0.35 : 0.62);
    final late = expected != null && expected!.difference(scheduled).inMinutes >= 1;

    final times = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 58,
          child: Text(
            hm(scheduled),
            textAlign: TextAlign.right,
            style: TransitType.figure.copyWith(color: late ? soft : white, fontSize: 20),
          ),
        ),
        SizedBox(
          width: 66,
          child: Text(
            late ? hm(expected!) : '',
            textAlign: TextAlign.right,
            style: TransitType.figure.copyWith(color: TransitColors.led, fontSize: 20),
          ),
        ),
      ],
    );
    final statusText = Text(
      status,
      style: TransitType.subheading.copyWith(color: statusColor, fontWeight: FontWeight.w800),
    );

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: TransitColors.boardLine)),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth > 760;
            final ident = Row(
              children: [
                Opacity(
                  opacity: dimmed ? 0.5 : 1,
                  child: RouteBadge(code: routeCode, color: routeColor, size: 40, rim: true),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: TransitType.subheading.copyWith(color: white, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: TransitType.small.copyWith(color: soft),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            );
            if (wide) {
              return Row(
                children: [
                  Expanded(flex: 5, child: ident),
                  const SizedBox(width: Space.m),
                  Opacity(opacity: dimmed ? 0.5 : 1, child: NumberPlate(registration, dense: true)),
                  const SizedBox(width: Space.l),
                  times,
                  const SizedBox(width: Space.l),
                  SizedBox(width: 170, child: statusText),
                  SizedBox(
                    width: 130,
                    child: Row(
                      children: [
                        SeatBlocks(taken: taken, capacity: capacity, onDark: true, cell: 5),
                        const SizedBox(width: Space.s),
                        Text(
                          '$taken',
                          style: TransitType.small.copyWith(color: soft, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: ident),
                    times,
                  ],
                ),
                const SizedBox(height: Space.s),
                Row(
                  children: [
                    const SizedBox(width: 52),
                    statusText,
                    const Spacer(),
                    Text('$taken/$capacity', style: TransitType.small.copyWith(color: soft)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
