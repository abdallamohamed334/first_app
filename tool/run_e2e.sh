#!/usr/bin/env bash
set -euo pipefail

required=(
  SUPABASE_URL
  SUPABASE_ANON_KEY
  TEST_USER_ACCESS_TOKEN
  TEST_PROVIDER_ACCESS_TOKEN
  TEST_INSTITUTION_ACCESS_TOKEN
)

missing=()
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    missing+=("$name")
  fi
done

if (( ${#missing[@]} > 0 )); then
  printf 'E2E requires dedicated non-production test credentials. Missing: %s\n' "${missing[*]}" >&2
  exit 2
fi

flutter test test/integration/production_contract_test.dart
