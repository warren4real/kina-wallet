import 'package:flutter/material.dart';

import '../widgets/wallet_design.dart';

import 'send_money_screen.dart';
import '../models/recipient.dart';
import '../models/demo_qr.dart';
import 'my_qr_screen.dart';
import 'paste_demo_qr_screen.dart';
import 'scan_qr_screen.dart';

class PayScreen extends StatelessWidget {
  const PayScreen({super.key});

  void _useDemoQr(BuildContext context) {
    const demoRecipient = Recipient(
      name: 'Demo PNG Shop',
      phoneNumber: '71234567',
    );

    try {
      final qrData = DemoQr.encode(demoRecipient);
      final recipient = DemoQr.decode(qrData);

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SendMoneyScreen(initialRecipient: recipient),
        ),
      );
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const WalletEmblem(icon: Icons.qr_code_scanner),
            const SizedBox(height: 20),
            const Text(
              'Pay with a QR code',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Scan a Kina Wallet demo QR, or try the sample and pasted-data options below.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ScanQrScreen()),
              ),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Scan QR with camera'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1769EF),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _useDemoQr(context),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Use demo QR'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const MyQrScreen()),
                );
              },
              icon: const Icon(Icons.qr_code),
              label: const Text('Show my QR'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PasteDemoQrScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste demo QR data'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'DEMO ONLY · Only Kina Wallet demo codes are supported. '
              'Scanning does not verify an account or send money. '
              'Review and confirm before the demo balance changes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
