import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/models/pin_lock_store.dart';
import 'package:kina_wallet/screens/security_screen.dart';

import 'face_id_test.dart' show FakeBiometrics;
import 'pin_lock_test.dart' show MemoryPinStorage, fakeDerive;

class ControlledStorage extends MemoryPinStorage {
  int writes = 0;
  int? failAt;
  bool commitBeforeError = false;
  bool unreadableAfterFailure = false;
  @override
  Future<void> write(String next) async {
    writes++;
    if (writes == failAt) {
      if (commitBeforeError) value = next;
      if (unreadableAfterFailure) failReads = true;
      throw StateError('Simulated write response failure');
    }
    await super.write(next);
  }
}

Future<PinLockStore> ready(MemoryPinStorage storage) async {
  final lock = PinLockStore(
    storage: storage,
    derive: fakeDerive,
    biometrics: FakeBiometrics(),
  );
  await lock.initialize();
  await lock.createPin('123456', '123456');
  return lock;
}

void main() {
  test('New PIN survives restart, rejects old PIN, rotates salt and preserves biometrics', () async {
    final storage = MemoryPinStorage();
    final lock = await ready(storage);
    await lock.enableBiometrics('123456');
    final before = jsonDecode(storage.value!) as Map<String, dynamic>;
    expect(
      await lock.changePin(
        currentPin: '123456',
        newPin: '654321',
        confirmation: '654321',
      ),
      isNull,
    );
    final after = jsonDecode(storage.value!) as Map<String, dynamic>;
    expect(after['salt'], isNot(before['salt']));
    expect(after['verifier'], isNot(before['verifier']));
    expect(after['biometricEnabled'], isTrue);
    final reopened = PinLockStore(
      storage: storage,
      derive: fakeDerive,
      biometrics: FakeBiometrics(),
    );
    await reopened.initialize();
    expect(await reopened.unlock('123456'), isNotNull);
    expect(reopened.unlocked, isFalse);
    expect(await reopened.unlock('654321'), isNull);
    expect(reopened.unlocked, isTrue);
    expect(reopened.biometricEnabled, isTrue);
    lock.dispose();
    reopened.dispose();
  });

  test('Locked sessions, invalid PINs, same PIN and mismatched confirmations cannot change the PIN', () async {
    final storage = MemoryPinStorage();
    final lock = await ready(storage);
    final before = storage.value;
    for (final request in [
      ('123456', '123456', '123456'),
      ('123456', '12345', '12345'),
      ('123456', '654321', '654322'),
    ]) {
      expect(
        await lock.changePin(
          currentPin: request.$1,
          newPin: request.$2,
          confirmation: request.$3,
        ),
        isNotNull,
      );
      expect(storage.value, before);
    }
    lock.lock();
    expect(
      await lock.changePin(
        currentPin: '123456',
        newPin: '654321',
        confirmation: '654321',
      ),
      isNotNull,
    );
    expect(storage.value, before);
    lock.dispose();
  });

  test(
    'Incorrect current PINs use the same persistent waiting period',
    () async {
      final storage = MemoryPinStorage();
      var now = DateTime.utc(2026, 10, 15);
      final lock = PinLockStore(
        storage: storage,
        derive: fakeDerive,
        biometrics: FakeBiometrics(),
        now: () => now,
      );
      await lock.initialize();
      await lock.createPin('123456', '123456');
      for (var i = 0; i < 5; i++) {
        expect(
          await lock.changePin(
            currentPin: '000000',
            newPin: '654321',
            confirmation: '654321',
          ),
          isNotNull,
        );
      }
      expect(lock.retrySeconds, 30);
      expect(
        await lock.changePin(
          currentPin: '123456',
          newPin: '654321',
          confirmation: '654321',
        ),
        isNotNull,
      );
      now = now.add(const Duration(seconds: 31));
      expect(
        await lock.changePin(
          currentPin: '123456',
          newPin: '654321',
          confirmation: '654321',
        ),
        isNull,
      );
      lock.dispose();
    },
  );

  test('Failed replacement keeps old PIN; an already committed write is reconciled', () async {
    for (final committed in [false, true]) {
      final storage = ControlledStorage();
      final lock = await ready(storage);
      storage.failAt =
          storage.writes + 2; // Current-PIN verification, then replacement.
      storage.commitBeforeError = committed;
      final error = await lock.changePin(
        currentPin: '123456',
        newPin: '654321',
        confirmation: '654321',
      );
      expect(error == null, committed);
      lock.lock();
      expect(await lock.unlock(committed ? '654321' : '123456'), isNull);
      expect(lock.unlocked, isTrue);
      lock.dispose();
    }
  });

  test('Uncertain storage state locks the app and reloads rather than guessing the active PIN', () async {
    final storage = ControlledStorage();
    final lock = await ready(storage);
    storage.failAt = storage.writes + 2;
    storage.commitBeforeError = true;
    storage.unreadableAfterFailure = true;
    expect(
      await lock.changePin(
        currentPin: '123456',
        newPin: '654321',
        confirmation: '654321',
      ),
      isNotNull,
    );
    expect(lock.initialized, isFalse);
    expect(lock.unlocked, isFalse);
    storage.failReads = false;
    await lock.initialize();
    expect(await lock.unlock('654321'), isNull);
    lock.dispose();
  });

  test('Leaving during new-PIN derivation cancels the change', () async {
    final storage = MemoryPinStorage();
    final first = await ready(storage);
    final entered = Completer<void>();
    final finish = Completer<void>();
    final lock = PinLockStore(
      storage: storage,
      biometrics: FakeBiometrics(),
      derive: (pin, salt) async {
        if (pin == '654321') {
          entered.complete();
          await finish.future;
        }
        return fakeDerive(pin, salt);
      },
    );
    await lock.initialize();
    await lock.unlock('123456');
    final operation = lock.changePin(
      currentPin: '123456',
      newPin: '654321',
      confirmation: '654321',
    );
    await entered.future;
    lock.setActive(false);
    lock.setActive(true);
    finish.complete();
    expect(await operation, isNotNull);
    expect(lock.unlocked, isFalse);
    expect(await lock.unlock('123456'), isNull);
    first.dispose();
    lock.dispose();
  });

  testWidgets(
    'Security opens Change PIN, validates confirmation, and reports a saved change',
    (tester) async {
      final lock = await ready(MemoryPinStorage());
      await tester.pumpWidget(MaterialApp(home: SecurityScreen(store: lock)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('change-pin')).hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('change-pin')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('change-current-pin')),
        '123456',
      );
      await tester.enterText(
        find.byKey(const ValueKey('change-new-pin')),
        '654321',
      );
      await tester.enterText(
        find.byKey(const ValueKey('change-confirm-pin')),
        '654322',
      );
      await tester.scrollUntilVisible(
        find.text('Save new PIN').hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save new PIN'));
      await tester.pumpAndSettle();
      expect(find.text('New PINs do not match.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('change-confirm-pin')),
        '654321',
      );
      await tester.scrollUntilVisible(
        find.text('Save new PIN').hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save new PIN'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find
            .text(
              'Your PIN has been changed. Use your new PIN the next time you unlock.',
            )
            .hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          'Your PIN has been changed. Use your new PIN the next time you unlock.',
        ),
        findsOneWidget,
      );
      lock.lock();
      expect(await lock.unlock('654321'), isNull);
      await tester.pumpWidget(const SizedBox());
      lock.dispose();
    },
  );
}
