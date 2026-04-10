import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class ExploreHubApp extends StatelessWidget {
  const ExploreHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();
    return MaterialApp.router(
      title: 'ExploreHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
