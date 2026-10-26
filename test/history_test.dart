import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

import 'package:kina_wallet/models/demo_transaction.dart';
import 'package:kina_wallet/screens/transaction_details_screen.dart';

void main() {
  testWidgets(
    'A limited list omits older rows without changing the full list',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TransactionList(limit: 2))),
      );
      expect(find.text('Money received'), findsOneWidget);
      expect(find.text('Electricity'), findsOneWidget);
      expect(find.text('Mobile top-up'), findsNothing);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TransactionList())),
      );
      expect(find.text('Mobile top-up'), findsOneWidget);
    },
  );

  testWidgets(
    'Transactions appear only in History and filters preserve full saved history',
    (tester) async {
      await tester.pumpWidget(const TestWalletApp());
      expect(find.byType(TransactionList), findsNothing);
      expect(find.text('Recent transactions'), findsNothing);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Transaction History'), findsOneWidget);
      expect(find.text('Money in'), findsNothing);
      expect(find.text('Money out'), findsNothing);
      expect(
        tester.widget<TransactionList>(find.byType(TransactionList)).limit,
        isNull,
      );
      expect(find.text('Electricity'), findsOneWidget);
      await tester.tap(find.byTooltip('Filter transactions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Money sent and payments'));
      await tester.pumpAndSettle();
      expect(find.text('Money received'), findsNothing);
      expect(find.text('Electricity'), findsOneWidget);
      await tester.tap(find.byTooltip('Filter transactions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All transactions'));
      await tester.pumpAndSettle();
      expect(find.text('Money received'), findsOneWidget);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionList), findsNothing);
    },
  );

  test('Old records load without inventing a date or reference', () {
    final old = DemoTransaction.fromJson({
      'title': 'Old entry',
      'detail': 'Existing details',
      'amountToea': -100,
      'icon': 'sent',
    });
    expect(old.createdAt, isNull);
    expect(old.reference, isNull);
    expect(old.formattedDate, 'Not recorded for this older demo entry');
  });

  testWidgets('Details display recorded dates and references', (tester) async {
    final transaction = DemoTransaction(
      'New demo',
      'Details',
      -100,
      Icons.north_east,
      createdAt: DateTime.utc(2026, 10, 14, 0, 30),
      reference: 'DEMO-TEST',
    );
    await tester.pumpWidget(
      MaterialApp(home: TransactionDetailsScreen(transaction: transaction)),
    );
    await tester.scrollUntilVisible(
      find.text('DEMO-TEST'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('DEMO-TEST'), findsOneWidget);
    expect(find.text(transaction.formattedDate), findsOneWidget);
  });
}
