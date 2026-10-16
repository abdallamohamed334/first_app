# Khedma Supabase + Flutter Security Audit

**Audit date:** 2026-10-16
**Project:** `gsrhoqdtcyfdmvgahqvl`

## Executive summary

- The app uses a public Supabase URL and publishable/anon key as expected. No service-role key or private-key material was found in current tracked source or the scanned Git history patterns.
- RLS is enabled on all application tables returned by the live inventory except the managed PostGIS table `public.spatial_ref_sys`.
- The unauthenticated REST checks did not return rows from `users`, `blocked_users`, or `reports`; `service_providers` correctly returned permission denied. Public food offers remained readable as intended.
- Applied hardening: trigger-only RPC execution was revoked for four functions; PostGIS helper RPC execution was attempted but remains controlled by the managed extension; `set_home_ads_updated_at` now has a fixed search path; provider identity documents gained an explicit admin-read storage policy; Android backup is disabled.

## Findings and status

| Area | Result | Status |
|---|---|---|
| Public Supabase URL/anon key | Treating these as public is correct; security must come from RLS, grants, and Edge Functions | PASS |
| Application-table RLS | All inventoried application tables have RLS enabled | PASS |
| Private provider documents | Bucket is private, 10 MiB limit, image MIME allowlist, owner read/write, admin read policy added | PASS |
| Trigger-only SECURITY DEFINER functions | Anonymous/authenticated EXECUTE revoked for four trigger functions | FIXED |
| Mutable function search path | `public.set_home_ads_updated_at` fixed to `public, pg_temp` | FIXED |
| PostGIS `spatial_ref_sys` RLS | Project role cannot alter managed extension-owned table; migration failed safely and was not partially applied | OPEN / PLATFORM-OWNED |
| PostGIS helper RPC grants | Still reported by advisor as extension-managed; no application data path uses them | OPEN / PLATFORM-OWNED |
| Authenticated A-vs-B live test | No disposable authenticated JWTs were provided; policy review and anon tests completed, but a true two-user JWT test remains required before launch | NOT EXECUTED |

## Applied migration

The applied migration is `20261016110000_security_audit_hardening` (live migration name `security_audit_hardening_v2`). The same intended SQL is recorded locally at `supabase/migrations/20261016110000_security_audit_hardening.sql`.

Changes applied:

1. Revoked client execution of `create_direct_charity_status_notifications`, `enforce_institution_offer_type`, `guard_offer_request_integrity`, and `protect_community_need_insert`.
2. Fixed the `search_path` on `set_home_ads_updated_at`.
3. Added `storage.objects` SELECT policy `provider_documents_admin_read` for authenticated admins, while retaining the provider-owner policy.
4. Attempted the PostGIS RLS remediation in a transaction; Supabase rejected it because the project role is not the owner of `spatial_ref_sys`, so no partial change occurred.

## Storage inventory

| Bucket | Public | Limit | MIME policy |
|---|---:|---:|---|
| avatars | yes | 5 MiB | JPEG/JPG/PNG/WebP |
| charity-images | yes | 5 MiB | JPEG/JPG/PNG/WebP |
| community-needs | yes | 5 MiB | JPEG/PNG/WebP |
| community-offers | yes | 10 MiB | JPEG/JPG/PNG/WebP |
| home-banners | yes | 5 MiB | JPEG/JPG/PNG/WebP |
| institution-images | yes | 10 MiB | JPEG/JPG/PNG/WebP |
| provider-documents | **no** | 10 MiB | JPEG/JPG/PNG/WebP |
| provider-images | yes | 10 MiB | JPEG/JPG/PNG/WebP |
| restaurant-offers | yes | 5 MiB | JPEG/JPG/PNG/WebP |
| swap-images | yes | 5 MiB | JPEG/PNG/WebP |

## Live inventory

**Tables:** 86 listed by the live API; application public tables: 82, private tables: 2.

### Private tables

`charity_login_secrets` (RLS=true), `institution_login_secrets` (RLS=true)

### Public tables

`account_audit_log` (RLS=true), `account_cases` (RLS=true), `account_evidence` (RLS=true), `admin_audit_logs` (RLS=true), `blocked_users` (RLS=true), `business_capabilities` (RLS=true), `businesses` (RLS=true), `charities` (RLS=true), `charity_donation_request_events` (RLS=true), `charity_donation_requests` (RLS=true), `charity_volunteers` (RLS=true), `community_categories` (RLS=true), `community_need_categories` (RLS=true), `community_needs` (RLS=true), `community_offers` (RLS=true), `community_requests` (RLS=true), `deliveries` (RLS=true), `delivery_tasks` (RLS=true), `direct_charity_points_awards` (RLS=true), `dismissed_community_needs` (RLS=true), `donations` (RLS=true), `favorites` (RLS=true), `food_offers` (RLS=true), `home_ads` (RLS=true), `home_banners` (RLS=true), `institution_charity_donations` (RLS=true), `institution_notifications` (RLS=true), `institution_offer_inventory` (RLS=true), `institution_offer_media` (RLS=true), `institution_offer_pickup` (RLS=true), `institution_offer_pricing` (RLS=true), `institution_offer_requests` (RLS=true), `institution_offer_status_events` (RLS=true), `institution_offers` (RLS=true), `institution_offers_core` (RLS=true), `institution_pickup_codes` (RLS=true), `institutions` (RLS=true), `marketplace_attribute_options` (RLS=true), `marketplace_attributes` (RLS=true), `marketplace_categories` (RLS=true), `marketplace_category_attribute_options` (RLS=true), `marketplace_category_attributes` (RLS=true), `marketplace_offer_attributes` (RLS=true), `marketplace_offers` (RLS=true), `need_contacts` (RLS=true), `notifications` (RLS=true), `offer_renewals_log` (RLS=true), `offer_requests` (RLS=true), `offer_reviews` (RLS=true), `organizations` (RLS=true), `otp_codes` (RLS=true), `otp_rate_limits` (RLS=true), `partner_login_otp_challenges` (RLS=true), `pending_signup_profiles` (RLS=true), `points_transactions` (RLS=true), `product_complaints` (RLS=true), `published_service_provider_cards` (RLS=true), `reports` (RLS=true), `rescued_meals` (RLS=true), `restaurant_charity_donation_events` (RLS=true), `restaurant_charity_donations` (RLS=true), `restaurant_charity_email_outbox` (RLS=true), `restaurant_charity_pickup_codes` (RLS=true), `restaurants` (RLS=true), `rewards` (RLS=true), `service_categories` (RLS=true), `service_offers` (RLS=true), `service_providers` (RLS=true), `service_requests` (RLS=true), `service_reviews` (RLS=true), `services` (RLS=true), `spatial_ref_sys` (RLS=false), `swap_categories` (RLS=true), `swap_listing_hidden` (RLS=true), `swap_listing_views` (RLS=true), `swap_listings` (RLS=true), `swap_proposals` (RLS=true), `user_devices` (RLS=true), `user_reviews` (RLS=true), `users` (RLS=true), `volunteer_points_awards` (RLS=true), `volunteer_profiles` (RLS=true)

### Public views

`active_food_offers`, `active_institution_offers`, `geography_columns`, `geometry_columns`, `home_offers`, `open_service_requests`, `published_service_providers`, `published_service_reviews`.

### Deployed Edge Functions

`send-push-notification`, `notify-new-charity-donation`, `issue-signup-email-code`, `send-whatsapp`, `send-otp`, `verify-otp`, `verify-and-create`, `notify-provider-approved`, `notify-charity-donation-event`, `request-notification`.

## Tests run

| Test | Result |
|---|---|
| `python3 tool/security_regression_check.py` | PASS |
| `python3 tool/performance_regression_check.py` | PASS |
| `python3 tool/production_gate.py` | PASS |
| `git diff --check` | PASS |
| Anonymous GET `users` | HTTP 200 with empty result under RLS |
| Anonymous GET `blocked_users` | HTTP 200 with empty result under RLS |
| Anonymous GET `reports` | HTTP 200 with empty result under RLS |
| Anonymous GET `service_providers` | HTTP 401 permission denied |
| Anonymous GET `food_offers` | HTTP 200; public available-offer surface remains intentional |
| Anonymous storage list `provider-documents` | HTTP 200 with empty result; bucket is private and no object data was exposed |

## Remaining risks / launch blockers

1. **PostGIS advisor findings remain.** The extension-owned `spatial_ref_sys` table and helper functions cannot be changed by the application project role. Ask Supabase support or use the platform-supported extension-management path to move PostGIS out of `public`/restrict its grants. Do not attempt to change ownership from the app migration.
2. **Two-user authorization test is still pending.** Run the supplied authenticated test plan with two disposable accounts (A and B) and verify SELECT/INSERT/UPDATE/DELETE for offers, reservations, reports, provider documents, profiles, and blocked users. No user data was mutated during this audit.
3. **Advisor performance notices are optimization work, not direct confidentiality failures:** 48 unindexed foreign keys and 111 RLS init-plan notices were reported. They should be addressed in a separate, measured performance migration rather than bundled into security changes.
4. **Captcha/provider confirmation settings** are not exposed by the database inventory tools used here. Verify phone/email confirmation, CAPTCHA, disabled unused auth providers, and auth rate limits in Supabase Dashboard before public launch.

## Recommended authenticated test matrix

| Actor | Must be able to read | Must not be able to read/modify |
|---|---|---|
| User A | own profile, own reports, own blocks, own reservations | User B profile/private rows, B reports/blocks, B provider documents |
| User B | own profile, own reports, own blocks, own reservations | User A profile/private rows, A reports/blocks, A provider documents |
| Admin | approved admin surfaces and provider documents | raw OTP/pickup/login secret tables |

No secrets, tokens, OTP values, private URLs, or personal record contents are included in this report.
