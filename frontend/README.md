# Transit: Flutter app (web + Android)

One app, three role areas chosen at login:

| Role | Area | Home |
|---|---|---|
| student | `/student` | My line: next bus at my stop, live line diagram, **Scan to board** |
| driver | `/driver` | Today's runs, then the run screen (ARRIVED per stop, boarding QR, riders, running late) |
| admin / security | `/admin` | Live departure board, network, fleet, people, allocation, schedules, reports |
| parent | `/parent` | placeholder (P1) |

## Run
```bash
flutter pub get
flutter run -d chrome                                                  # API at http://localhost:8000
flutter run -d emulator-5554 --dart-define=API_BASE=http://10.0.2.2:8000  # Android emulator
flutter run -d <phone> --dart-define=API_BASE=http://<laptop-ip>:8000     # real phone on same Wi-Fi
```
Demo logins (after `python -m scripts.seed` in `backend/`): `admin@college.edu`,
`driver1@college.edu`, `student1@college.edu`, password `transit123`.

### On a phone
The phone must reach the API on your laptop, so `localhost` won't work. Use the laptop's Wi-Fi IP
(`ipconfig` → "IPv4 Address"), keep both on the **same Wi-Fi**, and start the API on all interfaces:
```bash
cd backend && uvicorn app.main:app --host 0.0.0.0 --port 8000
```
Allow Python through Windows Firewall when prompted (Private networks). Check from the phone's
browser: `http://<laptop-ip>:8000/health` should show `{"status":"ok"}`.

| Option | Command | Notes |
|---|---|---|
| **Android app over USB** (best for demos) | enable Developer options → USB debugging, plug in, then `flutter run --dart-define=API_BASE=http://<laptop-ip>:8000` | QR camera works |
| **Install an APK** | `flutter build apk --release --dart-define=API_BASE=http://<laptop-ip>:8000`, then copy `build/app/outputs/flutter-apk/app-release.apk` to the phone and open it (allow "install unknown apps") | QR camera works; rebuild if your laptop IP changes |
| **Phone browser** (Android or iPhone) | `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define=API_BASE=http://<laptop-ip>:8000`, open `http://<laptop-ip>:8080` on the phone | Browsers only allow the camera on HTTPS, so use the paste-code fallback to board |

`android:usesCleartextTraffic="true"` in `AndroidManifest.xml` allows the plain-http dev API.
Remove it and serve the API over HTTPS for a production release.

**Testing boarding without a camera:** on the driver's QR screen use *Copy code* (debug builds),
then paste it into *No camera? Paste the boarding code* on the student's scan screen.

## Structure
```
lib/
  main.dart, app.dart     app.dart = router + role guards; the only file that knows every screen
  core/                   api client (JWT + refresh), session, realtime (WebSocket), formatting
  design/                 design system (read design/README.md first)
  shell/                  role shells: bottom bars (student/driver), side rail (admin)
  modules/<module>/       mirrors backend/app/modules/<module>/
    data/                 models + Riverpod providers + action classes calling the API
    screens/ widgets/ state/
```
State: Riverpod 3 (`FutureProvider.autoDispose` per read, `*Actions` classes for writes).
Live updates: `listenLive(ref, …)` re-fetches when the server pushes a relevant event.

## Tests
```bash
flutter analyze
flutter test                                                          # unit tests
flutter test test/screenshots_test.dart --run-skipped --update-goldens  # design review PNGs
```
