import 'dart:async';

import 'package:flutter/material.dart';
import '../core/i18n.dart';

import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/backend.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final ready = state.bootstrap();
    _t = Timer(const Duration(milliseconds: 1800), () async {
      await ready.timeout(const Duration(seconds: 8), onTimeout: () {});
      if (mounted) {
        final signedIn = (Backend.on && Backend.user != null) || (kPreview && !Backend.on);
        if (kPreview && !Backend.on) state.login(state.email);
        Navigator.of(context).pushReplacement(PageRouteBuilder(
          pageBuilder: (_, __, ___) => signedIn ? const Shell() : const OnboardingScreen(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        ));
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.bg,
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (c, v, child) => Opacity(
              opacity: v,
              child: Transform.scale(scale: 0.9 + 0.1 * v, child: child),
            ),
            child: const Text('explorehub', style: TextStyle(color: C.primary, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.2)),
          ),
        ),
      );
}

class _Slide {
  final String quote, by, seed;
  const _Slide(this.quote, this.by, this.seed);
}

const _slides = [
  _Slide('The earth has music for those who listen', 'William Shakespeare', 'onboard-mountain'),
  _Slide('Share every mile with people who get it', 'The ExploreHub community', 'onboard-friends'),
  _Slide('Plan, book and go. Flights, trains, buses and guides in one place', 'Your whole trip, start to end', 'onboard-road'),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _i = 0;

  void _next() {
    if (_i == _slides.length - 1) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const WelcomeScreen()));
    } else {
      _pc.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _slides.length - 1;
    return Scaffold(
      backgroundColor: C.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(children: [
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _slides.length,
                onPageChanged: (v) => setState(() => _i = v),
                itemBuilder: (c, i) => Column(children: [
                  Expanded(
                    flex: 6,
                    child: Stack(fit: StackFit.expand, children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(56)),
                        child: AppImage(_slides[i].seed, radius: 0),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: SafeArea(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const WelcomeScreen())),
                            child: Text(tr('Skip'), style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                      child: Column(children: [
                        Text(_slides[i].quote, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, height: 1.3)),
                        const SizedBox(height: 12),
                        Text(_slides[i].by, style: const TextStyle(color: C.muted, fontSize: 13)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.all(4),
                  width: i == _i ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(color: i == _i ? C.primary : C.line, borderRadius: BorderRadius.circular(4)),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: SafeArea(top: false, child: PrimaryButton(last ? 'Get Started' : 'Next', onPressed: _next)),
            ),
          ]),
        ),
      ),
    );
  }
}
