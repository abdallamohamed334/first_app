-- Applied to Supabase project gsrhoqdtcyfdmvgahqvl.
-- Keep direct table writes closed; update_institution_offer remains the write boundary.

DO $do$
DECLARE
  fn text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO fn
  FROM pg_proc AS p
  JOIN pg_namespace AS n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prokind = 'f'
    AND p.proname = 'update_institution_offer'
  LIMIT 1;

  IF fn IS NOT NULL THEN
    fn := replace(fn, 'AND status = ''active''', 'AND status = ''approved''');
    EXECUTE fn;
  END IF;
END
$do$;
