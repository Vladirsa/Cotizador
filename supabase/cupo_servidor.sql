-- ════════════════════════════════════════════════════════════════════
-- Cotizador 2.0 · Fase 1 — El límite del plan Gratis se decide en el servidor
--
-- Antes el límite (5 cotizaciones nuevas al mes) lo contaba la app:
--   · sacar el PDF o mandar por WhatsApp sin guardar no contaba,
--   · borrar cotizaciones liberaba cupo,
--   · si fallaba la consulta se contaba cero,
--   · un insert directo a la API se saltaba todo.
--
-- Ahora:
--   1. Cada cotización NUEVA pasa por un trigger que consume cupo del mes
--      en `cotizaciones_cupo` (un contador por taller y mes que NUNCA baja,
--      aunque se borren cotizaciones). Si el plan es Gratis (o la prueba
--      venció) y ya se usaron las 5, el insert se rechaza con el mensaje
--      'SIN_CUPO'. Da igual si viene de la app o de la API.
--   2. El folio también lo pone el trigger, por taller (antes la función
--      vieja tomaba el primer configuracion_empresa de toda la base y el
--      folio era único para todos los talleres: chocaban entre sí).
--   3. `cupo_cotizaciones()` le dice a la app cuántas le quedan, para
--      mostrarlo y avisar antes de que se acabe.
--
-- Pegar una sola vez en Supabase > SQL Editor del proyecto de la app.
-- Idempotente: se puede volver a correr.
-- ════════════════════════════════════════════════════════════════════

-- 1) Contador por taller y mes ─────────────────────────────────────
create table if not exists cotizaciones_cupo (
  negocio_id uuid not null references negocios(id) on delete cascade,
  mes text not null,                 -- 'YYYY-MM' en hora de México
  usadas integer not null default 0,
  actualizado timestamptz not null default now(),
  primary key (negocio_id, mes)
);
alter table cotizaciones_cupo enable row level security;
drop policy if exists "cupo: el taller lo lee" on cotizaciones_cupo;
create policy "cupo: el taller lo lee" on cotizaciones_cupo
  for select using (negocio_id = negocio_del_usuario());
-- Nadie lo escribe desde la app: sólo las funciones de abajo (security definer).

create or replace function mes_cupo_actual() returns text
language sql stable as $$
  select to_char(now() at time zone 'America/Mexico_City', 'YYYY-MM');
$$;

-- 2) Plan efectivo y límite ──────────────────────────────────────────
--    Mismo mapa que lib/services/planes.dart:
--    master/premium/taller/pro/industrial = sin límite; trial/prueba
--    vigente = sin límite; lo demás = Gratis, 5 al mes.
create or replace function limite_cotizaciones(p_negocio_id uuid) returns integer
language sql stable security definer set search_path = public as $$
  select case
    when n.plan in ('master', 'premium', 'taller', 'pro', 'industrial') then null
    when n.plan in ('trial', 'prueba') and n.trial_hasta > now() then null
    else 5
  end
  from negocios n where n.id = p_negocio_id;
$$;

-- 3) Lo que ve la app: { limite, usadas, quedan, mes } ─────────────
create or replace function cupo_cotizaciones() returns json
language plpgsql stable security definer set search_path = public as $$
declare
  v_neg uuid := negocio_del_usuario();
  v_lim integer;
  v_usadas integer;
begin
  if v_neg is null then
    return json_build_object('limite', 0, 'usadas', 0, 'quedan', 0, 'mes', mes_cupo_actual());
  end if;
  v_lim := limite_cotizaciones(v_neg);
  select coalesce(usadas, 0) into v_usadas
    from cotizaciones_cupo where negocio_id = v_neg and mes = mes_cupo_actual();
  v_usadas := coalesce(v_usadas, 0);
  return json_build_object(
    'limite', v_lim,
    'usadas', v_usadas,
    'quedan', case when v_lim is null then null else greatest(v_lim - v_usadas, 0) end,
    'mes', mes_cupo_actual());
end;
$$;
grant execute on function cupo_cotizaciones() to authenticated;

-- 4) Folio por taller ───────────────────────────────────────────────
--    Usa serie_cotizacion y folio_actual de la configuracion_empresa DEL
--    taller. Si no tiene configuración todavía, la crea.
create or replace function siguiente_folio_cotizacion(p_negocio_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_serie text;
  v_num integer;
begin
  update configuracion_empresa
     set folio_actual = coalesce(folio_actual, 1) + 1
   where negocio_id = p_negocio_id
   returning coalesce(serie_cotizacion, 'COT'), coalesce(folio_actual, 2) - 1 into v_serie, v_num;
  if v_num is null then
    insert into configuracion_empresa (negocio_id, serie_cotizacion, folio_actual)
      values (p_negocio_id, 'COT', 2);
    v_serie := 'COT'; v_num := 1;
  end if;
  return v_serie || '-' || to_char(now() at time zone 'America/Mexico_City', 'YYYY') || '-' || lpad(v_num::text, 4, '0');
end;
$$;

-- La función vieja que llamaba la app: ahora sólo da el folio del taller
-- del usuario (sin consumir cupo; el cupo lo consume el trigger al insertar).
create or replace function generar_folio_cotizacion() returns text
language plpgsql security definer set search_path = public as $$
begin
  return siguiente_folio_cotizacion(negocio_del_usuario());
end;
$$;

-- 5) El trigger: consume cupo y pone folio en cada cotización nueva ──
create or replace function cotizaciones_consumir_cupo() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_lim integer;
  v_usadas integer;
begin
  if new.negocio_id is null then
    new.negocio_id := negocio_del_usuario();
  end if;
  if new.negocio_id is null then
    raise exception 'SIN_NEGOCIO' using hint = 'La cotización no tiene taller.';
  end if;

  v_lim := limite_cotizaciones(new.negocio_id);

  insert into cotizaciones_cupo (negocio_id, mes, usadas)
    values (new.negocio_id, mes_cupo_actual(), 0)
    on conflict (negocio_id, mes) do nothing;

  -- Bloquea la fila del mes para que dos inserts al mismo tiempo no pasen
  select usadas into v_usadas
    from cotizaciones_cupo
   where negocio_id = new.negocio_id and mes = mes_cupo_actual()
   for update;

  if v_lim is not null and v_usadas >= v_lim then
    raise exception 'SIN_CUPO'
      using hint = format('Tu plan incluye %s cotizaciones al mes y ya las usaste. El cupo se renueva el día 1.', v_lim);
  end if;

  update cotizaciones_cupo
     set usadas = usadas + 1, actualizado = now()
   where negocio_id = new.negocio_id and mes = mes_cupo_actual();

  -- Folio del servidor si la app no mandó uno válido (o mandó uno provisional)
  if new.folio is null or new.folio = '' or new.folio ~ '^COT-[0-9]{13}$' then
    new.folio := siguiente_folio_cotizacion(new.negocio_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_cotizaciones_cupo on cotizaciones;
create trigger trg_cotizaciones_cupo
  before insert on cotizaciones
  for each row execute function cotizaciones_consumir_cupo();

-- 6) Folio único por taller, no por toda la base ────────────────────
--    (la restricción vieja `folio unique` hacía chocar a dos talleres con
--    la misma serie). Si el nombre de la restricción es otro en tu base,
--    revisa con: select conname from pg_constraint where conrelid = 'cotizaciones'::regclass;
alter table cotizaciones drop constraint if exists cotizaciones_folio_key;
create unique index if not exists cotizaciones_negocio_folio_idx on cotizaciones (negocio_id, folio);

-- 7) Arranque: anota lo que ya se cotizó este mes para que el cambio no
--    regale cupo a quien ya lo gastó.
insert into cotizaciones_cupo (negocio_id, mes, usadas)
select negocio_id, mes_cupo_actual(), count(*)
  from cotizaciones
 where negocio_id is not null
   and created_at >= date_trunc('month', now() at time zone 'America/Mexico_City') at time zone 'America/Mexico_City'
 group by negocio_id
on conflict (negocio_id, mes) do update set usadas = greatest(cotizaciones_cupo.usadas, excluded.usadas);
