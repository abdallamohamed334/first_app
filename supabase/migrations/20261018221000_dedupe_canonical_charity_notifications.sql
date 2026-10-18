WITH ranked AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY reference_id, user_id, title, body
           ORDER BY created_at DESC, id DESC
         ) AS rn
  FROM public.notifications
  WHERE reference_type = 'charity_donation'
    AND reference_id IS NOT NULL
)
DELETE FROM public.notifications n
USING ranked r
WHERE n.id = r.id AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS notifications_charity_donation_dedupe_idx
  ON public.notifications (reference_id, user_id, title, body)
  WHERE reference_type = 'charity_donation' AND reference_id IS NOT NULL;
