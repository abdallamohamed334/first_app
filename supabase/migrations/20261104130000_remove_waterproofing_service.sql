BEGIN;

-- Hide the waterproofing category from new provider registrations and service
-- browsing while preserving historical provider/request references.
UPDATE public.service_categories
SET is_active = false,
    updated_at = now()
WHERE slug = 'waterproofing';

NOTIFY pgrst, 'reload schema';
COMMIT;
