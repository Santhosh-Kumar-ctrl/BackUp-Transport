import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.severity,
    required this.payload,
    required this.createdAt,
    this.readAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final String severity; // info | warning | critical
  final Json payload;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;
  String? get routeCode => payload['route_code'] as String?;
  String? get routeColor => payload['route_color'] as String?;

  factory AppNotification.fromJson(Json j) => AppNotification(
    id: j['id'] as int,
    type: j['type'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    severity: j['severity'] as String,
    payload: (j['payload'] as Json?) ?? const {},
    createdAt: parseTime(j['created_at'])!,
    readAt: parseTime(j['read_at']),
  );
}

final inboxProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  return asList(await ref.read(apiProvider).get('/notifications', query: {'limit': 100}))
      .map(AppNotification.fromJson)
      .toList();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return (await ref.read(apiProvider).get<Json>('/notifications/unread-count'))['unread'] as int;
});

class NotificationActions {
  NotificationActions(this._api);

  final ApiClient _api;

  Future<void> markRead(int id) => _api.post('/notifications/$id/read');

  Future<void> markAllRead() => _api.post('/notifications/read-all');
}

final notificationActionsProvider = Provider((ref) => NotificationActions(ref.read(apiProvider)));
