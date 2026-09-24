import 'package:flutter/material.dart';

import '../tokens.dart';
import 'sign_button.dart';

/// Empty / error / info states: a plate with a coloured edge, plain words, and one action.
class SignNotice extends StatelessWidget {
  const SignNotice({
    super.key,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.edge = TransitColors.signBlue,
  });

  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color edge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(Space.gutter),
      decoration: BoxDecoration(
        color: TransitColors.white,
        borderRadius: Radii.signAll,
        border: Border(left: BorderSide(color: edge, width: 6)),
      ),
      padding: const EdgeInsets.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TransitType.heading),
          if (body != null) ...[
            const SizedBox(height: Space.xs),
            Text(body!, style: TransitType.body.copyWith(color: TransitColors.inkSoft)),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: Space.l),
            SignButton(label: actionLabel!, onPressed: onAction, kind: SignButtonKind.quiet, height: 44),
          ],
        ],
      ),
    );
  }
}
