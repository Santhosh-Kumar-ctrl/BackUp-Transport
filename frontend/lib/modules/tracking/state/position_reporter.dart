import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/session.dart';
import '../data/tracking_api.dart';

enum ReporterStatus {
  /// Not reporting (no trip running).
  off,
  starting,

  /// Fixes are flowing and reaching the server.
  sharing,

  /// Fixes are flowing but the server can't be reached; they are buffered.
  offline,

  /// Location permission refused.
  denied,

  /// Location is switched off on the phone.
  serviceOff,

  /// This device or browser has no usable location service.
  unavailable,
}

@immutable
class ReporterState {
  const ReporterState({this.status = ReporterStatus.off, this.tripId, this.lastFix, this.lastSentAt, this.pending = 0});

  final ReporterStatus status;
  final int? tripId;
  final BusFix? lastFix;
  final DateTime? lastSentAt;
  final int pending;

  bool get active => status == ReporterStatus.sharing || status == ReporterStatus.offline;

  ReporterState copyWith({ReporterStatus? status, BusFix? lastFix, DateTime? lastSentAt, int? pending}) =>
      ReporterState(
        status: status ?? this.status,
        tripId: tripId,
        lastFix: lastFix ?? this.lastFix,
        lastSentAt: lastSentAt ?? this.lastSentAt,
        pending: pending ?? this.pending,
      );
}

/// The driver's phone as the bus's GPS unit. While a trip runs it streams fixes, buffers them
/// when the network drops and sends them in batches; the server checks the bus in at stops and
/// tells riders when it's close. On Android a foreground service (with its own notification)
/// keeps it reporting with the screen off. On web it works only while the tab is open.
class PositionReporter extends Notifier<ReporterState> {
  static const _sendEvery = Duration(seconds: 5);
  static const _maxBatch = 500; // server limit per request
  static const _maxBuffer = 5000; // ~7 hours of fixes: beyond that drop the oldest

  StreamSubscription<Position>? _fixes;
  Timer? _timer;
  final _buffer = <Json>[];
  var _sending = false;

  @override
  ReporterState build() {
    // A new sign-in starts clean; signing out stops reporting.
    ref.watch(sessionProvider.select((s) => s?.user.id));
    ref.onDispose(_teardown);
    return const ReporterState();
  }

  Future<void> start(int tripId) async {
    if (state.tripId == tripId && (state.active || state.status == ReporterStatus.starting)) return;
    _teardown();
    state = ReporterState(status: ReporterStatus.starting, tripId: tripId);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        state = ReporterState(status: ReporterStatus.serviceOff, tripId: tripId);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        state = ReporterState(status: ReporterStatus.denied, tripId: tripId);
        return;
      }
    } catch (_) {
      // No location plugin/implementation here (some browsers, tests): the driver taps Arrived.
      state = ReporterState(status: ReporterStatus.unavailable, tripId: tripId);
      return;
    }
    if (state.tripId != tripId) return; // stopped or switched while we were asking

    _fixes = Geolocator.getPositionStream(locationSettings: _settings())
        .listen(_onFix, onError: (_) => state = state.copyWith(status: ReporterStatus.serviceOff));
    _timer = Timer.periodic(_sendEvery, (_) => _send());
    state = state.copyWith(status: ReporterStatus.sharing);
  }

  /// Stop reporting (trip ended). Unsent fixes are dropped: the trip no longer accepts them.
  void stop() {
    _teardown();
    state = const ReporterState();
  }

  /// Open the phone's settings for whatever is blocking us.
  Future<void> fixSettings() async {
    if (state.status == ReporterStatus.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
    final trip = state.tripId;
    if (trip != null) {
      state = const ReporterState();
      await start(trip);
    }
  }

  LocationSettings _settings() {
    const accuracy = LocationAccuracy.high;
    const distanceFilter = 10; // metres: a parked bus doesn't flood the server
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Sharing bus location',
          notificationText: 'Riders can see the bus while this trip runs.',
          notificationChannelName: 'Trip location',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return const LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
  }

  void _onFix(Position p) {
    final at = p.timestamp.toUtc();
    _buffer.add({
      'latitude': p.latitude,
      'longitude': p.longitude,
      if (p.speed >= 0) 'speed_kmph': double.parse((p.speed * 3.6).toStringAsFixed(1)),
      if (p.heading >= 0 && p.heading <= 360) 'heading_deg': p.heading,
      if (p.accuracy > 0) 'accuracy_m': p.accuracy,
      'recorded_at': at.toIso8601String(),
    });
    if (_buffer.length > _maxBuffer) _buffer.removeRange(0, _buffer.length - _maxBuffer);
    state = state.copyWith(
      lastFix: BusFix(
        tripId: state.tripId,
        latitude: p.latitude,
        longitude: p.longitude,
        recordedAt: at,
        speedKmph: p.speed >= 0 ? p.speed * 3.6 : null,
        headingDeg: p.heading,
      ),
      pending: _buffer.length,
    );
  }

  Future<void> _send() async {
    final tripId = state.tripId;
    if (_sending || _buffer.isEmpty || tripId == null) return;
    _sending = true;
    try {
      while (_buffer.isNotEmpty && state.tripId == tripId) {
        final batch = _buffer.take(_maxBatch).toList();
        await ref.read(apiProvider).post<Json>('/trips/$tripId/positions', {'positions': batch});
        _buffer.removeRange(0, batch.length);
        state = state.copyWith(status: ReporterStatus.sharing, lastSentAt: DateTime.now(), pending: _buffer.length);
      }
    } on ApiException catch (e) {
      if (e.status == null) {
        state = state.copyWith(status: ReporterStatus.offline, pending: _buffer.length); // retry next tick
      } else if (e.code == 'bad_trip_state' || e.status == 403 || e.status == 404) {
        stop(); // trip ended or isn't ours any more
      } else {
        _buffer.clear(); // a batch the server rejects won't get better by resending it
        state = state.copyWith(pending: 0);
      }
    } finally {
      _sending = false;
    }
  }

  void _teardown() {
    _fixes?.cancel();
    _fixes = null;
    _timer?.cancel();
    _timer = null;
    _buffer.clear();
  }
}

final positionReporterProvider = NotifierProvider<PositionReporter, ReporterState>(PositionReporter.new);

/// Call from a driver screen's build with the trip it shows (null = the driver has no running
/// trip): starts reporting for a running trip, stops it once that trip is no longer running.
/// Runs after the frame, never during build.
void syncTripReporting(WidgetRef ref, {required int? runningTripId, int? shownTripId}) {
  final current = ref.read(positionReporterProvider).tripId;
  final reporter = ref.read(positionReporterProvider.notifier);
  if (runningTripId != null && current != runningTripId) {
    WidgetsBinding.instance.addPostFrameCallback((_) => reporter.start(runningTripId));
  } else if (runningTripId == null && current != null && (shownTripId == null || shownTripId == current)) {
    WidgetsBinding.instance.addPostFrameCallback((_) => reporter.stop());
  }
}
