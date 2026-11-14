-- Encabezado de la cotización profesional: giro/eslogan, sitio web, contacto
-- comercial con su cargo y prefijo para los números de parte del taller.
-- Correr una vez en Supabase → SQL Editor.
alter table configuracion_empresa add column if not exists eslogan text;
alter table configuracion_empresa add column if not exists sitio_web text;
alter table configuracion_empresa add column if not exists contacto_nombre text;
alter table configuracion_empresa add column if not exists contacto_cargo text;
alter table configuracion_empresa add column if not exists prefijo_parte text;
