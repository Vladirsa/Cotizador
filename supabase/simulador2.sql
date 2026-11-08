-- ════════════════════════════════════════════════════════════════════
-- HETNA Cotizador — Simulador 2.0                              6 nov 2026
-- Correr en Supabase → SQL Editor del proyecto del Cotizador.
-- Se puede correr dos veces sin problema. No borra nada.
--
-- Una sola fórmula para todos los servicios:
--   PRECIO = (material + máquina + operador + preparación + acabados
--             + gastos fijos) ÷ (1 − margen)
-- El tiempo de máquina sale del archivo (metros de corte ÷ velocidad,
-- volumen ÷ tasa de remoción…). Las velocidades viven por máquina y
-- material en sim2_velocidades; las de HETNA se marcan "sugerido" hasta
-- que el taller las confirme o las corrija con sus tiempos reales.
-- ════════════════════════════════════════════════════════════════════
begin;

-- ── A. Máquinas: lo que el simulador necesita además del costo/hora ──
alter table maquinaria add column if not exists tipo text not null default 'router'
  check (tipo in ('router','laser_co2','laser_fibra','plasma','router_3d','impresora_3d','torno','otro'));
alter table maquinaria add column if not exists mesa_largo_mm numeric(8,0);
alter table maquinaria add column if not exists mesa_ancho_mm numeric(8,0);
alter table maquinaria add column if not exists mesa_alto_mm numeric(8,0);
-- Minutos de preparación típicos (montar material, cero pieza, cambio de
-- fresa). Se cobran UNA vez por pedido.
alter table maquinaria add column if not exists preparacion_min numeric(6,1) not null default 15;
-- Segundos que tarda cada perforación/entrada (plunge)
alter table maquinaria add column if not exists perforacion_seg numeric(5,1) not null default 2;
-- 3D: cm³ de material que quita por minuto (router 3D / torno)
alter table maquinaria add column if not exists remocion_cm3_min numeric(8,2);
-- Impresora 3D: cm³ por hora que imprime
alter table maquinaria add column if not exists impresion_cm3_h numeric(8,2);
-- $/hora escrito directo (si el taller no quiere que se calcule)
alter table maquinaria add column if not exists costo_hora_manual numeric(10,2);

-- ── B. Materiales: el inventario ya tiene espesor y medida de hoja (ver
--      inventario_pedidos.sql). Se agrega lo que falta para 3D y merma propia.
alter table inventario_bodega add column if not exists densidad_g_cm3 numeric(6,3);
alter table inventario_bodega add column if not exists merma_pct numeric(5,1);
alter table inventario_bodega add column if not exists tipo_material text; -- mdf, triplay, acrilico, pla, acero…

-- ── C. Velocidades por máquina y material ──
create table if not exists sim2_velocidades (
  id uuid primary key default uuid_generate_v4(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  maquina_id uuid references maquinaria(id) on delete cascade,
  -- Se guarda por tipo de material + espesor, no por fila del inventario,
  -- para que sirva aunque el taller compre otra marca de MDF 18 mm
  tipo_material text not null,
  espesor_mm numeric(6,2) not null default 0,
  velocidad_corte_m_min numeric(8,3),     -- 2D: corte perimetral
  velocidad_grabado_cm2_min numeric(8,2), -- grabado por área
  remocion_cm3_min numeric(8,2),          -- 3D
  impresion_cm3_h numeric(8,2),           -- impresión 3D
  sugerido boolean not null default true, -- true = valor de HETNA, sin confirmar
  origen text,                            -- 'hetna' | 'taller' | 'tiempo_real'
  muestras int not null default 0,        -- cuántos pedidos reales la ajustaron
  updated_at timestamptz default now(),
  unique (negocio_id, maquina_id, tipo_material, espesor_mm)
);
alter table sim2_velocidades enable row level security;
drop policy if exists "negocio sim2_velocidades" on sim2_velocidades;
create policy "negocio sim2_velocidades" on sim2_velocidades for all to authenticated
  using (negocio_id = negocio_del_usuario()) with check (negocio_id = negocio_del_usuario());

-- ── D. Acabados del taller (lija, barniz, pintura…) ──
create table if not exists sim2_acabados (
  id uuid primary key default uuid_generate_v4(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  nombre text not null,
  precio_pieza numeric(10,2) not null default 0,
  precio_m2 numeric(10,2) not null default 0,
  minutos_pieza numeric(6,1) not null default 0, -- tiempo de operador por pieza
  activo boolean not null default true,
  orden int not null default 0
);
alter table sim2_acabados enable row level security;
drop policy if exists "negocio sim2_acabados" on sim2_acabados;
create policy "negocio sim2_acabados" on sim2_acabados for all to authenticated
  using (negocio_id = negocio_del_usuario()) with check (negocio_id = negocio_del_usuario());

-- ── E. Referencia de mercado (opcional, sólo se muestra como comparación) ──
alter table empresa_config add column if not exists mercado_m2 numeric(10,2);    -- $/m² corte 2D
alter table empresa_config add column if not exists mercado_hora numeric(10,2);  -- $/h máquina
alter table empresa_config add column if not exists mercado_cm3 numeric(10,4);   -- $/cm³ impresión 3D
-- Tiempo de armado/manejo por pieza (quitar, limpiar, empacar) en minutos
alter table empresa_config add column if not exists manejo_min_pieza numeric(6,1) not null default 1;

-- ── F. Historial de simulaciones ("ya cotizaste algo parecido") ──
create table if not exists sim2_historial (
  id uuid primary key default uuid_generate_v4(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  cliente_id uuid references clientes(id) on delete set null,
  cliente_nombre text,
  archivo text,
  servicio text,            -- router | laser_co2 | plasma | router_3d | impresora_3d…
  maquina_id uuid,
  tipo_material text,
  espesor_mm numeric(6,2),
  largo_mm numeric(8,1), ancho_mm numeric(8,1), alto_mm numeric(8,1),
  metros_corte numeric(10,3),
  volumen_cm3 numeric(12,2),
  cantidad int not null default 1,
  tiempo_min numeric(10,1),
  costo_pieza numeric(12,2),
  precio_pieza numeric(12,2),
  margen_pct numeric(5,1),
  created_at timestamptz default now()
);
create index if not exists idx_sim2_historial on sim2_historial(negocio_id, created_at desc);
alter table sim2_historial enable row level security;
drop policy if exists "negocio sim2_historial" on sim2_historial;
create policy "negocio sim2_historial" on sim2_historial for all to authenticated
  using (negocio_id = negocio_del_usuario()) with check (negocio_id = negocio_del_usuario());

-- ── G. Aprender de los tiempos reales ──
-- La partida guarda cuánto tiempo de máquina se estimó, con qué máquina y
-- material; al terminar el maquinado (QR) se compara con el tiempo real.
alter table cotizacion_items add column if not exists tiempo_min numeric(10,1);
alter table cotizacion_items add column if not exists maquina_id uuid references maquinaria(id) on delete set null;
alter table cotizacion_items add column if not exists tipo_material text;
alter table cotizacion_items add column if not exists espesor_mm numeric(6,2);
alter table pedidos add column if not exists tiempo_estimado_min numeric(10,1);
alter table pedidos add column if not exists tiempo_real_min numeric(10,1);

commit;
