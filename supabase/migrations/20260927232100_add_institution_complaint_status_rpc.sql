-- Let only the owning institution resolve/reject a product complaint.
-- No general UPDATE policy is added; the RPC changes only status and updated_at.

CREATE OR REPLACE FUNCTION public.institution_update_product_complaint_status(
  p_complaint_id uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_updated_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_status NOT IN ('resolved', 'rejected') THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Invalid complaint status'
    );
  END IF;

  UPDATE public.product_complaints AS pc
  SET
    status = p_status,
    updated_at = now()
  WHERE pc.id = p_complaint_id
    AND EXISTS (
      SELECT 1
      FROM public.institutions AS i
      WHERE i.id = pc.institution_id
        AND i.user_id = auth.uid()
    )
  RETURNING pc.id INTO v_updated_id;

  IF v_updated_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Complaint not found or not owned by the current institution'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'complaint_id', v_updated_id,
    'status', p_status
  );
END;
$function$;
