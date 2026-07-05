-- ============================================================
-- HETNA CNC — Fix completo simulador
-- Tipos de trabajo correctos + Rangos Router 3D reales
-- ============================================================

DO $$
DECLARE
  v_router_id UUID;
BEGIN
  SELECT id INTO v_router_id FROM sim_servicios
  WHERE LOWER(nombre) LIKE '%router%'
    AND negocio_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
  LIMIT 1;

  IF v_router_id IS NULL THEN
    RAISE NOTICE 'Router CNC no encontrado';
    RETURN;
  END IF;

  -- 1. Borrar tipos de trabajo viejos del Router
  DELETE FROM sim_tipos_trabajo WHERE servicio_id = v_router_id;

  -- 2. Insertar tipos correctos con factores reales
  INSERT INTO sim_tipos_trabajo
    (negocio_id, servicio_id, nombre, formula, factor_complejidad,
     necesita_largo, necesita_ancho, necesita_alto, descripcion_formula, activo, orden)
  VALUES
    -- CORTE 2D
    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     'Corte simple', 'por_area', 1.0, true, true, false,
     '$350/m² — Figuras básicas, contornos sencillos', true, 1),

    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     'Corte complejo', 'por_area', 1.0, true, true, false,
     '$450/m² — Celosías, calados, texto calado', true, 2),

    -- GRABADO
    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     'Grabado delineado simple', 'por_area', 0.8, true, true, false,
     '$280/m² — Contorno grabado, trazos básicos', true, 3),

    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     'Grabado delineado complejo', 'por_area', 1.1, true, true, false,
     '$385/m² — Grabado denso, muchos trazos internos', true, 4),

    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     'Grabado 2.5D', 'por_area', 1.4, true, true, true,
     '$490/m² — Relieve ligero, profundidad parcial', true, 5),

    -- 3D
    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     'Relieve 3D', 'por_volumen', 1.0, true, true, true,
     'Precio por tabla de rangos × 1.0', true, 6),

    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     'Relieve Premium', 'por_volumen', 1.5, true, true, true,
     'Precio por tabla de rangos × 1.5 — Detalle fino', true, 7),

    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     'Escultura 3D', 'por_volumen', 1.8, true, true, true,
     'Precio por tabla de rangos × 1.8 — Múltiples pasadas', true, 8),

    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     'Rotativo 4° eje', 'por_volumen', 2.5, true, true, true,
     'Precio por tabla de rangos × 2.5 — Torneado CNC', true, 9);

  -- 3. Borrar rangos viejos
  DELETE FROM sim_rangos WHERE servicio_id = v_router_id;

  -- 4. Insertar rangos CORRECTOS basados en precios reales de HETNA CNC
  -- Volumen en cm³ → precio base de maquila Router 3D
  INSERT INTO sim_rangos
    (negocio_id, servicio_id, indice_desde, indice_hasta, precio, descripcion)
  VALUES
    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     0, 1200, 580, 'Pieza pequeña ej: 20×20×3 cm'),

    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     1201, 3000, 1200, 'Pieza mediana ej: 25×25×5 cm'),

    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     3001, 7000, 2000, 'Pieza grande ej: 40×40×5 cm'),

    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     7001, 20000, 4200, 'Pieza grande ej: 60×45×7 cm'),

    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     20001, 60000, 12000, 'Trabajo grande'),

    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     60001, 150000, 25000, 'Escultura mediana'),

    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     150001, 999999, 45000, 'Escultura grande');

  -- 5. Actualizar tarifas Router 2D
  -- Borrar tarifas viejas confusas
  DELETE FROM sim_tarifas
  WHERE servicio_id = v_router_id
    AND clave NOT IN ('tarifa_m2_normal','tarifa_m2_celosia',
                      'costo_lijado_hora','costo_barnizado','costo_diseno');

  -- Tarifas base para grabado (% de la tarifa normal)
  INSERT INTO sim_tarifas (negocio_id, servicio_id, clave, nombre, valor, unidad)
  VALUES
    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     'tarifa_m2_grabado_simple', 'Grabado delineado simple ($/m²)', 280, '$/m²'),
    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     'tarifa_m2_grabado_complejo', 'Grabado delineado complejo ($/m²)', 385, '$/m²'),
    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', v_router_id,
     'tarifa_m2_grabado_2_5d', 'Grabado 2.5D ($/m²)', 490, '$/m²')
  ON CONFLICT DO NOTHING;

END $$;

NOTIFY pgrst, 'reload schema';

-- Verificar rangos insertados
SELECT indice_desde, indice_hasta, precio, descripcion
FROM sim_rangos r
JOIN sim_servicios s ON s.id = r.servicio_id
WHERE LOWER(s.nombre) LIKE '%router%'
ORDER BY indice_desde;

-- Verificar tipos de trabajo
SELECT nombre, formula, factor_complejidad, descripcion_formula
FROM sim_tipos_trabajo t
JOIN sim_servicios s ON s.id = t.servicio_id
WHERE LOWER(s.nombre) LIKE '%router%'
ORDER BY orden;
