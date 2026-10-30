import 'demo_transaction.dart';

class CloudWalletSnapshot {
  CloudWalletSnapshot(
    this.balanceToea,
    this.transactions, {
    this.transferReference,
    this.transferCreatedAt,
  });
  final String? transferReference;
  final DateTime? transferCreatedAt;
  final int balanceToea;
  final List<DemoTransaction> transactions;
  factory CloudWalletSnapshot.fromJson(Map<String, dynamic> json) =>
      CloudWalletSnapshot(
        json['balanceToea'] as int,
        (json['transactions'] as List)
            .map(
              (item) => DemoTransaction.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        transferReference: json['transferReference'] as String?,
        transferCreatedAt: json['transferCreatedAt'] == null
            ? null
            : DateTime.parse(json['transferCreatedAt'] as String),
      );
}

class CloudWalletCommand {
  CloudWalletCommand(this.id, this.transaction, {this.recipientAccountId});
  final String? recipientAccountId;
  final String id;
  final DemoTransaction transaction;
  Map<String, dynamic> toJson() => {
    'id': id,
    'recipientAccountId': recipientAccountId,
    'transaction': transaction.toJson(),
  };
  factory CloudWalletCommand.fromJson(Map<String, dynamic> json) =>
      CloudWalletCommand(
        json['id'] as String,
        DemoTransaction.fromJson(
          Map<String, dynamic>.from(json['transaction'] as Map),
        ),
        recipientAccountId: json['recipientAccountId'] as String?,
      );
}

abstract interface class CloudWalletGateway {
  Future<CloudWalletSnapshot> load(String accountId);
  Future<CloudWalletSnapshot> post(
    String accountId,
    CloudWalletCommand command,
  );
}

class CloudWalletRejected implements Exception {
  const CloudWalletRejected(this.message);
  final String message;
}

class VerifiedDemoRecipient {
  const VerifiedDemoRecipient({
    required this.accountId,
    required this.displayName,
  });
  final String accountId, displayName;
}

abstract interface class CloudRecipientDirectory {
  Future<VerifiedDemoRecipient> lookup(
    String accountId,
    String recipientAccountId,
  );
}

bool isReceivingCode(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(value);

// Only a committed ledger entry can produce a recovery receipt.
class CloudRequestReceipt {
  const CloudRequestReceipt({required this.reference, required this.createdAt});
  final String reference;
  final DateTime createdAt;
}

abstract interface class CloudRequestLookup {
  Future<CloudRequestReceipt?> findRequest(String accountId, String requestId);
}

enum CloudOperationState { none, sending, pending, completed, failed }
