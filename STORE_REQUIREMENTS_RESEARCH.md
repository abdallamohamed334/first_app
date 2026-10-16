# Store requirements research

- Google Play official target API page: https://developer.android.com/google/play/requirements/target-sdk
  - Starting August 31, 2026, new apps and app updates must target Android 16 / API 36 or higher.
- Apple official upcoming requirements: https://developer.apple.com/news/upcoming-requirements/
  - Since April 28, 2026, App Store Connect uploads must be built with Xcode 26 or later using an iOS 26 SDK or newer.
  - Since September 9, 2026, iOS/iPadOS uploads must target iOS 13 or later.
- Google Play account deletion policy: https://support.google.com/googleplay/android-developer/answer/13327111
  - Apps that allow account creation must provide an in-app account deletion path and a web resource for deletion requests.
- Google Play UGC policy: https://support.google.com/googleplay/android-developer/answer/9876937
  - UGC apps must require terms acceptance before creating/uploading UGC and provide in-app reporting and blocking functionality with ongoing moderation.


## Official sources checked on 2026-10-16

- Google Play account deletion details: https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-GB — account-creating apps need an in-app deletion path and a web resource for account/data deletion requests.
- Apple current requirements: https://developer.apple.com/news/upcoming-requirements/ — uploads since April 28, 2026 need Xcode 26 or later with an iOS 26 SDK; iOS/iPadOS uploads since September 9, 2026 must target iOS 13 or later; approved reasons are required for listed APIs.
- Google Play target API requirement: https://developer.android.com/google/play/requirements/target-sdk — new apps and updates from August 31, 2026 target Android 16/API 36 or higher.
- Google Play testing requirement: https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-GB — new personal developer accounts may need 12 opted-in testers continuously for 14 days before production access; confirm the exact Play Console status at submission time.
