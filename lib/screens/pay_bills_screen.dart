import 'package:flutter/material.dart';

import '../widgets/wallet_design.dart';
import 'electricity_screen.dart';
import 'water_screen.dart';
import 'rent_screen.dart';

class PayBillsScreen extends StatelessWidget {
  const PayBillsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text('Pay Bills'),
      backgroundColor: designBlue,
      foregroundColor: Colors.white,
      toolbarHeight: 80,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Choose a bill',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Demo payments only · No provider is connected.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          for (final bill in const <(String, IconData, Widget)>[
            ('Electricity', Icons.bolt_rounded, ElectricityScreen()),
            ('Water', Icons.water_drop_outlined, WaterScreen()),
            ('Rent', Icons.home_work_outlined, RentScreen()),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFE6EEFC),
                    child: Icon(bill.$2, color: designBlue),
                  ),
                  title: Text(
                    bill.$1,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => bill.$3)),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
