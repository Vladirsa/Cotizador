-- ============================================
-- HETNA CNC - Base de datos Supabase (PostgreSQL)
-- Pegar completo en Supabase > SQL Editor > Run
-- ============================================

-- EXTENSIONES
create extension if not exists "uuid-ossp";

-- ============================================
-- TABLA: configuracion_empresa
-- ============================================
create table if not exists configuracion_empresa (
  id uuid primary key default uuid_generate_v4(),
  nombre_comercial text not null default 'HETNA CNC',
  rfc text,
  direccion text,
  telefono1 text,
  telefono2 text,
  correo text,
  sitio_web text,
  instagram text,
  facebook text,
  tiktok text,
  logo_url text,
  iva_default numeric(5,2) default 16.0,
  vigencia_cotizacion_dias integer default 7,
  metodo_pago_default text default '50% anticipo / 50% entrega',
  condicion_entrega_default text default 'LAB - En planta HETNA',
  serie_cotizacion text default 'COT',
  folio_actual integer default 1,
  alerta_dia3 boolean default true,
  alerta_dia5 boolean default true,
  cupon_dia7 boolean default true,
  alerta_post_entrega boolean default true,
  alerta_avances boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Insertar configuración inicial
insert into configuracion_empresa (nombre_comercial, sitio_web)
values ('HETNA CNC', 'www.hetnacnc.com')
on conflict do nothing;

-- ============================================
-- TABLA: clientes
-- ============================================
create table if not exists clientes (
  id uuid primary key default uuid_generate_v4(),
  nombre text not null,
  empresa text,
  rfc text,
  domicilio text,
  colonia text,
  ciudad text,
  estado text,
  codigo_postal text,
  telefono text,
  whatsapp text,
  correo text,
  tipo_cliente text default 'Cliente potencial'
    check (tipo_cliente in ('Cliente potencial','Cliente activo','Cliente frecuente','Distribuidor')),
  notas text,
  activo boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_clientes_nombre on clientes(nombre);
create index if not exists idx_clientes_empresa on clientes(empresa);
create index if not exists idx_clientes_tipo on clientes(tipo_cliente);

-- ============================================
-- TABLA: categorias_producto
-- ============================================
create table if not exists categorias_producto (
  id uuid primary key default uuid_generate_v4(),
  nombre text not null unique,
  color_hex text default '#185fa5',
  icono text default 'box',
  orden integer default 0
);

insert into categorias_producto (nombre, color_hex, icono, orden) values
  ('Maquinaria CNC', '#185fa5', 'tools', 1),
  ('Refacciones',    '#854f0b', 'settings', 2),
  ('Herramientas',   '#3b6d11', 'drill', 3),
  ('Consumibles',    '#993556', 'package', 4),
  ('Servicios',      '#0f6e56', 'tool', 5),
  ('Diseños CNC',    '#534ab7', 'vector', 6)
on conflict do nothing;

-- ============================================
-- TABLA: productos
-- ============================================
create table if not exists productos (
  id uuid primary key default uuid_generate_v4(),
  sku text unique,
  codigo_interno text,
  nombre text not null,
  descripcion text,
  categoria_id uuid references categorias_producto(id),
  marca text,
  proveedor text,
  costo numeric(12,2) default 0,
  precio_venta numeric(12,2) not null default 0,
  precio_distribuidor numeric(12,2),
  precio_mayoreo numeric(12,2),
  aplica_iva boolean default true,
  unidad_medida text default 'Pieza',
  stock_disponible integer default 0,
  stock_minimo integer default 1,
  ubicacion_fisica text,
  imagen_url text,
  pdf_url text,
  activo boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_productos_categoria on productos(categoria_id);
create index if not exists idx_productos_sku on productos(sku);
create index if not exists idx_productos_activo on productos(activo);

-- ============================================
-- TABLA: pdfs_catalogo
-- ============================================
create table if not exists pdfs_catalogo (
  id uuid primary key default uuid_generate_v4(),
  nombre text not null,
  descripcion text,
  url text not null,
  tamano_mb numeric(6,2),
  categoria text,
  activo boolean default true,
  created_at timestamptz default now()
);

-- ============================================
-- TABLA: cotizaciones
-- ============================================
create table if not exists cotizaciones (
  id uuid primary key default uuid_generate_v4(),
  folio text unique not null,
  cliente_id uuid references clientes(id),
  estado text default 'Borrador'
    check (estado in ('Borrador','Enviada','Aprobada','Rechazada','Vencida','Pedido')),
  subtotal numeric(12,2) default 0,
  descuento_pct numeric(5,2) default 0,
  descuento_fijo numeric(12,2) default 0,
  iva_pct numeric(5,2) default 16,
  iva_monto numeric(12,2) default 0,
  costo_envio numeric(12,2) default 0,
  total numeric(12,2) default 0,
  metodo_pago text,
  condicion_entrega text,
  fecha_entrega date,
  dias_habiles integer,
  vigencia_dias integer default 7,
  notas text,
  pdf_url text,
  fecha_envio_wa timestamptz,
  -- Seguimiento automático
  alerta_dia3_enviada boolean default false,
  alerta_dia5_enviada boolean default false,
  cupon_dia7_enviado boolean default false,
  cupon_codigo text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_cotizaciones_cliente on cotizaciones(cliente_id);
create index if not exists idx_cotizaciones_estado on cotizaciones(estado);
create index if not exists idx_cotizaciones_fecha on cotizaciones(created_at);

-- ============================================
-- TABLA: cotizacion_items
-- ============================================
create table if not exists cotizacion_items (
  id uuid primary key default uuid_generate_v4(),
  cotizacion_id uuid references cotizaciones(id) on delete cascade,
  producto_id uuid references productos(id),
  nombre_producto text not null,
  sku text,
  cantidad integer not null default 1,
  precio_unitario numeric(12,2) not null,
  descuento_item_pct numeric(5,2) default 0,
  subtotal numeric(12,2) not null,
  notas_item text,
  orden integer default 0
);

create index if not exists idx_items_cotizacion on cotizacion_items(cotizacion_id);

-- ============================================
-- TABLA: pedidos
-- ============================================
create table if not exists pedidos (
  id uuid primary key default uuid_generate_v4(),
  folio text unique not null,
  cotizacion_id uuid references cotizaciones(id),
  cliente_id uuid references clientes(id),
  estado text default 'Pedido'
    check (estado in ('Pedido','Pago','Produccion','Pruebas','Entrega','Entregado','Cancelado')),
  total numeric(12,2),
  fecha_entrega_estimada date,
  fecha_entregado date,
  notas_internas text,
  -- Alertas post-entrega
  redes_enviadas boolean default false,
  cupon_seguidor_enviado boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_pedidos_estado on pedidos(estado);
create index if not exists idx_pedidos_cliente on pedidos(cliente_id);

-- ============================================
-- TABLA: pedido_avances
-- ============================================
create table if not exists pedido_avances (
  id uuid primary key default uuid_generate_v4(),
  pedido_id uuid references pedidos(id) on delete cascade,
  etapa text not null,
  descripcion text,
  notificado_cliente boolean default false,
  fecha_notificacion timestamptz,
  created_at timestamptz default now()
);

-- ============================================
-- TABLA: alertas
-- ============================================
create table if not exists alertas (
  id uuid primary key default uuid_generate_v4(),
  tipo text not null,
    -- 'seguimiento_dia3' | 'seguimiento_dia5' | 'cupon_dia7'
    -- 'post_entrega_redes' | 'avance_pedido'
  referencia_id uuid,
  referencia_tipo text, -- 'cotizacion' | 'pedido'
  cliente_id uuid references clientes(id),
  titulo text not null,
  mensaje_wa text,
  completada boolean default false,
  fecha_programada timestamptz,
  fecha_completada timestamptz,
  created_at timestamptz default now()
);

create index if not exists idx_alertas_completada on alertas(completada);
create index if not exists idx_alertas_fecha on alertas(fecha_programada);

-- ============================================
-- FUNCIÓN: generar folio de cotización
-- ============================================
create or replace function generar_folio_cotizacion()
returns text as $$
declare
  cfg record;
  nuevo_folio text;
begin
  select serie_cotizacion, folio_actual into cfg
  from configuracion_empresa limit 1;

  nuevo_folio := cfg.serie_cotizacion || '-' || to_char(now(), 'YYYY') || '-' || lpad(cfg.folio_actual::text, 4, '0');

  update configuracion_empresa set folio_actual = folio_actual + 1;

  return nuevo_folio;
end;
$$ language plpgsql;

-- ============================================
-- FUNCIÓN: crear alertas automáticas al enviar cotización
-- ============================================
create or replace function crear_alertas_cotizacion()
returns trigger as $$
begin
  -- Solo cuando cambia a estado 'Enviada'
  if NEW.estado = 'Enviada' and OLD.estado != 'Enviada' then

    -- Alerta día 3
    insert into alertas (tipo, referencia_id, referencia_tipo, cliente_id, titulo, fecha_programada)
    values (
      'seguimiento_dia3', NEW.id, 'cotizacion', NEW.cliente_id,
      'Seguimiento día 3 — ' || NEW.folio,
      now() + interval '3 days'
    );

    -- Alerta día 5
    insert into alertas (tipo, referencia_id, referencia_tipo, cliente_id, titulo, fecha_programada)
    values (
      'seguimiento_dia5', NEW.id, 'cotizacion', NEW.cliente_id,
      'Seguimiento día 5 — ' || NEW.folio,
      now() + interval '5 days'
    );

    -- Cupón día 7
    insert into alertas (tipo, referencia_id, referencia_tipo, cliente_id, titulo, fecha_programada)
    values (
      'cupon_dia7', NEW.id, 'cotizacion', NEW.cliente_id,
      'Cupón de cierre — ' || NEW.folio,
      now() + interval '7 days'
    );

  end if;
  return NEW;
end;
$$ language plpgsql;

create trigger trg_alertas_cotizacion
after update on cotizaciones
for each row execute function crear_alertas_cotizacion();

-- ============================================
-- FUNCIÓN: crear alerta post-entrega al marcar pedido
-- ============================================
create or replace function crear_alerta_post_entrega()
returns trigger as $$
begin
  if NEW.estado = 'Entregado' and OLD.estado != 'Entregado' then
    insert into alertas (tipo, referencia_id, referencia_tipo, cliente_id, titulo, fecha_programada)
    values (
      'post_entrega_redes', NEW.id, 'pedido', NEW.cliente_id,
      'Enviar redes sociales — ' || NEW.folio,
      now()
    );
    update pedidos set fecha_entregado = current_date where id = NEW.id;
  end if;
  return NEW;
end;
$$ language plpgsql;

create trigger trg_alerta_post_entrega
after update on pedidos
for each row execute function crear_alerta_post_entrega();

-- ============================================
-- VISTA: alertas pendientes con datos de cliente
-- ============================================
create or replace view v_alertas_pendientes as
select
  a.id,
  a.tipo,
  a.titulo,
  a.mensaje_wa,
  a.fecha_programada,
  a.referencia_id,
  a.referencia_tipo,
  c.nombre as cliente_nombre,
  c.empresa as cliente_empresa,
  c.whatsapp as cliente_whatsapp,
  co.folio as cotizacion_folio,
  co.total as cotizacion_total,
  p.folio as pedido_folio
from alertas a
left join clientes c on c.id = a.cliente_id
left join cotizaciones co on co.id = a.referencia_id and a.referencia_tipo = 'cotizacion'
left join pedidos p on p.id = a.referencia_id and a.referencia_tipo = 'pedido'
where a.completada = false
  and a.fecha_programada <= now()
order by a.fecha_programada asc;

-- ============================================
-- VISTA: estadísticas del mes
-- ============================================
create or replace view v_estadisticas_mes as
select
  count(distinct c.id) filter (where c.created_at >= date_trunc('month', now())) as cotizaciones_mes,
  count(distinct c.id) filter (where c.estado = 'Enviada') as solicitudes_elaboradas,
  count(distinct p.id) filter (where p.estado = 'Entregado' and p.updated_at >= date_trunc('month', now())) as pedidos_entregados,
  count(distinct al.id) filter (where al.completada = false and al.fecha_programada <= now()) as alertas_pendientes,
  coalesce(sum(p.total) filter (where p.estado = 'Entregado' and p.updated_at >= date_trunc('month', now())), 0) as ventas_mes
from cotizaciones c
full outer join pedidos p on true
full outer join alertas al on true;
