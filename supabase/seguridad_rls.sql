-- ════════════════════════════════════════════════════════════════════
-- HETNA Cotizador — Cierre de huecos de seguridad (RLS)          21 oct 2026
-- Correr en Supabase → SQL Editor del proyecto del Cotizador.
-- Todo va dentro de una transacción: si algo falla, no se aplica NADA.
-- Se puede correr dos veces sin problema.
-- ════════════════════════════════════════════════════════════════════
begin;

-- Taller al que se asignan los datos viejos que no tenían taller
-- (las tablas de catálogos y etiquetas se crearon antes de que la app
-- fuera para varios talleres): el taller "master" (HETNA) o, si no
-- existe, el más antiguo.
create temp table _taller_hetna on commit drop as
  select id from negocios
  order by (plan = 'master') desc, created_at asc
  limit 1;

-- ────────────────────────────────────────────────────────────────────
-- 1) Tablas que no tenían RLS: ahora cada taller solo ve lo suyo
-- ────────────────────────────────────────────────────────────────────

-- 1a. Partidas de cotización → por la cotización
alter table cotizacion_items enable row level security;
drop policy if exists "negocio cotizacion_items" on cotizacion_items;
create policy "negocio cotizacion_items" on cotizacion_items for all to authenticated
  using (exists (select 1 from cotizaciones c
                 where c.id = cotizacion_items.cotizacion_id and c.negocio_id = negocio_del_usuario()))
  with check (exists (select 1 from cotizaciones c
                 where c.id = cotizacion_items.cotizacion_id and c.negocio_id = negocio_del_usuario()));

-- 1b. Avances de pedido → por el pedido
alter table pedido_avances enable row level security;
drop policy if exists "negocio pedido_avances" on pedido_avances;
create policy "negocio pedido_avances" on pedido_avances for all to authenticated
  using (exists (select 1 from pedidos p
                 where p.id = pedido_avances.pedido_id and p.negocio_id = negocio_del_usuario()))
  with check (exists (select 1 from pedidos p
                 where p.id = pedido_avances.pedido_id and p.negocio_id = negocio_del_usuario()));

-- 1c. Facturas → por el pedido o por el cliente
alter table facturas enable row level security;
drop policy if exists "negocio facturas" on facturas;
create policy "negocio facturas" on facturas for all to authenticated
  using (exists (select 1 from pedidos p where p.id = facturas.pedido_id and p.negocio_id = negocio_del_usuario())
      or exists (select 1 from clientes cl where cl.id = facturas.cliente_id and cl.negocio_id = negocio_del_usuario()))
  with check (exists (select 1 from pedidos p where p.id = facturas.pedido_id and p.negocio_id = negocio_del_usuario())
      or exists (select 1 from clientes cl where cl.id = facturas.cliente_id and cl.negocio_id = negocio_del_usuario()));

-- 1d. Cola de mensajes de WhatsApp → por el cliente
alter table cola_mensajes_wa enable row level security;
drop policy if exists "negocio cola_mensajes_wa" on cola_mensajes_wa;
create policy "negocio cola_mensajes_wa" on cola_mensajes_wa for all to authenticated
  using (exists (select 1 from clientes cl where cl.id = cola_mensajes_wa.cliente_id and cl.negocio_id = negocio_del_usuario()))
  with check (exists (select 1 from clientes cl where cl.id = cola_mensajes_wa.cliente_id and cl.negocio_id = negocio_del_usuario()));

-- 1e. Etiquetas puestas a clientes → por el cliente
alter table cliente_etiquetas enable row level security;
drop policy if exists "negocio cliente_etiquetas" on cliente_etiquetas;
create policy "negocio cliente_etiquetas" on cliente_etiquetas for all to authenticated
  using (exists (select 1 from clientes cl where cl.id = cliente_etiquetas.cliente_id and cl.negocio_id = negocio_del_usuario()))
  with check (exists (select 1 from clientes cl where cl.id = cliente_etiquetas.cliente_id and cl.negocio_id = negocio_del_usuario()));

-- 1f. Tablas sin columna de taller: se agrega negocio_id, se llena y se
--     pone el mismo trigger que ya usan las demás tablas (set_negocio_id).
do $$
declare t text;
begin
  foreach t in array array['etiquetas_cliente', 'pdfs_catalogo', 'catalogos_personalizados'] loop
    execute format('alter table %I add column if not exists negocio_id uuid references negocios(id)', t);
    execute format('drop trigger if exists tr_set_negocio_%s on %I', t, t);
    execute format('create trigger tr_set_negocio_%s before insert on %I for each row execute function set_negocio_id()', t, t);
  end loop;
end $$;

-- Etiquetas: si ya se usaron con un cliente, toman el taller de ese cliente
update etiquetas_cliente e set negocio_id = sub.negocio_id
from (select distinct on (ce.etiqueta_id) ce.etiqueta_id, cl.negocio_id
      from cliente_etiquetas ce join clientes cl on cl.id = ce.cliente_id
      where cl.negocio_id is not null) sub
where e.id = sub.etiqueta_id and e.negocio_id is null;

-- Catálogos personalizados: toman el taller de sus productos
update catalogos_personalizados cp set negocio_id = (
  select p.negocio_id from productos p where p.id = any (cp.producto_ids) and p.negocio_id is not null limit 1)
where cp.negocio_id is null;

-- Lo que quede sin taller es de antes de la versión multi-taller → HETNA
update etiquetas_cliente        set negocio_id = (select id from _taller_hetna) where negocio_id is null;
update pdfs_catalogo            set negocio_id = (select id from _taller_hetna) where negocio_id is null;
update catalogos_personalizados set negocio_id = (select id from _taller_hetna) where negocio_id is null;

do $$
declare t text;
begin
  foreach t in array array['etiquetas_cliente', 'pdfs_catalogo', 'catalogos_personalizados'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists "negocio %s" on %I', t, t);
    execute format('create policy "negocio %s" on %I for all to authenticated
                      using (negocio_id = negocio_del_usuario())
                      with check (negocio_id = negocio_del_usuario())', t, t);
  end loop;
end $$;

-- ────────────────────────────────────────────────────────────────────
-- 2) negocios: nadie se cambia el plan desde la app
--    Los miembros ven su taller; solo el administrador edita los datos
--    del taller, y NUNCA plan, trial_hasta, activo ni slug (eso solo lo
--    cambia HETNA desde aquí o el webhook de pagos con la llave de servicio).
-- ────────────────────────────────────────────────────────────────────
drop policy if exists "usuarios ven su negocio" on negocios;
drop policy if exists "miembros ven su negocio" on negocios;
drop policy if exists "admin edita su negocio" on negocios;
create policy "miembros ven su negocio" on negocios for select to authenticated
  using (id = negocio_del_usuario());
create policy "admin edita su negocio" on negocios for update to authenticated
  using (es_admin_del_negocio(id)) with check (es_admin_del_negocio(id));

create or replace function proteger_plan_negocio() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- auth.role() es 'authenticated' o 'anon' cuando viene de la app;
  -- es null desde el SQL Editor y 'service_role' desde el servidor.
  if coalesce(auth.role(), '') in ('authenticated', 'anon') and (
       new.plan        is distinct from old.plan
    or new.trial_hasta is distinct from old.trial_hasta
    or new.activo      is distinct from old.activo
    or new.slug        is distinct from old.slug) then
    raise exception 'El plan del taller solo se cambia al pagar la suscripción';
  end if;
  return new;
end $$;
drop trigger if exists tr_proteger_plan on negocios;
create trigger tr_proteger_plan before update on negocios
  for each row execute function proteger_plan_negocio();

-- ────────────────────────────────────────────────────────────────────
-- 3) usuarios_negocio: nadie se mete a un taller ajeno ni se sube el rol
--    Altas solo por el administrador del taller o por las funciones de
--    registro e invitación (registrar_taller, canjear_invitacion), que
--    no pasan por estas reglas.
-- ────────────────────────────────────────────────────────────────────
drop policy if exists "admin ve usuarios de su negocio" on usuarios_negocio;
drop policy if exists "admin_update_usuario_negocio" on usuarios_negocio;
drop policy if exists "select_mismo_negocio" on usuarios_negocio;
drop policy if exists "self_insert_usuario_negocio" on usuarios_negocio;
drop policy if exists "ver equipo" on usuarios_negocio;
drop policy if exists "admin agrega usuarios" on usuarios_negocio;
drop policy if exists "editar usuario" on usuarios_negocio;
drop policy if exists "admin borra usuarios" on usuarios_negocio;

create policy "ver equipo" on usuarios_negocio for select to authenticated
  using (user_id = auth.uid() or negocio_id = negocio_del_usuario());
create policy "admin agrega usuarios" on usuarios_negocio for insert to authenticated
  with check (es_admin_del_negocio(negocio_id));
-- Cada quien puede actualizar su propia fila (la app guarda ahí el token
-- de notificaciones); el trigger de abajo impide que cambie rol, taller o estado.
create policy "editar usuario" on usuarios_negocio for update to authenticated
  using (user_id = auth.uid() or es_admin_del_negocio(negocio_id))
  with check (user_id = auth.uid() or es_admin_del_negocio(negocio_id));
create policy "admin borra usuarios" on usuarios_negocio for delete to authenticated
  using (es_admin_del_negocio(negocio_id));

create or replace function proteger_rol_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(auth.role(), '') in ('authenticated', 'anon')
     and not es_admin_del_negocio(old.negocio_id) and (
       new.rol        is distinct from old.rol
    or new.negocio_id is distinct from old.negocio_id
    or new.activo     is distinct from old.activo
    or new.user_id    is distinct from old.user_id) then
    raise exception 'Solo el administrador del taller puede cambiar roles o usuarios';
  end if;
  return new;
end $$;
drop trigger if exists tr_proteger_rol on usuarios_negocio;
create trigger tr_proteger_rol before update on usuarios_negocio
  for each row execute function proteger_rol_usuario();

-- ────────────────────────────────────────────────────────────────────
-- 4) Vistas: que respeten las reglas de quien consulta
--    (antes corrían con permisos de dueño y juntaban a todos los talleres)
-- ────────────────────────────────────────────────────────────────────
alter view v_estadisticas_mes         set (security_invoker = true);
alter view v_alertas_pendientes       set (security_invoker = true);
alter view empresa_costos_calculados  set (security_invoker = true);
alter view mano_obra_costo_hora       set (security_invoker = true);
alter view maquinaria_costo_hora      set (security_invoker = true);

-- ────────────────────────────────────────────────────────────────────
-- 5) Planes nuevos (taller / pro / industrial / prueba) cuentan como
--    plan activo para el simulador, cupones, plantillas y marketing
-- ────────────────────────────────────────────────────────────────────
create or replace function negocio_plan_activo(p_negocio_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select plan in ('master', 'premium', 'taller', 'pro', 'industrial')
         or (plan in ('trial', 'prueba') and trial_hasta > now())
     from negocios where id = p_negocio_id),
    false);
$$;

-- ────────────────────────────────────────────────────────────────────
-- 6) registrar_taller: solo para la cuenta que se acaba de crear
--    Antes cualquiera podía crear un taller a nombre de cualquier usuario.
--    Ahora el usuario tiene que existir, tener ese mismo correo, haberse
--    creado hace menos de 1 hora y no tener ya un taller. Funciona igual
--    con o sin confirmación de correo activada.
-- ────────────────────────────────────────────────────────────────────
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

  -- Taller nuevo: plan "trial" con 1 mes completo desde hoy
  insert into negocios (nombre, slug, telefono, correo, plan, trial_hasta, activo)
  values (p_nombre_taller, v_slug, p_telefono, p_correo, 'trial', now() + interval '1 month', true)
  returning id into v_negocio_id;

  insert into usuarios_negocio (user_id, negocio_id, rol, nombre, correo, activo)
  values (p_user_id, v_negocio_id, 'administrador', p_nombre_admin, p_correo, true);

  return json_build_object('negocio_id', v_negocio_id);
exception when others then
  return json_build_object('error', sqlerrm);
end $$;

commit;

-- ────────────────────────────────────────────────────────────────────
-- Resumen: debe salir "RLS si" en las 8 tablas
-- ────────────────────────────────────────────────────────────────────
select c.relname as tabla, case when c.relrowsecurity then 'RLS si' else 'RLS NO' end as estado,
       (select count(*) from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname) as politicas
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname in ('cotizacion_items', 'pedido_avances', 'facturas',
  'cola_mensajes_wa', 'cliente_etiquetas', 'etiquetas_cliente', 'pdfs_catalogo',
  'catalogos_personalizados', 'negocios', 'usuarios_negocio')
order by 1;

