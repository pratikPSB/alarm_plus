# Dependency Audit — alarm_plus

**Date:** 2026-11-02
**Repositories in scope:** `pratikPSB/alarm_plus` (the only repository connected to this session)
**Branch audited:** `claude/nice-curie-ebu7da` @ `7420ae3` (level with `origin/main`)

> Versions were resolved from pub.dev, Maven Central, the Gradle Plugin Portal,
> `developer.android.com`, `kotlinlang.org` and the Flutter release index.
> Nothing was built or test-resolved — no Flutter/Gradle toolchain is available in
> this environment — so every upgrade below still needs a local build + `flutter test`
> before it lands.

---

## 1. Security advisories

### HIGH PRIORITY — CVE-2026-53914 (Kotlin Gradle plugin, 2 occurrences)

| Field | Value |
|---|---|
| Advisory | [GHSA-r937-wjx7-w2jp](https://github.com/advisories/GHSA-r937-wjx7-w2jp) / CVE-2026-53914 |
| Package | `org.jetbrains.kotlin:kotlin-gradle-plugin` |
| Severity | Moderate — CVSS 3.1 score **6.7** (`AV:L/AC:H/PR:H/UI:N/S:C/C:H/I:L/A:L`) |
| Weakness | CWE-502, unsafe deserialization of Kotlin **build-cache** metadata → code execution |
| Affected | `< 2.4.20-Beta1` |
| First patched | `2.4.20-Beta1` (latest stable: **2.4.21**) |
| EPSS | 0.333% (27th percentile) |

Both Kotlin plugin pins in this repository fall inside the affected range:

| File | Line | Current | Vulnerable? |
|---|---|---|---|
| `android/build.gradle.kts` | 5 (`val kotlinVersion`, buildscript classpath) | `2.2.20` | **yes** |
| `example/android/settings.gradle.kts` | 24 (`org.jetbrains.kotlin.android`) | `2.3.20` | **yes** |

**Scope of the risk.** This is a *build-time* issue, not a runtime vulnerability in
the shipped plugin or in apps that depend on it. Exploitation needs local access and
high privileges, so the realistic exposure is a developer workstation or CI runner
that reads a **shared or remote Kotlin build cache** that an attacker can write to.
A solo developer with a local-only cache is at low practical risk; a team with a
remote build cache should treat it as real.

**Remediation.** Raise both pins to Kotlin **2.4.21**. KSP versioning in the 2.x line
is decoupled from the Kotlin version — the official Kotlin docs pair Kotlin `2.4.21`
with KSP `2.3.10` — so bumping Kotlin does not force a KSP bump, though `2.3.13` is
current. Note that for a Flutter plugin module the host app's Kotlin plugin usually
wins at build time, which makes the **example app's `2.3.20` the more impactful of
the two**; the plugin's own pinned classpath should still be raised for correctness.

### Checked and NOT affected

| Dependency | Current | Advisory considered | Why not affected |
|---|---|---|---|
| `com.google.code.gson:gson` | 2.13.1 | GHSA-4jrv-ppp4-jm57 / CVE-2022-25647 (High) | fixed in 2.8.9 |
| `junit:junit` | 4.13.2 | GHSA-269g-pwp5-87pp / CVE-2020-15250 (Moderate) | fixed in 4.13.1 |
| `org.jetbrains.kotlin:kotlin-stdlib` | 2.x (transitive) | CVE-2020-29582, CVE-2022-24329 | fixed in 1.4.21 / 1.6.0 |
| `androidx.room:*`, `androidx.core:*`, `io.coil-kt:coil`, `org.mockito:mockito-core`, `kotlinx-coroutines-android` | — | — | no advisories found |
| Pub deps (`plugin_platform_interface`, `flutter_lints`, `very_good_analysis`, `material_ui`, `cupertino_icons`) | — | 13 Pub-ecosystem advisories reviewed | none match these packages |

**Coverage caveat.** The OSV API (`api.osv.dev`), deps.dev and GitHub's advisory
REST/GraphQL endpoints are all blocked by this session's egress policy. Advisory data
above came from the `github.com/advisories` **web UI**, which is keyword-searched
rather than range-matched, so this is a good-faith sweep and not an exhaustive scan.
Re-run with `flutter pub audit` / `gradle dependencyCheck` / Dependabot for authoritative
coverage.

---

## 2. Dart / pub — plugin root (`pubspec.yaml`)

| Dependency | Current | Latest | Type | Notes |
|---|---|---|---|---|
| `plugin_platform_interface` | `^2.1.8` | 2.1.8 | — | up to date |
| `flutter_lints` | `^6.0.0` | 6.0.0 | — | up to date |
| `very_good_analysis` | `^10.3.0` | **11.0.0** | **major** | 11.0.0 requires Dart SDK `^3.13.0`; 10.3.0 already requires `^3.12.0` |

**SDK floor inconsistency.** `environment.sdk: ^3.8.0` and `flutter: '>=3.3.0'` are
both far below what the tree actually needs: `very_good_analysis` 10.3.0 requires Dart
`^3.12.0`, and the iOS Swift Package needs Flutter 3.44+ (already logged as known issue
#10 in `AGENTS.md`). Latest Flutter stable is **3.47.9** (Dart 3.13.7, 2026-10-29).
Resolution on a declared-minimum SDK would fail today. Fixing the floor is a
prerequisite for the `very_good_analysis` 11.0.0 bump, and it is a **breaking change
for consumers** of the published plugin.

---

## 3. Dart / pub — example app (`example/pubspec.yaml`)

| Dependency | Constraint | Resolved | Latest | Type | Notes |
|---|---|---|---|---|---|
| `material_ui` | `^1.1.0` | **1.3.0** | **1.9.0** | minor (6 releases behind) | Publisher is `flutter.dev` (official). 1.4.0+ requires Dart `^3.13.0` / Flutter `>=3.47.0`; the example declares `sdk: ^3.12.2`, which is what pins resolution to 1.3.0 |
| `cupertino_icons` | `^1.0.8` | 1.0.9 | **2.0.0** | **major** | 2.0.0 requires Dart `^3.12.0`, so it is already compatible — only the constraint needs widening to `^2.0.0` |
| `flutter_lints` | `^6.0.0` | 6.0.0 | 6.0.0 | — | up to date |

**One-line fix for most of this section:** the example declares
`flutter: '>=3.47.0'` but `sdk: ^3.12.2`, and Flutter 3.47.0 ships Dart 3.13.x.
Raising the example's `sdk` to `^3.13.0` makes the two consistent and unblocks
`material_ui` 1.9.0 in a single step.

---

## 4. Android — build toolchain

| Item | File | Current | Latest | Type |
|---|---|---|---|---|
| `org.jetbrains.kotlin:kotlin-gradle-plugin` | `android/build.gradle.kts` | 2.2.20 | **2.4.21** | minor — **security, see §1** |
| `org.jetbrains.kotlin.android` | `example/android/settings.gradle.kts` | 2.3.20 | **2.4.21** | minor — **security, see §1** |
| `com.android.tools.build:gradle` (AGP) | `android/build.gradle.kts` | 8.11.2 | **9.5.x** | **major** |
| `com.android.application` (AGP) | `example/android/settings.gradle.kts` | 9.3.2 | **9.5.0** | minor |
| `com.google.devtools.ksp` | `android/build.gradle.kts` | 2.3.4 | **2.3.13** | patch |
| Gradle wrapper | `example/android/gradle/wrapper/gradle-wrapper.properties` | 9.5.0 | **9.8.2** | minor |
| `org.gradle.toolchains.foojay-resolver-convention` | `example/android/settings.gradle.kts` | 0.10.0 | **1.0.0** | **major** |

**Two things worth acting on here beyond the version numbers:**

1. **AGP is pinned inconsistently across the two modules** — 8.11.2 in the plugin's
   buildscript classpath vs 9.3.2 in the example. The plugin's own classpath is
   largely inert when the plugin is consumed by a host app (the host's
   `pluginManagement` resolves AGP), but the stale pin is misleading and is the same
   block that carries the vulnerable Kotlin pin.
2. **AGP 9.5 requires Gradle ≥ 9.6.0.** The example's wrapper is on 9.5.0, so an AGP
   bump to 9.5.x must be paired with a wrapper bump (9.8.2 is current). Do not bump
   one without the other.

---

## 5. Android — libraries (`android/build.gradle.kts`)

| Dependency | Current | Latest | Type | Breaking changes / notes |
|---|---|---|---|---|
| `androidx.room:room-runtime` + `room-compiler` | 2.7.2 | **2.8.5** | minor | See the behavior change below — **read before upgrading** |
| `org.jetbrains.kotlinx:kotlinx-coroutines-android` | 1.8.1 | **1.11.0** | minor (3 releases behind) | no breaking changes flagged |
| `org.mockito:mockito-core` | 5.0.0 | **5.24.0** | minor (24 releases behind) | test-only |
| `com.google.code.gson:gson` | 2.13.1 | **2.15.0** | minor | — |
| `io.coil-kt:coil` | 2.6.0 | **2.7.0** | patch | Coil 3.x exists as **`io.coil-kt.coil3:coil` 3.6.3** — new group id, package rename, breaking API. 2.7.0 is the zero-risk hop |
| `androidx.core:core-ktx` | 1.16.0 | **1.19.1** | minor | **Deprecated artifact:** the Kotlin APIs were merged into `androidx.core:core` in 1.19.0; `core-ktx` is now an empty compatibility shim. Migrate the coordinate to `androidx.core:core:1.19.1` |
| `junit:junit` | 4.13.2 | 4.13.2 | — | up to date (final JUnit 4 release) |
| `org.jetbrains.kotlin:kotlin-test` | unversioned | 2.4.21 | — | tracks the Kotlin plugin version |

### Room 2.7.2 → 2.8.5 — behavior change that matters for this plugin

Room **2.8.5** makes suspending queries and `InvalidationTracker` operations throw
`IllegalStateException` when they are called **after the database has been closed**.
Code that previously failed silently now crashes.

That is directly relevant to `alarm_plus`: `AlarmRepository`, `AlarmBootReceiver` and
the `AlarmRingingService` shutdown path all run DAO calls from a coroutine scope whose
lifetime is tied to a receiver or service that the OS can tear down mid-flight. Audit
those call sites for queries that can outlive the database before taking this upgrade.

Two other 2.8.0 changes were checked and are **not** blockers here:
`minSdk` rose to 23 (this module is on 24) and the Room Gradle Plugin now needs
AGP 8.4+ (this module declares 8.11.2).

---

## 6. CI — GitHub Actions

| Action | Current | Latest | Type | Used in |
|---|---|---|---|---|
| `actions/checkout` | `v4` | **v7.0.1** | **major** (3 majors behind) | `flutter_ci.yml`, `release_validation.yml` |
| `subosito/flutter-action` | `v2` | v2.23.0 | — | `flutter_ci.yml`, `release_validation.yml` — floating `v2` tag is current |
| `dart-lang/setup-dart/.github/workflows/publish.yml` | `v1` | v1 | — | `publish.yml` |

**No `.github/dependabot.yml` exists**, so nothing is currently watching any of
these ecosystems automatically. Adding Dependabot for `pub`, `gradle` and
`github-actions` would have surfaced the Kotlin CVE without a manual sweep.

---

## 7. Suggested order of work

1. **Kotlin `2.2.20`/`2.3.20` → `2.4.21`** in both files — the only security item (§1).
2. Add `.github/dependabot.yml` for `pub`, `gradle` and `github-actions` so this
   sweep does not have to be manual.
3. `actions/checkout@v4` → `@v7` — trivial, and v4 is three majors behind.
4. Low-risk library bumps: `coroutines` 1.11.0, `gson` 2.15.0, `mockito-core` 5.24.0,
   `coil` 2.7.0, `ksp` 2.3.13.
5. `androidx.core:core-ktx:1.16.0` → `androidx.core:core:1.19.1` (coordinate change).
6. **Room 2.8.5** — only after auditing the closed-database call sites described in §5.
7. Example app: raise `sdk` to `^3.13.0`, then `material_ui` `^1.9.0` and
   `cupertino_icons` `^2.0.0`.
8. Gradle wrapper 9.8.2 + AGP 9.5.x together, and reconcile the plugin module's
   stale 8.11.2 pin.
9. Plugin SDK floor (`sdk: ^3.8.0`, `flutter: '>=3.3.0'`) — breaking for consumers,
   so bundle it with the next minor release and with `very_good_analysis` 11.0.0.
