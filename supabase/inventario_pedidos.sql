-- ════════════════════════════════════════════════════════════════════
-- HETNA Cotizador — Inventario conectado a pedidos               6 nov 2026
-- Correr en Supabase → SQL Editor del proyecto del Cotizador.
-- Se puede correr dos veces sin problema.
-- ════════════════════════════════════════════════════════════════════
begin;

-- Cada partida de la cotización puede decir qué material del inventario
-- usa y cuántas unidades (hojas, kg, piezas). Lo llena el simulador.
alter table cotizacion_items add column if not exists material_id uuid references inventario_bodega(id) on delete set null;
alter table cotizacion_items add column if not exists material_cantidad numeric(12,3);

-- El pedido recuerda si ya se descontó el material (para no descontar dos veces)
alter table pedidos add column if not exists material_descontado boolean not null default false;

-- Retazos: sobrantes de hoja que vuelven a la bodega con su medida
alter table inventario_bodega add column if not exists es_retazo boolean not null default false;
alter table inventario_bodega add column if not exists largo_mm numeric(10,1);
alter table inventario_bodega add column if not exists ancho_mm numeric(10,1);
alter table inventario_bodega add column if not exists espesor_mm numeric(10,2);
alter table inventario_bodega add column if not exists material_padre_id uuid references inventario_bodega(id) on delete set null;

-- Los movimientos saben de qué pedido vienen
alter table movimientos_inventario add column if not exists pedido_id uuid references pedidos(id) on delete set null;

commit;
