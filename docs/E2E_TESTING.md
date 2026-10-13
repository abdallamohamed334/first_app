# E2E testing

The production contract suite is intentionally **not** allowed to run against
implicit or guessed credentials. Use three dedicated, non-production test
accounts with the roles `user`, `provider`, and `institution`.

```bash
export SUPABASE_URL="https://<project-ref>.supabase.co"
export SUPABASE_ANON_KEY="<publishable-key>"
export TEST_USER_ACCESS_TOKEN="<user-access-token>"
export TEST_PROVIDER_ACCESS_TOKEN="<provider-access-token>"
export TEST_INSTITUTION_ACCESS_TOKEN="<institution-access-token>"
./tool/run_e2e.sh
```

The suite covers:

- anonymous rejection of malformed OTP and unauthorized internal functions;
- anonymous provider discovery without contact or operational fields;
- authenticated provider discovery contract;
- user/provider/institution token availability;
- rejection of direct client reads from OTP, points, and service-role-only tables;
- institution context access through the owner-scoped RPC;
- rejection of invalid public image uploads;
- push notification endpoint authentication.

Never put these tokens in GitHub, `.env`, production logs, or the app bundle.
Rotate them after CI or manual test runs.
