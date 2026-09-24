import 'dart:ui';

import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../design/tokens.dart';

class RouteRef {
  const RouteRef({required this.id, required this.code, required this.name, required this.color});

  final int id;
  final String code;
  final String name;
  final Color color;

  factory RouteRef.fromJson(Json j) => RouteRef(
    id: j['id'] as int,
    code: j['code'] as String,
    name: j['name'] as String,
    color: TransitColors.parseHex(j['color'] as String),
  );
}

class StopEvent {
  const StopEvent({
    required this.id,
    required this.stopId,
    required this.stopName,
    required this.sequence,
    required this.scheduledAt,
    this.arrivedAt,
    this.delayMin,
  });

  final int id;
  final int stopId;
  final String stopName;
  final int sequence;
  final DateTime scheduledAt;
  final DateTime? arrivedAt;
  final int? delayMin;

  factory StopEvent.fromJson(Json j) => StopEvent(
    id: j['id'] as int,
    stopId: j['stop_id'] as int,
    stopName: j['stop_name'] as String,
    sequence: j['sequence'] as int,
    scheduledAt: parseTime(j['scheduled_at'])!,
    arrivedAt: parseTime(j['arrived_at']),
    delayMin: j['delay_min'] as int?,
  );
}

enum TripStatus {
  scheduled,
  inProgress,
  completed,
  cancelled;

  static TripStatus parse(String s) => s == 'in_progress' ? inProgress : TripStatus.values.byName(s);
}

class TripDetail {
  const TripDetail({
    required this.id,
    required this.direction,
    required this.status,
    required this.scheduledDeparture,
    required this.route,
    required this.busRegistration,
    required this.busCapacity,
    required this.driverName,
    required this.stops,
    required this.currentDelayMin,
    this.startedAt,
    this.endedAt,
    this.nextStop,
    this.cancelReason,
  });

  final int id;
  final String direction; // pickup | drop
  final TripStatus status;
  final DateTime scheduledDeparture;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final RouteRef route;
  final String busRegistration;
  final int busCapacity;
  final String driverName;
  final List<StopEvent> stops;
  final StopEvent? nextStop;
  final int currentDelayMin;
  final String? cancelReason;

  bool get running => status == TripStatus.inProgress;
  bool get isPickup => direction == 'pickup';
  String get headline => isPickup ? 'To ${stops.last.stopName}' : 'From ${stops.first.stopName}';

  factory TripDetail.fromJson(Json j) => TripDetail(
    id: j['id'] as int,
    direction: j['direction'] as String,
    status: TripStatus.parse(j['status'] as String),
    scheduledDeparture: parseTime(j['scheduled_departure'])!,
    startedAt: parseTime(j['started_at']),
    endedAt: parseTime(j['ended_at']),
    route: RouteRef.fromJson(j['route'] as Json),
    busRegistration: (j['bus'] as Json)['registration_no'] as String,
    busCapacity: (j['bus'] as Json)['capacity'] as int,
    driverName: (j['driver'] as Json)['full_name'] as String,
    stops: asList(j['stops']).map(StopEvent.fromJson).toList(),
    nextStop: j['next_stop'] == null ? null : StopEvent.fromJson(j['next_stop'] as Json),
    currentDelayMin: j['current_delay_min'] as int,
    cancelReason: j['cancel_reason'] as String?,
  );
}
