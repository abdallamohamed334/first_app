create or replace function public.verify_signup_email_code(
  p_user_id text,
  p_email text,
  p_code text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code_record public.signup_email_codes%rowtype;
begin
  -- البحث عن الكود
  select * into v_code_record
  from public.signup_email_codes
  where user_id = p_user_id
    and email = lower(trim(p_email))
    and code = trim(p_code)
    and is_used = false
    and expires_at > now()
  order by created_at desc
  limit 1;

  if v_code_record.id is null then
    return json_build_object(
      'success', false,
      'error', 'كود التحقق غير صحيح أو منتهي'
    );
  end if;

  -- علامة الكود كـ مستخدم
  update public.signup_email_codes
  set is_used = true, updated_at = now()
  where id = v_code_record.id;

  -- تحديث حالة المستخدم في auth
  update auth.users
  set email_confirmed_at = now()
  where id = p_user_id;

  return json_build_object(
    'success', true
  );
end;
$$;