import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/realtime/realtime.dart';
import '../../../design/design.dart';
import '../data/boarding_api.dart';

/// The QR students scan. Held up at the door: maximum contrast, screen kept awake,
/// code refreshed a few seconds before it expires, live count of who has boarded.
class DriverQrScreen extends ConsumerStatefulWidget {
  const DriverQrScreen({super.key, required this.tripId});

  final int tripId;

  @override
  ConsumerState<DriverQrScreen> createState() => _DriverQrScreenState();
}

class _DriverQrScreenState extends ConsumerState<DriverQrScreen> with SingleTickerProviderStateMixin {
  TripQr? _qr;
  String? _error;
  Timer? _refresh;
  int? _boarded;
  String? _lastName;
  late final AnimationController _countdown = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().catchError((_) {}); // unsupported platform: carry on without it
    _load();
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    _refresh?.cancel();
    _countdown.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final qr = await ref.read(boardingActionsProvider).qr(widget.tripId);
      if (!mounted) return;
      setState(() {
        _qr = qr;
        _error = null;
      });
      // Swap the code ~4s before expiry so a student mid-scan never gets a dead code.
      final life = Duration(seconds: qr.ttlSeconds);
      _countdown
        ..duration = life
        ..forward(from: 0);
      _refresh?.cancel();
      _refresh = Timer(life - const Duration(seconds: 4), _load);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    listenLive(ref, (m) {
      if (m.data['trip_id'] != widget.tripId) return;
      setState(() {
        _boarded = m.data['boarded_count'] as int?;
        _lastName = m.data['student_name'] as String?;
      });
    }, events: {'boarding'});

    final qr = _qr;
    final size = MediaQuery.sizeOf(context);
    final side = (size.shortestSide * 0.82).clamp(200.0, 440.0);

    return Scaffold(
      backgroundColor: TransitColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: TransitColors.board,
              padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.s),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back, color: TransitColors.white),
                    onPressed: () => context.pop(),
                  ),
                  if (qr != null) ...[
                    RouteBadge(code: qr.routeCode, color: TransitColors.parseHex(qr.routeColor), size: 40, rim: true),
                    const SizedBox(width: Space.m),
                    NumberPlate(qr.registration),
                  ],
                  const Spacer(),
                  Text(
                    _boarded == null ? 'Boarding' : '$_boarded on board',
                    style: TransitType.heading.copyWith(color: TransitColors.white),
                  ),
                  const SizedBox(width: Space.s),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: _error != null
                    ? SignNotice(
                        title: "Can't show the code",
                        body: _error!,
                        actionLabel: 'Try again',
                        onAction: _load,
                        edge: TransitColors.late,
                      )
                    : qr == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Scan to board', style: TransitType.title.copyWith(fontSize: 32)),
                          const SizedBox(height: Space.l),
                          Semantics(
                            label: 'Boarding QR code for route ${qr.routeCode}',
                            child: QrImageView(
                              data: qr.token,
                              size: side,
                              backgroundColor: TransitColors.white,
                              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: TransitColors.ink),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: TransitColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.m),
                          SizedBox(
                            width: side,
                            child: AnimatedBuilder(
                              animation: _countdown,
                              builder: (_, _) => LinearProgressIndicator(
                                value: 1 - _countdown.value,
                                minHeight: 6,
                                color: TransitColors.signBlue,
                                backgroundColor: TransitColors.enamelDeep,
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.s),
                          Text(
                            'The code changes every ${qr.ttlSeconds} seconds, so photos of it stop working.',
                            style: TransitType.small.copyWith(color: TransitColors.inkSoft),
                            textAlign: TextAlign.center,
                          ),
                          if (kDebugMode)
                            TextButton(
                              onPressed: () => Clipboard.setData(ClipboardData(text: qr.token)),
                              child: const Text('Copy code (testing without a camera)'),
                            ),
                        ],
                      ),
              ),
            ),
            if (_lastName != null)
              Container(
                width: double.infinity,
                color: TransitColors.go,
                padding: const EdgeInsets.all(Space.l),
                child: Text(
                  '$_lastName boarded',
                  style: TransitType.heading.copyWith(color: TransitColors.white),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
