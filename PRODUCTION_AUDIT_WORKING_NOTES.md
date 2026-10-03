# Production audit working notes

## Scope verified
- Repository: `abdallamohamed334/first_app`, branch `main`, HEAD `d60de14`.
- Flutter app: 364 Dart files, 62 local Supabase SQL/TypeScript files.
- Linked Supabase project: `gsrhoqdtcyfdmvgahqvl`, active/healthy, eu-west-1, PostgreSQL 17.6.1.
- Local sandbox initially had no Flutter/Dart SDK; installation is running separately.

## Live Supabase evidence (2026-10-02)
- Security Advisor:
  - 14 tables have RLS enabled with no policies (includes `admin_audit_logs`, `otp_codes`, `pending_signup_profiles`, `rewards`, `services`, `volunteer_profiles`, and others). This may intentionally deny all access, but must be confirmed against intended backend paths.
  - `published_service_reviews` and `published_service_providers` are reported as SECURITY DEFINER views.
  - `public.spatial_ref_sys` has RLS disabled (PostGIS-owned/system object; likely accepted platform limitation, not app data).
  - PostGIS is installed in `public` schema.
  - `check_charity_fixed_code_by_email` and `find_provider_by_phone` are SECURITY DEFINER and granted to `anon`; both need explicit business justification/rate limiting or grant removal.
  - PostGIS `st_estimatedextent` overloads are SECURITY DEFINER and granted to anon; likely extension/system findings, should not be changed blindly.
  - 146 authenticated SECURITY DEFINER functions are exposed; each needs allowlist review, not mass removal.
- Performance Advisor:
  - 42 unindexed foreign keys.
  - 109 RLS policies call auth/current_setting per row instead of wrapping with `(select auth.uid())`; scale issue, not immediate correctness failure.
- Storage buckets:
  - Public: `avatars` 5MB image allowlist; `community-needs` 5MB image allowlist; `community-offers` 10MB image allowlist; `institution-images` 10MB image allowlist; `provider-images` 10MB image allowlist; `swap-images` 5MB image allowlist.
  - Public and unbounded/no MIME allowlist: `charity-images`, `home-banners`, `restaurant-offers`.
  - Private: `provider-documents` 10MB image allowlist.
- `published_service_providers` exposes public phone, WhatsApp, email, website, company legal name, founded year, employees, branches, address, coordinates, and provider operational metrics. This is a potential privacy/data-minimization issue and must match product intent/store privacy disclosures.
- Production Edge Functions are ahead of or drift from local source in versions/content. Deployed active functions include `send-otp` v7, `verify-and-create` v18, `send-whatsapp` v3, `send-push-notification` v27, `notify-provider-approved` v6, `verify-otp` v2, `notify-new-charity-donation` v19, plus deployed `issue-signup-email-code` not present in local function listing.
- `verify-otp` deployed function still contains legacy behavior: `verify_jwt=true`, service-role queries, and uses `generateLink` for an email domain that differs from current `verify-and-create` (`loqma.app` vs `loqma.local`), indicating an obsolete parallel auth path that should be disabled or reconciled after usage checks.
- `send-otp`/`verify-and-create`/notification functions use wildcard CORS; this is not a credential leak by itself, but should be bounded if browser clients are not required.
- Live `users` table still contains legacy nullable/updatable `password` column; prior repository audit reports zero non-null values, but this must be rechecked and removed only after confirming no old client/function uses it.

## Local code observations
- Android manifest requests background location, fine/coarse location, notifications, and internet. Background location needs explicit product justification and store declarations.
- Android release signing is intentionally fail-closed unless four environment variables are supplied; no production keystore is in Git.
- `Info.plist` includes location, camera, photo-library, remote-notification, and broad ATS exceptions set to disallow insecure loads.
- Local source contains many debug logs; some include user IDs, phone values, paths, tokens/QR values, or API error details. Need classify and remove/redact in release-sensitive paths.
- `main.dart` loads `.env` optionally and uses compile-time defines; missing Supabase configuration only logs and continues, which can lead to a broken app with an unclear state rather than a controlled configuration screen.
- `verify-and-create` local and deployed function differ materially (deployed version has newer profile preservation/provider availability behavior). Do not deploy local code without reconciling drift.

## Do not do blindly
- Do not mass-revoke SECURITY DEFINER function grants; many are intentional authenticated business RPCs and require per-function authorization review.
- Do not apply schema/RLS/storage migrations to production without an explicit safe migration plan and validation; current audit is read-only.
