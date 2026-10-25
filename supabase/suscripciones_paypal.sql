-- ════════════════════════════════════════════════════════════════════
-- HETNA Cotizador — Suscripciones con PayPal (USD)            25 oct 2026
-- Correr en Supabase → SQL Editor del proyecto del Cotizador, DESPUÉS de
-- suscripciones_y_correos.sql y ANTES de desplegar el backend con PayPal.
-- Todo va en una transacción: si algo falla, no se aplica NADA.
-- Se puede correr dos veces sin problema.
-- ════════════════════════════════════════════════════════════════════
begin;

-- Con qué se paga la suscripción activa y los datos de PayPal.
-- Los escribe SOLO el backend de hetnacnc.com (llave de servicio).
alter table negocios add column if not exists pago_proveedor text;            -- mercadopago | paypal
alter table negocios add column if not exists pp_suscripcion_id text;         -- suscripción activa en PayPal
alter table negocios add column if not exists pp_suscripcion_pendiente text;  -- la que se acaba de crear y aún no se aprueba

-- Las suscripciones activas de Mercado Pago que ya existen son de Mercado Pago
update negocios set pago_proveedor = 'mercadopago'
where mp_suscripcion_id is not null and pago_proveedor is null;

-- Nadie cambia su plan ni los datos de cobro desde la app
-- (mismo trigger de suscripciones_y_correos.sql, con los campos de PayPal)
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
    or new.mp_correo_pago           is distinct from old.mp_correo_pago
    or new.pago_proveedor           is distinct from old.pago_proveedor
    or new.pp_suscripcion_id        is distinct from old.pp_suscripcion_id
    or new.pp_suscripcion_pendiente is distinct from old.pp_suscripcion_pendiente) then
    raise exception 'El plan del taller solo se cambia al pagar la suscripción';
  end if;
  return new;
end $$;
drop trigger if exists tr_proteger_plan on negocios;
create trigger tr_proteger_plan before update on negocios
  for each row execute function proteger_plan_negocio();

commit;

-- Revisión: deben salir las 3 columnas nuevas
select column_name from information_schema.columns
where table_schema = 'public' and table_name = 'negocios'
  and column_name in ('pago_proveedor', 'pp_suscripcion_id', 'pp_suscripcion_pendiente')
order by 1;
