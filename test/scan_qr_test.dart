import 'dart:async';

import 'support/test_app.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:kina_wallet/models/demo_qr.dart';
import 'package:kina_wallet/models/recipient.dart';
import 'package:kina_wallet/models/wallet_store.dart';
import 'package:kina_wallet/models/qr_scan_gate.dart';
import 'package:kina_wallet/screens/scan_qr_screen.dart';

class FakeCamera extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  MobileScannerErrorCode? failure;
  int stops = 0;
  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    if (failure != null) throw MobileScannerException(errorCode: failure!);
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(400, 600),
      numberOfCameras: 1,
    );
  }

  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {}
  @override
  Future<void> resetZoomScale() async {}
}

void main() {
  late MobileScannerPlatform previous;
  late FakeCamera camera;
  setUp(() {
    previous = MobileScannerPlatform.instance;
    camera = FakeCamera();
    MobileScannerPlatform.instance = camera;
  });
  tearDown(() async {
    MobileScannerPlatform.instance = previous;
    await camera.captures.close();
  });

  testWidgets(
    'Bottom Scan QR opens camera and returns to the selected History tab',
    (tester) async {
      await tester.pumpWidget(const TestWalletApp());
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      await tester.tap(find.text('Scan QR'));
      await tester.pumpAndSettle();
      expect(find.byType(ScanQrScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Services'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('All Services'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );
      await tester.tap(find.text('Pay Bills'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Water'));
      await tester.pumpAndSettle();
      expect(find.text('Water demo payment'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Choose a bill'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('All Services'), findsOneWidget);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(
        find.text('No registration or verification completed'),
        findsOneWidget,
      );
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('My wallet'), findsOneWidget);
      expect(find.text('Branches'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'Detection gate suppresses duplicates and supports invalid-code retry',
    () {
      final gate = QrScanGate();
      expect(() => gate.accept('bad'), throwsFormatException);
      expect(gate.claimed, isTrue);
      gate.reset();
      final raw = DemoQr.encode(
        const Recipient(name: 'Demo Shop', phoneNumber: '71234567'),
      );
      expect(gate.accept(raw)!.name, 'Demo Shop');
      expect(gate.accept(raw), isNull);
    },
  );

  testWidgets(
    'Valid camera detection opens exactly one prefilled form without moving funds',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final before = walletStore.exportDemoSnapshot();
      await tester.pumpWidget(const MaterialApp(home: ScanQrScreen()));
      await tester.pumpAndSettle();
      final capture = BarcodeCapture(
        barcodes: [
          Barcode(
            format: BarcodeFormat.qrCode,
            rawValue: DemoQr.encode(
              const Recipient(name: 'Scanned Shop', phoneNumber: '71234567'),
            ),
          ),
        ],
      );
      camera.captures.add(capture);
      camera.captures.add(capture);
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields[0].controller!.text, 'Scanned Shop');
      expect(fields[1].controller!.text, '71234567');
      expect(fields[2].controller!.text, isEmpty);
      expect(walletStore.exportDemoSnapshot(), before);
      expect(camera.stops, greaterThan(0));
    },
  );

  testWidgets('Invalid scan stays on scanner and can retry', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ScanQrScreen()));
    await tester.pumpAndSettle();
    camera.captures.add(
      const BarcodeCapture(
        barcodes: [
          Barcode(
            format: BarcodeFormat.qrCode,
            rawValue: 'https://example.com',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Scan again'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Scan again'));
    await tester.pumpAndSettle();
    expect(find.text('Scan again'), findsNothing);
  });

  testWidgets('Permission denial explains recovery and offers paste fallback', (
    tester,
  ) async {
    camera.failure = MobileScannerErrorCode.permissionDenied;
    await tester.pumpWidget(const MaterialApp(home: ScanQrScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Camera access is off.'), findsOneWidget);
    await tester.tap(find.text('Paste demo QR data'));
    await tester.pumpAndSettle();
    expect(find.text('Check a demo code'), findsOneWidget);
  });
}
