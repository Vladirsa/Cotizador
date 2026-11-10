-- ════════════════════════════════════════════════════════════════════
-- HETNA Cotizador — Alta guiada y checklist de arranque        10 nov 2026
-- Correr en Supabase → SQL Editor del proyecto del Cotizador.
-- Se puede correr dos veces sin problema. No borra nada.
--
-- Objetivo: que un taller nuevo haga su primera cotización el mismo día.
--   · arranque_visto: ya pasó por la alta guiada (o la saltó).
--   · arranque_bonus: ya se le dieron los 15 días extra por completar los
--     5 pasos (máquina, material, cotización, orden QR, cliente).
-- ════════════════════════════════════════════════════════════════════
begin;

alter table negocios add column if not exists arranque_visto timestamptz;
alter table negocios add column if not exists arranque_bonus timestamptz;

-- La app marca que ya mostró la alta guiada (aunque la haya saltado)
create or replace function marcar_arranque_visto() returns void
language sql security definer set search_path = public as $$
  update negocios set arranque_visto = now()
  where id = negocio_del_usuario() and arranque_visto is null;
$$;
grant execute on function marcar_arranque_visto() to authenticated;

-- El trigger que protege plan/trial_hasta deja pasar SOLO el bono de
-- arranque, que se otorga desde completar_arranque() (abajo).
create or replace function proteger_plan_negocio() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_setting('hetna.bono_arranque', true), '') = '1' then
    return new;
  end if;
  if coalesce(auth.role(), '') in ('authenticated', 'anon') and (
       new.plan        is distinct from old.plan
    or new.trial_hasta is distinct from old.trial_hasta
    or new.activo      is distinct from old.activo
    or new.slug        is distinct from old.slug) then
    raise exception 'El plan del taller solo se cambia al pagar la suscripción';
  end if;
  return new;
end $$;

-- Revisa los 5 pasos y, si están todos, da 15 días más de prueba (una vez).
-- Devuelve: { pasos: {maquina, material, cotizacion, orden, cliente},
--             completo, bonus_dado, bonus_nuevo, trial_hasta }
create or replace function completar_arranque() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_neg uuid := negocio_del_usuario();
  v_maq boolean; v_mat boolean; v_cot boolean; v_ord boolean; v_cli boolean;
  v_completo boolean; v_nuevo boolean := false;
  v_n negocios%rowtype;
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
      -- Sólo alarga la prueba a quien está en prueba; a los de pago no les cambia nada
      trial_hasta = case when plan in ('trial', 'prueba')
                         then greatest(coalesce(trial_hasta, now()), now()) + interval '15 days'
                         else trial_hasta end
    where id = v_neg;
    perform set_config('hetna.bono_arranque', '', true);
    v_nuevo := true;
    select * into v_n from negocios where id = v_neg;
  end if;

  return jsonb_build_object(
    'pasos', jsonb_build_object('maquina', v_maq, 'material', v_mat, 'cotizacion', v_cot, 'orden', v_ord, 'cliente', v_cli),
    'completo', v_completo,
    'bonus_dado', v_n.arranque_bonus is not null,
    'bonus_nuevo', v_nuevo,
    'trial_hasta', v_n.trial_hasta);
end $$;
grant execute on function completar_arranque() to authenticated;

commit;
