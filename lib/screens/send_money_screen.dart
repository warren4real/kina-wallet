import 'package:flutter/material.dart';

import 'review_transfer_screen.dart';
import '../models/wallet_store.dart';
import '../models/cloud_wallet.dart';
import '../models/recipient.dart';
import 'saved_recipients_screen.dart';
import 'remittance_preview_screen.dart';

class SendMoneyScreen extends StatefulWidget {
  final Recipient? initialRecipient;
  final WalletStore? store;

  const SendMoneyScreen({super.key, this.initialRecipient, this.store});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _formKey = GlobalKey<FormState>();
  WalletStore get wallet => widget.store ?? walletStore;
  final _receivingCodeController = TextEditingController();
  bool _reviewing = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final recipient = widget.initialRecipient;

    if (recipient != null) {
      _receivingCodeController.text = recipient.accountId ?? '';
      _nameController.text = recipient.name;
      _phoneController.text = recipient.phoneNumber;
    }
  }

  @override
  void dispose() {
    _receivingCodeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _chooseRecipient() async {
    final recipient = await Navigator.of(context).push<Recipient>(
      MaterialPageRoute<Recipient>(
        builder: (_) => const SavedRecipientsScreen(),
      ),
    );

    if (!mounted || recipient == null) return;

    _receivingCodeController.text = recipient.accountId ?? '';
    _nameController.text = recipient.name;
    _phoneController.text = recipient.phoneNumber;
  }

  // Bound digit count before parsing; no floating point conversion for money.
  int? _parseTransferToea(String raw) {
    final text = raw.trim();
    if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(text)) return null;
    final parts = text.split('.');
    final toea =
        int.parse(parts[0]) * 100 +
        (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
    return toea > 0 && toea <= 1000000 ? toea : null;
  }

  Future<void> _reviewTransfer() async {
    if (_reviewing || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final sender = wallet.accountId;
    final amountToea = _parseTransferToea(_amountController.text)!;
    setState(() => _reviewing = true);
    try {
      VerifiedDemoRecipient? verified;
      if (wallet.isCloud) {
        verified = await wallet.verifyCloudRecipient(
          _receivingCodeController.text,
        );
      }
      if (!mounted || sender != wallet.accountId) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReviewTransferScreen(
            recipientName: verified?.displayName ?? _nameController.text.trim(),
            phoneNumber: verified == null ? _phoneController.text.trim() : '',
            amountToea: amountToea,
            verifiedRecipient: verified,
            expectedSenderId: sender,
            store: wallet,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is CloudWalletRejected ? error.message : 'Could not match the receiving account. Check your connection and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Money')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Send to someone in PNG',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                wallet.isCloud
                    ? 'Paste the other demo account’s receiving code, or scan their account QR.'
                    : 'Enter the recipient’s details and an amount in kina.',
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RemittancePreviewScreen(),
                  ),
                ),
                icon: const Icon(Icons.public),
                label: const Text('Philippines → PNG preview'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _chooseRecipient,
                icon: const Icon(Icons.people_outline),
                label: const Text('Choose saved recipient'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
              const SizedBox(height: 20),
              if (wallet.isCloud)
                TextFormField(
                  controller: _receivingCodeController,
                  key: const ValueKey('receiving-code'),
                  enabled: !_reviewing,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Receiving account code',
                    helperText: 'Copy from the recipient’s My demo QR screen.',
                  ),
                  validator: (value) => isReceivingCode(value?.trim() ?? '')
                      ? null
                      : 'Enter a valid receiving account code',
                ),
              if (!wallet.isCloud)
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Recipient name',
                    hintText: 'Enter full name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter the recipient’s name';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 20),

              if (!wallet.isCloud)
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'PNG mobile number',
                    prefixText: '+675 ',
                    hintText: 'Enter 8 digits',
                  ),
                  validator: (value) {
                    final phone = value?.trim() ?? '';

                    // Basic prototype check, not provider verification.
                    if (!RegExp(r'^\d{8}$').hasMatch(phone)) {
                      return 'Enter 8 digits without spaces';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _amountController,
                key: const ValueKey('transfer-amount'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'K ',
                  hintText: '0.00',
                ),
                validator: (value) => _parseTransferToea(value ?? '') == null
                    ? 'Enter K 0.01–10,000.00 with up to 2 decimal places'
                    : null,
                onFieldSubmitted: (_) => _reviewTransfer(),
              ),
              const SizedBox(height: 28),

              FilledButton(
                onPressed: _reviewing ? null : _reviewTransfer,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: Text(
                  _reviewing ? 'Matching account…' : 'Review transfer',
                ),
              ),
              const SizedBox(height: 16),

              Text(
                wallet.isCloud
                    ? 'DEMO ONLY · Confirmation debits your cloud demo wallet and credits the matched demo account. No real money moves.'
                    : 'DEMO ONLY · Confirmation changes the local sample balance only. No receiving account is credited.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
