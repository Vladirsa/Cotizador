-- ════════════════════════════════════════════════════════════════════
-- HETNA Cotizador — Suscripciones con Mercado Pago y registro con correo
-- confirmado                                                  24 oct 2026
-- Correr en Supabase → SQL Editor del proyecto del Cotizador.
-- Todo va en una transacción: si algo falla, no se aplica NADA.
-- Se puede correr dos veces sin problema.
-- ════════════════════════════════════════════════════════════════════
begin;

-- ─────────────────────────────────────────────────────────────────────
-- 1) Datos de la suscripción en el taller
--    Los escribe SOLO el backend de hetnacnc.com (llave de servicio), con
--    lo que responde Mercado Pago. La app únicamente los lee.
-- ─────────────────────────────────────────────────────────────────────
alter table negocios add column if not exists plan_estado text;               -- activa | cancelada | pausada
alter table negocios add column if not exists plan_renueva timestamptz;       -- siguiente cobro
alter table negocios add column if not exists plan_vence timestamptz;         -- hasta cuándo dura lo pagado si se canceló
alter table negocios add column if not exists mp_suscripcion_id text;         -- suscripción activa en Mercado Pago
alter table negocios add column if not exists mp_suscripcion_pendiente text;  -- la que se acaba de crear y aún no se paga
alter table negocios add column if not exists mp_correo_pago text;            -- correo de la cuenta de Mercado Pago que paga

-- Bitácora de lo que pasa con cada suscripción (para revisar cobros)
create table if not exists suscripciones_eventos (
  id bigint generated always as identity primary key,
  negocio_id uuid references negocios(id) on delete cascade,
  preapproval_id text,
  evento text not null,        -- creada | activada | cancelada | pausada | vencida
  plan text,
  estado text,
  monto numeric,
  creado timestamptz not null default now()
);
create index if not exists suscripciones_eventos_negocio_idx on suscripciones_eventos (negocio_id, creado desc);
-- Sin políticas: nadie desde la app la lee ni la escribe; sólo el servidor.
alter table suscripciones_eventos enable row level security;

-- ─────────────────────────────────────────────────────────────────────
-- 2) Nadie cambia su plan ni los datos de cobro desde la app
--    (amplía el trigger de seguridad_rls.sql con los campos nuevos)
-- ─────────────────────────────────────────────────────────────────────
create or replace function proteger_plan_negocio() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- auth.role() es 'authenticated' o 'anon' cuando viene de la app;
  -- es null desde el SQL Editor y 'service_role' desde el servidor.
  if coalesce(auth.role(), '') in ('authenticated', 'anon') and (
       new.plan                     is distinct from old.plan
    or new.trial_hasta              is distinct from old.trial_hasta
    or new.activo                   is distinct from old.activo
    or new.slug                     is distinct from old.slug
    or new.plan_estado              is distinct from old.plan_estado
    or new.plan_renueva             is distinct from old.plan_renueva
    or new.plan_vence               is distinct from old.plan_vence
    or new.mp_suscripcion_id        is distinct from old.mp_suscripcion_id
    or new.mp_suscripcion_pendiente is distinct from old.mp_suscripcion_pendiente
    or new.mp_correo_pago           is distinct from old.mp_correo_pago) then
    raise exception 'El plan del taller solo se cambia al pagar la suscripción';
  end if;
  return new;
end $$;
drop trigger if exists tr_proteger_plan on negocios;
create trigger tr_proteger_plan before update on negocios
  for each row execute function proteger_plan_negocio();

-- ─────────────────────────────────────────────────────────────────────
-- 3) Registro con confirmación de correo
--    Con "Confirm email" activo, al crear la cuenta todavía no hay sesión:
--    la app llama a registrar_taller sin iniciar sesión. La función ya
--    revisa que la cuenta exista, sea de ese correo y tenga menos de una
--    hora (seguridad_rls.sql), así que puede llamarse sin sesión.
-- ─────────────────────────────────────────────────────────────────────
grant execute on function registrar_taller(uuid, text, text, text, text, text) to anon, authenticated;

commit;

-- Revisión: deben salir las 6 columnas nuevas y la tabla con RLS
select column_name from information_schema.columns
where table_schema = 'public' and table_name = 'negocios'
  and column_name in ('plan_estado', 'plan_renueva', 'plan_vence', 'mp_suscripcion_id', 'mp_suscripcion_pendiente', 'mp_correo_pago')
order by 1;
