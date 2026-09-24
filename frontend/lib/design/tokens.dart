import 'package:flutter/widgets.dart';

/// Colour tokens. See design/README.md for the rules — status colours carry
/// meaning only; route colours are identity only; LED amber is for live times.
abstract final class TransitColors {
  /// Page background: the cool grey-white of an enamel sign plate.
  static const enamel = Color(0xFFEEF1F3);

  /// A slightly deeper enamel for grouped surfaces and table stripes.
  static const enamelDeep = Color(0xFFE1E6EA);

  /// Structural panels: station / road sign blue, always with white type.
  static const signBlue = Color(0xFF123E63);
  static const signBlueDeep = Color(0xFF0C2C47);

  /// Departure-board panel (admin board, driver screens).
  static const board = Color(0xFF17212B);
  static const boardLine = Color(0xFF2A3743);

  /// Live figures on the board (expected times, delays). Nothing else.
  static const led = Color(0xFFFFB81C);

  /// Text.
  static const ink = Color(0xFF1B2733);
  static const inkSoft = Color(0xFF52606D);
  static const rule = Color(0xFFC5CDD4);
  static const white = Color(0xFFFFFFFF);

  /// Status — meaning only.
  static const late = Color(0xFFD7261E); // delay, over capacity, cancelled
  static const go = Color(0xFF1C8A4B); // on time, boarded, arrived
  static const caution = Color(0xFFF2A900); // nearly full, warning plates (with ink text)

  static Color parseHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  /// Readable text colour to put on top of a route colour.
  static Color onRoute(Color route) => route.computeLuminance() > 0.45 ? ink : white;
}

abstract final class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const gutter = 16.0; // phone side margin
}

abstract final class Radii {
  /// Enamel signs have gently rounded corners — not pills, not razor-sharp.
  static const sign = Radius.circular(4);
  static const signAll = BorderRadius.all(sign);
}

/// Type scale (Overpass — derived from Highway Gothic, the road-sign face).
/// Ratio ≈ 1.25, tabular figures everywhere numbers line up.
abstract final class TransitType {
  static const family = 'Overpass';
  static const _tab = [FontFeature.tabularFigures()];

  static const display = TextStyle(
    fontFamily: family,
    fontSize: 44,
    height: 1.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    fontFeatures: _tab,
  );
  static const title = TextStyle(
    fontFamily: family,
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  );
  static const heading = TextStyle(fontFamily: family, fontSize: 20, height: 1.2, fontWeight: FontWeight.w800);
  static const subheading = TextStyle(fontFamily: family, fontSize: 16, height: 1.3, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontFamily: family, fontSize: 15, height: 1.45, fontWeight: FontWeight.w400);
  static const small = TextStyle(fontFamily: family, fontSize: 13, height: 1.35, fontWeight: FontWeight.w400);
  static const figure = TextStyle(
    fontFamily: family,
    fontSize: 18,
    height: 1.0,
    fontWeight: FontWeight.w800,
    fontFeatures: _tab,
  );
  static const button = TextStyle(fontFamily: family, fontSize: 17, height: 1.0, fontWeight: FontWeight.w800);
}
