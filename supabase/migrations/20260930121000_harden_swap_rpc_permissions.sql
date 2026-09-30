BEGIN;
REVOKE EXECUTE ON FUNCTION public.create_swap_proposal(uuid, text, text, text, text[]) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_swap_proposal_status(uuid, text) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_swap_proposal(uuid, text, text, text, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_swap_proposal_status(uuid, text) TO authenticated;
COMMIT;
