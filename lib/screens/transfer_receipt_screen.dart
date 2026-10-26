import 'package:flutter/material.dart';

import '../widgets/wallet_design.dart';

class TransferReceiptScreen extends StatelessWidget {
  final String recipientName;
  final String phoneNumber;
  final double amount;
  final DateTime createdAt;

  const TransferReceiptScreen({
    super.key,
    required this.recipientName,
    required this.phoneNumber,
    required this.amount,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final date = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    final time =
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Receipt'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const WalletEmblem(icon: Icons.check_rounded, success: true),
            const SizedBox(height: 20),
            const Text(
              'Demo transfer complete',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'No real money was sent or deducted.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DEMO RECEIPT',
                      style: TextStyle(
                        color: designBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'K ${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: designNavy,
                      ),
                    ),
                    const Divider(height: 32),
                    _ReceiptDetail(label: 'Recipient', value: recipientName),
                    _ReceiptDetail(
                      label: 'PNG mobile',
                      value: '+675 $phoneNumber',
                    ),
                    _ReceiptDetail(
                      label: 'Amount',
                      value: 'K ${amount.toStringAsFixed(2)}',
                    ),
                    const _ReceiptDetail(label: 'Demo fee', value: 'K 0.00'),
                    _ReceiptDetail(
                      label: 'Demo total',
                      value: 'K ${amount.toStringAsFixed(2)}',
                    ),
                    _ReceiptDetail(
                      label: 'Created on this device',
                      value: '$date at $time',
                    ),
                    const _ReceiptDetail(label: 'Status', value: 'Demo only'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'This receipt is a preview and is not proof of payment. '
              'The demo balance and Activity have been updated. '
              'Demo data is saved on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 28),

            FilledButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: const Text('Back Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptDetail extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
