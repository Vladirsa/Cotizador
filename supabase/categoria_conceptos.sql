-- Categoría de cada concepto de la cotización profesional (fabricación,
-- material, programación, diseño, acabados, inspección, empaque, transporte,
-- otros). El PDF agrupa los conceptos por categoría con su subtotal.
-- Si no se corre, la app sigue funcionando: adivina la categoría por el nombre.
alter table public.cotizacion_items add column if not exists categoria text;
