import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/social.dart';
import '../state/app_state.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
import '../widgets/social_widgets.dart';
import 'community.dart';
import 'global_search.dart';
import 'home.dart';
import 'menu.dart';
import 'messages.dart';
import 'notifications.dart';
import 'traveler_profile.dart';
import 'trips.dart';
import 'watch.dart';

/// Lets any screen switch the main tab (0 Feed, 1 Explore, 2 Watch, 3 Trips, 4 Menu).
final ValueNotifier<int> shellTab = ValueNotifier<int>(0);

/// Pops back to the shell and selects [tab].
void openTab(BuildContext context, int tab) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  shellTab.value = tab;
}

class _Dest {
  final IconData icon, active;
  final String label;
  const _Dest(this.icon, this.active, this.label);
}

const _dests = [
  _Dest(Icons.home_outlined, Icons.home_rounded, 'Home'),
  _Dest(Icons.explore_outlined, Icons.explore_rounded, 'Explore'),
  _Dest(Icons.smart_display_outlined, Icons.smart_display_rounded, 'Watch'),
  _Dest(Icons.map_outlined, Icons.map_rounded, 'Trips'),
  _Dest(Icons.menu_rounded, Icons.menu_rounded, 'Menu'),
];

/// Top-bar actions shared by the phone feed header and the desktop header.
List<Widget> headerActions(BuildContext context, {bool withSearch = true}) {
  final s = context.watch<AppState>();
  final social = context.watch<SocialState>();
  return [
    if (withSearch) ...[
      CircleAction(Icons.search_rounded, () => go(context, const GlobalSearchScreen()), tooltip: 'Search'),
      const SizedBox(width: 8),
    ],
    CircleAction(Icons.chat_bubble_rounded, () => go(context, const MessagesScreen()), badge: social.unreadChats, tooltip: 'Messages'),
    const SizedBox(width: 8),
    CircleAction(Icons.notifications_rounded, () => go(context, const NotificationsScreen()), badge: s.unread, tooltip: 'Notifications'),
  ];
}

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: shellTab,
      builder: (context, i, _) {
        const tabs = [CommunityScreen(), HomeScreen(), WatchScreen(), TripsHubScreen(), MenuScreen()];
        // Hidden tabs stay alive (instant switching) but their animations are paused.
        final body = IndexedStack(index: i, children: [
          for (var n = 0; n < tabs.length; n++) TickerMode(enabled: n == i, child: tabs[n]),
        ]);
        if (Bp.isWide(context)) {
          return Scaffold(body: Row(children: [_SideRail(index: i), Expanded(child: body)]));
        }
        return Scaffold(extendBody: false, body: body, bottomNavigationBar: _PillBar(index: i));
      },
    );
  }
}

/// Slim navigation rail for tablet / desktop / web.
class _SideRail extends StatelessWidget {
  final int index;
  const _SideRail({required this.index});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final social = context.watch<SocialState>();
    Widget item(int n) {
      final on = n == index;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Tooltip(
          message: _dests[n].label,
          preferBelow: false,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => shellTab.value = n,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: on ? C.primary : Colors.transparent, borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                Icon(on ? _dests[n].active : _dests[n].icon, color: on ? C.on : C.muted, size: 24),
                const SizedBox(height: 4),
                Text(_dests[n].label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: on ? C.on : C.muted)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 88,
      decoration: const BoxDecoration(color: C.card, border: Border(right: BorderSide(color: C.line))),
      child: SafeArea(
        child: Column(children: [
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => shellTab.value = 0,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.travel_explore_rounded, color: C.on, size: 26),
            ),
          ),
          const SizedBox(height: 18),
          Tooltip(
            message: 'Share a moment',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => go(context, const CreatePostScreen()),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.primary, width: 1.5)),
                child: const Icon(Icons.add_rounded, color: C.primary),
              ),
            ),
          ),
          const SizedBox(height: 18),
          for (var n = 0; n < _dests.length; n++) item(n),
          const Spacer(),
          CircleAction(Icons.search_rounded, () => go(context, const GlobalSearchScreen()), tooltip: 'Search'),
          const SizedBox(height: 10),
          CircleAction(Icons.chat_bubble_rounded, () => go(context, const MessagesScreen()), badge: social.unreadChats, tooltip: 'Messages'),
          const SizedBox(height: 10),
          CircleAction(Icons.notifications_rounded, () => go(context, const NotificationsScreen()), badge: s.unread, tooltip: 'Notifications'),
          const SizedBox(height: 14),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => go(context, TravelerProfileScreen(traveler: me(s))),
            child: Avatar(s.avatarSeed, name: s.name, radius: 20),
          ),
          const SizedBox(height: 18),
        ]),
      ),
    );
  }
}

/// The signed-in user as a [Traveler], so their profile uses the same screen as everyone else's.
Traveler me(AppState s) => Traveler(
      id: meId,
      name: s.name.isEmpty ? 'Traveler' : s.name,
      seed: s.avatarSeed,
      handle: s.username ?? s.email.split('@').first,
      home: s.home,
      bio: s.bio,
      countries: s.countries,
      cover: s.coverUrl,
      followers: s.followers,
      following: s.followingCount,
      trips: s.tripCount,
      placesVisited: s.placesVisited,
      visitedCountries: s.visitedCountries,
    );

/// Floating pill navigation for phones, with a raised "share" button in the middle.
class _PillBar extends StatelessWidget {
  final int index;
  const _PillBar({required this.index});

  @override
  Widget build(BuildContext context) {
    Widget tab(int n) {
      final on = n == index;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: _dests[n].label,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => shellTab.value = n,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(on ? _dests[n].active : _dests[n].icon, color: on ? C.primary : C.muted, size: 24),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: on ? 18 : 0,
                height: 3,
                decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(2)),
              ),
            ]),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xF2152827),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: C.line),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: Row(children: [
            tab(0),
            tab(1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: C.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => go(context, const CreatePostScreen()),
                  child: const SizedBox(width: 50, height: 50, child: Icon(Icons.add_rounded, color: C.on, size: 28)),
                ),
              ),
            ),
            tab(3),
            tab(4),
          ]),
        ),
      ),
    );
  }
}
