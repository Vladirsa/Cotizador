-- ════════════════════════════════════════════════════════════════════
-- Cotizador 2.0 · Fase 2 — Liga pública de la cotización, aceptación en
-- línea y cobro del anticipo a la cuenta de Mercado Pago de cada taller.
--
-- Qué agrega:
--   1. cotizaciones.token_publico: la liga https://hetnacnc.com/c/<token>
--      que el taller manda al cliente. Se genera sola al crear la cotización.
--   2. Aceptación en línea: aceptada_en / aceptada_por (nombre que escribió
--      el cliente) y liga_vista_en (primera vez que la abrió).
--   3. Anticipo: anticipo_monto (lo que se pide), anticipo_pagado (lo que ya
--      entró) y anticipo_estado ('pendiente' | 'pagado' | 'sin_anticipo').
--   4. negocios_mp: la cuenta de Mercado Pago que conectó cada taller
--      (OAuth). NADIE la lee desde la app: sólo el servidor con la llave de
--      servicio. La app pregunta con mp_estado() si ya está conectada.
--   5. cotizacion_pagos: cada pago que avisó Mercado Pago, con la comisión
--      HETNA que se descontó (marketplace_fee).
--
-- Pegar una sola vez en Supabase > SQL Editor del proyecto de la app.
-- Idempotente: se puede volver a correr.
-- ════════════════════════════════════════════════════════════════════

-- 1) Columnas nuevas en cotizaciones ────────────────────────────────
alter table cotizaciones add column if not exists token_publico text;
alter table cotizaciones add column if not exists liga_vista_en timestamptz;
alter table cotizaciones add column if not exists aceptada_en timestamptz;
alter table cotizaciones add column if not exists aceptada_por text;
alter table cotizaciones add column if not exists anticipo_monto numeric(12,2);
alter table cotizaciones add column if not exists anticipo_pagado numeric(12,2) not null default 0;
alter table cotizaciones add column if not exists anticipo_estado text not null default 'pendiente'
  check (anticipo_estado in ('pendiente', 'pagado', 'sin_anticipo'));
create unique index if not exists cotizaciones_token_publico_idx on cotizaciones (token_publico);

-- Token: 22 caracteres de [a-zA-Z0-9], ~130 bits; imposible de adivinar.
create or replace function generar_token_publico() returns text
language sql volatile as $$
  select string_agg(
    substr('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
           1 + floor(random() * 62)::int, 1), '')
  from generate_series(1, 22);
$$;

create or replace function cotizaciones_poner_token() returns trigger
language plpgsql as $$
begin
  if new.token_publico is null or new.token_publico = '' then
    new.token_publico := generar_token_publico();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_cotizaciones_token on cotizaciones;
create trigger trg_cotizaciones_token
  before insert on cotizaciones
  for each row execute function cotizaciones_poner_token();

-- Las que ya existían
update cotizaciones set token_publico = generar_token_publico() where token_publico is null;

-- 2) Cuenta de Mercado Pago de cada taller ────────────────────────────
create table if not exists negocios_mp (
  negocio_id uuid primary key references negocios(id) on delete cascade,
  mp_user_id text not null,
  access_token text not null,
  refresh_token text,
  public_key text,
  expira_en timestamptz,
  conectado_en timestamptz not null default now(),
  actualizado timestamptz not null default now()
);
alter table negocios_mp enable row level security;
-- Sin políticas: ni select ni insert desde la app. Sólo la llave de servicio.
revoke all on negocios_mp from anon, authenticated;

-- Lo único que la app puede saber: ¿está conectada? ¿desde cuándo?
create or replace function mp_estado() returns json
language plpgsql stable security definer set search_path = public as $$
declare
  v_neg uuid := negocio_del_usuario();
  v_fila negocios_mp%rowtype;
begin
  if v_neg is null then
    return json_build_object('conectado', false);
  end if;
  select * into v_fila from negocios_mp where negocio_id = v_neg;
  if not found then
    return json_build_object('conectado', false);
  end if;
  return json_build_object(
    'conectado', true,
    'mp_user_id', v_fila.mp_user_id,
    'conectado_en', v_fila.conectado_en,
    'expira_en', v_fila.expira_en);
end;
$$;
grant execute on function mp_estado() to authenticated;

-- 3) Pagos que avisó Mercado Pago ─────────────────────────────────────
create table if not exists cotizacion_pagos (
  id uuid primary key default gen_random_uuid(),
  cotizacion_id uuid not null references cotizaciones(id) on delete cascade,
  negocio_id uuid not null references negocios(id) on delete cascade,
  mp_payment_id text not null unique,
  monto numeric(12,2) not null,
  comision_hetna numeric(12,2) not null default 0,
  estado text not null,                   -- approved, pending, rejected, refunded...
  metodo text,                            -- credit_card, debit_card, account_money, ticket...
  pagador text,                           -- correo que dio Mercado Pago
  detalle jsonb,
  creado timestamptz not null default now(),
  actualizado timestamptz not null default now()
);
create index if not exists cotizacion_pagos_cotizacion_idx on cotizacion_pagos (cotizacion_id);
alter table cotizacion_pagos enable row level security;
drop policy if exists "pagos: el taller los lee" on cotizacion_pagos;
create policy "pagos: el taller los lee" on cotizacion_pagos
  for select using (negocio_id = negocio_del_usuario());
-- Nadie escribe desde la app: los pone el servidor al recibir el aviso.

-- 4) Comisión HETNA por plan (misma tabla que el servidor; informativa) ─
--    Gratis 3 % · Taller 2 % · Pro 1.5 % · Industrial 1 % · tope $150 por cobro
create or replace function comision_hetna_pct(p_negocio_id uuid) returns numeric
language sql stable security definer set search_path = public as $$
  select case
    when n.plan in ('industrial', 'master') then 1.0
    when n.plan in ('pro', 'premium') then 1.5
    when n.plan = 'taller' then 2.0
    when n.plan in ('trial', 'prueba') and n.trial_hasta > now() then 2.0
    else 3.0
  end
  from negocios n where n.id = p_negocio_id;
$$;
