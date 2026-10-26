import 'package:flutter/material.dart';

import '../widgets/wallet_design.dart';

import '../models/wallet_store.dart';

class RentScreen extends StatefulWidget {
  const RentScreen({super.key});

  @override
  State<RentScreen> createState() => _RentScreenState();
}

class _RentScreenState extends State<RentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referenceController = TextEditingController();
  final _amountController = TextEditingController();

  bool _busy = false;
  bool _paid = false;

  String? _paidName;
  String? _paidPhone;
  String? _paidReference;
  int? _paidToea;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _referenceController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _reviewRent() async {
    if (_busy || _paid) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final reference = _referenceController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final amountToea = (amount * 100).round();

    setState(() => _busy = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Review demo rent'),
          content: SingleChildScrollView(
            child: Text(
              'Landlord: $name\n'
              'Mobile: +675 $phone\n'
              'Reference: $reference\n'
              'Amount: K ${(amountToea / 100).toStringAsFixed(2)}\n\n'
              'Only your demo balance changes. '
              'No money will be sent to the landlord.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Edit details'),
            ),
            FilledButton(
              onPressed: () {
                if (ModalRoute.of(dialogContext)?.isCurrent != true) {
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Confirm demo rent'),
            ),
          ],
        ),
      );

      if (!mounted || confirmed != true) return;

      final error = await walletStore.payDemoRent(
        landlordName: name,
        phoneNumber: phone,
        rentReference: reference,
        amountToea: amountToea,
      );

      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        return;
      }

      setState(() {
        _paid = true;
        _paidName = name;
        _paidPhone = phone;
        _paidReference = reference;
        _paidToea = amountToea;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rent')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            WalletEmblem(icon: Icons.home_work_outlined, success: _paid),
            const SizedBox(height: 20),
            Text(
              _paid ? 'Demo rent recorded' : 'Pay rent',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Use fictional landlord details to test this flow. '
              'No real rent payment is made.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            if (!_paid) ...[
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      enabled: !_busy,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Landlord name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter the landlord’s name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _phoneController,
                      enabled: !_busy,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'PNG mobile number',
                        prefixText: '+675 ',
                        hintText: 'Enter 8 digits',
                      ),
                      validator: (value) {
                        final phone = value?.trim() ?? '';

                        if (!RegExp(r'^\d{8}$').hasMatch(phone)) {
                          return 'Enter 8 digits without spaces';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _referenceController,
                      enabled: !_busy,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Rent reference',
                        hintText: 'For example: October rent',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a rent reference';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _amountController,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Rent amount',
                        prefixText: 'K ',
                        hintText: '0.00',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';

                        if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
                          return 'Enter an amount with up to 2 decimals';
                        }

                        final amount = double.tryParse(text);

                        if (amount == null || !amount.isFinite || amount <= 0) {
                          return 'Enter an amount greater than zero';
                        }

                        // A prototype limit, not a live payment limit.
                        if (amount > 10000) {
                          return 'Use up to K 10,000 per demo payment';
                        }

                        return null;
                      },
                      onFieldSubmitted: (_) => _reviewRent(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _reviewRent,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1769EF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(_busy ? 'Please wait…' : 'Review demo rent'),
              ),
            ] else ...[
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
                        'DEMO RECEIPT',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Landlord: $_paidName'),
                      const SizedBox(height: 12),
                      Text('Mobile: +675 $_paidPhone'),
                      const SizedBox(height: 12),
                      Text('Reference: $_paidReference'),
                      const SizedBox(height: 16),
                      Text(
                        'K ${(_paidToea! / 100).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Recorded in demo Activity only. '
                        'This is not proof of a real rent payment.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1769EF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                ),
                child: const Text('Back Home'),
              ),
            ],

            const SizedBox(height: 20),
            const Text(
              'DEMO ONLY · No money reaches a landlord. '
              'Sample data is saved on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
