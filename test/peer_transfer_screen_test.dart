import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/models/wallet_store.dart';
import 'package:kina_wallet/models/recipient.dart';
import 'package:kina_wallet/screens/send_money_screen.dart';
import 'package:kina_wallet/screens/review_transfer_screen.dart';

import 'peer_transfer_test.dart' show PeerCloud, sender, receiver;
import 'support/memory_preferences.dart';

void main() {
  testWidgets(
    'Cloud send matches account before reviewing and credits the peer once',
    (tester) async {
      final cloud = PeerCloud();
      final wallet = WalletStore(preferences: MemoryPreferences());
      await wallet.initialize();
      wallet.configureCloud(cloud);
      await wallet.useAccount(sender);
      await tester.pumpWidget(
        MaterialApp(
          home: SendMoneyScreen(
            store: wallet,
            initialRecipient: const Recipient(
              name: 'Untrusted contact label',
              phoneNumber: '',
              accountId: receiver,
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('transfer-amount')),
        '10',
      );
      await tester.ensureVisible(find.text('Review transfer'));
      await tester.tap(find.text('Review transfer'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewTransferScreen), findsOneWidget);
      expect(find.text('Recipient demo'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Confirm demo transfer'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ReviewTransferScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Confirm demo transfer'));
      await tester.pumpAndSettle();
      expect(wallet.balanceToea, 9000);
      expect(cloud.wallets[receiver]!.balanceToea, 1000);
      expect(find.text('Demo transfer complete'), findsOneWidget);
    },
  );
}
