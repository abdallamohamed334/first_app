-- The charity login RPC is intentionally callable before authentication.
-- It validates the supplied email and access code inside a SECURITY DEFINER
-- function, applies the existing lockout counter, and returns only the
-- minimum session lookup fields needed by the client.
REVOKE ALL ON FUNCTION public.check_charity_fixed_code_by_email(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_charity_fixed_code_by_email(text, text) TO anon, authenticated;
