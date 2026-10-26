import 'package:flutter/material.dart';

import '../main.dart';
import '../models/wallet_store.dart';
import '../models/profile_store.dart';
import 'send_money_screen.dart';
import 'all_services_screen.dart';
import 'my_qr_screen.dart';
import 'notifications_screen.dart';
import 'pay_bills_screen.dart';
import 'add_money_screen.dart';
import 'mobile_top_up_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool balanceVisible = true;

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListenableBuilder(
                    listenable: profileStore,
                    builder: (context, child) => Row(
                      children: [
                        const CircleAvatar(
                          radius: 23,
                          backgroundColor: Color(0xFFE6EEFC),
                          child: Icon(Icons.person_outline, color: walletBlue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Welcome back',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                profileStore.profile.name,
                                style: const TextStyle(
                                  color: navy,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Notifications',
                          onPressed: () => _open(const NotificationsScreen()),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFE6EEFC),
                            foregroundColor: walletBlue,
                          ),
                          icon: const Icon(Icons.notifications_outlined),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'My wallet',
                    style: TextStyle(
                      color: navy,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF368CFF), Color(0xFF1263DF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Available balance',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              tooltip: balanceVisible
                                  ? 'Hide balance'
                                  : 'Show balance',
                              onPressed: () => setState(
                                () => balanceVisible = !balanceVisible,
                              ),
                              icon: Icon(
                                balanceVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        ListenableBuilder(
                          listenable: walletStore,
                          builder: (context, child) => FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              balanceVisible
                                  ? walletStore.formattedBalance
                                  : 'K ••••••',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'KINA WALLET · PGK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'DEMO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _open(const AllServicesScreen()),
                          child: const Text(
                            'Services',
                            style: TextStyle(
                              color: navy,
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('services-view-all'),
                        onPressed: () => _open(const AllServicesScreen()),
                        child: const Text('View all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ServiceButton(
                          label: 'Send',
                          icon: Icons.logout_rounded,
                          onTap: () => _open(const SendMoneyScreen()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ServiceButton(
                          label: 'Receive',
                          icon: Icons.login_rounded,
                          onTap: () => _open(const MyQrScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final shortcut in const <(String, IconData, Widget)>[
                        (
                          'Pay Bills',
                          Icons.receipt_long_outlined,
                          PayBillsScreen(),
                        ),
                        ('Cash In', Icons.payments_outlined, AddMoneyScreen()),
                        (
                          'Mobile Top-Up',
                          Icons.phone_android_rounded,
                          MobileTopUpScreen(),
                        ),
                      ])
                        Expanded(
                          child: _HomeShortcut(
                            label: shortcut.$1,
                            icon: shortcut.$2,
                            onTap: () => _open(shortcut.$3),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Center(
                    child: Text(
                      'DEMO · Sample money and transactions',
                      style: TextStyle(color: Colors.black45, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceButton extends StatelessWidget {
  const _ServiceButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilledButton(
    key: ValueKey('home-action-$label'),
    onPressed: onTap,
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF103FAD),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Icon(icon, size: 22),
        ),
        const SizedBox(width: 10),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 17))),
      ],
    ),
  );
}

class _HomeShortcut extends StatelessWidget {
  const _HomeShortcut({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('home-action-$label'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: walletBlue, width: 2),
            ),
            child: Icon(icon, color: walletBlue, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: navy,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}
