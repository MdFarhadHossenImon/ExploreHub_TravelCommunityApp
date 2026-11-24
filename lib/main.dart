import 'dart:async';

import 'package:flutter/material.dart';
import 'core/i18n.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import 'core/env.dart';
import 'core/theme.dart';
import 'data/backend.dart';
import 'screens/auth.dart';
import 'screens/shell.dart';
import 'screens/splash_onboarding.dart';
import 'state/app_state.dart';
import 'state/social_state.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = !kPreview; // fonts are bundled in assets/google_fonts
  await loadLang();
  await Backend.init(); // no-op in demo mode (no --dart-define keys)
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => SocialState()),
      ],
      child: const ExploreHubApp(),
    ),
  );
}

class ExploreHubApp extends StatefulWidget {
  const ExploreHubApp({super.key});
  @override
  State<ExploreHubApp> createState() => _ExploreHubAppState();
}

class _ExploreHubAppState extends State<ExploreHubApp> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    if (!Backend.on) return;
    final state = context.read<AppState>();
    final social = context.read<SocialState>();
    _sub = Backend.authChanges.listen((e) async {
      final ctx = navKey.currentContext;
      // Load buddies, chats, groups, trips and stories whenever a session starts.
      if ((e.event == AuthChangeEvent.initialSession || e.event == AuthChangeEvent.signedIn) && e.session != null) {
        social.load();
      }
      if (e.event == AuthChangeEvent.signedOut) social.clear();
      // Opened the password reset link from the email: ask for the new password right away.
      if (e.event == AuthChangeEvent.passwordRecovery && ctx != null && ctx.mounted) {
        final pw = await askNewPassword(ctx);
        if (pw != null) {
          try {
            await Backend.updatePassword(pw);
            say('Password updated');
          } catch (err) {
            say(errText(err));
          }
        }
      }
      // Returning from Google / Apple / Facebook: finish the sign-in and open the app.
      if (e.event == AuthChangeEvent.signedIn && !state.loggedIn) {
        final provider = e.session?.user.appMetadata['provider'];
        if (provider != null && provider != 'email') {
          await state.onSignedIn();
          if (navKey.currentContext != null) goRoot(navKey.currentContext!, const Shell());
        }
      }
      // Session ended elsewhere (expired / revoked): send the user back to the start.
      if (e.event == AuthChangeEvent.signedOut && state.loggedIn) {
        state.markLoggedOut();
        if (ctx != null && ctx.mounted) goRoot(ctx, const WelcomeScreen());
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExploreHub',
      debugShowCheckedModeBanner: false,
      navigatorKey: navKey,
      scaffoldMessengerKey: messengerKey,
      theme: buildTheme(),
      home: const SplashScreen(),
    );
  }
}
