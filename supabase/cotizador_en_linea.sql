-- ════════════════════════════════════════════════════════════════════
-- Cotizador 2.0 · Fase 3 — Cotizador en línea de cada taller
--
-- Cada taller tiene una página pública hetnacnc.com/t/<slug> donde su cliente
-- sube su archivo (DXF, SVG, STL, OBJ), elige el servicio y ve un precio
-- estimado con las tarifas del simulador del taller. La solicitud llega a la
-- app como cotización en borrador, con el archivo, y avisa al taller.
--
--   · negocios_pagina: cómo se ve la página (activa, título, servicios que
--     ofrece, si muestra precio, si sale en el directorio). La edita el
--     administrador desde la app. La liga (negocios.slug) sólo la cambia el
--     servidor, para que no choque con otra.
--   · solicitudes_en_linea: cada solicitud (aunque el taller se haya quedado
--     sin cupo de cotizaciones del mes: queda guardada y se puede convertir
--     después).
--   · cotizaciones.origen / archivo_*: para marcarlas "🌐 En línea" y abrir
--     el archivo del cliente.
--   · Bucket privado "solicitudes": los archivos; cada taller sólo puede
--     abrir los de su carpeta.
--
-- Pegar una sola vez en Supabase > SQL Editor del proyecto de la app.
-- Idempotente: se puede volver a correr.
-- ════════════════════════════════════════════════════════════════════

-- 1) Página del taller ───────────────────────────────────────────────
create table if not exists negocios_pagina (
  negocio_id uuid primary key references negocios(id) on delete cascade,
  activa boolean not null default false,
  titulo text,                       -- vacío = nombre comercial
  descripcion text,                  -- qué hace el taller, en 1–3 renglones
  ciudad text,
  servicios uuid[] not null default '{}', -- sim_servicios que ofrece (vacío = todos)
  mostrar_precio boolean not null default true,
  en_directorio boolean not null default true,
  actualizado timestamptz not null default now()
);
alter table negocios_pagina enable row level security;
drop policy if exists "pagina: el taller la ve" on negocios_pagina;
create policy "pagina: el taller la ve" on negocios_pagina
  for select using (negocio_id = negocio_del_usuario());
drop policy if exists "pagina: el admin la edita" on negocios_pagina;
create policy "pagina: el admin la edita" on negocios_pagina for all to authenticated
  using (negocio_id = negocio_del_usuario() and es_admin_del_negocio(negocio_id))
  with check (negocio_id = negocio_del_usuario() and es_admin_del_negocio(negocio_id));

-- 2) Solicitudes que llegan de la página ──────────────────────────────
create table if not exists solicitudes_en_linea (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  cotizacion_id uuid references cotizaciones(id) on delete set null,
  cliente_id uuid references clientes(id) on delete set null,
  nombre text not null,
  telefono text,
  correo text,
  empresa text,
  servicio text,
  tipo text,
  cantidad integer not null default 1,
  medidas jsonb not null default '{}'::jsonb, -- largo, ancho, alto (mm), corte, perforaciones, volumen
  archivo_ruta text,                 -- solicitudes/<negocio>/<id>/<archivo>
  archivo_nombre text,
  estimado numeric(12,2),
  moneda text not null default 'MXN',
  mensaje text,
  estado text not null default 'nueva' check (estado in ('nueva', 'cotizada', 'sin_cupo', 'descartada')),
  ip_hash text,
  creado timestamptz not null default now()
);
create index if not exists solicitudes_negocio_idx on solicitudes_en_linea (negocio_id, creado desc);
create index if not exists solicitudes_ip_idx on solicitudes_en_linea (ip_hash, creado desc);
alter table solicitudes_en_linea enable row level security;
drop policy if exists "solicitudes: el taller las ve" on solicitudes_en_linea;
create policy "solicitudes: el taller las ve" on solicitudes_en_linea
  for select using (negocio_id = negocio_del_usuario());
drop policy if exists "solicitudes: el taller las marca" on solicitudes_en_linea;
create policy "solicitudes: el taller las marca" on solicitudes_en_linea
  for update using (negocio_id = negocio_del_usuario()) with check (negocio_id = negocio_del_usuario());
-- Nadie las crea desde la app: las crea el servidor (llave de servicio).

-- 3) Cotizaciones que vienen de la página ─────────────────────────────
alter table cotizaciones add column if not exists origen text;          -- 'en_linea' | null (app)
alter table cotizaciones add column if not exists archivo_ruta text;
alter table cotizaciones add column if not exists archivo_nombre text;

-- 4) Archivos: bucket privado, cada taller lee su carpeta ──────────────
insert into storage.buckets (id, name, public, file_size_limit)
values ('solicitudes', 'solicitudes', false, 52428800)
on conflict (id) do nothing;

drop policy if exists "solicitudes: el taller lee sus archivos" on storage.objects;
create policy "solicitudes: el taller lee sus archivos" on storage.objects
  for select to authenticated
  using (bucket_id = 'solicitudes' and (storage.foldername(name))[1] = negocio_del_usuario()::text);
