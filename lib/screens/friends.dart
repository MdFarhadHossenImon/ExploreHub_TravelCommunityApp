import 'package:flutter/material.dart';
import '../core/i18n.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/mock_data.dart';
import '../data/social.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
import '../widgets/pull_refresh.dart';
import '../widgets/social_widgets.dart';
import 'feed_sidebars.dart';
import 'messages.dart';
import 'traveler_profile.dart';

/// Travel buddies: requests, suggestions, buddy finder by destination, and your buddy list.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  int _tab = 0;
  String? _dest;

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialState>();
    final cols = MediaQuery.sizeOf(context).width >= 1100
        ? 4
        : MediaQuery.sizeOf(context).width >= 700
            ? 3
            : 2;
    final tabs = ['Requests', 'Suggestions', 'Buddy finder', 'Your buddies'];

    Widget grid(List<Traveler> list) => GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisExtent: 236, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: list.length,
          itemBuilder: (c, i) => SuggestionCard(list[i]),
        );

    Widget body;
    switch (_tab) {
      case 0:
        body = social.requestList.isEmpty
            ? const EmptyState(Icons.mark_email_read_outlined, 'No pending requests', 'When travelers ask to be your buddy, they show here.')
            : Column(children: [
                for (final t in social.requestList)
                  Panel(
                    margin: const EdgeInsets.only(bottom: 10),
                    onTap: () => go(context, TravelerProfileScreen(traveler: t)),
                    child: Row(children: [
                      Avatar(t.seed, name: t.name, radius: 30),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          VerifiedName(t, size: 15),
                          const SizedBox(height: 2),
                          Row(children: [
                            LevelBadge(t),
                            const SizedBox(width: 6),
                            Flexible(child: Text(trf('{0} mutual · {1} places', [social.mutuals(t), t.placesVisited]), overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 12.5))),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            FilledButton(onPressed: () => social.acceptRequest(t.id), child: Text(tr('Confirm'))),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: C.ink, side: const BorderSide(color: C.line)),
                              onPressed: () => social.declineRequest(t.id),
                              child: Text(tr('Delete')),
                            ),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
              ]);
      case 1:
        body = grid(social.suggestions);
      case 2:
        final going = travelers.where((t) => _dest == null ? t.nextTrip != null : t.nextTrip == _dest).toList();
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Find travelers heading to the same place as you, split costs and explore together.'), style: TextStyle(color: C.muted, fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(label: Text(tr('Anywhere')), selected: _dest == null, onSelected: (_) => setState(() => _dest = null)),
            for (final p in places.where((p) => travelers.any((t) => t.nextTrip == p.id))) ChoiceChip(label: Text(p.name), selected: _dest == p.id, onSelected: (_) => setState(() => _dest = p.id)),
          ]),
          const SizedBox(height: 14),
          for (final t in going)
            Panel(
              margin: const EdgeInsets.only(bottom: 10),
              onTap: () => go(context, TravelerProfileScreen(traveler: t)),
              child: Row(children: [
                PersonAvatar(t, radius: 26, showOnline: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    VerifiedName(t),
                    const SizedBox(height: 4),
                    Pill('Going to ${placeById(t.nextTrip!).name}', icon: Icons.flight_takeoff_rounded),
                    const SizedBox(height: 4),
                    Text(trf('From {0}', [t.home]), style: const TextStyle(color: C.muted, fontSize: 12)),
                  ]),
                ),
                IconButton(
                  tooltip: tr('Message'),
                  onPressed: () => go(context, ChatScreen(conversation: social.chatWith(t))),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: C.primary),
                ),
              ]),
            ),
        ]);
      default:
        body = Column(children: [
          for (final t in social.buddyList)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 2),
              onTap: () => go(context, TravelerProfileScreen(traveler: t)),
              leading: PersonAvatar(t, radius: 24, showOnline: true),
              title: VerifiedName(t),
              subtitle: Text(t.home, style: const TextStyle(color: C.muted, fontSize: 12.5)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: tr('Message'),
                  onPressed: () => go(context, ChatScreen(conversation: social.chatWith(t))),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: C.primary),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, color: C.muted),
                  onSelected: (_) => social.removeBuddy(t.id),
                  itemBuilder: (_) => [PopupMenuItem(value: 'remove', child: Text(tr('Remove buddy')))],
                ),
              ]),
            ),
        ]);
    }

    return Scaffold(
      appBar: AppBar(leading: const BackCircle(), leadingWidth: 56, title: Text(tr('Travel buddies'))),
      body: Constrained(
        maxWidth: Bp.isDesktop(context) ? 1000 : 760,
        child: PullRefresh(
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (c, i) => ChoiceChip(
                label: Text(i == 0 && social.incoming.isNotEmpty ? '${tabs[i]} (${social.incoming.length})' : tabs[i]),
                selected: _tab == i,
                showCheckmark: false,
                selectedColor: C.primary,
                labelStyle: TextStyle(color: _tab == i ? C.on : C.ink, fontWeight: FontWeight.w600),
                onSelected: (_) => setState(() => _tab = i),
              ),
            ),
          ),
          const SizedBox(height: 16),
          body,
        ])),
      ),
    );
  }
}
