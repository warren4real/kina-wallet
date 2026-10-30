import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kina_wallet/widgets/cloud_wallet_status.dart';
import 'package:kina_wallet/screens/review_transfer_screen.dart';
import 'package:kina_wallet/models/cloud_wallet.dart';
import 'package:kina_wallet/models/wallet_store.dart';

import 'peer_transfer_test.dart' show PeerCloud, sender, receiver;
import 'support/memory_preferences.dart';

class RecoverableCloud extends PeerCloud implements CloudRequestLookup {
  int posts = 0;
  bool offline = false, dropBeforeCommit = false, reject = false;
  Completer<void>? gate;
  Completer<CloudRequestReceipt?>? lookupGate;
  final ids = <String>[];
  @override
  Future<CloudWalletSnapshot> load(String owner) async {
    if (offline) throw TimeoutException('Offline');
    return super.load(owner);
  }

  @override
  Future<CloudRequestReceipt?> findRequest(
    String owner,
    String requestId,
  ) async {
    if (offline) throw TimeoutException('Offline');
    if (lookupGate != null) return lookupGate!.future;
    final done = commands['$owner/$requestId'];
    return done == null
        ? null
        : CloudRequestReceipt(
            reference: done.transferReference!,
            createdAt: done.transferCreatedAt!,
          );
  }

  @override
  Future<CloudWalletSnapshot> post(
    String owner,
    CloudWalletCommand command,
  ) async {
    posts++;
    ids.add(command.id);
    if (gate != null) await gate!.future;
    if (reject) throw const CloudWalletRejected('Recipient is unavailable.');
    if (dropBeforeCommit) {
      dropBeforeCommit = false;
      throw TimeoutException('No request reached server');
    }
    return super.post(owner, command);
  }
}

class FailClearPreferences extends MemoryPreferences {
  final failClear = ValueNotifier(true);
  @override
  Future<void> setString(String key, String value) async {
    if (failClear.value &&
        key.startsWith('kina_cloud_pending_') &&
        value.isEmpty) {
      throw StateError('Cannot save confirmation');
    }
    await super.setString(key, value);
  }
}

Future<WalletStore> open(
  RecoverableCloud cloud,
  MemoryPreferences prefs,
) async {
  final wallet = WalletStore(preferences: prefs);
  await wallet.initialize();
  wallet.configureCloud(cloud);
  await wallet.useAccount(sender);
  return wallet;
}

Future<String?> send(WalletStore wallet) => wallet.sendDemoMoney(
  recipientName: 'Receiver',
  phoneNumber: '',
  amountToea: 1000,
  recipientAccountId: receiver,
  expectedSenderId: sender,
);
void main() {
  test('committed transfer with lost response is reconciled after restart without resending', () async {
    final cloud = RecoverableCloud()..loseReply = true;
    final prefs = MemoryPreferences();
    final wallet = await open(cloud, prefs);
    expect(await send(wallet), isNotNull);
    expect(wallet.cloudOperationState, CloudOperationState.pending);
    final reopened = await open(cloud, prefs);
    expect(reopened.cloudOperationState, CloudOperationState.completed);
    expect(reopened.hasPendingCloudUpdate, false);
    expect(cloud.posts, 1);
    expect(reopened.balanceToea, 9000);
    expect(cloud.wallets[receiver]!.balanceToea, 1000);
  });
  test('uncommitted interruption stays pending and explicit retry uses the same saved request', () async {
    final cloud = RecoverableCloud()..dropBeforeCommit = true;
    final prefs = MemoryPreferences();
    final wallet = await open(cloud, prefs);
    await send(wallet);
    final reopened = await open(cloud, prefs);
    expect(reopened.cloudOperationState, CloudOperationState.pending);
    expect(cloud.posts, 1);
    expect(await reopened.retryPendingCloudUpdate(), isNull);
    expect(cloud.ids.toSet().length, 1);
    expect(cloud.wallets[receiver]!.balanceToea, 1000);
    expect(reopened.cloudOperationState, CloudOperationState.completed);
  });
  test(
    'offline refresh preserves last sync and balance; reconnect recovers',
    () async {
      final cloud = RecoverableCloud();
      final wallet = await open(cloud, MemoryPreferences());
      final synced = wallet.lastCloudSyncAt;
      expect(synced, isNotNull);
      cloud.offline = true;
      await wallet.refreshCloud();
      expect(wallet.cloudUnavailable, true);
      expect(wallet.lastCloudSyncAt, synced);
      expect(wallet.balanceToea, 10000);
      expect(await send(wallet), isNotNull);
      expect(cloud.posts, 0);
      cloud.offline = false;
      await wallet.refreshCloud();
      expect(wallet.cloudUnavailable, false);
    },
  );
  test('rejected transfer is failed, not pending or completed', () async {
    final cloud = RecoverableCloud()..reject = true;
    final wallet = await open(cloud, MemoryPreferences());
    expect(await send(wallet), isNotNull);
    expect(wallet.cloudOperationState, CloudOperationState.failed);
    expect(wallet.hasPendingCloudUpdate, false);
    expect(wallet.balanceToea, 10000);
    expect(wallet.cloudUnavailable, false);
  });
  test('sending state disables repeated writes; late completion cannot populate another account', () async {
    final cloud = RecoverableCloud()..gate = Completer<void>();
    final wallet = await open(cloud, MemoryPreferences());
    final writing = send(wallet);
    await Future<void>.delayed(Duration.zero);
    expect(wallet.cloudOperationState, CloudOperationState.sending);
    expect(await send(wallet), isNotNull);
    await wallet.useAccount(receiver);
    expect(wallet.cloudOperationState, CloudOperationState.none);
    cloud.gate!.complete();
    await writing;
    expect(wallet.accountId, receiver);
    expect(wallet.cloudOperationState, CloudOperationState.none);
    await wallet.refreshCloud();
    expect(wallet.balanceToea, 1000);
    await wallet.useAccount(sender);
    expect(wallet.balanceToea, 9000);
    expect(cloud.posts, 1);
  });
  test(
    'a late recovery lookup cannot clear or expose the next account state',
    () async {
      final cloud = RecoverableCloud()..loseReply = true;
      final wallet = await open(cloud, MemoryPreferences());
      await send(wallet);
      cloud.lookupGate = Completer<CloudRequestReceipt?>();
      final pending = wallet.refreshCloud();
      await Future<void>.delayed(Duration.zero);
      await wallet.useAccount(receiver);
      cloud.lookupGate!.complete(
        CloudRequestReceipt(
          reference: 'CLOUD-TRANSFER-test',
          createdAt: DateTime.utc(2026),
        ),
      );
      await pending;
      expect(wallet.accountId, receiver);
      expect(wallet.cloudOperationState, CloudOperationState.none);
      expect(wallet.lastTransferReference, isNull);
    },
  );
  test('a storage failure during retry cannot label the original unknown result as failed', () async {
    final cloud = RecoverableCloud()..dropBeforeCommit = true;
    final prefs = MemoryPreferences();
    final wallet = await open(cloud, prefs);
    await send(wallet);
    prefs.failWrites.value = true;
    expect(await wallet.retryPendingCloudUpdate(), isNotNull);
    expect(wallet.hasPendingCloudUpdate, true);
    expect(wallet.cloudOperationState, CloudOperationState.pending);
    expect(cloud.posts, 1);
    prefs.failWrites.value = false;
    expect(await wallet.retryPendingCloudUpdate(), isNull);
    expect(cloud.ids.toSet().length, 1);
    expect(cloud.wallets[receiver]!.balanceToea, 1000);
  });
  testWidgets(
    'pending status fits large text and Check status performs no write',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cloud = RecoverableCloud()..loseReply = true;
      final wallet = await open(cloud, MemoryPreferences());
      await send(wallet);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CloudWalletStatus(store: wallet),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pending confirmation'), findsOneWidget);
      await tester.ensureVisible(find.text('Check status'));
      await tester.tap(find.text('Check status'));
      await tester.pumpAndSettle();
      expect(cloud.posts, 1);
      expect(find.text('Completed'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      wallet.dispose();
    },
  );

  testWidgets(
    'a recovered completion cannot be sent again from the same review screen',
    (tester) async {
      final cloud = RecoverableCloud()..loseReply = true;
      final wallet = await open(cloud, MemoryPreferences());
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewTransferScreen(
            store: wallet,
            recipientName: 'Receiver',
            phoneNumber: '',
            amountToea: 1000,
            verifiedRecipient: const VerifiedDemoRecipient(
              accountId: receiver,
              displayName: 'Receiver',
            ),
            expectedSenderId: sender,
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('Confirm demo transfer'), 250);
      await tester.tap(find.text('Confirm demo transfer'));
      await tester.pumpAndSettle();
      expect(wallet.hasPendingCloudUpdate, true);
      await wallet.refreshCloud();
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(
        FilledButton,
        'Confirm demo transfer',
      );
      await tester.scrollUntilVisible(
        find.text('Confirm demo transfer'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.scrollUntilVisible(
        find.text('View completed transfer'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View completed transfer'));
      await tester.pumpAndSettle();
      expect(find.text('Demo transfer complete'), findsOneWidget);
      expect(cloud.posts, 1);
      expect(cloud.wallets[receiver]!.balanceToea, 1000);
      await tester.pumpWidget(const SizedBox());
      wallet.dispose();
    },
  );
  test('a server-confirmed request is not resubmitted when local confirmation cleanup fails', () async {
    final cloud = RecoverableCloud();
    final prefs = FailClearPreferences();
    final wallet = await open(cloud, prefs);
    expect(await send(wallet), isNotNull);
    expect(await wallet.retryPendingCloudUpdate(), isNotNull);
    expect(cloud.posts, 1);
    expect(wallet.hasPendingCloudUpdate, true);
    prefs.failClear.value = false;
    await wallet.refreshCloud();
    expect(wallet.hasPendingCloudUpdate, false);
    expect(wallet.cloudOperationState, CloudOperationState.completed);
    expect(cloud.wallets[receiver]!.balanceToea, 1000);
  });
}
