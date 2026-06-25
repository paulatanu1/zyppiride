# 29 — Production Readiness Report

A go/no-go style checklist against the actual state of the codebase. Each item is **PASS** (ready), **PARTIAL** (works but has gaps), or **FAIL** (blocking).

## Verdict summary

**Recommendation:** **NOT YET production-ready for the Play Store.** Two FAIL items (Android release signing, Cloud-function reaper) and several PARTIAL items must be addressed first. None are large; with focused work the gaps can close in ~1–2 weeks.

| Pillar | Status | Headline gap |
|---|---|---|
| Build & release | ❌ FAIL | Release signed with debug keystore |
| Security | ⚠️ PARTIAL | Service-account key not rotated; OTP brute-force only client-side |
| Reliability | ⚠️ PARTIAL | No server-side stale-booking reaper |
| Observability | ❌ FAIL | No crash reporting, no APM, no structured alerting |
| Performance | ⚠️ PARTIAL | Dashboard stats are `O(history)`; live-location collection at risk |
| Documentation | ✅ PASS | This `/docs` set |
| Compliance | ⚠️ PARTIAL | No privacy policy linked; no terms of service screen |
| Testing | ⚠️ PARTIAL | E2E mode exists; coverage thin; no rules-emulator tests |
| Cost controls | ⚠️ PARTIAL | No budget alerts; no aggregate docs |

## 1. Build & release

| Check | Status | Notes |
|---|---|---|
| Production Android keystore | ❌ | `android/app/build.gradle.kts` uses `signingConfigs.getByName("debug")` — Play Store will reject. |
| `key.properties` template documented | ✅ | See [12](12-deployment-guide.md). |
| iOS signing | ❌ | No assets configured in `ios/`. |
| `version` bump policy | ⚠️ | `pubspec.yaml` at `1.0.0+1`; no automated bump. |
| ProGuard / R8 rules | ✅ | `proguard-rules.pro` present. |
| App icons + splash | ⚠️ | `pubspec.yaml` notes `splash_animation.json` is commented out; current splash falls back to icon. |
| Release-build smoke test | ❓ | Should be part of CI. Today only manual. |

**Blocking actions:** generate production keystore, set up `key.properties`, switch `release` block. Then upload a build to the Play Console Internal Testing track.

## 2. Security

| Check | Status | Notes |
|---|---|---|
| Firestore rules — defence-in-depth | ✅ | See [11](11-security-audit-report.md). |
| `isAdmin` self-escalation blocked | ✅ | Server rule rejects any client write including the key. |
| App Check activated | ✅ | Both platforms; release uses Play Integrity / App Attest. |
| App Check **enforced** in Firebase Console | ❓ | Toggle in console after a clean release attests successfully. |
| Service-account key rotated | ❌ | Historic exposure in commit `01b0d30`. Rotate via GCP IAM. |
| Phone-auth resend cooldown | ❌ | Client allows immediate resend (S-03). |
| OTP brute-force protection | ⚠️ | Client-only (3 attempts, 5-min lockout). Move to Cloud Function. |
| Storage size caps on all paths | ⚠️ | `vehicles/` capped at 5 MB; `users/` and `support/` not capped. |
| `users` update key-whitelist | ❌ | Owner can write any field except `isAdmin` + transitioning `verificationStatus` (S-04). |
| HTTPS everywhere | ✅ | Firebase products are HTTPS-only. |
| Secrets in version control | ✅ | Audited; no live secrets after `01b0d30`. |

**Blocking actions:** rotate the service-account key. Strongly recommended before launch: phone-auth resend cooldown, server-side OTP verification, `users` update whitelist, Storage rule tightening.

## 3. Reliability

| Check | Status | Notes |
|---|---|---|
| Offline cache | ✅ | Firestore persistence enabled, 100 MB. |
| Background-message handler | ✅ | Top-level `@pragma('vm:entry-point')` handler registered. |
| Graceful Firebase-init failure | ✅ | `_FirebaseErrorApp` fallback in `main.dart`. |
| Global snackbar key | ✅ | Survives route transitions. |
| Stale-booking reaper | ❌ | `expireOldBookings` is a client method that no-ops without `adminOverride: true`. Move to a scheduled Cloud Function. |
| Service-side OTP attempt counter | ⚠️ | Client-only today. |
| Result<T> error model | ✅ | Used pervasively; clean error path. |
| Idempotent booking creation | ❌ | A double-tap creates duplicate bookings. Add `idempotencyKey` field + check on the dispatcher path. |
| Concurrency control on driver assignment | ❌ | Two riders booking the same driver simultaneously both succeed today. |

## 4. Observability

| Check | Status | Notes |
|---|---|---|
| Crash reporting | ❌ | **Firebase Crashlytics not wired in.** Critical gap. |
| APM / performance traces | ❌ | Firebase Performance not enabled. |
| Structured logs | ✅ | `AppLogger` with tag, level, gated by `kDebugMode`. |
| Cloud Function logs | ✅ | Standard `firebase functions:log`. |
| Analytics | ⚠️ | Only `sign_up` and `login` events emit. No booking funnel events. |
| Budget alerts | ❌ | GCP Console budget alerts not set. |
| Uptime checks | ❌ | No Stackdriver Uptime Check on Cloud Functions. |
| Alerting policy (Slack/email on errors) | ❌ | Not configured. |

**Blocking actions before launch:**
- Add `firebase_crashlytics` to `pubspec.yaml`, initialise in `main.dart`, hook `FlutterError.onError` to it.
- Add `firebase_performance` for HTTP / startup traces.
- Emit at least these analytics events: `booking_created`, `booking_accepted`, `booking_completed`, `booking_cancelled`, `payment_recorded`, `app_open` (auto), `screen_view` (auto).
- Set budget alerts at ₹X / month in GCP Console.

## 5. Performance

| Check | Status | Notes |
|---|---|---|
| Cold-start time on mid-range Android | ❓ | Measure. Target ≤ 3 s to splash. |
| Image cache | ✅ | `cached_network_image` used. |
| Firestore composite indexes | ✅ | ~24 indexes defined. |
| Dashboard `O(history)` reads | ❌ | `getUserStats` / `getDriverStats` load every completed booking. Aggregate doc needed. |
| Live-location write throughput | ⚠️ | 10 m distance filter is reasonable but at 100K scale risks Firestore 500/sec collection throttle (see [28](28-scalability-assessment.md)). |
| autoDispose stream providers | ❓ | Audit needed — leaked snapshots burn reads. |

## 6. Documentation

| Check | Status | Notes |
|---|---|---|
| Code-level docs (`CLAUDE.md`) | ✅ | Comprehensive. |
| User-facing manual | ✅ | [15 — User Manual](15-user-manual.md). |
| Admin / driver manual | ✅ | [16 — Admin Manual](16-admin-manual.md), [19 — Driver Flow](19-driver-app-flow.md). |
| API / schema | ✅ | [06](06-firestore-schema.md), [10](10-api-and-service-layer.md). |
| Deployment runbook | ✅ | [12 — Deployment Guide](12-deployment-guide.md). |
| Troubleshooting | ✅ | [17 — Troubleshooting](17-troubleshooting-guide.md). |

## 7. Compliance & policy

| Check | Status | Notes |
|---|---|---|
| Privacy policy | ❌ | No URL configured in app, no linked screen. **Play Store requires this.** |
| Terms of service | ❌ | Driver agreement exists (`agreements/*`), but no general ToS screen for riders. |
| GDPR-style data deletion path | ❌ | No "Delete my account" flow. Required by Play Store policy 2024+. |
| Data Safety form (Play Console) | ❓ | Must be filled before publishing — declare location, personal info, financial info collection. |
| Permission justification | ❓ | Each `dangerous` permission needs a Play Console disclosure (especially background location if added). |
| Cookies / SDK consent (web) | N/A | Web is not a delivery target. |
| Localised store listings | ❌ | Single language. |

**Blocking for Play Store launch:** privacy policy URL + Data Safety form + account deletion flow.

## 8. Testing

| Check | Status | Notes |
|---|---|---|
| Unit tests for fare math | ❌ | Nothing in `test/` covers `FareCalculator` today. |
| Service-layer mocks | ⚠️ | Mock infrastructure present (`mockito`); coverage low. |
| Widget tests for booking sheet | ❌ | None. |
| Integration / E2E framework | ✅ | `integration_test/` + `E2E_TESTING_DOCUMENTATION.md` + `run_e2e_tests.sh`. |
| Rules-emulator tests | ❌ | Not present. Highest-ROI testing investment. |
| CI pipeline | ❓ | None visible in repo. Add GitHub Actions / Bitrise. |
| Performance regression budget | ❌ | None. |

## 9. Cost controls

| Check | Status | Notes |
|---|---|---|
| Budget alerts | ❌ | Add in GCP Console. |
| Resource caps | ⚠️ | Functions are uncapped by default — set `maxInstances` to prevent runaway billing on attack. |
| Aggregate docs for dashboards | ❌ | Reads scale linearly with user activity today. |
| Live-location frequency review | ⚠️ | Acceptable today; revisit at scale. |
| Storage lifecycle rules | ❌ | Old signatures / receipts never cleaned. |
| Phone-auth quota | ❌ | No daily SMS cap configured. |

## 10. Operational readiness

| Check | Status | Notes |
|---|---|---|
| On-call rotation | ❓ | Define before launch. |
| Incident runbook | ⚠️ | Troubleshooting guide is a start; needs paging integration. |
| Backup strategy (Firestore export) | ❌ | Scheduled exports to Cloud Storage not configured. |
| Disaster-recovery plan | ❌ | Documented RTO/RPO required for any real business. |
| Rollback drill performed | ❌ | Once. Practice rolling back rules + functions + an app version. |
| Customer-support inbox | ⚠️ | Complaints/feedback flow into Firestore; admin UI exists separately. |

## Minimum viable launch checklist (Play Store)

Tightest possible launch path:

1. ✅ Generate production keystore; switch `release` block.
2. ✅ Rotate the Firebase Admin SDK service-account key.
3. ✅ Add Crashlytics + Performance.
4. ✅ Add a privacy policy URL + Data Safety form on Play Console.
5. ✅ Add an "Delete my account" flow (`AuthService.deleteAccount` + Cloud Function to scrub their bookings/vehicles/agreements).
6. ✅ Add `expireOldBookings` Cloud Function (scheduled).
7. ✅ Add Crashlytics-instrumented release-build smoke test.
8. ✅ Set up GCP budget alerts.
9. ✅ Fill in Play Console Data Safety + content rating + screenshots.
10. ✅ Upload to Internal Testing track; soak for ≥ 1 week with real testers.

Estimated effort: **1–2 weeks** of focused work for one engineer plus a designer for store assets.

## Post-launch monitoring (first 30 days)

Watch daily:
- Crashlytics — crash-free user rate (target > 99 %).
- Firebase Performance — startup time, network latency.
- Firestore reads & writes — variance vs forecast.
- Phone Auth SMS spend.
- Support ticket volume by category.
- Active drivers (online) by hour; book/accept ratio.

The first month is when the schema decisions you didn't make show up as bugs. Be ready to ship Hotfix-1 within a week of GA.
