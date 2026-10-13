-- Keep public provider cards in sync with the provider's published contact fields.
-- The public projection already exposes these approved contact columns; this repairs
-- rows created before the projection refresh without exposing internal user data.
UPDATE public.published_service_provider_cards AS card
SET phone = provider.phone,
    whatsapp = provider.whatsapp,
    email = provider.email,
    website = provider.website,
    updated_at = provider.updated_at
FROM public.service_providers AS provider
WHERE card.id = provider.id;
