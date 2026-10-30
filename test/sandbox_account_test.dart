import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/models/sandbox_account_store.dart';
import 'package:kina_wallet/models/wallet_store.dart';

class MemoryAccounts implements SandboxAccountGateway {
  final sessionEvents = StreamController<String?>.broadcast();
  SandboxAccount? current;
  bool confirmationRequired = false;
  bool fail = false;
  Completer<void>? pending;
  @override
  Stream<String?> get sessions => sessionEvents.stream;
  @override
  Future<SandboxAccount?> restore() async {
    if (fail) throw StateError('offline');
    return current;
  }

  @override
  Future<SandboxAccount?> register(
    String email,
    String password,
    String displayName,
  ) async {
    if (fail) throw StateError('offline');
    if (confirmationRequired) return null;
    return current = SandboxAccount(
      id: 'user-a',
      email: email,
      displayName: displayName,
    );
  }

  @override
  Future<SandboxAccount> signIn(String email, String password) async {
    await pending?.future;
    if (fail) throw StateError('offline');
    return current = SandboxAccount(
      id: 'user-a',
      email: email,
      displayName: 'Private test name',
    );
  }

  @override
  Future<SandboxAccount> rename(
    String displayName, {
    required String expectedUser,
    String? phoneNumber,
  }) async => current = SandboxAccount(
    id: current!.id,
    email: current!.email,
    displayName: displayName,
    phoneNumber: phoneNumber,
  );
  @override
  Future<void> signOut() async {
    if (fail) throw StateError('offline');
    current = null;
    sessionEvents.add(null);
  }
}

void main() {
  test('Changing signed-in identity reloads the new private profile', () async {
    final gateway = MemoryAccounts()
      ..current = const SandboxAccount(
        id: 'A',
        email: 'a@example.com',
        displayName: 'A',
      );
    final store = SandboxAccountStore(gateway: gateway);
    await store.initialize();
    gateway.current = const SandboxAccount(
      id: 'B',
      email: 'b@example.com',
      displayName: 'B',
    );
    gateway.sessionEvents.add('B');
    await Future<void>.delayed(Duration.zero);
    expect(store.account?.id, 'B');
    store.dispose();
    await gateway.sessionEvents.close();
  });

  late MemoryAccounts gateway;
  late SandboxAccountStore store;
  setUp(() {
    gateway = MemoryAccounts();
    store = SandboxAccountStore(gateway: gateway);
  });
  tearDown(() async {
    store.dispose();
    await gateway.sessionEvents.close();
  });

  test('Email confirmation does not create a signed-in account or change the local wallet', () async {
    final before = walletStore.exportDemoSnapshot();
    gateway.confirmationRequired = true;
    await store.initialize();
    await store.register(
      'test@example.com',
      'long-test-password',
      'Test account',
    );
    expect(store.account, isNull);
    expect(store.message, contains('email'));
    expect(walletStore.exportDemoSnapshot(), before);
  });

  test('Invalid registration never authenticates', () async {
    await store.register('not-an-email', 'short', '');
    expect(store.account, isNull);
    expect(store.error, isNotNull);
  });

  test('Restored account can update its own name and sign out without changing demo money', () async {
    gateway.current = const SandboxAccount(
      id: 'user-a',
      email: 'test@example.com',
      displayName: 'Before',
    );
    final before = walletStore.exportDemoSnapshot();
    await store.initialize();
    expect(store.account!.displayName, 'Before');
    await store.rename('After');
    expect(store.account!.displayName, 'After');
    await store.signOut();
    expect(store.account, isNull);
    expect(walletStore.exportDemoSnapshot(), before);
  });

  test('Failed sign-in reports failure and stays signed out', () async {
    gateway.fail = true;
    await store.signIn('test@example.com', 'wrong-password');
    expect(store.account, isNull);
    expect(store.error, isNotNull);
  });

  test('External session revocation clears the private profile', () async {
    gateway.current = const SandboxAccount(
      id: 'user-a',
      email: 'test@example.com',
      displayName: 'Private',
    );
    await store.initialize();
    gateway.current = null;
    gateway.sessionEvents.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(store.account, isNull);
  });

  test('A pending sign-in cannot overwrite a later revoked session', () async {
    await store.initialize();
    gateway.pending = Completer<void>();
    final signIn = store.signIn('test@example.com', 'long-test-password');
    expect(store.busy, isTrue);
    gateway.sessionEvents.add(null);
    await Future<void>.delayed(Duration.zero);
    gateway.pending!.complete();
    await signIn;
    expect(store.account, isNull);
  });
}
