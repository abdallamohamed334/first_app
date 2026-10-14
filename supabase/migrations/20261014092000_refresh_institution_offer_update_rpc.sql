BEGIN;

-- Keep the institution offer edit RPC visible to authenticated clients after
-- function replacement/signature changes, without opening direct table writes.
GRANT EXECUTE ON FUNCTION public.update_institution_offer(
  uuid,
  text,
  text,
  text,
  integer,
  integer,
  numeric,
  numeric,
  text[],
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  boolean,
  boolean,
  text,
  boolean,
  text,
  text
) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.update_institution_offer(
  uuid,
  text,
  text,
  text,
  integer,
  integer,
  numeric,
  numeric,
  text[],
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  boolean,
  boolean,
  text,
  boolean,
  text,
  text
) FROM anon;

NOTIFY pgrst, 'reload schema';

COMMIT;
