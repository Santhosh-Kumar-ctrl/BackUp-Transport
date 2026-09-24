import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../design/design.dart';
import '../data/master_data_api.dart';

/// Curated line colours. They steer clear of the status colours (red / amber / green).
const routePalette = ['#0B5CAD', '#00857C', '#8C1D40', '#7A5230', '#B0106E', '#3D4F63', '#5B3F99', '#00708F'];

class AdminNetworkScreen extends ConsumerWidget {
  const AdminNetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(routesProvider);
    return Column(
      children: [
        SignHeader(
          title: 'Network',
          subtitle: 'Routes and the order of their stops',
          trailing: SignButton(
            label: 'New route',
            icon: Icons.add,
            kind: SignButtonKind.onDark,
            height: 44,
            onPressed: () => _newRoute(context, ref),
          ),
        ),
        Expanded(
          child: AsyncBody(
            value: routes,
            onRetry: () => ref.invalidate(routesProvider),
            builder: (list) => list.isEmpty
                ? SignNotice(
                    title: 'No routes yet',
                    body: 'Create a route, then add its stops in order, ending at the campus.',
                    actionLabel: 'New route',
                    onAction: () => _newRoute(context, ref),
                  )
                : ListView(
                    padding: const EdgeInsets.all(Space.gutter),
                    children: [for (final r in list) _RouteStrip(route: r)],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _newRoute(BuildContext context, WidgetRef ref) async {
    final code = TextEditingController();
    final name = TextEditingController();
    var color = routePalette.first;
    String? error;
    final created = await showDialog<TransitRoute>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('New route', style: TransitType.heading),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'Route number, e.g. 14'),
                ),
                const SizedBox(height: Space.m),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name, e.g. North Loop'),
                ),
                const SizedBox(height: Space.l),
                const Text('Line colour', style: TransitType.subheading),
                const SizedBox(height: Space.s),
                ColorPicker(value: color, onChanged: (v) => set(() => color = v)),
                if (error != null) ...[
                  const SizedBox(height: Space.m),
                  Text(error!, style: TransitType.body.copyWith(color: TransitColors.late)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            SignButton(
              label: 'Create route',
              height: 44,
              onPressed: () async {
                try {
                  final r = await ref
                      .read(masterDataActionsProvider)
                      .createRoute(code: code.text.trim(), name: name.text.trim(), color: color);
                  if (c.mounted) Navigator.pop(c, r);
                } on ApiException catch (e) {
                  set(() => error = e.message);
                }
              },
            ),
          ],
        ),
      ),
    );
    if (created != null) {
      ref.invalidate(routesProvider);
      if (context.mounted) context.go('/admin/network/${created.id}');
    }
  }
}

class ColorPicker extends StatelessWidget {
  const ColorPicker({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.s,
    runSpacing: Space.s,
    children: [
      for (final hex in routePalette)
        Semantics(
          button: true,
          selected: hex == value,
          label: 'Colour $hex',
          child: InkWell(
            onTap: () => onChanged(hex),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: TransitColors.parseHex(hex),
                borderRadius: Radii.signAll,
                border: Border.all(color: hex == value ? TransitColors.ink : Colors.transparent, width: 3),
              ),
            ),
          ),
        ),
    ],
  );
}

/// A route as a horizontal strip map: badge, name, then its stops as dots on the line colour.
class _RouteStrip extends StatelessWidget {
  const _RouteStrip({required this.route});

  final TransitRoute route;

  @override
  Widget build(BuildContext context) {
    final r = route;
    return InkWell(
      onTap: () => context.go('/admin/network/${r.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.m),
        padding: const EdgeInsets.all(Space.l),
        decoration: const BoxDecoration(color: TransitColors.white, borderRadius: Radii.signAll),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RouteBadge(code: r.code, color: r.color),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: TransitType.heading),
                      Text(
                        r.stops.isEmpty
                            ? 'No stops yet'
                            : '${r.stops.length} stops, ${r.stops.first.stop.name} to ${r.terminus}, ${r.stops.last.offsetMin} min',
                        style: TransitType.small.copyWith(color: TransitColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                if (!r.isActive) const StatusPlate('Inactive', tone: Tone.neutral),
              ],
            ),
            if (r.stops.length >= 2) ...[const SizedBox(height: Space.l), _MiniLine(route: r)],
          ],
        ),
      ),
    );
  }
}

class _MiniLine extends StatelessWidget {
  const _MiniLine({required this.route});

  final TransitRoute route;

  @override
  Widget build(BuildContext context) {
    final total = route.stops.last.offsetMin.clamp(1, 10000);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth - 16;
        return SizedBox(
          height: 22,
          child: Stack(
            children: [
              Positioned(left: 8, right: 8, top: 7, child: Container(height: 8, color: route.color)),
              for (final s in route.stops)
                Positioned(
                  left: w * s.offsetMin / total,
                  top: 3,
                  child: Tooltip(
                    message: s.stop.name,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: TransitColors.white,
                        shape: s == route.stops.last ? BoxShape.rectangle : BoxShape.circle,
                        border: Border.all(color: route.color, width: 3.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
