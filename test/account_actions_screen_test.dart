import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/models/account_actions_store.dart';
import 'package:kina_wallet/screens/account_help_screen.dart';
import 'package:kina_wallet/screens/reset_password_screen.dart';
import 'package:kina_wallet/screens/delete_account_screen.dart';

import 'account_actions_test.dart' show FakeActions;

void main() {
  testWidgets('Recovery selection works in MaterialApp builder', (
    tester,
  ) async {
    final store = AccountActionsStore(gateway: FakeActions())
      ..enterRecovery('A', 'session-a');
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            AccountRecoveryGate(store: store, child: child!),
        home: const Scaffold(body: Text('Hidden wallet')),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'long-password',
    );
    await tester.longPress(find.byKey(const ValueKey('new-password')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Recovery gate hides wallet until a matching new password is saved',
    (tester) async {
      final api = FakeActions();
      final store = AccountActionsStore(gateway: api)
        ..enterRecovery('A', 'session-a');
      await tester.pumpWidget(
        MaterialApp(
          home: AccountRecoveryGate(
            store: store,
            child: const Text('Private wallet'),
          ),
        ),
      );
      expect(find.text('Private wallet'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('new-password')),
        'long-new-password',
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirm-new-password')),
        'long-new-password',
      );
      await tester.ensureVisible(find.text('Save new password'));
      await tester.tap(find.text('Save new password'));
      await tester.pumpAndSettle();
      expect(api.updates, 1);
      expect(
        find.text('Password updated. Sign in with your new password.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Back to wallet'));
      await tester.pumpAndSettle();
      expect(find.text('Private wallet'), findsOneWidget);
    },
  );
  testWidgets('Expired callback gives a recoverable error page', (
    tester,
  ) async {
    final store = AccountActionsStore()..failLink();
    await tester.pumpWidget(
      MaterialApp(
        home: AccountRecoveryGate(store: store, child: const Text('Wallet')),
      ),
    );
    expect(find.text('Wallet'), findsNothing);
    expect(find.textContaining('expired'), findsOneWidget);
    await tester.tap(find.text('Return to wallet'));
    await tester.pumpAndSettle();
    expect(find.text('Wallet'), findsOneWidget);
  });
  testWidgets(
    'Password help requests a reset without exposing account existence',
    (tester) async {
      final api = FakeActions();
      final store = AccountActionsStore(gateway: api);
      await tester.pumpWidget(
        MaterialApp(home: AccountHelpScreen(store: store)),
      );
      await tester.enterText(
        find.byKey(const ValueKey('reset-email')),
        'a@example.com',
      );
      await tester.ensureVisible(find.text('Send reset link'));
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(api.resets, 1);
      expect(find.textContaining('If this email'), findsOneWidget);
    },
  );
  testWidgets(
    'Deletion screen does not call server without typed confirmation',
    (tester) async {
      final api = FakeActions();
      final store = AccountActionsStore(gateway: api);
      await tester.pumpWidget(
        MaterialApp(
          home: DeleteAccountScreen(
            accountId: 'A',
            email: 'a@example.com',
            store: store,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('delete-password')),
        'current-password',
      );
      await tester.ensureVisible(find.text('Permanently delete test account'));
      await tester.tap(find.text('Permanently delete test account'));
      await tester.pumpAndSettle();
      expect(api.deletes, 0);
      expect(find.textContaining('Confirm deletion'), findsOneWidget);
    },
  );
}
