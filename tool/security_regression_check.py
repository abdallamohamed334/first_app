#!/usr/bin/env python3
"""Static regression checks for the provider/RLS security hardening.

This complements authenticated staging tests; it intentionally needs no Flutter
or network dependencies so CI can run it in a minimal environment.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20261001100000_close_provider_privilege_escalation.sql"
RPC_MIGRATION = ROOT / "supabase/migrations/20261001101500_revoke_anon_public_rpc_access.sql"
MAIN = ROOT / "lib/main.dart"
PROVIDER = ROOT / "lib/features/provider/data/repositories/service_provider_repository.dart"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def main() -> None:
    migration = MIGRATION.read_text()
    rpc_migration = RPC_MIGRATION.read_text()
    main_dart = MAIN.read_text()
    provider = PROVIDER.read_text()

    require(migration, "REVOKE UPDATE ON TABLE public.users", "users update revoke")
    require(migration, "GRANT UPDATE (", "allowlisted users update columns")
    require(migration, "REVOKE UPDATE ON TABLE public.service_providers", "provider update revoke")
    require(migration, "DROP FUNCTION IF EXISTS public.get_provider_auth_state(uuid)", "legacy auth RPC removal")
    require(migration, "WHERE sp.user_id = auth.uid()", "session-bound provider lookup")
    require(migration, "REVOKE ALL ON FUNCTION public.get_provider_auth_state() FROM PUBLIC, anon", "auth RPC anon revoke")
    require(migration, "RETURNS TABLE(\n  id uuid,\n  verification_status text,\n  is_active boolean", "minimal provider phone response")
    require(migration, "GRANT EXECUTE ON FUNCTION public.find_provider_by_phone(text) TO anon, authenticated", "pre-OTP lookup grant")
    for sensitive in ("id_card_front_url", "id_card_back_url", "verification_notes", "verified_by", "verified_at"):
        if sensitive in migration.split("CREATE VIEW public.published_service_providers", 1)[1].split("GRANT SELECT", 1)[0]:
            raise AssertionError(f"sensitive field leaked by public provider view: {sensitive}")

    if "params: {'p_user_id': userId}" in main_dart or "params: {'p_user_id': userId}" in provider:
        raise AssertionError("client still passes an arbitrary user ID to provider auth RPC")
    require(provider, "contentType: contentType", "provider image MIME enforcement")
    require(provider, "FileOptions(contentType: contentType)", "identity image MIME enforcement")
    require(provider, "experienceYears < 1", "normalized experience validation")
    require(rpc_migration, "list_community_needs_v2", "authenticated-only community needs RPC")
    require(rpc_migration, "list_public_volunteers() FROM anon, PUBLIC", "authenticated-only volunteers RPC")

    print("security regression checks: PASS")


if __name__ == "__main__":
    main()
