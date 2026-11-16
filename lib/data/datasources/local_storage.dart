import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/transfer_task.dart';

class LocalStorage {
  final SharedPreferences prefs;
  LocalStorage(this.prefs);

  static const _tokenKey = 'auth_token';
  static const _usernameKey = 'auth_username';
  static const _tasksKey = 'transfer_tasks_v1';
  static const _maxStoredTasks = 50;

  String? get token => prefs.getString(_tokenKey);
  String? get username => prefs.getString(_usernameKey);

  Future<void> saveSession(String token, String username) async {
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_usernameKey, username);
  }

  Future<void> clearSession() async {
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
  }

  List<TransferTask> loadTasks() {
    final raw = prefs.getString(_tasksKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => TransferTask.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      developer.log('Corrupt transfer history, resetting: $e');
      return const [];
    }
  }

  Future<void> saveTasks(List<TransferTask> tasks) async {
    final trimmed = tasks.take(_maxStoredTasks).map((t) => t.toJson()).toList();
    await prefs.setString(_tasksKey, jsonEncode(trimmed));
  }
}
