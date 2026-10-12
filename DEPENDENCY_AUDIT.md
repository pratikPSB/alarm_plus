# Dependency audit — pratikPSB/alarm_plus

Date: 2026-10-12 · Branch checked: `main` @ 7420ae3 · Toolchain reference: Flutter stable **3.47.7 / Dart 3.13.5**

Only one repository is connected to this session (`pratikPSB/alarm_plus`), so everything below is grouped by
manifest within it.

> Method note: `dl.google.com` / `maven.google.com` and `api.osv.dev` are blocked by this session's egress
> policy, so AndroidX and AGP "latest" figures come from the official release-notes pages and CVE screening
> was done against the GitHub Advisory Database instead of OSV. Maven Central, pub.dev, services.gradle.org
> and GitHub were reachable directly.

## 1. Security findings

### HIGH PRIORITY — Kotlin Gradle Plugin < 2.4.20 (CVE-2026-53914)

| | |
|---|---|
| Advisory | [GHSA-r937-wjx7-w2jp](https://github.com/advisories/GHSA-r937-wjx7-w2jp) / CVE-2026-53914 |
| Severity | Moderate (JetBrains CVSS 3.1 = 6.7, `AV:L/AC:H/PR:H`); NVD scores it 9.8 — the vector disagreement is noted in the advisory |
| Weakness | CWE-502, unsafe deserialization of Kotlin build-cache metadata → code execution |
| Affected | `org.jetbrains.kotlin:kotlin-gradle-plugin < 2.4.20-Beta1` |
| Fixed in | 2.4.20 (latest stable **2.4.21**) |

Both Kotlin plugin declarations in this repo are in range:

- `android/build.gradle.kts:4` — `kotlinVersion = "2.2.20"` (plugin module buildscript)
- `example/android/settings.gradle.kts:20` — `org.jetbrains.kotlin.android` version `2.3.20`

Exploitation needs local access plus high privileges (a poisoned shared build cache), so practical risk for a
single-maintainer plugin repo is low — but it is the only live advisory hit, so it is the one update worth
doing on its own. Bump both to 2.4.21 and move KSP in the same commit (see §3).

### No other advisories

Screened and clean at the pinned versions: `gson` 2.13.1 (the only Gson advisory, CVE-2022-25647, affects
< 2.8.9), all AndroidX artifacts (`room`, `core-ktx` — no advisories in the database), `kotlinx-coroutines`
(none published), Gradle 9.x (only CVE-2019-11065 / CVE-2019-16370, both pre-5.x), `junit` 4.13.2
(CVE-2020-15250 fixed in 4.13.1), `mockito-core`, and every pub.dev package in use
(`plugin_platform_interface`, `flutter_lints`, `very_good_analysis`, `material_ui`, `cupertino_icons`).
No advisories affect `actions/checkout`, `subosito/flutter-action` or `dart-lang/setup-dart`.

Hardening note, not a vulnerability: all three GitHub Actions are pinned to floating major tags (`@v4`, `@v2`,
`@v1`) rather than commit SHAs, so a tag-move in any of those repos lands in CI automatically.

## 2. Dart / Flutter packages

### `pubspec.yaml` (plugin)

| Package | Constraint | Latest | Type | Notes |
|---|---|---|---|---|
| `plugin_platform_interface` | ^2.1.8 | 2.1.8 | — | up to date |
| `flutter_lints` | ^6.0.0 | 6.0.0 | — | up to date |
| `very_good_analysis` | ^10.3.0 | **11.0.0** | major | No breaking changes labelled. Adds 7 lints (`async_return_with_no_await`, `empty_container_bodies`, `initialize_in_field_declaration`, `unnecessary_const_in_enum_constructor`, `unnecessary_primary_constructor_body`, `unnecessary_type_name_in_constructor`, `use_declaring_parameters`) and automatic trailing commas — expect new analyzer output, and CI runs `flutter analyze --fatal-infos`. **Requires Dart `^3.13.0`**, so adopting it means raising `environment.sdk` from `^3.8.0`, which narrows the plugin's published consumer range. Ties into known issue #10 (raise the Flutter floor to 3.44 for the Swift package). |

### `example/pubspec.yaml`

| Package | Constraint | Locked | Latest | Type | Notes |
|---|---|---|---|---|---|
| `material_ui` | ^1.1.0 | 1.3.0 | **1.6.0** | minor | 1.4.0+ requires Dart `^3.13.0`, while the example declares `sdk: ^3.12.2` — that constraint, not the caret range, is what holds the lock at 1.3.0. Raise the example's SDK floor to `^3.13.0` (stable already ships Dart 3.13.5) and `flutter pub upgrade` picks up 1.6.0. |
| `cupertino_icons` | ^1.0.8 | 1.0.9 | **2.0.0** | major | 2.0.0 moves to the `cupertino_ui` package instead of `flutter/cupertino.dart`; floor is Flutter 3.44 / Dart 3.12. Needs the caret bumped explicitly. Low value here — the example only uses it for the icon font. |
| `flutter_lints` | ^6.0.0 | 6.0.0 | 6.0.0 | — | up to date |

SDK floors for reference: plugin declares `sdk ^3.8.0` / `flutter >=3.3.0`; example declares `sdk ^3.12.2` /
`flutter >=3.47.0`.

## 3. Android — `android/build.gradle.kts` (plugin module)

| Dependency | Current | Latest | Type | Breaking changes / notes |
|---|---|---|---|---|
| `org.jetbrains.kotlin:kotlin-gradle-plugin` | 2.2.20 | **2.4.21** | minor ×2 | **Security — see §1.** |
| `com.android.tools.build:gradle` (classpath) | 8.11.2 | **9.4.0** | major | Requires Gradle ≥ 9.6.0 and JDK 17 (already on 17); max supported API 37. AGP 10 will make the new Variant API mandatory and will fail dynamic-feature flavor mismatches. Also note the mismatch with the example app, which is already on AGP 9.3.2. |
| `com.google.devtools.ksp` | 2.3.4 | **2.3.12** | patch ×8 | KSP has its own version line from 2.3.0 on. 2.3.7 raised the Kotlin target language version to 2.3 and **2.3.12 raises the minimum AGP to 8.12.0** — above this module's 8.11.2 classpath, so bump AGP and KSP together, alongside the Kotlin bump. |
| `androidx.core:core-ktx` | 1.16.0 | **1.19.1** | minor ×3 | 1.17.0 requires KGP ≥ 2.0 (fine). **1.18.0 moved `compileSdk` to API 36.1, while this module sets `compileSdk = 36`** — raise it or the upgrade will not compile. Since 1.19.0 all Kotlin extensions live in `androidx.core:core` and `core-ktx` is an empty compatibility artifact, so this dependency can be switched to `androidx.core:core:1.19.1`. |
| `androidx.room:room-runtime` + `room-compiler` | 2.7.2 | **2.8.5** | minor | 2.8.0 raised Room's minSdk to API 23 (this module is 24, so fine). 2.8.5 makes suspending queries and invalidation-tracker calls throw `IllegalStateException` after the database is closed — **checked: no DAO in `data/` declares `suspend`, so this does not affect the current code.** Also brings a prepared-statement cache and codegen fixes. |
| `com.google.code.gson:gson` | 2.13.1 | **2.14.0** | minor | Behaviour changes: JSON with a repeated key whose *first* value is null is now rejected; integer strings must be ASCII (non-ASCII Unicode digits no longer parse); internal `Type` impls no longer `Serializable`; `com.google.gson.graph` removed. Adds native `java.time` adapters. Only `core/AlarmJson.kt` uses Gson, so blast radius is small. |
| `io.coil-kt:coil` | 2.6.0 | **2.7.0** (2.x) / **3.6.3** (`io.coil-kt.coil3`) | patch / major | 2.7.0 is the end of the 2.x line — a safe patch. Coil 3 is a separate coordinate and package (`coil3`) with an API migration; do not mix 2.x and 3.x in one app. Used only in `runtime/AlarmRingingService.kt` for notification artwork. |
| `org.jetbrains.kotlinx:kotlinx-coroutines-android` | 1.8.1 | **1.11.0** | minor ×3 | 1.9 deprecated `BroadcastChannel` and the old `kotlinx-coroutines-test` APIs; 1.10 moved the debug agent to `kotlinx.coroutines.debug.internal.AgentPremain`; 1.11 deprecates passing a `Job` to coroutine builders and using `CoroutineDispatcher` as a context key. **Checked: the only coroutine usage is `runBlocking` in `AlarmRingingService.kt` (Coil calls), so none of these apply** — a clean upgrade. |
| `org.mockito:mockito-core` | 5.0.0 | **5.24.0** | minor ×24 | Test-only; 5.x has stayed source-compatible. |
| `junit:junit` | 4.13.2 | 4.13.2 | — | Latest of the 4.x line (JUnit 5 is a separate coordinate). |

## 4. Android — example app

| Item | Current | Latest | Type | Notes |
|---|---|---|---|---|
| `org.jetbrains.kotlin.android` | 2.3.20 | **2.4.21** | minor | **Security — see §1.** |
| `com.android.application` (AGP) | 9.3.2 | **9.4.0** | minor | AGP 9.4 requires Gradle ≥ 9.6.0 — pair it with the wrapper bump below. |
| Gradle wrapper | 9.5.0 | **9.8.1** | minor | Current Gradle release (2026-10-07). Needed before AGP 9.4. |
| `org.gradle.toolchains.foojay-resolver-convention` | 0.10.0 | not verified | — | Published to the Gradle Plugin Portal, which this session could not query. |
| `dev.flutter.flutter-plugin-loader` | 1.0.0 | 1.0.0 | — | Flutter-managed. |
| compileSdk / targetSdk | 37 / 37 | — | — | Matches AGP 9.4's max supported API 37. |

## 5. CI (`.github/workflows/`)

| Action | Current | Latest | Type | Notes |
|---|---|---|---|---|
| `actions/checkout` | `@v4` | **v7.0.1** | major ×3 | v7.0.0 moved to ESM and now blocks checking out fork PRs under `pull_request_target` / `workflow_run` — a security improvement that does not affect these push/`pull_request` workflows. v5/v6 also carry a `allow-unsafe-pr-checkout` change flagged BREAKING. |
| `subosito/flutter-action` | `@v2` | v2.23.0 | — | v2 is still the current major; the floating tag already tracks it. |
| `dart-lang/setup-dart` publish workflow | `@v1` | v1.8.1 | — | v1 is still the current major. |

## 6. Suggested order of work

1. **Security first, one commit:** Kotlin 2.2.20 → 2.4.21 (plugin) and 2.3.20 → 2.4.21 (example), plus KSP
   2.3.4 → 2.3.12 and the plugin's AGP classpath 8.11.2 → 9.4.0 (KSP 2.3.12 needs AGP ≥ 8.12.0).
2. **Example toolchain:** Gradle wrapper 9.5.0 → 9.8.1, then AGP 9.3.2 → 9.4.0.
3. **Low-risk runtime bumps:** coroutines 1.11.0, Coil 2.7.0, Gson 2.14.0 (re-check `AlarmJson.kt` against
   the duplicate-key / ASCII-digit changes), Room 2.8.5, mockito 5.24.0.
4. **Needs a compileSdk decision:** `core-ktx` 1.16.0 → `androidx.core:core` 1.19.1 together with
   `compileSdk = 36` → 36.1.
5. **Needs an SDK-floor decision:** `very_good_analysis` 11.0.0 (plugin `sdk ^3.13.0`) and `material_ui` 1.6.0
   (example `sdk ^3.13.0`); `cupertino_icons` 2.0.0 only if the example adopts `cupertino_ui`.
6. **CI:** `actions/checkout@v4` → `@v7`, and consider SHA-pinning all three actions.
