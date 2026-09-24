import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format.dart';

class TripQr {
  const TripQr({
    required this.token,
    required this.expiresAt,
    required this.ttlSeconds,
    required this.issuedAt,
    required this.routeCode,
    required this.routeColor,
    required this.registration,
  });

  final String token;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int ttlSeconds;
  final String routeCode;
  final String routeColor;
  final String registration;

  factory TripQr.fromJson(Json j) => TripQr(
    token: j['token'] as String,
    issuedAt: parseTime(j['issued_at'])!,
    expiresAt: parseTime(j['expires_at'])!,
    ttlSeconds: j['ttl_seconds'] as int,
    routeCode: j['route_code'] as String,
    routeColor: j['route_color'] as String,
    registration: j['bus_registration_no'] as String,
  );
}

class BoardingReceipt {
  const BoardingReceipt({
    required this.studentName,
    required this.boardedAt,
    required this.allocationMatch,
    required this.routeCode,
    required this.routeName,
    required this.routeColor,
    required this.registration,
    required this.boardedCount,
    required this.message,
    this.stopName,
  });

  final String studentName;
  final DateTime boardedAt;
  final bool allocationMatch;
  final String routeCode;
  final String routeName;
  final String routeColor;
  final String registration;
  final String? stopName;
  final int boardedCount;
  final String message;

  factory BoardingReceipt.fromJson(Json j) => BoardingReceipt(
    studentName: j['student_name'] as String,
    boardedAt: parseTime(j['boarded_at'])!,
    allocationMatch: j['allocation_match'] as bool,
    routeCode: j['route_code'] as String,
    routeName: j['route_name'] as String,
    routeColor: j['route_color'] as String,
    registration: j['bus_registration_no'] as String,
    stopName: j['stop_name'] as String?,
    boardedCount: j['boarded_count'] as int,
    message: j['message'] as String,
  );
}

class RosterEntry {
  const RosterEntry({
    required this.studentId,
    required this.fullName,
    required this.allocated,
    required this.boarded,
    this.rollNo,
    this.stopName,
    this.boardedAt,
    this.method,
  });

  final int studentId;
  final String fullName;
  final String? rollNo;
  final String? stopName;
  final bool allocated;
  final bool boarded;
  final DateTime? boardedAt;
  final String? method;

  factory RosterEntry.fromJson(Json j) => RosterEntry(
    studentId: j['student_id'] as int,
    fullName: j['full_name'] as String,
    rollNo: j['roll_no'] as String?,
    stopName: j['stop_name'] as String?,
    allocated: j['allocated'] as bool,
    boarded: j['boarded'] as bool,
    boardedAt: parseTime(j['boarded_at']),
    method: j['method'] as String?,
  );
}

class Roster {
  const Roster({required this.capacity, required this.allocated, required this.boarded, required this.entries});

  final int capacity;
  final int allocated;
  final int boarded;
  final List<RosterEntry> entries;

  factory Roster.fromJson(Json j) => Roster(
    capacity: j['capacity'] as int,
    allocated: j['allocated_count'] as int,
    boarded: j['boarded_count'] as int,
    entries: asList(j['entries']).map(RosterEntry.fromJson).toList(),
  );
}

class AttendanceItem {
  const AttendanceItem({
    required this.tripId,
    required this.date,
    required this.routeCode,
    required this.routeColor,
    required this.direction,
    required this.status,
    this.boardedAt,
  });

  final int tripId;
  final DateTime date;
  final String routeCode;
  final String routeColor;
  final String direction;
  final String status; // present | absent | present_unallocated
  final DateTime? boardedAt;

  factory AttendanceItem.fromJson(Json j) => AttendanceItem(
    tripId: j['trip_id'] as int,
    date: DateTime.parse(j['service_date'] as String),
    routeCode: j['route_code'] as String,
    routeColor: j['route_color'] as String,
    direction: j['direction'] as String,
    status: j['status'] as String,
    boardedAt: parseTime(j['boarded_at']),
  );
}

final rosterProvider = FutureProvider.autoDispose.family<Roster, int>((ref, tripId) async {
  return Roster.fromJson(await ref.read(apiProvider).get<Json>('/boarding/trips/$tripId/roster'));
});

final myAttendanceProvider = FutureProvider.autoDispose<List<AttendanceItem>>((ref) async {
  return asList(await ref.read(apiProvider).get('/boarding/me/attendance')).map(AttendanceItem.fromJson).toList();
});

class BoardingActions {
  BoardingActions(this._api);

  final ApiClient _api;

  Future<TripQr> qr(int tripId) async => TripQr.fromJson(await _api.get<Json>('/boarding/trips/$tripId/qr'));

  Future<BoardingReceipt> checkIn(String token) async =>
      BoardingReceipt.fromJson(await _api.post<Json>('/boarding/check-in', {'token': token}));

  Future<BoardingReceipt> manual(int tripId, {int? studentId, String? rollNo}) async => BoardingReceipt.fromJson(
    await _api.post<Json>('/boarding/trips/$tripId/manual', {'student_id': studentId, 'roll_no': rollNo}),
  );
}

final boardingActionsProvider = Provider((ref) => BoardingActions(ref.read(apiProvider)));
