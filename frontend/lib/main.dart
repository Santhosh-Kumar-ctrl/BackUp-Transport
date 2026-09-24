import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/auth/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionController.restore();
  runApp(const ProviderScope(child: TransitApp()));
}
