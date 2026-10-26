import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/qr_scan_gate.dart';
import 'send_money_screen.dart';
import 'paste_demo_qr_screen.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});
  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  final _gate = QrScanGate();
  String? _message;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _stop() async {
    try {
      await _controller.stop();
    } catch (_) {
      /* Already stopped or unavailable. */
    }
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await _stop();
      _gate.reset();
      if (mounted) setState(() => _message = null);
      await _controller.start();
    } on MobileScannerException catch (error) {
      if (mounted) setState(() => _message = _cameraMessage(error));
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not start the camera. Try again or paste demo QR data.',
        );
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!mounted || _gate.claimed || _retrying) return;
    final codes = capture.barcodes
        .where(
          (code) =>
              code.format == BarcodeFormat.qrCode && code.rawValue != null,
        )
        .toList();
    if (codes.isEmpty) return;
    try {
      final recipient = _gate.accept(codes.first.rawValue!);
      if (recipient == null) return;
      await _stop();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SendMoneyScreen(initialRecipient: recipient),
        ),
      );
    } on FormatException catch (error) {
      await _stop();
      if (mounted) {
        setState(
          () => _message =
              '${error.message} Use a Kina Wallet demo QR and tap Scan again.',
        );
      }
    }
  }

  void _detectionError(Object error, StackTrace stack) {
    if (!mounted || _gate.claimed) return;
    _gate.pause();
    // No raw payload is logged or uploaded.
    unawaited(_stop());
    setState(
      () => _message = 'The camera could not read this frame. Tap Scan again or paste demo QR data.',
    );
  }

  static String _cameraMessage(MobileScannerException error) {
    if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
      return 'Camera access is off. Enable Camera for Kina Wallet in your device settings, then return and tap Retry camera. You can also paste demo QR data.';
    }
    if (error.errorCode == MobileScannerErrorCode.unsupported) {
      return 'No supported camera is available. For an iPhone simulator, use Paste demo QR data. Test camera scanning on your physical iPhone.';
    }
    return 'Camera unavailable. Try again or use Paste demo QR data.';
  }

  Future<void> _paste() async {
    _gate.pause();
    await _stop();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const PasteDemoQrScreen()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed && !_gate.claimed && !_retrying) {
      unawaited(_retry());
    } else if (state != AppLifecycleState.resumed) {
      unawaited(_stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Scan Demo QR'),
      actions: [
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: _controller,
          builder: (context, state, child) => IconButton(
            tooltip: state.torchState == TorchState.on
                ? 'Turn torch off'
                : 'Turn torch on',
            onPressed:
                state.isRunning && state.torchState != TorchState.unavailable
                ? () async {
                    try {
                      await _controller.toggleTorch();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Torch is unavailable.'),
                          ),
                        );
                      }
                    }
                  }
                : null,
            icon: Icon(
              state.torchState == TorchState.on
                  ? Icons.flash_on
                  : Icons.flash_off,
            ),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: MobileScanner(
                    controller: _controller,
                    useAppLifecycleState: false,
                    onDetect: _onDetect,
                    onDetectError: _detectionError,
                    errorBuilder: (context, error) => ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.camera_alt_outlined,
                                color: Colors.white,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _cameraMessage(error),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _retrying ? null : _retry,
                                child: const Text('Retry camera'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.72,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.fromBorderSide(
                                BorderSide(color: Colors.white70, width: 3),
                              ),
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            flex: 0,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _message ?? 'Point at one Kina Wallet demo QR. A valid scan fills recipient details; you still choose the amount and confirm.',
                    textAlign: TextAlign.center,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _retrying ? null : _retry,
                      child: const Text('Scan again'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _paste,
                    icon: const Icon(Icons.content_paste),
                    label: const Text('Paste demo QR data'),
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
