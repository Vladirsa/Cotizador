-- ════════════════════════════════════════════════════════════════════
-- HETNA Cotizador — Talleres de Colombia, Perú y Chile        11 nov 2026
-- Correr en Supabase → SQL Editor del proyecto del Cotizador.
-- Se puede correr dos veces sin problema. No borra nada: los talleres que
-- ya existen se quedan como están (México, MXN, 16 %).
--
-- Qué hace:
--   · configuracion_empresa.pais_factura acepta MX, US, CO, PE, CL.
--   · configuracion_empresa.moneda acepta MXN, USD, COP, PEN, CLP.
-- ════════════════════════════════════════════════════════════════════
begin;

alter table public.configuracion_empresa
  add column if not exists pais_factura text not null default 'MX';
alter table public.configuracion_empresa
  add column if not exists moneda text not null default 'MXN';
alter table public.configuracion_empresa
  add column if not exists impuesto_pct numeric(5,2) not null default 16;

-- Lo que esté escrito raro queda en México / pesos (no debería haber nada)
update public.configuracion_empresa set pais_factura = 'MX'
  where pais_factura is null or upper(pais_factura) not in ('MX', 'US', 'CO', 'PE', 'CL');
update public.configuracion_empresa set pais_factura = upper(pais_factura)
  where pais_factura <> upper(pais_factura);

alter table public.configuracion_empresa drop constraint if exists configuracion_empresa_pais_factura_check;
alter table public.configuracion_empresa drop constraint if exists configuracion_empresa_pais_chk;
alter table public.configuracion_empresa
  add constraint configuracion_empresa_pais_chk check (pais_factura in ('MX', 'US', 'CO', 'PE', 'CL'));

alter table public.configuracion_empresa drop constraint if exists configuracion_empresa_moneda_chk;
alter table public.configuracion_empresa
  add constraint configuracion_empresa_moneda_chk check (moneda in ('MXN', 'USD', 'COP', 'PEN', 'CLP'));

commit;

-- Revisión: cuántos talleres hay por país y moneda
select pais_factura, moneda, count(*) from public.configuracion_empresa group by 1, 2 order by 3 desc;
