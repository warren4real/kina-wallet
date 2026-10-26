import 'dart:convert';

import 'recipient.dart';

class DemoQr {
  static String encode(Recipient recipient) {
    final name = recipient.name.trim();
    final phone = recipient.phoneNumber.trim();

    _validateRecipient(name, phone);

    return jsonEncode({
      'type': 'kina_wallet_demo',
      'version': 1,
      'name': name,
      'phoneNumber': phone,
    });
  }

  static Recipient decode(String raw) {
    if (raw.length > 2048) {
      throw const FormatException('Demo QR data is too long.');
    }

    final dynamic data;

    try {
      data = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Invalid demo QR data.');
    }

    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid demo QR format.');
    }

    if (data['type'] != 'kina_wallet_demo' ||
        data['version'] is! int ||
        data['version'] != 1) {
      throw const FormatException(
        'This is not a supported Kina Wallet demo QR.',
      );
    }

    final name = data['name'];
    final phone = data['phoneNumber'];

    if (name is! String || phone is! String) {
      throw const FormatException('The demo QR is missing recipient details.');
    }

    final cleanName = name.trim();
    final cleanPhone = phone.trim();

    _validateRecipient(cleanName, cleanPhone);

    return Recipient(name: cleanName, phoneNumber: cleanPhone);
  }

  static void _validateRecipient(String name, String phone) {
    if (name.isEmpty || name.length > 80) {
      throw const FormatException(
        'The recipient name must contain 1–80 characters.',
      );
    }

    if (!RegExp(r'^\d{8}$').hasMatch(phone)) {
      throw const FormatException('The mobile number must contain 8 digits.');
    }
  }
}
