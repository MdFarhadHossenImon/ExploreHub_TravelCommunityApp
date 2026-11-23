import 'package:flutter/material.dart';

/// Layout breakpoints used across the app.
/// < 840  : phone  (bottom navigation)
/// >= 840 : tablet / desktop / web (navigation rail, grids, side panels)
class Bp {
  static const wide = 840.0;
  static const desktop = 1180.0;
  static bool isWide(BuildContext c) => MediaQuery.sizeOf(c).width >= wide;
  static bool isDesktop(BuildContext c) => MediaQuery.sizeOf(c).width >= desktop;
}

/// Centers [child] and limits its width on large screens.
class Constrained extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const Constrained({super.key, required this.child, this.maxWidth = 1100});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
