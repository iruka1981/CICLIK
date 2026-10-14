-- Transferencias de Cicliks entre usuarios (QR / codi personal).
-- Idempotente: se puede ejecutar varias veces. No modifica saldos ni movimientos existentes.
-- Ejecutar completo en Supabase > SQL Editor.
--
-- Supuestos (los que ya usa la web): public.ciclik_users(user_id, role, qr_code),
-- public.ciclik_transactions(id, user_id, amount, transaction_type, description, created_by, created_at)
-- y public.ciclik_balances(user_id, balance). Si algo no coincide, el bloque de
-- comprobacion inicial aborta con un mensaje claro SIN haber cambiado nada.

-- 0. Comprobacion previa -----------------------------------------------------
do $$
declare
  v_missing text;
begin
  if to_regclass('public.ciclik_users') is null
     or to_regclass('public.ciclik_transactions') is null
     or to_regclass('public.ciclik_balances') is null then
    raise exception 'Faltan tablas/vistas: ciclik_users, ciclik_transactions o ciclik_balances';
  end if;

  select string_agg(c, ', ') into v_missing
  from unnest(array['user_id','amount','transaction_type','description','created_by']) c
  where not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'ciclik_transactions' and column_name = c
  );
  if v_missing is not null then
    raise exception 'ciclik_transactions no tiene las columnas: %', v_missing;
  end if;

  -- Columnas obligatorias sin valor por defecto que esta migracion no rellena.
  select string_agg(column_name, ', ') into v_missing
  from information_schema.columns
  where table_schema = 'public' and table_name = 'ciclik_transactions'
    and is_nullable = 'NO' and column_default is null
    and coalesce(is_generated, 'NEVER') = 'NEVER' and coalesce(is_identity, 'NO') = 'NO'
    and column_name not in ('user_id','amount','transaction_type','description','created_by');
  if v_missing is not null then
    raise exception 'ciclik_transactions tiene columnas obligatorias sin default que la transferencia no rellena: %', v_missing;
  end if;
end $$;

-- 1. Codigo QR unico por usuario (no es el user_id: no expone datos internos) ----
alter table public.ciclik_users add column if not exists qr_code uuid;
update public.ciclik_users set qr_code = gen_random_uuid() where qr_code is null;
alter table public.ciclik_users alter column qr_code set default gen_random_uuid();
alter table public.ciclik_users alter column qr_code set not null;
create unique index if not exists ciclik_users_qr_code_key on public.ciclik_users (qr_code);

-- 2. Registro de transferencias (idempotencia por request_id) ---------------------
create table if not exists public.ciclik_transfers (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id),
  recipient_id uuid not null references auth.users(id),
  amount integer not null check (amount > 0),
  request_id uuid not null,
  created_at timestamptz not null default now(),
  constraint ciclik_transfers_not_self check (sender_id <> recipient_id),
  constraint ciclik_transfers_request_unique unique (sender_id, request_id)
);
create index if not exists ciclik_transfers_recipient_idx on public.ciclik_transfers (recipient_id);

-- Solo accesible mediante las funciones RPC (security definer).
alter table public.ciclik_transfers enable row level security;
revoke all on public.ciclik_transfers from anon, authenticated;

alter table public.ciclik_transactions add column if not exists transfer_id uuid references public.ciclik_transfers(id);
create index if not exists ciclik_transactions_transfer_idx on public.ciclik_transactions (transfer_id);

-- 3. Permitir los tipos transfer_out / transfer_in si hay un CHECK sobre transaction_type
do $$
declare
  v_con record;
  v_types text[];
begin
  for v_con in
    select c.conname, pg_get_constraintdef(c.oid) as def
    from pg_constraint c
    where c.conrelid = 'public.ciclik_transactions'::regclass
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%transaction_type%'
      and pg_get_constraintdef(c.oid) not ilike '%transfer_out%'
  loop
    select array_agg(distinct t) into v_types
    from (
      select transaction_type as t from public.ciclik_transactions where transaction_type is not null
      union select 'transfer_out' union select 'transfer_in'
      union select 'clothing_contribution' union select 'market_purchase'
    ) s;
    execute format('alter table public.ciclik_transactions drop constraint %I', v_con.conname);
    execute format(
      'alter table public.ciclik_transactions add constraint %I check (transaction_type = any (%L::text[]))',
      v_con.conname, v_types
    );
  end loop;
end $$;

-- 4. Nombre visible (nunca email ni user_id) ------------------------------------
create or replace function public.ciclik_display_name(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select coalesce(
    nullif(btrim(u.raw_user_meta_data ->> 'nombre'), ''),
    nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(u.raw_user_meta_data ->> 'name'), ''),
    'Membre de Ciclik'
  )
  from auth.users u
  where u.id = p_user_id;
$$;
revoke all on function public.ciclik_display_name(uuid) from public, anon, authenticated;

-- 5. Resolver destinatario a partir de su codigo personal -----------------------
drop function if exists public.ciclik_resolve_transfer_recipient(text);
drop function if exists public.ciclik_resolve_transfer_recipient(uuid);
create function public.ciclik_resolve_transfer_recipient(p_qr_code uuid)
returns table (display_name text, is_self boolean)
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_caller uuid := auth.uid();
  v_recipient uuid;
begin
  if v_caller is null then
    raise exception 'ciclik_not_authenticated';
  end if;
  if p_qr_code is null then
    raise exception 'ciclik_invalid_recipient';
  end if;

  select u.user_id into v_recipient from public.ciclik_users u where u.qr_code = p_qr_code;
  if v_recipient is null then
    raise exception 'ciclik_invalid_recipient';
  end if;

  return query select public.ciclik_display_name(v_recipient), (v_recipient = v_caller);
end;
$$;

-- 6. Transferencia atomica -------------------------------------------------------
drop function if exists public.ciclik_transfer(uuid, integer);
drop function if exists public.ciclik_transfer(uuid, bigint);
drop function if exists public.ciclik_transfer(uuid, integer, uuid);
create function public.ciclik_transfer(p_qr_code uuid, p_amount integer, p_request_id uuid)
returns table (transfer_id uuid, already_processed boolean)
language plpgsql
volatile
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_sender uuid := auth.uid();
  v_recipient uuid;
  v_balance bigint;
  v_transfer uuid;
begin
  if v_sender is null then
    raise exception 'ciclik_not_authenticated';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'ciclik_invalid_amount';
  end if;
  if p_qr_code is null or p_request_id is null then
    raise exception 'ciclik_invalid_recipient';
  end if;

  -- Serializa las operaciones del mismo emisor: evita doble gasto y dobles clics concurrentes.
  perform pg_advisory_xact_lock(hashtextextended('ciclik_transfer:' || v_sender::text, 0));

  select t.id into v_transfer
  from public.ciclik_transfers t
  where t.sender_id = v_sender and t.request_id = p_request_id;
  if found then
    return query select v_transfer, true;
    return;
  end if;

  select u.user_id into v_recipient from public.ciclik_users u where u.qr_code = p_qr_code;
  if v_recipient is null then
    raise exception 'ciclik_invalid_recipient';
  end if;
  if v_recipient = v_sender then
    raise exception 'ciclik_transfer_self';
  end if;

  select coalesce(b.balance, 0) into v_balance from public.ciclik_balances b where b.user_id = v_sender;
  if coalesce(v_balance, 0) < p_amount then
    raise exception 'ciclik_insufficient_balance';
  end if;

  insert into public.ciclik_transfers (sender_id, recipient_id, amount, request_id)
  values (v_sender, v_recipient, p_amount, p_request_id)
  returning id into v_transfer;

  insert into public.ciclik_transactions (user_id, amount, transaction_type, description, created_by, transfer_id)
  values
    (v_sender,    -p_amount, 'transfer_out', 'Enviament de Cicliks', v_sender, v_transfer),
    (v_recipient,  p_amount, 'transfer_in',  'Cicliks rebuts',        v_sender, v_transfer);

  return query select v_transfer, false;
end;
$$;

-- 7. Contrapartida de cada movimiento propio (para "Enviats a..." / "Rebuts de...") ----
drop function if exists public.ciclik_my_transfer_counterparties();
create function public.ciclik_my_transfer_counterparties()
returns table (transaction_id text, display_name text, is_admin boolean)
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select
    x.id::text,
    public.ciclik_display_name(x.other_id),
    coalesce(cu.role in ('admin', 'operator'), false)
  from (
    select
      t.id,
      case
        when tr.id is not null and tr.sender_id = auth.uid() then tr.recipient_id
        when tr.id is not null then tr.sender_id
        when t.created_by is distinct from t.user_id then t.created_by
      end as other_id
    from public.ciclik_transactions t
    left join public.ciclik_transfers tr on tr.id = t.transfer_id
    where t.user_id = auth.uid()
      and t.transaction_type in ('transfer_out', 'transfer_in')
  ) x
  left join public.ciclik_users cu on cu.user_id = x.other_id
  where x.other_id is not null;
$$;

-- 8. Permisos: solo usuarios autenticados (cualquier rol, no solo admin) ------------
revoke all on function public.ciclik_resolve_transfer_recipient(uuid) from public, anon;
revoke all on function public.ciclik_transfer(uuid, integer, uuid) from public, anon;
revoke all on function public.ciclik_my_transfer_counterparties() from public, anon;
grant execute on function public.ciclik_resolve_transfer_recipient(uuid) to authenticated;
grant execute on function public.ciclik_transfer(uuid, integer, uuid) to authenticated;
grant execute on function public.ciclik_my_transfer_counterparties() to authenticated;

notify pgrst, 'reload schema';
