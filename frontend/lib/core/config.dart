/// Build-time configuration.
///
/// ```
/// flutter run -d chrome                                           # API on localhost:8000
/// flutter run -d emulator-5554 --dart-define=API_BASE=http://10.0.2.2:8000
/// flutter run -d <phone> --dart-define=API_BASE=http://<laptop-LAN-IP>:8000
/// ```
abstract final class AppConfig {
  static const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8000');

  static String get wsBase => apiBase.replaceFirst(RegExp(r'^http'), 'ws');
}
