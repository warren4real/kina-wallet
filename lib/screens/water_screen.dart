import 'package:flutter/material.dart';

import '../widgets/wallet_design.dart';

import '../models/wallet_store.dart';

class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  final _amountController = TextEditingController();

  bool _reviewOpen = false;
  bool _paid = false;
  String? _paidCustomer;
  int? _paidToea;

  @override
  void dispose() {
    _customerController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _reviewPayment() async {
    if (_reviewOpen || _paid) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final customer = _customerController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final amountToea = (amount * 100).round();

    setState(() => _reviewOpen = true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Review demo payment'),
        content: Text(
          'Customer: $customer\n'
          'Amount: K ${(amountToea / 100).toStringAsFixed(2)}\n\n'
          'Only your demo balance changes. '
          'No water bill will be actually paid.',
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
            child: const Text('Confirm demo payment'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed != true || _paid) {
      setState(() => _reviewOpen = false);
      return;
    }
    // Keep the review guard held until the saved result is known.

    final error = await walletStore.payDemoWater(
      customerNumber: customer,
      amountToea: amountToea,
    );

    if (!mounted) return;
    setState(() => _reviewOpen = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() {
      _paid = true;
      _paidCustomer = customer;
      _paidToea = amountToea;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Water')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            WalletEmblem(icon: Icons.water_drop_outlined, success: _paid),
            const SizedBox(height: 20),
            Text(
              _paid ? 'Demo payment recorded' : 'Water demo payment',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Water provider is connected. '
              'Use a fictional customer number to test this flow.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            if (!_paid) ...[
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _customerController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Demo customer number',
                        hintText: 'Use digits only',
                      ),
                      validator: (value) {
                        final customer = value?.trim() ?? '';

                        // Provider-specific rules will be added later.
                        if (!RegExp(r'^\d+$').hasMatch(customer)) {
                          return 'Enter a customer number using digits';
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
                          return 'Enter an amount with up to 2 decimals';
                        }

                        final amount = double.tryParse(text);

                        if (amount == null || !amount.isFinite || amount <= 0) {
                          return 'Enter an amount greater than zero';
                        }

                        if (amount > 10000) {
                          return 'Use up to K 10,000 per demo payment';
                        }

                        return null;
                      },
                      onFieldSubmitted: (_) => _reviewPayment(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _reviewOpen ? null : _reviewPayment,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1769EF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Review demo payment'),
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
                      Text('Customer: $_paidCustomer'),
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
                        'No water bill was actually paid.',
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
              'DEMO ONLY · No real water bill is paid. '
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
