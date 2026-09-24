import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../design/design.dart';
import '../data/notifications_api.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxProvider);
    final hasUnread = inbox.asData?.value.any((n) => n.unread) ?? false;
    return ColoredBox(
      color: onDark ? TransitColors.board : TransitColors.enamel,
      child: Column(
        children: [
          SignHeader(
            title: 'Alerts',
            subtitle: 'Delays, boarding and capacity updates',
            color: onDark ? TransitColors.board : TransitColors.signBlue,
            trailing: hasUnread
                ? TextButton(
                    style: TextButton.styleFrom(foregroundColor: TransitColors.white),
                    onPressed: () async {
                      await ref.read(notificationActionsProvider).markAllRead();
                      ref.invalidate(inboxProvider);
                      ref.invalidate(unreadCountProvider);
                    },
                    child: const Text('Mark all read'),
                  )
                : null,
          ),
          Expanded(
            child: AsyncBody(
              value: inbox,
              onDark: onDark,
              onRetry: () => ref.invalidate(inboxProvider),
              builder: (list) => list.isEmpty
                  ? const SignNotice(
                      title: 'No alerts',
                      body: "When a bus is late or something changes on your route, you'll see it here.",
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(inboxProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(Space.gutter),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _AlertRow(n: list[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends ConsumerWidget {
  const _AlertRow({required this.n});

  final AppNotification n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edge = switch (n.severity) {
      'critical' => TransitColors.late,
      'warning' => TransitColors.caution,
      _ => TransitColors.signBlue,
    };
    return InkWell(
      onTap: n.unread
          ? () async {
              await ref.read(notificationActionsProvider).markRead(n.id);
              ref.invalidate(inboxProvider);
              ref.invalidate(unreadCountProvider);
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.s),
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(
          color: n.unread ? TransitColors.white : TransitColors.enamelDeep,
          borderRadius: Radii.signAll,
          border: Border(left: BorderSide(color: n.unread ? edge : TransitColors.rule, width: 5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (n.routeCode != null && n.routeColor != null) ...[
              RouteBadge(code: n.routeCode!, color: TransitColors.parseHex(n.routeColor!), size: 34),
              const SizedBox(width: Space.m),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TransitType.subheading.copyWith(fontWeight: n.unread ? FontWeight.w800 : FontWeight.w600),
                  ),
                  if (n.body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(n.body, style: TransitType.body.copyWith(color: TransitColors.inkSoft)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            Text(relative(n.createdAt), style: TransitType.small.copyWith(color: TransitColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}
