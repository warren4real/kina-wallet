import 'dart:convert';

import 'recipient.dart';
import 'cloud_wallet.dart';

class DemoQr {
  static String encode(Recipient recipient) {
    final name = recipient.name.trim();
    final phone = recipient.phoneNumber.trim();

    _validateRecipient(name, phone, accountId: recipient.accountId);

    return jsonEncode({
      'type': 'kina_wallet_demo',
      'version': recipient.accountId == null ? 1 : 2,
      if (recipient.accountId != null) 'accountId': recipient.accountId,
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
        (data['version'] != 1 && data['version'] != 2)) {
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

    final accountId = data['version'] == 2 ? data['accountId'] : null;
    if (data['version'] == 2 &&
        (accountId is! String || !isReceivingCode(accountId))) {
      throw const FormatException('Invalid receiving account code.');
    }
    _validateRecipient(cleanName, cleanPhone, accountId: accountId as String?);

    return Recipient(
      name: cleanName,
      phoneNumber: cleanPhone,
      accountId: accountId,
    );
  }

  static void _validateRecipient(
    String name,
    String phone, {
    String? accountId,
  }) {
    if (accountId != null && !isReceivingCode(accountId)) {
      throw const FormatException('Invalid receiving account code.');
    }
    if (name.isEmpty || name.length > 80) {
      throw const FormatException(
        'The recipient name must contain 1–80 characters.',
      );
    }

    if (!(accountId != null && phone.isEmpty) &&
        !RegExp(r'^\d{8}$').hasMatch(phone)) {
      throw const FormatException('The mobile number must contain 8 digits.');
    }
  }
}
