import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('Balance privacy toggle and tab navigation work', (tester) async {
    await tester.pumpWidget(const TestWalletApp());
    expect(find.text('K 1250.00'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide balance'));
    await tester.pump();
    expect(find.text('K 1250.00'), findsNothing);
    expect(find.text('K ••••••'), findsOneWidget);
    await tester.tap(find.byTooltip('Show balance'));
    await tester.pump();
    expect(find.text('K 1250.00'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_outline).last);
    await tester.pumpAndSettle();
    expect(
      find.text('No registration or verification completed'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Home services screen opens a service and bell opens notifications',
    (tester) async {
      await tester.pumpWidget(const TestWalletApp());
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('No notifications yet'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('No notifications yet'), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('services-view-all')).hitTestable(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('services-view-all')));
      await tester.pumpAndSettle();
      for (final label in ['Mobile Top-Up', 'Pay Bills', 'Cash In']) {
        expect(
          find.descendant(
            of: find.byType(Scaffold).last,
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('All Services'), findsOneWidget);
      expect(find.text('Electricity'), findsNothing);
      await tester.tap(find.text('Pay Bills'));
      await tester.pumpAndSettle();
      for (final bill in ['Electricity', 'Water', 'Rent']) {
        expect(find.text(bill), findsOneWidget);
      }
      await tester.tap(find.text('Water'));
      await tester.pumpAndSettle();
      expect(find.text('Water demo payment'), findsOneWidget);
      expect(
        find.text('Choose a service to make a demo payment.'),
        findsNothing,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Choose a bill'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('All Services'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Services'), findsNWidgets(2));
    },
  );
  testWidgets(
    'All Home shortcuts survive a theme rebuild and open their screens',
    (tester) async {
      await tester.pumpWidget(const TestWalletApp());
      for (final entry in {
        'Send': 'Send to someone in PNG',
        'Receive': 'Your receiving QR',
        'Pay Bills': 'Choose a bill',
        'Cash In': 'Top up your demo wallet',
        'Mobile Top-Up': 'Top up a mobile',
      }.entries) {
        final reload = tester.binding.reassembleApplication();
        await tester.pump();
        await reload;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final action = find.byKey(ValueKey('home-action-${entry.key}'));
        await tester.scrollUntilVisible(
          action.hitTestable(),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(action, findsOneWidget);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
