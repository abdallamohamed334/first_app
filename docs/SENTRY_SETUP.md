# Sentry setup for Khedma

## Project

- **Organization:** `khedma`
- **Project:** `khedma`
- **Sentry project URL:** <https://khedma.sentry.io/projects/khedma/>
- **DSN:** `https://c43e1b3b4b83316500c8e7a3f7411b5d@o4510367891234816.ingest.de.sentry.io/4512264401846352`
- **Alert recipient:** `tallaey445@gmail.com`

The DSN is a client-side identifier, not an auth token. **Never put
`SENTRY_AUTH_TOKEN` in the app, repository, APK, or this file.**

## Runtime behavior

- `sentry_flutter: ^9.30.1` is used because this project currently builds iOS
  with CocoaPods. Sentry Flutter 10.x requires Swift Package Manager and is
  not compatible with this repository's current CocoaPods setup.
- Sentry is initialized only for non-debug builds and only when
  `SENTRY_DSN` is provided.
- Release is sent as `khedma@<version>+<buildNumber>`.
- Environment is `production` for release builds.
- Traces are sampled at **20%**.
- `sendDefaultPii`, screenshots, and view hierarchy are disabled.
- `beforeSend` removes user/request/extra data; breadcrumbs containing phone,
  token, password, authorization, identity-document, or request-body keys are
  dropped.
- The app stores only the authenticated Supabase UUID as an anonymous Sentry
  user identifier. Phone numbers, email addresses, OTPs, passwords, tokens,
  identity documents, and request bodies are not sent intentionally.

## Local verification

The hidden debug route is available only in debug builds:

`/__debug/sentry-test`

Open it directly in the app/router and press **Send test exception**. Since
debug builds intentionally do not initialize Sentry, this button is a safe
UI smoke test for the integration surface; use a release/profile build with
the DSN below to verify ingestion in Sentry.

## Release build and symbol upload

Set the DSN at build time, not in source code:

```bash
export SENTRY_DSN='https://c43e1b3b4b83316500c8e7a3f7411b5d@o4510367891234816.ingest.de.sentry.io/4512264401846352'
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

For iOS, use the same `SENTRY_*` CI environment and:

```bash
flutter build ipa --release \
  --obfuscate \
  --split-debug-info=build/symbols \
  --dart-define=SENTRY_DSN="$SENTRY_DSN"
flutter pub run sentry_dart_plugin
```

The plugin uploads symbols/source context. Keep the token in the CI secret
store only; do not commit `sentry.properties` or `.sentryclirc`.

## Alerts configured

1. **Khedma - New issue** — issue workflow, first-seen issue, email to
   `tallaey445@gmail.com`, 30-minute notification interval.
2. **Khedma - 5 affected users in 1 hour** — metric monitor for at least five
   unique users affected by `level:error` events in a rolling 60-minute
   window; connected to the email workflow above.

## References

- [Sentry Flutter package](https://pub.dev/packages/sentry_flutter)
- [Sentry Dart Plugin](https://docs.sentry.io/platforms/dart/guides/flutter/debug-symbols/dart-plugin/)
- [Sentry Flutter documentation](https://docs.sentry.io/platforms/flutter/)
