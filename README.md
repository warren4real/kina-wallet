# Kina Wallet

A Flutter prototype for Papua New Guinea with fictional kina balances, saved demo transactions, send/add money flows, bills, mobile top-up, saved recipients and QR scanning. Includes a six-digit local PIN, device biometrics and a 30-second background grace period.

**All money is fictional. No payment provider or real transfers are connected.** Optional Supabase test accounts provide email/password sign-in and a private cloud profile. Signed-in accounts have their own cloud demo balance and transaction history; signing out restores the separate local wallet. Saved recipients sync privately to that account. Local data stays separate. Includes native email callbacks, password recovery, password-confirmed test-account deletion and atomic transfers between demo accounts. See [two-account setup and tests](docs/peer-transfer-testing.md). See [test-account setup and limitations](docs/supabase-sandbox.md).

## Run

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

Use a physical phone to validate camera and biometrics. First-time test accounts require email confirmation. Keep account passwords separate from the local wallet PIN.

## Check

```sh
flutter analyze
flutter test
flutter build ios --release
```

The project includes iOS, Android and web targets; a successful iOS build does not establish validation of all platforms. This remains a learning prototype, without real payment, identity verification or production account recovery.
