# Capacity hardening — 2026-10-12

## What was changed

The highest-cost client paths were bounded and consolidated. Food-offer request enrichment no longer performs two `offer_requests` queries per offer; it now fetches the first 50 offers and enriches them with one batched `offer_id` query. Community counters and per-user counters now use aggregate, authorization-checked RPCs rather than transferring every matching row to the phone. The map fallback is capped at 500 candidates, and the primary nearby RPC is capped at 100 rows inside PostgreSQL. Marketplace category-tree expansion now loads the active category dimension once instead of issuing one request per tree level.

Static lists that are dimensions or dashboards now have explicit bounds, including banners, categories, provider areas, provider cities, provider lists, business request lists, and food offers. Composite indexes were added for food-offer expiry reads, offer-request counts and lookups, notification feeds, category-tree traversal, provider ranking, and user counters.

## Production changes applied

The following database changes were applied to the linked Supabase project:

- `capacity_hot_path_indexes`
- `aggregate_community_stats_rpc`
- `bound_nearby_institution_offers_v2`
- `aggregate_user_stats_rpc`
- `user_stats_indexes`

The aggregate community RPC returned HTTP 200 through the public REST endpoint during verification. The new indexes were confirmed in `pg_indexes`, and the nearby RPC was confirmed to have a server-side `LIMIT 100` with execution denied to `anon` and allowed to `authenticated`.

## Repository guards

`tool/performance_regression_check.py` now fails CI if the main N+1 path, unbounded map fallback, unbounded category tree, or aggregate RPC replacements regress. GitHub Flutter CI runs this check before analysis and tests.

## Expected impact

The largest reduction is in request amplification: the food-offer list path changes from up to 101 network requests for 50 offers to two requests. The stats paths change from multiple full-row scans/transfers to one small JSON response each. The database now has indexes matching the common filters and sort orders.

This removes the confirmed client-side bottlenecks. A final user-capacity number still requires a real authenticated load test against the production plan, because concurrent Supabase connection/API limits and image bandwidth are plan/runtime limits rather than properties visible in the repository.
