import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/models/wallet_identity.dart';
import 'package:kina_wallet/models/recipient.dart';
import 'package:kina_wallet/models/sandbox_account_store.dart';

void main() {
  const local = Recipient(name: 'Local demo', phoneNumber: '70000001');
  test('Signed-out identity keeps local details', () {
    final id = WalletIdentity.resolve(
      local: local,
      activeAccountId: null,
      account: null,
    );
    expect(id.name, 'Local demo');
    expect(id.recipient!.phoneNumber, '70000001');
  });
  test('Cloud identity never borrows the local mobile number', () {
    final id = WalletIdentity.resolve(
      local: local,
      activeAccountId: 'A',
      account: const SandboxAccount(
        id: 'A',
        email: 'a@example.com',
        displayName: 'Cloud A',
      ),
    );
    expect(id.name, 'Cloud A');
    expect(id.contact, 'a@example.com');
    expect(id.recipient, isNull);
  });
  test(
    'Optional cloud phone is used in demo QR and stale profiles are hidden',
    () {
      const account = SandboxAccount(
        id: 'A',
        email: 'a@example.com',
        displayName: 'Cloud A',
        phoneNumber: '72222222',
      );
      final id = WalletIdentity.resolve(
        local: local,
        activeAccountId: 'A',
        account: account,
      );
      expect(id.recipient!.phoneNumber, '72222222');
      final switched = WalletIdentity.resolve(
        local: local,
        activeAccountId: 'B',
        account: account,
      );
      expect(switched.name, 'Test account');
      expect(switched.recipient, isNull);
    },
  );
}
