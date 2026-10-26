import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:kina_wallet/models/biometric_service.dart';
import 'package:kina_wallet/models/pin_lock_store.dart';
import 'package:kina_wallet/screens/security_screen.dart';
import 'package:kina_wallet/widgets/app_lock_gate.dart';

import 'pin_lock_test.dart' show MemoryPinStorage, fakeDerive;

class FakeBiometrics implements BiometricService {
  bool supported = true;
  bool accepted = true;
  bool throwsError = false;
  int calls = 0;
  int cancellations = 0;
  Completer<bool>? pending;
  final started = Completer<void>();
  BiometricCapability sensor = const BiometricCapability(
    BiometricKind.face,
    'Face ID',
  );
  @override
  Future<BiometricCapability> capability() async =>
      supported ? sensor : BiometricCapability.unavailable;
  @override
  Future<bool> authenticate({required String reason}) async {
    calls++;
    if (!started.isCompleted) started.complete();
    if (throwsError) throw StateError('Cancelled, denied or locked out');
    return pending?.future ?? accepted;
  }

  @override
  Future<void> cancel() async {
    cancellations++;
  }
}

Future<PinLockStore> configured(
  MemoryPinStorage storage,
  FakeBiometrics face,
) async {
  final lock = PinLockStore(
    storage: storage,
    derive: fakeDerive,
    biometrics: face,
  );
  await lock.initialize();
  await lock.createPin('123456', '123456');
  return lock;
}

void main() {
  test(
    'Existing PIN records load with Face ID off and retain their PIN',
    () async {
      final storage = MemoryPinStorage();
      final first = await configured(storage, FakeBiometrics());
      final old = jsonDecode(storage.value!) as Map<String, dynamic>;
      old.remove('biometricEnabled');
      storage.value = jsonEncode(old);
      final reopened = PinLockStore(
        storage: storage,
        derive: fakeDerive,
        biometrics: FakeBiometrics(),
      );
      await reopened.initialize();
      expect(reopened.biometricEnabled, isFalse);
      expect(reopened.unlocked, isFalse);
      expect(await reopened.unlock('123456'), isNull);
      expect(reopened.unlocked, isTrue);
      first.dispose();
      reopened.dispose();
    },
  );

  test('Enabling requires the current PIN and successful Face ID; preference persists', () async {
    final storage = MemoryPinStorage();
    final face = FakeBiometrics();
    final lock = await configured(storage, face);
    expect(await lock.enableBiometrics('000000'), isNotNull);
    expect(face.calls, 0);
    expect(lock.biometricEnabled, isFalse);
    face.accepted = false;
    expect(await lock.enableBiometrics('123456'), isNotNull);
    expect(lock.biometricEnabled, isFalse);
    face.accepted = true;
    expect(await lock.enableBiometrics('123456'), isNull);
    expect(lock.biometricEnabled, isTrue);
    final reopened = PinLockStore(
      storage: storage,
      derive: fakeDerive,
      biometrics: face,
    );
    await reopened.initialize();
    expect(reopened.biometricEnabled, isTrue);
    expect(reopened.unlocked, isFalse);
    // A later PIN unlock must preserve the opt-in.
    expect(await reopened.unlock('123456'), isNull);
    expect(reopened.biometricEnabled, isTrue);
    lock.dispose();
    reopened.dispose();
  });

  test('Cancellation, denial, unavailability and storage failure stay locked; PIN remains usable', () async {
    final storage = MemoryPinStorage();
    final face = FakeBiometrics();
    final lock = await configured(storage, face);
    await lock.enableBiometrics('123456');
    lock.lock();
    face.accepted = false;
    expect(await lock.unlockWithBiometrics(), isNotNull);
    expect(lock.unlocked, isFalse);
    face.throwsError = true;
    expect(await lock.unlockWithBiometrics(), isNotNull);
    expect(lock.unlocked, isFalse);
    face.throwsError = false;
    face.supported = false;
    expect(await lock.unlockWithBiometrics(), isNotNull);
    expect(lock.unlocked, isFalse);
    face.supported = true;
    face.accepted = true;
    storage.failWrites = true;
    expect(await lock.unlockWithBiometrics(), isNotNull);
    expect(lock.unlocked, isFalse);
    storage.failWrites = false;
    expect(await lock.unlock('123456'), isNull);
    expect(lock.unlocked, isTrue);
    lock.dispose();
  });

  test('Face ID handles its own inactive prompt and waits for foreground before unlocking', () async {
    final storage = MemoryPinStorage();
    final face = FakeBiometrics();
    final lock = await configured(storage, face);
    await lock.enableBiometrics('123456');
    lock.lock();
    face.pending = Completer<bool>();
    final operation = lock.unlockWithBiometrics();
    // Let capability detection enter authentication.
    await Future<void>.delayed(Duration.zero);
    expect(lock.biometricPending, isTrue);
    lock.biometricPromptInactive();
    face.pending!.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(lock.unlocked, isFalse);
    lock.setActive(true);
    expect(await operation, isNull);
    expect(lock.unlocked, isTrue);
    lock.dispose();
  });

  test('A real background event invalidates a late Face ID success', () async {
    final storage = MemoryPinStorage();
    final face = FakeBiometrics();
    final lock = await configured(storage, face);
    await lock.enableBiometrics('123456');
    lock.lock();
    face.pending = Completer<bool>();
    final operation = lock.unlockWithBiometrics();
    await Future<void>.delayed(Duration.zero);
    lock.biometricPromptInactive();
    lock.setActive(false);
    lock.setActive(true);
    face.pending!.complete(true);
    expect(await operation, isNotNull);
    expect(lock.unlocked, isFalse);
    expect(face.cancellations, greaterThan(0));
    lock.dispose();
  });

  test('Disabling Face ID persists and does not change the PIN', () async {
    final storage = MemoryPinStorage();
    final face = FakeBiometrics();
    final lock = await configured(storage, face);
    await lock.enableBiometrics('123456');
    expect(await lock.disableBiometrics(), isNull);
    final reopened = PinLockStore(
      storage: storage,
      derive: fakeDerive,
      biometrics: face,
    );
    await reopened.initialize();
    expect(reopened.biometricEnabled, isFalse);
    expect(await reopened.unlockWithBiometrics(), isNotNull);
    expect(reopened.unlocked, isFalse);
    expect(await reopened.unlock('123456'), isNull);
    expect(reopened.unlocked, isTrue);
    lock.dispose();
    reopened.dispose();
  });

  testWidgets(
    'Biometric unlock starts only when chosen and can be retried after cancellation',
    (tester) async {
      final face = FakeBiometrics();
      final lock = await configured(MemoryPinStorage(), face);
      await lock.enableBiometrics('123456');
      face.calls = 0;
      face.accepted = false;
      lock.lock();
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => AppLockGate(store: lock, child: child!),
          home: const Scaffold(body: Text('Private wallet')),
        ),
      );
      await tester.pumpAndSettle();
      expect(face.calls, 0);
      expect(find.text('Private wallet'), findsNothing);
      expect(find.byKey(const ValueKey('app-pin-field')), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(face.calls, 0);
      await tester.tap(find.byKey(const ValueKey('choose-biometrics')));
      await tester.pumpAndSettle();
      expect(face.calls, 1);
      face.accepted = true;
      await tester.tap(find.byKey(const ValueKey('choose-biometrics')));
      await tester.pumpAndSettle();
      expect(face.calls, 2);
      expect(find.text('Private wallet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      lock.dispose();
    },
  );

  testWidgets('Security settings enable Face ID with PIN and can disable it', (
    tester,
  ) async {
    final lock = await configured(MemoryPinStorage(), FakeBiometrics());
    await tester.pumpWidget(MaterialApp(home: SecurityScreen(store: lock)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('face-id-pin')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const ValueKey('face-id-pin')), '123456');
    await tester.scrollUntilVisible(
      find.text('Enable Face ID').hitTestable(),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enable Face ID'));
    await tester.pumpAndSettle();
    expect(lock.biometricEnabled, isTrue);
    await tester.scrollUntilVisible(
      find.text('Turn off Face ID').hitTestable(),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Turn off Face ID'));
    await tester.pumpAndSettle();
    expect(lock.biometricEnabled, isFalse);
    await tester.pumpWidget(const SizedBox());
    lock.dispose();
  });
  testWidgets(
    'System Face ID prompt inactivity does not invalidate a successful foreground unlock',
    (tester) async {
      final face = FakeBiometrics();
      final lock = await configured(MemoryPinStorage(), face);
      await lock.enableBiometrics('123456');
      lock.lock();
      face.pending = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => AppLockGate(store: lock, child: child!),
          home: const Scaffold(body: Text('Private wallet')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('choose-biometrics')));
      await tester.pump();
      expect(lock.biometricPending, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Private wallet'), findsNothing);
      face.pending!.complete(true);
      await tester.pump();
      expect(lock.unlocked, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(lock.unlocked, isTrue);
      expect(find.text('Private wallet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      lock.dispose();
    },
  );
  test('Sensor labels handle Face ID, Touch ID, Android fingerprint and unknown sensor types', () {
    expect(
      selectBiometricCapability([BiometricType.face], TargetPlatform.iOS).label,
      'Face ID',
    );
    expect(
      selectBiometricCapability([
        BiometricType.fingerprint,
      ], TargetPlatform.iOS).label,
      'Touch ID',
    );
    expect(
      selectBiometricCapability([
        BiometricType.fingerprint,
      ], TargetPlatform.android).label,
      'Fingerprint',
    );
    expect(
      selectBiometricCapability([
        BiometricType.strong,
      ], TargetPlatform.android).kind,
      BiometricKind.generic,
    );
    expect(
      selectBiometricCapability([], TargetPlatform.iOS).available,
      isFalse,
    );
  });

  test(
    'Legacy Face ID opt-in migrates without changing the saved PIN',
    () async {
      final storage = MemoryPinStorage();
      final first = await configured(storage, FakeBiometrics());
      await first.enableBiometrics('123456');
      final legacy = jsonDecode(storage.value!) as Map<String, dynamic>;
      legacy['faceIdEnabled'] = legacy.remove('biometricEnabled');
      storage.value = jsonEncode(legacy);
      final migrated = PinLockStore(
        storage: storage,
        derive: fakeDerive,
        biometrics: FakeBiometrics(),
      );
      await migrated.initialize();
      expect(migrated.biometricEnabled, isTrue);
      expect(migrated.unlocked, isFalse);
      expect(await migrated.unlock('123456'), isNull);
      expect(migrated.biometricEnabled, isTrue);
      first.dispose();
      migrated.dispose();
    },
  );

  testWidgets('Fingerprint choice and PIN choice both work on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sensor = FakeBiometrics()
      ..sensor = const BiometricCapability(
        BiometricKind.fingerprint,
        'Fingerprint',
      );
    final lock = await configured(MemoryPinStorage(), sensor);
    await lock.enableBiometrics('123456');
    lock.lock();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => AppLockGate(store: lock, child: child!),
        home: const Scaffold(body: Text('Private wallet')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fingerprint'), findsNothing);
    expect(find.text('PIN passcode'), findsNothing);
    expect(find.byKey(const ValueKey('face-id-symbol')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('choose-pin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-pin-field')), findsOneWidget);
    await tester.tap(find.byTooltip('Back to unlock options'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-pin-field')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('choose-biometrics')));
    await tester.pumpAndSettle();
    expect(lock.unlocked, isTrue);
    await tester.pumpWidget(const SizedBox());
    lock.dispose();
  });
}
