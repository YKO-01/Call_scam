# Betrugsradar (Flutter)

Betrugsradar is a Flutter app that checks phone numbers against a fraud database and shows a risk-based result (`Betrug` or `Safe`).

It also includes a simulated incoming-call flow to demonstrate how real-time screening could look in a production phone assistant.

## What the app does

- Loads a remote fraud-number dataset (JSON) at startup.
- Validates German phone-number input (`+49...` or `0...`).
- Normalizes and looks up numbers in memory.
- Shows risk score, reason, category, source year, and suggested action.
- Tracks recent checks in the UI.
- Provides an incoming-call simulation with live analysis feedback.

## Project structure

- `lib/main.dart` – app entry point.
- `lib/app.dart` – `MaterialApp` setup and theme.
- `lib/features/fraud_radar/presentation/pages/betrugsradar_page.dart` – main screen and interaction logic.
- `lib/features/fraud_radar/data/fraud_database.dart` – remote fetch, JSON decode, and lookup logic.
- `lib/features/fraud_radar/domain/models/` – data models (`FraudEntry`, `CallCheckResult`, `RecentCheck`).
- `lib/core/utils/validators.dart` – German number validation/sanitization.
- `test/widget_test.dart` – basic UI smoke test.

## Run locally

1. Install Flutter (stable channel) and platform toolchain.
2. Get dependencies: `flutter pub get`
3. Start the app: `flutter run`

## Testing

- Run tests with: `flutter test`

## Detailed documentation

See `docs/how-app-works.md` for a full explanation of:

- Architecture and data flow
- Number validation rules
- Fraud matching algorithm
- Incoming-call simulation logic
- Error handling and limitations
