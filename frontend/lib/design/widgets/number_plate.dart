import 'package:flutter/material.dart';

import '../tokens.dart';

/// A bus registration drawn as the number plate it is: white plate, dark rim.
class NumberPlate extends StatelessWidget {
  const NumberPlate(this.registration, {super.key, this.dense = false});

  final String registration;
  final bool dense;

  static final _indian = RegExp(r'^([A-Z]{2})(\d{1,2})([A-Z]{0,3})(\d{1,4})$');

  static String format(String reg) {
    final m = _indian.firstMatch(reg.replaceAll(' ', '').toUpperCase());
    if (m == null) return reg;
    return [m[1], m[2], m[3], m[4]].where((p) => p != null && p.isNotEmpty).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 2 : 3),
      decoration: BoxDecoration(
        color: TransitColors.white,
        border: Border.all(color: TransitColors.ink, width: dense ? 1.2 : 1.6),
        borderRadius: const BorderRadius.all(Radius.circular(3)),
      ),
      child: Text(
        format(registration),
        style: TransitType.small.copyWith(
          color: TransitColors.ink,
          fontWeight: FontWeight.w800,
          fontSize: dense ? 11.5 : 13,
          letterSpacing: 0.6,
          height: 1.2,
        ),
      ),
    );
  }
}
