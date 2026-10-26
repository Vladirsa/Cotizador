-- HETNA Cotizador — moneda e impuesto por taller (Configuración → Idioma, moneda e impuestos)
-- Se puede correr más de una vez. Solo agrega columnas con valor por defecto:
-- los talleres existentes quedan en MXN con 16 % de IVA. RLS no cambia.
alter table public.configuracion_empresa
  add column if not exists moneda text not null default 'MXN',
  add column if not exists impuesto_pct numeric(5,2) not null default 16;

alter table public.configuracion_empresa drop constraint if exists configuracion_empresa_moneda_chk;
alter table public.configuracion_empresa
  add constraint configuracion_empresa_moneda_chk check (moneda in ('MXN', 'USD'));

alter table public.configuracion_empresa drop constraint if exists configuracion_empresa_impuesto_chk;
alter table public.configuracion_empresa
  add constraint configuracion_empresa_impuesto_chk check (impuesto_pct >= 0 and impuesto_pct <= 100);

select column_name, data_type, column_default
from information_schema.columns
where table_name = 'configuracion_empresa' and column_name in ('moneda', 'impuesto_pct');
