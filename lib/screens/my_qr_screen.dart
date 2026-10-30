import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/demo_qr.dart';
import 'sandbox_account_screen.dart';
import '../models/profile_store.dart';
import '../models/wallet_identity.dart';
import '../models/recipient.dart';
import '../models/wallet_store.dart';
import '../models/sandbox_account_store.dart';

class MyQrScreen extends StatelessWidget {
  const MyQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        profileStore,
        sandboxAccountStore,
        walletStore,
      ]),
      builder: (context, child) {
        final cloudAccount = sandboxAccountStore.account;
        final recipient = walletStore.isCloud
            ? Recipient(
                name: WalletIdentity.current.name,
                phoneNumber: cloudAccount?.id == walletStore.accountId
                    ? (cloudAccount?.phoneNumber ?? '')
                    : '',
                accountId: walletStore.accountId,
              )
            : WalletIdentity.current.recipient;
        if (recipient == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('My Demo QR')),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code, size: 64),
                    const SizedBox(height: 20),
                    const Text(
                      'Add a fictional PNG mobile number to your cloud profile to show your demo QR.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SandboxAccountScreen(),
                        ),
                      ),
                      child: const Text('Edit cloud profile'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
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
                  'Share your receiving code or QR with another demo account. No real payments are connected.',
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
                        if (recipient.phoneNumber.isNotEmpty)
                          Text(
                            '+675 ${recipient.phoneNumber}',
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
                if (recipient.accountId != null) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Receiving account code',
                    textAlign: TextAlign.center,
                  ),
                  SelectableText(
                    recipient.accountId!,
                    textAlign: TextAlign.center,
                    key: const ValueKey('my-receiving-code'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: recipient.accountId!),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Receiving code copied'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy receiving code'),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'DEMO ONLY · This prototype QR is not a bank or another wallet’s QR format. Scanning prepares a transfer; confirmation is required. All funds are fictional.',
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
