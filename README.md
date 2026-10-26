# Kina Wallet — Flutter starter

A small learning prototype for a Papua New Guinea wallet. It has a kina balance, a privacy toggle, Home / Activity / Profile navigation, sample transactions, and explanatory previews for sending money, adding money, QR payments, mobile top-up, electricity, water, and rent.

**All money and transactions are fictional.** No authentication, Firebase, real payment services, camera access, exchange rate quotes, or transfers are connected. Tapping an action explains the intended flow; it does not make a payment.

## Open and run

1. Open `/Users/warrenmalawae/Developer/kina_wallet` in VS Code using File → Open Folder.
2. Open Terminal → New Terminal.
3. Run `flutter pub get`.
4. Run `flutter run -d chrome`.
5. Keep the terminal open. After changing code, save and press `r` in that terminal to hot reload. Press `R` for a full restart or `q` to stop.

The project includes Android, iOS, and web folders. Chrome is ready on this Mac; Android SDK and iOS simulator setup are separate steps.

## Where to edit

```text
lib/
  main.dart                       App theme, bottom tabs, preview sheet
  models/demo_transaction.dart    Sample balance, transactions, transaction list
  screens/home_screen.dart        Dashboard and service shortcuts
  screens/activity_screen.dart    Activity screen
  screens/profile_screen.dart     Profile screen
test/widget_test.dart             Balance toggle, navigation, preview tests
```

`navy` and `walletBlue` in `main.dart` control the main colors. Change `demoBalanceToea` in `models/demo_transaction.dart` to change the sample balance (100 toea = 1 kina). Change the labels and layout in `home_screen.dart` to practice.

## Suggested next steps together

1. Run the starter and inspect the three tabs.
2. Make one small text or color change and hot reload.
3. Add a Send Money form with recipient and amount validation.
4. Add a review screen and a clearly marked demo receipt.
5. Build bill forms one service at a time.
6. Decide on persistence and authentication after the basic flows are understood.

International transfers should eventually show the sender's PHP amount, fees, exchange rate, PGK received, and delivery estimate. Those details must come from a connected provider, not invented live rates.

## Checks

```sh
flutter analyze
flutter test
flutter build web
```
