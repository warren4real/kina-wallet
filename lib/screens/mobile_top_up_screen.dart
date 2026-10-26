import 'package:flutter/material.dart';

import '../widgets/wallet_design.dart';

import '../models/wallet_store.dart';

class MobileTopUpScreen extends StatefulWidget {
  const MobileTopUpScreen({super.key});

  @override
  State<MobileTopUpScreen> createState() => _MobileTopUpScreenState();
}

class _MobileTopUpScreenState extends State<MobileTopUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();

  bool _busy = false;
  bool _paid = false;
  String? _paidPhone;
  int? _paidToea;

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _reviewTopUp() async {
    if (_busy || _paid) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final phone = _phoneController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final amountToea = (amount * 100).round();

    setState(() => _busy = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Review demo top-up'),
          content: Text(
            'Mobile: +675 $phone\n'
            'Amount: K ${(amountToea / 100).toStringAsFixed(2)}\n\n'
            'Only your demo balance changes. '
            'No mobile credit will be delivered.',
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
              child: const Text('Confirm demo top-up'),
            ),
          ],
        ),
      );

      if (!mounted || confirmed != true) return;

      final error = await walletStore.payDemoMobileTopUp(
        phoneNumber: phone,
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
        _paidPhone = phone;
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
      appBar: AppBar(title: const Text('Mobile Top-Up')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            WalletEmblem(icon: Icons.phone_android, success: _paid),
            const SizedBox(height: 20),
            Text(
              _paid ? 'Demo top-up recorded' : 'Top up a mobile',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'No mobile provider is connected. '
              'Use a fictional PNG mobile number to test this flow.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            if (!_paid) ...[
              Form(
                key: _formKey,
                child: Column(
                  children: [
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
                      controller: _amountController,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Top-up amount',
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

                        // A prototype limit, not a provider rule.
                        if (amount > 10000) {
                          return 'Use up to K 10,000 per demo top-up';
                        }

                        return null;
                      },
                      onFieldSubmitted: (_) => _reviewTopUp(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _reviewTopUp,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1769EF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(_busy ? 'Please wait…' : 'Review demo top-up'),
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
                      Text('Mobile: +675 $_paidPhone'),
                      const SizedBox(height: 12),
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
                        'No mobile credit was delivered.',
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
              'DEMO ONLY · No real mobile top-up. '
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
