import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recipient.dart';
import 'cloud_wallet.dart';

abstract interface class CloudRecipientGateway {
  Future<List<Recipient>> load(String accountId);
  Future<void> save(String accountId, Recipient value, {String? originalPhone});
  Future<void> remove(String accountId, String phone);
}

class RecipientStore extends ChangeNotifier {
  RecipientStore({SharedPreferencesAsync? preferences})
    : _provided = preferences;
  static const _storageKey = 'kina_wallet_recipients_v1';
  final SharedPreferencesAsync? _provided;
  late final _preferences = _provided ?? SharedPreferencesAsync();
  final List<Recipient> _recipients = [];
  List<Recipient> _local = [];
  CloudRecipientGateway? _cloud;
  String? _accountId;
  int _epoch = 0;
  bool _ready = false;
  bool _loading = false;
  String? _error;
  final _writes = <String>{};
  String get _scope => _accountId ?? 'local';
  bool get saving => _writes.contains(_scope);
  bool get loading => _loading;
  bool get isCloud => _accountId != null;
  String? get error => _error;
  List<Recipient> get recipients => List.unmodifiable(_recipients);

  Future<void> initialize() async {
    if (_ready) return;
    final saved = await _preferences.getString(_storageKey);
    if (saved != null) {
      final data = jsonDecode(saved) as List;
      _local = data
          .map(
            (item) =>
                Recipient.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    }
    _recipients
      ..clear()
      ..addAll(_local);
    _ready = true;
    notifyListeners();
  }

  void configureCloud(CloudRecipientGateway gateway) {
    _cloud = gateway;
  }

  Future<void> useAccount(String? id) async {
    if (id == _accountId) return;
    _epoch++;
    _accountId = id;
    _ready = id == null;
    _error = null;
    _loading = false;
    _recipients
      ..clear()
      ..addAll(id == null ? _local : []);
    notifyListeners();
    if (id != null) await refresh();
  }

  Future<void> refresh() async {
    final id = _accountId;
    if (id == null || _cloud == null || _loading || saving) return;
    final epoch = _epoch;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final values = await _cloud!.load(id);
      if (epoch != _epoch) return;
      _recipients
        ..clear()
        ..addAll(values);
      _ready = true;
    } catch (_) {
      if (epoch == _epoch) {
        _ready = false;
        _error =
            'Could not load cloud recipients. Connect and refresh to retry.';
      }
    } finally {
      if (epoch == _epoch) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  String? _validation(String name, String phone) {
    if (name.trim().isEmpty || name.trim().length > 80) {
      return 'Use a recipient name with 1–80 characters.';
    }
    if (!RegExp(r'^\d{8}$').hasMatch(phone.trim())) {
      return 'Enter an 8-digit PNG mobile number.';
    }
    return null;
  }

  Future<String?> _mutate(
    List<Recipient> updated,
    Future<void> Function(String id) cloudAction,
  ) async {
    if (!_ready || _loading) {
      return 'Saved recipients are not ready. Refresh and retry.';
    }
    if (saving) return 'A recipient update is already being saved.';
    final epoch = _epoch;
    final id = _accountId;
    final scope = _scope;
    _writes.add(scope);
    _error = null;
    notifyListeners();
    try {
      if (id == null) {
        await _preferences.setString(
          _storageKey,
          jsonEncode(updated.map((r) => r.toJson()).toList()),
        );
        _local = List.of(updated);
        if (_accountId == null) {
          _recipients
            ..clear()
            ..addAll(updated);
        }
      } else {
        await cloudAction(id);
        final values = await _cloud!.load(id);
        if (epoch == _epoch) {
          _recipients
            ..clear()
            ..addAll(values);
        }
      }
      if (epoch != _epoch) {
        return 'The active account changed. Reopen saved recipients.';
      }
      notifyListeners();
      return null;
    } catch (_) {
      if (epoch == _epoch) _error = 'Could not confirm the recipient update. Refresh the list before retrying.';
      return 'Could not confirm the recipient update. Refresh the list before retrying.';
    } finally {
      _writes.remove(scope);
      if (_scope == scope) {
        notifyListeners();
        if (epoch != _epoch && isCloud) unawaited(refresh());
      }
    }
  }

  Future<String?> addRecipient({
    required String name,
    required String phoneNumber,
    String? receivingAccountId,
  }) async {
    if (receivingAccountId != null &&
        receivingAccountId.trim().isNotEmpty &&
        !isReceivingCode(receivingAccountId.trim())) {
      return 'Enter a valid receiving account code.';
    }
    final error = _validation(name, phoneNumber);
    if (error != null) return error;
    final value = Recipient(
      name: name.trim(),
      phoneNumber: phoneNumber.trim(),
      accountId: receivingAccountId == null || receivingAccountId.trim().isEmpty
          ? null
          : receivingAccountId.trim().toLowerCase(),
    );
    if (_recipients.any((r) => r.phoneNumber == value.phoneNumber)) {
      return 'This mobile number is already saved.';
    }
    return _mutate([..._recipients, value], (id) => _cloud!.save(id, value));
  }

  Future<String?> updateRecipient({
    required String originalPhoneNumber,
    required String name,
    required String phoneNumber,
    String? receivingAccountId,
  }) async {
    if (receivingAccountId != null &&
        receivingAccountId.trim().isNotEmpty &&
        !isReceivingCode(receivingAccountId.trim())) {
      return 'Enter a valid receiving account code.';
    }
    final error = _validation(name, phoneNumber);
    if (error != null) return error;
    final value = Recipient(
      name: name.trim(),
      phoneNumber: phoneNumber.trim(),
      accountId: receivingAccountId == null || receivingAccountId.trim().isEmpty
          ? null
          : receivingAccountId.trim().toLowerCase(),
    );
    final index = _recipients.indexWhere(
      (r) => r.phoneNumber == originalPhoneNumber,
    );
    if (index < 0) return 'This recipient could not be found.';
    if (_recipients.any(
      (r) =>
          r.phoneNumber == value.phoneNumber &&
          r.phoneNumber != originalPhoneNumber,
    )) {
      return 'This mobile number is already saved.';
    }
    final updated = List<Recipient>.of(_recipients)..[index] = value;
    return _mutate(
      updated,
      (id) => _cloud!.save(id, value, originalPhone: originalPhoneNumber),
    );
  }

  Future<String?> removeRecipient({required String phoneNumber}) async {
    if (!_recipients.any((r) => r.phoneNumber == phoneNumber)) {
      return 'This recipient could not be found.';
    }
    return _mutate(
      _recipients.where((r) => r.phoneNumber != phoneNumber).toList(),
      (id) => _cloud!.remove(id, phoneNumber),
    );
  }
}

final recipientStore = RecipientStore();
