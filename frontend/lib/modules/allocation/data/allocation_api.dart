import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class Allocation {
  const Allocation({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.routeId,
    required this.stopId,
    required this.stopName,
    this.rollNo,
  });

  final int id;
  final int studentId;
  final String studentName;
  final String? rollNo;
  final int routeId;
  final int stopId;
  final String stopName;

  factory Allocation.fromJson(Json j) {
    final s = j['student'] as Json;
    return Allocation(
      id: j['id'] as int,
      studentId: s['id'] as int,
      studentName: s['full_name'] as String,
      rollNo: s['roll_no'] as String?,
      routeId: (j['route'] as Json)['id'] as int,
      stopId: (j['stop'] as Json)['id'] as int,
      stopName: (j['stop'] as Json)['name'] as String,
    );
  }
}

final routeAllocationsProvider = FutureProvider.autoDispose.family<List<Allocation>, int>((ref, routeId) async {
  return asList(await ref.read(apiProvider).get('/allocations', query: {'route_id': routeId}))
      .map(Allocation.fromJson)
      .toList();
});

/// Result of an assignment. `warnings` is non-empty when an admin override was used
/// or capacity is unknown.
typedef AssignOutcome = ({bool changed, List<String> warnings});

class AllocationActions {
  AllocationActions(this._api);

  final ApiClient _api;

  Future<AssignOutcome> assign({
    required int studentId,
    required int routeId,
    required int stopId,
    bool force = false,
  }) async {
    final r = await _api.post<Json>('/allocations', {
      'student_id': studentId,
      'route_id': routeId,
      'stop_id': stopId,
      'force': force,
    });
    return (changed: r['changed'] as bool, warnings: (r['warnings'] as List).cast<String>());
  }

  Future<void> unassign(int studentId) => _api.delete('/allocations/students/$studentId');
}

final allocationActionsProvider = Provider((ref) => AllocationActions(ref.read(apiProvider)));
