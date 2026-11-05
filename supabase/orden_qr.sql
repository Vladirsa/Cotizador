-- Orden de trabajo con QR (app del Cotizador)
-- Guarda quién movió cada etapa del pedido al escanear el QR de la hoja de
-- orden: el operador que terminó el maquinado, quién capturó la guía, etc.
-- Se corre una vez en el SQL Editor de Supabase (proyecto de la app). Si no
-- se corre, la app sigue funcionando pero el historial no dice quién fue.

alter table public.pedido_avances add column if not exists hecho_por uuid;
alter table public.pedido_avances add column if not exists hecho_por_nombre text;
alter table public.pedido_avances add column if not exists rol text;

create index if not exists idx_pedido_avances_pedido on public.pedido_avances (pedido_id, created_at desc);
