import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryPreferences implements SharedPreferencesAsync {
  final Map<String, String> data = {};
  final failWrites = ValueNotifier(false);

  @override
  Future<String?> getString(String key) async => data[key];

  @override
  Future<void> setString(String key, String value) async {
    if (failWrites.value) throw StateError('Simulated storage failure');
    data[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unused preferences method');
}
