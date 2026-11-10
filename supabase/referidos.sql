-- ════════════════════════════════════════════════════════════════════
-- HETNA Cotizador — Referidos y códigos de distribuidor        10 nov 2026
-- Correr en Supabase → SQL Editor del proyecto del Cotizador, DESPUÉS de
-- arranque.sql. Se puede correr dos veces sin problema. No borra nada.
--
-- Cómo funciona:
--   · Cada taller tiene su código (6 letras) y su liga
--       hetnacnc.com/cotizador/?ref=CODIGO
--   · El taller invitado aplica el código (solo, al entrar por la liga, o
--     escribiéndolo). Vale durante sus primeros 30 días y una sola vez.
--   · Cuando el invitado COMPLETA su arranque (los 5 pasos del checklist),
--     los dos ganan 1 mes:
--       – en prueba  → 30 días más de prueba, automático;
--       – ya pagando → queda un "mes a favor" que HETNA aplica a mano
--         (se ve en negocios.meses_a_favor).
--     Tope: 12 meses ganados por taller que invita.
--   · Códigos de distribuidor (tabla codigos_promo): regalan N días de
--     prueba al taller nuevo en cuanto los aplica (ej. 90 días con la
--     compra de una máquina).
-- ════════════════════════════════════════════════════════════════════
begin;

alter table negocios add column if not exists codigo_referido text unique;
alter table negocios add column if not exists referido_por uuid references negocios(id) on delete set null;
alter table negocios add column if not exists referido_codigo text;       -- código que usó (de taller o de distribuidor)
alter table negocios add column if not exists referido_premio timestamptz; -- cuándo se pagó el premio por este invitado
alter table negocios add column if not exists meses_a_favor int not null default 0;
create index if not exists idx_negocios_referido_por on negocios(referido_por);

-- Códigos de distribuidores / promociones. Sólo HETNA los crea (SQL Editor
-- o panel); los talleres no pueden leer la tabla.
create table if not exists codigos_promo (
  codigo text primary key,
  nombre text not null,               -- "CNC del Bajío", "Expo Guadalajara 2027"
  dias_regalo int not null default 90,
  activo boolean not null default true,
  usos int not null default 0,
  max_usos int,                       -- null = sin tope
  vence date,
  created_at timestamptz default now()
);
alter table codigos_promo enable row level security;
-- (sin políticas: nadie con la llave pública puede leer ni escribir)

-- El taller no puede regalarse meses ni cambiar quién lo invitó escribiendo
-- directo en la tabla: esos campos sólo los mueven las funciones de abajo.
create or replace function proteger_plan_negocio() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_setting('hetna.bono_arranque', true), '') = '1' then
    return new;
  end if;
  if coalesce(auth.role(), '') in ('authenticated', 'anon') and (
       new.plan             is distinct from old.plan
    or new.trial_hasta      is distinct from old.trial_hasta
    or new.activo           is distinct from old.activo
    or new.slug             is distinct from old.slug
    or new.meses_a_favor    is distinct from old.meses_a_favor
    or new.referido_por     is distinct from old.referido_por
    or new.referido_codigo  is distinct from old.referido_codigo
    or new.referido_premio  is distinct from old.referido_premio
    or new.codigo_referido  is distinct from old.codigo_referido
    or new.arranque_bonus   is distinct from old.arranque_bonus) then
    raise exception 'Ese dato del taller no se puede cambiar desde la app';
  end if;
  return new;
end $$;

-- Código propio del taller; se genera la primera vez que se pide.
create or replace function mi_codigo_referido() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_neg uuid := negocio_del_usuario();
  v_cod text;
  v_n negocios%rowtype;
  i int := 0;
begin
  if v_neg is null then return jsonb_build_object('error', 'sin negocio'); end if;
  select * into v_n from negocios where id = v_neg;
  if v_n.codigo_referido is null then
    loop
      -- 6 caracteres sin letras que se confunden (0/O, 1/I)
      select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1), '')
        into v_cod from generate_series(1, 6);
      begin
        perform set_config('hetna.bono_arranque', '1', true);
        update negocios set codigo_referido = v_cod where id = v_neg;
        perform set_config('hetna.bono_arranque', '', true);
        exit;
      exception when unique_violation then
        i := i + 1;
        if i > 8 then return jsonb_build_object('error', 'no se pudo generar el código'); end if;
      end;
    end loop;
    select * into v_n from negocios where id = v_neg;
  end if;
  return jsonb_build_object(
    'codigo', v_n.codigo_referido,
    'invitados', (select count(*) from negocios where referido_por = v_neg),
    'completaron', (select count(*) from negocios where referido_por = v_neg and referido_premio is not null),
    'meses_a_favor', v_n.meses_a_favor,
    'ya_referido', v_n.referido_codigo is not null,
    'puede_aplicar', v_n.referido_codigo is null and v_n.created_at > now() - interval '30 days');
end $$;
grant execute on function mi_codigo_referido() to authenticated;

-- El taller nuevo aplica un código (de otro taller o de distribuidor).
create or replace function aplicar_referido(p_codigo text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_neg uuid := negocio_del_usuario();
  v_cod text := upper(trim(coalesce(p_codigo, '')));
  v_n negocios%rowtype;
  v_ref negocios%rowtype;
  v_promo codigos_promo%rowtype;
begin
  if v_neg is null then return jsonb_build_object('ok', false, 'mensaje', 'sin negocio'); end if;
  if length(v_cod) < 4 or length(v_cod) > 24 then return jsonb_build_object('ok', false, 'mensaje', 'Código inválido'); end if;
  select * into v_n from negocios where id = v_neg;
  if v_n.referido_codigo is not null then
    return jsonb_build_object('ok', false, 'mensaje', 'Tu taller ya usó un código de invitación');
  end if;
  if v_n.created_at < now() - interval '30 days' then
    return jsonb_build_object('ok', false, 'mensaje', 'Los códigos de invitación sólo valen en los primeros 30 días del taller');
  end if;

  -- 1) ¿Es el código de otro taller?
  select * into v_ref from negocios where codigo_referido = v_cod;
  if found then
    if v_ref.id = v_neg then return jsonb_build_object('ok', false, 'mensaje', 'No puedes usar tu propio código'); end if;
    perform set_config('hetna.bono_arranque', '1', true);
    update negocios set referido_por = v_ref.id, referido_codigo = v_cod where id = v_neg;
    perform set_config('hetna.bono_arranque', '', true);
    return jsonb_build_object('ok', true, 'tipo', 'taller', 'de', v_ref.nombre,
      'mensaje', 'Te invitó ' || v_ref.nombre || '. Completa tu arranque y los dos ganan 1 mes.');
  end if;

  -- 2) ¿Es un código de distribuidor?
  select * into v_promo from codigos_promo where codigo = v_cod;
  if found then
    if not v_promo.activo or (v_promo.vence is not null and v_promo.vence < current_date)
       or (v_promo.max_usos is not null and v_promo.usos >= v_promo.max_usos) then
      return jsonb_build_object('ok', false, 'mensaje', 'Ese código ya no está vigente');
    end if;
    perform set_config('hetna.bono_arranque', '1', true);
    update negocios set
      referido_codigo = v_cod,
      trial_hasta = case when plan in ('trial', 'prueba')
                         then greatest(coalesce(trial_hasta, now()), now()) + make_interval(days => v_promo.dias_regalo)
                         else trial_hasta end,
      meses_a_favor = case when plan in ('trial', 'prueba') then meses_a_favor
                           else meses_a_favor + greatest(1, v_promo.dias_regalo / 30) end
    where id = v_neg;
    perform set_config('hetna.bono_arranque', '', true);
    update codigos_promo set usos = usos + 1 where codigo = v_cod;
    return jsonb_build_object('ok', true, 'tipo', 'distribuidor', 'de', v_promo.nombre, 'dias', v_promo.dias_regalo,
      'mensaje', 'Código de ' || v_promo.nombre || ': ' || v_promo.dias_regalo || ' días de HETNA Taller.');
  end if;

  return jsonb_build_object('ok', false, 'mensaje', 'No encontramos ese código');
end $$;
grant execute on function aplicar_referido(text) to authenticated;

-- Premio: 1 mes a un taller (prueba → 30 días más; pagando → mes a favor).
create or replace function _premiar_mes(p_neg uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('hetna.bono_arranque', '1', true);
  update negocios set
    trial_hasta = case when plan in ('trial', 'prueba')
                       then greatest(coalesce(trial_hasta, now()), now()) + interval '30 days'
                       else trial_hasta end,
    meses_a_favor = case when plan in ('trial', 'prueba') then meses_a_favor else meses_a_favor + 1 end
  where id = p_neg;
  perform set_config('hetna.bono_arranque', '', true);
end $$;
revoke all on function _premiar_mes(uuid) from public, anon, authenticated;

-- completar_arranque(): igual que en arranque.sql, y además paga el premio
-- de referidos la primera vez que el invitado completa los 5 pasos.
create or replace function completar_arranque() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_neg uuid := negocio_del_usuario();
  v_maq boolean; v_mat boolean; v_cot boolean; v_ord boolean; v_cli boolean;
  v_completo boolean; v_nuevo boolean := false; v_ref_nuevo boolean := false;
  v_n negocios%rowtype;
  v_ganados int;
begin
  if v_neg is null then return jsonb_build_object('error', 'sin negocio'); end if;
  select exists(select 1 from maquinaria where negocio_id = v_neg and activo) into v_maq;
  select exists(select 1 from inventario_bodega where negocio_id = v_neg and activo) into v_mat;
  select exists(select 1 from cotizaciones where negocio_id = v_neg) into v_cot;
  select exists(select 1 from pedidos where negocio_id = v_neg) into v_ord;
  select exists(select 1 from clientes where negocio_id = v_neg) into v_cli;
  v_completo := v_maq and v_mat and v_cot and v_ord and v_cli;

  select * into v_n from negocios where id = v_neg;
  if v_completo and v_n.arranque_bonus is null then
    perform set_config('hetna.bono_arranque', '1', true);
    update negocios set
      arranque_bonus = now(),
      trial_hasta = case when plan in ('trial', 'prueba')
                         then greatest(coalesce(trial_hasta, now()), now()) + interval '15 days'
                         else trial_hasta end
    where id = v_neg;
    perform set_config('hetna.bono_arranque', '', true);
    v_nuevo := true;
  end if;

  -- Referido: el invitado terminó su arranque → 1 mes para cada uno (una vez)
  if v_completo and v_n.referido_por is not null and v_n.referido_premio is null then
    perform set_config('hetna.bono_arranque', '1', true);
    update negocios set referido_premio = now() where id = v_neg and referido_premio is null;
    if found then
      perform _premiar_mes(v_neg);
      select count(*) into v_ganados from negocios where referido_por = v_n.referido_por and referido_premio is not null;
      if v_ganados <= 12 then perform _premiar_mes(v_n.referido_por); end if;
      v_ref_nuevo := true;
    end if;
  end if;

  select * into v_n from negocios where id = v_neg;
  return jsonb_build_object(
    'pasos', jsonb_build_object('maquina', v_maq, 'material', v_mat, 'cotizacion', v_cot, 'orden', v_ord, 'cliente', v_cli),
    'completo', v_completo,
    'bonus_dado', v_n.arranque_bonus is not null,
    'bonus_nuevo', v_nuevo,
    'referido_nuevo', v_ref_nuevo,
    'trial_hasta', v_n.trial_hasta);
end $$;
grant execute on function completar_arranque() to authenticated;

commit;

-- ── Para crear un código de distribuidor (ejemplo; cambia nombre y código) ──
-- insert into codigos_promo (codigo, nombre, dias_regalo) values ('BAJIO90', 'CNC del Bajío', 90);
