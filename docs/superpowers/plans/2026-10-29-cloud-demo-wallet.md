# Cloud Demo Wallet Implementation Plan

Goal: each confirmed account gets a separate zero-balance fictional wallet; preserve the local demo.
Architecture: keep WalletStore as the UI facade. Auth changes switch its data source and clear the previous account immediately. Supabase RPCs perform atomic ledger/balance updates under a row lock, using an account-scoped UUID for idempotency. A separately persisted pending command survives uncertain responses and restarts.
Stack: existing Flutter, secure Auth session storage and Supabase Free. No new subscriptions or real payment integrations.

- [x] Add failing client tests for account isolation, stale responses, zero initial state, local preservation, pending retry after lost responses and reopening.
- [x] Add server schema and RPCs with read-only table grants, RLS and a private narrowly privileged writer. Validate owner, confirmed account, transaction bounds and repeat payloads. Roll back test fixtures.
- [x] Implement gateway, source switching and persisted pending commands. Block writes until loaded; never fall back to local on cloud errors.
- [x] Bind auth lifecycle and add cloud/local status, refresh and explicit pending retry. Clear open routes when the wallet source changes.
- [x] Update docs, run full tests and analyzer, build/install the iPhone release. Test server isolation, idempotency, invalid/insufficient funds and concurrent debits. Do not alter the user's local balance or create real test deposits in their account.

Design calls: cloud starts K 0.00; per-operation cap K 10,000; no real recipient credit (outgoing entries are simulated debits). Refresh on foreground and pull-to-refresh; no Realtime subscription. Existing local data is never imported automatically. Offline cloud operations require a connection; uncertain writes remain pending until safely retried.

Verification: 77 Flutter tests passed. SQL assertions passed including expected-owner mismatch; concurrent overspending check passed and all fixtures were removed. Independent review found expected-owner and pending-cleanup races; both fixed with server assertions and client regression coverage. iPhone build/install validation recorded at completion. No local balances were imported.
