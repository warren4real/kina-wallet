import 'package:flutter/material.dart';

import '../widgets/wallet_design.dart';

import '../models/wallet_store.dart';
import 'transfer_receipt_screen.dart';

class ReviewTransferScreen extends StatelessWidget {
  final String recipientName;
  final String phoneNumber;
  final double amount;

  const ReviewTransferScreen({
    super.key,
    required this.recipientName,
    required this.phoneNumber,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    // Placeholder fee for the demo.
    const demoFee = 0.0;
    final total = amount + demoFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Review Transfer')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const WalletEmblem(icon: Icons.account_circle_outlined),
            const SizedBox(height: 16),
            const Text('You’re sending', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'K ${amount.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 28),

            // Transfer details
            Card(
              elevation: 0,
              color: Colors.white,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _DetailRow(label: 'Recipient', value: recipientName),
                    const SizedBox(height: 16),
                    _DetailRow(label: 'PNG mobile', value: '+675 $phoneNumber'),
                    const Divider(height: 32),
                    _DetailRow(
                      label: 'Transfer amount',
                      value: 'K ${amount.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      label: 'Demo fee',
                      value: 'K ${demoFee.toStringAsFixed(2)}',
                    ),
                    const Divider(height: 32),
                    _DetailRow(
                      label: 'Total',
                      value: 'K ${total.toStringAsFixed(2)}',
                      bold: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Check the name and mobile number carefully. '
              'This demo does not verify the recipient.',
            ),
            const SizedBox(height: 12),
            const Text(
              'DEMO ONLY · The fee is a placeholder. '
              'Only your sample balance changes. '
              'No real money will be sent or deducted.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 28),

            // Confirm and update the demo wallet.
            FilledButton(
              onPressed: () async {
                if (ModalRoute.of(context)?.isCurrent != true) {
                  return;
                }

                final amountToea = (amount * 100).round();

                final error = await walletStore.sendDemoMoney(
                  recipientName: recipientName,
                  phoneNumber: phoneNumber,
                  amountToea: amountToea,
                );

                if (!context.mounted) return;

                if (error != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error)));
                  return;
                }

                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => TransferReceiptScreen(
                      recipientName: recipientName,
                      phoneNumber: phoneNumber,
                      amount: amountToea / 100,
                      createdAt: DateTime.now(),
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1769EF),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Confirm demo transfer'),
            ),
            const SizedBox(height: 12),

            // Return to the form without changing the balance.
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1769EF),
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Edit details'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
