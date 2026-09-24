import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../config.dart';

enum Role { student, driver, admin, security, parent }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.rollNo,
  });

  final int id;
  final String email;
  final String fullName;
  final Role role;
  final String? phone;
  final String? rollNo;

  String get firstName => fullName.split(' ').first;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] as int,
    email: j['email'] as String,
    fullName: j['full_name'] as String,
    role: Role.values.byName(j['role'] as String),
    phone: j['phone'] as String?,
    rollNo: (j['student'] as Map<String, dynamic>?)?['roll_no'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'role': role.name,
    'phone': phone,
    'student': rollNo == null ? null : {'roll_no': rollNo},
  };
}

class Session {
  const Session({required this.accessToken, required this.refreshToken, required this.user});

  final String accessToken;
  final String refreshToken;
  final AppUser user;

  factory Session.fromTokenPair(Map<String, dynamic> j) => Session(
    accessToken: j['access_token'] as String,
    refreshToken: j['refresh_token'] as String,
    user: AppUser.fromJson(j['user'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {'access_token': accessToken, 'refresh_token': refreshToken, 'user': user.toJson()};
}

const _storeKey = 'transit.session';

/// Holds the signed-in session and persists it (shared_preferences / localStorage on web).
class SessionController extends Notifier<Session?> {
  /// Set by main() from storage before the first frame.
  static Session? restored;

  final _bare = Dio(BaseOptions(baseUrl: AppConfig.apiBase, connectTimeout: const Duration(seconds: 8)));

  @override
  Session? build() => restored;

  static Future<void> restore() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_storeKey);
      if (raw != null) restored = Session.fromTokenPair(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      restored = null; // corrupted or old format: sign in again
    }
  }

  Future<void> _save(Session? s) async {
    final prefs = await SharedPreferences.getInstance();
    if (s == null) {
      await prefs.remove(_storeKey);
    } else {
      await prefs.setString(_storeKey, jsonEncode(s.toJson()));
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final r = await _bare.post('/auth/login', data: {'email': email.trim(), 'password': password});
      final s = Session.fromTokenPair(r.data as Map<String, dynamic>);
      await _save(s);
      state = s;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Returns the new access token, or null if the session can't be renewed.
  Future<String?> refresh() async {
    final current = state;
    if (current == null) return null;
    try {
      final r = await _bare.post('/auth/refresh', data: {'refresh_token': current.refreshToken});
      final s = Session.fromTokenPair(r.data as Map<String, dynamic>);
      await _save(s);
      state = s;
      return s.accessToken;
    } on DioException {
      await logout();
      return null;
    }
  }

  Future<void> logout() async {
    await _save(null);
    state = null;
  }
}

final sessionProvider = NotifierProvider<SessionController, Session?>(SessionController.new);
