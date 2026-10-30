import 'dart:async';

import 'package:flutter/material.dart';

import '../models/sandbox_account_store.dart';
import 'account_help_screen.dart';
import 'delete_account_screen.dart';

class SandboxAccountScreen extends StatefulWidget {
  const SandboxAccountScreen({super.key, this.store});
  final SandboxAccountStore? store;
  @override
  State<SandboxAccountScreen> createState() => _SandboxAccountScreenState();
}

class _SandboxAccountScreenState extends State<SandboxAccountScreen>
    with WidgetsBindingObserver {
  late final SandboxAccountStore store;
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  bool registering = false;
  String? accountId;

  @override
  void initState() {
    super.initState();
    store = widget.store ?? sandboxAccountStore;
    WidgetsBinding.instance.addObserver(this);
    store.addListener(_syncAccount);
    _syncAccount();
    unawaited(store.initialize());
  }

  void _syncAccount() {
    if (accountId != store.account?.id) {
      accountId = store.account?.id;
      password.clear();
      name.text = store.account?.displayName ?? '';
      phone.text = store.account?.phoneNumber ?? '';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) password.clear();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final enteredPassword = password.text;
    password.clear();
    if (registering) {
      await store.register(email.text, enteredPassword, name.text);
    } else {
      await store.signIn(email.text, enteredPassword);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(_syncAccount);
    email.dispose();
    password.dispose();
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sandbox account')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final account = store.account;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.cloud_outlined,
                size: 48,
                color: Color(0xFF1769EF),
              ),
              const SizedBox(height: 20),
              Text(
                account == null ? 'Your test account' : account.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your account has a separate cloud demo balance and history, starting at K 0.00. Signing out restores the original local wallet. Your recipients also sync to this account. The PIN stays on this phone. No real money moves.',
              ),
              const SizedBox(height: 24),
              if (account != null) ...[
                Text(account.email),
                const SizedBox(height: 20),
                TextFormField(
                  controller: name,
                  enabled: !store.busy,
                  key: const ValueKey('sandbox-name'),
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Cloud display name',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phone,
                  enabled: !store.busy,
                  key: const ValueKey('sandbox-phone'),
                  keyboardType: TextInputType.phone,
                  maxLength: 8,
                  decoration: const InputDecoration(
                    labelText: 'Optional demo mobile number',
                    prefixText: '+675 ',
                    helperText:
                        'Fictional details only. This number is not verified.',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: store.busy
                      ? null
                      : () => store.rename(name.text, phoneNumber: phone.text),
                  child: const Text('Save profile'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: store.busy ? null : store.signOut,
                  child: const Text('Sign out'),
                ),
                TextButton(
                  onPressed: store.busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DeleteAccountScreen(
                              accountId: account.id,
                              email: account.email,
                            ),
                          ),
                        ),
                  child: const Text('Delete test account'),
                ),
              ] else ...[
                if (registering) ...[
                  TextFormField(
                    controller: name,
                    enabled: !store.busy,
                    key: const ValueKey('sandbox-name'),
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: email,
                  enabled: !store.busy,
                  key: const ValueKey('sandbox-email'),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: password,
                  enabled: !store.busy,
                  key: const ValueKey('sandbox-password'),
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Account password',
                    helperText: registering
                        ? 'At least 12 characters. Separate from your wallet PIN.'
                        : 'Separate from your wallet PIN.',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: store.busy ? null : _submit,
                  child: Text(registering ? 'Create account' : 'Sign in'),
                ),
                TextButton(
                  onPressed: store.busy
                      ? null
                      : () {
                          password.clear();
                          setState(() => registering = !registering);
                        },
                  child: Text(
                    registering
                        ? 'Already have an account? Sign in'
                        : 'Create a test account',
                  ),
                ),
                TextButton(
                  onPressed: store.busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AccountHelpScreen(email: email.text),
                          ),
                        ),
                  child: const Text('Forgot account password?'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'For the first Free-plan test, use your Supabase organization email. Open the newest confirmation link on this phone to return to Kina Wallet.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
              if (store.busy)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (store.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    store.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (store.message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(store.message!, semanticsLabel: store.message),
                ),
              const SizedBox(height: 24),
              const Text(
                'TEST ACCOUNTS ONLY · No identity verification or payment connection',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          );
        },
      ),
    ),
  );
}
