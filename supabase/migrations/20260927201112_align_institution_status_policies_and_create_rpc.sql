-- Applied to Supabase project gsrhoqdtcyfdmvgahqvl.
-- Institution accounts use approved; offer statuses remain unchanged.

ALTER POLICY institutions_public_select
ON public.institutions
USING (status = 'approved');

ALTER POLICY institution_offers_public_select
ON public.institution_offers
USING (
  status = 'active'
  AND expires_at > now()
  AND EXISTS (
    SELECT 1 FROM public.institutions AS i
    WHERE i.id = institution_offers.institution_id
      AND i.status = 'approved'
  )
);

DO $do$
DECLARE
  fn text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO fn
  FROM pg_proc AS p
  JOIN pg_namespace AS n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prokind = 'f'
    AND p.proname = 'create_institution_offer'
  LIMIT 1;

  IF fn IS NOT NULL THEN
    fn := replace(fn, 'i.status = ''active''', 'i.status = ''approved''');
    EXECUTE fn;
  END IF;
END
$do$;
