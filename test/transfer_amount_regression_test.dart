import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/screens/send_money_screen.dart';
import 'package:kina_wallet/screens/review_transfer_screen.dart';

void main() {
  for (final sample in const [
    ('0.29', 29),
    ('1.01', 101),
    ('10000', 1000000),
  ]) {
    testWidgets('Transfer ${sample.$1} reaches review as exact integer toea', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: SendMoneyScreen()));
      await tester.enterText(find.byType(TextFormField).at(0), 'Demo');
      await tester.enterText(find.byType(TextFormField).at(1), '71234567');
      await tester.enterText(find.byType(TextFormField).at(2), sample.$1);
      await tester.tap(find.text('Review transfer'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ReviewTransferScreen>(find.byType(ReviewTransferScreen))
            .amountToea,
        sample.$2,
      );
    });
  }

  testWidgets(
    'Oversized amounts stay on the transfer form instead of reaching confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: SendMoneyScreen()));
      await tester.enterText(find.byType(TextFormField).at(0), 'Demo');
      await tester.enterText(find.byType(TextFormField).at(1), '71234567');
      await tester.enterText(find.byType(TextFormField).at(2), '1${'0' * 307}');
      await tester.tap(find.text('Review transfer'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewTransferScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
