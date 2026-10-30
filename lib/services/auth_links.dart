import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_actions_store.dart';

const _secureAuthStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  ),
);
const _recoveryKey = 'kina_wallet_recovery_user_v1';

class SecurePkceStorage extends GotrueAsyncStorage {
  const SecurePkceStorage();
  String _key(String key) => 'kina_wallet_pkce_v1_$key';
  @override
  Future<String?> getItem({required String key}) =>
      _secureAuthStorage.read(key: _key(key));
  @override
  Future<void> setItem({required String key, required String value}) =>
      _secureAuthStorage.write(key: _key(key), value: value);
  @override
  Future<void> removeItem({required String key}) =>
      _secureAuthStorage.delete(key: _key(key));
}

class AuthLinkCoordinator {
  AuthLinkCoordinator(this.client, this.actions);
  final SupabaseClient client;
  final AccountActionsStore actions;
  final _seen = <String>{};
  final _links = AppLinks();
  String? _recoveryUser, _recoverySession;
  Future<void> _markerWrite = Future<void>.value();
  Future<void> _persistMarker(String? value) {
    _markerWrite = _markerWrite
        .catchError((_) {})
        .then(
          (_) => value == null
              ? _secureAuthStorage.delete(key: _recoveryKey)
              : _secureAuthStorage.write(key: _recoveryKey, value: value),
        );
    return _markerWrite;
  }

  Future<void> _rememberRecovery(Session session) async {
    final id = authSessionId(session);
    if (client.auth.currentUser?.id != session.user.id ||
        authSessionId(client.auth.currentSession) != id) {
      return;
    }
    if (id.isEmpty) {
      actions.failLink();
      return;
    }
    _recoveryUser = session.user.id;
    _recoverySession = id;
    actions.enterRecovery(session.user.id, id);
    try {
      await _persistMarker(
        jsonEncode({'user': session.user.id, 'session': id}),
      );
    } catch (_) {
      actions.failLink();
    }
  }

  void _clearRecovery() {
    _recoveryUser = null;
    _recoverySession = null;
    actions.leaveRecovery();
    unawaited(_persistMarker(null).catchError((_) {}));
  }

  Future<void> initialize() async {
    final saved = await _secureAuthStorage.read(key: _recoveryKey);
    if (saved != null) {
      try {
        final value = jsonDecode(saved) as Map;
        _recoveryUser = value['user'] as String;
        _recoverySession = value['session'] as String;
      } catch (_) {
        _clearRecovery();
      }
    }
    final current = client.auth.currentSession;
    if (current != null &&
        _recoveryUser == current.user.id &&
        _recoverySession == authSessionId(current)) {
      actions.enterRecovery(_recoveryUser!, _recoverySession!);
    }
    client.auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.passwordRecovery &&
            state.session != null) {
          unawaited(_rememberRecovery(state.session!));
        } else if (state.event == AuthChangeEvent.signedOut) {
          _clearRecovery();
        } else if (state.session != null && _recoveryUser != null) {
          if (_recoveryUser != state.session!.user.id ||
              _recoverySession != authSessionId(state.session!)) {
            _clearRecovery();
          } else if (!actions.needsRecovery) {
            actions.enterRecovery(_recoveryUser!, _recoverySession!);
          }
        }
      },
      onError: (_) {
        /* Network errors do not turn another session into recovery. */
      },
    );
    _links.uriLinkStream.listen(
      (uri) => unawaited(handle(uri)),
      onError: (_) => actions.failLink(),
    );
    final initial = await _links.getInitialLink();
    if (initial != null) await handle(initial);
  }

  Future<void> handle(Uri uri) async {
    if (!isKinaAuthCallback(uri)) return;
    final code = uri.queryParameters['code'];
    if (code == null ||
        code.isEmpty ||
        uri.queryParameters.containsKey('error') ||
        uri.queryParameters.containsKey('error_code')) {
      actions.failLink();
      return;
    }
    if (!_seen.add(code)) return;
    try {
      final result = await client.auth
          .exchangeCodeForSession(code)
          .timeout(const Duration(seconds: 20));
      if (result.redirectType == AuthChangeEvent.passwordRecovery.name) {
        await _rememberRecovery(result.session);
      }
    } catch (_) {
      _seen.remove(code);
      actions.failLink();
    }
  }
}

String authSessionId(Session? session) {
  if (session == null) return '';
  try {
    final payload = jsonDecode(
      utf8.decode(
        base64Url.decode(
          base64Url.normalize(session.accessToken.split('.')[1]),
        ),
      ),
    ) as Map;
    return payload['session_id'] is String
        ? payload['session_id'] as String
        : '';
  } catch (_) {
    return '';
  }
}
