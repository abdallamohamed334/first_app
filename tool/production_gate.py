#!/usr/bin/env python3
"""Static release gate for the Loqma production repository."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []

required = [
    ROOT / "pubspec.yaml",
    ROOT / "lib/main.dart",
    ROOT / "supabase/config.toml",
    ROOT / "supabase/migrations/20261002100000_harden_public_image_bucket_limits.sql",
    ROOT / "supabase/migrations/20261002110000_add_otp_rate_limit.sql",
    ROOT / ".github/workflows/flutter-ci.yml",
    ROOT / ".github/workflows/release.yml",
]
for path in required:
    if not path.is_file() or path.stat().st_size == 0:
        errors.append(f"missing required release file: {path.relative_to(ROOT)}")

text_files = list((ROOT / "lib").rglob("*.dart")) + list(
    (ROOT / "supabase/functions").rglob("*.ts")
)
for path in text_files:
    text = path.read_text(errors="replace")
    rel = path.relative_to(ROOT)
    if re.search(r"TEST-\$|G-XXXXXXXX|Orphan public user\. Deleting|conflictDeleteError", text):
        errors.append(f"release placeholder/unsafe fallback found: {rel}")
    if re.search(r"(?:debugPrint|print|console\.(?:log|warn|error)).*(?:access_token|refresh_token|OTP to|Final Token|AUTH USER:)", text, re.I):
        errors.append(f"possible sensitive log found: {rel}")

config = (ROOT / "supabase/config.toml").read_text()
for function in ("send-otp", "verify-and-create", "verify-otp", "notify-provider-approved"):
    if f"[functions.{function}]" not in config:
        errors.append(f"missing explicit function config: {function}")

workflow = (ROOT / ".github/workflows/release.yml").read_text()
for marker in ("flutter analyze", "flutter test", "flutter build appbundle", "flutter build ipa"):
    if marker not in workflow:
        errors.append(f"release workflow missing: {marker}")

if errors:
    print("PRODUCTION_GATE_FAILED")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PRODUCTION_GATE_PASS")
