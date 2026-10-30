import 'dart:async';

import 'package:flutter/material.dart';

import '../models/wallet_store.dart';
import '../models/transfer_notifications.dart';

// Poll only while foregrounded. No OS notification permission or paid service.
class LiveWalletUpdates extends StatefulWidget {
  const LiveWalletUpdates({
    super.key,
    required this.child,
    this.wallet,
    this.notifications,
    this.interval = const Duration(seconds: 10),
  });
  final Widget child;
  final WalletStore? wallet;
  final TransferNotificationStore? notifications;
  final Duration interval;
  @override
  State<LiveWalletUpdates> createState() => _LiveWalletUpdatesState();
}

class _LiveWalletUpdatesState extends State<LiveWalletUpdates>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _active = true, _refreshing = false;
  late final WalletStore _wallet = widget.wallet ?? walletStore;
  late final TransferNotificationStore _notifications =
      widget.notifications ?? transferNotifications;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _active) _start();
    });
  }

  void _start() {
    _timer?.cancel();
    unawaited(_refresh());
    _timer = Timer.periodic(widget.interval, (_) => unawaited(_refresh()));
  }

  Future<void> _refresh() async {
    if (!_active || _refreshing || !_wallet.isCloud) return;
    _refreshing = true;
    try {
      await Future.wait([_wallet.refreshCloud(), _notifications.refresh()]);
    } finally {
      _refreshing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      _start();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
