import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../data/social.dart';
import '../state/app_state.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
import '../widgets/pull_refresh.dart';
import 'bookings.dart';
import 'community.dart';
import 'friends.dart';
import 'groups.dart';
import 'meetups.dart';
import 'traveler_profile.dart';
import 'trips.dart';

/// Facebook-style badge: icon and colour for each kind of notification.
(IconData, Color) _badge(String k) {
  switch (k) {
    case 'like':
      return (Icons.favorite_rounded, const Color(0xFFE5484D));
    case 'comment':
      return (Icons.mode_comment_rounded, const Color(0xFF30A46C));
    case 'follow':
      return (Icons.person_add_alt_1_rounded, const Color(0xFF3E63DD));
    case 'buddy':
      return (Icons.handshake_rounded, const Color(0xFF3E63DD));
    case 'group':
      return (Icons.groups_rounded, const Color(0xFF8E4EC6));
    case 'meetup':
      return (Icons.event_available_rounded, const Color(0xFFF76B15));
    case 'trip':
      return (Icons.map_rounded, const Color(0xFF12A594));
    case 'hotel':
      return (Icons.apartment_rounded, const Color(0xFF0090FF));
    case 'flight':
      return (Icons.flight_rounded, const Color(0xFF0090FF));
    case 'community':
      return (Icons.favorite_rounded, const Color(0xFFE5484D));
    default:
      return (Icons.notifications_rounded, C.primary);
  }
}

/// Opens whatever the notification is about: the post, the profile, the group, etc.
Future<void> openNotification(BuildContext context, AppNotification n) async {
  final app = context.read<AppState>();
  final social = context.read<SocialState>();
  app.markRead(n);
  final id = n.targetId;
  final type = n.targetType;
  try {
    switch (type) {
      case 'post':
        if (id == null) break;
        final p = await Backend.postById(id);
        if (!context.mounted) return;
        if (p == null) return toast(context, 'This post was deleted');
        if (n.kind == 'comment') await app.loadComments(p);
        if (!context.mounted) return;
        go(context, Scaffold(appBar: AppBar(title: const Text('Post')), body: ListView(children: [PostCard(p)])));
        return;
      case 'profile':
        if (id == null) break;
        final known = travelers.where((t) => t.id == id);
        final t = known.isNotEmpty ? known.first : await Backend.fetchTraveler(id);
        if (!context.mounted) return;
        if (t == null) return toast(context, 'This traveler is no longer on ExploreHub');
        go(context, TravelerProfileScreen(traveler: t));
        return;
      case 'group':
        final g = social.groups.where((x) => x.id == id);
        go(context, g.isNotEmpty ? GroupDetailScreen(group: g.first) : const GroupsScreen());
        return;
      case 'trip':
        final t = social.trips.where((x) => x.id == id);
        go(context, t.isNotEmpty ? TripDetailScreen(trip: t.first) : const TripsHubScreen());
        return;
      case 'meetup':
        if (social.meetups.every((x) => x.id != id)) await social.loadMeetups();
        if (!context.mounted) return;
        final m = social.meetups.where((x) => x.id == id);
        go(context, m.isNotEmpty ? MeetupDetailScreen(meetup: m.first) : const MeetupsScreen());
        return;
      case 'booking':
        final b = app.bookings.where((x) => x.id == id);
        go(context, b.isNotEmpty ? BookingDetailScreen(booking: b.first) : const BookingsScreen());
        return;
    }
    // Older notifications without a target: open the closest screen.
    if (!context.mounted) return;
    switch (n.kind) {
      case 'buddy':
      case 'follow':
        go(context, const FriendsScreen());
      case 'group':
        go(context, const GroupsScreen());
      case 'meetup':
        go(context, const MeetupsScreen());
      case 'trip':
        go(context, const TripsHubScreen());
      case 'hotel':
      case 'flight':
        go(context, const BookingsScreen());
    }
  } catch (e) {
    if (context.mounted) toast(context, 'Could not open this right now');
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final days = <String>[];
    for (final n in s.notifications) {
      if (!days.contains(n.day)) days.add(n.day);
    }
    return ScreenScaffold(
      title: 'Notifications',
      actions: [TextButton(onPressed: s.unread == 0 ? null : s.markAllRead, child: const Text('Read all'))],
      body: PullRefresh(
        child: s.notifications.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                SizedBox(height: 120),
                EmptyState(Icons.notifications_none_rounded, 'All caught up', 'Likes, comments, buddy requests and bookings show up here.'),
              ])
            : ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(vertical: 8), children: [
                for (final d in days) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Text(d, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  for (final n in s.notifications.where((x) => x.day == d)) _NotificationTile(n),
                ],
              ]),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification n;
  const _NotificationTile(this.n);

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _badge(n.kind);
    final hasActor = n.actorName != null;
    return Material(
      color: n.read ? Colors.transparent : C.primary.withValues(alpha: .08),
      child: InkWell(
        onTap: () => openNotification(context, n),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(clipBehavior: Clip.none, children: [
                hasActor
                    ? Avatar(n.actorAvatar ?? '', name: n.actorName!, radius: 28)
                    : CircleAvatar(radius: 28, backgroundColor: color.withValues(alpha: .15), child: Icon(icon, color: color, size: 28)),
                if (hasActor)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: C.bg, width: 2)),
                      child: Icon(icon, color: Colors.white, size: 13),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700, fontSize: 14, height: 1.3)),
                if (n.body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
                ],
                const SizedBox(height: 4),
                Text(n.time, style: TextStyle(fontSize: 11.5, color: n.read ? C.muted : C.primary, fontWeight: FontWeight.w600)),
              ]),
            ),
            if (!n.read)
              Container(width: 10, height: 10, margin: const EdgeInsets.only(left: 8), decoration: const BoxDecoration(color: C.primary, shape: BoxShape.circle)),
          ]),
        ),
      ),
    );
  }
}
