# zyppi_ride

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

- Registration flow

/splash  → SplashScreen
│
├── Checks Firebase Authentication State
│   ├── Authenticated → /dashboard → MainDashboard
│   └── Not Authenticated → /auth → AuthScreen
│
└── /auth  → AuthScreen
│
├── Tap “Login” → /login → LoginScreen
│       └── On success → /dashboard → MainDashboard
│
└── Tap “Register” → /register → RegisterScreen
│
├── Create user in FirebaseAuth
├── Save user info to Firestore (/users/{uid})
└── Navigate to RoleSelectionScreen
│
├── Enter Full Name
├── Select Date of Birth
├── Choose Role (e.g., Driver / Customer)
├── Accept Terms & Conditions
└── Navigate → /dashboard → MainDashboard

