# Handoff log

> Working notes for whoever (human or AI) continues this project. Delete this file once it has served its purpose; the permanent docs live in `docs/`.

## What this is

Tamdid (تمدید, "renewal") is a free, open-source subscription tracker built as a portfolio project for **Ali Asadi** (Senior iOS Engineer, GitHub `Ali-Asadi-Dev`) and as a free app for the Iranian Android store **Cafe Bazaar**. Two native apps share rules through test fixtures, not code. Five languages: en, fa, ar, tr, de.

**Repositories (split on 2026-11-20; the original `tamdid` monorepo is superseded):**
- `Ali-Asadi-Dev/tamdid-IOS` — this repo, **iOS only** (SwiftUI app at the root, `Packages/TamdidKit`). The portfolio piece.
- `Ali-Asadi-Dev/tamdid-android` — Android (Compose), history preserved from the monorepo.
- `shared/test-vectors/business-rules.json`, `shared/catalog.json` (Android: `shared/catalog/catalog.json`) and `shared/i18n/translations.json` exist in **both** repos and must stay identical. Change a rule in both, run both test suites.

Owner's goals, in their words: a "free version of paid apps", professional enough for a job search, with Android on Bazaar. They want every step tested "like a QA", with screenshots.

## Status (end of first session, 2026-11-20)

| Area | State | Verified how |
|---|---|---|
| `TamdidKit` (Swift core + storage) | Done | `swift test` on Linux: 61 tests, all vectors |
| Android `:core` | Done | JUnit: 28 tests, same vectors |
| Android app (all v1 screens, reminders, 5 languages, dark mode) | Done | 20 JVM tests incl. Robolectric UI tests with screenshots; lint 0 warnings; debug + release APK build |
| iOS app (all v1 screens, reminders, 5 languages) | Done; **compiles and passes on Xcode 26.6** in CI | Not yet run by a human on a device. CI runs unit tests (Swift Testing) and XCUITest screenshot tours; screenshots are pushed to the `ci-screenshots` branch |
| CI | `shared.yml`, `android.yml`, `ios.yml` | See Actions tab |
| Docs | README, docs/PRODUCT, ARCHITECTURE, DESIGN | — |

## First things to do on the Mac

1. `git clone https://github.com/Ali-Asadi-Dev/tamdid-IOS && cd tamdid-IOS` (and `tamdid-android` for Android)
2. Check the latest **iOS** workflow run on GitHub (it should be green). Screenshots from the UI tests are on the `ci-screenshots` branch.
3. `brew install xcodegen && xcodegen generate && open Tamdid.xcodeproj`, then run on a simulator. Set your Team under Signing to run on a device.
4. Android: open the `tamdid-android` repo in Android Studio, or `./gradlew :app:installDebug`.
5. Consider committing the generated `Tamdid.xcodeproj` (currently git-ignored) if you prefer opening the project without XcodeGen.

## Repository map

```
Packages/TamdidKit/Sources/TamdidCore   CivilDate, Jalali, Money(+Formatter), Language, Subscription, Billing,
                                            AppData(+settings, converter), Insights(+ReminderPlanner), CalendarDisplay, Catalog
Packages/TamdidKit/Sources/TamdidData   FileStore (atomic JSON), BackupCodec (JSON, CSV)
Tamdid/App                              TamdidApp (entry, RootView, tabs, navigation), AppModel (@Observable store), SampleData
Tamdid/Features/*                       Home, Subscriptions (list/detail/edit/add flow), Calendar, Insights, Settings, Onboarding
Tamdid/Shared                           AppFormat (environment), Components, MonthGridView
Tamdid/Services/ReminderScheduler.swift UNUserNotificationCenter scheduling of the shared plan
project.yml                             XcodeGen spec (bundle id com.aliasadi.tamdid, iOS 17+)
shared/test-vectors/business-rules.json     Fixtures BOTH test suites run. Add a case here first when changing a rule.
shared/catalog.json                         31 preset services, en/fa names, no logos
shared/i18n/translations.json               All UI text; run `python3 tools/i18n.py` after editing
tools/i18n.py                               Generates Localizable.xcstrings (the Android repo has its own copy for XML)
```

## Conventions

- **Changing a business rule:** add or adjust a case in `shared/test-vectors/business-rules.json`, then change Swift and Kotlin until both suites pass.
- **Adding UI text:** use English in code (Swift literal / Android `values/strings.xml`), add the translations to `shared/i18n/translations.json`, run `python3 tools/i18n.py`. CI runs `--check`.
- Money is always minor units (`Int64`/`Long`). Dates in rules are date-only (`CivilDate`/`LocalDate`).
- Format money and dates only through `MoneyFormatter` and `DateText` (never platform formatters), so both apps print the same.
- Persian is the reference RTL language; Arabic uses Arabic-Indic digits.

## Decisions worth knowing

- Renewal dates are computed from the anchor (`trialEnd ?? start`), never by repeated addition.
- Cancelled/paused: `endDate` is the last day a charge can happen (inclusive). Resume moves the payments so far into `pastCharges` (date + amount) and restarts the series on the resume day; `payments(from:to:)` merges both for totals, the chart and the calendar.
- Price history: `priceHistory` holds earlier prices with their start dates; `currentPriceSince` is when the current price started. Changing currency on edit is a correction (history cleared).
- Monthly totals include active trials (they'll charge unless cancelled). Currencies without a user-entered rate are reported separately, never guessed.
- Reminders: planner caps at 60 (iOS limit 64), fires at `reminderHour` (09:00). Android uses inexact alarms (no exact-alarm permission needed) plus a receiver for boot / time change / app update.
- Per-app language: Android uses `AppCompatDelegate.setApplicationLocales` (in-app picker); iOS uses the system Settings → Tamdid → Language (button opens it).
- Android package and iOS bundle id: `com.aliasadi.tamdid`. **Bazaar package names are permanent**, so decide before the first upload.

## Environment notes from the first session (cloud Linux container)

- Swift 6.3.1 toolchain installed from download.swift.org to `/opt/tools/swift`; Android SDK 36 to `/opt/android-sdk`. The cloud environment "Tamdid (iOS + Android builds)" allows `dl.google.com` and `download.swift.org`.
- Maven Central redirected large files to a blocked host; `~/.gradle/init.d/maven-mirror.gradle` (container-local, not in the repo) put Google's Maven Central mirror first and pointed Robolectric at it. Not needed on a normal machine.
- Building XcodeGen on Linux was not permitted, so the `.xcodeproj` is generated in CI / on the Mac.
- The session could not create GitHub repos or change repo settings; the owner created the repositories. The original monorepo `Ali-Asadi-Dev/tamdid` was split into `tamdid-IOS` and `tamdid-android` (history kept in both) and can be archived or deleted.

## QA review log (first session)

Bugs found by reading every rule line by line and fixed, each with a regression test on both platforms:

1. **Decimal commas** — "9,99" was saved as 999.00 for German/Turkish users. New parser + 29 shared vectors (`parse`).
2. **Pause/resume lost history** — earlier payments vanished from the 12-month chart and calendar. Now kept in `pastCharges`.
3. **Same-day resume double charge** — resuming on the pause day counted that day twice. `resume` now closes the old series the day before.
4. **Corrupt backups** — interval 0 hung iOS (infinite loop); reminder hour 27 crashed Android scheduling. Rejected / clamped.
5. **Negative reminder days** scheduled reminders after the charge. Ignored now.
6. **Kotlin number separators** for ar/tr/de were wrong (caught by the shared vectors when languages were added).
7. **Android "today" frozen** at app start, so relative dates went stale past midnight.

Accepted limitations: a reminder whose time already passed today is skipped (not sent late); editing a price with an
effective date earlier than the last change overwrites rather than inserts (the UI always uses today).

## Known gaps / next steps

1. **Verify the iOS build** (see above) and look at the UI-test screenshots in the `ios-results` artifact.
2. iOS screenshots for the README (Android ones are in `docs/screenshots`).
3. Bazaar release: create a release keystore (keep it backed up!), add `keystore.properties` (git-ignored) in the tamdid-android repo with `storeFile`, `storePassword`, `keyAlias`, `keyPassword`, then `./gradlew :app:assembleRelease`. Bazaar needs Persian store text and screenshots; `UiTest` already produces Persian ones.
4. v2 ideas from `docs/PRODUCT.md`: widgets, app lock, iCloud/Drive sync, bundled Vazirmatn font, Shortcuts.
5. Optional polish: Android app is ~2 MB release; the debug APK is large because of `material-icons-extended` (R8 strips it in release).
