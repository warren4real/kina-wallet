import 'package:flutter/material.dart';

import '../main.dart';
import '../models/profile_store.dart';
import '../models/wallet_identity.dart';
import '../models/wallet_store.dart';
import '../models/sandbox_account_store.dart';
import '../widgets/wallet_design.dart';
import '../models/recipient.dart';
import 'send_money_screen.dart';
import 'edit_profile_screen.dart';
import 'security_screen.dart';
import 'sandbox_account_screen.dart';
import 'my_qr_screen.dart';
import 'saved_recipients_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _chooseRecipient(BuildContext context) async {
    final recipient = await Navigator.of(context).push<Recipient>(
      MaterialPageRoute<Recipient>(
        builder: (_) => const SavedRecipientsScreen(),
      ),
    );
    if (!context.mounted || recipient == null) return;
    _open(context, SendMoneyScreen(initialRecipient: recipient));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      walletStore,
      sandboxAccountStore,
      profileStore,
    ]),
    builder: (context, _) => WalletTabLayout(
      title: 'Profile',
      subtitle: 'Your details. Your everyday wallet.',
      header: ListenableBuilder(
        listenable: Listenable.merge([
          profileStore,
          sandboxAccountStore,
          walletStore,
        ]),
        builder: (context, child) => Column(
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: Color(0xFF294363),
              child: Icon(Icons.person_outline, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              WalletIdentity.current.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              WalletIdentity.current.contact,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFF294363),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                walletStore.isCloud ? 'CLOUD DEMO ACCOUNT' : 'DEMO PROFILE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
      children: [
        const Text(
          'Account',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              _ProfileTile(
                icon: Icons.cloud_outlined,
                title: 'Sandbox account',
                subtitle: 'Test sign-in and private cloud profile',
                onTap: () => _open(context, const SandboxAccountScreen()),
              ),
              const Divider(height: 1, indent: 72),
              _ProfileTile(
                icon: Icons.person_outline,
                title: walletStore.isCloud
                    ? 'Edit cloud profile'
                    : 'Edit demo profile',
                subtitle: walletStore.isCloud
                    ? 'Cloud name and optional demo mobile'
                    : 'Name and PNG mobile number',
                onTap: () => _open(
                  context,
                  walletStore.isCloud
                      ? const SandboxAccountScreen()
                      : const EditProfileScreen(),
                ),
              ),
              const Divider(height: 1, indent: 72),
              _ProfileTile(
                icon: Icons.qr_code,
                title: 'My demo QR',
                subtitle: 'Show your receiving code',
                onTap: () => _open(context, const MyQrScreen()),
              ),
              const Divider(height: 1, indent: 72),
              _ProfileTile(
                icon: Icons.people_outline,
                title: 'Saved recipients',
                subtitle: 'Manage the people you send to',
                onTap: () => _chooseRecipient(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Support & security',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              _ProfileTile(
                icon: Icons.lock_outline,
                title: 'Security',
                subtitle: 'PIN & biometrics · Automatic locking',
                onTap: () => _open(context, const SecurityScreen()),
              ),
              const Divider(height: 1, indent: 72),
              _ProfileTile(
                icon: Icons.help_outline,
                title: 'Help',
                subtitle: 'About Kina Wallet',
                onTap: () => showFeaturePreview(
                  context,
                  'Help',
                  'Kina Wallet is an early prototype for everyday payments and sending money home to PNG.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'No identity verification completed',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        const Text(
          'Prototype only · No real funds or payment connections.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    ),
  );
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFE8F0FF),
      child: Icon(icon, color: designBlue, size: 22),
    ),
    title: Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: Colors.black54, fontSize: 12),
    ),
    trailing: const Icon(Icons.chevron_right, color: Colors.black38),
    onTap: onTap,
  );
}
