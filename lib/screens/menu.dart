import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
import '../widgets/pull_refresh.dart';
import '../widgets/social_widgets.dart';
import 'bookings.dart';
import 'friends.dart';
import 'groups.dart';
import 'meetups.dart';
import 'messages.dart';
import 'notifications.dart';
import 'profile.dart';
import 'shell.dart';
import 'traveler_profile.dart';
import 'transport.dart';

/// Menu tab: profile card, shortcut grid and settings.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final social = context.watch<SocialState>();
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 900
        ? 4
        : w >= 600
            ? 3
            : 2;
    final items = <(IconData, Color, String, String?, VoidCallback)>[
      (Icons.people_alt_rounded, const Color(0xFF6FB7E9), 'Travel buddies', social.incoming.isEmpty ? null : '${social.incoming.length} new', () => go(context, const FriendsScreen())),
      (Icons.chat_bubble_rounded, const Color(0xFFB68CF0), 'Messages', social.unreadChats == 0 ? null : '${social.unreadChats} unread', () => go(context, const MessagesScreen())),
      (Icons.groups_rounded, const Color(0xFF7CC08D), 'Groups', '${social.joined.length} joined', () => go(context, const GroupsScreen())),
      (
        Icons.event_rounded,
        const Color(0xFFE76F51),
        'Meetups',
        social.meetups.where((m) => !m.isPast).isEmpty ? null : '${social.meetups.where((m) => !m.isPast).length} upcoming',
        () => go(context, const MeetupsScreen())
      ),
      (Icons.map_rounded, C.primary, 'Trip planner', '${social.trips.length} plans', () => shellTab.value = 3),
      (Icons.confirmation_number_rounded, const Color(0xFFE9C46A), 'Bookings', null, () => go(context, const Scaffold(body: BookingsScreen()))),
      (Icons.smart_display_rounded, C.danger, 'Watch', null, () => shellTab.value = 2),
      (Icons.bookmark_rounded, const Color(0xFFE88DB0), 'Saved', null, () => go(context, const SavedPlacesScreen())),
      (Icons.badge_rounded, const Color(0xFF8FB3AC), 'Local guides', null, () => go(context, const GuidesScreen())),
      (Icons.notifications_rounded, const Color(0xFFF4A261), 'Notifications', s.unread == 0 ? null : '${s.unread} new', () => go(context, const NotificationsScreen())),
    ];
    return Scaffold(
      appBar: Bp.isWide(context)
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              centerTitle: false,
              title: const Text('Menu', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              actions: [...headerActions(context), const SizedBox(width: 12)],
            ),
      body: Constrained(
        maxWidth: 900,
        child: PullRefresh(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          Panel(
            onTap: () => go(context, TravelerProfileScreen(traveler: me(s))),
            child: Row(children: [
              Avatar(s.avatarSeed, name: s.name, radius: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const Text('See your traveler profile', style: TextStyle(color: C.muted, fontSize: 12.5)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: C.muted),
            ]),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisExtent: 92, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: items.length,
            itemBuilder: (c, i) {
              final it = items[i];
              return Panel(
                padding: const EdgeInsets.all(12),
                onTap: it.$5,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(it.$1, color: it.$2, size: 26),
                  const Spacer(),
                  Text(it.$3, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  if (it.$4 != null) Text(it.$4!, style: const TextStyle(color: C.muted, fontSize: 11.5)),
                ]),
              );
            },
          ),
          const SizedBox(height: 16),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.settings_rounded, color: C.muted),
                title: const Text('Settings & privacy', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded, color: C.muted),
                onTap: () => go(context, const ProfileScreen(standalone: true)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.verified_user_rounded, color: C.muted),
                title: const Text('Safety center', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                subtitle: const Text('Travel advisories, emergency numbers, report a user', style: TextStyle(color: C.muted, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded, color: C.muted),
                onTap: () => toast(context, 'Safety center opens in the next update'),
              ),
            ]),
          ),
        ])),
      ),
    );
  }
}
