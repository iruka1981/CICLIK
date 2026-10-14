-- ENDURECIMIENTO idempotente: nadie con rol anon/authenticated puede escribir directamente
-- en saldos, movimientos ni transferencias. Solo las funciones security definer (RPC) escriben.
-- No modifica datos. Ejecutar DESPUES de revisar supabase-ciclik-audit.sql.
-- La web actual no hace INSERT/UPDATE/DELETE directos sobre estas tablas (solo SELECT y RPC).

do $$
declare
  r record;
begin
  for r in
    select c.relname, c.relkind
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in ('ciclik_transactions', 'ciclik_balances', 'ciclik_transfers')
      and c.relkind in ('r', 'v', 'm', 'p')
  loop
    execute format('revoke insert, update, delete, truncate, references, trigger from anon, authenticated, public on public.%I', r.relname);
    execute format('revoke all on public.%I from anon', r.relname);
    if r.relkind in ('r', 'p') then
      execute format('alter table public.%I enable row level security', r.relname);
    end if;
  end loop;
end $$;

-- ciclik_transfers: sin acceso directo (solo via RPC)
do $$
begin
  if to_regclass('public.ciclik_transfers') is not null then
    revoke all on public.ciclik_transfers from anon, authenticated, public;
  end if;
end $$;

-- Los usuarios autenticados solo leen (las politicas SELECT existentes limitan a sus filas)
do $$
begin
  if to_regclass('public.ciclik_transactions') is not null then
    grant select on public.ciclik_transactions to authenticated;
  end if;
  if to_regclass('public.ciclik_balances') is not null then
    grant select on public.ciclik_balances to authenticated;
  end if;
end $$;

-- Las funciones ciclik_* se endurecen en supabase-ciclik-function-hardening.sql

notify pgrst, 'reload schema';
