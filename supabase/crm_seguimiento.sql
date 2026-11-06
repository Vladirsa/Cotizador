-- ════════════════════════════════════════════════════════════════════
-- HETNA Cotizador — CRM con seguimiento                       6 nov 2026
-- Correr en Supabase → SQL Editor del proyecto del Cotizador.
-- Se puede correr dos veces sin problema.
-- ════════════════════════════════════════════════════════════════════
begin;

-- Próximo paso y último contacto en la ficha del cliente
alter table clientes add column if not exists proximo_paso text;
alter table clientes add column if not exists proximo_paso_fecha date;
alter table clientes add column if not exists ultimo_contacto timestamptz;

-- Por qué se perdió una cotización (precio, tiempo, otro proveedor…)
alter table cotizaciones add column if not exists motivo_perdida text;
alter table cotizaciones add column if not exists nota_perdida text;

-- Bitácora de contactos: llamadas, WhatsApp, visitas, correos
create table if not exists contactos_cliente (
  id uuid primary key default uuid_generate_v4(),
  negocio_id uuid references negocios(id),
  cliente_id uuid not null references clientes(id) on delete cascade,
  tipo text not null default 'whatsapp'
    check (tipo in ('whatsapp','llamada','visita','correo','otro')),
  nota text,
  hecho_por_nombre text,
  created_at timestamptz default now()
);
create index if not exists idx_contactos_cliente on contactos_cliente(cliente_id, created_at desc);

alter table contactos_cliente enable row level security;
drop policy if exists "negocio contactos_cliente" on contactos_cliente;
create policy "negocio contactos_cliente" on contactos_cliente for all to authenticated
  using (negocio_id = negocio_del_usuario()
         or exists (select 1 from clientes cl where cl.id = contactos_cliente.cliente_id and cl.negocio_id = negocio_del_usuario()))
  with check (negocio_id = negocio_del_usuario()
         or exists (select 1 from clientes cl where cl.id = contactos_cliente.cliente_id and cl.negocio_id = negocio_del_usuario()));

-- Cada contacto registrado actualiza "último contacto" del cliente
create or replace function marcar_ultimo_contacto() returns trigger as $$
begin
  update clientes set ultimo_contacto = NEW.created_at where id = NEW.cliente_id;
  return NEW;
end;
$$ language plpgsql;
drop trigger if exists trg_contacto_cliente on contactos_cliente;
create trigger trg_contacto_cliente after insert on contactos_cliente
  for each row execute function marcar_ultimo_contacto();

commit;
