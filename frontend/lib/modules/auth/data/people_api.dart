import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/session.dart';

class Person {
  const Person({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    this.phone,
    this.rollNo,
    this.department,
    this.licenseNo,
  });

  final int id;
  final String fullName;
  final String email;
  final Role role;
  final bool isActive;
  final String? phone;
  final String? rollNo;
  final String? department;
  final String? licenseNo;

  factory Person.fromJson(Json j) {
    final s = j['student'] as Json?;
    final d = j['driver'] as Json?;
    return Person(
      id: j['id'] as int,
      fullName: j['full_name'] as String,
      email: j['email'] as String,
      role: Role.values.byName(j['role'] as String),
      isActive: j['is_active'] as bool,
      phone: j['phone'] as String?,
      rollNo: s?['roll_no'] as String?,
      department: s?['department'] as String?,
      licenseNo: d?['license_no'] as String?,
    );
  }
}

typedef PeopleQuery = ({Role? role, String q});

final peopleProvider = FutureProvider.autoDispose.family<List<Person>, PeopleQuery>((ref, query) async {
  final rows = await ref
      .read(apiProvider)
      .get('/users', query: {'role': query.role?.name, 'q': query.q.isEmpty ? null : query.q, 'limit': 300});
  return asList(rows).map(Person.fromJson).toList();
});

class PeopleActions {
  PeopleActions(this._api);

  final ApiClient _api;

  Future<void> create(Json body) => _api.post('/users', body);

  Future<void> setActive(int id, bool active) => _api.patch('/users/$id', {'is_active': active});
}

final peopleActionsProvider = Provider((ref) => PeopleActions(ref.read(apiProvider)));
