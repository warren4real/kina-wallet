import 'support/memory_preferences.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/models/wallet_store.dart';

void main() {
  test(
    'Captured session, funds, transfers and electricity reload together',
    () async {
      final storage = MemoryPreferences();
      final wallet = WalletStore(preferences: storage);
      await wallet.initialize();
      expect(wallet.balanceToea, 133000);
      expect(wallet.transactions.length, 8);
      expect(await wallet.addDemoMoney(amountToea: 1000), isNull);
      expect(
        await wallet.sendDemoMoney(
          recipientName: 'Demo',
          phoneNumber: '71234567',
          amountToea: 5000,
        ),
        isNull,
      );
      expect(
        await wallet.payDemoElectricity(
          meterNumber: '12345678',
          amountToea: 2000,
        ),
        isNull,
      );
      final recent = wallet.transactions.take(3).toList();
      expect(
        recent.every(
          (item) =>
              item.createdAt != null && item.reference!.startsWith('DEMO-'),
        ),
        isTrue,
      );
      expect(recent.map((item) => item.reference).toSet().length, 3);
      expect(
        wallet.transactions
            .skip(3)
            .every((item) => item.createdAt == null && item.reference == null),
        isTrue,
      );
      final reopened = WalletStore(preferences: storage);
      await reopened.initialize();
      expect(reopened.balanceToea, 127000);
      expect(reopened.transactions.length, 11);
      expect(reopened.exportDemoSnapshot(), wallet.exportDemoSnapshot());
    },
  );

  test(
    'Insufficient balance and failed saving leave wallet unchanged',
    () async {
      final storage = MemoryPreferences();
      final wallet = WalletStore(preferences: storage);
      await wallet.initialize();
      final before = wallet.exportDemoSnapshot();
      expect(
        await wallet.sendDemoMoney(
          recipientName: 'Demo',
          phoneNumber: '71234567',
          amountToea: 999999,
        ),
        isNotNull,
      );
      storage.failWrites.value = true;
      expect(await wallet.addDemoMoney(amountToea: 1000), isNotNull);
      expect(wallet.exportDemoSnapshot(), before);
      storage.failWrites.value = false;
      final reopened = WalletStore(preferences: storage);
      await reopened.initialize();
      expect(reopened.exportDemoSnapshot(), before);
    },
  );

  test('Damaged saved data is reported without overwriting it', () async {
    final storage = MemoryPreferences();
    final wallet = WalletStore(preferences: storage);
    await wallet.initialize();
    storage.data.updateAll((key, value) => 'broken');
    final reopened = WalletStore(preferences: storage);
    await expectLater(reopened.initialize(), throwsFormatException);
    expect(storage.data.values.single, 'broken');
  });
}
