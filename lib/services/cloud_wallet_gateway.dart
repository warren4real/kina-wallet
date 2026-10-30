import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cloud_wallet.dart';

class SupabaseCloudWallet
    implements CloudWalletGateway, CloudRecipientDirectory, CloudRequestLookup {
  SupabaseCloudWallet(this.client);
  final SupabaseClient client;

  Future<CloudWalletSnapshot> _call(
    String accountId,
    String function, [
    Map<String, dynamic>? params,
  ]) async {
    if (client.auth.currentUser?.id != accountId) {
      throw const CloudWalletRejected(
        'Your account changed. Reopen the wallet before retrying.',
      );
    }
    try {
      final result = await client
          .rpc(function, params: {'p_expected_user': accountId, ...?params})
          .timeout(const Duration(seconds: 20));
      return CloudWalletSnapshot.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } on PostgrestException catch (error) {
      if (error.code == 'P0001') {
        throw const CloudWalletRejected(
          'Not enough cloud demo balance. Add demo money first.',
        );
      }
      if (error.code == 'P0002') {
        throw const CloudWalletRejected(
          'No confirmed demo account matches that receiving code.',
        );
      }
      if (error.code == '22003') {
        throw const CloudWalletRejected(
          'The recipient demo balance limit would be exceeded.',
        );
      }
      if (error.code == '22023') {
        throw const CloudWalletRejected(
          'Demo update rejected. Use valid details and K 0.01–10,000.00 per update.',
        );
      }
      if (error.code == '28000' || error.code == '42501') {
        throw const CloudWalletRejected(
          'Sign in with a confirmed test account before updating this wallet.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<CloudWalletSnapshot> load(String accountId) =>
      _call(accountId, 'cloud_demo_snapshot');
  @override
  Future<CloudWalletSnapshot> post(
    String accountId,
    CloudWalletCommand command,
  ) {
    if (command.recipientAccountId != null) {
      return _call(accountId, 'transfer_demo_funds', {
        'p_request_id': command.id,
        'p_recipient': command.recipientAccountId,
        'p_amount_toea': command.transaction.amountToea.abs(),
      });
    }
    final transaction = command.transaction.toJson();
    return _call(accountId, 'post_cloud_demo_transaction', {
      'p_request_id': command.id,
      'p_kind': transaction['icon'],
      'p_title': transaction['title'],
      'p_detail': transaction['detail'],
      'p_amount_toea': transaction['amountToea'],
    });
  }

  @override
  Future<VerifiedDemoRecipient> lookup(
    String accountId,
    String recipientAccountId,
  ) async {
    if (client.auth.currentUser?.id != accountId) {
      throw const CloudWalletRejected('Your account changed.');
    }
    try {
      final result = await client
          .rpc(
            'find_demo_recipient',
            params: {
              'p_expected_user': accountId,
              'p_recipient': recipientAccountId,
            },
          )
          .timeout(const Duration(seconds: 20));
      return VerifiedDemoRecipient(
        accountId: result['accountId'] as String,
        displayName: result['displayName'] as String,
      );
    } on PostgrestException {
      throw const CloudWalletRejected(
        'No other confirmed demo account matches that receiving code.',
      );
    }
  }

  @override
  Future<CloudRequestReceipt?> findRequest(
    String accountId,
    String requestId,
  ) async {
    if (client.auth.currentUser?.id != accountId) {
      throw const CloudWalletRejected('Your account changed.');
    }
    final result = await client
        .rpc(
          'cloud_demo_request_status',
          params: {'p_expected_user': accountId, 'p_request_id': requestId},
        )
        .timeout(const Duration(seconds: 20));
    if (result == null) return null;
    return CloudRequestReceipt(
      reference: result['reference'] as String,
      createdAt: DateTime.parse(result['createdAt'] as String),
    );
  }
}
