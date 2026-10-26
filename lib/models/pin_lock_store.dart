import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'biometric_service.dart';

abstract interface class PinStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SecurePinStorage implements PinStorage {
  static const key = 'kina_wallet_app_lock_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
}

typedef PinDeriver = Future<List<int>> Function(String pin, List<int> salt);

// Expensive derivation runs outside the UI isolate on mobile.
Future<List<int>> derivePinKey((String, List<int>, int) input) async {
  final key = await Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: input.$3,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(input.$1)), nonce: input.$2);
  return key.extractBytes();
}

Future<List<int>> _deriveSecurePin(String pin, List<int> salt) =>
    compute(derivePinKey, (pin, salt, 600000));

class _PinRecord {
  const _PinRecord(
    this.salt,
    this.verifier,
    this.failures,
    this.retryAt, [
    this.biometricEnabled = false,
  ]);
  final List<int> salt;
  final List<int> verifier;
  final int failures;
  final int retryAt;
  final bool biometricEnabled;
  factory _PinRecord.parse(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1 ||
        data['iterations'] != 600000 ||
        data['failures'] is! int ||
        data['retryAt'] is! int ||
        (data.containsKey('biometricEnabled') &&
            data['biometricEnabled'] is! bool) ||
        (data.containsKey('faceIdEnabled') && data['faceIdEnabled'] is! bool)) {
      throw const FormatException('Invalid app lock record');
    }
    final salt = base64Decode(data['salt'] as String);
    final verifier = base64Decode(data['verifier'] as String);
    final failures = data['failures'] as int;
    final retryAt = data['retryAt'] as int;
    if (salt.length != 32 ||
        verifier.length != 32 ||
        failures < 0 ||
        failures > 1000000 ||
        retryAt < 0) {
      throw const FormatException('Invalid app lock record');
    }
    return _PinRecord(
      salt,
      verifier,
      failures,
      retryAt,
      (data['biometricEnabled'] ?? data['faceIdEnabled']) as bool? ?? false,
    );
  }
  String encode() => jsonEncode({
    'version': 1,
    'iterations': 600000,
    'salt': base64Encode(salt),
    'verifier': base64Encode(verifier),
    'failures': failures,
    'retryAt': retryAt,
    'biometricEnabled': biometricEnabled,
  });
}

class PinLockStore extends ChangeNotifier {
  PinLockStore({
    PinStorage? storage,
    PinDeriver? derive,
    BiometricService? biometrics,
    DateTime Function()? now,
  }) : _storage = storage ?? SecurePinStorage(),
       _derive = derive ?? _deriveSecurePin,
       _biometrics = biometrics ?? DeviceBiometricService(),
       _now = now ?? DateTime.now;
  final PinStorage _storage;
  final PinDeriver _derive;
  final BiometricService _biometrics;
  BiometricCapability _capability = BiometricCapability.unavailable;
  bool _biometricPending = false;
  Completer<void>? _foreground;
  String? _biometricMessage;
  bool get active => _active;
  bool get biometricEnabled => _record?.biometricEnabled ?? false;
  bool get biometricAvailable => _capability.available;
  String get biometricLabel => _capability.label;
  BiometricKind get biometricKind => _capability.kind;
  bool get biometricPending => _biometricPending;
  String? get biometricMessage => _biometricMessage;
  final DateTime Function() _now;
  _PinRecord? _record;
  bool _initialized = false;
  bool _unlocked = false;
  bool _active = true;
  static const backgroundGracePeriod = Duration(seconds: 30);
  DateTime? _backgroundAt;
  bool _busy = false;
  int _epoch = 0;
  String? _error;
  bool get initialized => _initialized;
  bool get unlocked => _unlocked && _active;
  bool get hasPin => _record != null;
  bool get busy => _busy;
  int get epoch => _epoch;
  String? get error => _error;
  int get retrySeconds {
    final remaining = (_record?.retryAt ?? 0) - _now().millisecondsSinceEpoch;
    return remaining <= 0 ? 0 : (remaining / 1000).ceil();
  }

  Future<void> initialize() async {
    if (_initialized || _busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await _storage.read();
      _record = raw == null ? null : _PinRecord.parse(raw);
      _initialized = true;
      await refreshBiometricAvailability();
    } catch (_) {
      // Storage errors must never turn an existing lock into first-time setup.
      _error = 'Could not read your app lock. Unlock your phone and retry. Your saved data has not been erased.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void setActive(bool active) {
    if (!active) {
      // Hide immediately and invalidate in-flight authentication. Only an
      // already unlocked, idle session can resume within the grace period.
      if (_active) {
        _backgroundAt = _unlocked && !_busy ? _now() : null;
      }
      if (_biometricPending) unawaited(_cancelBiometrics());
      if (_backgroundAt == null || _busy) _unlocked = false;
      _epoch++;
    } else if (_backgroundAt != null) {
      final elapsed = _now().difference(_backgroundAt!);
      // Clock rollback must not extend an unlocked session.
      if (elapsed.isNegative || elapsed >= backgroundGracePeriod) {
        _unlocked = false;
      }
      _backgroundAt = null;
    }
    _active = active;
    if (active) {
      _foreground?.complete();
      _foreground = null;
    }
    notifyListeners();
  }

  // The biometrics system sheet briefly makes iOS inactive. Hide the wallet,
  // but only a real background/hidden event invalidates this auth attempt.
  void biometricPromptInactive() {
    _active = false;
    _foreground ??= Completer<void>();
    notifyListeners();
  }

  void lock() {
    _backgroundAt = null;
    if (_biometricPending) unawaited(_cancelBiometrics());
    _unlocked = false;
    _epoch++;
    notifyListeners();
  }

  Future<String?> createPin(String pin, String confirmation) async {
    if (!_initialized || _busy || hasPin || !_active) {
      return 'App lock is not ready. Please try again.';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) return 'Use exactly six digits.';
    if (pin != confirmation) return 'PINs do not match. Please try again.';
    final epoch = _epoch;
    _busy = true;
    notifyListeners();
    try {
      final random = Random.secure();
      final salt = List<int>.generate(32, (_) => random.nextInt(256));
      final verifier = await _derive(pin, salt);
      final next = _PinRecord(salt, verifier, 0, 0);
      await _storage.write(next.encode());
      // Read back before allowing access; a platform write must really persist.
      final saved = await _storage.read();
      if (saved != next.encode()) throw StateError('App lock was not saved');
      _record = next;
      _unlocked = _active && epoch == _epoch;
      return null;
    } catch (_) {
      // A write may have reached storage even when its response failed. Re-read
      // on retry instead of offering a replacement PIN for an uncertain record.
      _initialized = false;
      _unlocked = false;
      _error = 'Could not save your app lock. Retry to check secure storage.';
      return _error;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<String?> unlock(String pin) async {
    if (!_initialized || _busy || !_active || _record == null) {
      return 'App lock is not ready. Please try again.';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) return 'Enter your six-digit PIN.';
    if (retrySeconds > 0) {
      return 'Too many attempts. Try again in $retrySeconds seconds.';
    }
    final record = _record!;
    final epoch = _epoch;
    _busy = true;
    notifyListeners();
    try {
      final candidate = await _derive(pin, record.salt);
      var difference = candidate.length ^ record.verifier.length;
      for (var i = 0; i < record.verifier.length; i++) {
        difference |=
            record.verifier[i] ^ (i < candidate.length ? candidate[i] : 0);
      }
      final correct = difference == 0;
      final failures = correct ? 0 : min(record.failures + 1, 1000000);
      final delay = failures < 5
          ? 0
          : min(300, 30 * (1 << min(4, failures - 5)));
      final next = _PinRecord(
        record.salt,
        record.verifier,
        failures,
        delay == 0 ? 0 : _now().millisecondsSinceEpoch + delay * 1000,
        record.biometricEnabled,
      );
      // Persist attempt limits before responding, including successful resets.
      await _storage.write(next.encode());
      _record = next;
      if (!correct) {
        return delay > 0
            ? 'Too many attempts. Try again in $delay seconds.'
            : 'Incorrect PIN. Please try again.';
      }
      _unlocked = _active && epoch == _epoch;
      _biometricMessage = null;
      return null;
    } catch (_) {
      _unlocked = false;
      return 'Could not check your PIN securely. Please try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<String?> changePin({
    required String currentPin,
    required String newPin,
    required String confirmation,
  }) async {
    if (!_initialized || !unlocked || _busy || _record == null) {
      return 'Unlock your wallet before changing your PIN.';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(newPin)) {
      return 'Use exactly six digits for your new PIN.';
    }
    if (newPin != confirmation) return 'New PINs do not match.';
    if (newPin == currentPin) {
      return 'Choose a PIN different from your current PIN.';
    }

    final epoch = _epoch;
    // Use the same verification and persisted attempt limits as normal unlock.
    final verificationError = await unlock(currentPin);
    if (verificationError != null) return verificationError;
    if (!unlocked || _busy || epoch != _epoch) {
      return 'The app was locked. Please start the PIN change again.';
    }
    final previous = _record!;
    _busy = true;
    notifyListeners();
    _PinRecord? replacement;
    try {
      final random = Random.secure();
      final salt = List<int>.generate(32, (_) => random.nextInt(256));
      final verifier = await _derive(newPin, salt);
      if (!unlocked || epoch != _epoch) {
        return 'The app was locked. Your PIN has not been changed.';
      }
      replacement = _PinRecord(salt, verifier, 0, 0, previous.biometricEnabled);
      await _storage.write(replacement.encode());
      if (await _storage.read() != replacement.encode()) {
        throw StateError('PIN update could not be confirmed');
      }
      _record = replacement;
      _biometricMessage = null;
      // Never restore a session that was locked during a storage operation.
      return null;
    } catch (_) {
      // A platform write can commit before its response fails. Reconcile with
      // storage rather than asserting that the old or new PIN must be valid.
      try {
        final saved = await _storage.read();
        if (replacement != null && saved == replacement.encode()) {
          _record = replacement;
          _biometricMessage = null;
          return null;
        }
        if (saved == previous.encode()) {
          _record = previous;
          return 'Could not save your new PIN. Your current PIN is unchanged.';
        }
      } catch (_) {
        /* Uncertain storage state must remain locked. */
      }
      _initialized = false;
      _unlocked = false;
      _epoch++;
      _error = 'Could not confirm the PIN update. Retry secure storage to check the saved lock. Your wallet data has not been erased.';
      return _error;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshBiometricAvailability() async {
    try {
      _capability = await _biometrics.capability();
    } catch (_) {
      _capability = BiometricCapability.unavailable;
    }
    notifyListeners();
  }

  Future<void> _cancelBiometrics() async {
    try {
      await _biometrics.cancel();
    } catch (_) {
      /* Remain locked. */
    }
  }

  Future<bool> _returnedToForeground(int epoch) async {
    if (epoch != _epoch) return false;
    if (!_active) {
      try {
        await (_foreground ??= Completer<void>()).future.timeout(
          const Duration(seconds: 5),
        );
      } on TimeoutException {
        return false;
      }
    }
    return _active && epoch == _epoch;
  }

  Future<String?> enableBiometrics(String pin) async {
    if (!unlocked || _busy || !hasPin) {
      return 'Unlock with your PIN before enabling biometrics.';
    }
    // Re-entering the app PIN proves permission to change the unlock method.
    final pinError = await unlock(pin);
    if (pinError != null) return pinError;
    if (!unlocked) return 'The app was locked. Please try again.';
    return _runBiometrics(enabling: true);
  }

  Future<String?> unlockWithBiometrics() async {
    if (!_initialized ||
        !hasPin ||
        !biometricEnabled ||
        _busy ||
        !_active ||
        unlocked) {
      return 'Enter your PIN to unlock.';
    }
    return _runBiometrics(enabling: false);
  }

  Future<String?> _runBiometrics({required bool enabling}) async {
    final epoch = _epoch;
    _busy = true;
    _biometricPending = true;
    _biometricMessage = null;
    notifyListeners();
    try {
      await refreshBiometricAvailability();
      if (!biometricAvailable || !_active || epoch != _epoch) {
        return _biometricMessage =
            '$biometricLabel is unavailable. You can still use your PIN.';
      }
      final accepted = await _biometrics.authenticate(
        reason: enabling
            ? 'Enable $biometricLabel to unlock Kina Wallet.'
            : 'Unlock your Kina Wallet demo wallet.',
      );
      if (!accepted) {
        return _biometricMessage =
            '$biometricLabel did not unlock the wallet. Try again or use your PIN.';
      }
      if (!await _returnedToForeground(epoch)) {
        return _biometricMessage =
            'The app was locked. Try biometrics again or use your PIN.';
      }
      final current = _record!;
      final next = _PinRecord(current.salt, current.verifier, 0, 0, true);
      await _storage.write(next.encode());
      if (await _storage.read() != next.encode()) {
        throw StateError('biometrics preference was not saved');
      }
      _record = next;
      // A lifecycle change can occur while secure storage is being updated.
      _unlocked = _active && epoch == _epoch;
      return null;
    } catch (_) {
      return _biometricMessage =
          '$biometricLabel was cancelled or is unavailable. Use your PIN or try again.';
    } finally {
      _biometricPending = false;
      _busy = false;
      notifyListeners();
    }
  }

  Future<String?> disableBiometrics() async {
    if (!unlocked || _busy || _record == null) {
      return 'Unlock your wallet first.';
    }
    _busy = true;
    notifyListeners();
    try {
      final current = _record!;
      final next = _PinRecord(
        current.salt,
        current.verifier,
        current.failures,
        current.retryAt,
        false,
      );
      await _storage.write(next.encode());
      if (await _storage.read() != next.encode()) {
        throw StateError('biometrics preference was not saved');
      }
      _record = next;
      _biometricMessage = null;
      return null;
    } catch (_) {
      return 'Could not save your biometrics setting. Please try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}

final pinLockStore = PinLockStore();
