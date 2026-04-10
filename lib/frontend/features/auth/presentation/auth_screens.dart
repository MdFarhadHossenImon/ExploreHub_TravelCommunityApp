import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/images/onboarding.png', fit: BoxFit.cover),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 80,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'The earth has music for those who listen',
                    style: theme.textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text('William Shakespeare', style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () => context.go('/auth'),
                    child: const Text('Get Started'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthHubScreen extends StatelessWidget {
  const AuthHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Image.asset('assets/images/logo.png', width: 120, height: 120),
                  const SizedBox(height: 20),
                  Text('ExploreHub', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  Text(
                    'A traveler community that turns inspiration into bookable plans.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Log In'),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => context.go('/signup'),
                    child: const Text('Sign Up'),
                  ),
                  const SizedBox(height: 28),
                  const _AuthDivider(),
                  const SizedBox(height: 20),
                  const _SocialButton(
                    label: 'Continue with Google',
                    assetPath: 'assets/images/google.png',
                  ),
                  const SizedBox(height: 12),
                  const _SocialButton(
                    label: 'Continue with Facebook',
                    assetPath: 'assets/images/facebook.png',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rememberMe = ref.watch(rememberMeProvider);
    return AuthLayout(
      title: 'Log In',
      leading: IconButton(
        onPressed: () => context.go('/auth'),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              hintText: 'Email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Password',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Checkbox(
                value: rememberMe,
                onChanged: (value) => ref.read(rememberMeProvider.notifier).state =
                    value ?? false,
              ),
              const Text('Remember me'),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/forgot-password'),
                child: const Text('Forgot Password'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => context.go('/app/feed'),
            child: const Text('Log In'),
          ),
          const SizedBox(height: 20),
          const _AuthDivider(),
          const SizedBox(height: 20),
          const _SocialButton(
            label: 'Continue with Google',
            assetPath: 'assets/images/google.png',
          ),
          const SizedBox(height: 12),
          const _SocialButton(
            label: 'Continue with Facebook',
            assetPath: 'assets/images/facebook.png',
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () => context.go('/signup'),
            child: const Text('Need an account? Sign Up'),
          ),
        ],
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Sign Up',
      leading: IconButton(
        onPressed: () => context.go('/auth'),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              hintText: 'Email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Password',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Confirm your password',
              prefixIcon: Icon(Icons.verified_user_outlined),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/app/feed'),
            child: const Text('Create Account'),
          ),
          const SizedBox(height: 20),
          const _AuthDivider(),
          const SizedBox(height: 20),
          const _SocialButton(
            label: 'Continue with Google',
            assetPath: 'assets/images/google.png',
          ),
          const SizedBox(height: 12),
          const _SocialButton(
            label: 'Continue with Facebook',
            assetPath: 'assets/images/facebook.png',
          ),
        ],
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Forgot Password',
      subtitle:
          'Please enter the email associated with your account and we will send a verification code.',
      leading: IconButton(
        onPressed: () => context.go('/login'),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              hintText: 'Email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/verify-otp'),
            child: const Text('Send OTP'),
          ),
        ],
      ),
    );
  }
}

class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({super.key});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Verify OTP',
      subtitle:
          'Enter the 6 digit code that was sent to your email and complete verification.',
      leading: IconButton(
        onPressed: () => context.go('/forgot-password'),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      child: Column(
        children: [
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter OTP',
              prefixIcon: Icon(Icons.password_rounded),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: const Text('Resend OTP'),
            ),
          ),
          ElevatedButton(
            onPressed: () => context.go('/app/feed'),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('Or'),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.assetPath,
  });

  final String label;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: Row(
        children: [
          Image.asset(assetPath, width: 24, height: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: AppTheme.ink,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
