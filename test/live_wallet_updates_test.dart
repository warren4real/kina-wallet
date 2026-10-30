import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/models/cloud_wallet.dart';
import 'package:kina_wallet/models/wallet_store.dart';
import 'package:kina_wallet/models/transfer_notifications.dart';
import 'package:kina_wallet/widgets/live_wallet_updates.dart';

import 'support/memory_preferences.dart';

class LiveGateway implements CloudWalletGateway {
  int balance = 1000, loads = 0;
  @override
  Future<CloudWalletSnapshot> load(String owner) async {
    loads++;
    return CloudWalletSnapshot(balance, []);
  }

  @override
  Future<CloudWalletSnapshot> post(
    String owner,
    CloudWalletCommand command,
  ) async => load(owner);
}

void main() {
  testWidgets(
    'refreshes wallet on timer and resume; pauses in background and disposes timer',
    (tester) async {
      final gateway = LiveGateway();
      final wallet = WalletStore(preferences: MemoryPreferences())
        ..configureCloud(gateway);
      await wallet.useAccount('A');
      final notifications = TransferNotificationStore();
      await tester.pumpWidget(
        LiveWalletUpdates(
          wallet: wallet,
          notifications: notifications,
          interval: const Duration(seconds: 10),
          child: const SizedBox(),
        ),
      );
      await tester.pumpAndSettle();
      gateway.balance = 2000;
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(wallet.balanceToea, 2000);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final before = gateway.loads;
      gateway.balance = 3000;
      await tester.pump(const Duration(seconds: 30));
      expect(gateway.loads, before);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(wallet.balanceToea, 3000);
      await tester.pumpWidget(const SizedBox());
      final disposed = gateway.loads;
      await tester.pump(const Duration(seconds: 30));
      expect(gateway.loads, disposed);
      wallet.dispose();
      notifications.dispose();
    },
  );
}
