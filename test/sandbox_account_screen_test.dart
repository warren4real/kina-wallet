import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/models/sandbox_account_store.dart';
import 'package:kina_wallet/screens/sandbox_account_screen.dart';

import 'sandbox_account_test.dart' show MemoryAccounts;

void main() {
  testWidgets(
    'Creating an account awaiting email confirmation does not display a signed-in profile',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = MemoryAccounts()..confirmationRequired = true;
      final store = SandboxAccountStore(gateway: gateway);
      await tester.pumpWidget(
        MaterialApp(home: SandboxAccountScreen(store: store)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create a test account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('sandbox-name')),
        'Test name',
      );
      await tester.enterText(
        find.byKey(const ValueKey('sandbox-email')),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('sandbox-password')),
        'long-test-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Check your email'), findsOneWidget);
      expect(find.text('Sign out'), findsNothing);
      expect(store.account, isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      await gateway.sessionEvents.close();
    },
  );

  testWidgets(
    'Account screen signs in and signs out while clearing password input',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = MemoryAccounts();
      final store = SandboxAccountStore(gateway: gateway);
      await tester.pumpWidget(
        MaterialApp(home: SandboxAccountScreen(store: store)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('sandbox-email')),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('sandbox-password')),
        'long-test-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Private test name'), findsNWidgets(2));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Private test name'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('sandbox-password')),
            )
            .controller!
            .text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      await gateway.sessionEvents.close();
    },
  );
}
