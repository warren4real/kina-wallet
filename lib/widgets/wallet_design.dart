import 'package:flutter/material.dart';

const designNavy = Color(0xFF102443);
const designBlue = Color(0xFF1769EF);
const designSurface = Color(0xFFF5F7FB);

/// The shared navy header and rounded content surface used by wallet tabs.
class WalletTabLayout extends StatelessWidget {
  const WalletTabLayout({
    super.key,
    required this.title,
    required this.subtitle,
    this.header,
    required this.children,
  });
  final String title;
  final String subtitle;
  final Widget? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: designNavy,
    child: SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, height: 1.5),
                  ),
                  if (header != null) ...[const SizedBox(height: 24), header!],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: designSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: ColoredBox(color: designSurface),
          ),
        ],
      ),
    ),
  );
}

/// A consistent emblem for payment forms, QR tools and demo receipts.
class WalletEmblem extends StatelessWidget {
  const WalletEmblem({super.key, required this.icon, this.success = false});
  final IconData icon;
  final bool success;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: success ? const Color(0xFFE7F6ED) : const Color(0xFFE8F0FF),
        border: Border.all(
          color: success ? const Color(0xFFD0EBD9) : const Color(0xFFD6E5FF),
          width: 6,
        ),
      ),
      child: Icon(
        success ? Icons.check_rounded : icon,
        size: 44,
        color: success ? const Color(0xFF16754B) : designBlue,
      ),
    ),
  );
}
