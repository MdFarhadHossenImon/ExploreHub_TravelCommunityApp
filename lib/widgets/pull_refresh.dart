import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/app_state.dart';
import '../state/social_state.dart';

/// Facebook-style "pull down to reload" for any scrollable page.
/// Reloads the feed, stories, chats, buddies, places and notifications.
class PullRefresh extends StatelessWidget {
  const PullRefresh({super.key, required this.child, this.extra});
  final Widget child;
  final Future<void> Function()? extra;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        color: C.primary,
        displacement: 48,
        triggerMode: RefreshIndicatorTriggerMode.anywhere,
        onRefresh: () async {
          final app = context.read<AppState>();
          final social = context.read<SocialState>();
          await Future.wait([
            app.pullRefresh(),
            social.load(),
            if (extra != null) extra!(),
          ]);
        },
        child: child,
      );
}
