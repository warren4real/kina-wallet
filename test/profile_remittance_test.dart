import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/models/profile_store.dart';
import 'package:kina_wallet/models/demo_qr.dart';
import 'package:kina_wallet/models/remittance_quote.dart';
import 'package:kina_wallet/models/wallet_store.dart';
import 'package:kina_wallet/screens/remittance_preview_screen.dart';

import 'support/memory_preferences.dart';

void main() {
  test('Profile survives reopening and provides QR details', () async {
    final preferences = MemoryPreferences();
    final profile = ProfileStore(preferences: preferences);
    await profile.initialize();
    expect(
      await profile.update(name: ' Demo Owner ', phoneNumber: '71234567'),
      isNull,
    );
    final reopened = ProfileStore(preferences: preferences);
    await reopened.initialize();
    expect(reopened.profile.name, 'Demo Owner');
    final decoded = DemoQr.decode(DemoQr.encode(reopened.profile));
    expect(decoded.name, 'Demo Owner');
    expect(decoded.phoneNumber, '71234567');
    expect(await reopened.update(name: '', phoneNumber: '123'), isNotNull);
    preferences.failWrites.value = true;
    expect(
      await reopened.update(name: 'Other Owner', phoneNumber: '70000001'),
      isNotNull,
    );
    expect(reopened.profile.name, 'Demo Owner');
  });

  test('Sample conversion separates fee from principal and rounds in toea', () {
    final quote = RemittanceQuote(100000);
    expect(quote.totalCentavos, 105000);
    expect(quote.recipientToea, 7000);
    expect(RemittanceQuote(8).recipientToea, 1);
    expect(RemittanceQuote.parseCentavos('1000.50'), 100050);
    expect(RemittanceQuote.parseCentavos('1.999'), isNull);
    expect(RemittanceQuote.parseCentavos('-1'), isNull);
    expect(() => RemittanceQuote(0), throwsArgumentError);
    expect(() => RemittanceQuote(10000001), throwsArgumentError);
  });

  testWidgets(
    'Overseas preview can be edited and finished without changing funds',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final before = walletStore.exportDemoSnapshot();
      await tester.pumpWidget(
        const MaterialApp(home: RemittancePreviewScreen()),
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Demo Recipient');
      await tester.enterText(fields.at(1), '71234567');
      await tester.enterText(fields.at(2), '1000');
      await tester.tap(find.text('Review sample quote'));
      await tester.pumpAndSettle();
      expect(find.text('PHP 1050.00'), findsOneWidget);
      expect(find.text('K 70.00'), findsNWidgets(2));
      await tester.tap(find.text('Edit details'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(fields.at(2)).controller!.text,
        '1000',
      );
      await tester.tap(find.text('Review sample quote'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish preview'));
      await tester.pumpAndSettle();
      expect(find.text('Preview complete'), findsOneWidget);
      expect(walletStore.exportDemoSnapshot(), before);
    },
  );
}
