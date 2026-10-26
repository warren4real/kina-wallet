import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pin_lock_store.dart';
import '../models/biometric_service.dart';
import '../widgets/wallet_design.dart';
import 'change_pin_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key, this.store});
  final PinLockStore? store;
  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _pin = TextEditingController();
  late final PinLockStore _store = widget.store ?? pinLockStore;
  String? _message;
  @override
  void initState() {
    super.initState();
    _store.addListener(_clearOnLock);
    _store.refreshBiometricAvailability();
  }

  void _clearOnLock() {
    // Do not retain a PIN typed into settings after the session is locked.
    if (!_store.unlocked) _pin.clear();
  }

  @override
  void dispose() {
    _store.removeListener(_clearOnLock);
    _pin.clear();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _enable() async {
    final pin = _pin.text;
    _pin.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _message = null);
    final error = await _store.enableBiometrics(pin);
    if (!mounted) return;
    setState(
      () => _message =
          error ??
          '${_store.biometricLabel} is enabled. Choose it on the lock screen to unlock.',
    );
  }

  Future<void> _disable() async {
    final error = await _store.disableBiometrics();
    if (mounted) {
      setState(
        () => _message =
            error ??
            'Biometric unlock is off. Use your six-digit PIN to unlock.',
      );
    }
  }

  Future<void> _changePin() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => ChangePinScreen(store: _store)),
    );
    if (!mounted || changed != true) return;
    setState(
      () => _message = 'Your PIN has been changed. Use your new PIN the next time you unlock.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Security')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const WalletEmblem(icon: Icons.shield_outlined),
            const SizedBox(height: 24),
            const Text(
              'Unlock your way',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose biometrics or your six-digit PIN to unlock.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text('Six-digit PIN'),
                    subtitle: Text('Always available as your unlock fallback'),
                    trailing: Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF16754B),
                    ),
                  ),
                  const Divider(height: 1, indent: 18, endIndent: 18),
                  ListTile(
                    key: const ValueKey('change-pin'),
                    leading: const Icon(Icons.password_rounded),
                    title: const Text('Change PIN'),
                    subtitle: const Text(
                      'Confirm your current PIN to choose a new one',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _store.busy ? null : _changePin,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_clock_outlined),
                title: Text('Automatic locking'),
                subtitle: Text(
                  'Requires PIN or biometrics after 30 seconds away, or when the app restarts. Repeated incorrect PIN attempts add a waiting period.',
                ),
                trailing: Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF16754B),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _store.biometricKind == BiometricKind.face
                              ? Icons.face_outlined
                              : Icons.fingerprint,
                          color: designBlue,
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _store.biometricLabel,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          _store.biometricEnabled ? 'On' : 'Off',
                          style: const TextStyle(
                            color: designBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Use the face or fingerprint enrolled on your phone. Kina Wallet does not receive or store biometric data.',
                      style: TextStyle(color: Colors.black54, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    if (_store.biometricEnabled)
                      OutlinedButton(
                        onPressed: _store.busy ? null : _disable,
                        child: Text('Turn off ${_store.biometricLabel}'),
                      )
                    else if (_store.biometricAvailable) ...[
                      Text(
                        'Confirm your app PIN, then approve ${_store.biometricLabel} to enable it.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('face-id-pin'),
                        controller: _pin,
                        enabled: !_store.busy,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        enableInteractiveSelection: false,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Current app PIN',
                        ),
                        onSubmitted: (_) => _enable(),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _store.busy ? null : _enable,
                        icon: Icon(
                          _store.biometricKind == BiometricKind.face
                              ? Icons.face_outlined
                              : Icons.fingerprint,
                        ),
                        label: Text(
                          _store.biometricPending
                              ? 'Checking ${_store.biometricLabel}…'
                              : 'Enable ${_store.biometricLabel}',
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'No enrolled biometrics are available to this app. Set up face or fingerprint unlock in your phone settings, then check again. Your PIN remains available.',
                        style: TextStyle(color: Colors.black54, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _store.busy
                            ? null
                            : () => _store.refreshBiometricAvailability(),
                        child: const Text('Check availability'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            const Text(
              'Keep your PIN safe. Forgotten-PIN recovery is not available yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}
