import 'package:flutter/material.dart';

import '../models/account_actions_store.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({
    super.key,
    required this.accountId,
    required this.email,
    this.store,
  });
  final String accountId, email;
  final AccountActionsStore? store;
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen>
    with WidgetsBindingObserver {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) password.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store ?? accountActionsStore;
    return Scaffold(
      appBar: AppBar(title: const Text('Delete test account')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.delete_forever_outlined,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              Text(
                widget.email,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Permanently delete this test account and its cloud profile, demo balance, transaction history and saved recipients. This cannot be undone. Your separate local demo wallet and device PIN will remain.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: password,
                key: const ValueKey('delete-password'),
                enabled: !store.busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Current account password',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmation,
                key: const ValueKey('delete-confirmation'),
                enabled: !store.busy,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Type DELETE to confirm',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
                onPressed: store.busy
                    ? null
                    : () async {
                        final current = password.text;
                        password.clear();
                        await store.deleteAccount(
                          widget.accountId,
                          current,
                          confirmed: confirmation.text == 'DELETE',
                        );
                      },
                child: Text(
                  store.busy ? 'Deleting…' : 'Permanently delete test account',
                ),
              ),
              const SizedBox(height: 16),
              if (store.error != null)
                Text(
                  store.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
