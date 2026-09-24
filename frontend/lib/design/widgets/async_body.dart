import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../tokens.dart';
import 'sign_notice.dart';

/// Renders an AsyncValue with the house loading and error styles.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.builder, this.onRetry, this.onDark = false});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    // Keep showing the previous data while refreshing, so live screens don't flicker.
    final data = value.asData;
    if (data != null) return builder(data.value);
    if (value.hasError) {
      return SignNotice(
        title: "Couldn't load this",
        body: describeError(value.error!),
        actionLabel: onRetry == null ? null : 'Try again',
        onAction: onRetry,
        edge: TransitColors.late,
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: LinearProgressIndicator(
        minHeight: 3,
        color: onDark ? TransitColors.led : TransitColors.signBlue,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
