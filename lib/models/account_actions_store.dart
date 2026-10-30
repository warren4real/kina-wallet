import 'package:flutter/foundation.dart';

const kinaAuthRedirect = 'com.kinawallet.app://auth/callback';
bool isKinaAuthCallback(Uri uri) =>
    uri.scheme == 'com.kinawallet.app' &&
    uri.host == 'auth' &&
    uri.path == '/callback' &&
    uri.userInfo.isEmpty &&
    !uri.hasPort &&
    uri.fragment.isEmpty &&
    (uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('error') ||
        uri.queryParameters.containsKey('error_code'));

abstract interface class AccountActionsGateway {
  Future<void> requestReset(String email);
  Future<void> completeReset(
    String password, {
    required String expectedUser,
    required String expectedSession,
  });
  Future<void> cancelRecovery();
  Future<void> deleteAccount(String expectedUser, String password);
}

class AccountActionFailure implements Exception {
  const AccountActionFailure(this.message);
  final String message;
}

class AccountActionsStore extends ChangeNotifier {
  // Public injection parameter keeps the implementation private.
  // ignore: prefer_initializing_formals
  AccountActionsStore({AccountActionsGateway? gateway}) : _gateway = gateway;
  final AccountActionsGateway? _gateway;
  bool _busy = false;
  bool _needsRecovery = false;
  String? _recoveryUser, _recoverySession;
  String get recoveryKey => '$_recoveryUser/$_recoverySession';
  bool _resultReady = false;
  String? _error, _message, _linkError;
  bool get busy => _busy;
  bool get needsRecovery => _needsRecovery;
  bool get resultReady => _resultReady;
  void dismissResult() {
    _resultReady = false;
    notifyListeners();
  }

  String? get error => _error;
  String? get message => _message;
  String? get linkError => _linkError;
  void enterRecovery(String userId, String sessionId) {
    if (userId.isEmpty || sessionId.isEmpty) return;
    _recoveryUser = userId;
    _recoverySession = sessionId;
    _resultReady = false;
    _needsRecovery = true;
    _error = null;
    _message = null;
    notifyListeners();
  }

  void leaveRecovery() {
    _recoveryUser = null;
    _recoverySession = null;
    _needsRecovery = false;
    notifyListeners();
  }

  void failLink() {
    _linkError = 'This email link is expired, already used, or was requested on another device. Request a new link from this phone.';
    notifyListeners();
  }

  void dismissLinkError() {
    _linkError = null;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _error = null;
    _message = null;
    if (_gateway == null) {
      _error = 'Account service is unavailable. Reopen the app and retry.';
      notifyListeners();
      return;
    }
    _busy = true;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _error = error is AccountActionFailure ? error.message : 'Could not complete the account request. Check your connection and retry.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> requestReset(String email) async {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
      _error = 'Enter a valid email address.';
      notifyListeners();
      return;
    }
    await _run(() async {
      await _gateway!.requestReset(email.trim());
      _message = 'If this email has a test account and delivery is available, a reset link will arrive. Open the newest link on this phone.';
    });
  }

  Future<void> completeReset(String password, String confirmation) async {
    if (!_needsRecovery) {
      _error = 'Open a valid password-reset link first.';
      notifyListeners();
      return;
    }
    if (password.length < 12 || password != confirmation) {
      _error = 'Use matching passwords with at least 12 characters.';
      notifyListeners();
      return;
    }
    final expectedUser = _recoveryUser!;
    final expectedSession = _recoverySession!;
    await _run(() async {
      await _gateway!.completeReset(
        password,
        expectedUser: expectedUser,
        expectedSession: expectedSession,
      );
      // The gateway verifies the captured session before changing the password.
      // A new recovery link must retain its own form if one arrived meanwhile.
      if (_needsRecovery &&
          (_recoveryUser != expectedUser ||
              _recoverySession != expectedSession)) {
        return;
      }
      _needsRecovery = false;
      _recoveryUser = null;
      _recoverySession = null;
      _message = 'Password updated. Sign in with your new password.';
      _resultReady = true;
    });
  }

  Future<void> cancelRecovery() {
    final expectedRecovery = recoveryKey;
    return _run(() async {
      await _gateway!.cancelRecovery();
      if (recoveryKey == expectedRecovery || !needsRecovery) leaveRecovery();
    });
  }

  Future<void> deleteAccount(
    String expectedUser,
    String password, {
    required bool confirmed,
  }) async {
    if (!confirmed || expectedUser.isEmpty || password.isEmpty) {
      _error = 'Confirm deletion and enter your account password.';
      notifyListeners();
      return;
    }
    await _run(() async {
      await _gateway!.deleteAccount(expectedUser, password);
      _needsRecovery = false;
      _message =
          'Test account deleted. Your local demo wallet and PIN were kept.';
      _resultReady = true;
    });
  }
}

AccountActionsStore accountActionsStore = AccountActionsStore();
