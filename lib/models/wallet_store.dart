import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_backup.dart';
import 'cloud_wallet.dart';
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

  final Set<String> _cloudWrites = {};
  bool _localSaving = false;
  CloudWalletGateway? _cloud;
  String? _accountId;
  int _epoch = 0;
  int? _localBalance;
  List<DemoTransaction>? _localTransactions;
  bool _cloudReady = false;
  bool _cloudLoading = false;
  String? _cloudError;
  CloudWalletCommand? _pending;
  bool _pendingConfirmed = false;
  DateTime? _lastCloudSyncAt;
  DateTime? _cloudOperationCreatedAt;
  DateTime? get cloudOperationCreatedAt => _cloudOperationCreatedAt;
  bool _cloudUnavailable = false;
  CloudOperationState _cloudOperationState = CloudOperationState.none;
  CloudWalletCommand? _cloudOperationCommand;
  String? _cloudOperationMessage, _cloudOperationReference;
  DateTime? get lastCloudSyncAt => _lastCloudSyncAt;
  bool get cloudUnavailable => _cloudUnavailable;
  CloudOperationState get cloudOperationState => _cloudOperationState;
  CloudWalletCommand? get cloudOperationCommand => _cloudOperationCommand;
  String? get cloudOperationMessage => _cloudOperationMessage;
  String? get cloudOperationReference => _cloudOperationReference;
  String? _lastTransferReference;
  DateTime? _lastTransferCreatedAt;
  String? get lastTransferReference => _lastTransferReference;
  DateTime? get lastTransferCreatedAt => _lastTransferCreatedAt;
  Future<VerifiedDemoRecipient> verifyCloudRecipient(String code) async {
    final sender = _accountId;
    final epoch = _epoch;
    final directory = _cloud;
    final target = code.trim().toLowerCase();
    if (sender == null || directory is! CloudRecipientDirectory) {
      throw const CloudWalletRejected(
        'Sign in to look up a demo receiving account.',
      );
    }
    if (!isReceivingCode(target) || target == sender) {
      throw const CloudWalletRejected(
        'Use another demo account’s receiving code.',
      );
    }
    final recipient = await (directory as CloudRecipientDirectory).lookup(
      sender,
      target,
    );
    if (epoch != _epoch || sender != _accountId) {
      throw const CloudWalletRejected(
        'Your account changed. Review the transfer again.',
      );
    }
    return recipient;
  }

  bool get isCloud => _accountId != null;
  String? get accountId => _accountId;
  bool get cloudReady => _cloudReady;
  bool get saving => _saving;
  bool get cloudLoading => _cloudLoading;
  String? get cloudError => _cloudError;
  bool get hasPendingCloudUpdate => _pending != null;
  String _pendingKey(String id) => 'kina_cloud_pending_v1_$id';

  void configureCloud(CloudWalletGateway gateway) {
    _cloud = gateway;
  }

  Future<void> useAccount(String? id) async {
    if (_accountId == id) return;
    if (_accountId == null && id != null) {
      _localBalance = _balanceToea;
      _localTransactions = List.of(_transactions);
    }
    _epoch++;
    _accountId = id;
    _pending = null;
    _pendingConfirmed = false;
    _lastCloudSyncAt = null;
    _cloudOperationCreatedAt = null;
    _cloudUnavailable = false;
    _cloudOperationState = CloudOperationState.none;
    _cloudOperationCommand = null;
    _cloudOperationMessage = null;
    _cloudOperationReference = null;
    _lastTransferReference = null;
    _lastTransferCreatedAt = null;
    _cloudError = null;
    _cloudReady = false;
    _cloudLoading = false;
    _saving = id == null ? _localSaving : _cloudWrites.contains(id);
    _balanceToea = id == null ? (_localBalance ?? _balanceToea) : 0;
    _transactions
      ..clear()
      ..addAll(id == null ? (_localTransactions ?? []) : []);
    notifyListeners();
    if (id != null) await refreshCloud();
  }

  Future<void> refreshCloud() async {
    final id = _accountId;
    if (id == null || _cloud == null || _cloudLoading || _saving) return;
    final epoch = _epoch;
    _cloudLoading = true;
    _cloudError = null;
    notifyListeners();
    try {
      final raw = await _preferences.getString(_pendingKey(id));
      final pending = raw == null || raw.isEmpty
          ? null
          : CloudWalletCommand.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            );
      if (_epoch != epoch) return;
      _pending = pending;
      _pendingConfirmed = false;
      CloudRequestReceipt? receipt;
      if (pending != null) {
        _cloudOperationCommand = pending;
        _cloudOperationState = CloudOperationState.pending;
        _cloudOperationMessage =
            'Checking the original saved request. Do not send it again.';
        final gateway = _cloud;
        if (gateway is CloudRequestLookup) {
          receipt = await (gateway as CloudRequestLookup).findRequest(
            id,
            pending.id,
          );
          if (_epoch != epoch) return;
        }
      }
      // Read the wallet after the receipt check, so a confirmed request is
      // included in this snapshot even if it completed during reconnection.
      final snapshot = await _cloud!.load(id);
      if (_epoch != epoch) return;
      _applyCloud(snapshot);
      _cloudReady = true;
      if (pending != null && receipt != null) {
        _pendingConfirmed = true;
        _cloudOperationReference = receipt.reference;
        _cloudOperationCreatedAt = receipt.createdAt;
        try {
          await _preferences.setString(_pendingKey(id), '');
          if (_epoch != epoch) return;
          _pending = null;
          _cloudOperationState = CloudOperationState.completed;
          _cloudOperationReference = receipt.reference;
          _cloudOperationCreatedAt = receipt.createdAt;
          _cloudOperationMessage =
              'Confirmed on the server. The original update completed once.';
          _lastTransferReference = receipt.reference;
          _lastTransferCreatedAt = receipt.createdAt;
        } catch (_) {
          if (_epoch != epoch) return;
          _cloudOperationMessage = 'The server confirmed this update, but this phone could not save the confirmation. Check again safely; do not send a new payment.';
        }
      } else if (pending != null) {
        _cloudOperationMessage = 'No completion confirmed yet. A retry uses the same saved request; do not create a new payment.';
      }
    } catch (_) {
      if (_epoch == epoch) {
        _cloudUnavailable = true;
        _cloudError = 'Cloud wallet unavailable. Check your connection and retry. The displayed balance may be out of date.';
        if (_pending != null) {
          _cloudOperationState = CloudOperationState.pending;
          _cloudOperationMessage = 'The result is still unknown. Your original request is saved on this phone.';
        }
      }
    } finally {
      if (_epoch == epoch) {
        _cloudLoading = false;
        notifyListeners();
      }
    }
  }

  void _applyCloud(CloudWalletSnapshot snapshot) {
    _lastCloudSyncAt = DateTime.now();
    _cloudUnavailable = false;
    _lastTransferReference = snapshot.transferReference;
    _lastTransferCreatedAt = snapshot.transferCreatedAt;
    _balanceToea = snapshot.balanceToea;
    _transactions
      ..clear()
      ..addAll(snapshot.transactions);
  }

  String _requestId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> clearPendingForDeletedAccount(String id) async {
    await _preferences.setString(_pendingKey(id), '');
    if (_accountId == id) {
      _pending = null;
      notifyListeners();
    }
  }

  Future<String?> retryPendingCloudUpdate() async {
    if (_pending == null) return 'No cloud update is waiting.';
    if (_saving || _cloudLoading) {
      return 'An update is already being checked. Please wait.';
    }
    final id = _accountId;
    final epoch = _epoch;
    // First check for a committed receipt without writing anything. Never
    // automatically submit an unconfirmed payment when the connection returns.
    await refreshCloud();
    if (_epoch != epoch || _accountId != id) {
      return 'Your account changed. Reopen its wallet.';
    }
    if (_pending == null) return null;
    if (_pendingConfirmed) {
      return 'The server confirmed this update. This phone could not save the confirmation yet. Use Check status again; no new request was sent.';
    }
    if (!_cloudReady || _cloudUnavailable) {
      return 'Reconnect before retrying the saved request.';
    }
    return _recordCloud(_pending!.transaction, retry: true);
  }

  Future<String?> _recordCloud(
    DemoTransaction transaction, {
    bool retry = false,
    String? recipientAccountId,
  }) async {
    if (!_cloudReady || _cloudLoading || _cloud == null || _cloudUnavailable) {
      return 'Reconnect and refresh the cloud wallet before making a demo payment.';
    }
    if (_saving) return 'A demo update is already being saved. Please wait.';
    if (_pending != null && !retry) {
      return 'A previous cloud update needs checking. Use Retry pending update before making another payment.';
    }
    if (transaction.amountToea.abs() > 1000000) {
      return 'Use K 0.01–10,000.00 per demo update.';
    }
    final id = _accountId!;
    final epoch = _epoch;
    final command =
        _pending ??
        CloudWalletCommand(
          _requestId(),
          transaction,
          recipientAccountId: recipientAccountId,
        );
    _cloudWrites.add(id);
    _saving = true;
    _cloudOperationCommand = command;
    _cloudOperationState = CloudOperationState.sending;
    _cloudOperationMessage =
        'Keep the app open while the server confirms this update.';
    _cloudOperationReference = null;
    _cloudOperationCreatedAt = null;
    notifyListeners();
    var submitted = false;
    try {
      await _preferences.setString(
        _pendingKey(id),
        jsonEncode(command.toJson()),
      );
      if (_epoch != epoch) {
        return 'The active wallet changed. Check its history before retrying.';
      }
      _pending = command;
      submitted = true;
      final snapshot = await _cloud!.post(id, command);
      await _preferences.setString(_pendingKey(id), '');
      if (_epoch != epoch) {
        return 'The active wallet changed. Check its history before retrying.';
      }
      _applyCloud(snapshot);
      _pending = null;
      _cloudError = null;
      _cloudOperationState = CloudOperationState.completed;
      _cloudOperationMessage = 'The server confirmed this demo update. Check History for the receipt.';
      _cloudOperationReference = snapshot.transferReference;
      _cloudOperationCreatedAt = snapshot.transferCreatedAt;
      notifyListeners();
      return null;
    } on CloudWalletRejected catch (error) {
      try {
        await _preferences.setString(_pendingKey(id), '');
        if (_epoch == epoch) _pending = null;
      } catch (_) {
        // Retain the saved request if local cleanup could not complete.
      }
      if (_epoch == epoch) {
        _cloudUnavailable = false;
        _cloudError = error.message;
        _cloudOperationState = _pending == null
            ? CloudOperationState.failed
            : CloudOperationState.pending;
        _cloudOperationMessage = error.message;
      }
      return error.message;
    } catch (_) {
      final uncertain = submitted || _pending != null;
      final message = uncertain
          ? 'Pending confirmation. The result is unknown. Reconnect to check the original request; do not send it again.'
          : 'Could not save the pending request on this phone. No new cloud request was sent.';
      if (_epoch == epoch) {
        _cloudError = message;
        _cloudUnavailable = submitted;
        _cloudOperationState = uncertain
            ? CloudOperationState.pending
            : CloudOperationState.failed;
        _cloudOperationMessage = message;
      }
      return message;
    } finally {
      _cloudWrites.remove(id);
      if (_accountId == id) {
        _saving = false;
        notifyListeners();
        if (_epoch != epoch) unawaited(refreshCloud());
      }
    }
  }

  int get balanceToea => _balanceToea;

  List<DemoTransaction> get transactions => List.unmodifiable(_transactions);

  String get formattedBalance => isCloud && !_cloudReady
      ? 'K —'
      : 'K ${(_balanceToea / 100).toStringAsFixed(2)}';

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
    if (isCloud) return _recordCloud(transaction);

    if (!_ready) {
      return 'The demo wallet is not ready yet.';
    }

    if (_saving) {
      return 'A demo update is already being saved. Please wait.';
    }

    final epoch = _epoch;
    _localSaving = true;
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

      _localBalance = newBalanceToea;
      _localTransactions = List.of(updatedTransactions);
      if (!isCloud) {
        _balanceToea = newBalanceToea;
        _transactions
          ..clear()
          ..addAll(updatedTransactions);
        notifyListeners();
      }
      return _epoch == epoch
          ? null
          : 'The active wallet changed. The local update was saved separately.';
    } catch (_) {
      return 'Could not save the demo payment. '
          'Your balance was not changed. Try again.';
    } finally {
      _localSaving = false;
      if (!isCloud) _saving = false;
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
    String? recipientAccountId,
    String? expectedSenderId,
  }) async {
    if (expectedSenderId != null && expectedSenderId != _accountId) {
      return 'Your account changed. Review the transfer again.';
    }
    if (amountToea <= 0) {
      return 'Enter an amount greater than zero.';
    }

    if (amountToea > _balanceToea) {
      return 'Not enough demo balance for this transfer.';
    }

    if (isCloud) {
      if (expectedSenderId != _accountId ||
          recipientAccountId == null ||
          !isReceivingCode(recipientAccountId) ||
          recipientAccountId == _accountId) {
        return 'Match another account’s receiving code before sending.';
      }
      return _recordCloud(
        DemoTransaction(
          'Sent to $recipientName',
          'Cloud demo transfer · Fictional funds',
          -amountToea,
          Icons.north_east,
        ),
        recipientAccountId: recipientAccountId,
      );
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
