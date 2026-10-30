# Account Completion Build

User-approved next build: private cloud recipients; account identity throughout the app; email callbacks; password recovery and account deletion. Keep all money fictional and the local demo/PIN intact. No paid subscriptions or email-provider change.

- [x] Add RecipientStore gateway, account switching and owner-scoped CRUD with RLS. Test isolation, failed load, delayed responses, local preservation and a second client.
- [x] Extend private profile with an optional fictional phone. Home/Profile/My QR use the signed-in profile, never another account or local phone. Allow profile editing and clear identity on sign-out.
- [x] Register one exact native auth callback and allowlist it in Supabase. Use SDK PKCE handling, secure verifier storage, recovery routing and expired-link errors. Keep the existing PIN gate.
- [x] Add email password-reset request and new-password/confirmation form. Add current-password-confirmed account deletion through an authenticated Edge Function using server-only Admin API. Never delete the owner's account during development.
- [x] Verify database ownership/grants and fixture deletion, tests/analyzer, build/install iPhone. Provide one grouped manual checklist including recovery/deletion using a disposable test account.

Implementation notes: existing local recipients remain separate; no automatic import. Cloud writes are online-only and refresh after errors. Deletion is irreversible only after explicit confirmation in the app; removal cascades to profile, wallet, history and recipients. Same-device PKCE is required for emailed links in this stage. Multi-device manual testing remains unverified.

Completion evidence (2026-10-30): 96 Flutter tests and 7 deletion-handler tests passed; analyzer and whitespace checks clean; iOS release build passed. Live recipient RLS and cascade checks passed. Deployed deletion function with built-in JWT verification enabled rejected a wrong password and deleted a disposable account after correct confirmation; fixture rows were verified absent. Exact native callback saved in Supabase and iOS/Android registrations added. Recovery/profile account-switch findings and recovery text-overlay failure were fixed with regression coverage. Physical-device email recovery and a second device remain owner/manual tests.
