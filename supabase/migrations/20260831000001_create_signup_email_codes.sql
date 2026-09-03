create table public.signup_email_codes (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  email text not null,
  code text not null,
  name text,
  phone text,
  is_used boolean default false,
  expires_at timestamptz not null,
  created_at timestamptz default now()
);

alter table public.signup_email_codes enable row level security;

create policy "Users can read own codes"
  on public.signup_email_codes
  for select
  using (auth.uid() = user_id);

create policy "Users can insert own codes"
  on public.signup_email_codes
  for insert
  with check (auth.uid() = user_id);

create policy "Users can update own codes"
  on public.signup_email_codes
  for update
  using (auth.uid() = user_id);

create index idx_signup_email_codes_user_email
  on public.signup_email_codes (user_id, email, is_used);

create index idx_signup_email_codes_expires_at
  on public.signup_email_codes (expires_at);