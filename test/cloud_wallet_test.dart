import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:kina_wallet/models/wallet_store.dart';
import 'package:kina_wallet/models/cloud_wallet.dart';

import 'support/memory_preferences.dart';

class FakeCloud implements CloudWalletGateway {
  final wallets = <String, CloudWalletSnapshot>{};
  final requests = <String, CloudWalletSnapshot>{};
  bool loseResponse = false;
  Completer<CloudWalletSnapshot>? pendingLoad;
  int posts = 0;
  Completer<void>? postGate;
  @override
  Future<CloudWalletSnapshot> load(String accountId) async =>
      pendingLoad == null
      ? wallets.putIfAbsent(accountId, () => CloudWalletSnapshot(0, []))
      : pendingLoad!.future;
  @override
  Future<CloudWalletSnapshot> post(
    String accountId,
    CloudWalletCommand command,
  ) async {
    posts++;
    if (postGate != null) await postGate!.future;
    final key = '$accountId/${command.id}';
    final result = requests.putIfAbsent(key, () {
      final old = wallets[accountId]!;
      final updated = CloudWalletSnapshot(
        old.balanceToea + command.transaction.amountToea,
        [command.transaction, ...old.transactions],
      );
      wallets[accountId] = updated;
      return updated;
    });
    if (loseResponse) {
      loseResponse = false;
      throw TimeoutException('Response lost after commit');
    }
    return result;
  }
}

class DelayedPreferences extends MemoryPreferences {
  final block = ValueNotifier<Completer<void>?>(null);
  @override
  Future<void> setString(String key, String value) async {
    if (key == 'kina_wallet_demo_v1' && block.value != null) {
      await block.value!.future;
    }
    await super.setString(key, value);
  }
}

void main() {
  test(
    'Another phone restores the account balance and history from the server',
    () async {
      final cloud = FakeCloud();
      final first = WalletStore(preferences: MemoryPreferences());
      await first.initialize();
      first.configureCloud(cloud);
      await first.useAccount('A');
      expect(await first.addDemoMoney(amountToea: 5000), isNull);
      expect(
        await first.sendDemoMoney(
          recipientName: 'Demo',
          phoneNumber: '71234567',
          amountToea: 1500,
          recipientAccountId: '22222222-2222-4222-8222-222222222222',
          expectedSenderId: 'A',
        ),
        isNull,
      );
      final second = WalletStore(preferences: MemoryPreferences());
      await second.initialize();
      second.configureCloud(cloud);
      await second.useAccount('A');
      expect(second.balanceToea, 3500);
      expect(second.transactions.length, 2);
      expect(second.transactions.first.amountToea, -1500);
    },
  );

  test(
    'Returning to an account waits for its old write before allowing a new one',
    () async {
      final cloud = FakeCloud()..postGate = Completer<void>();
      final wallet = WalletStore(preferences: MemoryPreferences());
      await wallet.initialize();
      wallet.configureCloud(cloud);
      await wallet.useAccount('A');
      final writing = wallet.addDemoMoney(amountToea: 1000);
      await Future<void>.delayed(Duration.zero);
      await wallet.useAccount('B');
      await wallet.useAccount('A');
      expect(wallet.saving, isTrue);
      cloud.postGate!.complete();
      await writing;
      await Future<void>.delayed(Duration.zero);
      expect(wallet.balanceToea, 1000);
      expect(wallet.hasPendingCloudUpdate, isFalse);
      expect(wallet.saving, isFalse);
    },
  );

  test(
    'A local save completing after sign-in cannot overwrite the cloud wallet',
    () async {
      final prefs = DelayedPreferences();
      final wallet = WalletStore(preferences: prefs);
      await wallet.initialize();
      final starting = wallet.balanceToea;
      prefs.block.value = Completer<void>();
      final writing = wallet.addDemoMoney(amountToea: 1000);
      await Future<void>.delayed(Duration.zero);
      wallet.configureCloud(FakeCloud());
      await wallet.useAccount('B');
      prefs.block.value!.complete();
      expect(await writing, isNotNull);
      expect(wallet.balanceToea, 0);
      expect(wallet.transactions, isEmpty);
      await wallet.useAccount(null);
      expect(wallet.balanceToea, starting + 1000);
    },
  );

  test('Cloud accounts start empty and signing out restores the untouched local wallet', () async {
    final prefs = MemoryPreferences();
    final wallet = WalletStore(preferences: prefs);
    await wallet.initialize();
    final local = wallet.exportDemoSnapshot();
    final saved = Map.of(prefs.data);
    final cloud = FakeCloud();
    wallet.configureCloud(cloud);
    await wallet.useAccount('A');
    expect(wallet.balanceToea, 0);
    expect(wallet.transactions, isEmpty);
    expect(await wallet.addDemoMoney(amountToea: 5000), isNull);
    expect(wallet.balanceToea, 5000);
    await wallet.useAccount('B');
    expect(wallet.balanceToea, 0);
    await wallet.useAccount('A');
    expect(wallet.balanceToea, 5000);
    await wallet.useAccount(null);
    expect(wallet.exportDemoSnapshot(), local);
    expect(
      Map.fromEntries(
        prefs.data.entries.where(
          (e) => !e.key.startsWith('kina_cloud_pending_'),
        ),
      ),
      saved,
    );
  });

  test(
    'An uncertain committed deposit is retried with the same key after restart',
    () async {
      final prefs = MemoryPreferences();
      final cloud = FakeCloud()..loseResponse = true;
      final wallet = WalletStore(preferences: prefs);
      await wallet.initialize();
      wallet.configureCloud(cloud);
      await wallet.useAccount('A');
      expect(await wallet.addDemoMoney(amountToea: 5000), isNotNull);
      expect(wallet.hasPendingCloudUpdate, isTrue);
      expect(await wallet.addDemoMoney(amountToea: 7000), isNotNull);
      expect(cloud.posts, 1);
      final reopened = WalletStore(preferences: prefs);
      await reopened.initialize();
      reopened.configureCloud(cloud);
      await reopened.useAccount('A');
      expect(reopened.hasPendingCloudUpdate, isTrue);
      expect(await reopened.retryPendingCloudUpdate(), isNull);
      expect(reopened.balanceToea, 5000);
      expect(reopened.transactions.length, 1);
      expect(reopened.hasPendingCloudUpdate, isFalse);
      expect(cloud.posts, 2);
    },
  );

  test('An old account response cannot replace a different wallet', () async {
    final wallet = WalletStore(preferences: MemoryPreferences());
    await wallet.initialize();
    final cloud = FakeCloud()..pendingLoad = Completer<CloudWalletSnapshot>();
    wallet.configureCloud(cloud);
    final loading = wallet.useAccount('A');
    await wallet.useAccount(null);
    final local = wallet.exportDemoSnapshot();
    cloud.pendingLoad!.complete(CloudWalletSnapshot(9900, []));
    await loading;
    expect(wallet.isCloud, isFalse);
    expect(wallet.exportDemoSnapshot(), local);
  });

  test(
    'A cloud load failure blocks writes without using local demo funds',
    () async {
      final wallet = WalletStore(preferences: MemoryPreferences());
      await wallet.initialize();
      final cloud = FakeCloud()..pendingLoad = Completer<CloudWalletSnapshot>();
      wallet.configureCloud(cloud);
      final loading = wallet.useAccount('A');
      cloud.pendingLoad!.completeError(StateError('Offline'));
      await loading;
      expect(wallet.isCloud, isTrue);
      expect(wallet.cloudReady, isFalse);
      expect(wallet.balanceToea, 0);
      expect(await wallet.addDemoMoney(amountToea: 1000), isNotNull);
      expect(cloud.posts, 0);
    },
  );
}
