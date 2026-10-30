import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/models/recipient.dart';
import 'package:kina_wallet/models/recipient_store.dart';
import 'package:kina_wallet/screens/saved_recipients_screen.dart';

import 'cloud_recipient_test.dart' show MemoryRecipients;
import 'support/memory_preferences.dart';

void main() {
  testWidgets('Opening recipients fetches changes saved by another device', (
    tester,
  ) async {
    final cloud = MemoryRecipients();
    final store = RecipientStore(preferences: MemoryPreferences());
    await store.initialize();
    store.configureCloud(cloud);
    await store.useAccount('A');
    cloud.data['A'] = [
      const Recipient(name: 'From other phone', phoneNumber: '72222222'),
    ];
    await tester.pumpWidget(
      MaterialApp(home: SavedRecipientsScreen(store: store)),
    );
    await tester.pumpAndSettle();
    expect(find.text('From other phone'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('Refresh recipients'),
      ),
      findsOneWidget,
    );
    cloud.data['A']!.add(
      const Recipient(name: 'Second remote recipient', phoneNumber: '73333333'),
    );
    await tester.tap(find.byTooltip('Refresh recipients'));
    await tester.pumpAndSettle();
    expect(find.text('Second remote recipient'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
