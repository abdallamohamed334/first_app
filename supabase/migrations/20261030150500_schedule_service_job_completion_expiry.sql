BEGIN;
CREATE EXTENSION IF NOT EXISTS pg_cron;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'expire-service-job-completions') THEN
    PERFORM cron.schedule(
      'expire-service-job-completions',
      '*/15 * * * *',
      'SELECT public.expire_service_job_completions();'
    );
  END IF;
END;
$$;
COMMIT;
