import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_backup.dart';
import 'demo_transaction.dart';

class WalletStore extends ChangeNotifier {
  static const _storageKey = 'kina_wallet_demo_v1';

  WalletStore({SharedPreferencesAsync? preferences})
    : _providedPreferences = preferences;

  final SharedPreferencesAsync? _providedPreferences;
  late final SharedPreferencesAsync _preferences =
      _providedPreferences ?? SharedPreferencesAsync();

  int _balanceToea = demoBalanceToea;
  final List<DemoTransaction> _transactions = List.of(demoTransactions);

  bool _ready = false;
  bool _saving = false;

  int get balanceToea => _balanceToea;

  List<DemoTransaction> get transactions => List.unmodifiable(_transactions);

  String get formattedBalance => 'K ${(_balanceToea / 100).toStringAsFixed(2)}';

  String exportDemoSnapshot() {
    return jsonEncode({
      'balanceToea': _balanceToea,
      'transactions': _transactions
          .map((transaction) => transaction.toJson())
          .toList(),
    });
  }

  Future<void> initialize() async {
    if (_ready) return;

    final saved = await _preferences.getString(_storageKey);

    // Use our captured session only when no saved wallet exists.
    final data = jsonDecode(saved ?? demoBackupJson) as Map<String, dynamic>;

    final balance = data['balanceToea'];
    final transactionData = data['transactions'];

    if (balance is! int || balance < 0 || transactionData is! List) {
      throw const FormatException('Invalid saved demo wallet');
    }

    final loadedTransactions = transactionData.map((item) {
      return DemoTransaction.fromJson(Map<String, dynamic>.from(item as Map));
    }).toList();

    if (saved == null) {
      await _preferences.setString(_storageKey, jsonEncode(data));
    }

    _balanceToea = balance;
    _transactions
      ..clear()
      ..addAll(loadedTransactions);

    _ready = true;
    notifyListeners();
  }

  // Save the balance and history together before updating the screen.
  Future<String?> _recordTransaction({
    required int newBalanceToea,
    required DemoTransaction transaction,
  }) async {
    if (!_ready) {
      return 'The demo wallet is not ready yet.';
    }

    if (_saving) {
      return 'A demo update is already being saved. Please wait.';
    }

    _saving = true;

    try {
      final now = DateTime.now().toUtc();
      final randomPart = Random.secure()
          .nextInt(0x100000000)
          .toRadixString(16)
          .padLeft(8, '0')
          .toUpperCase();
      final recorded = DemoTransaction(
        transaction.title,
        transaction.detail,
        transaction.amountToea,
        transaction.icon,
        createdAt: now,
        reference: 'DEMO-${now.microsecondsSinceEpoch}-$randomPart',
      );
      final updatedTransactions = [recorded, ..._transactions];

      final snapshot = jsonEncode({
        'balanceToea': newBalanceToea,
        'transactions': updatedTransactions
            .map((item) => item.toJson())
            .toList(),
      });

      await _preferences.setString(_storageKey, snapshot);

      _balanceToea = newBalanceToea;
      _transactions
        ..clear()
        ..addAll(updatedTransactions);

      notifyListeners();
      return null;
    } catch (_) {
      return 'Could not save the demo payment. '
          'Your balance was not changed. Try again.';
    } finally {
      _saving = false;
    }
  }

  Future<String?> addDemoMoney({required int amountToea}) async {
    if (amountToea <= 0) {
      return 'Enter an amount greater than zero.';
    }

    return _recordTransaction(
      newBalanceToea: _balanceToea + amountToea,
      transaction: DemoTransaction(
        'Demo money added',
        'Sample funding · No real deposit',
        amountToea,
        Icons.south_west,
      ),
    );
  }

  Future<String?> payDemoRent({
    required String landlordName,
    required String phoneNumber,
    required String rentReference,
    required int amountToea,
  }) async {
    final landlord = landlordName.trim();
    final phone = phoneNumber.trim();
    final reference = rentReference.trim();

    if (landlord.isEmpty) {
      return 'Enter the landlord’s name.';
    }

    if (!RegExp(r'^\d{8}$').hasMatch(phone)) {
      return 'Enter an 8-digit PNG mobile number.';
    }

    if (reference.isEmpty) {
      return 'Enter a rent reference.';
    }

    if (amountToea <= 0) {
      return 'Enter an amount greater than zero.';
    }

    if (amountToea > _balanceToea) {
      return 'Not enough demo balance for this rent payment.';
    }

    return _recordTransaction(
      newBalanceToea: _balanceToea - amountToea,
      transaction: DemoTransaction(
        'Rent demo payment to $landlord',
        '$reference · +675 $phone · No rent actually paid',
        -amountToea,
        Icons.home_work_outlined,
      ),
    );
  }

  Future<String?> payDemoMobileTopUp({
    required String phoneNumber,
    required int amountToea,
  }) async {
    final phone = phoneNumber.trim();

    // Basic demo format check; no mobile provider is connected.
    if (!RegExp(r'^\d{8}$').hasMatch(phone)) {
      return 'Enter an 8-digit PNG mobile number.';
    }

    if (amountToea <= 0) {
      return 'Enter an amount greater than zero.';
    }

    if (amountToea > _balanceToea) {
      return 'Not enough demo balance for this top-up.';
    }

    return _recordTransaction(
      newBalanceToea: _balanceToea - amountToea,
      transaction: DemoTransaction(
        'Mobile top-up demo payment',
        'Mobile: +675 $phone · No credit delivered',
        -amountToea,
        Icons.phone_android,
      ),
    );
  }

  Future<String?> payDemoWater({
    required String customerNumber,
    required int amountToea,
  }) async {
    final customer = customerNumber.trim();

    if (customer.isEmpty) {
      return 'Enter a customer number.';
    }

    if (amountToea <= 0) {
      return 'Enter an amount greater than zero.';
    }

    if (amountToea > _balanceToea) {
      return 'Not enough demo balance for this payment.';
    }

    return _recordTransaction(
      newBalanceToea: _balanceToea - amountToea,
      transaction: DemoTransaction(
        'Water demo payment',
        'Customer: $customer · No bill paid',
        -amountToea,
        Icons.water_drop_outlined,
      ),
    );
  }

  Future<String?> payDemoElectricity({
    required String meterNumber,
    required int amountToea,
  }) async {
    final meter = meterNumber.trim();

    if (meter.isEmpty) {
      return 'Enter a meter number.';
    }

    if (amountToea <= 0) {
      return 'Enter an amount greater than zero.';
    }

    if (amountToea > _balanceToea) {
      return 'Not enough demo balance for this payment.';
    }

    return _recordTransaction(
      newBalanceToea: _balanceToea - amountToea,
      transaction: DemoTransaction(
        'Electricity demo payment',
        'Meter: $meter · No electricity purchased',
        -amountToea,
        Icons.bolt,
      ),
    );
  }

  Future<String?> sendDemoMoney({
    required String recipientName,
    required String phoneNumber,
    required int amountToea,
  }) async {
    if (amountToea <= 0) {
      return 'Enter an amount greater than zero.';
    }

    if (amountToea > _balanceToea) {
      return 'Not enough demo balance for this transfer.';
    }

    return _recordTransaction(
      newBalanceToea: _balanceToea - amountToea,
      transaction: DemoTransaction(
        'Sent to $recipientName',
        'Demo transfer · +675 $phoneNumber',
        -amountToea,
        Icons.north_east,
      ),
    );
  }
}

final walletStore = WalletStore();
