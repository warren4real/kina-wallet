import 'package:flutter/material.dart';

class WalletLogo extends StatelessWidget {
  const WalletLogo({super.key, this.height = 110});
  final double height;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/kina-wallet-logo-v1.png',
    width: 360,
    height: height,
    fit: BoxFit.contain,
    semanticLabel: 'Kina Wallet',
  );
}
