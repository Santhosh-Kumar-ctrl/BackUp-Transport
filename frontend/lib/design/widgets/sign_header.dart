import 'package:flutter/material.dart';

import '../tokens.dart';

/// Sign-blue panel with white type — the top of most screens, like a station sign.
class SignHeader extends StatelessWidget {
  const SignHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.color = TransitColors.signBlue,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Color color;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, Space.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: Space.m)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TransitType.title.copyWith(color: TransitColors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              style: TransitType.body.copyWith(color: TransitColors.white.withValues(alpha: 0.78)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              if (bottom != null) ...[const SizedBox(height: Space.l), bottom!],
            ],
          ),
        ),
      ),
    );
  }
}
