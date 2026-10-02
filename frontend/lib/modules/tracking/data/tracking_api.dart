import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../core/realtime/realtime.dart';
import '../../trips/data/trip_models.dart';

/// One GPS fix of a bus, as the API and the `position` WebSocket message send it.
class BusFix {
  const BusFix({
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.speedKmph,
    this.headingDeg,
  });

  final int? tripId;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? speedKmph;
  final double? headingDeg;

  LatLng get point => LatLng(latitude, longitude);

  factory BusFix.fromJson(Json j) => BusFix(
    tripId: j['trip_id'] as int?,
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    recordedAt: parseTime(j['recorded_at'])!,
    speedKmph: (j['speed_kmph'] as num?)?.toDouble(),
    headingDeg: (j['heading_deg'] as num?)?.toDouble(),
  );
}

class LiveStop {
  const LiveStop({
    required this.sequence,
    required this.stopId,
    required this.name,
    required this.scheduledAt,
    this.latitude,
    this.longitude,
    this.arrivedAt,
  });

  final int sequence;
  final int stopId;
  final String name;
  final double? latitude;
  final double? longitude;
  final DateTime scheduledAt;
  final DateTime? arrivedAt;

  LatLng? get point => latitude == null || longitude == null ? null : LatLng(latitude!, longitude!);

  factory LiveStop.fromJson(Json j) => LiveStop(
    sequence: j['sequence'] as int,
    stopId: j['stop_id'] as int,
    name: j['name'] as String,
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    scheduledAt: parseTime(j['scheduled_at'])!,
    arrivedAt: parseTime(j['arrived_at']),
  );
}

/// Everything a map needs for one trip: its line, stops and the bus's latest fix.
class LiveTrip {
  const LiveTrip({
    required this.tripId,
    required this.route,
    required this.direction,
    required this.status,
    required this.busRegistration,
    required this.delayMin,
    required this.stops,
    this.nextStopSequence,
    this.position,
  });

  final int tripId;
  final RouteRef route;
  final String direction;
  final TripStatus status;
  final String busRegistration;
  final int delayMin;
  final int? nextStopSequence;
  final BusFix? position;
  final List<LiveStop> stops;

  bool get running => status == TripStatus.inProgress;

  LiveTrip withPosition(BusFix? fix) => LiveTrip(
    tripId: tripId,
    route: route,
    direction: direction,
    status: status,
    busRegistration: busRegistration,
    delayMin: delayMin,
    stops: stops,
    nextStopSequence: nextStopSequence,
    position: fix,
  );

  /// Keep whichever fix is newer: a refetch can race a WebSocket update.
  LiveTrip withNewerPosition(BusFix? fix) {
    if (fix == null) return this;
    final current = position;
    return current == null || fix.recordedAt.isAfter(current.recordedAt) ? withPosition(fix) : this;
  }

  factory LiveTrip.fromJson(Json j) => LiveTrip(
    tripId: j['trip_id'] as int,
    route: RouteRef.fromJson(j['route'] as Json),
    direction: j['direction'] as String,
    status: TripStatus.parse(j['status'] as String),
    busRegistration: j['bus_registration_no'] as String,
    delayMin: j['delay_min'] as int,
    nextStopSequence: j['next_stop_sequence'] as int?,
    position: j['position'] == null ? null : BusFix.fromJson(j['position'] as Json),
    stops: asList(j['stops']).map(LiveStop.fromJson).toList(),
  );
}

/// Events after which the stops (reached / next) or the set of running buses change.
const _stopEvents = {'StopArrived', 'TripStarted', 'TripEnded', 'TripCancelled', 'TripDelayed', 'TripDelayResolved'};

/// One trip, kept live: the API snapshot, then `position` pushes move the bus and stop
/// events refetch. Position pushes reach whoever follows `route:<id>` (students do) and staff.
final liveTripProvider = StreamProvider.autoDispose.family<LiveTrip, int>((ref, tripId) async* {
  final api = ref.read(apiProvider);
  final live = ref.watch(realtimeProvider);
  Future<LiveTrip> fetch() async => LiveTrip.fromJson(await api.get<Json>('/trips/$tripId/live'));

  var trip = await fetch();
  yield trip;
  if (live == null) return;
  live.subscribe('route:${trip.route.id}');
  await for (final m in live.messages) {
    if (m.type == 'position' && m.data['trip_id'] == tripId) {
      trip = trip.withNewerPosition(BusFix.fromJson(m.data));
      yield trip;
    } else if (m.type == 'ops' && m.payload['trip_id'] == tripId && _stopEvents.contains(m.event)) {
      try {
        trip = (await fetch()).withNewerPosition(trip.position);
        yield trip;
      } on ApiException {
        // Keep showing the last good state; the next push or event tries again.
      }
    }
  }
});

/// Every running trip, for the transport office map.
final allLiveTripsProvider = StreamProvider.autoDispose<List<LiveTrip>>((ref) async* {
  final api = ref.read(apiProvider);
  final live = ref.watch(realtimeProvider);
  Future<List<LiveTrip>> fetch() async => asList(await api.get('/tracking/live')).map(LiveTrip.fromJson).toList();

  var trips = await fetch();
  yield trips;
  if (live == null) return;
  await for (final m in live.messages) {
    if (m.type == 'position') {
      final i = trips.indexWhere((t) => t.tripId == m.data['trip_id']);
      if (i < 0) continue; // a trip we haven't fetched yet: its TripStarted refetch brings it
      trips = [...trips]..[i] = trips[i].withNewerPosition(BusFix.fromJson(m.data));
      yield trips;
    } else if (m.type == 'ops' && _stopEvents.contains(m.event)) {
      final previous = {for (final t in trips) t.tripId: t.position};
      try {
        trips = [for (final t in await fetch()) t.withNewerPosition(previous[t.tripId])];
        yield trips;
      } on ApiException {
        // Keep the last good board.
      }
    }
  }
});
