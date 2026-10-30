import 'recipient.dart';
import 'sandbox_account_store.dart';
import 'profile_store.dart';
import 'wallet_store.dart';

class WalletIdentity {
  const WalletIdentity(this.name, this.contact, this.recipient);
  final String name;
  final String contact;
  final Recipient? recipient;
  static WalletIdentity get current => resolve(
    local: profileStore.profile,
    activeAccountId: walletStore.accountId,
    account: sandboxAccountStore.account,
  );
  static WalletIdentity resolve({
    required Recipient local,
    required String? activeAccountId,
    required SandboxAccount? account,
  }) {
    if (activeAccountId == null) {
      return WalletIdentity(local.name, '+675 ${local.phoneNumber}', local);
    }
    if (account == null || account.id != activeAccountId) {
      return const WalletIdentity('Test account', 'Loading account…', null);
    }
    return WalletIdentity(
      account.displayName,
      account.email,
      account.phoneNumber == null
          ? null
          : Recipient(
              name: account.displayName,
              phoneNumber: account.phoneNumber!,
            ),
    );
  }

  String get lockedLabel {
    final phone = recipient?.phoneNumber;
    if (phone != null && phone.length >= 4) {
      return '+675 •••• ${phone.substring(phone.length - 4)}';
    }
    return 'Your test account';
  }
}
