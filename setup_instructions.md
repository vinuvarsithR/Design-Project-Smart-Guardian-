# SmartGuardian — Setup Instructions

## Prerequisites

| Tool | Version | Download |
|---|---|---|
| Flutter SDK | >=3.0.0 | https://flutter.dev/docs/get-started/install |
| Dart SDK | >=3.0.0 | Included with Flutter |
| Android Studio | Latest | https://developer.android.com/studio |
| Firebase CLI | Latest | `npm install -g firebase-tools` |
| Git | Any | https://git-scm.com |

---

## Step 1 — Clone the Repository

```bash
git clone https://github.com/vinuvarsithR/Design-Project-Smart-Guardian-.git
cd Design-Project-Smart-Guardian-/src
```

---

## Step 2 — Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Open project **smartguardian-113d2**
3. Download `google-services.json` → place in `src/android/app/`
4. Enable the following in Firebase Console:
   - Authentication → Email/Password
   - Cloud Firestore → production mode
   - Cloud Messaging (for push notifications)

### Firestore Security Rules

Publish the following rules in Firestore Console → Rules:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
        && request.resource.data.guardianId == request.auth.uid;
      allow update: if request.auth != null
        && (resource.data.guardianId == request.auth.uid
            || resource.data.monitoredUid == request.auth.uid);
      allow delete: if request.auth != null
        && resource.data.guardianId == request.auth.uid;
    }
    match /alerts/{alertId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null
        && resource.data.guardianId == request.auth.uid;
    }
    match /guardians/{uid} {
      allow read, write: if request.auth != null
        && request.auth.uid == uid;
    }
  }
}
```

### Firestore Composite Indexes

Create these indexes in Firestore Console → Indexes:

| Collection | Fields |
|---|---|
| users | guardianId ↑, createdAt ↑ |
| alerts | guardianId ↑, createdAt ↓ |
| alerts | guardianId ↑, isRead ↑, createdAt ↓ |
| alerts | userId ↑, createdAt ↓ |
| alerts | userId ↑, type ↑, isResolved ↑ |

---

## Step 3 — Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Enable **Maps SDK for Android**
3. Create an API key
4. Add it to `src/android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY_HERE"/>
```

---

## Step 4 — Install Dependencies

```bash
cd src
flutter pub get
```

---

## Step 5 — Run the App

```bash
# Connect an Android device or start an emulator
flutter run
```

---

## Step 6 — Create Test Accounts

### Guardian account
1. Open app → Sign Up → use any email/password
2. This account sees the Dashboard / Map / Alerts

### Patient account
1. Open app on a second device or emulator → Sign Up → use a different email
2. In Firestore Console → `users` collection → find the patient's document
3. Add field: `monitoredUid` = patient's Firebase Auth UID
4. Now logging in with the patient account shows `MonitoredUserScreen`

---

## Project Structure (inside src/)

```
lib/
├── main.dart                    # Entry point, role-based routing, theme setup
├── firebase_options.dart        # Auto-generated Firebase config
├── models/
│   └── person_model.dart        # Patient data model
├── providers/
│   └── theme_provider.dart      # Dark/light theme state
├── screens/
│   ├── login_screen.dart
│   ├── dashboard_screen.dart    # Guardian — patient list, add patient form
│   ├── user_detail_screen.dart  # Guardian — patient detail, geofence config
│   ├── live_tracking_screen.dart # Guardian — real-time GPS map
│   ├── alerts_screen.dart       # Guardian — alert inbox
│   └── monitored_user_screen.dart # Patient — vitals simulator
├── services/
│   ├── firestore_service.dart   # All Firestore reads/writes, vitals watcher
│   ├── location_service.dart    # GPS permission and stream
│   ├── geofence_service.dart    # Haversine distance check
│   ├── notification_service.dart # FCM token save, local notifications
│   └── tracking_service.dart   # Background GPS tracking loop
└── widgets/
    └── sg_design_system.dart    # Shared theme, colours, components
```

---

## Troubleshooting

| Issue | Fix |
|---|---|
| `DEVELOPER_ERROR` in logs | Add SHA-1 fingerprint to Firebase Console |
| Maps not showing | Check Google Maps API key in AndroidManifest.xml |
| No push notifications | Enable FCM API (V1) in Firebase → Project Settings → Cloud Messaging |
| Firestore permission denied | Check security rules are published |
| Build fails with desugaring error | Ensure `build.gradle` has `isCoreLibraryDesugaringEnabled = true` |
