import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transit/core/api/api_client.dart';
import 'package:transit/core/format.dart';
import 'package:transit/design/design.dart';
import 'package:transit/modules/dashboard/data/dashboard_api.dart';
import 'package:transit/modules/dashboard/screens/student_home_screen.dart';
import 'package:transit/modules/trips/data/trip_models.dart';

import 'support/fakes.dart';

void main() {
  test('number plates are spaced like real plates', () {
    expect(NumberPlate.format('TN09AB1401'), 'TN 09 AB 1401');
    expect(NumberPlate.format('ka01f22'), 'KA 01 F 22');
    expect(NumberPlate.format('BUS-7'), 'BUS-7'); // unknown format left alone
  });

  test('delay labels', () {
    expect(delayLabel(12), '+12 min');
    expect(delayLabel(0), 'On time');
    expect(delayLabel(-1), 'On time');
    expect(delayLabel(-3), '3 min early');
  });

  test('route colours pick readable text', () {
    expect(TransitColors.onRoute(TransitColors.parseHex('#0B5CAD')), TransitColors.white);
    expect(TransitColors.onRoute(TransitColors.parseHex('#FFB81C')), TransitColors.ink);
  });

  test('trip status parses the API spelling', () {
    expect(TripStatus.parse('in_progress'), TripStatus.inProgress);
    expect(TripStatus.parse('completed'), TripStatus.completed);
  });

  test('student home focuses the running trip over later ones', () {
    final dash = StudentDashboard.fromJson(studentDashboardJson());
    expect(StudentHomeScreen.focusTrip(dash.trips)!.tripId, 7);
    expect(dash.myStopId, 3);
    expect(dash.route!.stops.last.stop.name, 'Main Gate (Campus)');
  });

  test('trip JSON maps next stop and delay', () {
    final t = TripDetail.fromJson(tripJson(delay: 8));
    expect(t.running, isTrue);
    expect(t.nextStop!.stopName, 'Koyambedu Market');
    expect(t.headline, 'To Main Gate (Campus)');
  });

  test('API errors keep the backend message and code', () {
    final req = RequestOptions(path: '/boarding/check-in');
    final e = ApiException.fromDio(DioException(
      requestOptions: req,
      response: Response(requestOptions: req, statusCode: 422,
          data: {'detail': 'This QR code has expired.', 'code': 'qr_expired'}),
    ));
    expect(e.code, 'qr_expired');
    expect(e.message, 'This QR code has expired.');

    final v = ApiException.fromDio(DioException(
      requestOptions: req,
      response: Response(requestOptions: req, statusCode: 422, data: {
        'detail': [
          {'loc': ['body', 'email'], 'msg': 'Value error, student profile is required for role=student'}
        ]
      }),
    ));
    expect(v.message, 'student profile is required for role=student');

    final offline = ApiException.fromDio(DioException(requestOptions: req));
    expect(offline.message, contains("Can't reach"));
  });
}
