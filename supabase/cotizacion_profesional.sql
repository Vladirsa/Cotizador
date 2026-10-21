-- HETNA Cotizador — Cotización profesional (formato internacional)
-- Correr UNA vez en Supabase → SQL Editor (proyecto del Cotizador).
-- Es seguro correrlo de nuevo: no borra nada.

alter table cotizaciones
  add column if not exists tipo text not null default 'sencilla',
  add column if not exists datos_pro jsonb not null default '{}'::jsonb;

-- Solo se permiten los dos tipos
do $$ begin
  alter table cotizaciones
    add constraint cotizaciones_tipo_chk check (tipo in ('sencilla', 'profesional'));
exception when duplicate_object then null; end $$;

-- Para contar rápido las profesionales de cada taller (muestra del plan Gratis)
do $$ begin
  create index if not exists cotizaciones_tipo_idx on cotizaciones (negocio_id, tipo);
exception when undefined_column then
  create index if not exists cotizaciones_tipo_idx on cotizaciones (tipo);
end $$;
