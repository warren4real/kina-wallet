import 'package:flutter/material.dart';

import '../models/demo_transaction.dart';
import '../models/wallet_store.dart';
import '../widgets/wallet_design.dart';
import '../widgets/cloud_wallet_status.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  TransactionFilter _filter = TransactionFilter.all;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F9FC),
    appBar: AppBar(
      title: const Text('Transaction History'),
      backgroundColor: designBlue,
      foregroundColor: Colors.white,
      toolbarHeight: 80,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CloudWalletStatus(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
              decoration: BoxDecoration(
                color: designBlue,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'All wallet transactions',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Kina Wallet · PGK · Demo',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Latest transactions',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                ),
                PopupMenuButton<TransactionFilter>(
                  tooltip: 'Filter transactions',
                  initialValue: _filter,
                  icon: const Icon(Icons.tune_rounded),
                  onSelected: (value) => setState(() => _filter = value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: TransactionFilter.all,
                      child: Text('All transactions'),
                    ),
                    PopupMenuItem(
                      value: TransactionFilter.incoming,
                      child: Text('Money received'),
                    ),
                    PopupMenuItem(
                      value: TransactionFilter.outgoing,
                      child: Text('Money sent and payments'),
                    ),
                  ],
                ),
              ],
            ),
            ListenableBuilder(
              listenable: walletStore,
              builder: (context, _) => Text(
                '${walletStore.transactions.where((t) => _filter.includes(t)).length} entries · '
                '${_filter == TransactionFilter.all
                    ? 'All transactions'
                    : _filter == TransactionFilter.incoming
                    ? 'Money received'
                    : 'Money sent and payments'}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
            const SizedBox(height: 18),
            TransactionList(filter: _filter),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'DEMO · Sample money and transactions',
                style: TextStyle(color: Colors.black45, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
