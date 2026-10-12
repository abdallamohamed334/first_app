-- Composite indexes for the highest-volume read paths.
BEGIN;

CREATE INDEX IF NOT EXISTS idx_food_offers_status_expiry_created
  ON public.food_offers (status, expiry_time, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_offer_requests_offer_status
  ON public.offer_requests (offer_id, status);

CREATE INDEX IF NOT EXISTS idx_offer_requests_offer_user
  ON public.offer_requests (offer_id, user_id);

CREATE INDEX IF NOT EXISTS idx_offer_requests_restaurant_requested
  ON public.offer_requests (restaurant_id, requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_marketplace_categories_parent_active_sort
  ON public.marketplace_categories (parent_id, is_active, sort_order);

CREATE INDEX IF NOT EXISTS idx_published_provider_category_rating
  ON public.published_service_provider_cards
    (category_id, rating_avg DESC, total_reviews DESC);

COMMIT;
