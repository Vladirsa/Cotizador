-- Prueba gratis de 14 días (antes 1 mes), igual que lo que promete
-- hetnacnc.com/servicios/cotizador-cnc. Sólo cambia a los talleres NUEVOS:
-- los que ya están en prueba conservan su fecha.
-- Correr en Supabase > SQL Editor.

create or replace function registrar_taller(
  p_user_id uuid, p_nombre_taller text, p_giro text, p_correo text,
  p_nombre_admin text, p_telefono text default null)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_negocio_id uuid;
  v_slug text;
begin
  if auth.uid() is not null and auth.uid() <> p_user_id then
    return json_build_object('error', 'No puedes registrar un taller para otra cuenta');
  end if;
  if not exists (select 1 from auth.users u
                 where u.id = p_user_id
                   and lower(u.email) = lower(trim(p_correo))
                   and u.created_at > now() - interval '1 hour') then
    return json_build_object('error', 'No pudimos verificar la cuenta. Intenta registrarte de nuevo.');
  end if;
  if exists (select 1 from usuarios_negocio where user_id = p_user_id) then
    return json_build_object('error', 'Esta cuenta ya tiene un taller registrado');
  end if;

  v_slug := lower(regexp_replace(p_nombre_taller, '[^a-zA-Z0-9]+', '-', 'g'))
            || '-' || substr(md5(random()::text), 1, 6);

  -- Taller nuevo: plan "trial" con 14 días con todo abierto (igual que hetnacnc.com)
  insert into negocios (nombre, slug, telefono, correo, plan, trial_hasta, activo)
  values (p_nombre_taller, v_slug, p_telefono, p_correo, 'trial', now() + interval '14 days', true)
  returning id into v_negocio_id;

  insert into usuarios_negocio (user_id, negocio_id, rol, nombre, correo, activo)
  values (p_user_id, v_negocio_id, 'administrador', p_nombre_admin, p_correo, true);

  return json_build_object('negocio_id', v_negocio_id);
exception when others then
  return json_build_object('error', sqlerrm);
end $$;
