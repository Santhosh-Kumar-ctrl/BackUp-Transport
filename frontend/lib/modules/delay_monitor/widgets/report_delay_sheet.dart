import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../design/design.dart';
import '../data/delay_api.dart';

Future<void> showReportDelaySheet(BuildContext context, {required int tripId}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ReportDelaySheet(tripId: tripId),
);

/// Two taps for a driver: how late, and why. Riders at upcoming stops are told.
class _ReportDelaySheet extends ConsumerStatefulWidget {
  const _ReportDelaySheet({required this.tripId});

  final int tripId;

  @override
  ConsumerState<_ReportDelaySheet> createState() => _ReportDelaySheetState();
}

class _ReportDelaySheetState extends ConsumerState<_ReportDelaySheet> {
  static const _minutes = [5, 10, 15, 20, 30];
  static const _reasons = ['Heavy traffic', 'Road closed', 'Bus breakdown', 'Heavy rain', 'Waiting for students'];
  int? _min;
  String? _reason;
  final _other = TextEditingController();
  var _busy = false;
  String? _error;

  String get _finalReason => _other.text.trim().isNotEmpty ? _other.text.trim() : (_reason ?? '');

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(delayActionsProvider).report(widget.tripId, minutes: _min!, reason: _finalReason);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Riders at upcoming stops were told the bus is $_min min late.')));
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: Radii.signAll,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? TransitColors.ink : TransitColors.white,
        borderRadius: Radii.signAll,
        border: Border.all(color: selected ? TransitColors.ink : TransitColors.rule, width: 1.5),
      ),
      child: Text(
        label,
        style: TransitType.subheading.copyWith(
          color: selected ? TransitColors.white : TransitColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ready = _min != null && _finalReason.length >= 3;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        Space.xl,
        Space.gutter,
        MediaQuery.viewInsetsOf(context).bottom + Space.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Running late', style: TransitType.title),
          const SizedBox(height: Space.xs),
          Text(
            'Students waiting at the next stops get your message.',
            style: TransitType.body.copyWith(color: TransitColors.inkSoft),
          ),
          const SizedBox(height: Space.l),
          const Text('How late?', style: TransitType.subheading),
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [for (final m in _minutes) _choice('$m min', _min == m, () => setState(() => _min = m))],
          ),
          const SizedBox(height: Space.l),
          const Text('Why?', style: TransitType.subheading),
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final r in _reasons)
                _choice(
                  r,
                  _reason == r && _other.text.isEmpty,
                  () => setState(() {
                    _reason = r;
                    _other.clear();
                  }),
                ),
            ],
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: _other,
            decoration: const InputDecoration(labelText: 'Or type the reason'),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: Space.m),
            Text(_error!, style: TransitType.body.copyWith(color: TransitColors.late)),
          ],
          const SizedBox(height: Space.xl),
          SignButton(
            label: _min == null ? 'Tell riders' : 'Tell riders: $_min min late',
            expand: true,
            height: 56,
            busy: _busy,
            onPressed: ready ? _send : null,
          ),
        ],
      ),
    );
  }
}
