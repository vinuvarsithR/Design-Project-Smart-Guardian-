# SmartGuardian
### Real-Time Dementia Patient Safety Monitoring System

> Capstone Project — 3rd Year | Healthcare Technology / Mobile Application Development / Cloud Computing

---

## Overview

SmartGuardian is a real-time dementia patient safety monitoring system built as a Flutter mobile application backed by Firebase. It provides guardians with instant alerts for abnormal heart rate, fever, geofence breaches, and fall detection — all through a dual-role app that runs on both the guardian's and patient's device.

---

## Features

- Real-time GPS tracking with customisable geofencing and live dark/light themed map
- Instant push notifications for geofence breaches, fall events, abnormal heart rate, and fever
- Dual-role app — same APK serves both guardian and monitored patient
- Multi-step patient registration capturing dementia stage, medications, allergies, and emergency contacts
- Alert management inbox with read/resolve workflow and unread badge count
- Dark/light theme toggle with adaptive Google Maps styling
- Automatic vitals watcher with alert deduplication
- Background GPS tracking and accelerometer fall detection on patient's device

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| Backend | Firebase Authentication, Cloud Firestore |
| Cloud | Google Firebase — Spark plan (free) |
| Maps | Google Maps Flutter SDK |
| Notifications | Firebase Cloud Messaging (FCM) + flutter_local_notifications |
| Sensors | sensors_plus, geolocator |

---

## Project Structure

```
SmartGuardian/
├── src/                        # Flutter project source
│   ├── lib/
│   │   ├── main.dart           # Entry point, role-based routing
│   │   ├── models/             # Person model
│   │   ├── providers/          # ThemeProvider
│   │   ├── screens/            # All app screens
│   │   ├── services/           # Firestore, Location, Notification, Tracking
│   │   └── widgets/            # SG design system
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
├── docs/
│   ├── architecture.png        # System architecture diagram
│   └── setup_instructions.md  # Setup guide
├── README.md                   # This file
├── requirements.txt            # Flutter dependencies
├── architecture.png            # Architecture diagram (root copy)
└── demo_video_link.txt         # Link to demo video
```

---

## Firestore Collections

| Collection | Purpose |
|---|---|
| `users/{userId}` | Patient profile, live vitals, GPS, geofence config |
| `alerts/{alertId}` | All alerts with type, severity, read/resolve status |
| `guardians/{uid}` | Guardian FCM token for push notifications |

---

## Alert Types

| Type | Trigger |
|---|---|
| `fall` | Accelerometer detects sudden impact |
| `heart_rate` | HR below 40 bpm or above 120 bpm |
| `temperature` | Below 35°C (hypothermia) or above 38.5°C (fever) |
| `geofence` | Patient exits the configured safe zone radius |

---

## Setup

See `setup_instructions.md` or `docs/setup_instructions.md` for full setup guide.

---

## Future Enhancements

- Dedicated hardware sensor integration for live physiological data
- AI-powered anomaly detection using LSTM on 7-day vitals history
- ABDM (Ayushman Bharat Digital Mission) health ID integration
- Multi-language support — Hindi, Tamil, Telugu, Kannada
- WhatsApp alert forwarding for family members
- SOS panic button on patient screen

---

## SDG Mapping

- **SDG 3** — Good Health and Well-being
- **SDG 9** — Industry, Innovation and Infrastructure

---

## Contributors

- vinuvarsithR

---

## License

This project is submitted as part of an academic capstone. All rights reserved.
