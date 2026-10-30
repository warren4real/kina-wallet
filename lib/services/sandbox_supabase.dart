import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sandbox_account_store.dart';
import '../models/wallet_store.dart';
import 'cloud_wallet_gateway.dart';
import 'transfer_notification_gateway.dart';
import '../models/transfer_notifications.dart';
import 'cloud_recipient_gateway.dart';
import '../models/recipient_store.dart';
import '../models/account_actions_store.dart';
import 'account_actions_gateway.dart';
import 'auth_links.dart';

// Public client configuration. Never put service-role/secret keys in this app.
const sandboxUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://gwksimuqnzyckjvlhwof.supabase.co',
);
const sandboxPublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_t8rbYuGt4RXxtDm4wOzbgQ_OFlmEqCT',
);

class SandboxSessionStorage extends LocalStorage {
  const SandboxSessionStorage();
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  static final _key =
      'kina_wallet_sandbox_session_${Uri.parse(sandboxUrl).host}';
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() => _storage.read(key: _key);
  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;
  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);
  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}

Future<void> initializeSandboxAccounts() async {
  try {
    await Supabase.initialize(
      url: sandboxUrl,
      publishableKey: sandboxPublishableKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: SandboxSessionStorage(),
        authFlowType: AuthFlowType.pkce,
        pkceAsyncStorage: SecurePkceStorage(),
        detectSessionInUri: false,
      ),
    );
    final client = Supabase.instance.client;
    walletStore.configureCloud(SupabaseCloudWallet(client));
    transferNotifications.configure(SupabaseTransferNotifications(client));
    recipientStore.configureCloud(SupabaseCloudRecipients(client));
    void syncWallet() {
      unawaited(transferNotifications.useAccount(client.auth.currentUser?.id));
      unawaited(recipientStore.useAccount(client.auth.currentUser?.id));
      unawaited(walletStore.useAccount(client.auth.currentUser?.id));
    }

    // Read SDK identity, not editable profile fields. A cloud failure must never
    // silently switch a signed-in account to local demo money.
    client.auth.onAuthStateChange.listen(
      (_) => syncWallet(),
      onError: (_) {
        /* Preserve the current source during network errors. */
      },
    );
    syncWallet();
    sandboxAccountStore = SandboxAccountStore(
      gateway: SupabaseSandboxAccounts(client),
    );
    accountActionsStore = AccountActionsStore(
      gateway: SupabaseAccountActions(client),
    );
    unawaited(sandboxAccountStore.initialize());
    unawaited(
      AuthLinkCoordinator(client, accountActionsStore).initialize().catchError((
        _,
      ) {
        accountActionsStore.failLink();
      }),
    );
  } catch (_) {
    // Account-service startup must never erase or disable the existing local demo.
    debugPrint(
      'Sandbox account service could not initialize. Local demo remains available.',
    );
  }
}

class SupabaseSandboxAccounts implements SandboxAccountGateway {
  SupabaseSandboxAccounts(this.client);
  final SupabaseClient client;
  @override
  Stream<String?> get sessions => client.auth.onAuthStateChange
      .map((state) => state.session?.user.id)
      .distinct();

  Future<T> _request<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(const Duration(seconds: 20));
    } on AuthException catch (error) {
      if (error.code == 'email_address_not_authorized' ||
          error.code == 'over_email_send_rate_limit') {
        throw const SandboxAccountFailure(
          'Supabase Free limits confirmation emails. Use your Supabase organization email, or try again later.',
        );
      }
      throw const SandboxAccountFailure(
        'Could not authenticate. Check your email, password, and email confirmation, then retry.',
      );
    }
  }

  Future<SandboxAccount> _profile(User user) async {
    var row = await client
        .from('sandbox_profiles')
        .select('display_name,phone_number')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) {
      final candidate = user.userMetadata?['display_name'];
      final name =
          candidate is String &&
              candidate.trim().isNotEmpty &&
              candidate.trim().length <= 80
          ? candidate.trim()
          : 'Sandbox user';
      try {
        row = await client
            .from('sandbox_profiles')
            .insert({'id': user.id, 'display_name': name})
            .select('display_name,phone_number')
            .single();
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
        row = await client
            .from('sandbox_profiles')
            .select('display_name,phone_number')
            .eq('id', user.id)
            .single();
      }
    }
    return SandboxAccount(
      id: user.id,
      email: user.email ?? '',
      displayName: row['display_name'] as String,
      phoneNumber: row['phone_number'] as String?,
    );
  }

  @override
  Future<SandboxAccount?> restore() => _request(() async {
    if (client.auth.currentSession == null) return null;
    final user = (await client.auth.getUser()).user;
    return user == null ? null : await _profile(user);
  });
  @override
  Future<SandboxAccount?> register(
    String email,
    String password,
    String displayName,
  ) => _request(() async {
    final result = await client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
      emailRedirectTo: kinaAuthRedirect,
    );
    if (result.session == null || result.user == null) return null;
    return _profile(result.user!);
  });
  @override
  Future<SandboxAccount> signIn(String email, String password) =>
      _request(() async {
        final result = await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (result.user == null) {
          throw const SandboxAccountFailure(
            'Sign-in did not complete. Please retry.',
          );
        }
        return _profile(result.user!);
      });
  @override
  Future<SandboxAccount> rename(
    String displayName, {
    required String expectedUser,
    String? phoneNumber,
  }) => _request(() async {
    if (client.auth.currentUser?.id != expectedUser) {
      throw const SandboxAccountFailure(
        'The active account changed. Reopen your profile.',
      );
    }
    final user = (await client.auth.getUser()).user;
    if (user == null || user.id != expectedUser) {
      throw const SandboxAccountFailure(
        'Sign in again to update your profile.',
      );
    }
    final row = await client
        .from('sandbox_profiles')
        .update({'display_name': displayName, 'phone_number': phoneNumber})
        .eq('id', expectedUser)
        .select('display_name,phone_number')
        .single();
    return SandboxAccount(
      id: user.id,
      email: user.email ?? '',
      displayName: row['display_name'] as String,
      phoneNumber: row['phone_number'] as String?,
    );
  });
  @override
  Future<void> signOut() =>
      _request(() => client.auth.signOut(scope: SignOutScope.local));
}
