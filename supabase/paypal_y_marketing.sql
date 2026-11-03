-- ════════════════════════════════════════════════════════════════════════════
-- Cotizador 2.0 — PayPal del taller + Marketing en piloto automático
--
-- PayPal:
--   · negocios_paypal: la cuenta PayPal que vinculó cada taller ("Iniciar
--     sesión con PayPal"). Sólo la lee el servidor (llave de servicio).
--   · cotizacion_pagos ahora sirve para Mercado Pago y PayPal (proveedor,
--     moneda). Con PayPal el dinero llega completo al taller y la comisión
--     HETNA se anota como pendiente; se cobra una vez al mes
--     (comisiones_cobros) con una liga de pago.
--
-- Marketing automático:
--   · marketing_recetas: qué automatizaciones prendió cada taller y con qué
--     mensaje (seguimiento de cotización, último aviso, anticipo pendiente,
--     gracias + reseña, reactivar clientes).
--   · marketing_envios: bitácora de lo que ya se mandó (para no repetir y
--     para los números de "Resultados").
--
-- Pegar una sola vez en Supabase > SQL Editor del proyecto de la app.
-- Idempotente: se puede volver a correr.
-- ════════════════════════════════════════════════════════════════════════════

-- 1) PayPal del taller ───────────────────────────────────────────────
create table if not exists negocios_paypal (
  negocio_id uuid primary key references negocios(id) on delete cascade,
  payer_id text not null,          -- id de cuenta (merchant id) de PayPal
  email text,
  nombre text,
  verificada boolean,
  conectado_en timestamptz not null default now(),
  actualizado timestamptz not null default now()
);
alter table negocios_paypal enable row level security;
revoke all on negocios_paypal from anon, authenticated;

-- 2) Pagos de Mercado Pago y PayPal ───────────────────────────────────
alter table cotizacion_pagos add column if not exists proveedor text not null default 'mercadopago';
alter table cotizacion_pagos add column if not exists moneda text not null default 'MXN';
-- Comisión HETNA: con Mercado Pago ya viene descontada (cobrada); con PayPal
-- queda pendiente hasta el cobro del mes.
alter table cotizacion_pagos add column if not exists comision_cobrada boolean not null default true;
alter table cotizacion_pagos add column if not exists comision_cobro_id uuid;

create table if not exists comisiones_cobros (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  periodo text not null,            -- 'YYYY-MM' de los pagos que cubre
  monto numeric(12,2) not null,
  moneda text not null default 'MXN',
  estado text not null default 'pendiente' check (estado in ('pendiente', 'pagado', 'cancelado')),
  liga_pago text,
  referencia_pago text,
  creado timestamptz not null default now(),
  pagado_en timestamptz,
  unique (negocio_id, periodo, moneda)
);
alter table comisiones_cobros enable row level security;
drop policy if exists "comisiones: el taller las ve" on comisiones_cobros;
create policy "comisiones: el taller las ve" on comisiones_cobros
  for select using (negocio_id = negocio_del_usuario());

-- Lo que el taller ve en Configuración: comisiones PayPal por cobrar
create or replace function comisiones_pendientes() returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'pendiente', coalesce(sum(comision_hetna) filter (where comision_cobro_id is null), 0),
    'en_cobro', coalesce((select sum(monto) from comisiones_cobros c
                           where c.negocio_id = negocio_del_usuario() and c.estado = 'pendiente'), 0),
    'liga', (select liga_pago from comisiones_cobros c
              where c.negocio_id = negocio_del_usuario() and c.estado = 'pendiente'
              order by creado desc limit 1))
  from cotizacion_pagos
  where negocio_id = negocio_del_usuario() and proveedor = 'paypal'
    and estado = 'approved' and comision_cobrada = false;
$$;
grant execute on function comisiones_pendientes() to authenticated;

-- 3) Marketing en piloto automático ───────────────────────────────────
create table if not exists marketing_recetas (
  negocio_id uuid not null references negocios(id) on delete cascade,
  receta text not null,             -- seguimiento_cotizacion | ultimo_aviso | anticipo_pendiente | gracias_resena | reactivacion
  activa boolean not null default false,
  mensaje text,                     -- vacío = el mensaje sugerido
  correo boolean not null default true,     -- sale solo por correo
  whatsapp boolean not null default true,   -- queda listo en "Cola de hoy"
  config jsonb not null default '{}'::jsonb, -- dias, cupon, resena_url...
  actualizado timestamptz not null default now(),
  primary key (negocio_id, receta)
);
alter table marketing_recetas enable row level security;
drop policy if exists "recetas: el taller las maneja" on marketing_recetas;
create policy "recetas: el taller las maneja" on marketing_recetas for all to authenticated
  using (negocio_id = negocio_del_usuario())
  with check (negocio_id = negocio_del_usuario());

create table if not exists marketing_envios (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios(id) on delete cascade,
  receta text not null,
  cliente_id uuid references clientes(id) on delete cascade,
  referencia text not null default '',   -- cotización, pedido o periodo
  correo boolean not null default false,
  whatsapp boolean not null default false,
  enviado_en timestamptz not null default now(),
  unique (negocio_id, receta, cliente_id, referencia)
);
create index if not exists marketing_envios_negocio_idx on marketing_envios (negocio_id, enviado_en desc);
alter table marketing_envios enable row level security;
drop policy if exists "envios: el taller los ve" on marketing_envios;
create policy "envios: el taller los ve" on marketing_envios
  for select using (negocio_id = negocio_del_usuario());

-- La cola de WhatsApp necesita saber de qué taller es (la llena el servidor)
alter table cola_mensajes_wa add column if not exists negocio_id uuid references negocios(id) on delete cascade;
alter table cola_mensajes_wa add column if not exists receta text;

-- Resultados de los últimos 30 días por receta: enviados y cuántas de esas
-- cotizaciones se aceptaron o se pagaron DESPUÉS del mensaje.
create or replace function marketing_resultados() returns json
language sql stable security definer set search_path = public as $$
  select coalesce(json_object_agg(receta, json_build_object(
           'enviados', enviados, 'correos', correos, 'whatsapps', whatsapps, 'ganadas', ganadas)), '{}'::json)
  from (
    select e.receta,
           count(*) as enviados,
           count(*) filter (where e.correo) as correos,
           count(*) filter (where e.whatsapp) as whatsapps,
           count(*) filter (where exists (
             select 1 from cotizaciones c
              where c.negocio_id = e.negocio_id
                and c.id::text = split_part(e.referencia, ':', 1)
                and (c.aceptada_en > e.enviado_en or c.anticipo_estado = 'pagado' and c.updated_at > e.enviado_en)
           ) or exists (
             select 1 from pedidos p
              where p.cliente_id = e.cliente_id and p.created_at > e.enviado_en
                and e.receta = 'reactivacion'
           )) as ganadas
      from marketing_envios e
     where e.negocio_id = negocio_del_usuario()
       and e.enviado_en > now() - interval '30 days'
     group by e.receta
  ) t;
$$;
grant execute on function marketing_resultados() to authenticated;
