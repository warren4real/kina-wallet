import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pin_lock_store.dart';
import '../widgets/wallet_design.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key, required this.store});
  final PinLockStore store;
  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _message;
  Timer? _retryTimer;
  int _lastRetrySeconds = 0;
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_clearWhenLocked);
    _lastRetrySeconds = widget.store.retrySeconds;
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final seconds = widget.store.retrySeconds;
      if (mounted && seconds != _lastRetrySeconds) {
        setState(() {
          if (_lastRetrySeconds > 0 && seconds == 0) {
            _message = 'You can try your current PIN again.';
          }
          _lastRetrySeconds = seconds;
        });
      }
    });
  }

  void _clearWhenLocked() {
    if (!widget.store.unlocked) {
      _current.clear();
      _new.clear();
      _confirm.clear();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    widget.store.removeListener(_clearWhenLocked);
    for (final controller in [_current, _new, _confirm]) {
      controller.clear();
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || widget.store.busy || widget.store.retrySeconds > 0) return;
    if (!_form.currentState!.validate()) return;
    final current = _current.text;
    final next = _new.text;
    final confirmation = _confirm.text;
    _current.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _message = null;
    });
    final error = await widget.store.changePin(
      currentPin: current,
      newPin: next,
      confirmation: confirmation,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = error;
      _lastRetrySeconds = widget.store.retrySeconds;
    });
    if (error == null) {
      _new.clear();
      _confirm.clear();
      Navigator.of(context).pop(true);
    }
  }

  Widget _field({
    required String keyName,
    required String label,
    required TextEditingController controller,
    bool last = false,
  }) => TextFormField(
    key: ValueKey(keyName),
    controller: controller,
    enabled: !_saving && !widget.store.busy,
    obscureText: true,
    autocorrect: false,
    enableSuggestions: false,
    enableInteractiveSelection: false,
    keyboardType: TextInputType.number,
    textInputAction: last ? TextInputAction.done : TextInputAction.next,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(6),
    ],
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      if (!RegExp(r'^\d{6}$').hasMatch(value ?? '')) {
        return 'Enter exactly six digits.';
      }
      if (last && value != _new.text) return 'New PINs do not match.';
      if (controller == _new && value == _current.text) {
        return 'Choose a different PIN.';
      }
      return null;
    },
    onFieldSubmitted: (_) {
      if (last) _save();
    },
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) => PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Change PIN')),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const WalletEmblem(icon: Icons.password_rounded),
                const SizedBox(height: 24),
                const Text(
                  'Choose a new PIN',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Confirm your current PIN, then enter your new six-digit PIN twice.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                _field(
                  keyName: 'change-current-pin',
                  label: 'Current PIN',
                  controller: _current,
                ),
                const SizedBox(height: 20),
                _field(
                  keyName: 'change-new-pin',
                  label: 'New six-digit PIN',
                  controller: _new,
                ),
                const SizedBox(height: 20),
                _field(
                  keyName: 'change-confirm-pin',
                  label: 'Confirm new PIN',
                  controller: _confirm,
                  last: true,
                ),
                if (_message != null || widget.store.retrySeconds > 0) ...[
                  const SizedBox(height: 16),
                  Text(
                    widget.store.retrySeconds > 0
                        ? 'Try again in ${widget.store.retrySeconds} seconds.'
                        : _message!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed:
                      _saving ||
                          widget.store.busy ||
                          widget.store.retrySeconds > 0
                      ? null
                      : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save new PIN'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Your balance, history, saved recipients and biometric preference stay the same. Keep your new PIN safe; forgotten-PIN recovery is not available yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
