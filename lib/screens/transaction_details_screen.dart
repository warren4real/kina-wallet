import 'package:flutter/material.dart';

import '../models/demo_transaction.dart';
import '../widgets/wallet_design.dart';

class TransactionDetailsScreen extends StatelessWidget {
  final DemoTransaction transaction;

  const TransactionDetailsScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final incoming = transaction.amountToea >= 0;
    final amount = (transaction.amountToea.abs() / 100).toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Details')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            WalletEmblem(icon: transaction.icon),
            const SizedBox(height: 20),
            Text(
              transaction.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              '${incoming ? '+' : '−'}K $amount',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: incoming
                    ? const Color(0xFF16754B)
                    : const Color(0xFF102443),
              ),
            ),
            const SizedBox(height: 28),
            Card(
              elevation: 0,
              color: Colors.white,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Details',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      transaction.detail,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Divider(height: 32),
                    const Text(
                      'Direction',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      incoming ? 'Money in' : 'Money out',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Recorded on this device',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      transaction.formattedDate,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Demo reference',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      transaction.reference ??
                          'Not recorded for this older demo entry',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Record type',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Demo transaction',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'This is a saved demo record, not proof of payment. '
              'No real money or services were delivered.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
