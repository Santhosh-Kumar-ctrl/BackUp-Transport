import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config.dart';
import '../../../core/format.dart';
import '../../../design/design.dart';
import '../data/tracking_api.dart';

/// A fix older than this is shown as "last seen" instead of live.
const staleAfter = Duration(seconds: 90);

/// Map of one or more trips: each route drawn as a line through its stops (passed part grey,
/// like the LineDiagram), stops as roundels, the campus as a square, and the bus with its heading.
///
/// Follows the bus until the user pans; "Follow bus" re-centres.
class LiveMap extends StatefulWidget {
  const LiveMap({super.key, required this.trips, this.myStopId, this.localFix, this.height = 260, this.followTripId});

  final List<LiveTrip> trips;

  /// The viewer's stop (students): drawn larger with a "You" tag, and the overlay says how far the bus is.
  final int? myStopId;

  /// The driver's own latest fix, fresher than the server's copy.
  final BusFix? localFix;
  final double height;

  /// Keep this trip's bus in view as it moves. Null = fit everything, don't follow.
  final int? followTripId;

  /// Tests swap in a provider that needs no platform plugins (the default caches tiles on disk).
  @visibleForTesting
  static TileProvider? tileProviderOverride;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  final _map = MapController();
  var _follow = true;
  var _ready = false;
  var _fitted = false;

  BusFix? _fixOf(LiveTrip t) =>
      widget.localFix != null && t.tripId == widget.followTripId ? widget.localFix : t.position;

  LiveTrip? get _followed =>
      widget.followTripId == null ? null : widget.trips.where((t) => t.tripId == widget.followTripId).firstOrNull;

  @override
  void didUpdateWidget(LiveMap old) {
    super.didUpdateWidget(old);
    final t = _followed;
    final fix = t == null ? null : _fixOf(t);
    if (_ready && _fitted && _follow && fix != null) _map.move(fix.point, _map.camera.zoom);
  }

  /// Frame the whole line and the bus. Done here rather than with `initialCameraFit`, which is
  /// skipped when the map first lays out before it has a size (e.g. appearing inside a list).
  void _fitAll([int attempt = 0]) {
    if (!mounted) return;
    final points = _allPoints;
    if (_map.camera.nonRotatedSize.width <= 0 && attempt < 10) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll(attempt + 1));
      return;
    }
    if (points.length > 1) {
      _map.fitCamera(CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(36), maxZoom: 16));
    }
    _fitted = true;
  }

  List<LatLng> get _allPoints => [
    for (final t in widget.trips) ...[...t.stops.map((s) => s.point).nonNulls, if (_fixOf(t) != null) _fixOf(t)!.point],
  ];

  void _recentre() {
    setState(() => _follow = true);
    final t = _followed;
    final fix = t == null ? null : _fixOf(t);
    if (fix != null) {
      _map.move(fix.point, math.max(_map.camera.zoom, 14));
    } else if (_allPoints.length > 1) {
      _map.fitCamera(CameraFit.coordinates(coordinates: _allPoints, padding: const EdgeInsets.all(36)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _allPoints;
    if (points.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const SignNotice(
          title: 'No map for this route yet',
          body: "Its stops have no location set. The transport office can add them; until then use the line below.",
        ),
      );
    }
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: Radii.signAll,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: points.first,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onMapReady: () {
                  _ready = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
                },
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture && _follow) setState(() => _follow = false);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: AppConfig.tileUrl,
                  userAgentPackageName: 'edu.college.transit',
                  tileProvider: LiveMap.tileProviderOverride,
                ),
                PolylineLayer(polylines: [for (final t in widget.trips) ..._lines(t)]),
                MarkerLayer(
                  markers: [
                    for (final t in widget.trips) ..._stopMarkers(t),
                    for (final t in widget.trips)
                      if (_fixOf(t) case final fix?) _busMarker(t, fix),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    color: TransitColors.white.withValues(alpha: 0.85),
                    padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: 1),
                    child: Text(AppConfig.tileAttribution, style: TransitType.small.copyWith(fontSize: 11)),
                  ),
                ),
              ],
            ),
            Positioned(
              left: Space.s,
              top: Space.s,
              right: 64,
              child: _Overlay(map: widget, fixOf: _fixOf),
            ),
            if (widget.followTripId != null && !_follow)
              Positioned(
                right: Space.s,
                top: Space.s,
                child: SignButton(label: 'Follow bus', icon: Icons.my_location, height: 36, onPressed: _recentre),
              ),
          ],
        ),
      ),
    );
  }

  List<Polyline> _lines(LiveTrip t) {
    final lastReached = t.stops.lastWhere((s) => s.arrivedAt != null, orElse: () => t.stops.first);
    final done = [
      for (final s in t.stops)
        if (s.sequence <= lastReached.sequence) s.point,
    ].nonNulls.toList();
    final ahead = [
      for (final s in t.stops)
        if (s.sequence >= lastReached.sequence) s.point,
    ].nonNulls.toList();
    final fix = _fixOf(t);
    return [
      if (done.length > 1) Polyline(points: done, strokeWidth: 5, color: TransitColors.rule),
      if (ahead.length > 1)
        Polyline(
          points: t.running && fix != null ? [fix.point, ...ahead.skip(1)] : ahead,
          strokeWidth: 5,
          color: t.route.color,
        ),
    ];
  }

  List<Marker> _stopMarkers(LiveTrip t) => [
    for (final s in t.stops)
      if (s.point case final p?)
        Marker(
          point: p,
          width: s.stopId == widget.myStopId ? 64 : 22,
          height: s.stopId == widget.myStopId ? 44 : 22,
          child: _StopMark(
            color: t.route.color,
            reached: s.arrivedAt != null,
            terminus: t.direction == 'drop' ? s == t.stops.first : s == t.stops.last, // the campus
            isYou: s.stopId == widget.myStopId,
            name: s.name,
          ),
        ),
  ];

  Marker _busMarker(LiveTrip t, BusFix fix) => Marker(
    point: fix.point,
    width: 40,
    height: 40,
    child: Semantics(
      label: 'Bus ${t.busRegistration}, route ${t.route.code}',
      child: _BusMark(heading: fix.headingDeg, stale: DateTime.now().difference(fix.recordedAt) > staleAfter),
    ),
  );
}

class _StopMark extends StatelessWidget {
  const _StopMark({
    required this.color,
    required this.reached,
    required this.terminus,
    required this.isYou,
    required this.name,
  });

  final Color color;
  final bool reached;
  final bool terminus;
  final bool isYou;
  final String name;

  @override
  Widget build(BuildContext context) {
    final ring = reached ? TransitColors.rule : color;
    final size = isYou ? 22.0 : 16.0;
    final node = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isYou ? ring : TransitColors.white,
        border: Border.all(color: isYou ? TransitColors.white : ring, width: isYou ? 3 : 4),
        shape: terminus ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: terminus ? Radii.signAll : null,
      ),
    );
    return Tooltip(
      message: name,
      child: isYou
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: color, borderRadius: Radii.signAll),
                  child: Text(
                    'You',
                    style: TransitType.small.copyWith(color: TransitColors.onRoute(color), fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 2),
                node,
              ],
            )
          : Center(child: node),
    );
  }
}

class _BusMark extends StatelessWidget {
  const _BusMark({required this.heading, required this.stale});

  final double? heading;
  final bool stale;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: stale ? TransitColors.inkSoft : TransitColors.ink,
      borderRadius: Radii.signAll,
      border: Border.all(color: TransitColors.white, width: 2),
    ),
    child: heading == null
        ? const Icon(Icons.directions_bus, color: TransitColors.led, size: 22)
        : Transform.rotate(
            angle: heading! * math.pi / 180,
            child: const Icon(Icons.navigation, color: TransitColors.led, size: 22),
          ),
  );
}

/// Top-left plate: is the position live, stale or missing, and (for a student) how far away.
class _Overlay extends StatelessWidget {
  const _Overlay({required this.map, required this.fixOf});

  final LiveMap map;
  final BusFix? Function(LiveTrip) fixOf;

  @override
  Widget build(BuildContext context) {
    if (map.trips.length != 1) return const SizedBox.shrink();
    final t = map.trips.single;
    if (!t.running) return const SizedBox.shrink();
    final fix = fixOf(t);
    if (fix == null) return const StatusPlate('Waiting for the bus location', tone: Tone.neutral);
    final age = DateTime.now().difference(fix.recordedAt);
    final mine = t.stops.where((s) => s.stopId == map.myStopId).firstOrNull;
    final away = mine?.point == null || mine!.arrivedAt != null
        ? null
        : const Distance().as(LengthUnit.Meter, fix.point, mine.point!);
    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        age > staleAfter
            ? StatusPlate('Last seen ${relative(fix.recordedAt)}', tone: Tone.caution)
            : const StatusPlate('Live', tone: Tone.go),
        if (away != null) StatusPlate('${distanceLabel(away)} from your stop', tone: Tone.info),
      ],
    );
  }
}

/// "850 m", "1.8 km", "12 km"
String distanceLabel(double metres) {
  if (metres < 1000) return '${(metres / 50).round() * 50} m';
  if (metres < 10000) return '${(metres / 1000).toStringAsFixed(1)} km';
  return '${(metres / 1000).round()} km';
}
