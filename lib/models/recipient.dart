class Recipient {
  final String name;
  final String phoneNumber;

  const Recipient({required this.name, required this.phoneNumber});

  // Save values in a format device storage can understand.
  Map<String, dynamic> toJson() {
    return {'name': name, 'phoneNumber': phoneNumber};
  }

  // Recreate a recipient from saved data.
  factory Recipient.fromJson(Map<String, dynamic> json) {
    return Recipient(
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
    );
  }
}
