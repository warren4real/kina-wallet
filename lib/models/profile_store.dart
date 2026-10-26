import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recipient.dart';

class ProfileStore extends ChangeNotifier {
  ProfileStore({SharedPreferencesAsync? preferences}) : _provided = preferences;
  static const _key = 'kina_wallet_demo_profile_v1';
  final SharedPreferencesAsync? _provided;
  late final _preferences = _provided ?? SharedPreferencesAsync();
  Recipient _profile = const Recipient(
    name: 'Warrens Demo account',
    phoneNumber: '70000001',
  );
  bool _ready = false;
  bool _saving = false;
  Recipient get profile => _profile;

  static String? validate(String name, String phone) {
    if (name.trim().isEmpty || name.trim().length > 80) {
      return 'Enter a name with 1–80 characters.';
    }
    if (!RegExp(r'^\d{8}$').hasMatch(phone.trim())) {
      return 'Enter an 8-digit PNG mobile number.';
    }
    return null;
  }

  Future<void> initialize() async {
    if (_ready) return;
    final saved = await _preferences.getString(_key);
    if (saved != null) {
      final profile = Recipient.fromJson(
        jsonDecode(saved) as Map<String, dynamic>,
      );
      if (validate(profile.name, profile.phoneNumber) != null) {
        throw const FormatException('Invalid saved demo profile');
      }
      _profile = profile;
    }
    _ready = true;
    notifyListeners();
  }

  Future<String?> update({
    required String name,
    required String phoneNumber,
  }) async {
    if (!_ready) return 'Profile is loading. Restart the app and try again.';
    if (_saving) return 'Profile is already being saved.';
    final error = validate(name, phoneNumber);
    if (error != null) return error;
    _saving = true;
    try {
      final updated = Recipient(
        name: name.trim(),
        phoneNumber: phoneNumber.trim(),
      );
      await _preferences.setString(_key, jsonEncode(updated.toJson()));
      _profile = updated;
      notifyListeners();
      return null;
    } catch (_) {
      return 'Could not save your demo profile. Try again.';
    } finally {
      _saving = false;
    }
  }
}

final profileStore = ProfileStore();
