import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'trip_models.dart';

final tripProvider = FutureProvider.autoDispose.family<TripDetail, int>((ref, id) async {
  return TripDetail.fromJson(await ref.read(apiProvider).get<Json>('/trips/$id'));
});

class Schedule {
  const Schedule({
    required this.id,
    required this.routeId,
    required this.busId,
    required this.driverId,
    required this.direction,
    required this.departureTime,
    required this.days,
    required this.isActive,
  });

  final int id;
  final int routeId;
  final int busId;
  final int driverId;
  final String direction;
  final String departureTime; // "07:30:00"
  final List<int> days;
  final bool isActive;

  String get departureHm => departureTime.substring(0, 5);

  factory Schedule.fromJson(Json j) => Schedule(
    id: j['id'] as int,
    routeId: j['route_id'] as int,
    busId: j['bus_id'] as int,
    driverId: j['driver_id'] as int,
    direction: j['direction'] as String,
    departureTime: j['departure_time'] as String,
    days: (j['days_of_week'] as List).cast<int>(),
    isActive: j['is_active'] as bool,
  );
}

final schedulesProvider = FutureProvider.autoDispose<List<Schedule>>((ref) async {
  return asList(await ref.read(apiProvider).get('/schedules')).map(Schedule.fromJson).toList();
});

/// Driver/admin actions on a trip. Each returns the updated trip.
class TripActions {
  TripActions(this._api);

  final ApiClient _api;

  Future<TripDetail> start(int id) async => TripDetail.fromJson(await _api.post<Json>('/trips/$id/start'));

  Future<TripDetail> arrive(int id, int sequence) async =>
      TripDetail.fromJson(await _api.post<Json>('/trips/$id/stops/$sequence/arrive'));

  Future<TripDetail> end(int id) async => TripDetail.fromJson(await _api.post<Json>('/trips/$id/end'));

  Future<TripDetail> cancel(int id, String reason) async =>
      TripDetail.fromJson(await _api.post<Json>('/trips/$id/cancel', {'reason': reason}));

  Future<void> generateToday() => _api.post('/trips/generate', {});

  Future<void> createSchedule(Json body) => _api.post('/schedules', body);

  Future<void> updateSchedule(int id, Json body) => _api.patch('/schedules/$id', body);
}

final tripActionsProvider = Provider((ref) => TripActions(ref.read(apiProvider)));
