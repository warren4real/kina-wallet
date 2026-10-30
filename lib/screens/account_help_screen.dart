import 'package:flutter/material.dart';

import '../models/account_actions_store.dart';

class AccountHelpScreen extends StatefulWidget {
  const AccountHelpScreen({super.key, this.store, this.email = ''});
  final AccountActionsStore? store;
  final String email;
  @override
  State<AccountHelpScreen> createState() => _AccountHelpScreenState();
}

class _AccountHelpScreenState extends State<AccountHelpScreen> {
  late final email = TextEditingController(text: widget.email);
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store ?? accountActionsStore;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset account password')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Forgot your account password?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Request an email reset link, then open the newest link on this same phone. This changes your cloud account password, not your local wallet PIN.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: email,
                key: const ValueKey('reset-email'),
                enabled: !store.busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Account email'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: store.busy
                    ? null
                    : () => store.requestReset(email.text),
                child: Text(store.busy ? 'Requesting…' : 'Send reset link'),
              ),
              const SizedBox(height: 16),
              if (store.error != null)
                Text(
                  store.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (store.message != null) Text(store.message!),
              const SizedBox(height: 16),
              const Text(
                'The Free-plan email delivery restrictions and rate limits still apply.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
