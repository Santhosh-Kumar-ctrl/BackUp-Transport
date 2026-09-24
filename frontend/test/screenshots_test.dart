/// Renders key screens with realistic fake data into PNGs for design review.
///
///   flutter test test/screenshots_test.dart --update-goldens
///
/// Output: test/screenshots/*.png. Tagged `screenshot` and skipped by a plain
/// `flutter test` (font rendering differs between machines, so these are
/// review images, not pass/fail assertions).
@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transit/core/auth/session.dart';
import 'package:transit/core/realtime/realtime.dart';
import 'package:transit/design/design.dart';
import 'package:transit/modules/auth/screens/login_screen.dart';
import 'package:transit/modules/boarding/data/boarding_api.dart';
import 'package:transit/modules/boarding/screens/driver_qr_screen.dart';
import 'package:transit/modules/dashboard/data/dashboard_api.dart';
import 'package:transit/modules/dashboard/screens/admin_board_screen.dart';
import 'package:transit/modules/dashboard/screens/student_home_screen.dart';
import 'package:transit/modules/notifications/data/notifications_api.dart';
import 'package:transit/modules/trips/data/trip_models.dart';
import 'package:transit/modules/trips/data/trips_api.dart';
import 'package:transit/modules/trips/screens/driver_run_screen.dart';
import 'package:transit/shell/role_shells.dart';

import 'support/fakes.dart';

class _FakeBoarding implements BoardingActions {
  @override
  Future<TripQr> qr(int tripId) async => TripQr.fromJson({
    'token': 'eyJhbGciOiJIUzI1NiJ9.eyJ0eXAiOiJib2FyZCIsInRyaXAiOjcsIm4iOiJhYmMxMjMifQ.demo-signature-for-screenshot',
    'trip_id': 7,
    'issued_at': at(0),
    'expires_at': at(1),
    'ttl_seconds': 30,
    'route_code': '14',
    'route_color': '#0B5CAD',
    'bus_registration_no': 'TN09AB1401',
  });

  @override
  Future<BoardingReceipt> checkIn(String token) => throw UnimplementedError();

  @override
  Future<BoardingReceipt> manual(int tripId, {int? studentId, String? rollNo}) => throw UnimplementedError();
}

Session _session(Role role, String name) => Session(
  accessToken: 'x',
  refreshToken: 'y',
  user: AppUser(id: 1, email: 'demo@college.edu', fullName: name, role: role),
);

Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget screen, {
  Size size = const Size(390, 844),
  List overrides = const [],
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        unreadCountProvider.overrideWith((ref) async => 2),
        realtimeProvider.overrideWithValue(null), // no sockets in tests
        ...overrides.cast(),
      ],
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTransitTheme(), home: screen),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 1));
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/$name.png'));
  await tester.pumpWidget(const SizedBox.shrink()); // dispose timers
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('login', (t) async {
    SessionController.restored = null;
    await _shoot(t, 'login', const LoginScreen());
  });

  testWidgets('student home', (t) async {
    SessionController.restored = _session(Role.student, 'Manoj K');
    await _shoot(
      t,
      'student_home',
      const StudentShell(location: '/student', child: StudentHomeScreen()),
      size: const Size(390, 1300),
      overrides: [
        studentDashboardProvider.overrideWith((ref) async => StudentDashboard.fromJson(studentDashboardJson())),
        tripProvider(7).overrideWith((ref) async => TripDetail.fromJson(tripJson())),
      ],
    );
  });

  testWidgets('driver run', (t) async {
    SessionController.restored = _session(Role.driver, 'Murugan K');
    await _shoot(
      t,
      'driver_run',
      const DriverRunScreen(tripId: 7),
      size: const Size(390, 1000),
      overrides: [
        tripProvider(7).overrideWith((ref) async => TripDetail.fromJson(tripJson())),
        rosterProvider(7).overrideWith(
          (ref) async =>
              Roster.fromJson({'trip_id': 7, 'capacity': 40, 'allocated_count': 10, 'boarded_count': 4, 'entries': []}),
        ),
      ],
    );
  });

  testWidgets('driver qr', (t) async {
    SessionController.restored = _session(Role.driver, 'Murugan K');
    await _shoot(
      t,
      'driver_qr',
      const DriverQrScreen(tripId: 7),
      overrides: [boardingActionsProvider.overrideWithValue(_FakeBoarding())],
    );
  });

  testWidgets('boarded ticket', (t) async {
    await _shoot(
      t,
      'ticket',
      const Scaffold(
        backgroundColor: TransitColors.board,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: TicketStub(
              routeCode: '14',
              routeColor: Color(0xFF0B5CAD),
              routeName: 'North Loop',
              registration: 'TN09AB1401',
              time: '07:42',
              stopName: 'Koyambedu Market',
              message: 'Boarded route 14. Have a good ride.',
            ),
          ),
        ),
      ),
    );
  });

  testWidgets('admin board', (t) async {
    SessionController.restored = _session(Role.admin, 'Transport Office');
    await _shoot(
      t,
      'admin_board',
      const AdminShell(location: '/admin', child: AdminBoardScreen()),
      size: const Size(1440, 900),
      overrides: [adminDashboardProvider.overrideWith((ref) async => AdminDashboard.fromJson(adminDashboardJson()))],
    );
  });

  testWidgets('admin board, phone', (t) async {
    SessionController.restored = _session(Role.admin, 'Transport Office');
    await _shoot(
      t,
      'admin_board_phone',
      const AdminShell(location: '/admin', child: AdminBoardScreen()),
      size: const Size(390, 1100),
      overrides: [adminDashboardProvider.overrideWith((ref) async => AdminDashboard.fromJson(adminDashboardJson()))],
    );
  });
}
