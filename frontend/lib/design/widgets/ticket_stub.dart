import 'package:flutter/material.dart';

import '../tokens.dart';
import 'number_plate.dart';
import 'route_badge.dart';

/// The boarding receipt, styled as a punched bus ticket. The "Boarded" stamp lands
/// once — the app's single orchestrated motion. Reduced-motion users see it in place.
class TicketStub extends StatefulWidget {
  const TicketStub({
    super.key,
    required this.routeCode,
    required this.routeColor,
    required this.routeName,
    required this.registration,
    required this.time,
    required this.message,
    this.stopName,
    this.onRoute = true,
  });

  final String routeCode;
  final Color routeColor;
  final String routeName;
  final String registration;
  final String time;
  final String message;
  final String? stopName;
  final bool onRoute;

  @override
  State<TicketStub> createState() => _TicketStubState();
}

class _TicketStubState extends State<TicketStub> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stampColor = widget.onRoute ? TransitColors.go : TransitColors.caution;
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(color: TransitColors.white, borderRadius: Radii.signAll),
      child: Stack(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 14,
                  decoration: BoxDecoration(
                    color: widget.routeColor,
                    borderRadius: const BorderRadius.horizontal(left: Radii.sign),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            RouteBadge(code: widget.routeCode, color: widget.routeColor, size: 48),
                            const SizedBox(width: Space.m),
                            Expanded(child: Text(widget.routeName, style: TransitType.heading)),
                          ],
                        ),
                        const SizedBox(height: Space.l),
                        _Line('Bus', child: NumberPlate(widget.registration)),
                        _Line('Boarded at', text: widget.time),
                        if (widget.stopName != null) _Line('Your stop', text: widget.stopName!),
                        const SizedBox(height: Space.m),
                        const _Perforation(),
                        const SizedBox(height: Space.m),
                        Text(widget.message, style: TransitType.body),
                        const SizedBox(height: 64), // blank corner for the stamp
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: FadeTransition(
              opacity: _c,
              child: ScaleTransition(
                scale: Tween(begin: 1.8, end: 1.0).animate(curve),
                child: Transform.rotate(
                  angle: -0.16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: stampColor, width: 3),
                      borderRadius: Radii.signAll,
                    ),
                    child: Text(
                      widget.onRoute ? 'Boarded' : 'Boarded, check',
                      style: TransitType.heading.copyWith(color: stampColor),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, {this.text, this.child});

  final String label;
  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.s),
    child: Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: TransitType.small.copyWith(color: TransitColors.inkSoft)),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: child ?? Text(text ?? '', style: TransitType.subheading),
          ),
        ),
      ],
    ),
  );
}

class _Perforation extends StatelessWidget {
  const _Perforation();

  // Painted (not LayoutBuilder) so the ticket can size itself with IntrinsicHeight.
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 2,
    width: double.infinity,
    child: CustomPaint(painter: _DashPainter()),
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = TransitColors.rule;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 5, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
