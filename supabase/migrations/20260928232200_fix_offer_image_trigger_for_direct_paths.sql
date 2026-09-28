-- community-offers is shared by food offers and direct charity donations.
-- The legacy trigger must ignore direct/<user>/<charity>/<file> paths before
-- attempting to cast the first path segment to a food-offer UUID.
CREATE OR REPLACE FUNCTION public.auto_link_offer_images()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_business_id text;
  v_offer_id uuid;
BEGIN
  IF NEW.bucket_id <> 'community-offers'
     OR NEW.name IS NULL
     OR NEW.name !~ '^[0-9a-fA-F-]{36}/[^/]+$' THEN
    RETURN NEW;
  END IF;

  v_business_id := split_part(NEW.name, '/', 1);

  SELECT id INTO v_offer_id
  FROM public.food_offers
  WHERE business_id = v_business_id::uuid
    AND created_at > now() - interval '1 minute'
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_offer_id IS NOT NULL THEN
    UPDATE public.food_offers
    SET image = NEW.name,
        images = CASE
          WHEN images IS NULL THEN ARRAY[NEW.name]
          WHEN NOT (NEW.name = ANY(images)) THEN array_append(images, NEW.name)
          ELSE images
        END,
        updated_at = now()
    WHERE id = v_offer_id;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN NEW;
END;
$$;
