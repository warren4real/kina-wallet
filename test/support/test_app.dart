import 'package:flutter/material.dart';
import 'package:kina_wallet/main.dart';
import 'package:kina_wallet/models/pin_lock_store.dart';

class _UnlockedLock extends PinLockStore {
  @override
  bool get initialized => true;
  @override
  bool get unlocked => true;
  @override
  Future<void> initialize() async {}
  @override
  void setActive(bool active) {}
  @override
  Future<void> refreshBiometricAvailability() async {}
}

final _lock = _UnlockedLock();

class TestWalletApp extends StatelessWidget {
  const TestWalletApp({super.key});
  @override
  Widget build(BuildContext context) => KinaWalletApp(lockStore: _lock);
}
