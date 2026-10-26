import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/main.dart';
import 'package:kina_wallet/models/pin_lock_store.dart';
import 'package:kina_wallet/models/biometric_service.dart';
import 'package:kina_wallet/widgets/app_lock_gate.dart';

class NoBiometrics implements BiometricService {
  @override
  Future<BiometricCapability> capability() async =>
      BiometricCapability.unavailable;
  @override
  Future<bool> authenticate({required String reason}) async => false;
  @override
  Future<void> cancel() async {}
}

class MemoryPinStorage implements PinStorage {
  String? value;
  bool failReads = false;
  bool failWrites = false;
  @override
  Future<String?> read() async {
    if (failReads) throw StateError('Read failed');
    return value;
  }

  @override
  Future<void> write(String next) async {
    if (failWrites) throw StateError('Write failed');
    value = next;
  }
}

// Fast deterministic stand-in for UI/state tests; the real KDF has its own vector test.
Future<List<int>> fakeDerive(String pin, List<int> salt) async =>
    List.generate(32, (i) => (pin.codeUnitAt(i % 6) + salt[i]) % 256);

Future<void> enterKeypadPin(WidgetTester tester, String pin) async {
  final clear = find.byKey(const ValueKey('pin-clear'));
  await tester.ensureVisible(clear);
  await tester.tap(clear);
  await tester.pump();
  for (final digit in pin.split('')) {
    final key = find.byKey(ValueKey('pin-key-$digit'));
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pump();
  }
}

void main() {
  test('Grace period resumes before 30 seconds, locks at the boundary, and restarts per visit', () async {
    var now = DateTime(2026, 10, 16);
    final lock = PinLockStore(
      storage: MemoryPinStorage(),
      derive: fakeDerive,
      biometrics: NoBiometrics(),
      now: () => now,
    );
    await lock.initialize();
    await lock.createPin('123456', '123456');
    lock.setActive(false);
    expect(lock.unlocked, isFalse); // Hidden even during grace.
    now = now.add(const Duration(seconds: 29));
    lock.setActive(true);
    expect(lock.unlocked, isTrue);
    lock.setActive(false);
    now = now.add(const Duration(seconds: 20));
    lock.setActive(false); // Repeated lifecycle events cannot restart grace.
    now = now.add(const Duration(seconds: 10));
    lock.setActive(true);
    expect(lock.unlocked, isFalse);
    await lock.unlock('123456');
    lock.setActive(false);
    now = now.add(const Duration(minutes: 2));
    lock.setActive(true);
    expect(lock.unlocked, isFalse);
    lock.dispose();
  });

  test(
    'Explicit lock, cold start, and clock rollback never use grace to unlock',
    () async {
      var now = DateTime(2026, 10, 16);
      final storage = MemoryPinStorage();
      final lock = PinLockStore(
        storage: storage,
        derive: fakeDerive,
        biometrics: NoBiometrics(),
        now: () => now,
      );
      await lock.initialize();
      await lock.createPin('123456', '123456');
      lock.setActive(false);
      lock.lock();
      lock.setActive(true);
      expect(lock.unlocked, isFalse);
      await lock.unlock('123456');
      lock.setActive(false);
      now = now.subtract(const Duration(seconds: 1));
      lock.setActive(true);
      expect(lock.unlocked, isFalse);
      final reopened = PinLockStore(
        storage: storage,
        derive: fakeDerive,
        biometrics: NoBiometrics(),
        now: () => now,
      );
      await reopened.initialize();
      reopened.setActive(true);
      expect(reopened.unlocked, isFalse);
      reopened.dispose();
      lock.dispose();
    },
  );

  testWidgets(
    'Short absence hides private routes then restores them without authentication',
    (tester) async {
      var now = DateTime(2026, 10, 16);
      final lock = PinLockStore(
        storage: MemoryPinStorage(),
        derive: fakeDerive,
        biometrics: NoBiometrics(),
        now: () => now,
      );
      await lock.initialize();
      await lock.createPin('123456', '123456');
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => AppLockGate(store: lock, child: child!),
          home: const Scaffold(body: Text('Private payment draft')),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.text('Private payment draft'), findsNothing);
      now = now.add(const Duration(seconds: 29));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Private payment draft'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      lock.dispose();
    },
  );

  test('PBKDF2 SHA-256 matches a known derivation vector', () async {
    final bytes = await derivePinKey(('password', utf8.encode('salt'), 1));
    expect(
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
    );
  });

  test(
    'PIN setup validates, saves a salted verifier, and locks on reopening',
    () async {
      final storage = MemoryPinStorage();
      final lock = PinLockStore(
        biometrics: NoBiometrics(),
        storage: storage,
        derive: fakeDerive,
      );
      await lock.initialize();
      expect(await lock.createPin('12345', '12345'), isNotNull);
      expect(await lock.createPin('123456', '654321'), isNotNull);
      expect(storage.value, isNull);
      expect(await lock.createPin('123456', '123456'), isNull);
      expect(lock.unlocked, isTrue);
      final saved = jsonDecode(storage.value!) as Map<String, dynamic>;
      expect(saved.containsKey('pin'), isFalse);
      expect(base64Decode(saved['salt']).length, 32);
      expect(base64Decode(saved['verifier']).length, 32);
      final reopened = PinLockStore(
        biometrics: NoBiometrics(),
        storage: storage,
        derive: fakeDerive,
      );
      await reopened.initialize();
      expect(reopened.hasPin, isTrue);
      expect(reopened.unlocked, isFalse);
      expect(await reopened.unlock('654321'), isNotNull);
      expect(reopened.unlocked, isFalse);
      expect(await reopened.unlock('123456'), isNull);
      expect(reopened.unlocked, isTrue);
      lock.dispose();
      reopened.dispose();
    },
  );

  test(
    'Attempt delay survives reopening and cannot be skipped by a correct PIN',
    () async {
      final storage = MemoryPinStorage();
      var now = DateTime.utc(2026, 10, 14);
      var lock = PinLockStore(
        biometrics: NoBiometrics(),
        storage: storage,
        derive: fakeDerive,
        now: () => now,
      );
      await lock.initialize();
      await lock.createPin('123456', '123456');
      lock.lock();
      for (var i = 0; i < 5; i++) {
        await lock.unlock('000000');
      }
      expect(lock.retrySeconds, 30);
      lock.dispose();
      lock = PinLockStore(
        biometrics: NoBiometrics(),
        storage: storage,
        derive: fakeDerive,
        now: () => now,
      );
      await lock.initialize();
      expect(lock.retrySeconds, 30);
      expect(await lock.unlock('123456'), isNotNull);
      expect(lock.unlocked, isFalse);
      now = now.add(const Duration(seconds: 31));
      expect(await lock.unlock('123456'), isNull);
      expect(lock.unlocked, isTrue);
      expect(lock.retrySeconds, 0);
      lock.dispose();
    },
  );

  test('Storage failures and corrupt records never bypass the lock', () async {
    final storage = MemoryPinStorage()..failReads = true;
    final lock = PinLockStore(
      biometrics: NoBiometrics(),
      storage: storage,
      derive: fakeDerive,
    );
    await lock.initialize();
    expect(lock.initialized, isFalse);
    expect(lock.unlocked, isFalse);
    storage.failReads = false;
    await lock.initialize();
    storage.failWrites = true;
    expect(await lock.createPin('123456', '123456'), isNotNull);
    expect(lock.unlocked, isFalse);
    expect(lock.initialized, isFalse);
    storage.failWrites = false;
    await lock.initialize();
    await lock.createPin('123456', '123456');
    lock.lock();
    storage.failWrites = true;
    expect(await lock.unlock('123456'), isNotNull);
    expect(lock.unlocked, isFalse);
    lock.dispose();
    storage.value = '{broken';
    final broken = PinLockStore(
      biometrics: NoBiometrics(),
      storage: storage,
      derive: fakeDerive,
    );
    await broken.initialize();
    expect(broken.initialized, isFalse);
    expect(broken.unlocked, isFalse);
    expect(storage.value, '{broken');
    broken.dispose();
  });

  test('Backgrounding during verification cannot complete an unlock', () async {
    final storage = MemoryPinStorage();
    final first = PinLockStore(
      biometrics: NoBiometrics(),
      storage: storage,
      derive: fakeDerive,
    );
    await first.initialize();
    await first.createPin('123456', '123456');
    final started = Completer<void>();
    final finish = Completer<void>();
    final lock = PinLockStore(
      biometrics: NoBiometrics(),
      storage: storage,
      derive: (pin, salt) async {
        started.complete();
        await finish.future;
        return fakeDerive(pin, salt);
      },
    );
    await lock.initialize();
    final pending = lock.unlock('123456');
    await started.future;
    lock.setActive(false);
    lock.setActive(true);
    finish.complete();
    await pending;
    expect(lock.unlocked, isFalse);
    first.dispose();
    lock.dispose();
  });

  testWidgets(
    'Fresh startup requires matching PINs before any wallet is visible',
    (tester) async {
      final lock = PinLockStore(
        biometrics: NoBiometrics(),
        storage: MemoryPinStorage(),
        derive: fakeDerive,
      );
      await lock.initialize();
      await tester.pumpWidget(KinaWalletApp(lockStore: lock));
      await tester.pumpAndSettle();
      expect(find.text('Create your PIN'), findsOneWidget);
      expect(find.text('Available balance'), findsNothing);
      await enterKeypadPin(tester, '123456');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm your PIN'), findsOneWidget);
      await enterKeypadPin(tester, '654321');
      await tester.tap(find.text('Save PIN'));
      await tester.pumpAndSettle();
      expect(find.text('PINs do not match. Please try again.'), findsOneWidget);
      expect(find.text('Available balance'), findsNothing);
      await enterKeypadPin(tester, '123456');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await enterKeypadPin(tester, '123456');
      await tester.tap(find.text('Save PIN'));
      await tester.pumpAndSettle();
      expect(find.text('Available balance'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      lock.dispose();
    },
  );

  testWidgets(
    'Lifecycle lock covers pushed routes and dialogs and restores them only after PIN',
    (tester) async {
      var now = DateTime(2026, 10, 16);
      final lock = PinLockStore(
        biometrics: NoBiometrics(),
        storage: MemoryPinStorage(),
        derive: fakeDerive,
        now: () => now,
      );
      await lock.initialize();
      await lock.createPin('123456', '123456');
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => AppLockGate(store: lock, child: child!),
          home: const Scaffold(body: Text('Private home')),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Private payment')),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (_) =>
              const AlertDialog(content: Text('Private confirmation')),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Private confirmation'), findsNothing);
      expect(find.text('Private payment'), findsNothing);
      expect(find.text('Welcome back'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      now = now.add(const Duration(seconds: 30));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(lock.unlocked, isFalse);
      await tester.tap(find.byKey(const ValueKey('choose-pin')));
      await tester.pumpAndSettle();
      await enterKeypadPin(tester, '000000');
      await tester.pumpAndSettle();
      expect(find.text('Private confirmation'), findsNothing);
      expect(find.text('Unlock wallet'), findsNothing);
      await enterKeypadPin(tester, '12345');
      await tester.pumpAndSettle();
      expect(lock.unlocked, isFalse);
      expect(find.text('Private confirmation'), findsNothing);
      await enterKeypadPin(tester, '123456');
      await tester.pumpAndSettle();
      expect(find.text('Private confirmation'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      lock.dispose();
    },
  );
  testWidgets('Leaving during PIN setup clears both entry and confirmation', (
    tester,
  ) async {
    final lock = PinLockStore(
      biometrics: NoBiometrics(),
      storage: MemoryPinStorage(),
      derive: fakeDerive,
    );
    await lock.initialize();
    await tester.pumpWidget(KinaWalletApp(lockStore: lock));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('app-pin-field'));
    await enterKeypadPin(tester, '123456');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await enterKeypadPin(tester, '123');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Create your PIN'), findsOneWidget);
    expect(
      tester.widget<Semantics>(field).properties.value,
      '0 of 6 digits entered',
    );
    expect(find.byType(TextField), findsNothing);
    expect(lock.hasPin, isFalse);
    expect(lock.unlocked, isFalse);
    await tester.pumpWidget(const SizedBox());
    lock.dispose();
  });
}
