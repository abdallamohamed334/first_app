#!/usr/bin/env python3
"""Static guards for the application's highest-cost client read paths."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
service = (ROOT / "lib/core/services/supabase_service.dart").read_text()
map_repo = (ROOT / "lib/features/map/data/repositories/map_repository_impl.dart").read_text()
userhome = (ROOT / "lib/features/userhome/data/repositories/userhome_repository.dart").read_text()
provider = (ROOT / "lib/features/services/data/repositories/service_providers_repository.dart").read_text()
nearby_rpc = (ROOT / "supabase/migrations/20261012232000_bound_nearby_institution_offers.sql").read_text()
user_stats_rpc = (ROOT / "supabase/migrations/20261012233000_aggregate_user_stats_rpc.sql").read_text()

start = service.index("getAvailableOffersWithRequests")
end = service.index("getOfferById", start)
hot_path = service[start:end]
if "inFilter('offer_id', offerIds)" not in hot_path:
    raise AssertionError("food-offer request enrichment must use one batched offer_id query")
if hot_path.count("from('offer_requests')") != 1:
    raise AssertionError("food-offer request enrichment regressed to multiple offer_requests queries")
if ".limit(50)" not in hot_path:
    raise AssertionError("food-offer request enrichment must remain bounded")

if ".limit(500);" not in map_repo:
    raise AssertionError("Haversine map fallback must stay bounded")
if ".limit(1000);" in map_repo:
    raise AssertionError("map fallback must not fetch 1000 rows into the client")
if "LIMIT 100;" not in nearby_rpc:
    raise AssertionError("nearby institution RPC must stay bounded at the database")
if "get_community_stats" not in service:
    raise AssertionError("community stats must use the aggregate RPC")
if "get_community_stats" not in (ROOT / "supabase/migrations/20261012231000_aggregate_community_stats_rpc.sql").read_text():
    raise AssertionError("aggregate stats RPC migration is missing")
if "get_user_stats" not in service or "get_user_stats" not in user_stats_rpc:
    raise AssertionError("user stats must use the aggregate RPC")
if ".limit(5000)" not in userhome:
    raise AssertionError("category tree must load the category dimension with one bounded query")
if "limit = 500," in provider:
    raise AssertionError("provider list must not default to 500 rows")

print("performance regression checks: PASS")
