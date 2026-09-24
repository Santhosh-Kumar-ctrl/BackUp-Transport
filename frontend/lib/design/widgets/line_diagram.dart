import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../tokens.dart';

/// One stop on a [LineDiagram].
class LineStop {
  const LineStop({
    required this.name,
    this.note,
    this.scheduled,
    this.expected,
    this.arrived,
    this.isYou = false,
    this.isTerminus = false,
  });

  final String name;
  final String? note;
  final DateTime? scheduled;
  final DateTime? expected;
  final DateTime? arrived;
  final bool isYou;
  final bool isTerminus;

  bool get reached => arrived != null;
}

/// The vertical line map: a thick bar in the route's colour with a node per stop.
///
/// * stops already passed turn grey (like a metro "next station" strip)
/// * the bus sits on the segment after the last reached stop
/// * the rider's own stop is a large roundel marked "You"
/// * the campus terminus is a square end cap
class LineDiagram extends StatelessWidget {
  const LineDiagram({
    super.key,
    required this.stops,
    required this.color,
    this.showBus = false,
    this.onDark = false,
    this.trailingFor,
  });

  final List<LineStop> stops;
  final Color color;

  /// Draw the bus marker (trip in progress).
  final bool showBus;
  final bool onDark;

  /// Optional per-stop trailing widget (e.g. the driver's ARRIVED button).
  final Widget? Function(int index, LineStop stop)? trailingFor;

  int get _lastReached => stops.lastIndexWhere((s) => s.reached);

  @override
  Widget build(BuildContext context) {
    final last = _lastReached;
    return Column(
      children: [
        for (var i = 0; i < stops.length; i++)
          _StopRow(
            stop: stops[i],
            index: i,
            count: stops.length,
            color: color,
            passedAbove: i <= last,
            passedBelow: i < last,
            busBelow: showBus && i == last && i < stops.length - 1,
            isNext: showBus && i == last + 1,
            onDark: onDark,
            trailing: trailingFor?.call(i, stops[i]),
          ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.index,
    required this.count,
    required this.color,
    required this.passedAbove,
    required this.passedBelow,
    required this.busBelow,
    required this.isNext,
    required this.onDark,
    this.trailing,
  });

  final LineStop stop;
  final int index;
  final int count;
  final Color color;
  final bool passedAbove;
  final bool passedBelow;
  final bool busBelow;
  final bool isNext;
  final bool onDark;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ink = onDark ? TransitColors.white : TransitColors.ink;
    final soft = onDark ? TransitColors.white.withValues(alpha: 0.55) : TransitColors.inkSoft;
    final nameStyle = (stop.isYou || isNext ? TransitType.heading : TransitType.subheading).copyWith(
      color: stop.reached ? soft : ink,
    );

    return Semantics(
      label: [stop.name, if (stop.isYou) 'your stop', if (stop.reached) 'reached', if (isNext) 'next stop'].join(', '),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 56,
              child: CustomPaint(
                painter: _SegmentPainter(
                  color: color,
                  first: index == 0,
                  last: index == count - 1,
                  passedAbove: passedAbove,
                  passedBelow: passedBelow,
                  node: stop.isYou
                      ? _Node.you
                      : stop.isTerminus
                      ? _Node.terminus
                      : _Node.stop,
                  reached: stop.reached,
                  busBelow: busBelow,
                  boardColor: onDark ? TransitColors.board : TransitColors.enamel,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 14, bottom: busBelow ? 34 : 14, right: Space.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(stop.name, style: nameStyle)),
                        if (stop.isYou) ...[
                          const SizedBox(width: Space.s),
                          _Tag('You', bg: color, fg: TransitColors.onRoute(color)),
                        ],
                        if (isNext) ...[
                          const SizedBox(width: Space.s),
                          _Tag(
                            'Next',
                            bg: onDark ? TransitColors.led : TransitColors.ink,
                            fg: onDark ? TransitColors.board : TransitColors.white,
                          ),
                        ],
                      ],
                    ),
                    if (stop.note != null) Text(stop.note!, style: TransitType.small.copyWith(color: soft)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 14, bottom: busBelow ? 34 : 14),
              child: Align(
                alignment: Alignment.centerRight,
                child: trailing ?? _Times(stop: stop, onDark: onDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Times extends StatelessWidget {
  const _Times({required this.stop, required this.onDark});

  final LineStop stop;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final soft = onDark ? TransitColors.white.withValues(alpha: 0.55) : TransitColors.inkSoft;
    final ink = onDark ? TransitColors.white : TransitColors.ink;
    if (stop.arrived != null) {
      return Text(hm(stop.arrived!), style: TransitType.figure.copyWith(color: soft, fontSize: 16));
    }
    if (stop.scheduled == null) return const SizedBox.shrink();
    final late = stop.expected != null && stop.expected!.difference(stop.scheduled!).inMinutes >= 1;
    if (!late) return Text(hm(stop.scheduled!), style: TransitType.figure.copyWith(color: ink, fontSize: 16));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          hm(stop.expected!),
          style: TransitType.figure.copyWith(color: onDark ? TransitColors.led : TransitColors.late, fontSize: 16),
        ),
        Text(
          hm(stop.scheduled!),
          style: TransitType.small.copyWith(color: soft, decoration: TextDecoration.lineThrough, decorationColor: soft),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: bg, borderRadius: Radii.signAll),
    child: Text(
      text,
      style: TransitType.small.copyWith(color: fg, fontWeight: FontWeight.w800),
    ),
  );
}

enum _Node { stop, you, terminus }

class _SegmentPainter extends CustomPainter {
  _SegmentPainter({
    required this.color,
    required this.first,
    required this.last,
    required this.passedAbove,
    required this.passedBelow,
    required this.node,
    required this.reached,
    required this.busBelow,
    required this.boardColor,
  });

  final Color color;
  final bool first;
  final bool last;
  final bool passedAbove;
  final bool passedBelow;
  final _Node node;
  final bool reached;
  final bool busBelow;
  final Color boardColor;

  static const barWidth = 10.0;
  static const passedGrey = Color(0xFFB3BDC6);

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    // The node sits level with the stop name (top padding 14 + half a line).
    final nodeY = 14.0 + 13.0;
    final bar = Paint()..strokeWidth = barWidth;

    if (!first) {
      bar.color = passedAbove ? passedGrey : color;
      canvas.drawLine(Offset(x, 0), Offset(x, nodeY), bar);
    }
    if (!last) {
      bar.color = passedBelow ? passedGrey : color;
      canvas.drawLine(Offset(x, nodeY), Offset(x, size.height), bar);
    }

    final ring = reached ? passedGrey : color;
    switch (node) {
      case _Node.stop:
        canvas.drawCircle(Offset(x, nodeY), 9, Paint()..color = boardColor);
        canvas.drawCircle(
          Offset(x, nodeY),
          9,
          Paint()
            ..color = ring
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
      case _Node.you:
        canvas.drawCircle(Offset(x, nodeY), 15, Paint()..color = ring);
        canvas.drawCircle(Offset(x, nodeY), 7, Paint()..color = boardColor);
      case _Node.terminus:
        final r = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, nodeY), width: 26, height: 26),
          const Radius.circular(3),
        );
        canvas.drawRRect(r, Paint()..color = ring);
        canvas.drawRRect(r.deflate(6), Paint()..color = boardColor);
    }

    // Bus sits halfway between this stop's node and the next row.
    if (busBelow) _paintBus(canvas, Offset(x, nodeY + (size.height - nodeY) / 2 + 6));
  }

  /// A simple front-on bus glyph sitting on the bar.
  void _paintBus(Canvas canvas, Offset c) {
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 30, height: 26), const Radius.circular(5));
    canvas.drawRRect(body.inflate(2.5), Paint()..color = boardColor);
    canvas.drawRRect(body, Paint()..color = TransitColors.ink);
    final glass = Rect.fromLTWH(c.dx - 11, c.dy - 9, 22, 9);
    canvas.drawRRect(RRect.fromRectAndRadius(glass, const Radius.circular(2)), Paint()..color = TransitColors.led);
    final light = Paint()..color = TransitColors.white;
    canvas.drawCircle(Offset(c.dx - 8, c.dy + 6), 2.2, light);
    canvas.drawCircle(Offset(c.dx + 8, c.dy + 6), 2.2, light);
  }

  @override
  bool shouldRepaint(covariant _SegmentPainter old) =>
      old.color != color ||
      old.passedAbove != passedAbove ||
      old.passedBelow != passedBelow ||
      old.node != node ||
      old.reached != reached ||
      old.busBelow != busBelow ||
      old.boardColor != boardColor;
}
