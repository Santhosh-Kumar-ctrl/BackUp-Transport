import 'package:flutter/material.dart';

import '../tokens.dart';

enum SignButtonKind { primary, go, danger, quiet, onDark }

/// Large, flat, square-ish action. Keyboard focus draws an LED-amber rim.
class SignButton extends StatelessWidget {
  const SignButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = SignButtonKind.primary,
    this.icon,
    this.expand = false,
    this.height = 52,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final SignButtonKind kind;
  final IconData? icon;
  final bool expand;
  final double height;
  final bool busy;

  (Color, Color, BorderSide) get _palette => switch (kind) {
    SignButtonKind.primary => (TransitColors.signBlue, TransitColors.white, BorderSide.none),
    SignButtonKind.go => (TransitColors.go, TransitColors.white, BorderSide.none),
    SignButtonKind.danger => (TransitColors.late, TransitColors.white, BorderSide.none),
    SignButtonKind.quiet => (
      TransitColors.white,
      TransitColors.ink,
      const BorderSide(color: TransitColors.ink, width: 1.5),
    ),
    SignButtonKind.onDark => (
      TransitColors.board,
      TransitColors.white,
      const BorderSide(color: TransitColors.white, width: 1.5),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, side) = _palette;
    final child = busy
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 10)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );
    final button = TextButton(
      onPressed: busy ? null : onPressed,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(64, height)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20)),
        textStyle: const WidgetStatePropertyAll(TransitType.button),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: Radii.signAll)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) && !busy ? TransitColors.enamelDeep : bg,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) && !busy ? TransitColors.inkSoft : fg,
        ),
        overlayColor: WidgetStatePropertyAll(fg.withValues(alpha: 0.08)),
        side: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.focused) ? const BorderSide(color: TransitColors.led, width: 3) : side,
        ),
      ),
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
