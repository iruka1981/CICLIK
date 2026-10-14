-- Retira EXECUTE a anon y PUBLIC en 4 funciones ciclik_*. No cambia su codigo ni sus datos.
-- Idempotente. Conserva el acceso que ya tengan authenticated y service_role
-- (si lo recibian solo via PUBLIC, se les concede de forma explicita antes de revocar PUBLIC).

do $$
declare
  f record;
  v_auth boolean;
  v_service boolean;
begin
  for f in
    select p.oid, p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'ciclik_find_member_by_qr',
        'ciclik_initialize_new_user',
        'ciclik_process_clothes',
        'ciclik_redeem_physical'
      )
  loop
    v_auth := has_function_privilege('authenticated', f.oid, 'execute');
    v_service := has_function_privilege('service_role', f.oid, 'execute');

    execute format('revoke execute on function %s from public', f.sig);
    execute format('revoke execute on function %s from anon', f.sig);

    if v_auth then
      execute format('grant execute on function %s to authenticated', f.sig);
    end if;
    if v_service then
      execute format('grant execute on function %s to service_role', f.sig);
    end if;
  end loop;
end $$;

notify pgrst, 'reload schema';

-- Verificacion (esperado: 0 filas en la primera; authenticated = true donde corresponda en la segunda)
select p.proname, pg_get_function_identity_arguments(p.oid) as args
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname like 'ciclik\_%'
  and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('public', p.oid, 'execute'));
