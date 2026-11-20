# Tamdid · تمدید

**A free, open-source subscription tracker for iPhone, built with SwiftUI.** See what you pay for, what it costs per month and what renews next, with a reminder before every renewal and every free trial that's about to turn into a payment.

[![iOS](https://github.com/Ali-Asadi-Dev/tamdid-IOS/actions/workflows/ios.yml/badge.svg)](https://github.com/Ali-Asadi-Dev/tamdid-IOS/actions/workflows/ios.yml)
[![Core and translations](https://github.com/Ali-Asadi-Dev/tamdid-IOS/actions/workflows/shared.yml/badge.svg)](https://github.com/Ali-Asadi-Dev/tamdid-IOS/actions/workflows/shared.yml)

No account, no ads, no tracking: data stays on the device. English, Persian, Arabic, Turkish and German, with right-to-left layouts, native digits, the Solar Hijri (Jalali) calendar and the Iranian toman.

<p>
  <img src="docs/screenshots/ios-en-home.png" width="200" alt="Home: monthly total, ending trials, next 7 days">
  <img src="docs/screenshots/ios-en-insights.png" width="200" alt="Insights: last 12 months and spend by category">
  <img src="docs/screenshots/ios-fa-home.png" width="200" alt="Home in Persian, right to left, in tomans">
  <img src="docs/screenshots/ios-ar-calendar.png" width="200" alt="Calendar in Arabic, week starting Saturday">
</p>

Screenshots are produced by the XCUITest suite in CI, so they always show the current build.

## Features

- **Monthly and yearly totals** across weekly, monthly, yearly or custom cycles, in 7 currencies, converted with your own exchange rates (never guessed).
- **Reminders** N days before a renewal, and a separate warning before a free trial ends.
- **Calendar** in Gregorian or Solar Hijri, with every past and upcoming payment.
- **Insights**: the last 12 months of actual payments, spend by category, most expensive plans, overlapping services.
- **Price history**: a price change applies from its date, so "spent so far" stays correct.
- **Pause, resume, cancel** without losing payment history.
- **Backup and restore** as JSON (compatible with the Android app), export to CSV.

## Architecture

```
Tamdid (SwiftUI app)
 ├─ App/            entry point, RootView, tabs, AppModel (@Observable, @MainActor store)
 ├─ Features/       Home · Subscriptions (list, detail, add/edit form) · Calendar · Insights · Settings · Onboarding
 ├─ Shared/         AppFormat environment, design components, month grid
 └─ Services/       local-notification scheduling
Packages/TamdidKit (Swift package, no UI, builds and tests on Linux too)
 ├─ TamdidCore      renewal dates, money, Jalali calendar, insights, reminder planning, formatting, parsing
 └─ TamdidData      atomic JSON store, backup and CSV codecs
```

- **Swift 6 package** with Swift Testing; app on iOS 17+ with `@Observable`, `NavigationStack`, Swift Charts, String Catalogs.
- **Date-only billing** (`CivilDate`): renewals are computed from the anchor date, so Jan 31 → Feb 28 → Mar 31, with no time-zone bugs.
- **Money in minor units** (`Int64`), formatted and parsed deterministically in five languages ("9,99" and "9.99" both mean 9.99).
- **Shared test vectors** in [`shared/test-vectors`](shared/test-vectors/business-rules.json): the same fixtures run against the [Android app](https://github.com/Ali-Asadi-Dev/tamdid-android)'s Kotlin core, so both apps compute identical results.
- **One translation source** for both apps: [`shared/i18n/translations.json`](shared/i18n/translations.json) → `tools/i18n.py` → String Catalog.

More in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/DESIGN.md](docs/DESIGN.md) and [docs/PRODUCT.md](docs/PRODUCT.md).

## Run

Xcode 16 or later:

```bash
brew install xcodegen
xcodegen generate && open Tamdid.xcodeproj
```

Tests:

```bash
swift test --package-path Packages/TamdidKit   # business rules (also runs on Linux)
xcodebuild test -project Tamdid.xcodeproj -scheme Tamdid -destination 'platform=iOS Simulator,name=iPhone 17'
python3 tools/i18n.py --check                  # every string translated
```

## Android

The Android app (Jetpack Compose, published on Cafe Bazaar) lives in **[Ali-Asadi-Dev/tamdid-android](https://github.com/Ali-Asadi-Dev/tamdid-android)**.

## License

MIT
