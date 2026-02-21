# Alarm

A smart iOS alarm app with commute-aware reminders and multi-country public holiday support.

## Features

- **Smart Alarms** — One-time or recurring alarms by weekday
- **Public Holiday Aware** — Skip alarms on official holidays; supports 100+ countries
- **Commute Reminders** — Calculates real-time travel time (driving / walking / transit) and alerts you when it's time to leave
- **Multi-language UI** — English and Simplified Chinese; country names auto-localize to the device language
- **Snooze** — Configurable snooze duration (5 / 9 / 10 / 15 min)

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 16+ |
| iOS deployment target | 17.0+ |
| XcodeGen | any recent |

## Quick Start

```bash
# 1. Install XcodeGen (first time only)
brew install xcodegen

# 2. Clone
git clone https://github.com/xenonyu/Alarm.git && cd Alarm

# 3. Build & run on Simulator or connected iPhone
./deploy.sh
```

> **Real device**: Set your Apple Developer Team ID in `project.yml` (`DEVELOPMENT_TEAM`).

## Project Structure

```
Alarm/
├── project.yml                  # XcodeGen config (source of truth)
├── deploy.sh                    # Build + install script
├── AlarmApp.swift               # App entry point
├── ContentView.swift            # Root tab view
├── Models/
│   ├── Alarm.swift              # SwiftData alarm model
│   ├── AppSettings.swift        # Snooze duration + holiday country
│   └── HolidayResponse.swift   # timor.tech API response model
├── Services/
│   ├── AlarmStore.swift         # Central coordinator (CRUD + scheduling)
│   ├── HolidayService.swift     # Multi-country holiday data
│   ├── NotificationService.swift
│   ├── NotificationDelegate.swift
│   ├── LocationManager.swift
│   └── CommuteService.swift
├── Views/
│   ├── Alarm/                   # Alarm list, row, add/edit sheet
│   ├── Calendar/                # Calendar picker view
│   ├── Commute/                 # Destination picker
│   └── Settings/                # App settings + holiday region picker
├── Utils/
│   └── DateExtensions.swift
├── Assets.xcassets
└── Localizable.xcstrings        # en + zh-Hans strings
```

## Holiday Data Sources

| Region | API | Notes |
|--------|-----|-------|
| 🇨🇳 China (CN) | [timor.tech](https://timor.tech/api/holiday) | Includes makeup workdays |
| 🌍 100+ countries | [Nager.Date](https://date.nager.at) | ISO 3166-1 country codes |

Change the holiday region anytime in **Settings → Public Holidays → Holiday Region**.

## Tech Stack

- **Swift 5 / SwiftUI** — Declarative UI
- **SwiftData** — Persistent alarm storage
- **MapKit / CoreLocation** — Commute route calculation
- **UserNotifications** — Local alarm notifications
- **Observation** (`@Observable`) — Reactive state management

## CI / CD

GitHub Actions runs on every push and pull request:

| Job | Trigger | Description |
|-----|---------|-------------|
| `build` | push / PR | Generates project with XcodeGen, builds for Simulator |
| `test` | push / PR | Runs UI tests on iPhone 16 Pro Simulator |

See [`.github/workflows/ci.yml`](.github/workflows/ci.yml) for details.

To set up TestFlight distribution, add the following secrets to your GitHub repository:

| Secret | Description |
|--------|-------------|
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | API Issuer ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Base64-encoded `.p8` key |
| `CERTIFICATE_P12_BASE64` | Base64-encoded distribution certificate |
| `CERTIFICATE_PASSWORD` | Certificate password |
| `PROVISIONING_PROFILE_BASE64` | Base64-encoded provisioning profile |

## Development

```bash
# Regenerate Xcode project after editing project.yml
xcodegen generate

# Deploy to connected device or Simulator
./deploy.sh
```
