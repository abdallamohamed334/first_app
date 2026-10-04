-- Swap listings are contact-first: users reach the owner by phone or WhatsApp.
-- Keep legacy proposal rows for auditability, but disable the old offer workflow.
BEGIN;

DROP POLICY IF EXISTS swap_proposals_proposer_insert ON public.swap_proposals;
DROP POLICY IF EXISTS swap_proposals_involved_read ON public.swap_proposals;

REVOKE ALL ON TABLE public.swap_proposals FROM authenticated;
REVOKE ALL ON TABLE public.swap_proposals FROM anon;
REVOKE ALL ON TABLE public.swap_proposals FROM PUBLIC;

REVOKE ALL ON FUNCTION public.create_swap_proposal(uuid,text,text,text,text[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.update_swap_proposal_status(uuid,text) FROM PUBLIC, anon, authenticated;

COMMIT;
