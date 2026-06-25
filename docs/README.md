# Zyppi Ride — Documentation

Enterprise documentation for the **Zyppi Ride** Flutter + Firebase ride-hailing platform. All documents in this folder are derived from the actual source code (commit on branch `phase-3-development` as of this generation), not from product specs or assumptions. Where information could not be confirmed from code, it is explicitly marked as such.

Firebase project: `zyppiride-2025` · Android package: `com.zyppiride.app` · Flutter SDK: `^3.9.2`

## Table of Contents

| # | Document | Audience |
|---|---|---|
| 01 | [Executive Summary](01-executive-summary.md) | Client / Stakeholders |
| 02 | [Business Documentation](02-business-documentation.md) | Client / Product |
| 03 | [System Architecture](03-system-architecture.md) | Engineering / Architect |
| 04 | [Flutter Architecture](04-flutter-architecture.md) | Mobile Engineers |
| 05 | [Firebase Architecture](05-firebase-architecture.md) | Backend Engineers |
| 06 | [Firestore Schema](06-firestore-schema.md) | Engineering / DBA |
| 07 | [Authentication & Authorization](07-auth-and-authorization.md) | Engineering / Security |
| 08 | [Push Notifications](08-push-notifications.md) | Engineering |
| 09 | [State Management](09-state-management.md) | Mobile Engineers |
| 10 | [API & Service Layer](10-api-and-service-layer.md) | Mobile Engineers |
| 11 | [Security Audit Report](11-security-audit-report.md) | Security / Engineering |
| 12 | [Deployment Guide](12-deployment-guide.md) | DevOps / Release |
| 13 | [Environment Configuration](13-environment-configuration.md) | DevOps / Engineering |
| 14 | [Testing Documentation](14-testing-documentation.md) | QA / Engineering |
| 15 | [User Manual](15-user-manual.md) | End Users |
| 16 | [Admin Manual](16-admin-manual.md) | Operations / Admin |
| 17 | [Troubleshooting Guide](17-troubleshooting-guide.md) | Support / Engineering |
| 18 | [Future Enhancements](18-future-enhancements.md) | Product / Engineering |
| 19 | [Driver App Flow](19-driver-app-flow.md) | Mobile / QA |
| 20 | [Rider App Flow](20-rider-app-flow.md) | Mobile / QA |
| 21 | [Admin Panel Documentation](21-admin-panel-documentation.md) | Web team / Ops |
| 22 | [Ride Booking Workflow](22-ride-booking-workflow.md) | Engineering / QA |
| 23 | [Driver Assignment Workflow](23-driver-assignment-workflow.md) | Engineering / Product |
| 24 | [Live Tracking Architecture](24-live-tracking-architecture.md) | Engineering |
| 25 | [Notification Flow](25-notification-flow.md) | Engineering / Product |
| 26 | [Fare Calculation](26-fare-calculation.md) | Engineering / Finance |
| 27 | [Firebase Cost Optimization](27-firebase-cost-optimization.md) | Engineering / Finance |
| 28 | [Scalability Assessment (100K+ users)](28-scalability-assessment.md) | Engineering / Leadership |
| 29 | [Production Readiness Report](29-production-readiness.md) | Engineering / Leadership |
| 30 | [Security Vulnerability Assessment](30-security-vulnerability-assessment.md) | Security / Engineering |

## How to use this documentation

- **Client / stakeholder readers** — start with 01, 02, 15. These describe what the platform does and who it serves.
- **New engineer onboarding** — read 03 → 04 → 05 → 09 → 10. By the end you can navigate the code.
- **Security / compliance review** — read 06, 07, 11.
- **Release / DevOps** — read 12, 13.
- **Operations / support** — read 15, 16, 17.

## Source-of-truth note

This documentation is generated from a snapshot of the codebase. Whenever code changes substantively, regenerate the affected document. Areas most prone to drift:

- **Firestore schema** (`06`) — keep in sync with `firestore.rules` and model classes in `lib/models/`.
- **Routes** (`04`) — keep in sync with `lib/router/router.dart` and `lib/router/routes_name.dart`.
- **Security rules** (`07`, `11`) — keep in sync with `firestore.rules` and `storage.rules`.
- **Cloud Functions** (`05`, `08`) — keep in sync with `functions/index.js` and `functions/feedback-suggestion-fun.js`.
