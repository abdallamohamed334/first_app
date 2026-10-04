BEGIN;

ALTER TABLE public.users REPLICA IDENTITY FULL;
ALTER TABLE public.account_cases REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'users'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'account_cases'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.account_cases;
  END IF;
END;
$$;

COMMIT;
