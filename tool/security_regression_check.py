#!/usr/bin/env python3
"""Static regression checks for the provider/RLS security hardening.

This complements authenticated staging tests; it intentionally needs no Flutter
or network dependencies so CI can run it in a minimal environment.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20261001100000_close_provider_privilege_escalation.sql"
RPC_MIGRATION = ROOT / "supabase/migrations/20261001101500_revoke_anon_public_rpc_access.sql"
SENSITIVE_GRANT_MIGRATION = ROOT / "supabase/migrations/20261001103000_revoke_provider_sensitive_update_grants.sql"
PUBLIC_PROVIDER_MIGRATION = ROOT / "supabase/migrations/20261002120000_lock_public_provider_surface.sql"
MAIN = ROOT / "lib/main.dart"
PROVIDER = ROOT / "lib/features/provider/data/repositories/service_provider_repository.dart"
MAP_PAGE = ROOT / "lib/features/auth/presentation/pages/location_picker_page.dart"
LOAD_TEST = ROOT / "load_test.py"
FIREBASE_OPTIONS = ROOT / "lib/firebase_options.dart"
CHARITY_ACCESS_MIGRATION = ROOT / "supabase/migrations/20261008234500_harden_charity_donation_access.sql"
CHARITY_REPOSITORY = ROOT / "lib/features/charity/data/repositories/charity_donation_repository_separate.dart"
FEED_RLS_MIGRATION = ROOT / "supabase/migrations/20261008235000_harden_user_feed_rls.sql"
USER_HOME_REPOSITORY = ROOT / "lib/features/userhome/data/repositories/userhome_repository.dart"
SUPABASE_SERVICE = ROOT / "lib/core/services/supabase_service.dart"
VOLUNTEER_TRACKING_PAGE = ROOT / "lib/features/community/presentation/pages/volunteer_donations_tracking_page.dart"
DONOR_TRACKING_PAGE = ROOT / "lib/features/community/presentation/pages/community_my_charity_donations_page.dart"
AUTH_STATE = ROOT / "lib/core/services/auth_state_notifier.dart"
APP_ROUTER = ROOT / "lib/routes/app_router.dart"
ONBOARDING_BLOC = ROOT / "lib/features/onboarding/presentation/bloc/onboarding_bloc.dart"
USER_HOME_BLOC = ROOT / "lib/features/userhome/presentation/bloc/userhome_bloc.dart"
ERROR_MAPPER = ROOT / "lib/core/errors/app_error_mapper.dart"
RELEASE_WORKFLOW = ROOT / ".github/workflows/release.yml"
PROFILE_PAGE = ROOT / "lib/features/auth/presentation/pages/complete_profile_page.dart"
FOOD_OFFER_MIGRATION = ROOT / "supabase/migrations/20261008235500_atomic_food_offer_request_lifecycle.sql"
PARTNER_LOGIN_PAGE = ROOT / "lib/features/auth/presentation/pages/institution_login_page.dart"
PARTNER_OTP_PAGE = ROOT / "lib/features/auth/presentation/pages/institution_otp_verify_page.dart"
MANUAL_PARTNER_OTP_MIGRATION = ROOT / "supabase/migrations/20261009223400_restore_manual_partner_login_otp.sql"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def main() -> None:
    migration = MIGRATION.read_text()
    rpc_migration = RPC_MIGRATION.read_text()
    sensitive_grant_migration = SENSITIVE_GRANT_MIGRATION.read_text()
    public_provider_migration = PUBLIC_PROVIDER_MIGRATION.read_text()
    main_dart = MAIN.read_text()
    provider = PROVIDER.read_text()
    map_page = MAP_PAGE.read_text()
    load_test = LOAD_TEST.read_text()
    firebase_options = FIREBASE_OPTIONS.read_text()
    charity_access_migration = CHARITY_ACCESS_MIGRATION.read_text()
    charity_repository = CHARITY_REPOSITORY.read_text()
    feed_rls_migration = FEED_RLS_MIGRATION.read_text()
    user_home_repository = USER_HOME_REPOSITORY.read_text()
    supabase_service = SUPABASE_SERVICE.read_text()
    volunteer_tracking_page = VOLUNTEER_TRACKING_PAGE.read_text()
    donor_tracking_page = DONOR_TRACKING_PAGE.read_text()
    auth_state = AUTH_STATE.read_text()
    app_router = APP_ROUTER.read_text()
    onboarding_bloc = ONBOARDING_BLOC.read_text()
    user_home_bloc = USER_HOME_BLOC.read_text()
    error_mapper = ERROR_MAPPER.read_text()
    release_workflow = RELEASE_WORKFLOW.read_text()
    profile_page = PROFILE_PAGE.read_text()
    food_offer_migration = FOOD_OFFER_MIGRATION.read_text()
    partner_login_page = PARTNER_LOGIN_PAGE.read_text()
    partner_otp_page = PARTNER_OTP_PAGE.read_text()
    manual_partner_otp_migration = MANUAL_PARTNER_OTP_MIGRATION.read_text()

    require(migration, "REVOKE UPDATE ON TABLE public.users", "users update revoke")
    require(migration, "GRANT UPDATE (", "allowlisted users update columns")
    require(migration, "REVOKE UPDATE ON TABLE public.service_providers", "provider update revoke")
    require(migration, "DROP FUNCTION IF EXISTS public.get_provider_auth_state(uuid)", "legacy auth RPC removal")
    require(migration, "WHERE sp.user_id = auth.uid()", "session-bound provider lookup")
    require(migration, "REVOKE ALL ON FUNCTION public.get_provider_auth_state() FROM PUBLIC, anon", "auth RPC anon revoke")
    require(public_provider_migration, "RETURNS TABLE(\n  verification_status text,\n  is_active boolean", "minimal provider phone response")
    require(migration, "GRANT EXECUTE ON FUNCTION public.find_provider_by_phone(text) TO anon, authenticated", "pre-OTP lookup grant")
    require(public_provider_migration, "CASE WHEN auth.uid() IS NOT NULL THEN sp.phone END", "authenticated provider contact access")
    require(public_provider_migration, "REVOKE ALL ON public.published_service_providers FROM PUBLIC", "public provider privilege reset")
    for sensitive in ("id_card_front_url", "id_card_back_url", "verification_notes", "verified_by", "verified_at", "company_legal_name", "employees_count", "founded_year"):
        if sensitive in public_provider_migration.split("CREATE VIEW public.published_service_providers", 1)[1].split("REVOKE ALL", 1)[0]:
            raise AssertionError(f"sensitive field leaked by public provider view: {sensitive}")

    if "params: {'p_user_id': userId}" in main_dart or "params: {'p_user_id': userId}" in provider:
        raise AssertionError("client still passes an arbitrary user ID to provider auth RPC")
    require(provider, "contentType: contentType", "provider image MIME enforcement")
    require(provider, "FileOptions(contentType: contentType)", "identity image MIME enforcement")
    require(provider, "experienceYears < 1", "normalized experience validation")
    require(map_page, "String.fromEnvironment('MAPBOX_PUBLIC_TOKEN')", "build-time map token")
    if re.search(r"pk\.ey[A-Za-z0-9_.-]{20,}", map_page):
        raise AssertionError("Mapbox token is hardcoded in the client")
    require(load_test, "os.environ.get(\"SUPABASE_ANON_KEY\"", "environment-based load-test key")
    if re.search(r"sb_(publishable|secret)_[A-Za-z0-9_-]{12,}", load_test):
        raise AssertionError("Supabase key is hardcoded in load_test.py")
    for env_name in (
        "FIREBASE_ANDROID_API_KEY",
        "FIREBASE_IOS_API_KEY",
        "FIREBASE_WEB_API_KEY",
        "FIREBASE_MACOS_API_KEY",
    ):
        require(firebase_options, f"_env('{env_name}')", f"environment-based Firebase key: {env_name}")
    if "AIza" in firebase_options:
        raise AssertionError("Firebase API key is hardcoded in lib/firebase_options.dart")
    for dart_file in ROOT.joinpath("lib").rglob("*.dart"):
        dart_text = dart_file.read_text()
        if "gsrhoqdtcyfdmvgahqvl.supabase.co" in dart_text:
            raise AssertionError(f"Supabase URL is hardcoded in {dart_file}")
    require(rpc_migration, "list_community_needs_v2", "authenticated-only community needs RPC")
    require(rpc_migration, "list_public_volunteers() FROM anon, PUBLIC", "authenticated-only volunteers RPC")
    for protected in ("id_card_front_url", "id_card_back_url", "profile_locked_at"):
        require(sensitive_grant_migration, protected, f"sensitive provider revoke: {protected}")

    require(charity_access_migration, "REVOKE ALL PRIVILEGES ON TABLE public.charity_donation_requests", "charity donation table privilege reset")
    require(charity_access_migration, "GRANT UPDATE (charity_notes)", "charity notes-only direct update")
    require(charity_access_migration, "DROP POLICY IF EXISTS volunteer_open_requests_authenticated", "open volunteer row policy removal")
    require(charity_access_migration, "get_donor_donation_pickup_token", "donor-owned pickup token RPC")
    require(charity_access_migration, "get_assigned_donation_pickup_token", "assigned-volunteer pickup token RPC")
    require(charity_access_migration, "confirm_charity_delivery_with_code", "atomic charity delivery confirmation RPC")
    if re.search(r"\.select\([^)]*(?<![A-Za-z0-9_])(pickup_token|charity_pickup_code)(?![A-Za-z0-9_])", charity_repository, re.DOTALL):
        raise AssertionError("charity repository still selects pickup secrets directly")
    if "'status': 'completed'" in charity_repository or "'charity_pickup_code'" in charity_repository:
        raise AssertionError("charity repository still writes delivery state or pickup secrets directly")

    require(feed_rls_migration, "CREATE POLICY favorites_owner_select", "owner-scoped favorites RLS")
    require(feed_rls_migration, "CREATE POLICY delivery_tasks_assigned_volunteer_read", "assigned-task RLS")
    require(feed_rls_migration, "SECURITY DEFINER", "secured rescue-list RPC")
    require(feed_rls_migration, "موقع الاستلام الدقيق متاح بعد قبول المهمة", "redacted pre-claim location")
    require(feed_rls_migration, "AND pickup_before > now()", "unexpired atomic task claim")
    require(feed_rls_migration, "REVOKE EXECUTE ON FUNCTION public.nearby_rescue_tasks", "anon rescue-list revoke")
    if ".from('delivery_tasks')" in user_home_repository or ".from('charity_donation_requests')" in user_home_repository:
        raise AssertionError("UserHome still directly reads open task/donation rows")
    require(user_home_repository, "list_open_donations_for_volunteers", "safe open-donation RPC")
    require(supabase_service, ".select('id, title, description, points_required, image, is_active')", "safe rewards catalog columns")
    require(supabase_service, "json['image'] ?? json['image_url']", "live rewards image column mapping")
    if "charity_pickup_code" in volunteer_tracking_page or re.search(r"\.select\(['\"]\s*\*", volunteer_tracking_page):
        raise AssertionError("volunteer tracking page selects a private pickup code or all donation columns")
    require(volunteer_tracking_page, "getCharityPickupCode(_donationId)", "authorized charity code RPC")
    if ".stream(primaryKey: ['id'])" in donor_tracking_page:
        raise AssertionError("donor tracking still streams all donation columns")
    require(donor_tracking_page, "Timer.periodic(", "safe donor status refresh")

    require(auth_state, "return '/account-restricted';", "unknown-role fail-closed route")
    require(app_router, "auth.homeRoute == accountRestricted", "unknown-role router guard")
    require(app_router, "loc == institutionsHome && auth.homeRoute != institutionsHome", "institution route role guard")
    require(app_router, "protectedProviderRoutes.contains(loc) && auth.role != 'provider'", "provider route role allowlist")
    require(app_router, "loc == charityHome && auth.role != 'charity'", "charity route role allowlist")
    require(onboarding_bloc, "setBool('onboarding_seen', true)", "persisted onboarding completion")
    require(user_home_bloc, "generation != _loadGeneration", "stale UserHome load guard")
    require(main_dart, "client.auth.currentUser?.id != userId", "session identity recheck after auth sync awaits")
    require(main_dart, "_supabaseInitialization ??= Supabase.initialize(", "single-flight Supabase initialization")
    require(main_dart, "storedProfileRole == null || storedProfileRole.isEmpty", "unknown role handling for incomplete profile")
    if re.search(r"debugPrint\([^\n]*(?:userId|phone|\$name)", main_dart):
        raise AssertionError("auth logs expose user identifiers or phone/name values")
    require(user_home_repository, "expires_at.is.null,expires_at.gt.", "community/institution category expiry filters")
    require(user_home_repository, ".gt('expiry_time', DateTime.now().toUtc().toIso8601String())", "food category expiry filter")
    if "_bioCtrl" in profile_page:
        raise AssertionError("profile page offers bio even though public.users has no bio column")
    require(profile_page, "avatarUrl = await _storage.uploadAvatar(", "avatar upload must succeed before full profile success")
    require(release_workflow, "python3 tool/security_regression_check.py", "release security gate")
    require(food_offer_migration, "IF auth.uid() IS NULL", "authenticated food-request lifecycle")
    require(food_offer_migration, "AND status = 'available'", "single-request reservation guard")
    require(food_offer_migration, "IF NOT FOUND THEN", "atomic offer reservation failure rollback")
    if "send-partner-login-otp" in partner_login_page:
        raise AssertionError("partner login must not send an OTP message")
    require(partner_login_page, "verify_institution_login_otp", "manual institution-code database verification")
    require(partner_login_page, "verify_charity_login_otp", "manual charity-code database verification")
    require(partner_otp_page, "يتم التحقق منه في قاعدة البيانات فقط", "manual code verification copy")
    require(manual_partner_otp_migration, "REVOKE ALL ON FUNCTION public.verify_institution_login_otp(uuid, text)", "manual institution verifier access reset")
    if not re.search(r"GRANT EXECUTE ON FUNCTION public\.verify_institution_login_otp\(uuid, text\)\s+TO authenticated", manual_partner_otp_migration):
        raise AssertionError("missing authenticated-only institution verifier grant")
    require(manual_partner_otp_migration, "REVOKE ALL ON FUNCTION public.verify_charity_login_otp(uuid, text)", "manual charity verifier access reset")
    if not re.search(r"GRANT EXECUTE ON FUNCTION public\.verify_charity_login_otp\(uuid, text\)\s+TO authenticated", manual_partner_otp_migration):
        raise AssertionError("missing authenticated-only charity verifier grant")
    for shared_file in (supabase_service, error_mapper):
        if "import 'dart:io'" in shared_file or 'import "dart:io"' in shared_file:
            raise AssertionError("shared app code imports dart:io and blocks web compilation")

    print("security regression checks: PASS")


if __name__ == "__main__":
    main()
