import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/recipient.dart';
import '../models/recipient_store.dart';

class SupabaseCloudRecipients implements CloudRecipientGateway {
  SupabaseCloudRecipients(this.client);
  final SupabaseClient client;
  void _owner(String id) {
    if (client.auth.currentUser?.id != id) {
      throw StateError('Active account changed');
    }
  }

  @override
  Future<List<Recipient>> load(String accountId) async {
    _owner(accountId);
    final rows = await client
        .from('cloud_demo_recipients')
        .select('name,phone_number,receiving_account_id')
        .eq('user_id', accountId)
        .order('name')
        .timeout(const Duration(seconds: 20));
    return rows
        .map(
          (row) => Recipient(
            name: row['name'] as String,
            phoneNumber: row['phone_number'] as String,
            accountId: row['receiving_account_id'] as String?,
          ),
        )
        .toList();
  }

  @override
  Future<void> save(
    String accountId,
    Recipient value, {
    String? originalPhone,
  }) async {
    _owner(accountId);
    if (originalPhone == null) {
      await client
          .from('cloud_demo_recipients')
          .insert({
            'user_id': accountId,
            'name': value.name,
            'phone_number': value.phoneNumber,
            'receiving_account_id': value.accountId,
          })
          .timeout(const Duration(seconds: 20));
    } else {
      await client
          .from('cloud_demo_recipients')
          .update({
            'name': value.name,
            'phone_number': value.phoneNumber,
            'receiving_account_id': value.accountId,
          })
          .eq('user_id', accountId)
          .eq('phone_number', originalPhone)
          .select('phone_number')
          .single()
          .timeout(const Duration(seconds: 20));
    }
  }

  @override
  Future<void> remove(String accountId, String phone) async {
    _owner(accountId);
    await client
        .from('cloud_demo_recipients')
        .delete()
        .eq('user_id', accountId)
        .eq('phone_number', phone)
        .timeout(const Duration(seconds: 20));
  }
}
