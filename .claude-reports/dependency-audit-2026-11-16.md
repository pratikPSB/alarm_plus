# Dependency Audit — pratikPSB/alarm_plus
**Date:** 2026-11-16 · **Branch:** `claude/nice-curie-cammvf` · **HEAD:** `7420ae3`

One repository is connected (`pratikPSB/alarm_plus`), covering four dependency surfaces: Dart/pub
(plugin + example), Android/Gradle (plugin + example), iOS (SwiftPM/CocoaPods), and GitHub Actions.

---

## 1. Security — action recommended

### CVE-2026-53914 — Kotlin Gradle Plugin (build-time code execution)

| | |
|---|---|
| Advisory | [GHSA-r937-wjx7-w2jp](https://github.com/advisories/GHSA-r937-wjx7-w2jp) / [CVE-2026-53914](https://nvd.nist.gov/vuln/detail/CVE-2026-53914) |
| Package | `org.jetbrains.kotlin:kotlin-gradle-plugin` |
| Vulnerable | `< 2.4.20-Beta1` |
| Patched | `2.4.20-Beta1` (latest stable: **2.4.21**) |
| Severity | GitHub: **Moderate, CVSS 6.7** · NVD: **Critical, 9.8** (JetBrains classes it as medium) |
| Weakness | CWE-502 — unsafe deserialization of build-cache metadata allows code execution |

**Both Kotlin pins in this repo are affected:**

| File | Line | Current | Target |
|---|---|---|---|
| `android/build.gradle.kts` | 4 (`val kotlinVersion`) | `2.2.20` | `2.4.21` |
| `example/android/settings.gradle.kts` | 21 (`org.jetbrains.kotlin.android`) | `2.3.20` | `2.4.21` |

**Real-world exposure:** the attack path is a tampered or poisoned **shared/remote Gradle build
cache**, so it matters most on CI and shared caches, not on a clean local build. This repo's CI
(`.github/workflows/flutter_ci.yml`) does not configure a remote build cache today, which lowers
the practical risk — but anyone consuming the plugin builds it with the Kotlin version resolved in
their own project, so keeping the pin current is still the right call.

### Not affected (checked)

- **Gradle wrapper 9.5.0** (`example/android/gradle/wrapper/gradle-wrapper.properties`) — the two
  January 2026 Gradle dependency-resolution CVEs, [CVE-2026-22816](https://nvd.nist.gov/vuln/detail/CVE-2026-22816)
  and [CVE-2026-22865](https://nvd.nist.gov/vuln/detail/CVE-2026-22865) (high), affect **≤ 9.2.x**
  and were fixed in 9.3.0. 9.5.0 is clear.
- **No advisories found** for: `androidx.core:core-ktx`, `androidx.room:*`,
  `com.google.code.gson:gson`, `io.coil-kt:coil`, `org.jetbrains.kotlinx:kotlinx-coroutines-android`,
  `org.mockito:mockito-core`, `junit:junit`, `com.android.tools.build:gradle`, or any of the pub
  packages (`plugin_platform_interface`, `flutter_lints`, `very_good_analysis`, `material_ui`,
  `cupertino_icons`).
- **iOS** declares no third-party dependencies — only the Flutter framework (`Package.swift`,
  `alarm_plus.podspec`), so there is no iOS dependency attack surface to audit.

> **Method caveat.** The OSV batch API (`api.osv.dev`), the GitHub global advisories API
> (`/advisories`, blocked to repo-scoped endpoints in this session) and Google's Maven mirror
> (`maven.google.com` / `dl.google.com`) were all unreachable from this sandbox. Advisory coverage
> was therefore assembled from the GitHub Advisory Database web UI, NVD and targeted search rather
> than from a batch scanner, and AndroidX versions came from Google's published stable-channel page.
> A `flutter pub outdated` / `gradle dependencyUpdates` run on an unrestricted network would be a
> useful cross-check. No Flutter/Dart toolchain is installed here either, so pub resolution was read
> from the pub.dev API rather than resolved.

---

## 2. Android — plugin module (`android/build.gradle.kts`)

| Dependency | Current | Latest | Type | Notes |
|---|---|---|---|---|
| `org.jetbrains.kotlin:kotlin-gradle-plugin` | 2.2.20 | **2.4.21** | minor ×2 | **Security — see §1.** Crosses two language releases; expect new warnings/deprecations. |
| `com.android.tools.build:gradle` (AGP) | 8.11.2 | **9.5.1** | **major** | AGP 9.x enables **built-in Kotlin support by default** and max API level is 37; AGP 9.5 needs **Gradle ≥ 9.6.0** and JDK 17. Note the example app is already on AGP 9.3.2 — the plugin module's buildscript pin is a full major version behind it. |
| `com.google.devtools.ksp` | 2.3.4 | **2.3.14** | patch | KSP decoupled its versioning from Kotlin at 2.3.0, so 2.3.x is not tied to Kotlin 2.3. ⚠️ **KSP 2.3.12+ raises the minimum AGP to 8.12.0** — so this bump requires the AGP bump above (or stopping at 2.3.11). |
| `androidx.room:room-runtime` + `room-compiler` | 2.7.2 | **2.8.5** (2026-09-09) | minor | Bump both together — runtime and compiler must match. Room 2.8 assumes a Kotlin 2.0+ language level. |
| `androidx.core:core-ktx` | 1.16.0 | **1.19.1** (2026-09-23) | minor ×3 | Since 1.18.0, core requires **KGP 2.0.0+** (Kotlin 2.0 language level) — satisfied here. Adds `NotificationCompat` extensions relevant to this plugin's notification path. |
| `org.jetbrains.kotlinx:kotlinx-coroutines-android` | 1.8.1 | **1.11.0** | minor ×3 | Three minor releases of deprecation removals across 1.9/1.10/1.11 — verify the `AlarmRepository`/DAO coroutine scopes still compile cleanly. |
| `com.google.code.gson:gson` | 2.13.1 | **2.15.0** | minor ×2 | Low-risk; used only in `core/AlarmJson.kt`. |
| `io.coil-kt:coil` | 2.6.0 | **2.7.0** (2.x line) | minor | 2.7.0 is a drop-in. The active line is now **`io.coil-kt.coil3:coil` 3.6.3** — a major rewrite with **changed coordinates and package names** (`coil3.*`); treat as a migration, not a bump. |
| `org.mockito:mockito-core` | 5.0.0 | **5.24.0** | minor ×24 | Test-only, and 5.0.0 dates to Jan 2023. Newer byte-buddy = better modern-JDK support. Cheapest win here. |
| `junit:junit` | 4.13.2 | 4.13.2 | — | ✅ Current (JUnit 4 is feature-frozen; JUnit 5 `junit-jupiter` is at 6.1.3 if you ever migrate). |

## 3. Android — example app

| Item | File | Current | Latest | Type |
|---|---|---|---|---|
| Gradle wrapper | `example/android/gradle/wrapper/gradle-wrapper.properties` | 9.5.0 | **9.9.1** (2026-11-10) | minor ×4 |
| `com.android.application` | `example/android/settings.gradle.kts:20` | 9.3.2 | **9.5.1** | minor ×2 (needs Gradle ≥ 9.6.0) |
| `org.jetbrains.kotlin.android` | `example/android/settings.gradle.kts:21` | 2.3.20 | **2.4.21** | **security — §1** |
| `org.gradle.toolchains.foojay-resolver-convention` | `example/android/settings.gradle.kts:22` | 0.10.0 | 0.10.0 | ✅ current |
| `dev.flutter.flutter-plugin-loader` | `example/android/settings.gradle.kts:19` | 1.0.0 | 1.0.0 | ✅ pinned by Flutter |

## 4. Dart / pub

**Plugin (`pubspec.yaml`)**

| Dependency | Constraint | Latest | Type | Notes |
|---|---|---|---|---|
| `plugin_platform_interface` | ^2.1.8 | 2.1.8 | — | ✅ Current (unchanged since 2024-01). |
| `flutter_lints` | ^6.0.0 | 6.0.0 | — | ✅ Current. |
| `very_good_analysis` | ^10.3.0 | **11.0.0** (2026-09-03) | **major** | ⚠️ 11.0.0 requires **Dart `^3.13.0`**, but this package declares `sdk: ^3.8.0`. Taking it forces the SDK floor up and will surface new lints as `flutter analyze --fatal-infos` failures in CI. |

**Example (`example/pubspec.yaml`)**

| Dependency | Constraint | Latest | Type | Notes |
|---|---|---|---|---|
| `material_ui` | ^1.1.0 | **1.11.1** (released today) | minor ×10 | Inside the existing caret range — `flutter pub upgrade` picks it up; worth pinning the floor higher. |
| `cupertino_icons` | ^1.0.8 | **2.0.0** (2026-09-29) | **major** | Requires Dart `^3.12.0`; the example declares `^3.12.2`, so it fits. Icon/font-set changes mean glyph names can move. |

**SDK constraint drift (not a dependency, but it bites the same way)**

- Plugin declares `flutter: '>=3.3.0'` / `sdk: ^3.8.0`; the example requires `flutter: '>=3.47.0'` /
  `sdk: ^3.12.2`. Current stable is **Flutter 3.50.0 / Dart 3.14.0** (2026-11-11).
- `AGENTS.md` known-issue #10 already tracks raising the plugin floor to Flutter 3.44, which
  `ios/alarm_plus/Package.swift` effectively requires via its `FlutterFramework` path dependency.
  The published `>=3.3.0` floor is not actually buildable.

## 5. GitHub Actions

| Action | Files | Current | Latest | Type |
|---|---|---|---|---|
| `actions/checkout` | `flutter_ci.yml:16`, `release_validation.yml:13` | **v4** | **v7.0.1** | **major ×3** — v5/v6/v7 are Node-runtime bumps (through Node 24) and need a reasonably recent runner; `ubuntu-latest` is fine. |
| `subosito/flutter-action` | `flutter_ci.yml:18`, `release_validation.yml:15` | v2 | v2.23.0 | ✅ latest major; the floating `@v2` tag already tracks it. |
| `dart-lang/setup-dart/.github/workflows/publish.yml` | `publish.yml:11` | v1 | v1 | ✅ current; `@v1` is the intended pin for pub.dev OIDC publishing. |

## 6. iOS

No third-party dependencies. `Package.swift` (swift-tools 5.9, iOS 15.0) and `alarm_plus.podspec`
(iOS 15.0, Swift 5.0) depend only on the Flutter framework and system frameworks
(UserNotifications, AVFoundation, AlarmKit on 26+). Nothing to update — though `AGENTS.md`
known-issue #8 notes the podspec's `homepage` and `author` fields are still wrong.

---

## Recommended order

1. **Kotlin 2.2.20 / 2.3.20 → 2.4.21** in both Gradle files — the only security-driven change. Do it on its own commit so it is easy to verify and revert.
2. **Cheap, low-risk bumps:** `mockito-core` 5.24.0, `gson` 2.15.0, `coil` 2.7.0 (stay on 2.x), `core-ktx` 1.19.1, `room` 2.8.5 (runtime + compiler together), `kotlinx-coroutines-android` 1.11.0.
3. **Toolchain, as one coordinated change:** Gradle wrapper 9.9.1 → AGP 9.5.1 (plugin buildscript **and** example) → KSP 2.3.14. These three are interlocked: AGP 9.5 needs Gradle ≥ 9.6.0, and KSP 2.3.12+ needs AGP ≥ 8.12.0. Also unifies `compileSdk` (36 in the plugin vs 37 in the example).
4. **Deferred / decide first:** `very_good_analysis` 11.0.0 and the Flutter/Dart SDK floor — these move the published floor and belong with known-issue #10. `cupertino_icons` 2.0.0 is example-only and safe whenever. `coil3` is a migration, not an update.

CI has no automated dependency monitoring. A `.github/dependabot.yml` covering `pub`, `gradle` and
`github-actions` would have surfaced the Kotlin CVE on its own.
