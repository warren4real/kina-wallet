import 'package:flutter/material.dart';

import '../models/demo_qr.dart';
import '../models/recipient.dart';
import 'send_money_screen.dart';

class PasteDemoQrScreen extends StatefulWidget {
  const PasteDemoQrScreen({super.key});

  @override
  State<PasteDemoQrScreen> createState() => _PasteDemoQrScreenState();
}

class _PasteDemoQrScreenState extends State<PasteDemoQrScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadExample() {
    _formKey.currentState?.reset();
    _controller.text = DemoQr.encode(
      const Recipient(name: 'Demo PNG Shop', phoneNumber: '71234567'),
    );
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final recipient = DemoQr.decode(_controller.text.trim());
    FocusScope.of(context).unfocus();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SendMoneyScreen(initialRecipient: recipient),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paste Demo QR Data')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Check a demo code',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Paste the text encoded in a Kina Wallet demo QR, or load the example below. This does not read a QR image.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _controller,
                minLines: 5,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Demo QR data',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final raw = value?.trim() ?? '';
                  if (raw.isEmpty) {
                    return 'Paste demo QR data or load an example.';
                  }
                  try {
                    DemoQr.decode(raw);
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadExample,
                icon: const Icon(Icons.science_outlined),
                label: const Text('Load demo example'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _continue,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1769EF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                ),
                child: const Text('Continue to transfer'),
              ),
              const SizedBox(height: 20),
              const Text(
                'DEMO ONLY · Valid format does not verify the recipient. Check their details on the next screen. Your balance changes only after you review and confirm a demo transfer.',
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
