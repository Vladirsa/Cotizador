-- ════════════════════════════════════════════════════════════════════
-- Cotizador 2.0 · Fase 4 — Factura electrónica, costo real y mantenimiento
--
-- 1. Factura electrónica (CFDI 4.0) con Facturapi en modo multi-organización:
--    HETNA tiene una cuenta y cada taller es una "organización" con su RFC y
--    su CSD. La llave de cada organización la guarda sólo el servidor
--    (negocios_facturapi, sin acceso desde la app). cfdi_emitidos es la
--    bitácora que ve el taller. Facturas incluidas por plan: Taller 30,
--    Pro 150, Industrial sin límite; las extra se anotan a $2 y se cobran en
--    el corte del día 1 (junto con la comisión de PayPal).
-- 2. Costo real por pedido (pedido_costos): horas de cada máquina, material
--    del inventario, horas del operador y otros gastos → utilidad real por
--    pedido, por máquina y por cliente.
-- 3. Mantenimiento de máquinas: horas acumuladas (horas_base + las horas de
--    máquina capturadas en los pedidos), tareas cada N horas o N días y
--    registro de lo que se hizo. El servidor avisa cuando toca.
--
-- Pegar una sola vez en Supabase > SQL Editor del proyecto de la app.
-- Idempotente: se puede volver a correr.
-- ════════════════════════════════════════════════════════════════════

-- 0) Trigger común: si la app no manda negocio_id, se toma el del usuario
create or replace function poner_negocio_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.negocio_id is null then
    new.negocio_id := negocio_del_usuario();
  end if;
  return new;
end;
$$;

-- 1) Factura electrónica ─────────────────────────────────────────────
create table if not exists negocios_facturapi (
  negocio_id uuid primary key references negocios(id) on delete cascade,
  org_id text not null,               -- organización en Facturapi
  llave_prueba text,                  -- sk_test_...
  llave_real text,                    -- sk_live_...
  rfc text,
  razon_social text,
  regimen text,
  cp text,
  csd_vence timestamptz,
  config jsonb not null default '{}'::jsonb,  -- clave_producto, clave_unidad, serie
  creado timestamptz not null default now(),
  actualizado timestamptz not null default now()
);
alter table negocios_facturapi enable row level security;
revoke all on negocios_facturapi from anon, authenticated;

create table if not exists cfdi_emitidos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  pedido_id uuid references pedidos(id) on delete set null,
  cotizacion_id uuid references cotizaciones(id) on delete set null,
  cliente_id uuid references clientes(id) on delete set null,
  facturapi_id text not null,
  uuid text,                           -- folio fiscal del SAT
  serie text,
  folio integer,
  receptor_rfc text,
  receptor_nombre text,
  receptor_correo text,
  subtotal numeric(12,2),
  iva numeric(12,2),
  total numeric(12,2),
  moneda text not null default 'MXN',
  modo text not null default 'prueba' check (modo in ('prueba', 'real')),
  estado text not null default 'valida' check (estado in ('valida', 'cancelada', 'cancelacion_pendiente')),
  motivo_cancelacion text,
  extra boolean not null default false,        -- pasó las incluidas en su plan
  costo_extra numeric(10,2) not null default 0,
  comision_cobro_id uuid,
  creado timestamptz not null default now(),
  cancelado_en timestamptz
);
create index if not exists cfdi_negocio_idx on cfdi_emitidos (negocio_id, creado desc);
create index if not exists cfdi_pedido_idx on cfdi_emitidos (pedido_id);
alter table cfdi_emitidos enable row level security;
drop policy if exists "cfdi: el taller los ve" on cfdi_emitidos;
create policy "cfdi: el taller los ve" on cfdi_emitidos
  for select using (negocio_id = negocio_del_usuario());
-- Sólo el servidor los crea y cancela.

-- 2) Costo real por pedido ───────────────────────────────────────────
create table if not exists pedido_costos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid references negocios(id) on delete cascade,
  pedido_id uuid not null references pedidos(id) on delete cascade,
  tipo text not null check (tipo in ('maquina', 'material', 'operador', 'otro')),
  maquina_id uuid,                     -- maquinaria.id (tipo maquina)
  material_id uuid,                    -- inventario_bodega.id (tipo material)
  concepto text,
  cantidad numeric(12,3) not null default 0,  -- horas o unidades
  costo_unitario numeric(12,2) not null default 0,
  costo_total numeric(12,2) not null default 0,
  creado timestamptz not null default now()
);
create index if not exists pedido_costos_pedido_idx on pedido_costos (pedido_id);
create index if not exists pedido_costos_maquina_idx on pedido_costos (maquina_id) where tipo = 'maquina';
alter table pedido_costos enable row level security;
drop policy if exists "costos: el taller los maneja" on pedido_costos;
create policy "costos: el taller los maneja" on pedido_costos for all to authenticated
  using (negocio_id = negocio_del_usuario())
  with check (negocio_id = negocio_del_usuario());
drop trigger if exists trg_pedido_costos_negocio on pedido_costos;
create trigger trg_pedido_costos_negocio before insert on pedido_costos
  for each row execute function poner_negocio_usuario();

-- 3) Mantenimiento ──────────────────────────────────────────────────
alter table maquinaria add column if not exists horas_base numeric(12,1) not null default 0;  -- horas que ya traía
alter table maquinaria add column if not exists tipo_maquina text;  -- router | laser | plasma | impresora3d | fibra | otra

create table if not exists mantenimiento_tareas (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid references negocios(id) on delete cascade,
  maquina_id uuid not null,
  nombre text not null,
  cada_horas numeric(10,1),            -- cada N horas de máquina (o null)
  cada_dias integer,                   -- cada N días (o null)
  ultima_horas numeric(12,1) not null default 0,
  ultima_fecha date not null default current_date,
  activa boolean not null default true,
  avisado_en timestamptz,
  creado timestamptz not null default now()
);
create index if not exists mant_tareas_maquina_idx on mantenimiento_tareas (maquina_id);
alter table mantenimiento_tareas enable row level security;
drop policy if exists "mant tareas: el taller" on mantenimiento_tareas;
create policy "mant tareas: el taller" on mantenimiento_tareas for all to authenticated
  using (negocio_id = negocio_del_usuario()) with check (negocio_id = negocio_del_usuario());
drop trigger if exists trg_mant_tareas_negocio on mantenimiento_tareas;
create trigger trg_mant_tareas_negocio before insert on mantenimiento_tareas
  for each row execute function poner_negocio_usuario();

create table if not exists mantenimiento_registros (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid references negocios(id) on delete cascade,
  maquina_id uuid not null,
  tarea_id uuid references mantenimiento_tareas(id) on delete set null,
  descripcion text not null,
  fecha date not null default current_date,
  horas_maquina numeric(12,1),
  costo numeric(12,2) not null default 0,
  notas text,
  creado timestamptz not null default now()
);
create index if not exists mant_reg_maquina_idx on mantenimiento_registros (maquina_id, fecha desc);
alter table mantenimiento_registros enable row level security;
drop policy if exists "mant registros: el taller" on mantenimiento_registros;
create policy "mant registros: el taller" on mantenimiento_registros for all to authenticated
  using (negocio_id = negocio_del_usuario()) with check (negocio_id = negocio_del_usuario());
drop trigger if exists trg_mant_reg_negocio on mantenimiento_registros;
create trigger trg_mant_reg_negocio before insert on mantenimiento_registros
  for each row execute function poner_negocio_usuario();

-- Horas actuales de cada máquina = horas_base + horas capturadas en pedidos
create or replace view v_horas_maquina with (security_invoker = true) as
select m.id as maquina_id, m.negocio_id,
       coalesce(m.horas_base, 0) + coalesce(sum(c.cantidad), 0) as horas
  from maquinaria m
  left join pedido_costos c on c.maquina_id = m.id and c.tipo = 'maquina'
 group by m.id, m.negocio_id, m.horas_base;
