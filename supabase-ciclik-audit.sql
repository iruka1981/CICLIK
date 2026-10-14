-- AUDITORIA DE SOLO LECTURA (no modifica nada). Ejecutar en Supabase > SQL Editor.
-- Resultado esperado: 0 filas en las consultas 1, 3 y 4; en la 2, solo SELECT.

-- 1. Privilegios de escritura de anon/authenticated sobre las tablas sensibles (esperado: 0 filas)
select grantee, table_name, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in ('ciclik_transactions', 'ciclik_balances', 'ciclik_transfers')
  and grantee in ('anon', 'authenticated', 'PUBLIC')
  and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
order by table_name, grantee, privilege_type;

-- 2. Todos los privilegios restantes (esperado: authenticated SELECT en transactions/balances; nada en transfers)
select grantee, table_name, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in ('ciclik_transactions', 'ciclik_balances', 'ciclik_transfers')
  and grantee in ('anon', 'authenticated', 'PUBLIC')
order by table_name, grantee, privilege_type;

-- 3. Politicas RLS de escritura (esperado: 0 filas) y tipo/RLS de cada relacion
select schemaname, tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('ciclik_transactions', 'ciclik_balances', 'ciclik_transfers')
  and cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL');

select c.relname, c.relkind, c.relrowsecurity as rls_activa,
       c.reloptions as opciones_vista  -- en una vista, debe incluir security_invoker=true
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('ciclik_transactions', 'ciclik_balances', 'ciclik_transfers');

-- 4. Triggers sobre ciclik_transactions (revisar que no haya nada inesperado)
select tgname, pg_get_triggerdef(oid) as definicion
from pg_trigger
where tgrelid = 'public.ciclik_transactions'::regclass and not tgisinternal;

-- 5. Politicas SELECT (cada usuario solo debe ver lo suyo, p. ej. user_id = auth.uid())
select tablename, policyname, roles, qual
from pg_policies
where schemaname = 'public'
  and tablename in ('ciclik_transactions', 'ciclik_balances', 'ciclik_transfers')
  and cmd = 'SELECT';

-- 6. Funciones ciclik_* ejecutables por anon/PUBLIC (esperado: ninguna)
select p.proname, pg_get_function_identity_arguments(p.oid) as args, p.prosecdef as security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname like 'ciclik\_%'
  and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('public', p.oid, 'execute'))
order by p.proname;
