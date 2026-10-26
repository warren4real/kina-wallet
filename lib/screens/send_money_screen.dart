import 'package:flutter/material.dart';

import 'review_transfer_screen.dart';
import '../models/recipient.dart';
import 'saved_recipients_screen.dart';
import 'remittance_preview_screen.dart';

class SendMoneyScreen extends StatefulWidget {
  final Recipient? initialRecipient;

  const SendMoneyScreen({super.key, this.initialRecipient});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final recipient = widget.initialRecipient;

    if (recipient != null) {
      _nameController.text = recipient.name;
      _phoneController.text = recipient.phoneNumber;
    }
  }

  @override
  void dispose() {
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

    _nameController.text = recipient.name;
    _phoneController.text = recipient.phoneNumber;
  }

  void _reviewTransfer() {
    if (!_formKey.currentState!.validate()) return;

    // Dismiss the keyboard before opening the review screen.
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final amount = double.parse(_amountController.text.trim());

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewTransferScreen(
          recipientName: name,
          phoneNumber: phone,
          amount: amount,
        ),
      ),
    );
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
              const Text(
                'Enter the recipient’s details and an amount in kina.',
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'K ',
                  hintText: '0.00',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';

                  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
                    return 'Enter an amount with up to 2 decimal places';
                  }

                  final amount = double.tryParse(text);
                  if (amount == null || !amount.isFinite || amount <= 0) {
                    return 'Enter an amount greater than zero';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _reviewTransfer(),
              ),
              const SizedBox(height: 28),

              FilledButton(
                onPressed: _reviewTransfer,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: const Text('Review transfer'),
              ),
              const SizedBox(height: 16),

              const Text(
                'DEMO ONLY · No real money moves. '
                'Confirmation updates your saved demo balance and history. '
                'Recipient verification is not connected.',
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
