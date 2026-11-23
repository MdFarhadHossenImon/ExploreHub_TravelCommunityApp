> **UI:** dark green and tan theme (see `lib/core/theme.dart`), Feed / Explore / Watch / Trips / Profile tabs, big place cards, swipeable place gallery, reels.
>
> **Backend + store release:** see [BACKEND_AND_RELEASE.md](BACKEND_AND_RELEASE.md). SQL is in `supabase/`.

# ExploreHub

## What's new in v2 (social network for travelers)
- **Responsive shell:** phone bottom bar with labels; tablet/desktop top header with search, tabs, messages, notifications and profile.
- **Home feed:** desktop 3-column layout (shortcuts, feed, next trip / buddy requests / online buddies), composer (photo, check-in, trip plan), **stories** with a full-screen player, **reactions** (long-press Like), "Travelers you may know".
- **Traveler profiles:** cover, bio, countries visited, stats, posts / photos / trips tabs, add buddy, follow, message.
- **Travel buddies:** requests, suggestions, buddy finder by destination, buddy list.
- **Messenger:** inbox with online buddies, 1:1 and group chats; split view on wide screens.
- **Groups:** your groups, discover, create, join / request (private), discussion, about, members.
- **Trip planner:** trip plans with day-by-day itinerary timeline, add stops, invite buddies, budget, privacy; Bookings live under the same Trips tab.
- **Global search:** travelers, places, groups and posts.
- Database: run `supabase/social.sql` after `schema.sql` (tables + row level security for all of the above).
- Offline web preview: `flutter build web --web-renderer html --dart-define=PREVIEW=true` uses bundled illustrations and fonts and skips sign-in.

Travelers' social network + video discovery + one-stop travel marketplace, built in Flutter (mobile, tablet, web, desktop).

## Run
```bash
flutter create . --org com.explorehub --project-name explorehub   # generates android/ ios/ web/ ...
flutter pub get
flutter run            # or: flutter run -d chrome
```
Android release builds need `<uses-permission android:name="android.permission.INTERNET"/>` in `android/app/src/main/AndroidManifest.xml`.

## Structure
```
lib/
  core/        theme tokens, responsive helpers
  data/        models + demo data
  state/       AppState (provider)
  widgets/     shared UI
  screens/     splash, auth, shell, home, search, place_detail (How to go),
               booking_flow, transport (flight/train/bus + guides),
               community (feed, comments, create post), watch (reels),
               bookings, notifications, profile
```
Demo images come from picsum.photos and avatars from pravatar.cc (need internet).

## Next steps to go live
1. Backend: Firebase or Supabase (auth, Firestore/Postgres, Storage). Replace `AppState` lists with repositories.
2. Media: `image_picker` + `video_player`/`chewie`; upload to storage / CDN.
3. Real inventory: aggregator APIs for flights, trains, buses, hotels; guide onboarding and verification.
4. Payments: Stripe, SSLCommerz or bKash. Real QR: `qr_flutter`. Maps: `google_maps_flutter` / `url_launcher`.
5. Push: Firebase Cloud Messaging. Moderation and reporting for user content.
