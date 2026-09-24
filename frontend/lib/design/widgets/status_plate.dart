import 'package:flutter/material.dart';

import '../tokens.dart';

enum Tone { late, go, caution, neutral, info }

/// A small enamel status plate. Colour always means something (see tokens).
class StatusPlate extends StatelessWidget {
  const StatusPlate(this.text, {super.key, required this.tone, this.large = false});

  final String text;
  final Tone tone;
  final bool large;

  (Color, Color) get _colors => switch (tone) {
    Tone.late => (TransitColors.late, TransitColors.white),
    Tone.go => (TransitColors.go, TransitColors.white),
    Tone.caution => (TransitColors.caution, TransitColors.ink),
    Tone.info => (TransitColors.signBlue, TransitColors.white),
    Tone.neutral => (TransitColors.enamelDeep, TransitColors.ink),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8, vertical: large ? 6 : 3),
      decoration: BoxDecoration(color: bg, borderRadius: Radii.signAll),
      child: Text(
        text,
        style: (large ? TransitType.subheading : TransitType.small).copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}
