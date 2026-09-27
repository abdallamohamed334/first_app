-- Applied to Supabase project gsrhoqdtcyfdmvgahqvl.
-- Replace only institution authorization predicates; offer status values stay active/paused/etc.

DO $do$
DECLARE
  f record;
  fn text;
BEGIN
  FOR f IN
    SELECT p.oid, p.proname
    FROM pg_proc AS p
    JOIN pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'
      AND p.proname IN (
        'cancel_institution_offer',
        'get_all_institution_offers',
        'get_nearby_institution_offers',
        'institution_complete_offer_request',
        'institution_create_normalized_offer',
        'institution_generate_offer_request_pickup_code',
        'institution_list_offer_requests',
        'institution_mark_offer_request_ready',
        'institution_request_offer',
        'institution_update_offer_request',
        'institution_verify_offer_request_pickup_code',
        'toggle_institution_offer_status',
        'update_institution_offer'
      )
      AND pg_get_functiondef(p.oid) ILIKE '%status = ''active''%'
  LOOP
    fn := pg_get_functiondef(f.oid);
    fn := replace(fn, 'i.status = ''active''', 'i.status = ''approved''');
    fn := replace(fn, 'AND status = ''active''', 'AND status = ''approved''');
    fn := replace(fn, 'and status = ''active''', 'and status = ''approved''');
    EXECUTE fn;
  END LOOP;
END
$do$;
