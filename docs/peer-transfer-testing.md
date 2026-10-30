# Two-account demo transfers

All funds are fictional. This build sends between distinct confirmed Kina Wallet test accounts. Enter or scan a receiving account code, match the server-provided name, review the amount, then confirm. Phone numbers and contact labels are not account identity verification.

## Prepare the second account

1. Open the kina-wallet-sandbox project in Supabase: https://supabase.com/dashboard/project/gwksimuqnzyckjvlhwof/auth/users
2. Under Authentication → Users, add/create a new user with a different test email. Choose its password privately (at least 12 characters) and enable Auto Confirm for this sandbox test user. This avoids depending on Free-plan confirmation email delivery for the second address. Do not change global email-confirmation settings.
3. Keep your original account signed in on the physical iPhone. Sign out of that account on the simulator, then sign in with the new test user.
4. Edit the simulator's cloud profile to a recognizable name such as Simulator Test. My demo QR now shows a receiving account code even without an optional demo mobile number.

If the simulator is already running Flutter, press capital R in that terminal to hot restart after the source update. Otherwise start the iPhone 17 Pro simulator and run `flutter run -d A4D68C6E-D1E3-46A0-A294-06CEE388A1D2` from the project folder. No second-account password should be shared in chat.

## Test checklist

- Copy the simulator account's receiving code from Profile → My demo QR. On the iPhone, open Send, enter that code and K 10. The review must show the simulator account's actual cloud display name.
- Confirm once. The iPhone balance decreases K 10. Refresh the simulator: its balance increases K 10. Each History shows one leg and the same CLOUD-TRANSFER reference.
- Send K 5 back using the iPhone's receiving code. Check the reverse debit/credit and shared reference.
- Try your own receiving code, a random/nonexistent code and an amount greater than your balance. None may change either wallet.
- Rapidly tap confirmation. Only one transfer should be recorded.
- Save a contact's receiving code with its fictional name/mobile, reopen it from Send and check that the matched server name appears before confirmation.
- Restart both apps and refresh: both balances and histories must remain correct.
- Scan the other account's new QR as an alternative to pasting the receiving code. Old version-1 name/mobile QR data does not identify a cloud account; enter the receiving code before a cloud transfer.
- If a connection failure leaves an uncertain update, use Retry pending update. Its account target and request ID persist across app restarts; don't create a new payment for the same uncertain operation.

## Implementation and validation

The database verifies the authenticated sender and confirmed target, locks wallets in sorted UUID order, checks funds/limits, then records debit and credit atomically. Both entries carry one server-generated transfer ID and timestamp. Sender request IDs prevent duplicate debit/credit, including retries after the recipient has deleted their account. A counterparty retains its own historical receipt if the other user deletes their account.

Existing local demo data and old debit-only cloud records stay intact. New cloud sends require a matched receiving code; legacy clients cannot create new debit-only sends. Bills/top-ups remain simulated debits and Cash In creates fictional funds.

Validation in this build: Flutter regression/widget tests; rolled-back SQL assertions for matching legs, ownership, unknown/self recipients, overspending, changed replay payloads and deletion/retry behavior; concurrent opposing transfers and competing debits on disposable fixtures; authenticated HTTP lookup/transfer/retry snapshots proving sender K 90 / receiver K 10 and matching references. All fixture accounts were removed. Owner-operated iPhone/simulator testing remains to be completed.
