import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/mock_data.dart';
import '../data/social.dart';
import '../state/app_state.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
import '../widgets/social_widgets.dart';
import 'community.dart';
import 'groups.dart';
import 'place_detail.dart';
import 'traveler_profile.dart';

/// One search box for travelers, places, groups and posts.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});
  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _q = TextEditingController();
  String _filter = 'All';

  bool _has(String text) => text.toLowerCase().contains(_q.text.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final social = context.watch<SocialState>();
    final q = _q.text.trim();
    final people = travelers.where((t) => q.isEmpty || _has(t.name) || _has(t.home) || _has(t.handle)).toList();
    final pl = places.where((p) => q.isEmpty || _has(p.name) || _has(p.country) || _has(p.category)).toList();
    final gr = social.groups.where((g) => q.isEmpty || _has(g.name) || _has(g.category)).toList();
    final po = s.posts.where((p) => q.isNotEmpty && (_has(p.caption) || _has(p.userName))).toList();
    bool show(String f) => _filter == 'All' || _filter == f;

    Widget h(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        );

    return Scaffold(
      appBar: AppBar(
        leading: const BackCircle(),
        leadingWidth: 56,
        titleSpacing: 0,
        title: TextField(
          controller: _q,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search ExploreHub',
            prefixIcon: const Icon(Icons.search_rounded, color: C.muted),
            suffixIcon: q.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(_q.clear)),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
        actions: const [SizedBox(width: 16)],
      ),
      body: Constrained(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Wrap(spacing: 8, children: [
            for (final f in const ['All', 'Travelers', 'Places', 'Groups', 'Posts'])
              ChoiceChip(
                label: Text(f),
                selected: _filter == f,
                showCheckmark: false,
                selectedColor: C.primary,
                labelStyle: TextStyle(color: _filter == f ? C.on : C.ink, fontWeight: FontWeight.w600),
                onSelected: (_) => setState(() => _filter = f),
              ),
          ]),
          if (show('Travelers') && people.isNotEmpty) ...[
            h('Travelers'),
            for (final t in people.take(_filter == 'All' ? 4 : 50))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                onTap: () => go(context, TravelerProfileScreen(traveler: t)),
                leading: PersonAvatar(t, radius: 22, showOnline: true),
                title: VerifiedName(t),
                subtitle: Text('${t.home} · ${compact(t.followers)} followers', style: const TextStyle(color: C.muted, fontSize: 12)),
                trailing: BuddyButton(t, dense: true),
              ),
          ],
          if (show('Places') && pl.isNotEmpty) ...[
            h('Places'),
            for (final p in pl.take(_filter == 'All' ? 4 : 50))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                onTap: () => go(context, PlaceDetailScreen(place: p)),
                leading: AppImage(p.photo, width: 48, height: 48, radius: 12),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${p.category} · ${p.where}', style: const TextStyle(color: C.muted, fontSize: 12)),
                trailing: RatingText(p.rating),
              ),
          ],
          if (show('Groups') && gr.isNotEmpty) ...[
            h('Groups'),
            for (final g in gr.take(_filter == 'All' ? 3 : 50))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                onTap: () => go(context, GroupDetailScreen(group: g)),
                leading: AppImage(g.coverSeed, width: 48, height: 48, radius: 12),
                title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${g.category} · ${compact(g.members)} members', style: const TextStyle(color: C.muted, fontSize: 12)),
              ),
          ],
          if (show('Posts') && po.isNotEmpty) ...[
            h('Posts'),
            for (final p in po) PostCard(p),
          ],
          if (q.isNotEmpty && people.isEmpty && pl.isEmpty && gr.isEmpty && po.isEmpty)
            const EmptyState(Icons.search_off_rounded, 'No results', 'Try a place, a country or a traveler name.'),
        ]),
      ),
    );
  }
}
