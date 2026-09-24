import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../design/tokens.dart';

class Stop {
  const Stop({required this.id, required this.name, this.landmark});

  final int id;
  final String name;
  final String? landmark;

  factory Stop.fromJson(Json j) =>
      Stop(id: j['id'] as int, name: j['name'] as String, landmark: j['landmark'] as String?);
}

class RouteStop {
  const RouteStop({required this.id, required this.stop, required this.sequence, required this.offsetMin});

  final int id;
  final Stop stop;
  final int sequence;
  final int offsetMin;

  factory RouteStop.fromJson(Json j) => RouteStop(
    id: j['id'] as int,
    stop: Stop.fromJson(j['stop'] as Json),
    sequence: j['sequence'] as int,
    offsetMin: j['offset_min'] as int,
  );
}

class TransitRoute {
  const TransitRoute({
    required this.id,
    required this.code,
    required this.name,
    required this.colorHex,
    required this.isActive,
    required this.stops,
    this.description,
  });

  final int id;
  final String code;
  final String name;
  final String colorHex;
  final bool isActive;
  final String? description;
  final List<RouteStop> stops;

  Color get color => TransitColors.parseHex(colorHex);
  String get terminus => stops.isEmpty ? '—' : stops.last.stop.name;

  factory TransitRoute.fromJson(Json j) => TransitRoute(
    id: j['id'] as int,
    code: j['code'] as String,
    name: j['name'] as String,
    colorHex: j['color'] as String,
    isActive: j['is_active'] as bool,
    description: j['description'] as String?,
    stops: j['stops'] == null ? const [] : asList(j['stops']).map(RouteStop.fromJson).toList(),
  );
}

class Bus {
  const Bus({
    required this.id,
    required this.registration,
    required this.capacity,
    required this.status,
    this.model,
    this.driverId,
    this.driverName,
  });

  final int id;
  final String registration;
  final int capacity;
  final String status; // active | maintenance | retired
  final String? model;
  final int? driverId; // the bus's regular driver
  final String? driverName;

  factory Bus.fromJson(Json j) => Bus(
    id: j['id'] as int,
    registration: j['registration_no'] as String,
    capacity: j['capacity'] as int,
    status: j['status'] as String,
    model: j['model'] as String?,
    driverId: j['driver_id'] as int?,
    driverName: j['driver_name'] as String?,
  );
}

final routesProvider = FutureProvider.autoDispose<List<TransitRoute>>((ref) async {
  return asList(await ref.read(apiProvider).get('/routes')).map(TransitRoute.fromJson).toList();
});

final routeProvider = FutureProvider.autoDispose.family<TransitRoute, int>((ref, id) async {
  return TransitRoute.fromJson(await ref.read(apiProvider).get<Json>('/routes/$id'));
});

final stopsProvider = FutureProvider.autoDispose<List<Stop>>((ref) async {
  return asList(await ref.read(apiProvider).get('/stops')).map(Stop.fromJson).toList();
});

final busesProvider = FutureProvider.autoDispose<List<Bus>>((ref) async {
  return asList(await ref.read(apiProvider).get('/buses')).map(Bus.fromJson).toList();
});

class MasterDataActions {
  MasterDataActions(this._api);

  final ApiClient _api;

  Future<TransitRoute> createRoute({required String code, required String name, required String color}) async =>
      TransitRoute.fromJson(await _api.post<Json>('/routes', {'code': code, 'name': name, 'color': color}));

  Future<void> updateRoute(int id, Json body) => _api.patch('/routes/$id', body);

  Future<TransitRoute> setStops(int routeId, List<({int stopId, int offsetMin})> stops) async => TransitRoute.fromJson(
    await _api.put<Json>('/routes/$routeId/stops', [
      for (final s in stops) {'stop_id': s.stopId, 'offset_min': s.offsetMin},
    ]),
  );

  Future<Stop> createStop(String name, {String? landmark}) async =>
      Stop.fromJson(await _api.post<Json>('/stops', {'name': name, 'landmark': landmark}));

  Future<void> createBus({required String registration, required int capacity, String? model}) =>
      _api.post('/buses', {'registration_no': registration, 'capacity': capacity, 'model': model});

  Future<void> updateBus(int id, Json body) => _api.patch('/buses/$id', body);

  /// Set the bus's regular driver (null removes). Throws ApiException `driver_taken`
  /// when the driver already has another bus, unless [move] is true.
  Future<void> assignDriver(int busId, int? driverId, {bool move = false}) =>
      _api.put('/buses/$busId/driver', {'driver_id': driverId, 'move': move});
}

final masterDataActionsProvider = Provider((ref) => MasterDataActions(ref.read(apiProvider)));
