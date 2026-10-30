class Recipient {
  final String name;
  final String phoneNumber;
  final String? accountId;

  const Recipient({
    required this.name,
    required this.phoneNumber,
    this.accountId,
  });

  // Save values in a format device storage can understand.
  Map<String, dynamic> toJson() {
    return {'name': name, 'phoneNumber': phoneNumber, 'accountId': accountId};
  }

  // Recreate a recipient from saved data.
  factory Recipient.fromJson(Map<String, dynamic> json) {
    return Recipient(
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      accountId: json['accountId'] as String?,
    );
  }
}
