import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../dashboard/data/dashboard_api.dart';

class TripReport {
  const TripReport({
    required this.tripId,
    required this.date,
    required this.routeCode,
    required this.routeColor,
    required this.direction,
    required this.registration,
    required this.driverName,
    required this.status,
    required this.scheduledDeparture,
    required this.maxDelay,
    required this.alerts,
    required this.boarded,
    required this.present,
    required this.absent,
    this.startedAt,
    this.endedAt,
  });

  final int tripId;
  final DateTime date;
  final String routeCode;
  final String routeColor;
  final String direction;
  final String registration;
  final String driverName;
  final String status;
  final DateTime scheduledDeparture;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int maxDelay;
  final int alerts;
  final int boarded;
  final int present;
  final int absent;

  factory TripReport.fromJson(Json j) => TripReport(
    tripId: j['trip_id'] as int,
    date: DateTime.parse(j['service_date'] as String),
    routeCode: j['route_code'] as String,
    routeColor: j['route_color'] as String,
    direction: j['direction'] as String,
    registration: j['bus_registration_no'] as String,
    driverName: j['driver_name'] as String,
    status: j['status'] as String,
    scheduledDeparture: parseTime(j['scheduled_departure'])!,
    startedAt: parseTime(j['started_at']),
    endedAt: parseTime(j['ended_at']),
    maxDelay: j['max_delay_min'] as int,
    alerts: j['delay_alerts'] as int,
    boarded: j['boarded'] as int,
    present: j['present'] as int,
    absent: j['absent'] as int,
  );
}

class AttendanceRow {
  const AttendanceRow({
    required this.date,
    required this.tripId,
    required this.routeCode,
    required this.direction,
    required this.studentName,
    required this.status,
    this.rollNo,
    this.boardedAt,
  });

  final DateTime date;
  final int tripId;
  final String routeCode;
  final String direction;
  final String studentName;
  final String? rollNo;
  final String status;
  final DateTime? boardedAt;

  factory AttendanceRow.fromJson(Json j) => AttendanceRow(
    date: DateTime.parse(j['service_date'] as String),
    tripId: j['trip_id'] as int,
    routeCode: j['route_code'] as String,
    direction: j['direction'] as String,
    studentName: j['student_name'] as String,
    rollNo: j['roll_no'] as String?,
    status: j['status'] as String,
    boardedAt: parseTime(j['boarded_at']),
  );
}

String _d(DateTime d) => d.toIso8601String().substring(0, 10);

final tripReportsProvider = FutureProvider.autoDispose.family<List<TripReport>, DateTime>((ref, day) async {
  return asList(await ref.read(apiProvider).get('/history/trips', query: {'date_from': _d(day), 'date_to': _d(day)}))
      .map(TripReport.fromJson)
      .toList();
});

final attendanceProvider = FutureProvider.autoDispose.family<List<AttendanceRow>, DateTime>((ref, day) async {
  return asList(
    await ref.read(apiProvider).get('/history/attendance', query: {'date_from': _d(day), 'date_to': _d(day)}),
  ).map(AttendanceRow.fromJson).toList();
});

final timelineProvider = FutureProvider.autoDispose.family<List<AlertEvent>, int>((ref, tripId) async {
  return asList(await ref.read(apiProvider).get('/history/trips/$tripId/timeline')).map(AlertEvent.fromJson).toList();
});
