# ExploreHub: run with Supabase, then publish to Google Play and the App Store

The app runs in two modes:

| Mode | When | Data |
|---|---|---|
| Demo | no keys passed | built-in sample data, nothing saved |
| Live | `SUPABASE_URL` and `SUPABASE_ANON_KEY` passed | real accounts, posts, uploads, bookings in your Supabase project |

---

## Part 1. Supabase (already live)

The live backend is the Supabase project **explorehub-live** (Mumbai, ap-south-1):

- URL: `https://qikajcgweazcpohbynkf.supabase.co`
- Public anon key: in Supabase > Project Settings > API (safe to ship in the app; never ship the `service_role` key).
- Applied: every table in `supabase/schema.sql` and `supabase/social.sql`, row level security on all of them, the `avatars` and `post-media` storage buckets, realtime for messages and buddy requests, 15 real places with real Wikipedia photos, 7 guides and 6 starter groups.
- Account deletion runs through the `delete-account` Edge Function (deletes the user's files, then the user).

Dashboard steps that only the owner can do:

1. **Authentication > Email Templates**: in **Confirm signup** and **Reset password**, add `Your ExploreHub code is {{ .Token }}` so the 6-digit code screen works.
2. **Authentication > URL Configuration**: set **Site URL** to the web app address, and add `io.explorehub.app://login-callback/` under **Redirect URLs**.
3. **Authentication > SMTP Settings**: connect your own mail provider (Resend, Brevo, etc.) before launch. The built-in mailer only sends a few emails an hour.
4. Social logins (Google, Apple, Facebook) need their own client IDs. If you skip one, remove its button in `SocialButtons` in `lib/screens/auth.dart`.

## Part 2. Run the app

1. Install Flutter (https://docs.flutter.dev/get-started/install) and run `flutter doctor` until it is clean.
2. The Android project is included (app id `com.explorehub.app`). Run `flutter pub get`.
3. `flutter analyze` and fix anything it reports.
4. Add platform config (once).

   **Android** `android/app/src/main/AndroidManifest.xml`, inside `<manifest>` before `<application>`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
   and inside the `<activity ...>` element add:
   ```xml
   <intent-filter>
     <action android:name="android.intent.action.VIEW"/>
     <category android:name="android.intent.category.DEFAULT"/>
     <category android:name="android.intent.category.BROWSABLE"/>
     <data android:scheme="io.explorehub.app" android:host="login-callback"/>
   </intent-filter>
   ```
   Also add `<queries><intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent></queries>` inside `<manifest>` so "Open in Maps" works.

   **iOS** `ios/Runner/Info.plist`, inside the top `<dict>`:
   ```xml
   <key>NSPhotoLibraryUsageDescription</key><string>Choose photos and videos to share with other travelers.</string>
   <key>NSCameraUsageDescription</key><string>Take photos to share with other travelers.</string>
   <key>NSMicrophoneUsageDescription</key><string>Record sound for videos you share.</string>
   <key>CFBundleURLTypes</key>
   <array><dict>
     <key>CFBundleURLSchemes</key><array><string>io.explorehub.app</string></array>
   </dict></array>
   <key>LSApplicationQueriesSchemes</key><array><string>https</string></array>
   ```
5. Run:
   ```
   flutter run \
     --dart-define=SUPABASE_URL=https://YOUR-REF.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
   ```
   Sign up, enter the 6-digit email code, post a photo, book a trip, then check the rows in Supabase **Table Editor**.
6. For an admin to moderate: reports land in the `reports` table. Review it daily and delete offending posts (Table Editor > `posts`). Apple and Google expect you to act on reports within 24 hours.

---

## Part 3. Before you submit anywhere (store-review blockers)

- **Real inventory or honest labelling.** Flight, train, bus and hotel booking here is a simulated flow (fares are samples, no payment is taken). Stores reject apps that look like they sell something they cannot deliver. Either connect real providers and a payment gateway (Stripe or a local one; physical travel services use external payment, not in-app purchase), or label booking as "coming soon / request only" before release.
- **Privacy policy URL** (public web page) covering account data, photos/videos you store, Supabase as processor, and how to delete data.
- **Account deletion in-app**: included (Settings > Delete account, calls the `delete-account` Edge Function).
- **User-generated content tools**: included (report post, block user, delete own post). Add terms of use that ban abusive content and tell users where to report.
- **Sign in with Apple** if you keep Google/Facebook buttons (App Store rule 4.8).
- **Review account**: create a test user in Supabase Auth (confirm its email in the dashboard) and give the credentials to both stores.
- **Icons and name**: set the launcher icon (e.g. `flutter_launcher_icons` package) and app name in `AndroidManifest.xml` (`android:label`) and `Info.plist` (`CFBundleDisplayName`).
- Known gaps: no push notifications yet. In live mode, only real uploaded photos and real place photos are shown.

---

## Part 4. Publish on Google Play

1. **Developer account**: https://play.google.com/console, one-time fee of US$25, identity verification.
2. **Set the app id and version**: in `android/app/build.gradle(.kts)` `applicationId` is already `com.explorehub.app` (it cannot be changed after publishing), and keep `version: 1.0.0+1` in `pubspec.yaml` (the number after `+` is the versionCode; raise it on every upload).
3. **Target API**: new apps and updates must target the current required API level (API 36 from 31 Aug 2026, check https://developer.android.com/google/play/requirements/target-sdk). A fresh `flutter create` on a current Flutter uses the right value; verify `targetSdk` in the gradle file.
4. **Create a signing key** (keep it and the passwords safe, never commit):
   ```
   keytool -genkey -v -keystore ~/explorehub-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Create `android/key.properties`:
   ```
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/home/you/explorehub-upload.jks
   ```
   and wire it into `android/app/build.gradle` `signingConfigs.release` as in https://docs.flutter.dev/deployment/android#sign-the-app. Play App Signing (default) holds the final key.
5. **Build**:
   ```
   flutter build appbundle --release \
     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`.
6. **Play Console > Create app**. Fill in:
   - Store listing: name, short and full description, 512x512 icon, 1024x500 feature graphic, at least 2 phone screenshots.
   - App content: privacy policy URL, Ads (no), App access (give the review login), Content rating questionnaire (answer yes to user-generated content), Target audience (13+ or 18+), **Data safety** (declare email, name, photos/videos, user content, bookings; data is encrypted in transit; users can request deletion).
7. **Testing track**: new personal developer accounts must run a **closed test with at least 12 testers opted in for 14 continuous days** before they can apply for production (applies to accounts created after 13 Nov 2023). Upload the `.aab` to Closed testing, add testers by email or Google Group, and wait out the 14 days.
8. **Apply for production access**, then **Production > Create release**, upload the same or a newer `.aab`, add release notes, and **Send for review**. First reviews usually take a few days.

## Part 5. Publish on the App Store

1. **Apple Developer Program**: https://developer.apple.com/programs/ (US$99/year). Individual or organization enrollment can take days.
2. **You need a Mac with Xcode.** Uploads must be built with Xcode 26 or later (iOS 26 SDK) since 28 Apr 2026. No Mac? Use a cloud builder such as Codemagic, GitHub Actions macOS runners, or rent a Mac, and let it build and upload.
3. **Bundle id**: open `ios/Runner.xcworkspace` in Xcode, select Runner > **Signing & Capabilities**, set bundle identifier `io.explorehub.app`, choose your Team, tick **Automatically manage signing**. Add the **Sign in with Apple** capability. Set Display Name and the app icon (Assets.xcassets > AppIcon). Check the deployment target is not below what Apple currently requires (the Flutter default is fine on current Flutter).
4. **Register the app**: https://appstoreconnect.apple.com > **My Apps > +** > New App, same bundle id, pick a name and SKU.
5. **Build the archive**:
   ```
   flutter build ipa --release \
     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
   ```
   Upload `build/ios/ipa/*.ipa` with the **Transporter** app (or Xcode > Product > Archive > Distribute App).
6. **TestFlight**: after processing (about 15-30 minutes) the build appears in TestFlight. Add yourself and testers, fix crashes on a real iPhone first.
7. **App Store listing**: description, keywords, screenshots (6.9" and 6.5" iPhone sizes at minimum, iPad if you support it), support URL, privacy policy URL, age rating (UGC), category Travel.
8. **App Privacy** (nutrition labels): declare Contact info (email), User content (photos/videos, posts), Identifiers (user id), Purchases/bookings. State they are linked to the user and not used for tracking.
9. **App Review information**: enter the demo account, and a note: "Users can report posts, block users, delete their own account in Profile > Delete account. Bookings are for real-world travel services paid outside the app."
10. Select the build, **Add for Review**, **Submit**. Reviews usually take 1-3 days; the first rejection is common, reply in Resolution Center with the fix.

---

## After launch

- Raise `version:` build number in `pubspec.yaml` for every upload.
- In Supabase: turn on daily backups (Pro plan), enable CAPTCHA/rate limits under Authentication, watch **Reports > API** for abuse, and move to a paid plan before launch day so the project is not paused for inactivity (free projects pause after about a week with no activity).
- Add push notifications (Firebase Cloud Messaging + a Supabase Edge Function) and a real payments/inventory provider as the next milestones.
