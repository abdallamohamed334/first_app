-- Internal volunteer IDs must belong to the donation's charity and be active.
-- A null ID remains allowed for the existing external-volunteer flow.

CREATE OR REPLACE FUNCTION public.institution_assign_charity_volunteer(
  p_donation_id uuid,
  p_volunteer_id uuid,
  p_volunteer_name text,
  p_volunteer_phone text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_charity_id uuid;
  v_status text;
begin
  select charity_id, status into v_charity_id, v_status
  from public.institution_charity_donations
  where id = p_donation_id
  for update;

  if v_charity_id is null then raise exception 'التبرع غير موجود'; end if;
  if not exists (
    select 1 from public.charities
    where id = v_charity_id and user_id = auth.uid() and status = 'active'
  ) then raise exception 'غير مسموح للجمعية بتنفيذ العملية'; end if;
  if v_status <> 'accepted' then raise exception 'يجب قبول التبرع أولًا'; end if;
  if nullif(btrim(coalesce(p_volunteer_name, '')), '') is null then raise exception 'اسم المتطوع مطلوب'; end if;
  if nullif(btrim(coalesce(p_volunteer_phone, '')), '') is null then raise exception 'رقم المتطوع مطلوب'; end if;

  if p_volunteer_id is not null and not exists (
    select 1 from public.charity_volunteers
    where id = p_volunteer_id
      and charity_id = v_charity_id
      and status = 'active'
  ) then raise exception 'المتطوع غير تابع للجمعية أو غير نشط'; end if;

  update public.institution_charity_donations
  set volunteer_id = p_volunteer_id,
      volunteer_name = btrim(p_volunteer_name),
      volunteer_phone = btrim(p_volunteer_phone),
      status = 'volunteer_assigned',
      updated_at = now()
  where id = p_donation_id;

  return jsonb_build_object('success', true, 'status', 'volunteer_assigned');
end;
$function$;
