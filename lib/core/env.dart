import 'package:flutter/material.dart';

/// Supabase settings are passed at build time so no secret is committed to git:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
/// Only the public "anon" key belongs here. NEVER put the service_role key in the app.
/// With no keys the app runs in offline demo mode using the bundled sample data.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Must match the URL scheme registered in AndroidManifest.xml and Info.plist
  /// and be listed under Supabase > Authentication > URL Configuration > Redirect URLs.
  static const authRedirect = 'io.explorehub.app://login-callback/';

  /// Public web address of the app (used in shared links).
  static const webUrl = 'https://mdfarhadhossenimon.github.io/ExploreHub_TravelCommunityApp/';

  static bool get configured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

void say(String message) => messengerKey.currentState
    ?.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
