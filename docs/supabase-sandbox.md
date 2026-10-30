# Supabase test accounts

Project: kina-wallet-sandbox, Wazza’s Org (Free), Singapore.
Dashboard: https://supabase.com/dashboard/project/gwksimuqnzyckjvlhwof

Open Profile → Sandbox account. Create a test account using your Supabase organization email and a separate password of at least 12 characters. Default Supabase email delivery is limited to organization members and rate limited. Open the newest confirmation link on the same phone that requested it. The exact native callback com.kinawallet.app://auth/callback is registered on iOS/Android and configured as the Supabase Site URL and sole additional redirect. PKCE exchanges the code using a verifier in secure device storage. Expired or cross-device links show a recoverable error; request a new link from the intended phone. No paid email or SMS service is configured.

A private display name and optional fictional PNG mobile number are stored in public.sandbox_profiles, linked to the authenticated user. The optional number is not verified and is used only for the prototype QR format. Supabase Auth stores the email and manages password authentication. RLS and explicit column grants isolate each profile. Session tokens are persisted in device secure storage; account passwords are not persisted by the app. The wallet PIN remains a separate local lock.

Signed-in accounts now use a separate cloud demo balance and history. Each account starts at K 0.00; use Cash In to add fictional funds. Home and History identify the active wallet. Signing out restores the original local wallet, which is never automatically imported. Saved recipients now sync privately to the signed-in account; the separate local list is preserved for sign-out. The PIN stays on the phone. There are no real payments, phone verification or identity verification. Do not use real financial or identity information.

The app uses only the public publishable key. Override SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY with Flutter --dart-define when switching projects. Never put a service-role or secret key in the app.

The remotely applied create_private_sandbox_profiles migration is recorded in Supabase migration history. supabase/schema.sql is a reference copy, not an automatically applied local migration. Do not reapply it to the existing project.

Validation: account store and screen tests use a fake gateway; they do not prove live email delivery or real-account login. A real-account sign-up, confirmation, sign-in and restored session must be tested on-device by the account owner.

## Cloud demo wallet

All existing demo deposit, transfer and bill flows use the cloud wallet while signed in. Cloud Send now performs a paired debit/credit between matched demo accounts using receiving codes. Bills and top-ups remain simulated debits with no real provider connection. The balance and append-only ledger are updated atomically on the server, using integer toea and a per-account UUID. Limits are K 0.01–10,000 per update and K 10,000,000 maximum demo balance. A row lock prevents concurrent overspending. Clients have SELECT-only access to their own wallet/history; narrow private server functions handle mutations, deriving owner from the JWT and checking the request's expected account before execution. Confirmed email accounts only.

Cloud writes require an internet connection. A pending command is stored under an account-specific phone key before sending. If the response is uncertain, other updates are blocked: refresh the wallet and choose Retry pending update. That reuses the same request ID even after restarting. Successful retries show the transaction in History; they do not create another deposit/payment. Account switching clears the previous cloud wallet immediately and closes its open forms. Returning to an account with an in-flight request waits for it to finish. No cloud history is cached to the local demo wallet.

Refresh is available on Home/History and runs when the app returns to the foreground. Changes from another device appear on refresh; this stage does not use live Realtime subscriptions. History currently loads as one snapshot; pagination is future work for larger histories. Clearing app storage or uninstalling can remove a pending request ID, so check cloud History before repeating an uncertain operation after reinstalling.

Database references: cloud_wallet_schema.sql records the two applied cloud migrations; cloud_wallet_checks.sql runs isolation, wrong-account, duplicate, invalid, insufficient-funds and permission assertions inside a rolled-back transaction. A separate live concurrency check verified one of two K 80 debits from K 100 succeeds, with K 20 remaining; all fixture accounts were deleted. Tests do not add money to the owner's actual account.

Supabase's security advisor currently reports leaked-password protection disabled. No paid upgrade or Auth setting change was made. Real payments remain outside this prototype.

## Account completion build

Home, Profile and My QR resolve the signed-in cloud identity. A new account without a fictional phone does not inherit the local number: My QR asks for an optional demo number. Cloud profile editing captures the expected account ID; identity changes clear stale profile responses and reload the new owner.

Saved recipients use owner-scoped CRUD with RLS, a composite user/phone primary key and strict names/mobile validation. Refresh is available on Saved Recipients and on foreground resume. A failed cloud load blocks edits, rather than falling back to local contacts. There is no automatic import of the existing local list.

Forgot account password is under Sandbox account. The new-password form is gated to the verified recovery user and session, remains behind the device PIN, and requires matching passwords of at least 12 characters. A successful reset signs out that recovery session; sign in with the new password. The recovery form preserves Navigator/Overlay support for text editing. A later identity change cannot redirect an old reset or profile edit to another account.

Delete test account requires the current account password and typing DELETE in the app. The deployed delete-demo-account Edge Function retains built-in JWT verification, verifies the caller through Auth, matches the expected owner, rechecks the password, revokes that user's sessions, then calls the official Admin deleteUser API with a server-only key. Profile, cloud wallet/history and recipients cascade on deletion. Local demo data and PIN are kept. The developer did not delete the owner's account.

Validation: live recipient ownership and cascade assertions passed in a rolled-back transaction. A separate disposable account successfully signed in, was rejected for a wrong deletion password, and was deleted by the deployed function after correct password confirmation; its user/profile/recipient rows were verified absent. No fixture tokens were printed. Native email delivery and the full reset-link flow still require the owner to test with their email; a second physical device remains unverified.

Recipient refresh fix (2026-10-30): Saved Recipients refreshes its cloud data on opening and exposes Refresh recipients in the app-bar toolbar. The refresh action was removed from the removal confirmation. A widget regression reproducing a remote save followed by opening/refreshing the list passed; the full app suite passed 97 tests. This remains refresh-based sync, not Realtime streaming.

## Paired demo transfers

The two-account build is documented in [peer-transfer-testing.md](peer-transfer-testing.md), including second-user setup and one grouped manual checklist. Matching uses a shared receiving UUID and exposes only the target account display name, without a public phone/email directory. QR version 2 carries the account code; local version 1 remains a local-demo format. Saved cloud contacts may include an optional receiving code. Both history legs use a shared CLOUD-TRANSFER reference, while existing records retain their old references.
