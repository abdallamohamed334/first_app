-- Atomic server-side OTP rate limiting.
-- The key is a SHA-256 digest of phone + request IP; raw PII is not stored here.
BEGIN;

CREATE TABLE IF NOT EXISTS public.otp_rate_limits (
  rate_key text PRIMARY KEY,
  window_started_at timestamptz NOT NULL DEFAULT now(),
  request_count integer NOT NULL DEFAULT 0,
  CONSTRAINT otp_rate_limits_count_nonnegative CHECK (request_count >= 0)
);

ALTER TABLE public.otp_rate_limits ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS otp_rate_limits_window_idx
  ON public.otp_rate_limits (window_started_at);

CREATE OR REPLACE FUNCTION public.consume_otp_rate_limit(
  p_key text,
  p_window_seconds integer DEFAULT 300,
  p_max_requests integer DEFAULT 5
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.otp_rate_limits%ROWTYPE;
  v_now timestamptz := now();
BEGIN
  IF p_key IS NULL OR length(trim(p_key)) < 32
     OR p_window_seconds < 1 OR p_window_seconds > 3600
     OR p_max_requests < 1 OR p_max_requests > 100 THEN
    RETURN false;
  END IF;

  DELETE FROM public.otp_rate_limits
  WHERE window_started_at < v_now - interval '2 days';

  INSERT INTO public.otp_rate_limits(rate_key, window_started_at, request_count)
  VALUES (p_key, v_now, 1)
  ON CONFLICT (rate_key) DO NOTHING;
  IF FOUND THEN
    RETURN true;
  END IF;

  SELECT * INTO v_row
  FROM public.otp_rate_limits
  WHERE rate_key = p_key
  FOR UPDATE;

  IF NOT FOUND OR v_now >= v_row.window_started_at + make_interval(secs => p_window_seconds) THEN
    UPDATE public.otp_rate_limits
    SET window_started_at = v_now, request_count = 1
    WHERE rate_key = p_key;
    RETURN true;
  END IF;

  IF v_row.request_count >= p_max_requests THEN
    RETURN false;
  END IF;

  UPDATE public.otp_rate_limits
  SET request_count = request_count + 1
  WHERE rate_key = p_key;
  RETURN true;
END;
$$;

REVOKE ALL ON TABLE public.otp_rate_limits FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.consume_otp_rate_limit(text, integer, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_otp_rate_limit(text, integer, integer)
  TO service_role;

COMMIT;
