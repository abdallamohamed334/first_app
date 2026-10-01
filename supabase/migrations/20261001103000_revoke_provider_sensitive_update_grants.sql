-- Defense-in-depth follow-up for the provider privilege escalation fix.
-- The previous allow-list must not permit clients to alter KYC fields or the
-- moderation lock, even if that migration has already been applied.
BEGIN;

REVOKE UPDATE (
  id_card_front_url,
  id_card_back_url,
  profile_locked_at
) ON TABLE public.service_providers FROM anon, authenticated;

COMMIT;
