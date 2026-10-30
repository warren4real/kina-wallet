import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transfer_notifications.dart';

class SupabaseTransferNotifications implements TransferNotificationGateway {
  SupabaseTransferNotifications(this.client);
  final SupabaseClient client;
  void _check(String owner) {
    if (client.auth.currentUser?.id != owner) {
      throw StateError('Account changed');
    }
  }

  @override
  Future<NotificationSnapshot> load(String owner) async {
    _check(owner);
    final result = await client
        .rpc('demo_transfer_notifications', params: {'p_expected_user': owner})
        .timeout(const Duration(seconds: 20));
    return NotificationSnapshot(
      (result['items'] as List)
          .map(
            (n) => TransferNotification.fromJson(
              Map<String, dynamic>.from(n as Map),
            ),
          )
          .toList(),
      result['unreadCount'] as int,
    );
  }

  @override
  Future<void> markRead(String owner, String id) async {
    _check(owner);
    await client
        .rpc(
          'read_demo_transfer_notification',
          params: {'p_expected_user': owner, 'p_request_id': id},
        )
        .timeout(const Duration(seconds: 20));
  }
}
