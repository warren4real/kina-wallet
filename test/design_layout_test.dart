import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

import 'package:kina_wallet/screens/all_services_screen.dart';
import 'package:kina_wallet/screens/pay_bills_screen.dart';
import 'package:kina_wallet/screens/notifications_screen.dart';

import 'package:kina_wallet/main.dart';
import 'package:kina_wallet/models/pin_lock_store.dart';
import 'package:kina_wallet/widgets/wallet_logo.dart';

import 'pin_lock_test.dart' show MemoryPinStorage, fakeDerive, NoBiometrics;

import 'package:kina_wallet/screens/activity_screen.dart';
import 'package:kina_wallet/screens/profile_screen.dart';
import 'package:kina_wallet/screens/send_money_screen.dart';
import 'package:kina_wallet/screens/transfer_receipt_screen.dart';

void main() {
  testWidgets('Phone layouts render without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TestWalletApp());
    final theme = Theme.of(tester.element(find.byType(NavigationBar)));
    for (final entry in <String, Widget>{
      'activity': const Scaffold(body: ActivityScreen()),
      'profile': const Scaffold(body: ProfileScreen()),
      'send': const SendMoneyScreen(),
      'services': const AllServicesScreen(),
      'bills': const PayBillsScreen(),
      'notifications': const NotificationsScreen(),
      'receipt': TransferReceiptScreen(
        recipientName: 'Demo PNG Shop',
        phoneNumber: '71234567',
        amount: 50,
        createdAt: DateTime(2026, 10, 14, 12, 30),
      ),
    }.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(theme: theme, home: entry.value),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: entry.key);
    }
  });
  testWidgets('Services supports large text on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: const AllServicesScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Pay Bills'), 200);
    expect(find.text('Pay Bills'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Branded lock screen fits a small phone with the PIN keyboard open',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final lock = PinLockStore(
        storage: MemoryPinStorage(),
        derive: fakeDerive,
        biometrics: NoBiometrics(),
      );
      await lock.initialize();
      await tester.pumpWidget(KinaWalletApp(lockStore: lock));
      await tester.pumpAndSettle();
      expect(find.byType(WalletLogo), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      lock.dispose();
    },
  );
}
