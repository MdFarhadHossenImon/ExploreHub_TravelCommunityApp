import 'package:flutter/material.dart';
import '../core/i18n.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/mock_data.dart';
import '../data/social.dart';
import '../state/app_state.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
import '../widgets/social_widgets.dart';
import 'bookings.dart';
import 'friends.dart';
import 'groups.dart';
import 'messages.dart';
import 'place_detail.dart';
import 'profile.dart';
import 'shell.dart';
import 'traveler_profile.dart';
import 'transport.dart';
import 'trips.dart';

/// Desktop left column: shortcuts + your groups.
class LeftSidebar extends StatelessWidget {
  const LeftSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final social = context.watch<SocialState>();
    return ListView(padding: const EdgeInsets.fromLTRB(12, 16, 8, 24), children: [
      ShortcutTile(
        leading: Avatar(s.avatarSeed, name: s.name, radius: 18),
        label: s.name,
        onTap: () => go(context, TravelerProfileScreen(traveler: me(s))),
      ),
      ShortcutTile(
          leading: const IconBubble(Icons.people_alt_rounded, Color(0xFF6FB7E9)),
          label: tr('Travel buddies'),
          trailing: social.incoming.isEmpty ? null : '${social.incoming.length}',
          onTap: () => go(context, const FriendsScreen())),
      ShortcutTile(
          leading: const IconBubble(Icons.chat_bubble_rounded, Color(0xFFB68CF0)),
          label: tr('Messages'),
          trailing: social.unreadChats == 0 ? null : '${social.unreadChats}',
          onTap: () => go(context, const MessagesScreen())),
      ShortcutTile(leading: const IconBubble(Icons.groups_rounded, Color(0xFF7CC08D)), label: tr('Groups'), onTap: () => go(context, const GroupsScreen())),
      ShortcutTile(leading: const IconBubble(Icons.map_rounded, C.primary), label: tr('Trip planner'), onTap: () => shellTab.value = 3),
      ShortcutTile(leading: const IconBubble(Icons.smart_display_rounded, C.danger), label: tr('Watch'), onTap: () => shellTab.value = 2),
      ShortcutTile(
          leading: const IconBubble(Icons.confirmation_number_rounded, Color(0xFFE9C46A)),
          label: tr('Bookings'),
          onTap: () => go(context, const Scaffold(body: BookingsScreen()))),
      ShortcutTile(leading: const IconBubble(Icons.bookmark_rounded, Color(0xFFE88DB0)), label: tr('Saved places'), onTap: () => go(context, const SavedPlacesScreen())),
      ShortcutTile(leading: const IconBubble(Icons.badge_rounded, Color(0xFF8FB3AC)), label: tr('Local guides'), onTap: () => go(context, const GuidesScreen())),
      const Divider(height: 28),
      Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 8, 6),
        child: Text(tr('Your groups'), style: TextStyle(color: C.muted, fontWeight: FontWeight.w700, fontSize: 13.5)),
      ),
      for (final g in social.myGroups)
        ShortcutTile(
          leading: AppImage(g.coverSeed, width: 36, height: 36, radius: 10),
          label: g.name,
          onTap: () => go(context, GroupDetailScreen(group: g)),
        ),
      Padding(
        padding: EdgeInsets.fromLTRB(8, 18, 8, 0),
        child: Text(tr('Privacy · Terms · Help · ExploreHub © 2026'), style: TextStyle(color: C.muted, fontSize: 11.5)),
      ),
    ]);
  }
}

/// Desktop right column: upcoming trip, requests, online buddies, trending.
class RightSidebar extends StatelessWidget {
  const RightSidebar({super.key});

  Widget _h(String t, {VoidCallback? onAll}) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(children: [
          Expanded(child: Text(tr(t), style: const TextStyle(color: C.muted, fontWeight: FontWeight.w700, fontSize: 13.5))),
          if (onAll != null) GestureDetector(onTap: onAll, child: Text(tr('See all'), style: TextStyle(color: C.primary, fontSize: 12.5))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialState>();
    final trip = social.trips.isEmpty ? null : social.trips.first;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
      if (trip != null) ...[
        _h('Your next trip', onAll: () => shellTab.value = 3),
        TripCard(trip, compact: true),
      ],
      if (social.requestList.isNotEmpty) ...[
        _h('Buddy requests', onAll: () => go(context, const FriendsScreen())),
        for (final t in social.requestList)
          Panel(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              GestureDetector(onTap: () => go(context, TravelerProfileScreen(traveler: t)), child: Avatar(t.seed, name: t.name, radius: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  GestureDetector(onTap: () => go(context, TravelerProfileScreen(traveler: t)), child: VerifiedName(t, size: 13.5)),
                  Text(trf('{0} mutual buddies', [social.mutuals(t)]), style: const TextStyle(color: C.muted, fontSize: 11.5)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: FilledButton(style: FilledButton.styleFrom(visualDensity: VisualDensity.compact), onPressed: () => social.acceptRequest(t.id), child: Text(tr('Accept')))),
                    const SizedBox(width: 6),
                    Expanded(
                        child: OutlinedButton(
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: C.ink, side: const BorderSide(color: C.line)),
                            onPressed: () => social.declineRequest(t.id),
                            child: Text(tr('Delete')))),
                  ]),
                ]),
              ),
            ]),
          ),
      ],
      _h('Buddies online'),
      for (final t in social.onlineBuddies)
        ShortcutTile(
          leading: PersonAvatar(t, radius: 17, showOnline: true),
          label: t.name,
          onTap: () => go(context, ChatScreen(conversation: social.chatWith(t))),
        ),
      _h('Trending destinations'),
      for (final p in places.take(4))
        ShortcutTile(
          leading: AppImage(p.photo, width: 40, height: 40, radius: 10),
          label: '${p.name} · ${p.country}',
          onTap: () => go(context, PlaceDetailScreen(place: p)),
        ),
    ]);
  }
}

/// Horizontal "Travelers you may know" strip inserted into the phone feed.
class PeopleStrip extends StatelessWidget {
  const PeopleStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialState>();
    final list = social.suggestions;
    if (list.isEmpty) return const SizedBox.shrink();
    return Panel(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Expanded(child: Text(tr('Travelers you may know'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            GestureDetector(onTap: () => go(context, const FriendsScreen()), child: Text(tr('See all'), style: TextStyle(color: C.primary, fontSize: 12.5))),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (c, i) => SuggestionCard(list[i]),
          ),
        ),
      ]),
    );
  }
}

class SuggestionCard extends StatelessWidget {
  final Traveler t;
  const SuggestionCard(this.t, {super.key});

  @override
  Widget build(BuildContext context) {
    final going = t.nextTrip == null ? null : placeById(t.nextTrip!);
    return Container(
      width: 160,
      decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cover, photo, name and home all open the traveler's profile.
        InkWell(
          onTap: () => go(context, TravelerProfileScreen(traveler: t)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 96,
              child: Stack(children: [
                AppImage(t.cover ?? 'cover-${t.seed}', height: 70, width: double.infinity, radius: 0),
                Positioned(left: 10, bottom: 0, child: CircleAvatar(radius: 26, backgroundColor: C.bg, child: Avatar(t.seed, name: t.name, radius: 23))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                VerifiedName(t, size: 13),
                const SizedBox(height: 2),
                Text(going == null ? t.home : 'Going to ${going.name}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 11.5)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: BuddyButton(t, dense: true)),
          ]),
        ),
      ]),
    );
  }
}
