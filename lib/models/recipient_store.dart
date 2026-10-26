import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recipient.dart';

class RecipientStore extends ChangeNotifier {
  static const _storageKey = 'kina_wallet_recipients_v1';

  late final _preferences = SharedPreferencesAsync();
  final List<Recipient> _recipients = [];

  bool _ready = false;
  bool _saving = false;

  List<Recipient> get recipients => List.unmodifiable(_recipients);

  Future<void> initialize() async {
    if (_ready) return;

    final saved = await _preferences.getString(_storageKey);

    if (saved != null) {
      final data = jsonDecode(saved) as List<dynamic>;

      final loaded = data.map((item) {
        return Recipient.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();

      _recipients
        ..clear()
        ..addAll(loaded);
    }

    _ready = true;
    notifyListeners();
  }

  Future<String?> updateRecipient({
    required String originalPhoneNumber,
    required String name,
    required String phoneNumber,
  }) async {
    if (!_ready) {
      return 'Saved recipients are not ready yet.';
    }

    if (_saving) {
      return 'A recipient update is already being saved.';
    }

    final cleanName = name.trim();
    final cleanPhone = phoneNumber.trim();

    if (cleanName.isEmpty) {
      return 'Enter the recipient’s name.';
    }

    if (!RegExp(r'^\d{8}$').hasMatch(cleanPhone)) {
      return 'Enter an 8-digit PNG mobile number.';
    }

    final index = _recipients.indexWhere(
      (recipient) => recipient.phoneNumber == originalPhoneNumber,
    );

    if (index == -1) {
      return 'This recipient could not be found.';
    }

    final duplicate = _recipients.any(
      (recipient) =>
          recipient.phoneNumber == cleanPhone &&
          recipient.phoneNumber != originalPhoneNumber,
    );

    if (duplicate) {
      return 'This mobile number is already saved.';
    }

    _saving = true;

    try {
      final updated = List<Recipient>.of(_recipients);

      updated[index] = Recipient(name: cleanName, phoneNumber: cleanPhone);

      await _preferences.setString(
        _storageKey,
        jsonEncode(updated.map((recipient) => recipient.toJson()).toList()),
      );

      _recipients
        ..clear()
        ..addAll(updated);

      notifyListeners();
      return null;
    } catch (_) {
      return 'Could not update the recipient. Please try again.';
    } finally {
      _saving = false;
    }
  }

  Future<String?> removeRecipient({required String phoneNumber}) async {
    if (!_ready) {
      return 'Saved recipients are not ready yet.';
    }

    if (_saving) {
      return 'A recipient update is already being saved.';
    }

    if (!_recipients.any((recipient) => recipient.phoneNumber == phoneNumber)) {
      return 'This recipient could not be found.';
    }

    _saving = true;

    try {
      final updated = _recipients
          .where((recipient) => recipient.phoneNumber != phoneNumber)
          .toList();

      await _preferences.setString(
        _storageKey,
        jsonEncode(updated.map((recipient) => recipient.toJson()).toList()),
      );

      _recipients
        ..clear()
        ..addAll(updated);

      notifyListeners();
      return null;
    } catch (_) {
      return 'Could not remove the recipient. Please try again.';
    } finally {
      _saving = false;
    }
  }

  Future<String?> addRecipient({
    required String name,
    required String phoneNumber,
  }) async {
    if (!_ready) {
      return 'Saved recipients are not ready yet.';
    }

    if (_saving) {
      return 'A recipient is already being saved. Please wait.';
    }

    final cleanName = name.trim();
    final cleanPhone = phoneNumber.trim();

    if (cleanName.isEmpty) {
      return 'Enter the recipient’s name.';
    }

    if (!RegExp(r'^\d{8}$').hasMatch(cleanPhone)) {
      return 'Enter an 8-digit PNG mobile number.';
    }

    if (_recipients.any((recipient) => recipient.phoneNumber == cleanPhone)) {
      return 'This mobile number is already saved.';
    }

    _saving = true;

    try {
      final updated = [
        ..._recipients,
        Recipient(name: cleanName, phoneNumber: cleanPhone),
      ];

      await _preferences.setString(
        _storageKey,
        jsonEncode(updated.map((recipient) => recipient.toJson()).toList()),
      );

      _recipients
        ..clear()
        ..addAll(updated);

      notifyListeners();
      return null;
    } catch (_) {
      return 'Could not save the recipient. Please try again.';
    } finally {
      _saving = false;
    }
  }
}

final recipientStore = RecipientStore();
