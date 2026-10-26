import 'package:flutter/material.dart';

import 'wallet_store.dart';
import '../screens/transaction_details_screen.dart';

class DemoTransaction {
  final String title;
  final String detail;
  final int amountToea;
  final IconData icon;
  final DateTime? createdAt;
  final String? reference;

  const DemoTransaction(
    this.title,
    this.detail,
    this.amountToea,
    this.icon, {
    this.createdAt,
    this.reference,
  });

  String get formattedDate {
    final date = createdAt?.toLocal();
    if (date == null) return 'Not recorded for this older demo entry';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} at ${two(date.hour)}:${two(date.minute)}';
  }

  String get formattedAmount =>
      '${amountToea >= 0 ? '+' : '−'}K '
      '${(amountToea.abs() / 100).toStringAsFixed(2)}';

  // Convert the transaction into values we can save.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'detail': detail,
      'amountToea': amountToea,
      'icon': _iconName(icon),
      'createdAt': createdAt?.toUtc().toIso8601String(),
      'reference': reference,
    };
  }

  // Recreate a transaction from saved values.
  factory DemoTransaction.fromJson(Map<String, dynamic> json) {
    return DemoTransaction(
      json['title'] as String,
      json['detail'] as String,
      json['amountToea'] as int,
      _iconFromName(json['icon'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      reference: json['reference'] as String?,
    );
  }

  static String _iconName(IconData icon) {
    if (icon == Icons.bolt) return 'electricity';
    if (icon == Icons.water_drop_outlined) return 'water';
    if (icon == Icons.phone_android) return 'mobile';
    if (icon == Icons.home_work_outlined) return 'rent';
    if (icon == Icons.north_east) return 'sent';
    return 'received';
  }

  static IconData _iconFromName(String name) {
    switch (name) {
      case 'electricity':
        return Icons.bolt;
      case 'water':
        return Icons.water_drop_outlined;
      case 'mobile':
        return Icons.phone_android;
      case 'rent':
        return Icons.home_work_outlined;
      case 'sent':
        return Icons.north_east;
      default:
        return Icons.south_west;
    }
  }
}

// Fictional examples, not live account information.
const demoBalanceToea = 125000;
const demoTransactions = [
  DemoTransaction(
    'Money received',
    'Family transfer · Today',
    30000,
    Icons.south_west,
  ),
  DemoTransaction(
    'Electricity',
    'Sample payment · Yesterday',
    -5000,
    Icons.bolt,
  ),
  DemoTransaction(
    'Mobile top-up',
    'Sample payment · Yesterday',
    -1000,
    Icons.phone_android,
  ),
];

enum TransactionFilter {
  all,
  incoming,
  outgoing;

  bool includes(DemoTransaction transaction) => switch (this) {
    all => true,
    incoming => transaction.amountToea > 0,
    outgoing => transaction.amountToea < 0,
  };
}

class TransactionList extends StatelessWidget {
  final int? limit;
  final WalletStore? store;
  final TransactionFilter filter;

  const TransactionList({
    super.key,
    this.limit,
    this.store,
    this.filter = TransactionFilter.all,
  }) : assert(limit == null || limit > 0);

  @override
  Widget build(BuildContext context) {
    final wallet = store ?? walletStore;
    return ListenableBuilder(
      listenable: wallet,
      builder: (context, child) {
        final matching = wallet.transactions.where(filter.includes);
        final transactions = (limit == null ? matching : matching.take(limit!))
            .toList();
        if (transactions.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No transactions to show. Your saved demo activity will appear here.',
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final transaction in transactions)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  shadowColor: const Color(0x12000000),
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TransactionDetailsScreen(transaction: transaction),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact =
                              constraints.maxWidth < 320 ||
                              MediaQuery.textScalerOf(context).scale(14) > 19;
                          final amount = Text(
                            transaction.formattedAmount,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: transaction.amountToea > 0
                                  ? const Color(0xFF16754B)
                                  : const Color(0xFF102443),
                            ),
                          );
                          final date = Text(
                            transaction.createdAt == null
                                ? 'Date not recorded'
                                : transaction.formattedDate.split(' at ').first,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 11,
                            ),
                          );
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF102443),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  transaction.icon,
                                  size: 21,
                                  color: const Color(0xFF102443),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      transaction.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      transaction.detail,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (compact) ...[
                                      const SizedBox(height: 10),
                                      amount,
                                      const SizedBox(height: 4),
                                      date,
                                    ],
                                  ],
                                ),
                              ),
                              if (!compact) ...[
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      amount,
                                      const SizedBox(height: 8),
                                      date,
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
