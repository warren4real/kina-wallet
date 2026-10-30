# Two-account demo transfers

Scope: atomic sender debit and recipient credit between distinct confirmed demo accounts, matching history references, verified review and receiving codes/QR. Preserve existing local wallet, old history and pending-request safety. No real funds or provider integration.

- [x] Add tests for receiving-code/QR round trips, pending recipient persistence and repeat-safe credit after a lost response.
- [x] Add narrowly scoped recipient lookup and atomic transfer RPCs. Lock wallets in UUID order, recheck both accounts/balances, and reuse the sender request ID for retries. Record both legs with one server transfer reference. Reject new generic debit-only sends, keeping old committed retry support.
- [x] Extend pending commands with recipient ID, gateway lookup/transfer calls and sender-bound review. Add account QR codes and optional receiving codes on saved recipients; no public phone/email directory.
- [x] Test live fixtures for atomicity, ownership, self/unknown targets, repeat payloads, overspending, opposing transfers and deletion/retry behavior. Review the implementation independently.
- [x] Run full Flutter tests/analyzer, release build and install iPhone; give simulator restart and two-account test instructions.

Design: the receiving code is the high-entropy account UUID, shared intentionally by the recipient. Lookup reveals only that account's display name to a signed-in confirmed caller. Phone numbers are not verified identifiers. Cloud QR v2 carries receiving ID; local QR v1 remains supported for local demos. Saved contacts may retain phone-only details but need a receiving code for cloud sends. Existing historical debit-only records do not gain a recipient credit. A counterparty keeps its own receipt if the other account is deleted.

Verified: 103 Flutter tests passed; analyzer and diff checks clean; release iOS build passed. SQL fixture assertions passed; opposing transfers completed and competing debits rejected overspending. Authenticated HTTP lookup/transfer/retry showed K 90 sender / K 10 receiver with one matching reference and wrong-owner rejection. All test accounts removed. Independent review found the stale cloud-review-to-local fallback; regression reproduced it and the sender-scope guard fixed it. iPhone installation completed; second-account and simulator setup are in docs/peer-transfer-testing.md.
