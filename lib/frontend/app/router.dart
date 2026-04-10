import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_screens.dart';
import '../features/community/presentation/community_screens.dart';
import '../features/main/presentation/dashboard_screen.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/auth', builder: (context, state) => const AuthHubScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) => const VerifyOtpScreen(),
      ),
      GoRoute(
        path: '/app/create-post',
        builder: (context, state) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/app/:tab',
        builder: (context, state) => DashboardScreen(
          currentTab: state.pathParameters['tab'] ?? 'feed',
        ),
      ),
    ],
  );
}
