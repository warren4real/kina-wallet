import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/models/account_actions_store.dart';

class FakeActions implements AccountActionsGateway {
  int resets = 0, updates = 0, deletes = 0;
  bool fail = false;
  Completer<void>? pendingReset, pendingCancel;
  String? lastUser, lastSession;
  @override
  Future<void> requestReset(String email) async {
    resets++;
    if (fail) throw StateError('Offline');
  }

  @override
  Future<void> completeReset(
    String password, {
    required String expectedUser,
    required String expectedSession,
  }) async {
    lastUser = expectedUser;
    lastSession = expectedSession;
    await pendingReset?.future;
    updates++;
    if (fail) throw StateError('Offline');
  }

  @override
  Future<void> cancelRecovery() async {
    await pendingCancel?.future;
  }

  @override
  Future<void> deleteAccount(String expectedUser, String password) async {
    deletes++;
    if (fail) throw StateError('Wrong password');
  }
}

void main() {
  test(
    'An old reset response cannot dismiss a newer recovery session',
    () async {
      final api = FakeActions()..pendingReset = Completer<void>();
      final store = AccountActionsStore(gateway: api);
      store.enterRecovery('A', 'session-a');
      final changing = store.completeReset(
        'long-new-password',
        'long-new-password',
      );
      expect(api.lastUser, 'A');
      expect(api.lastSession, 'session-a');
      store.enterRecovery('B', 'session-b');
      api.pendingReset!.complete();
      await changing;
      expect(store.needsRecovery, isTrue);
      expect(store.recoveryKey, 'B/session-b');
      expect(store.resultReady, isFalse);
    },
  );
  test('An old cancellation cannot dismiss a newer recovery session', () async {
    final api = FakeActions()..pendingCancel = Completer<void>();
    final store = AccountActionsStore(gateway: api);
    store.enterRecovery('A', 'session-a');
    final cancel = store.cancelRecovery();
    store.enterRecovery('B', 'session-b');
    api.pendingCancel!.complete();
    await cancel;
    expect(store.needsRecovery, isTrue);
    expect(store.recoveryKey, 'B/session-b');
  });

  test(
    'Changing the recovery identity cannot complete an old recovery flow',
    () async {
      final api = FakeActions();
      final store = AccountActionsStore(gateway: api);
      store.enterRecovery('A', 'session-a');
      store.leaveRecovery();
      await store.completeReset('long-new-password', 'long-new-password');
      expect(api.updates, 0);
      store.enterRecovery('B', 'session-b');
      expect(store.recoveryKey, 'B/session-b');
      await store.cancelRecovery();
      expect(store.needsRecovery, isFalse);
    },
  );

  test(
    'Recovery requests validate email and never claim delivery for failure',
    () async {
      final api = FakeActions();
      final store = AccountActionsStore(gateway: api);
      await store.requestReset('bad');
      expect(api.resets, 0);
      api.fail = true;
      await store.requestReset('a@example.com');
      expect(store.error, isNotNull);
      expect(store.message, isNull);
      api.fail = false;
      await store.requestReset('a@example.com');
      expect(store.message, contains('If this email'));
    },
  );
  test('New password requires a verified recovery session and matching strong values', () async {
    final api = FakeActions();
    final store = AccountActionsStore(gateway: api);
    await store.completeReset('long-new-password', 'long-new-password');
    expect(api.updates, 0);
    store.enterRecovery('A', 'session-a');
    await store.completeReset('short', 'short');
    expect(api.updates, 0);
    await store.completeReset('long-new-password', 'different');
    expect(api.updates, 0);
    await store.completeReset('long-new-password', 'long-new-password');
    expect(api.updates, 1);
    expect(store.needsRecovery, isFalse);
  });
  test('Deletion needs explicit confirmation and password, and failure is not success', () async {
    final api = FakeActions();
    final store = AccountActionsStore(gateway: api);
    await store.deleteAccount('A', 'secret', confirmed: false);
    expect(api.deletes, 0);
    await store.deleteAccount('A', '', confirmed: true);
    expect(api.deletes, 0);
    api.fail = true;
    await store.deleteAccount('A', 'secret', confirmed: true);
    expect(store.error, isNotNull);
    expect(store.message, isNull);
  });
  test('Only the exact native callback is accepted', () {
    expect(
      isKinaAuthCallback(
        Uri.parse('com.kinawallet.app://auth/callback?code=valid'),
      ),
      isTrue,
    );
    expect(
      isKinaAuthCallback(Uri.parse('https://auth/callback?code=valid')),
      isFalse,
    );
    expect(
      isKinaAuthCallback(
        Uri.parse('com.kinawallet.app://other/callback?code=valid'),
      ),
      isFalse,
    );
    expect(
      isKinaAuthCallback(
        Uri.parse('com.kinawallet.app://auth/other?code=valid'),
      ),
      isFalse,
    );
    expect(
      isKinaAuthCallback(
        Uri.parse('com.kinawallet.app://auth/callback#access_token=unsafe'),
      ),
      isFalse,
    );
  });
}
