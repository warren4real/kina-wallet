import 'package:flutter/material.dart';

import '../widgets/wallet_design.dart';

import '../models/wallet_store.dart';
import '../models/cloud_wallet.dart';
import '../widgets/cloud_wallet_status.dart';
import 'transfer_receipt_screen.dart';

class ReviewTransferScreen extends StatefulWidget {
  final String recipientName;
  final String phoneNumber;
  final int amountToea;
  final VerifiedDemoRecipient? verifiedRecipient;
  final String? expectedSenderId;
  final WalletStore? store;
  double get amount => amountToea / 100;

  const ReviewTransferScreen({
    super.key,
    required this.recipientName,
    required this.phoneNumber,
    required this.amountToea,
    this.verifiedRecipient,
    this.expectedSenderId,
    this.store,
  });

  @override
  State<ReviewTransferScreen> createState() => _ReviewTransferScreenState();
}

class _ReviewTransferScreenState extends State<ReviewTransferScreen> {
  String? _submittedRequestId;
  String get recipientName => widget.recipientName;
  String get phoneNumber => widget.phoneNumber;
  int get amountToea => widget.amountToea;
  double get amount => widget.amount;
  VerifiedDemoRecipient? get verifiedRecipient => widget.verifiedRecipient;
  String? get expectedSenderId => widget.expectedSenderId;
  WalletStore? get store => widget.store;
  bool _completed(WalletStore wallet) =>
      _submittedRequestId != null &&
      wallet.cloudOperationCommand?.id == _submittedRequestId &&
      wallet.cloudOperationState == CloudOperationState.completed;
  void _openReceipt(BuildContext context, WalletStore wallet, bool peer) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TransferReceiptScreen(
          recipientName: recipientName,
          phoneNumber: phoneNumber,
          amount: amount,
          createdAt:
              wallet.cloudOperationCreatedAt ??
              wallet.lastTransferCreatedAt ??
              DateTime.now(),
          reference: peer
              ? (wallet.cloudOperationReference ?? wallet.lastTransferReference)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = store ?? walletStore;
    final peer = verifiedRecipient != null;
    // Placeholder fee for the demo.
    const demoFee = 0.0;
    final total = amount + demoFee;

    return ListenableBuilder(
      listenable: wallet,
      builder: (context, _) => Scaffold(
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
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
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
                      _DetailRow(
                        label: peer ? 'Receiving code' : 'PNG mobile',
                        value:
                            verifiedRecipient?.accountId ?? '+675 $phoneNumber',
                      ),
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
              Text(
                peer
                    ? 'Matched demo account: $recipientName. Check this name and receiving code before confirming. This is not identity verification.'
                    : 'Check the name and mobile number carefully. This local demo does not verify a recipient.',
              ),
              const SizedBox(height: 12),
              Text(
                peer
                    ? 'DEMO ONLY · Both demo balances and histories change together. No real money moves.'
                    : 'DEMO ONLY · Only your local sample balance changes. No real money moves.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 28),

              if (wallet.isCloud)
                CloudOperationPanel(
                  store: wallet,
                  showCompleted: _completed(wallet),
                ),
              const SizedBox(height: 12),
              // Confirm and update the demo wallet.
              FilledButton(
                onPressed:
                    _completed(wallet) ||
                        wallet.saving ||
                        (wallet.isCloud &&
                            (wallet.hasPendingCloudUpdate ||
                                !wallet.cloudReady ||
                                wallet.cloudUnavailable ||
                                wallet.cloudLoading ||
                                wallet.accountId != expectedSenderId))
                    ? null
                    : () async {
                        if (ModalRoute.of(context)?.isCurrent != true) {
                          return;
                        }

                        if (amountToea <= 0 || amountToea > 1000000) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Use K 0.01–10,000.00 per demo transfer.',
                              ),
                            ),
                          );
                          return;
                        }

                        final before = wallet.cloudOperationCommand?.id;
                        final sending = wallet.sendDemoMoney(
                          recipientName: recipientName,
                          phoneNumber: phoneNumber,
                          amountToea: amountToea,
                          recipientAccountId: verifiedRecipient?.accountId,
                          expectedSenderId: expectedSenderId,
                        );
                        if (wallet.cloudOperationState ==
                                CloudOperationState.sending &&
                            wallet.cloudOperationCommand?.id != before) {
                          _submittedRequestId =
                              wallet.cloudOperationCommand?.id;
                        }
                        final error = await sending;

                        if (!context.mounted) return;

                        if (error != null) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(error)));
                          return;
                        }

                        _openReceipt(context, wallet, peer);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1769EF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  wallet.saving ? 'Sending…' : 'Confirm demo transfer',
                ),
              ),
              if (_completed(wallet))
                TextButton(
                  onPressed: () => _openReceipt(context, wallet, peer),
                  child: const Text('View completed transfer'),
                ),
              const SizedBox(height: 12),

              // Return to the form without changing the balance.
              OutlinedButton(
                onPressed: wallet.saving ? null : () => Navigator.pop(context),
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
