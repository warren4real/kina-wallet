import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_actions_store.dart';
import '../models/wallet_store.dart';
import 'auth_links.dart';

class SupabaseAccountActions implements AccountActionsGateway {
  SupabaseAccountActions(this.client);
  final SupabaseClient client;
  @override
  Future<void> requestReset(String email) async {
    await client.auth
        .resetPasswordForEmail(email, redirectTo: kinaAuthRedirect)
        .timeout(const Duration(seconds: 20));
  }

  @override
  Future<void> completeReset(
    String password, {
    required String expectedUser,
    required String expectedSession,
  }) async {
    final session = client.auth.currentSession;
    if (session == null ||
        session.user.id != expectedUser ||
        authSessionId(session) != expectedSession) {
      throw const AccountActionFailure(
        'The recovery session expired. Request a new reset link.',
      );
    }
    await client.auth
        .updateUser(UserAttributes(password: password))
        .timeout(const Duration(seconds: 20));
    // Do not sign out a different session that arrived during the network call.
    if (client.auth.currentUser?.id == expectedUser &&
        authSessionId(client.auth.currentSession) == expectedSession) {
      try {
        await client.auth.signOut(scope: SignOutScope.global);
      } catch (_) {}
    }
  }

  @override
  Future<void> cancelRecovery() async {
    // SDK clears the local session before making the logout request.
    try {
      await client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }

  @override
  Future<void> deleteAccount(String expectedUser, String password) async {
    if (client.auth.currentUser?.id != expectedUser) {
      throw const AccountActionFailure(
        'The active account changed. Reopen account settings.',
      );
    }
    try {
      final result = await client.functions
          .invoke(
            'delete-demo-account',
            body: {
              'expectedUser': expectedUser,
              'password': password,
              'confirm': 'DELETE',
            },
          )
          .timeout(const Duration(seconds: 30));
      if (result.data is! Map || result.data['deleted'] != true) {
        throw const AccountActionFailure(
          'Account deletion was not confirmed. Sign in again before retrying.',
        );
      }
    } on FunctionException catch (error) {
      throw AccountActionFailure(
        error.status == 401
            ? 'Your account password or session was not accepted.'
            : 'Could not confirm deletion. Sign in again before retrying.',
      );
    }
    if (client.auth.currentUser?.id == expectedUser) {
      try {
        await client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
    }
    await walletStore.clearPendingForDeletedAccount(expectedUser);
  }
}
