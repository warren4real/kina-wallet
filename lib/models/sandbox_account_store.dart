import 'dart:async';

import 'package:flutter/foundation.dart';

class SandboxAccount {
  const SandboxAccount({
    required this.id,
    required this.email,
    required this.displayName,
    this.phoneNumber,
  });
  final String id;
  final String email;
  final String displayName;
  final String? phoneNumber;
}

abstract interface class SandboxAccountGateway {
  Stream<String?> get sessions;
  Future<SandboxAccount?> restore();
  Future<SandboxAccount?> register(
    String email,
    String password,
    String displayName,
  );
  Future<SandboxAccount> signIn(String email, String password);
  Future<SandboxAccount> rename(
    String displayName, {
    required String expectedUser,
    String? phoneNumber,
  });
  Future<void> signOut();
}

class SandboxAccountFailure implements Exception {
  const SandboxAccountFailure(this.message);
  final String message;
}

class SandboxAccountStore extends ChangeNotifier {
  // Public named parameter keeps the gateway implementation private.
  // ignore: prefer_initializing_formals
  SandboxAccountStore({SandboxAccountGateway? gateway}) : _gateway = gateway;

  final SandboxAccountGateway? _gateway;
  StreamSubscription<String?>? _subscription;
  String? _sessionUser;
  bool _restoreAfterBusy = false;
  SandboxAccount? _account;
  bool _busy = false;
  bool _initialized = false;
  bool _disposed = false;
  int _revision = 0;
  String? _error;
  String? _message;
  bool get configured => _gateway != null;
  bool get busy => _busy;
  SandboxAccount? get account => _account;
  String? get error => _error;
  String? get message => _message;

  Future<void> _run(Future<void> Function(int revision) action) async {
    if (_busy || _disposed) return;
    if (!configured) {
      _error = 'Sandbox accounts are unavailable. Your local demo is still available.';
      notifyListeners();
      return;
    }
    _busy = true;
    _error = null;
    _message = null;
    notifyListeners();
    try {
      await action(_revision);
    } catch (error) {
      if (!_disposed) {
        _error = error is SandboxAccountFailure ? error.message : 'Could not connect to your sandbox account. Check your connection and retry.';
      }
    } finally {
      if (!_disposed) {
        _busy = false;
        notifyListeners();
        if (_restoreAfterBusy) {
          _restoreAfterBusy = false;
          if (_sessionUser != null) {
            _initialized = false;
            unawaited(initialize());
          }
        }
      }
    }
  }

  Future<void> initialize() async {
    if (_initialized || !configured) return;
    _subscription ??= _gateway!.sessions.listen(
      (userId) {
        if (userId == null || userId != _sessionUser) {
          _sessionUser = userId;
          _revision++;
          _account = null;
          _initialized = false;
          if (!_disposed) notifyListeners();
          if (userId != null) {
            if (_busy) {
              _restoreAfterBusy = true;
            } else {
              unawaited(initialize());
            }
          }
        }
      },
      onError: (_) {
        if (!_disposed) {
          _error = 'Account connection interrupted. Reconnect and retry.';
          notifyListeners();
        }
      },
    );
    await _run((revision) async {
      final account = await _gateway!.restore();
      if (!_disposed && revision == _revision) {
        _account = account;
        _initialized = true;
      }
    });
  }

  bool _validCredentials(
    String email,
    String password, {
    bool registering = false,
  }) {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim()) ||
        password.isEmpty ||
        (registering && password.length < 12)) {
      _error = registering
          ? 'Use a valid email and a password with at least 12 characters.'
          : 'Enter your email and password.';
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> register(String email, String password, String name) async {
    if (_busy || !_validCredentials(email, password, registering: true)) return;
    if (name.trim().isEmpty || name.trim().length > 80) {
      _error = 'Use a display name with 1–80 characters.';
      notifyListeners();
      return;
    }
    await _run((revision) async {
      final account = await _gateway!.register(
        email.trim(),
        password,
        name.trim(),
      );
      if (!_disposed && revision == _revision) {
        _account = account;
        _message = account == null
            ? 'Check your email for a confirmation link, then return here and sign in. On the Free sandbox, use your Supabase organization email.'
            : 'Your sandbox account is ready. Your separate cloud demo wallet starts at K 0.00.';
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    if (_busy || !_validCredentials(email, password)) return;
    await _run((revision) async {
      _account = null;
      final account = await _gateway!.signIn(email.trim(), password);
      if (!_disposed && revision == _revision) _account = account;
    });
  }

  Future<void> rename(String name, {String? phoneNumber}) async {
    if (_busy || _account == null) return;
    if (name.trim().isEmpty || name.trim().length > 80) {
      _error = 'Use a display name with 1–80 characters.';
      notifyListeners();
      return;
    }
    final expectedUser = _account!.id;
    final phone = phoneNumber ?? _account?.phoneNumber;
    if (phone != null &&
        phone.isNotEmpty &&
        !RegExp(r'^\d{8}$').hasMatch(phone.trim())) {
      _error = 'Use an 8-digit fictional PNG mobile number, or leave it empty.';
      notifyListeners();
      return;
    }
    await _run((revision) async {
      final account = await _gateway!.rename(
        name.trim(),
        expectedUser: expectedUser,
        phoneNumber: phone == null || phone.trim().isEmpty
            ? null
            : phone.trim(),
      );
      if (!_disposed && revision == _revision) {
        _account = account;
        _message = 'Your private sandbox profile was saved.';
      }
    });
  }

  Future<void> signOut() => _run((_) async {
    await _gateway!.signOut();
    if (!_disposed) {
      _revision++;
      _account = null;
      _message = 'Signed out. Your local demo data has not been changed.';
    }
  });

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

SandboxAccountStore sandboxAccountStore = SandboxAccountStore();
