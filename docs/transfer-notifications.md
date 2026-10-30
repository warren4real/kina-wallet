# Automatic demo transfer updates

While the app is foregrounded, a lifecycle-aware timer refreshes the cloud wallet and transfer inbox every 10 seconds. Returning to the app triggers a refresh immediately. Polls do not overlap, pause in the background, and never submit or retry a payment. Existing pending-payment safety remains unchanged.

The inbox is derived from completed peer-transfer ledger rows, for both incoming and outgoing transfers. Cash In, old debit-only entries and bill simulations do not create peer-transfer alerts. Existing paired transfers appear unread initially. The bell shows the unread count. Tapping an alert opens its matching transaction details and saves its read marker in Supabase. Read status is account-specific and synchronizes on the next refresh. A failed read write keeps the alert unread and shows a retry message.

`demo_transfer_reads` stores only owner/request/read timestamp, references the matching ledger leg, and cascades on deletion. Owner-only RLS plus limited column grants permit reading and inserting markers; clients cannot change ledger values, another account's markers, or the server timestamp. Invoker RPCs reject an unexpected authenticated owner. Notification listing shows the latest 100 peer transfers, with total unread count. No OS push notification service or permission is added: alerts arrive when the app is open or reopened.

## Device test checklist

- Run the latest build on two distinct accounts, one on iPhone and one on Simulator.
- Keep the receiving app open. Send K10 from the other account. Within about 10 seconds, balance and History should update without tapping refresh.
- The receiver bell should gain an unread count. Open Notifications and check the incoming sender name and K10 amount. The sender also gets an outgoing transfer entry.
- Tap an alert: its matching reference/date/amount should open, and its unread count should decrease.
- Restart the app: the read marker must remain saved. Sign into the same account on another device and wait for refresh: the read state should match.
- Background the receiving app, send another transfer, then return: wallet and inbox should refresh. Existing PIN/Face ID and 30-second grace behavior should continue.
- Go offline: prior alerts should remain visible with an error after refresh. Reconnect and refresh or wait for the next check.
- Switch accounts or sign out: the previous account's alerts and badge must clear immediately.

All funds remain fictional. Owner-operated iPhone/Simulator tests are still required after installation.

## Build verification — 31 October 2026

- Full Flutter suite: 109 tests passed. Focused notification navigation tests also passed after the final route-refresh adjustment.
- Flutter analyzer: no issues; git diff whitespace checks passed.
- Signed iPhone release: built successfully (20.9 MB).
- Hosted rollback-only fixtures verified incoming/outgoing alerts, exclusion of Cash In, saved/idempotent read status, wrong-owner rejection, cross-account RLS isolation and anonymous denial. Fixture users and transfers were rolled back; existing user funds were untouched.
- Database security advisor found no new schema findings; the previously known leaked-password-protection setting remains unchanged.
- The iPhone/Simulator checklist above remains for owner-operated validation.
