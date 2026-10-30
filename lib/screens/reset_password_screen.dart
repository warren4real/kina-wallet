import 'package:flutter/material.dart';

import '../models/account_actions_store.dart';

class AccountRecoveryGate extends StatelessWidget {
  const AccountRecoveryGate({super.key, required this.child, this.store});
  final Widget child;
  final AccountActionsStore? store;
  @override
  Widget build(BuildContext context) {
    final actions = store ?? accountActionsStore;
    return ListenableBuilder(
      listenable: actions,
      builder: (context, _) {
        if (actions.linkError == null &&
            !actions.needsRecovery &&
            !actions.resultReady) {
          return child;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeFocus(child: Offstage(offstage: true, child: child)),
            HeroControllerScope.none(
              child: Navigator(
                key: ValueKey(
                  'account-gate-${actions.recoveryKey}-${actions.linkError != null}-${actions.resultReady}',
                ),
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) => _page(context, actions),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _page(BuildContext context, AccountActionsStore actions) {
    if (actions.linkError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_off, size: 48),
                  const SizedBox(height: 20),
                  Text(actions.linkError!, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: actions.dismissLinkError,
                    child: const Text('Return to wallet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (actions.needsRecovery) return ResetPasswordScreen(store: actions);
    if (actions.resultReady) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 48),
                  const SizedBox(height: 20),
                  Text(
                    actions.message ?? 'Account request completed.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: actions.dismissResult,
                    child: const Text('Back to wallet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return child;
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.store});
  final AccountActionsStore store;
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
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
    if (state != AppLifecycleState.resumed) {
      password.clear();
      confirmation.clear();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Choose a new password'),
      automaticallyImplyLeading: false,
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Reset your account password',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Use at least 12 characters. Your wallet PIN is separate and stays unchanged.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: password,
              key: const ValueKey('new-password'),
              enabled: !widget.store.busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'New account password',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: confirmation,
              key: const ValueKey('confirm-new-password'),
              enabled: !widget.store.busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: widget.store.busy
                  ? null
                  : () async {
                      final next = password.text;
                      final confirm = confirmation.text;
                      password.clear();
                      confirmation.clear();
                      await widget.store.completeReset(next, confirm);
                    },
              child: const Text('Save new password'),
            ),
            const SizedBox(height: 16),
            if (widget.store.error != null)
              Text(
                widget.store.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            TextButton(
              onPressed: widget.store.busy
                  ? null
                  : () async {
                      await widget.store.cancelRecovery();
                    },
              child: const Text('Cancel and sign out'),
            ),
          ],
        ),
      ),
    ),
  );
}
