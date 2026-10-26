import 'package:flutter/material.dart';

import '../widgets/wallet_design.dart';

import '../models/wallet_store.dart';

class AddMoneyScreen extends StatefulWidget {
  const AddMoneyScreen({super.key});

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  bool _added = false;
  int? _addedToea;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _addMoney() async {
    // Prevent repeated additions from the same confirmation.
    if (_added) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final amount = double.parse(_amountController.text.trim());
    final amountToea = (amount * 100).round();

    final error = await walletStore.addDemoMoney(amountToea: amountToea);

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() {
      _added = true;
      _addedToea = amountToea;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Money')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            WalletEmblem(icon: Icons.add_circle_outline, success: _added),
            const SizedBox(height: 20),
            Text(
              _added ? 'Demo money added' : 'Top up your demo wallet',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'This adds fictional funds only. '
              'No bank account or payment card is charged.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            if (!_added) ...[
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Amount to add',
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

                    // A simple limit for this learning prototype.
                    if (amount > 10000) {
                      return 'Add up to K 10,000 per demo top-up';
                    }

                    return null;
                  },
                  onFieldSubmitted: (_) => _addMoney(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _addMoney,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1769EF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Add demo money'),
              ),
            ] else ...[
              Text(
                '+K ${(_addedToea! / 100).toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF16754B),
                ),
              ),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: walletStore,
                builder: (context, child) {
                  return Text(
                    'New balance: ${walletStore.formattedBalance}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  );
                },
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1769EF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Back Home'),
              ),
            ],

            const SizedBox(height: 20),
            const Text(
              'DEMO ONLY · Sample funds and history are saved '
              'on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
