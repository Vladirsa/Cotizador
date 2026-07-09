| proname                   | prosrc                                                                                                                                                                                                                                                                                                                |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| validar_codigo_invitacion | 
BEGIN
  IF EXISTS (
    SELECT 1 FROM codigos_invitacion
    WHERE codigo = UPPER(p_codigo) AND activo = true AND usado = false
  ) THEN
    RETURN json_build_object('valido', true);
  ELSE
    RETURN json_build_object('valido', false, 'mensaje', 'Código inválido o ya utilizado');
  END IF;
END;
 |
