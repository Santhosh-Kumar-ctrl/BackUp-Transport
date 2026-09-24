import 'package:flutter/material.dart';

import '../tokens.dart';

/// Occupancy drawn as a top-down bus seat plan: rows of 2 + aisle + 2, front to back
/// (left to right). Taken seats fill in; riders beyond capacity add red seats at the back.
class SeatBlocks extends StatelessWidget {
  const SeatBlocks({super.key, required this.taken, required this.capacity, this.onDark = false, this.cell = 6});

  final int taken;
  final int capacity;
  final bool onDark;
  final double cell;

  Color get _fill {
    if (taken > capacity) return TransitColors.late;
    if (taken * 100 >= capacity * 90) return TransitColors.caution;
    return onDark ? TransitColors.white : TransitColors.go;
  }

  @override
  Widget build(BuildContext context) {
    final seats = capacity + (taken > capacity ? taken - capacity : 0);
    final columns = (seats / 4).ceil();
    const gap = 1.5;
    final aisle = cell * 0.8;
    return Semantics(
      label: '$taken of $capacity seats taken',
      child: CustomPaint(
        size: Size(columns * (cell + gap), 4 * (cell + gap) + aisle),
        painter: _SeatPlanPainter(
          seats: seats,
          taken: taken,
          capacity: capacity,
          cell: cell,
          gap: gap,
          aisle: aisle,
          fill: _fill,
          empty: onDark ? TransitColors.boardLine : TransitColors.rule,
        ),
      ),
    );
  }
}

class _SeatPlanPainter extends CustomPainter {
  _SeatPlanPainter({
    required this.seats,
    required this.taken,
    required this.capacity,
    required this.cell,
    required this.gap,
    required this.aisle,
    required this.fill,
    required this.empty,
  });

  final int seats;
  final int taken;
  final int capacity;
  final double cell;
  final double gap;
  final double aisle;
  final Color fill;
  final Color empty;

  @override
  void paint(Canvas canvas, Size size) {
    final filled = Paint()..color = fill;
    final over = Paint()..color = TransitColors.late;
    final outline = Paint()
      ..color = empty
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 0; i < seats; i++) {
      final col = i ~/ 4;
      final row = i % 4;
      final y = row * (cell + gap) + (row >= 2 ? aisle : 0);
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(col * (cell + gap), y, cell, cell), const Radius.circular(1.5));
      if (i < taken) {
        canvas.drawRRect(r, i >= capacity ? over : filled);
      } else {
        canvas.drawRRect(r.deflate(0.55), outline);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SeatPlanPainter old) =>
      old.taken != taken || old.seats != seats || old.fill != fill || old.empty != empty;
}
