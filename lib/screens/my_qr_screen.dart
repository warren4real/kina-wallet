import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/demo_qr.dart';
import '../models/profile_store.dart';

class MyQrScreen extends StatelessWidget {
  const MyQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: profileStore,
      builder: (context, child) {
        final recipient = profileStore.profile;
        final qrData = DemoQr.encode(recipient);
        return Scaffold(
          appBar: AppBar(title: const Text('My Demo QR')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Your receiving QR',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This code contains a fictional recipient’s '
                  'name and mobile number.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text(
                          'KINA WALLET · DEMO',
                          style: TextStyle(
                            color: Color(0xFF1769EF),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: QrImageView(
                              data: qrData,
                              version: QrVersions.auto,
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.all(20),
                              semanticsLabel:
                                  'Kina Wallet demo recipient QR code',
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          recipient.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '+675 ${recipient.phoneNumber}',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'DEMO ONLY · No real receiving account is linked. '
                  'This code does not transfer money. '
                  'It uses our prototype format, not a bank '
                  'or another wallet’s QR format.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: qrData));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Demo QR data copied. Paste it from the Pay screen.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy demo QR data'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: const Text('Back to Pay'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
