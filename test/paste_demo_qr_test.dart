import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/screens/paste_demo_qr_screen.dart';
import 'package:kina_wallet/models/wallet_store.dart';

void main() {
  testWidgets(
    'Invalid QR stays on form; example prefills transfer without changing funds',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final balance = walletStore.balanceToea;
      final count = walletStore.transactions.length;
      await tester.pumpWidget(const MaterialApp(home: PasteDemoQrScreen()));
      await tester.enterText(find.byType(TextFormField), 'bad data');
      await tester.tap(find.text('Continue to transfer'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid demo QR data.'), findsOneWidget);
      await tester.tap(find.text('Load demo example'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to transfer'));
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields[0].controller!.text, 'Demo PNG Shop');
      expect(fields[1].controller!.text, '71234567');
      expect(fields[2].controller!.text, isEmpty);
      expect(walletStore.balanceToea, balance);
      expect(walletStore.transactions.length, count);
    },
  );
}
