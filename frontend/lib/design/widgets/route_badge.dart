import 'package:flutter/material.dart';

import '../tokens.dart';

/// The square route tile you see on a bus stop pole: line colour + route code.
class RouteBadge extends StatelessWidget {
  const RouteBadge({super.key, required this.code, required this.color, this.size = 44, this.rim = false});

  final String code;
  final Color color;
  final double size;

  /// White rim, like the border on a pole-mounted tile. Use on dark panels so a
  /// dark line colour doesn't sink into the background.
  final bool rim;

  @override
  Widget build(BuildContext context) {
    final fg = TransitColors.onRoute(color);
    return Semantics(
      label: 'Route $code',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: Radii.signAll,
          border: rim ? Border.all(color: TransitColors.white, width: size * 0.06) : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.all(size * 0.1),
            child: Text(
              code,
              style: TransitType.figure.copyWith(color: fg, fontSize: size * 0.48, height: 1.05),
            ),
          ),
        ),
      ),
    );
  }
}
