import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'shell.dart';

/// Signs the user in, loads their data and opens the app.
Future<void> _enterApp(BuildContext context) async {
  final state = context.read<AppState>();
  await state.onSignedIn();
  if (context.mounted) goRoot(context, const Shell());
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Constrained(
            maxWidth: 440,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const SizedBox(height: 56),
              const Text('explorehub', textAlign: TextAlign.center, style: TextStyle(color: C.primary, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1)),
              const SizedBox(height: 48),
              PrimaryButton('Log In', onPressed: () => go(context, const LoginScreen())),
              const SizedBox(height: 12),
              PrimaryButton('Sign Up', outlined: true, onPressed: () => go(context, const SignupScreen())),
              const _OrDivider(),
              const SocialButtons(),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("Don't have an account? ", style: TextStyle(color: C.muted, fontSize: 13)),
                GestureDetector(
                  onTap: () => go(context, const SignupScreen()),
                  child: const Text('Register', style: TextStyle(color: C.primary, fontSize: 13)),
                ),
              ]),
            ]),
          ),
        ),
      );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Row(children: [
          Expanded(child: Divider()),
          Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Or', style: TextStyle(color: C.muted))),
          Expanded(child: Divider()),
        ]),
      );
}

/// Google, Apple and Facebook. Apple is required on iOS whenever other social logins are offered.
class SocialButtons extends StatelessWidget {
  const SocialButtons({super.key});

  Future<void> _social(BuildContext c, OAuthProvider provider) async {
    if (!Backend.on) {
      c.read<AppState>().login('traveler@explorehub.app'); // demo mode
      goRoot(c, const Shell());
      return;
    }
    try {
      await Backend.oauth(provider); // opens the browser; main.dart finishes the sign-in on return
    } catch (e) {
      if (c.mounted) toast(c, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget btn(String label, Widget icon, OAuthProvider p) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _social(context, p),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.ink,
                backgroundColor: C.card,
                side: const BorderSide(color: C.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [icon, const SizedBox(width: 10), Text(label)]),
            ),
          ),
        );
    return Column(children: [
      btn('Continue with Google', const Text('G', style: TextStyle(color: Color(0xFFDB4437), fontWeight: FontWeight.w800, fontSize: 20)), OAuthProvider.google),
      btn('Continue with Apple', const Icon(Icons.apple, color: C.ink), OAuthProvider.apple),
      btn('Continue with Facebook', const Icon(Icons.facebook, color: Color(0xFF1877F2)), OAuthProvider.facebook),
    ]);
  }
}

String? _email(String? v) => (v == null || !v.contains('@') || !v.contains('.')) ? 'Enter a valid email address' : null;
String? _pass(String? v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email0 = TextEditingController();
  final _pass0 = TextEditingController();
  bool _remember = true;
  bool _busy = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (Backend.on) {
        await Backend.signIn(_email0.text.trim(), _pass0.text);
        if (mounted) await _enterApp(context);
      } else {
        context.read<AppState>().login(_email0.text.trim());
        goRoot(context, const Shell());
      }
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email0.dispose();
    _pass0.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScreenScaffold(
        title: 'Log In',
        maxWidth: 440,
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const SizedBox(height: 12),
            LabeledField('Email', 'Text your email', controller: _email0, keyboard: TextInputType.emailAddress, validator: _email),
            LabeledField('Password', 'Text your password', controller: _pass0, obscure: true, validator: _pass),
            Row(children: [
              Checkbox(value: _remember, activeColor: C.ok, onChanged: (v) => setState(() => _remember = v ?? false)),
              const Text('Remember me', style: TextStyle(fontSize: 12)),
              const Spacer(),
              GestureDetector(
                onTap: () => go(context, const ForgotScreen()),
                child: const Text('Forgot password?', style: TextStyle(color: C.muted, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 16),
            PrimaryButton(_busy ? 'Please wait...' : 'Log In', onPressed: _busy ? null : _submit),
            const _OrDivider(),
            const SocialButtons(),
          ]),
        ),
      );
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _email0 = TextEditingController();
  final _pass0 = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final mail = _email0.text.trim();
    if (!Backend.on) {
      go(context, OtpScreen(email: mail));
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await Backend.signUp(mail, _pass0.text);
      if (!mounted) return;
      if (res.session != null) {
        await _enterApp(context); // email confirmation is switched off in your project
      } else {
        go(context, OtpScreen(email: mail)); // a 6-digit code was emailed
      }
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email0.dispose();
    _pass0.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScreenScaffold(
        title: 'Sign Up',
        maxWidth: 440,
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const SizedBox(height: 12),
            LabeledField('Email', 'Text your email', controller: _email0, keyboard: TextInputType.emailAddress, validator: _email),
            LabeledField('Password', 'At least 8 characters', controller: _pass0, obscure: true, validator: _pass),
            LabeledField('Confirm password', 'Text your password again',
                controller: _confirm, obscure: true, validator: (v) => v != _pass0.text ? 'Passwords do not match' : null),
            const SizedBox(height: 8),
            PrimaryButton(_busy ? 'Please wait...' : 'Create account', onPressed: _busy ? null : _submit),
            const SizedBox(height: 10),
            const Text('By creating an account you agree to our Terms of Service and Privacy Policy.',
                textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 11.5)),
            const _OrDivider(),
            const SocialButtons(),
          ]),
        ),
      );
}

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});
  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _form = GlobalKey<FormState>();
  final _email0 = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final mail = _email0.text.trim();
    if (Backend.on) {
      setState(() => _busy = true);
      try {
        await Backend.sendResetCode(mail);
      } catch (e) {
        if (mounted) toast(context, errText(e));
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) go(context, OtpScreen(email: mail, resetFlow: true));
  }

  @override
  void dispose() {
    _email0.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScreenScaffold(
        title: 'Forgot Password',
        maxWidth: 440,
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const SizedBox(height: 12),
            const Text('Enter the email associated with your account and we will send an email with a code to reset your password.',
                style: TextStyle(color: C.muted, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            LabeledField('Email', 'Text your email', controller: _email0, keyboard: TextInputType.emailAddress, validator: _email),
            const SizedBox(height: 8),
            PrimaryButton(_busy ? 'Please wait...' : 'Confirm', onPressed: _busy ? null : _submit),
          ]),
        ),
      );
}

class OtpScreen extends StatefulWidget {
  final String email;
  final bool resetFlow;
  const OtpScreen({super.key, required this.email, this.resetFlow = false});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  int _left = 57;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _left = 57;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left == 0) {
        t.cancel();
      } else if (mounted) {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<String?> _askNewPassword() => askNewPassword(context);

  Future<void> _resend() async {
    setState(_startTimer);
    if (!Backend.on) return;
    try {
      widget.resetFlow ? await Backend.sendResetCode(widget.email) : await Backend.resendSignupCode(widget.email);
      if (mounted) toast(context, 'A new code is on its way');
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) return toast(context, 'Enter the 6-digit code');
    setState(() => _busy = true);
    try {
      if (Backend.on) {
        await Backend.verifyOtp(widget.email, _code.text, recovery: widget.resetFlow);
        if (widget.resetFlow) {
          final pw = await _askNewPassword();
          if (pw == null) {
            if (mounted) toast(context, 'Password not changed. Use at least 8 characters.');
            return;
          }
          await Backend.updatePassword(pw);
          if (mounted) toast(context, 'Password updated');
        }
        if (mounted) await _enterApp(context);
      } else if (widget.resetFlow) {
        final pw = await _askNewPassword();
        if (pw != null && mounted) {
          goRoot(context, const LoginScreen());
          toast(context, 'Password updated. Log in with your new password.');
        }
      } else {
        context.read<AppState>().login(widget.email);
        goRoot(context, const Shell());
      }
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mm = (_left ~/ 60).toString().padLeft(2, '0');
    final ss = (_left % 60).toString().padLeft(2, '0');
    return ScreenScaffold(
      title: Backend.on ? 'Check your email' : 'Verify OTP',
      maxWidth: 440,
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const SizedBox(height: 12),
        Text(
          !Backend.on
              ? 'Enter the code sent to ${widget.email}. (Demo: any 6 digits work.)'
              : widget.resetFlow
                  ? 'We emailed ${widget.email}. Open the link in that email to set a new password, or enter the 6-digit code if the email shows one.'
                  : 'We emailed ${widget.email}. Open the confirmation link in that email to activate your account, then come back and log in. If the email shows a 6-digit code, you can enter it here instead.',
          style: const TextStyle(color: C.muted, fontSize: 13, height: 1.5),
        ),
        if (Backend.on && !widget.resetFlow) ...[
          const SizedBox(height: 16),
          PrimaryButton('I confirmed my email, log in', outlined: true, onPressed: () => goRoot(context, const LoginScreen())),
        ],
        const SizedBox(height: 32),
        TextField(
          controller: _code,
          autofocus: true,
          maxLength: 6,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 18, fontWeight: FontWeight.w500),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '------',
            filled: false,
            border: UnderlineInputBorder(),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: C.line, width: 2)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: C.primary, width: 2)),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: _left > 0
              ? Text('Resend in $mm:$ss', style: const TextStyle(color: C.primary, fontWeight: FontWeight.w500))
              : TextButton(onPressed: _resend, child: const Text('Resend code')),
        ),
        const SizedBox(height: 16),
        PrimaryButton(_busy ? 'Please wait...' : 'Confirm', onPressed: _busy ? null : _verify),
      ]),
    );
  }
}

/// Dialog asking for a new password (at least 8 characters). Returns null if cancelled.
Future<String?> askNewPassword(BuildContext context) {
  final pw = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Create a new password'),
      content: TextField(controller: pw, obscureText: true, decoration: const InputDecoration(hintText: 'At least 8 characters')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, pw.text.length >= 8 ? pw.text : null), child: const Text('Save password')),
      ],
    ),
  );
}
