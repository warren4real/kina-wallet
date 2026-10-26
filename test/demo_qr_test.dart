import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/models/demo_qr.dart';
import 'package:kina_wallet/models/recipient.dart';

void main() {
  test('Demo QR round trip preserves and trims recipient details', () {
    final recipient = DemoQr.decode(
      DemoQr.encode(
        const Recipient(name: ' Demo Shop ', phoneNumber: '71234567'),
      ),
    );
    expect(recipient.name, 'Demo Shop');
    expect(recipient.phoneNumber, '71234567');
  });

  test('Rejects malformed and unsupported payloads', () {
    for (final raw in [
      'not json',
      '[]',
      '{}',
      jsonEncode({
        'type': 'other',
        'version': 1,
        'name': 'Shop',
        'phoneNumber': '71234567',
      }),
      jsonEncode({
        'type': 'kina_wallet_demo',
        'version': 1.0,
        'name': 'Shop',
        'phoneNumber': '71234567',
      }),
      jsonEncode({
        'type': 'kina_wallet_demo',
        'version': 2,
        'name': 'Shop',
        'phoneNumber': '71234567',
      }),
    ]) {
      expect(() => DemoQr.decode(raw), throwsFormatException);
    }
  });

  test('Rejects invalid recipient fields and oversized payloads', () {
    for (final fields in [
      {'name': '', 'phoneNumber': '71234567'},
      {'name': 'Shop', 'phoneNumber': '123'},
      {'name': 42, 'phoneNumber': '71234567'},
    ]) {
      expect(
        () => DemoQr.decode(
          jsonEncode({'type': 'kina_wallet_demo', 'version': 1, ...fields}),
        ),
        throwsFormatException,
      );
    }
    expect(() => DemoQr.decode('x' * 2049), throwsFormatException);
  });
}
