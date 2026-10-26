import 'package:flutter/material.dart';

import '../widgets/wallet_design.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F9FC),
    appBar: AppBar(
      title: const Text('Notifications'),
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
        children: const [
          Text(
            'Latest',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 24),
          Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 44,
                    color: designBlue,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Live alerts are not connected in this demo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
