-- Comprobación de integridad de una base restaurada (T139). Falla con un mensaje que nombra lo que falta.
DO $$
DECLARE
  expected text[] := ARRAY[
    'users', 'businesses', 'memberships', 'invitations', 'sessions', 'clients', 'products',
    'fiados', 'fiado_items', 'payments', 'change_log', 'processed_ops', 'admin_audit'];
  missing text;
  orphans bigint;
BEGIN
  SELECT string_agg(t, ', ') INTO missing
  FROM unnest(expected) AS t
  WHERE to_regclass('public.' || t) IS NULL;
  IF missing IS NOT NULL THEN
    RAISE EXCEPTION 'Faltan tablas en la copia: %', missing;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM "__EFMigrationsHistory") THEN
    RAISE EXCEPTION 'La copia no trae el historial de migraciones';
  END IF;

  SELECT count(*) INTO orphans
  FROM memberships m
  LEFT JOIN users u ON u.id = m.user_id
  LEFT JOIN businesses b ON b.id = m.business_id
  WHERE u.id IS NULL OR b.id IS NULL;
  IF orphans > 0 THEN
    RAISE EXCEPTION 'Hay % pertenencia(s) sin usuario o sin negocio', orphans;
  END IF;
END $$;

SELECT 'usuarios|' || count(*) FROM users;
SELECT 'negocios|' || count(*) FROM businesses;
SELECT 'pertenencias|' || count(*) FROM memberships;
SELECT 'clientes|' || count(*) FROM clients;
SELECT 'fiados|' || count(*) FROM fiados;
SELECT 'abonos|' || count(*) FROM payments;
