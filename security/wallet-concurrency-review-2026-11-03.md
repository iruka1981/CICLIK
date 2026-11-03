# Cíclic — wallet concurrency hardening (DRAFT, no production changes)

## Confirmed from live database read-only inspection (2026-11-03)
- `public.ciclik_transfer` locks `hashtextextended('ciclik_transfer:' || sender_id,0)`.
- `ciclik_private.charge_workshop` locks `hashtextextended('ciclik_wallet:' || user_id,0)`.
- `public.ciclik_process_clothes` checks transaction sum without locking.
- These locks are inconsistent; concurrent spend paths can each pass a balance check.

## Required implementation
1. All debit operations must acquire the **same per-user transaction-scoped advisory lock** BEFORE reading balance: `pg_advisory_xact_lock(hashtextextended('ciclik_wallet:' || user_id::text,0))`.
2. Change transfer sender lock to the common wallet lock; preserve request-id idempotency and self-transfer rejection.
3. For clothing exits, lock the member wallet before checking the balance and writing operation records; consider locking clothing entries too to serialize credits/debits.
4. Retain workshop existing wallet lock.
5. Audit every other balance-changing RPC/trigger for equivalent serialization and ensure no unguarded write path.
6. Audit permissions on trigger functions `give_ciclik_welcome_bonus` and `ciclik_initialize_new_user`. Trigger functions cannot be invoked as ordinary RPCs; avoid disabling active triggers. Revoke unnecessary direct EXECUTE only after verifying dependencies.
7. Check Supabase Auth leaked-password protection in dashboard; do not change auth configuration without validation.

## Pre-deployment checks
- Use a separate Supabase staging project with anonymized/seeded accounts; never clone real customer credentials.
- Two simultaneous clothing redemptions with only enough balance for one: exactly one succeeds.
- Simultaneous transfer + clothing redemption: exactly one succeeds.
- Simultaneous workshop charge + transfer: exactly one succeeds.
- Duplicate request IDs are idempotent for transfer/workshop.
- Insufficient balance rejects without creating operation rows.
- Admin/operator role checks still reject regular users.
- New-user welcome bonus issued once; registration and login work.
- Existing balances and transaction histories unchanged.
- Verify no unauthorized direct writes to transactions/balances.

## Release gate
Do not apply SQL to production or merge until staging tests and a backup/rollback plan have been verified and owner has approved.
