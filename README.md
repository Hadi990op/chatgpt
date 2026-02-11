# Rickshaw Pulse (Open & Free)

Rickshaw Pulse is an **Android-first community app** that helps daily travelers understand if rickshaws are active on a route at a given time.

> This is **not** a booking app. No payments, no subscriptions, no ride requests, and no exact private tracking.

## What this repo includes

- `mobile/` – Flutter app (Traveler + Driver modes)
- `backend/` – lightweight Node.js API with file-based persistence
- Open map stack:
  - OpenStreetMap tiles/data
  - Nominatim geocoding/reverse geocoding
  - No paid API and no API keys

## Core capabilities

- Route selection (start + end)
- Time-based availability check
- Driver active/inactive toggle
- Approximate ETA ranges (not exact)
- Save daily routes
- Availability history labels (usually / sometimes / rare)
- Traveler mode without login
- Driver mode with simple login

## Architecture

- **Mobile:** Flutter + `flutter_map`
- **Backend:** Express.js API + JSON storage (easy to replace with PostgreSQL later)
- **Privacy-first:**
  - No precise tracking timeline for travelers
  - Driver location stored only while active and rounded to 3 decimals
  - No payment/identity documents in app

---

## Quick start

### 1) Backend

```bash
cd backend
npm install
npm run dev
```

Backend runs at `http://localhost:8080`.

### 2) Mobile app

```bash
cd mobile
flutter pub get
flutter run
```

Use `--dart-define=API_BASE_URL=http://10.0.2.2:8080` for Android emulator.

---

## API overview

### Driver

- `POST /api/drivers/login`
- `POST /api/drivers/:driverId/status`

### Traveler

- `GET /api/availability?startLat&startLon&endLat&endLon&hour`
- `POST /api/routes/save`
- `GET /api/routes/saved/:travelerId`
- `GET /api/history?startLat&startLon&endLat&endLon`

### Open geo proxy (no API keys)

- `GET /api/geo/search?q=...` (Nominatim search)
- `GET /api/geo/reverse?lat=...&lon=...` (Nominatim reverse)

---

## Community model

- Drivers indicate availability and rough location while active.
- Travelers check expected availability by route + time.
- History is generated from actual active records, not mock data.

## License

MIT
