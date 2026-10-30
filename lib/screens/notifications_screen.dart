import 'dart:async';

import 'package:flutter/material.dart';

import '../models/transfer_notifications.dart';
import '../models/demo_transaction.dart';
import '../screens/transaction_details_screen.dart';
import '../widgets/wallet_design.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.store});
  final TransferNotificationStore? store;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final store = widget.store ?? transferNotifications;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(store.refresh());
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F9FC),
    appBar: AppBar(
      title: const Text('Notifications'),
      backgroundColor: designBlue,
      foregroundColor: Colors.white,
      toolbarHeight: 80,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh notifications',
          onPressed: () => store.refresh(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => RefreshIndicator(
          onRefresh: store.refresh,
          child: ListView(
            padding: const EdgeInsets.all(24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const Text(
                'Latest transfers',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Demo transfers only · Fictional funds',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              if (store.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(store.error!, semanticsLabel: store.error),
                ),
              if (store.loading && store.items.isEmpty)
                const Center(child: CircularProgressIndicator()),
              if (!store.loading && store.items.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.notifications_none_rounded,
                          size: 44,
                          color: designBlue,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          store.accountId == null
                              ? 'Sign in to see transfer notifications'
                              : 'No transfer notifications yet',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              for (final item in store.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Icon(
                        item.amountToea > 0
                            ? Icons.south_west
                            : Icons.north_east,
                        color: designBlue,
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: item.isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text(item.message),
                          const SizedBox(height: 6),
                          Text(
                            item.createdAt.toLocal().toString().substring(
                              0,
                              16,
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      trailing: item.isRead
                          ? null
                          : const Icon(
                              Icons.circle,
                              size: 10,
                              color: designBlue,
                              semanticLabel: 'Unread',
                            ),
                      onTap: () {
                        unawaited(store.markRead(item.id));
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TransactionDetailsScreen(
                              transaction: DemoTransaction(
                                item.title,
                                'Cloud demo transfer · Fictional funds',
                                item.amountToea,
                                item.amountToea > 0
                                    ? Icons.south_west
                                    : Icons.north_east,
                                createdAt: item.createdAt,
                                reference: item.reference,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              if (store.items.length == 100)
                const Text(
                  'Showing the latest 100 transfers. Older entries remain in History.',
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
