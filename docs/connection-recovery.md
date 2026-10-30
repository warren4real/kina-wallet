# Connection and interrupted-update recovery

All funds remain fictional. This build adds last-sync information, a stale-balance warning when the cloud service cannot be reached, and explicit sending/pending/completed/failed states. New updates pause until a successful refresh. The cloud balance is not cached across process restarts: before the first successful sync it stays K —. A definitive server rejection or an unsent local-persistence failure is a failed attempt; it never appears as a completed ledger record. A timeout is pending, not failed, because the server might have committed it.

Every command is persisted per account before submission. The new invoker RPC `cloud_demo_request_status` reads only the authenticated owner's ledger and returns a reference/date only for committed requests. Refresh and foreground polling check a saved request without submitting it; a confirmed receipt clears the pending marker and surfaces completion. The wallet snapshot is loaded after the receipt lookup to include any recovered commit. If the result is still unknown, an explicit retry checks once more, then submits the identical saved command/request ID. Returning online never automatically sends an uncommitted request. The server's existing atomic/idempotent transfer function remains the writer.

Account epoch guards discard late snapshots and receipts after sign-out/switching. Existing local demo money stays separate. A pending request survives app termination on the originating phone. This is not a cross-device pending-request queue; another device sees committed history, while recovery controls remain on the phone that initiated it. A local cleanup failure retains the marker and blocks new writes until it can be cleared safely. A recovered completion on an open review disables confirming again and offers its original receipt, including the server reference/date.

## Grouped device checks

1. While signed into a test account, note the last-updated time. Disable both Wi-Fi and cellular data. Wait for a refresh/check to time out (up to about 30 seconds including the polling interval). The app should show “Offline or service unavailable”, keep its last-known balance/history and timestamp, and pause new payments. A new process without a loaded cloud snapshot shows K — instead.
2. Reconnect and return to the app or tap refresh. The warning should clear and last-updated time advance after a successful sync.
3. Prepare a small K1 transfer online. Confirm and immediately interrupt the connection or close the app. Timing may allow it to complete before interruption; that is valid. If it becomes pending, do not start a new transfer for the same payment.
4. Reopen/reconnect. If the original request committed, it should become Completed without another submission. If unconfirmed, use Check status, then Retry pending update. Sender debit/recipient credit and their shared reference must occur only once. Repeat the retry/check if needed; never create a replacement payment while pending.
5. If recovery happens on the still-open review, Confirm must stay disabled and View completed transfer must open its matching receipt. A genuinely new send starts from a fresh form.
6. Switch accounts during a slow/checking update. The next account must show only its own funds/status. Return to the original account and check its history/recovery status.
7. Try a valid transfer after reconnecting, and verify both accounts' balances, history and notifications. Existing PIN/Face ID and 30-second grace should continue.

Automated fixtures cover interruptions both before and after server commit, restart recovery without resubmitting a committed request, same-ID explicit retry, repeated taps, account changes during submission and lookup, storage failure during retry, and narrow-screen status/recovered-review interaction. The rollback-only SQL checks cover receipt integrity, a missing request, read-only balances, owner isolation and anonymous denial.

## Verification — 31 October 2026

The full Flutter suite passed 119 tests. The focused recovery fixtures reproduced and fixed two classification/reconfirmation edge cases plus the local-cleanup resubmission case. An independent read-only review found no actionable material issues in the recovery scope. Hosted rollback-only SQL checks verified matching reference/date, missing requests, unchanged funds after repeated status checks, account isolation and anonymous denial. Existing owner accounts and funds were not changed by the fixtures. User-operated device interruption tests remain to be completed.

Final analyzer: no issues. Signed iPhone release built successfully (20.9 MB) and installed on 404 NOT FOUND.
