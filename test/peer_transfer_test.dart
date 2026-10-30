import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/models/cloud_wallet.dart';
import 'package:kina_wallet/models/wallet_store.dart';
import 'package:kina_wallet/models/demo_transaction.dart';
import 'package:kina_wallet/models/demo_qr.dart';
import 'package:kina_wallet/models/recipient.dart';

import 'support/memory_preferences.dart';

const sender = '11111111-1111-4111-8111-111111111111';
const receiver = '22222222-2222-4222-8222-222222222222';

class PeerCloud implements CloudWalletGateway, CloudRecipientDirectory {
  final wallets = <String, CloudWalletSnapshot>{
    sender: CloudWalletSnapshot(10000, []),
    receiver: CloudWalletSnapshot(0, []),
  };
  final commands = <String, CloudWalletSnapshot>{};
  bool loseReply = false;
  @override
  Future<VerifiedDemoRecipient> lookup(String owner, String target) async {
    if (owner == target || !wallets.containsKey(target)) {
      throw const CloudWalletRejected('Invalid target');
    }
    return VerifiedDemoRecipient(
      accountId: target,
      displayName: 'Recipient demo',
    );
  }

  @override
  Future<CloudWalletSnapshot> load(String owner) async => wallets[owner]!;
  @override
  Future<CloudWalletSnapshot> post(
    String owner,
    CloudWalletCommand command,
  ) async {
    final key = '$owner/${command.id}';
    final snapshot = commands.putIfAbsent(key, () {
      final target = command.recipientAccountId!;
      final amount = command.transaction.amountToea.abs();
      final date = DateTime.utc(2026, 10, 30);
      const ref = 'CLOUD-TRANSFER-test';
      wallets[target] = CloudWalletSnapshot(
        wallets[target]!.balanceToea + amount,
        [
          DemoTransaction(
            'Received demo transfer',
            'Fictional funds',
            amount,
            Icons.south_west,
            createdAt: date,
            reference: ref,
          ),
          ...wallets[target]!.transactions,
        ],
      );
      return wallets[owner] = CloudWalletSnapshot(
        wallets[owner]!.balanceToea - amount,
        [
          DemoTransaction(
            'Sent demo transfer',
            'Fictional funds',
            -amount,
            Icons.north_east,
            createdAt: date,
            reference: ref,
          ),
          ...wallets[owner]!.transactions,
        ],
        transferReference: ref,
        transferCreatedAt: date,
      );
    });
    if (loseReply) {
      loseReply = false;
      throw TimeoutException('Committed but response lost');
    }
    return snapshot;
  }
}

void main() {
  test('A stale cloud review cannot debit the local wallet after sign-out',()async{
    final wallet=WalletStore(preferences:MemoryPreferences());await wallet.initialize();
    wallet.configureCloud(PeerCloud());await wallet.useAccount(sender);await wallet.useAccount(null);
    final local=wallet.exportDemoSnapshot();
    expect(await wallet.sendDemoMoney(recipientName:'Peer',phoneNumber:'',amountToea:1000,recipientAccountId:receiver,expectedSenderId:sender),isNotNull);
    expect(wallet.exportDemoSnapshot(),local);
  });

  test('Cloud QR carries immutable receiving code and supports accounts without phone numbers', () {
    final raw = DemoQr.encode(
      const Recipient(name: 'Recipient', phoneNumber: '', accountId: receiver),
    );
    final decoded = DemoQr.decode(raw);
    expect(decoded.accountId, receiver);
    expect(decoded.phoneNumber, isEmpty);
  });
  test('Pending transfer command keeps recipient ID across serialization', () {
    final command = CloudWalletCommand(
      'request',
      const DemoTransaction('Sent', 'Demo', -1000, Icons.north_east),
      recipientAccountId: receiver,
    );
    expect(
      CloudWalletCommand.fromJson(command.toJson()).recipientAccountId,
      receiver,
    );
  });
  test('A lost response and restart cannot credit the peer twice', () async {
    final prefs = MemoryPreferences();
    final cloud = PeerCloud()..loseReply = true;
    final wallet = WalletStore(preferences: prefs);
    await wallet.initialize();
    wallet.configureCloud(cloud);
    await wallet.useAccount(sender);
    final verified = await wallet.verifyCloudRecipient(receiver);
    expect(verified.displayName, 'Recipient demo');
    expect(
      await wallet.sendDemoMoney(
        recipientName: verified.displayName,
        phoneNumber: '',
        amountToea: 1000,
        recipientAccountId: receiver,
        expectedSenderId: sender,
      ),
      isNotNull,
    );
    final reopened = WalletStore(preferences: prefs);
    await reopened.initialize();
    reopened.configureCloud(cloud);
    await reopened.useAccount(sender);
    expect(await reopened.retryPendingCloudUpdate(), isNull);
    expect(reopened.balanceToea, 9000);
    expect(cloud.wallets[receiver]!.balanceToea, 1000);
    expect(cloud.wallets[receiver]!.transactions.length, 1);
    expect(
      reopened.lastTransferReference,
      cloud.wallets[receiver]!.transactions.single.reference,
    );
  });
  test('Cloud sends require another account and the captured sender', () async {
    final wallet = WalletStore(preferences: MemoryPreferences());
    await wallet.initialize();
    wallet.configureCloud(PeerCloud());
    await wallet.useAccount(sender);
    expect(
      await wallet.sendDemoMoney(
        recipientName: 'Any',
        phoneNumber: '71111111',
        amountToea: 1000,
      ),
      isNotNull,
    );
    expect(
      await wallet.sendDemoMoney(
        recipientName: 'Self',
        phoneNumber: '',
        amountToea: 1000,
        recipientAccountId: sender,
        expectedSenderId: sender,
      ),
      isNotNull,
    );
    expect(
      await wallet.sendDemoMoney(
        recipientName: 'Peer',
        phoneNumber: '',
        amountToea: 1000,
        recipientAccountId: receiver,
        expectedSenderId: 'other',
      ),
      isNotNull,
    );
    expect(wallet.balanceToea, 10000);
  });
}
