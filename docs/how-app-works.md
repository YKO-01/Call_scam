# How Betrugsradar Works

This document explains the app flow end-to-end, from startup to number analysis.

## 1) High-level overview

Betrugsradar is a single-screen Flutter app that helps users evaluate whether a phone number is potentially fraudulent.

Core idea:

1. Load known fraud numbers from a remote JSON file.
2. Validate user input as a German phone number.
3. Normalize the input (remove formatting symbols).
4. Match it against an in-memory lookup map.
5. Return a risk result and render it in the UI.

## 2) Startup and app boot

### Entry point

- File: `lib/main.dart`
- `main()` calls `runApp(const MyApp())`.

### App shell

- File: `lib/app.dart`
- `MyApp` configures:
	- Material 3 theme
	- title: `Betrugsradar`
	- home page: `BetrugsradarPage`

## 3) Main screen responsibilities

File: `lib/features/fraud_radar/presentation/pages/betrugsradar_page.dart`

`BetrugsradarPage` manages:

- Database loading state (`_database`, `_loadError`)
- Input validation state (`_phoneValidationError`)
- Last analysis result (`_result`)
- Popup lifecycle (`_showPopup`, timer-based auto-dismiss)
- Incoming call simulation state (`_isIncomingCallVisible`, `_isChecking`, `_simulatedResult`)
- History list (`_recentChecks`)

When the page initializes (`initState`), it immediately calls `_loadDatabase()`.

## 4) Data loading and lookup logic

File: `lib/features/fraud_radar/data/fraud_database.dart`

### Remote source

`FraudDatabase.load()` fetches fraud entries from a remote JSON URL using `http.get` with a 15-second timeout.

### Parsing

- JSON bytes are decoded as UTF-8.
- Parsing is offloaded via `compute(...)` to avoid UI jank.
- Each item becomes a `FraudEntry` object.

### Lookup map

After parsing, a map is built:

- Key: normalized phone number (digits only)
- Value: corresponding `FraudEntry`

This gives near O(1) lookup during checks.

## 5) Number validation rules

File: `lib/core/utils/validators.dart`

`GermanPhoneValidator.validateGermanPhoneNumber(...)` applies these rules:

1. Empty input is allowed only when `allowEmpty = true`.
2. Must contain only digits with optional leading `+`.
3. Must start with `+49` (international Germany) or `0` (local German format).
4. Length (digits-only view) must be between 10 and 14.

If validation fails, the user sees:

`Invalid German phone number. Please enter a valid number.`

## 6) Analysis flow (manual check)

Triggered by **"Nummer analysieren"** button:

1. Validate input with `allowEmpty: false`.
2. Stop if invalid and show inline error.
3. Sanitize input (`GermanPhoneValidator.sanitize`).
4. Call `_database!.checkNumber(...)`.
5. Save result into `_result`.
6. Prepend a new `RecentCheck` item.
7. Show a transient popup (`_showPopupWithAutoDismiss`) for 3 seconds.

### Result classification

Inside `FraudDatabase.checkNumber(...)`:

- **Match found** in lookup:
	- `isFraud = true`
	- status text: `Betrug`
	- reason: number found in fraud database
	- category, source year, action from source entry
	- risk score from source entry

- **No match**:
	- `isFraud = false`
	- status text: `Safe`
	- reason: not found in loaded list
	- default risk score: `8`

## 7) Incoming call simulation flow

Triggered by **"Anruf simulieren"** button:

1. Randomly pick one of predefined numbers.
2. Show full-screen incoming-call overlay.
3. Wait 2 seconds to simulate processing.
4. Reuse same lookup method (`checkNumber`) for result.
5. Render fraud/safe visual state and category badge.
6. Append to recent checks list.

This is a UI demo mode; it does not integrate with real phone APIs.

## 8) UI sections shown to the user

The page displays:

- Header with branding (`Betrugsradar`)
- Current warning banner
- Stats grid calculated from loaded dataset
- Risk Analyzer card (manual input + quick sample chips)
- Incoming Call Simulation card
- Result card (if a check has been performed)
- Recent checks card (latest 5 shown)
- Safety tips and informational footer

## 9) Error handling and edge behavior

- If remote load fails, `_loadError` is shown in UI.
- Analyze button is disabled until:
	- database is loaded,
	- input is non-empty,
	- input is valid.
- Popup safely dismisses on tap and auto-dismiss timer is canceled in `dispose`.
- Async state updates guard with `if (!mounted) return;` to avoid setting state after widget disposal.

## 10) Domain models

- `FraudEntry`: source dataset entry (`number`, `category`, `riskScore`, `sourceYear`, etc.).
- `CallCheckResult`: output shown to user for one analyzed number.
- `RecentCheck`: compact UI model for history list.

## 11) Current limitations

- Remote data URL is hardcoded in `FraudDatabase`.
- No persistent local cache if network is unavailable.
- No backend sync/telemetry for checks.
- No real telephony integration (simulation only).
- Existing tests are UI smoke tests only (no unit tests for validator/database yet).

## 12) Suggested next improvements

1. Add local caching of the JSON file for offline startup.
2. Add unit tests for `GermanPhoneValidator` and `FraudDatabase.checkNumber`.
3. Split page logic into smaller view-model/controller classes.
4. Add localization (DE/EN) for all visible text.
5. Add a dedicated error/retry state for remote load failures.

