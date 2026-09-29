-- Public reviews need display data only; never expose internal user/request IDs.
BEGIN;

DROP VIEW IF EXISTS public.published_service_reviews;
CREATE VIEW public.published_service_reviews
WITH (security_invoker = false)
AS
SELECT
  r.id,
  NULL::uuid AS request_id,
  NULL::uuid AS from_user_id,
  r.to_provider_id,
  r.rating,
  r.comment,
  r.images,
  r.tags,
  r.is_anonymous,
  r.created_at,
  CASE WHEN r.is_anonymous THEN NULL::text ELSE u.name END AS user_name,
  CASE WHEN r.is_anonymous THEN NULL::text ELSE u.avatar_url END AS user_avatar
FROM public.service_reviews AS r
LEFT JOIN public.users AS u ON u.id = r.from_user_id;

GRANT SELECT ON public.published_service_reviews TO anon, authenticated;
COMMIT;
