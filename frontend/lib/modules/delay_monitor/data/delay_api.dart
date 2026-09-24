import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class DelayActions {
  DelayActions(this._api);

  final ApiClient _api;

  /// Driver/admin tells riders the bus is running late.
  Future<void> report(int tripId, {required int minutes, required String reason}) =>
      _api.post('/trips/$tripId/delay', {'delay_min': minutes, 'reason': reason});
}

final delayActionsProvider = Provider((ref) => DelayActions(ref.read(apiProvider)));
