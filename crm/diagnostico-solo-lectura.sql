-- CICLIK CRM · Diagnóstico de solo lectura (NO cambia datos).
-- Ejecutar en Supabase SQL Editor para verificar la instalación y el rol.
-- IMPORTANTE: auth.uid() suele ser NULL en SQL Editor; no usar
-- SELECT ciclik_is_admin() aquí para comprobar el rol del usuario web.

-- 1. Funciones instaladas, firma y permisos de ejecución
select p.proname as funcion,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       p.prosecdef as security_definer,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_puede_ejecutar
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in ('ciclik_is_admin','ciclik_admin_dashboard',
                    'ciclik_admin_list_users','ciclik_admin_user_movements')
order by p.proname;

-- 2. Número de cuentas con rol admin (sin exponer nombres ni correos)
select count(*) as cuentas_administradoras
from public.ciclik_users where role='admin';

-- 3. Comprobar que el esquema de usuarios conserva sus campos
select column_name, data_type
from information_schema.columns
where table_schema='public' and table_name='ciclik_users'
order by ordinal_position;

-- 4. Comprobar que existen las tablas de soporte
select to_regclass('public.ciclik_events') as eventos,
       to_regclass('public.ciclik_requests') as solicitudes,
       to_regclass('public.ciclik_transactions') as movimientos,
       to_regclass('public.ciclik_balances') as saldos;
