import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../design/tokens.dart';
import '../../master_data/data/master_data_api.dart';
import '../../trips/data/trip_models.dart';

// ---------------- Admin ----------------
class BoardRow {
  const BoardRow({
    required this.tripId,
    required this.route,
    required this.direction,
    required this.registration,
    required this.driverName,
    required this.status,
    required this.scheduledDeparture,
    required this.delayMin,
    required this.stopsTotal,
    required this.stopsDone,
    required this.boarded,
    required this.capacity,
    required this.occupancy,
    required this.allocated,
    this.nextStopName,
    this.nextStopExpected,
    this.nextStopScheduled,
  });

  final int tripId;
  final RouteRef route;
  final String direction;
  final String registration;
  final String driverName;
  final TripStatus status;
  final DateTime scheduledDeparture;
  final int delayMin;
  final String? nextStopName;
  final DateTime? nextStopScheduled;
  final DateTime? nextStopExpected;
  final int stopsTotal;
  final int stopsDone;
  final int boarded;
  final int capacity;
  final String occupancy; // ok | warning | full | over | unknown
  final int allocated;

  factory BoardRow.fromJson(Json j) {
    final ns = j['next_stop'] as Json?;
    return BoardRow(
      tripId: j['trip_id'] as int,
      route: RouteRef.fromJson(j['route'] as Json),
      direction: j['direction'] as String,
      registration: j['bus_registration_no'] as String,
      driverName: j['driver_name'] as String,
      status: TripStatus.parse(j['status'] as String),
      scheduledDeparture: parseTime(j['scheduled_departure'])!,
      delayMin: j['delay_min'] as int,
      nextStopName: ns?['name'] as String?,
      nextStopScheduled: parseTime(ns?['scheduled_at']),
      nextStopExpected: parseTime(ns?['expected_at']),
      stopsTotal: j['stops_total'] as int,
      stopsDone: j['stops_done'] as int,
      boarded: j['boarded'] as int,
      capacity: j['capacity'] as int,
      occupancy: j['occupancy_level'] as String,
      allocated: j['allocated'] as int,
    );
  }
}

class AlertEvent {
  const AlertEvent({required this.id, required this.type, required this.payload, required this.occurredAt, this.actor});

  final int id;
  final String type;
  final Json payload;
  final DateTime occurredAt;
  final String? actor;

  factory AlertEvent.fromJson(Json j) => AlertEvent(
    id: j['id'] as int,
    type: j['type'] as String,
    payload: j['payload'] as Json,
    occurredAt: parseTime(j['occurred_at'])!,
    actor: j['actor_name'] as String?,
  );
}

class RouteUtil {
  const RouteUtil({
    required this.route,
    required this.allocated,
    required this.capacity,
    required this.pct,
    required this.level,
    required this.schedules,
  });

  final RouteRef route;
  final int allocated;
  final int? capacity;
  final int? pct;
  final String level;
  final int schedules;

  factory RouteUtil.fromJson(Json j) => RouteUtil(
    route: RouteRef(
      id: j['route_id'] as int,
      code: j['code'] as String,
      name: j['name'] as String,
      color: TransitColors.parseHex(j['color'] as String),
    ),
    allocated: j['allocated'] as int,
    capacity: j['seat_capacity'] as int?,
    pct: j['pct'] as int?,
    level: j['level'] as String,
    schedules: j['active_schedules'] as int,
  );
}

class AdminDashboard {
  const AdminDashboard({
    required this.serviceDate,
    required this.counts,
    required this.board,
    required this.alerts,
    required this.utilization,
  });

  final DateTime serviceDate;
  final Map<String, int> counts;
  final List<BoardRow> board;
  final List<AlertEvent> alerts;
  final List<RouteUtil> utilization;

  factory AdminDashboard.fromJson(Json j) => AdminDashboard(
    serviceDate: DateTime.parse(j['service_date'] as String),
    counts: (j['counts'] as Json).map((k, v) => MapEntry(k, v as int)),
    board: asList(j['board']).map(BoardRow.fromJson).toList(),
    alerts: asList(j['alerts']).map(AlertEvent.fromJson).toList(),
    utilization: asList(j['utilization']).map(RouteUtil.fromJson).toList(),
  );
}

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboard>((ref) async {
  return AdminDashboard.fromJson(await ref.read(apiProvider).get<Json>('/dashboard/admin'));
});

// ---------------- Driver ----------------
class DriverTrip {
  const DriverTrip({required this.trip, required this.delayMin, required this.boarded, required this.capacity});

  final TripDetail trip;
  final int delayMin;
  final int boarded;
  final int capacity;

  factory DriverTrip.fromJson(Json j) => DriverTrip(
    trip: TripDetail.fromJson(j['trip'] as Json),
    delayMin: j['delay_min'] as int,
    boarded: j['boarded'] as int,
    capacity: j['capacity'] as int,
  );
}

class DriverDashboard {
  const DriverDashboard({required this.trips, this.active});

  final List<DriverTrip> trips;
  final DriverTrip? active;

  factory DriverDashboard.fromJson(Json j) => DriverDashboard(
    trips: asList(j['trips']).map(DriverTrip.fromJson).toList(),
    active: j['active'] == null ? null : DriverTrip.fromJson(j['active'] as Json),
  );
}

final driverDashboardProvider = FutureProvider.autoDispose<DriverDashboard>((ref) async {
  return DriverDashboard.fromJson(await ref.read(apiProvider).get<Json>('/dashboard/driver'));
});

// ---------------- Student ----------------
class StudentTrip {
  const StudentTrip({
    required this.tripId,
    required this.direction,
    required this.status,
    required this.scheduledDeparture,
    required this.registration,
    required this.delayMin,
    required this.stopsDone,
    required this.stopsTotal,
    required this.boarded,
    this.startedAt,
    this.myStopName,
    this.myStopSequence,
    this.myStopScheduled,
    this.myStopExpected,
    this.myStopArrived,
    this.nextStopName,
    this.boardedAt,
  });

  final int tripId;
  final String direction;
  final TripStatus status;
  final DateTime scheduledDeparture;
  final DateTime? startedAt;
  final String registration;
  final int delayMin;
  final String? myStopName;
  final int? myStopSequence;
  final DateTime? myStopScheduled;
  final DateTime? myStopExpected;
  final DateTime? myStopArrived;
  final String? nextStopName;
  final int stopsDone;
  final int stopsTotal;
  final bool boarded;
  final DateTime? boardedAt;

  bool get isPickup => direction == 'pickup';

  factory StudentTrip.fromJson(Json j) {
    final my = j['my_stop'] as Json?;
    return StudentTrip(
      tripId: j['trip_id'] as int,
      direction: j['direction'] as String,
      status: TripStatus.parse(j['status'] as String),
      scheduledDeparture: parseTime(j['scheduled_departure'])!,
      startedAt: parseTime(j['started_at']),
      registration: j['bus_registration_no'] as String,
      delayMin: j['delay_min'] as int,
      myStopName: my?['name'] as String?,
      myStopSequence: my?['sequence'] as int?,
      myStopScheduled: parseTime(my?['scheduled_at']),
      myStopExpected: parseTime(my?['expected_at']),
      myStopArrived: parseTime(my?['arrived_at']),
      nextStopName: j['next_stop_name'] as String?,
      stopsDone: j['stops_done'] as int,
      stopsTotal: j['stops_total'] as int,
      boarded: j['boarded'] as bool,
      boardedAt: parseTime(j['boarded_at']),
    );
  }
}

class StudentDashboard {
  const StudentDashboard({required this.trips, required this.unread, this.route, this.myStopId});

  final TransitRoute? route;
  final int? myStopId;
  final List<StudentTrip> trips;
  final int unread;

  factory StudentDashboard.fromJson(Json j) {
    final alloc = j['allocation'] as Json?;
    return StudentDashboard(
      route: alloc == null ? null : TransitRoute.fromJson(alloc['route'] as Json),
      myStopId: alloc == null ? null : ((alloc['allocation'] as Json)['stop'] as Json)['id'] as int,
      trips: asList(j['trips']).map(StudentTrip.fromJson).toList(),
      unread: j['unread_notifications'] as int,
    );
  }
}

final studentDashboardProvider = FutureProvider.autoDispose<StudentDashboard>((ref) async {
  return StudentDashboard.fromJson(await ref.read(apiProvider).get<Json>('/dashboard/student'));
});
