import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../dashboard/data/dashboard_api.dart';

/// Route allocation vs seats, one line per route.
class UtilizationList extends StatelessWidget {
  const UtilizationList({super.key, required this.items});

  final List<RouteUtil> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final u in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RouteBadge(code: u.route.code, color: u.route.color, size: 32),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              u.route.name,
                              style: TransitType.subheading.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            u.capacity == null ? '${u.allocated} allocated' : '${u.allocated} / ${u.capacity}',
                            style: TransitType.figure.copyWith(
                              fontSize: 15,
                              color: u.level == 'over' ? TransitColors.late : TransitColors.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (u.capacity != null)
                        SeatBlocks(taken: u.allocated, capacity: u.capacity!, cell: 5)
                      else
                        Text(
                          'No schedule yet, so seats are unknown',
                          style: TransitType.small.copyWith(color: TransitColors.inkSoft),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
