import 'package:flutter/material.dart';

import '../widgets/wallet_design.dart';
import 'send_money_screen.dart';
import 'my_qr_screen.dart';
import 'add_money_screen.dart';
import 'mobile_top_up_screen.dart';
import 'pay_bills_screen.dart';

class AllServicesScreen extends StatelessWidget {
  const AllServicesScreen({super.key});

  static const _services = <(String, IconData, Widget)>[
    ('Send Money', Icons.logout_rounded, SendMoneyScreen()),
    ('Receive', Icons.login_rounded, MyQrScreen()),
    ('Cash In', Icons.payments_outlined, AddMoneyScreen()),
    ('Mobile Top-Up', Icons.phone_android_rounded, MobileTopUpScreen()),
    ('Pay Bills', Icons.receipt_long_outlined, PayBillsScreen()),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text('All Services'),
      backgroundColor: designBlue,
      foregroundColor: Colors.white,
      toolbarHeight: 80,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns = scale > 1.3
              ? 2
              : (constraints.maxWidth < 360 ? 3 : 4);
          return CustomScrollView(
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 28, 24, 16),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Services',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 96 + 96 * scale,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final service = _services[index];
                    return Semantics(
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => service.$3),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 12,
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: designNavy,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  service.$2,
                                  size: 30,
                                  color: designNavy,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                service.$1,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }, childCount: _services.length),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
