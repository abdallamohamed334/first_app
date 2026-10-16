# Sentry setup for Khedma

## Project

- **Organization:** `khedma`
- **Project:** `khedma`
- **Sentry project URL:** <https://khedma.sentry.io/projects/khedma/>
- **Production DSN:** `https://9e520b4324385a5c44f38c2119ca5aff@o4512264384086016.ingest.de.sentry.io/4512264401846352`
- **Production DSN rate limit:** 60 events per 3600 seconds
- **Alert recipient:** `tallaey445@gmail.com`

The DSN is a client-side identifier, not an auth token. **Never put
`SENTRY_AUTH_TOKEN` in the app, repository, APK, or this file.**

## Runtime behavior and quotas

- `sentry_flutter: ^9.30.1` is used because this project currently builds iOS
  with CocoaPods.
- Debug builds send nothing. Profile/development builds send nothing unless
  explicitly built with `--dart-define=SENTRY_STAGING=true`.
- Release builds use environment `production`; opt-in staging builds use
  environment `staging` and a 1% traces sample rate.
- Production traces are sampled at **5%**.
- `maxBreadcrumbs` is **50**. Screenshots, view hierarchy, session replay,
  profiling, and default PII are disabled.
- The client sends at most **10 accepted error events per app session**.
- The same `(exception type + message + top stack frame)` is sent at most once
  per 10 minutes per app session.
- Dropped events are counted locally and logged with a `[Sentry] dropped` line;
  they are not silently treated as application failures.
- The app stores only the authenticated Supabase UUID as an anonymous Sentry
  user identifier. Phone numbers, email addresses, OTPs, passwords, tokens,
  identity documents, and request bodies are not sent intentionally.

## Events filtered by `beforeSend`

The following are dropped locally but remain visible as local breadcrumbs/log
counters:

1. `SocketException`, `ClientException`, `TimeoutException`, and
   `HandshakeException` caused by normal connectivity failures.
2. Messages containing `Connection closed`, `Network is unreachable`, or
   `Failed host lookup`.
3. User-cancelled picker/camera/share actions, permission denial by the user,
   and messages containing `cancelled`, `canceled`, or `dismissed`.
4. Expected authentication outcomes: invalid credentials, email already
   registered, weak password, wrong/expired OTP.
5. Expected reservation outcomes: sold out, reservation limit reached, and
   expired offer (including the Arabic business-rule messages).
6. Missing/deleted cached images and normal 404 image-provider failures.

The following are **not** filtered:

- Unexpected exceptions and `StateError`, null/type errors, and crashes.
- `PostgrestException`, including server-side 5xx and RLS/permission errors.
- `StorageException` unless it is clearly a network/timeout failure.
- Any error that does not match the explicit expected/noise rules above.

## Debug/staging verification

The hidden route is:

`/__debug/sentry-test`

In a normal debug build, Sentry is disabled and the page verifies the filter
logic only:

- **Test filtered network error:** `SocketException` + `Network is unreachable`
  must show `drop`.
- **Send real StateError test:** `StateError` must show `report`.

To verify actual ingestion without enabling ordinary development telemetry:

```bash
flutter run --profile \
  --dart-define=SENTRY_STAGING=true \
  --dart-define=SENTRY_TEST=true \
  --dart-define=SENTRY_DSN="$SENTRY_DSN"
```

Use a separate staging DSN/rate limit for this test whenever possible. Do not
use `SENTRY_TEST=true` in the production APK distributed to users.

## Release build and symbol upload

Set the DSN at build time, not in source code:

```bash
export SENTRY_DSN='https://9e520b4324385a5c44f38c2119ca5aff@o4512264384086016.ingest.de.sentry.io/4512264401846352'
export SENTRY_AUTH_TOKEN='<store-this-only-in-CI-secrets>'
export SENTRY_ORG='khedma'
export SENTRY_PROJECT='khedma'
export SENTRY_RELEASE='khedma@1.0.0+1'

flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols \
  --dart-define=SENTRY_DSN="$SENTRY_DSN"

flutter pub run sentry_dart_plugin
```

## Sentry project settings

The connected Sentry API supports DSN rate limits, and the production key is
already limited to **60 events/hour**. The API connector used for this project
does not expose controls for Spike Protection, quota notifications, or custom
issue grouping rules; configure those in the Sentry UI:

1. **Spike Protection:** open `khedma` → **Settings** → **Spike Protection**;
   enable it for the project and keep the default protective threshold.
2. **Usage notification:** open **Settings → Usage & Billing → Notifications**;
   add an email notification at **80%** of the monthly error quota.
3. **Grouping:** open **Project Settings → Issue Grouping**. Keep the default
   stack-trace grouping, and add grouping rules only for known wrapper errors
   that have the same root cause.
4. **Noisy issues:** from the issue page choose **Ignore** only for a known
   expected issue already covered by the client filter. Set an expiration or
   alert threshold instead of ignoring crashes permanently.

## Alerts configured

1. **Khedma - New issue** — issue workflow, first-seen issue, email to
   `tallaey445@gmail.com`, 30-minute notification interval.
2. **Khedma - 5 affected users in 1 hour** — metric monitor for at least five
   unique users affected by `level:error` events in a rolling 60-minute
   window; connected to the email workflow above.

## Checking monthly usage

Open **Sentry → Settings → Usage & Billing** and inspect the current monthly
error-event total and the projected usage. For a 5,000-error monthly quota:

- **Below 4,000 (80%)**: healthy buffer.
- **4,000–4,499**: investigate noisy issues and dropped-event reasons.
- **4,500+ (90%)**: urgent review; keep the 60/hour DSN cap and inspect the
  project before releasing a new build.
- **5,000**: quota reached; new events may be rate-limited or rejected.

## References

- [Sentry Flutter package](https://pub.dev/packages/sentry_flutter)
- [Sentry Dart Plugin](https://docs.sentry.io/platforms/dart/guides/flutter/debug-symbols/dart-plugin/)
- [Sentry Flutter documentation](https://docs.sentry.io/platforms/flutter/)
