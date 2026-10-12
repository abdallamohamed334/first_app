-- Harden food-offer request integrity and bound the user's request list.
BEGIN;

CREATE OR REPLACE FUNCTION public.guard_offer_request_integrity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF auth.uid() IS NOT NULL AND NEW.user_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'لا يمكنك إنشاء طلب باسم مستخدم آخر';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM public.food_offers f
      JOIN public.businesses b ON b.id = f.business_id
      JOIN public.restaurants r ON r.user_id = b.user_id
      WHERE f.id = NEW.offer_id
        AND r.id = NEW.restaurant_id
    ) THEN
      RAISE EXCEPTION 'المطعم غير مرتبط بصاحب العرض';
    END IF;

    IF auth.uid() IS NOT NULL THEN
      NEW.user_id := auth.uid();
      NEW.status := 'pending';
      NEW.quantity := GREATEST(COALESCE(NEW.quantity, 1), 1);
      NEW.requested_at := COALESCE(NEW.requested_at, now());
      NEW.updated_at := now();
    END IF;
  ELSE
    IF NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.offer_id IS DISTINCT FROM OLD.offer_id
       OR NEW.restaurant_id IS DISTINCT FROM OLD.restaurant_id
       OR NEW.quantity IS DISTINCT FROM OLD.quantity
       OR NEW.requested_at IS DISTINCT FROM OLD.requested_at THEN
      RAISE EXCEPTION 'لا يمكن تغيير بيانات الطلب الأساسية';
    END IF;

    IF NEW.status = 'accepted' AND OLD.status <> 'accepted' THEN
      NEW.accepted_at := COALESCE(NEW.accepted_at, now());
    END IF;
    IF NEW.status IN ('completed', 'redeemed') AND OLD.status NOT IN ('completed', 'redeemed') THEN
      NEW.completed_at := COALESCE(NEW.completed_at, now());
    END IF;
    IF NEW.status IN ('cancelled', 'rejected', 'expired')
       AND NULLIF(btrim(NEW.cancellation_reason), '') IS NULL THEN
      NEW.cancellation_reason := CASE NEW.status
        WHEN 'cancelled' THEN 'تم إلغاء الطلب'
        WHEN 'rejected' THEN 'تم رفض الطلب من صاحب العرض'
        ELSE 'انتهت صلاحية الطلب'
      END;
    END IF;
    NEW.updated_at := now();
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS offer_requests_guard_integrity ON public.offer_requests;
CREATE TRIGGER offer_requests_guard_integrity
BEFORE INSERT OR UPDATE ON public.offer_requests
FOR EACH ROW EXECUTE FUNCTION public.guard_offer_request_integrity();

CREATE OR REPLACE FUNCTION public.user_list_my_food_requests()
RETURNS TABLE (
  id uuid,
  offer_id uuid,
  offer_title text,
  offer_image text,
  offer_images text[],
  offer_food_type text,
  offer_sale_price numeric,
  offer_original_price numeric,
  offer_pickup_location text,
  offer_expiry_time timestamptz,
  business_id uuid,
  business_name text,
  business_logo text,
  business_type text,
  business_address text,
  business_phone text,
  status text,
  quantity integer,
  requested_at timestamptz,
  updated_at timestamptz,
  accepted_at timestamptz,
  completed_at timestamptz,
  notes text,
  pickup_token text,
  pickup_token_expires_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;

  RETURN QUERY
  SELECT r.id, r.offer_id, f.title, f.image, f.images, f.food_type,
    f.sale_price, f.original_price, f.pickup_location, f.expiry_time,
    b.id, b.name, b.logo, b.business_type, b.address, b.phone,
    r.status, r.quantity, r.requested_at, r.updated_at, r.accepted_at,
    r.completed_at, r.notes, r.pickup_token, r.pickup_token_expires_at
  FROM public.offer_requests r
  JOIN public.food_offers f ON f.id = r.offer_id
  LEFT JOIN public.businesses b ON b.id = f.business_id
  WHERE r.user_id = auth.uid()
  ORDER BY r.requested_at DESC NULLS LAST
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.user_list_my_food_requests() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.user_list_my_food_requests() TO authenticated;

CREATE INDEX IF NOT EXISTS idx_offer_requests_user_requested_desc
  ON public.offer_requests (user_id, requested_at DESC);

COMMIT;
