-- CÍCLIC · correcciones candidatas · 2026-11-11
-- NO ejecutar en producción sin validar el funcionamiento en staging.
-- No modifica filas ni saldos. Reduce privilegios de escritura y de ejecución.
BEGIN;

-- Los usuarios leen sus datos mediante las políticas RLS existentes.
-- Las escrituras de negocio deben pasar por RPCs autorizadas.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE
ON TABLE public.ciclik_users, public.ciclik_wallets,
         public.ciclik_transactions, public.ciclik_transfers
FROM PUBLIC, anon, authenticated;

-- Vista de saldos: debe ser de solo lectura para clientes.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE
ON TABLE public.ciclik_balances
FROM PUBLIC, anon, authenticated;

-- La bonificación de bienvenida se ejecuta como trigger, no como API pública.
-- Revisar el vínculo del trigger antes de desplegar.
REVOKE EXECUTE ON FUNCTION public.give_ciclik_welcome_bonus()
FROM PUBLIC, anon, authenticated;

-- Evitar búsquedas de objetos a través de schemas controlables.
ALTER FUNCTION public.set_member_profiles_updated_at()
SET search_path TO pg_catalog, public;

COMMIT;

-- Comprobaciones de SOLO LECTURA tras aplicar en staging:
-- 1) Ningún usuario anon/authenticated debe escribir en las tablas sensibles:
SELECT n.nspname, c.relname,
       has_table_privilege('anon', c.oid, 'INSERT') AS anon_insert,
       has_table_privilege('authenticated', c.oid, 'INSERT') AS authenticated_insert,
       has_table_privilege('anon', c.oid, 'UPDATE') AS anon_update,
       has_table_privilege('authenticated', c.oid, 'UPDATE') AS authenticated_update
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname IN
 ('ciclik_users','ciclik_wallets','ciclik_transactions','ciclik_transfers','ciclik_balances');

-- 2) Verificar el trigger y los permisos de la bonificación:
SELECT tgname, pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t WHERE t.tgfoid='public.give_ciclik_welcome_bonus()'::regprocedure
  AND NOT t.tgisinternal;

-- Pruebas de aplicación imprescindibles: registro + bonus único, inicio de
-- sesión, consultas propias, aportación/canje, traspaso válido, doble clic,
-- rechazo de transferencias sin saldo, acceso a operaciones de administrador.
-- Si alguna prueba falla, NO desplegar en producción.
