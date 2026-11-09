-- CICLIK: workshop charges and instructor credits.
-- Run the complete file as one transaction after reviewing the target project.
begin;
set local lock_timeout = '5s';

create schema if not exists ciclik_private;
revoke all on schema ciclik_private from public, anon;
grant usage on schema ciclik_private to authenticated;

create table if not exists ciclik_private.workshop_receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  operator_id uuid not null references auth.users(id),
  activity text not null check (length(activity) between 1 and 160),
  activity_key text not null,
  session_date date not null,
  amount integer not null check (amount > 0),
  operation text not null default 'charge' check (operation in ('charge','credit')),
  request_id uuid not null,
  transaction_id bigint not null unique references public.ciclik_transactions(id),
  created_at timestamptz not null default now(),
  constraint workshop_receipt_activity_key check (activity_key = lower(regexp_replace(btrim(activity), '\s+', ' ', 'g'))),
  constraint workshop_receipt_request unique (operator_id, request_id),
  constraint workshop_receipt_attendance unique (user_id, activity_key, session_date, operation)
);
alter table ciclik_private.workshop_receipts
  add column if not exists operation text not null default 'charge' check (operation in ('charge','credit'));
alter table ciclik_private.workshop_receipts
  drop constraint if exists workshop_receipt_attendance;
alter table ciclik_private.workshop_receipts
  add constraint workshop_receipt_attendance unique (user_id, activity_key, session_date, operation);
alter table ciclik_private.workshop_receipts enable row level security;
revoke all on ciclik_private.workshop_receipts from public, anon, authenticated;

-- Every debit uses one wallet lock, including clothing and transfers. Otherwise
-- a simultaneous clothing purchase could spend the same balance as a workshop.
create or replace function ciclik_private.guard_wallet_debit()
returns trigger language plpgsql volatile security definer set search_path = '' as $$
declare v_balance bigint;
begin
  if new.amount < 0 then
    perform pg_advisory_xact_lock(hashtextextended('ciclik_wallet:' || new.user_id::text, 0));
    select coalesce(sum(t.amount),0) into v_balance
      from public.ciclik_transactions t where t.user_id = new.user_id;
    if v_balance + new.amount < 0 then raise exception 'ciclik_insufficient_balance'; end if;
  end if;
  return new;
end;
$$;
revoke all on function ciclik_private.guard_wallet_debit() from public, anon, authenticated;
create or replace trigger ciclik_guard_wallet_debit
before insert on public.ciclik_transactions
for each row execute function ciclik_private.guard_wallet_debit();

create or replace function ciclik_private.workshop_member(p_user_id uuid)
returns table(display_name text, balance bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.ciclik_users s where s.user_id = auth.uid() and s.role in ('admin','operator')
  ) then raise exception 'ciclik_staff_required'; end if;
  if not exists (select 1 from public.ciclik_users u where u.user_id=p_user_id)
     or not exists (select 1 from public.ciclik_wallets w where w.user_id=p_user_id)
    then raise exception 'ciclik_member_not_found'; end if;
  return query select
    coalesce(nullif(btrim(u.raw_user_meta_data->>'nombre'),''),nullif(btrim(u.raw_user_meta_data->>'full_name'),''),nullif(btrim(u.raw_user_meta_data->>'name'),''),'Membre de Ciclik'),
    (select coalesce(sum(t.amount),0) from public.ciclik_transactions t where t.user_id=p_user_id)
    from auth.users u where u.id=p_user_id;
end;
$$;
revoke all on function ciclik_private.workshop_member(uuid) from public, anon;
grant execute on function ciclik_private.workshop_member(uuid) to authenticated;
create or replace function public.ciclik_workshop_member(p_user_id uuid)
returns table(display_name text, balance bigint)
language sql stable security invoker set search_path = '' as $$
  select * from ciclik_private.workshop_member(p_user_id);
$$;
revoke all on function public.ciclik_workshop_member(uuid) from public, anon;
grant execute on function public.ciclik_workshop_member(uuid) to authenticated;

create or replace function ciclik_private.record_workshop(
  p_user_id uuid, p_activity text, p_session_date date, p_amount integer, p_request_id uuid, p_operation text
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_operator uuid := auth.uid();
  v_activity text := regexp_replace(btrim(p_activity), '\s+', ' ', 'g');
  v_key text := lower(v_activity);
  v_balance bigint;
  v_transaction bigint;
  v_receipt uuid;
  v_existing ciclik_private.workshop_receipts%rowtype;
begin
  if v_operator is null or not exists (
    select 1 from public.ciclik_users s where s.user_id=v_operator and s.role in ('admin','operator')
  ) then raise exception 'ciclik_staff_required'; end if;
  if p_operation is null or p_operation not in ('charge','credit') then raise exception 'ciclik_invalid_operation'; end if;
  if p_operation='credit' and not exists (select 1 from public.ciclik_users where user_id=v_operator and role='admin') then raise exception 'ciclik_admin_required'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'ciclik_invalid_amount'; end if;
  if v_activity is null or length(v_activity) not between 1 and 160
    or p_session_date is null or p_request_id is null then raise exception 'ciclik_invalid_workshop'; end if;
  if not exists (select 1 from public.ciclik_users u where u.user_id=p_user_id)
    or not exists (select 1 from public.ciclik_wallets w where w.user_id=p_user_id)
    then raise exception 'ciclik_member_not_found'; end if;

  -- Serialize retries of this request even if a buggy client changes the member.
  perform pg_advisory_xact_lock(hashtextextended('ciclik_workshop_request:' || v_operator::text || ':' || p_request_id::text,0));
  perform pg_advisory_xact_lock(hashtextextended('ciclik_wallet:' || p_user_id::text,0));
  select coalesce(sum(t.amount),0) into v_balance
    from public.ciclik_transactions t where t.user_id=p_user_id;
  select * into v_existing from ciclik_private.workshop_receipts r
    where r.operator_id=v_operator and r.request_id=p_request_id;
  if found then
    if v_existing.operation is distinct from p_operation or v_existing.user_id is distinct from p_user_id or v_existing.amount is distinct from p_amount
      or v_existing.activity_key is distinct from v_key or v_existing.session_date is distinct from p_session_date
      then raise exception 'ciclik_request_mismatch'; end if;
    return jsonb_build_object('receipt_id',v_existing.id,'new_balance',v_balance,'already_processed',true);
  end if;
  if exists (select 1 from ciclik_private.workshop_receipts r
    where r.user_id=p_user_id and r.activity_key=v_key and r.session_date=p_session_date and r.operation=p_operation)
    then raise exception 'ciclik_workshop_already_paid'; end if;
  if p_operation='charge' and v_balance < p_amount then raise exception 'ciclik_insufficient_balance'; end if;

  insert into public.ciclik_transactions(user_id,amount,transaction_type,description,created_by)
    values(p_user_id,case p_operation when 'credit' then p_amount else -p_amount end,case p_operation when 'credit' then 'adjustment' else 'activity' end,case p_operation when 'credit' then 'Abonament taller · ' else 'Cobrament taller · ' end || v_activity || ' · ' || p_session_date::text,v_operator)
    returning id into v_transaction;
  insert into ciclik_private.workshop_receipts(user_id,operator_id,activity,activity_key,session_date,amount,operation,request_id,transaction_id)
    values(p_user_id,v_operator,v_activity,v_key,p_session_date,p_amount,p_operation,p_request_id,v_transaction)
    returning id into v_receipt;
  return jsonb_build_object('receipt_id',v_receipt,'new_balance',v_balance + case p_operation when 'credit' then p_amount else -p_amount end,'already_processed',false);
end;
$$;
revoke all on function ciclik_private.record_workshop(uuid,text,date,integer,uuid,text) from public, anon;
grant execute on function ciclik_private.record_workshop(uuid,text,date,integer,uuid,text) to authenticated;
create or replace function public.ciclik_record_workshop(
  p_user_id uuid, p_activity text, p_session_date date, p_amount integer, p_request_id uuid, p_operation text
) returns jsonb language sql volatile security invoker set search_path = '' as $$
  select ciclik_private.record_workshop(p_user_id,p_activity,p_session_date,p_amount,p_request_id,p_operation);
$$;
revoke all on function public.ciclik_record_workshop(uuid,text,date,integer,uuid,text) from public, anon;
grant execute on function public.ciclik_record_workshop(uuid,text,date,integer,uuid,text) to authenticated;
notify pgrst, 'reload schema';
commit;
