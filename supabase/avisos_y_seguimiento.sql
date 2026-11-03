-- ════════════════════════════════════════════════════════════════════
-- Cotizador 2.0 · Fase 2 (cierre) — Avisos al taller y seguimiento del
-- pedido en la liga del cliente (hetnacnc.com/c/<token>).
--
-- Qué agrega:
--   1. alertas.negocio_id (si no existía): el servidor crea alertas
--      "👀 abrió la cotización", "✅ aceptó" y "💰 pagó" para el taller.
--   2. pedidos.paqueteria / guia / rastreo_url: la guía de envío que
--      captura el taller en Avances; el cliente la ve y la rastrea desde
--      la misma liga.
--
-- Pegar una sola vez en Supabase > SQL Editor del proyecto de la app.
-- Idempotente: se puede volver a correr.
-- ════════════════════════════════════════════════════════════════════

-- 1) Alertas con taller ──────────────────────────────────────────────
alter table alertas add column if not exists negocio_id uuid references negocios(id) on delete cascade;
create index if not exists alertas_negocio_idx on alertas (negocio_id);

-- Las alertas viejas sin taller toman el de su cliente
update alertas a set negocio_id = cl.negocio_id
  from clientes cl
 where a.negocio_id is null and a.cliente_id = cl.id and cl.negocio_id is not null;

-- Que cada taller vea sólo sus alertas (además de lo que ya hubiera)
alter table alertas enable row level security;
drop policy if exists "alertas: el taller las ve" on alertas;
create policy "alertas: el taller las ve" on alertas for all to authenticated
  using (negocio_id = negocio_del_usuario()
         or (negocio_id is null and exists (select 1 from clientes cl
               where cl.id = alertas.cliente_id and cl.negocio_id = negocio_del_usuario())))
  with check (negocio_id is null or negocio_id = negocio_del_usuario());

-- Las que crea la app sin negocio_id lo toman del usuario
create or replace function alertas_poner_negocio() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.negocio_id is null then
    new.negocio_id := negocio_del_usuario();
  end if;
  return new;
end;
$$;
drop trigger if exists trg_alertas_negocio on alertas;
create trigger trg_alertas_negocio before insert on alertas
  for each row execute function alertas_poner_negocio();

-- 2) Guía de envío del pedido ───────────────────────────────────────
alter table pedidos add column if not exists paqueteria text;
alter table pedidos add column if not exists guia text;
alter table pedidos add column if not exists rastreo_url text;
