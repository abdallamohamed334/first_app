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

    print("security regression checks: PASS")


if __name__ == "__main__":
    main()
