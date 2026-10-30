import 'package:flutter/material.dart';

import '../models/wallet_store.dart';
import '../models/cloud_wallet.dart';

class CloudWalletStatus extends StatelessWidget {
  const CloudWalletStatus({super.key, this.store});
  final WalletStore? store;
  @override
  Widget build(BuildContext context) {
    final wallet = store ?? walletStore;
    return ListenableBuilder(
      listenable: wallet,
      builder: (context, _) {
        if (!wallet.isCloud) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Local demo wallet · Saved on this phone',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          );
        }
        final last = wallet.lastCloudSyncAt?.toLocal();
        String two(int n) => n.toString().padLeft(2, '0');
        final synced = last == null
            ? 'No successful cloud sync yet'
            : 'Last updated ${two(last.day)}/${two(last.month)}/${last.year} at ${two(last.hour)}:${two(last.minute)}:${two(last.second)}';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    wallet.cloudUnavailable
                        ? Icons.cloud_off_outlined
                        : Icons.cloud_outlined,
                    size: 19,
                    color: wallet.cloudUnavailable
                        ? const Color(0xFF996000)
                        : const Color(0xFF1769EF),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      wallet.cloudLoading
                          ? 'Checking cloud wallet…'
                          : wallet.cloudUnavailable
                          ? 'Offline or service unavailable'
                          : 'Cloud demo wallet · Your account',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh cloud wallet',
                    onPressed: wallet.cloudLoading || wallet.saving
                        ? null
                        : wallet.refreshCloud,
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                ],
              ),
              Text(
                synced,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              if (wallet.cloudUnavailable)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Balance and history may be out of date. New payments are paused until a successful refresh.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF805100)),
                  ),
                ),
              if (wallet.cloudError != null &&
                  wallet.cloudOperationState == CloudOperationState.none)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    wallet.cloudError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              CloudOperationPanel(store: wallet),
              const SizedBox(height: 6),
              const Text(
                'Fictional funds · Local wallet kept separately',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CloudOperationPanel extends StatelessWidget {
  const CloudOperationPanel({
    super.key,
    required this.store,
    this.showCompleted = true,
  });
  final WalletStore store;
  final bool showCompleted;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final state = store.cloudOperationState;
      if (!store.isCloud ||
          state == CloudOperationState.none ||
          (!showCompleted && state == CloudOperationState.completed)) {
        return const SizedBox.shrink();
      }
      final (title, icon, color) = switch (state) {
        CloudOperationState.sending => (
          'Sending demo update…',
          Icons.hourglass_top,
          const Color(0xFF1769EF),
        ),
        CloudOperationState.pending => (
          'Pending confirmation',
          Icons.schedule,
          const Color(0xFF805100),
        ),
        CloudOperationState.completed => (
          'Completed',
          Icons.check_circle_outline,
          const Color(0xFF16754B),
        ),
        CloudOperationState.failed => (
          'Update failed',
          Icons.error_outline,
          const Color(0xFFAD2525),
        ),
        CloudOperationState.none => ('', Icons.info_outline, Colors.black54),
      };
      final command = store.cloudOperationCommand;
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (command != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${command.transaction.title} · K ${(command.transaction.amountToea.abs() / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (store.cloudOperationMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  store.cloudOperationMessage!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (store.cloudOperationReference != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SelectableText(
                  store.cloudOperationReference!,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            if (store.hasPendingCloudUpdate && !store.saving)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: store.cloudLoading ? null : store.refreshCloud,
                    child: const Text('Check status'),
                  ),
                  OutlinedButton(
                    onPressed: store.cloudLoading
                        ? null
                        : () async {
                            final owner = store.accountId;
                            final error = await store.retryPendingCloudUpdate();
                            if (context.mounted && store.accountId == owner) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    error ?? 'Original update confirmed. Check History.',
                                  ),
                                ),
                              );
                            }
                          },
                    child: const Text('Retry pending update'),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}
