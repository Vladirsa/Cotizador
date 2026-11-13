-- PDF de cada cotización para la liga del cliente (hetnacnc.com/c/<token>).
-- La app sube el PDF a este bucket PRIVADO, en la carpeta de su taller, y guarda
-- la ruta en cotizaciones.pdf_url ("cotizaciones-pdf/<negocio>/<id>.pdf").
-- La página de la liga (servidor de hetnacnc.com, con la llave de servicio)
-- firma esa ruta por una hora para que el cliente vea y descargue el PDF.
-- Correr una vez en Supabase → SQL Editor.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cotizaciones-pdf', 'cotizaciones-pdf', false, 15728640, array['application/pdf'])
on conflict (id) do nothing;

drop policy if exists "cotizaciones-pdf: el taller sube los suyos" on storage.objects;
create policy "cotizaciones-pdf: el taller sube los suyos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'cotizaciones-pdf' and (storage.foldername(name))[1] = negocio_del_usuario()::text);

drop policy if exists "cotizaciones-pdf: el taller reemplaza los suyos" on storage.objects;
create policy "cotizaciones-pdf: el taller reemplaza los suyos" on storage.objects
  for update to authenticated
  using (bucket_id = 'cotizaciones-pdf' and (storage.foldername(name))[1] = negocio_del_usuario()::text);

drop policy if exists "cotizaciones-pdf: el taller lee los suyos" on storage.objects;
create policy "cotizaciones-pdf: el taller lee los suyos" on storage.objects
  for select to authenticated
  using (bucket_id = 'cotizaciones-pdf' and (storage.foldername(name))[1] = negocio_del_usuario()::text);
