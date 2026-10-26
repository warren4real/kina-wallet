import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pin_lock_store.dart';
import '../models/profile_store.dart';
import 'wallet_design.dart';
import 'wallet_logo.dart';
import 'pin_keypad.dart';

/// Covers the root Navigator, including pushed routes and modal dialogs.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.store, required this.child});
  final PinLockStore store;
  final Widget child;
  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  static const _privacy = MethodChannel('kina_wallet/privacy');
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.setActive(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
    unawaited(widget.store.initialize());
    _releaseNativeCover();
  }

  void _releaseNativeCover() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      try {
        await _privacy.invokeMethod<void>('lockScreenReady');
      } on PlatformException {
        /* A missing native bridge never unlocks Flutter. */
      } on MissingPluginException {
        /* Widget tests have no native bridge. */
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (state == AppLifecycleState.inactive && widget.store.biometricPending) {
      widget.store.biometricPromptInactive();
    } else {
      widget.store.setActive(state == AppLifecycleState.resumed);
    }
    if (state == AppLifecycleState.detached) widget.store.lock();
    if (state == AppLifecycleState.resumed) {
      _releaseNativeCover();
      unawaited(widget.store.refreshBiometricAvailability());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: !widget.store.unlocked,
            child: TickerMode(
              enabled: widget.store.unlocked,
              child: ExcludeFocus(
                excluding: !widget.store.unlocked,
                child: widget.child,
              ),
            ),
          ),
          if (!widget.store.unlocked)
            Positioned.fill(
              child: Overlay.wrap(
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle.dark,
                  child: _PinScreen(
                    key: ValueKey(widget.store.epoch),
                    store: widget.store,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _PinScreen extends StatefulWidget {
  const _PinScreen({super.key, required this.store});
  final PinLockStore store;
  @override
  State<_PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<_PinScreen> {
  final _controller = TextEditingController();
  String? _firstPin;
  bool _showPin = false;
  String? _message;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.store.hasPin) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.clear();
    _controller.dispose();
    _firstPin = null;
    super.dispose();
  }

  Future<void> _submit() async {
    final store = widget.store;
    if (store.busy || store.retrySeconds > 0) return;
    final pin = _controller.text;
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _message = 'Enter exactly six digits.');
      return;
    }
    _controller.clear();
    if (!store.hasPin && _firstPin == null) {
      setState(() {
        _firstPin = pin;
        _message = null;
      });
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final error = store.hasPin
        ? await store.unlock(pin)
        : await store.createPin(_firstPin!, pin);
    if (!mounted) return;
    setState(() {
      _message = error;
      if (error != null && !store.hasPin) _firstPin = null;
    });
  }

  Future<void> _useBiometrics() async {
    _controller.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _message = null);
    final message = await widget.store.unlockWithBiometrics();
    if (mounted) setState(() => _message = message);
  }

  void _choosePin() {
    _controller.clear();
    setState(() {
      _showPin = true;
      _message = null;
    });
  }

  void _chooseBiometrics() {
    final store = widget.store;
    if (store.biometricEnabled && store.biometricAvailable) {
      unawaited(_useBiometrics());
    } else {
      setState(
        () => _message = store.biometricAvailable
            ? 'Unlock with your PIN, then enable ${store.biometricLabel} in Profile → Security.'
            : 'No enrolled biometrics are available to this app. Use your PIN to continue.',
      );
    }
  }

  Widget _pinEntry(
    BuildContext context,
    String phone,
    bool confirming,
    bool waiting,
  ) {
    final store = widget.store;
    final message = waiting
        ? 'Try again in ${store.retrySeconds} seconds.'
        : _message;
    return Scaffold(
      backgroundColor: designBlue,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 88,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          if (store.hasPin)
                            IconButton(
                              tooltip: 'Back to unlock options',
                              onPressed: store.busy
                                  ? null
                                  : () {
                                      _controller.clear();
                                      setState(() {
                                        _showPin = false;
                                        _message = null;
                                      });
                                    },
                              icon: const Icon(
                                Icons.arrow_circle_left_outlined,
                                size: 32,
                                color: Colors.white,
                              ),
                            )
                          else
                            const SizedBox(width: 48),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                              child: WalletLogo(height: 44),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 88,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(36),
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      28,
                      30,
                      28,
                      20 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              store.hasPin
                                  ? phone
                                  : confirming
                                  ? 'Confirm your PIN'
                                  : 'Create your PIN',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 26,
                                color: designNavy,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              store.hasPin
                                  ? 'Please enter your six-digit PIN'
                                  : confirming
                                  ? 'Enter the same six digits again.'
                                  : 'Choose six digits to protect your wallet.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: designNavy,
                              ),
                            ),
                            const SizedBox(height: 26),
                            PinKeypad(
                              value: _controller.text,
                              enabled: store.active && !store.busy && !waiting,
                              onChanged: (value) {
                                setState(() {
                                  _controller.text = value;
                                  _message = null;
                                });
                                if (store.hasPin && value.length == 6) {
                                  unawaited(_submit());
                                }
                              },
                            ),
                            if (message != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  message,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFB42318),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            if (store.busy)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            if (!store.hasPin) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: store.busy || waiting
                                      ? null
                                      : _submit,
                                  child: Text(
                                    confirming ? 'Save PIN' : 'Continue',
                                  ),
                                ),
                              ),
                              if (confirming)
                                TextButton(
                                  onPressed: store.busy
                                      ? null
                                      : () {
                                          _controller.clear();
                                          setState(() {
                                            _firstPin = null;
                                            _message = null;
                                          });
                                        },
                                  child: const Text('Choose a different PIN'),
                                ),
                            ],
                            const SizedBox(height: 14),
                            TextButton.icon(
                              onPressed: () => setState(
                                () => _message = 'Use your PIN or enabled biometrics. Forgotten-PIN recovery is not available yet.',
                              ),
                              icon: const Icon(Icons.help_outline, size: 18),
                              label: const Text('Need help?'),
                            ),
                            const Text(
                              'DEMO WALLET · No real funds',
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final ready = store.initialized;
    final confirming = !store.hasPin && _firstPin != null;
    final waiting = store.retrySeconds > 0;
    final choices = ready && store.hasPin && !_showPin;
    final phone = profileStore.profile.phoneNumber;
    final maskedPhone = phone.length >= 4
        ? '+675 •••• ${phone.substring(phone.length - 4)}'
        : 'Your demo wallet';
    if (ready && !choices) {
      return _pinEntry(context, maskedPhone, confirming, waiting);
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final headerHeight = choices || !ready
                ? (constraints.maxHeight * .36).clamp(140.0, 300.0)
                : 120.0;
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: headerHeight,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            WalletLogo(height: headerHeight < 220 ? 64 : 110),
                            if (headerHeight >= 220) ...[
                              const SizedBox(height: 6),
                              const Text(
                                'Send home. Pay everyday.',
                                style: TextStyle(
                                  color: designNavy,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                'DEMO WALLET',
                                style: TextStyle(
                                  color: Colors.black45,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - headerHeight,
                    ),
                    decoration: const BoxDecoration(
                      color: designBlue,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(38),
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_showPin && store.hasPin)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  tooltip: 'Back to unlock options',
                                  onPressed: store.busy
                                      ? null
                                      : () {
                                          _controller.clear();
                                          setState(() {
                                            _showPin = false;
                                            _message = null;
                                          });
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            Text(
                              !ready
                                  ? 'App lock'
                                  : store.hasPin
                                  ? 'Welcome back'
                                  : confirming
                                  ? 'Confirm your PIN'
                                  : 'Create your PIN',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (store.hasPin) ...[
                              Text(
                                maskedPhone,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Text(
                              !ready
                                  ? 'Checking secure storage.'
                                  : choices
                                  ? 'Choose how to unlock your wallet'
                                  : store.hasPin
                                  ? 'Enter your six-digit PIN.'
                                  : confirming
                                  ? 'Enter the same six digits again.'
                                  : 'Choose six digits to protect your demo wallet.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 28),
                            if (!ready) ...[
                              if (store.error != null) ...[
                                Text(
                                  store.error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: store.busy
                                      ? null
                                      : store.initialize,
                                  child: const Text('Retry secure storage'),
                                ),
                              ] else
                                const CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                            ] else if (choices) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _UnlockChoice(
                                      key: const ValueKey('choose-biometrics'),
                                      semanticLabel:
                                          'Unlock with ${store.biometricLabel}',
                                      icon: Icons.face_outlined,
                                      onTap: store.busy
                                          ? null
                                          : _chooseBiometrics,
                                      muted:
                                          !store.biometricAvailable ||
                                          !store.biometricEnabled,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: _UnlockChoice(
                                      key: const ValueKey('choose-pin'),
                                      semanticLabel: 'Use PIN passcode',
                                      icon: Icons.dialpad_rounded,
                                      onTap: store.busy ? null : _choosePin,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              if (store.biometricAvailable &&
                                  !store.biometricEnabled)
                                Text(
                                  'Enable ${store.biometricLabel} in Security after unlocking.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              if (store.biometricPending) ...[
                                const SizedBox(height: 16),
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ],
                            ] else ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  confirming
                                      ? 'Confirm six-digit PIN'
                                      : 'Six-digit PIN',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              PinKeypad(
                                value: _controller.text,
                                enabled:
                                    store.active && !store.busy && !waiting,
                                onChanged: (value) {
                                  setState(() {
                                    _controller.text = value;
                                    _message = null;
                                  });
                                  if (store.hasPin && value.length == 6) {
                                    unawaited(_submit());
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              if (!store.hasPin)
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: designBlue,
                                      disabledBackgroundColor: Colors.white38,
                                    ),
                                    onPressed: store.busy || waiting
                                        ? null
                                        : _submit,
                                    child: store.busy
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            confirming
                                                ? 'Save PIN'
                                                : 'Continue',
                                          ),
                                  ),
                                ),
                              if (store.hasPin && store.busy)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              if (confirming && !store.busy)
                                TextButton(
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() {
                                      _firstPin = null;
                                      _message = null;
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Choose a different PIN'),
                                ),
                            ],
                            if (waiting ||
                                _message != null ||
                                store.biometricMessage != null) ...[
                              const SizedBox(height: 20),
                              Text(
                                waiting
                                    ? 'Try again in ${store.retrySeconds} seconds.'
                                    : (_message ?? store.biometricMessage)!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
                            TextButton.icon(
                              onPressed: () => setState(
                                () => _message = 'Use your app PIN, or biometrics if you previously enabled them. Forgotten-PIN recovery is not available yet.',
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.help_outline, size: 18),
                              label: const Text('Need help?'),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'DEMO ONLY · No real funds',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            if (!store.hasPin && ready) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Keep your PIN safe. PIN recovery is not available yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _UnlockChoice extends StatelessWidget {
  const _UnlockChoice({
    super.key,
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
    this.muted = false,
  });
  final String semanticLabel;
  final IconData icon;
  final VoidCallback? onTap;
  final bool muted;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    button: true,
    enabled: onTap != null,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: muted ? Colors.white38 : Colors.white,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: icon == Icons.face_outlined
                      ? CustomPaint(
                          key: const ValueKey('face-id-symbol'),
                          size: const Size(54, 54),
                          painter: _FaceIdSymbolPainter(
                            color: muted ? Colors.white60 : Colors.white,
                          ),
                        )
                      : Icon(
                          icon,
                          size: 54,
                          color: muted ? Colors.white60 : Colors.white,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FaceIdSymbolPainter extends CustomPainter {
  const _FaceIdSymbolPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(5, 22)
        ..lineTo(5, 11)
        ..quadraticBezierTo(5, 5, 11, 5)
        ..lineTo(22, 5)
        ..moveTo(42, 5)
        ..lineTo(53, 5)
        ..quadraticBezierTo(59, 5, 59, 11)
        ..lineTo(59, 22)
        ..moveTo(59, 42)
        ..lineTo(59, 53)
        ..quadraticBezierTo(59, 59, 53, 59)
        ..lineTo(42, 59)
        ..moveTo(22, 59)
        ..lineTo(11, 59)
        ..quadraticBezierTo(5, 59, 5, 53)
        ..lineTo(5, 42),
      pen,
    );
    canvas.drawLine(const Offset(20, 22), const Offset(20, 27), pen);
    canvas.drawLine(const Offset(45, 22), const Offset(45, 27), pen);
    canvas.drawPath(
      Path()
        ..moveTo(32, 23)
        ..lineTo(35, 34)
        ..quadraticBezierTo(35, 37, 31, 37),
      pen,
    );
    canvas.drawPath(
      Path()
        ..moveTo(21, 43)
        ..quadraticBezierTo(32, 54, 44, 43),
      pen,
    );
  }

  @override
  bool shouldRepaint(_FaceIdSymbolPainter oldDelegate) =>
      oldDelegate.color != color;
}
