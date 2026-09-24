import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/session.dart';
import '../../../design/design.dart';
import '../../auth/data/people_api.dart';
import '../data/master_data_api.dart';

class AdminFleetScreen extends ConsumerWidget {
  const AdminFleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buses = ref.watch(busesProvider);
    return Column(
      children: [
        SignHeader(
          title: 'Fleet',
          subtitle: buses.asData == null
              ? null
              : '${buses.asData!.value.where((b) => b.status == 'active').length} in service, '
                    '${buses.asData!.value.fold<int>(0, (n, b) => b.status == 'active' ? n + b.capacity : n)} seats',
          trailing: SignButton(
            label: 'Add bus',
            icon: Icons.add,
            kind: SignButtonKind.onDark,
            height: 44,
            onPressed: () async {
              if (await showDialog<bool>(context: context, builder: (_) => const _AddBusDialog()) == true) {
                ref.invalidate(busesProvider);
              }
            },
          ),
        ),
        Expanded(
          child: AsyncBody(
            value: buses,
            onRetry: () => ref.invalidate(busesProvider),
            builder: (list) => list.isEmpty
                ? const SignNotice(
                    title: 'No buses yet',
                    body: 'Add the buses the college runs, with their seat count.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(Space.gutter),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (_, i) => _BusRow(bus: list[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _BusRow extends ConsumerWidget {
  const _BusRow({required this.bus});

  final Bus bus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = bus;
    final tone = switch (b.status) {
      'active' => Tone.go,
      'maintenance' => Tone.caution,
      _ => Tone.neutral,
    };
    final info = Row(
      children: [
        NumberPlate(b.registration),
        const SizedBox(width: Space.l),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.model ?? 'Bus', style: TransitType.subheading.copyWith(fontWeight: FontWeight.w800)),
              Text('${b.capacity} seats', style: TransitType.small.copyWith(color: TransitColors.inkSoft)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: b.driverName == null ? TransitColors.caution : TransitColors.inkSoft,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      b.driverName ?? 'No driver assigned',
                      style: TransitType.small.copyWith(
                        color: TransitColors.ink,
                        fontWeight: b.driverName == null ? FontWeight.w400 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final actions = [
      TextButton(
        onPressed: () async {
          final changed = await showDialog<bool>(
            context: context,
            builder: (_) => _AssignDriverDialog(bus: b),
          );
          if (changed == true) ref.invalidate(busesProvider);
        },
        child: Text(b.driverId == null ? 'Assign driver' : 'Change driver'),
      ),
      const SizedBox(width: Space.s),
      PopupMenuButton<String>(
        tooltip: 'Change status',
        onSelected: (s) async {
          try {
            await ref.read(masterDataActionsProvider).updateBus(b.id, {'status': s});
            ref.invalidate(busesProvider);
          } on ApiException catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'active', child: Text('In service')),
          PopupMenuItem(value: 'maintenance', child: Text('In maintenance')),
          PopupMenuItem(value: 'retired', child: Text('Retired')),
        ],
        child: StatusPlate(switch (b.status) {
          'active' => 'In service',
          'maintenance' => 'Maintenance',
          _ => 'Retired',
        }, tone: tone),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.m),
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth < 600
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  info,
                  const SizedBox(height: Space.s),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
                ],
              )
            : Row(
                children: [
                  Expanded(child: info),
                  ...actions,
                ],
              ),
      ),
    );
  }
}

/// Pick the bus's regular driver. Their schedules and upcoming trips on this bus move to them.
class _AssignDriverDialog extends ConsumerStatefulWidget {
  const _AssignDriverDialog({required this.bus});

  final Bus bus;

  @override
  ConsumerState<_AssignDriverDialog> createState() => _AssignDriverDialogState();
}

class _AssignDriverDialogState extends ConsumerState<_AssignDriverDialog> {
  late int? _selected = widget.bus.driverId;
  var _busy = false;
  String? _error;
  ApiException? _taken; // driver already drives another bus

  Future<void> _save({bool move = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(masterDataActionsProvider).assignDriver(widget.bus.id, _selected, move: move);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        if (e.code == 'driver_taken') {
          _taken = e;
        } else {
          _error = e.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final drivers = ref.watch(peopleProvider((role: Role.driver, q: '')));
    final buses = ref.watch(busesProvider).asData?.value ?? const <Bus>[];
    final busOf = {
      for (final b in buses)
        if (b.driverId != null && b.id != widget.bus.id) b.driverId!: b,
    };
    final unchanged = _selected == widget.bus.driverId;

    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Driver for', style: TransitType.heading)),
          NumberPlate(widget.bus.registration),
        ],
      ),
      content: SizedBox(
        width: 440,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Schedules and upcoming trips on this bus move to the driver you pick. Trips already running keep their driver.',
              style: TransitType.small.copyWith(color: TransitColors.inkSoft),
            ),
            const SizedBox(height: Space.m),
            Expanded(
              child: AsyncBody(
                value: drivers,
                builder: (list) => RadioGroup<int?>(
                  groupValue: _selected,
                  onChanged: (v) => setState(() {
                    _selected = v;
                    _taken = null;
                  }),
                  child: ListView(
                    children: [
                      for (final d in list.where((d) => d.isActive))
                        RadioListTile<int?>(
                          value: d.id,
                          title: Text(d.fullName, style: TransitType.subheading),
                          subtitle: Text(
                            busOf[d.id] == null ? 'No bus' : 'Drives ${NumberPlate.format(busOf[d.id]!.registration)}',
                            style: TransitType.small.copyWith(
                              color: busOf[d.id] == null ? TransitColors.inkSoft : TransitColors.ink,
                            ),
                          ),
                        ),
                      if (widget.bus.driverId != null)
                        RadioListTile<int?>(
                          value: null,
                          title: Text('No driver', style: TransitType.subheading),
                          subtitle: Text(
                            'Existing runs keep their current driver',
                            style: TransitType.small.copyWith(color: TransitColors.inkSoft),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_taken != null)
              Container(
                padding: const EdgeInsets.all(Space.m),
                decoration: const BoxDecoration(
                  color: TransitColors.white,
                  border: Border(left: BorderSide(color: TransitColors.caution, width: 5)),
                ),
                child: Text(
                  '${_taken!.message}. Move them to this bus? '
                  '${NumberPlate.format(_taken!.data?['registration_no'] as String? ?? '')} will have no driver.',
                  style: TransitType.body,
                ),
              ),
            if (_error != null) Text(_error!, style: TransitType.body.copyWith(color: TransitColors.late)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        SignButton(
          label: _taken != null ? 'Move driver here' : 'Save',
          height: 44,
          busy: _busy,
          onPressed: unchanged ? null : () => _save(move: _taken != null),
        ),
      ],
    );
  }
}

class _AddBusDialog extends ConsumerStatefulWidget {
  const _AddBusDialog();

  @override
  ConsumerState<_AddBusDialog> createState() => _AddBusDialogState();
}

class _AddBusDialogState extends ConsumerState<_AddBusDialog> {
  final _reg = TextEditingController();
  final _cap = TextEditingController(text: '40');
  final _model = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add bus', style: TransitType.heading),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _reg,
            decoration: const InputDecoration(labelText: 'Registration, e.g. TN09AB1401'),
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: _cap,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Seats'),
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: _model,
            decoration: const InputDecoration(labelText: 'Model (optional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: Space.m),
            Text(_error!, style: TransitType.body.copyWith(color: TransitColors.late)),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      SignButton(
        label: 'Add bus',
        height: 44,
        onPressed: () async {
          try {
            await ref
                .read(masterDataActionsProvider)
                .createBus(
                  registration: _reg.text.trim(),
                  capacity: int.tryParse(_cap.text) ?? 0,
                  model: _model.text.trim().isEmpty ? null : _model.text.trim(),
                );
            if (context.mounted) Navigator.pop(context, true);
          } on ApiException catch (e) {
            setState(() => _error = e.message);
          }
        },
      ),
    ],
  );
}
