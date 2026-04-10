# ExploreHub Flutter

Flutter implementation of the ExploreHub traveler community app with a layered structure:

- `lib/backend`: models, repositories, services
- `lib/frontend`: app shell, theme, widgets, screens

## Current State

This project now supports two modes:

- Mock mode: works without Firebase and is enabled by default
- Firebase mode: real authentication, posts, and bookings after setup

Switch to Firebase mode in [app_config.dart](C:\Users\User\Documents\New project\lib\app_config.dart):

```dart
static const bool enableFirebase = true;
```

Do that only after completing Firebase setup.

## Firebase Setup

Official references:

- [FlutterFire setup](https://firebase.google.com/docs/flutter/setup)
- [Firebase Auth for Flutter](https://firebase.google.com/docs/auth/flutter/start)
- [Cloud Firestore for Flutter](https://firebase.google.com/docs/firestore)

### 1. Generate platform folders if missing

```bash
flutter create .
```

### 2. Add Firebase to the project

```bash
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure
```

This will generate a real `firebase_options.dart`. Replace the placeholder file in `lib/`.

### 3. Turn Firebase mode on

Update:

```dart
static const bool enableFirebase = true;
```

### 4. Run the app

```bash
flutter pub get
flutter run
```

## Implemented Real Actions

Buttons are now wired to repository actions:

- Login
- Sign up
- Reset password email
- Publish post
- Like post
- Save post
- Book hotel
- Book ticket
- Sign out

When Firebase is disabled, these actions use in-memory mock data.

## Firestore Schema

### `users/{uid}`

```json
{
  "email": "imon@example.com",
  "name": "Imon Rahman",
  "handle": "@imontravels",
  "bio": "Traveler on ExploreHub",
  "avatarUrl": "",
  "homeCity": "Dhaka, Bangladesh",
  "stats": {
    "followers": 0,
    "trips": 0,
    "bookings": 0
  }
}
```

### `posts/{postId}`

```json
{
  "authorId": "uid",
  "author": "Imon Rahman",
  "location": "Bali, Indonesia",
  "caption": "Beautiful place",
  "imageUrl": "https://...",
  "likes": 0,
  "comments": 0,
  "tags": ["Community"],
  "createdAt": "2026-04-10T10:00:00.000Z",
  "likedBy": [],
  "savedBy": []
}
```

### `hotels/{hotelId}`

```json
{
  "name": "Azure Coast Resort",
  "city": "Phuket",
  "pricePerNight": 120,
  "rating": 4.8,
  "imageUrl": "https://...",
  "features": ["Breakfast", "Pool"]
}
```

### `tickets/{ticketId}`

```json
{
  "from": "DAC",
  "to": "IST",
  "carrier": "Turkish Airlines",
  "departure": "2026-05-16T09:45:00.000Z",
  "duration": "8h 20m",
  "price": 540
}
```

### `bookings/{bookingId}`

```json
{
  "userId": "uid",
  "type": "hotel",
  "itemId": "hotel-1",
  "title": "Azure Coast Resort",
  "subtitle": "Phuket",
  "price": 120,
  "status": "pending",
  "createdAt": "2026-04-10T10:00:00.000Z"
}
```

## What Still Needs Real Business Integrations

Firebase is now a strong backend foundation, but real travel commerce usually also needs:

- hotel inventory provider
- flight provider
- payment gateway
- admin/vendor dashboard
- push notifications
- moderation/reporting

## Notes

- Password reset is implemented with Firebase email reset links. The old OTP screen is kept as an explanation screen.
- Google and Facebook buttons still need provider configuration in Firebase Console and their platform SDK setup.
