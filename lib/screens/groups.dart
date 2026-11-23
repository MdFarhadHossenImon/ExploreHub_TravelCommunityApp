import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../data/social.dart';
import '../state/app_state.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
import '../widgets/pull_refresh.dart';
import '../widgets/social_widgets.dart';
import 'community.dart';

/// Groups hub: your groups, discover, and a combined feed of group posts.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialState>();
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 1100
        ? 3
        : w >= 640
            ? 2
            : 1;
    final groupFeed = [
      for (final g in social.myGroups)
        for (final p in g.posts) (g, p),
    ];
    return Scaffold(
      appBar: AppBar(
        leading: const BackCircle(),
        leadingWidth: 56,
        title: const Text('Groups'),
        actions: [
          IconButton(tooltip: 'Create group', onPressed: () => _create(context), icon: const Icon(Icons.add_circle_outline_rounded, color: C.primary)),
        ],
      ),
      body: Constrained(
        maxWidth: Bp.isDesktop(context) ? 1100 : 760,
        child: PullRefresh(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Your groups', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 10),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: social.myGroups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (c, i) {
                final g = social.myGroups[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => go(context, GroupDetailScreen(group: g)),
                  child: SizedBox(
                    width: 120,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AppImage(g.coverSeed, width: 120, height: 72, radius: 14),
                      const SizedBox(height: 6),
                      Text(g.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          const Text('Discover groups', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisExtent: 226, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemCount: social.discoverGroups.length,
            itemBuilder: (c, i) => GroupCard(social.discoverGroups[i]),
          ),
          const SizedBox(height: 22),
          const Text('Recent activity', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 10),
          for (final e in groupFeed) Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: PostCard(e.$2, groupName: e.$1.name))),
        ])),
      ),
    );
  }

  void _create(BuildContext context) {
    final name = TextEditingController();
    final about = TextEditingController();
    var private = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, MediaQuery.of(c).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Create a group', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 14),
            LabeledField('Name', 'e.g. Sundarbans Explorers', controller: name),
            LabeledField('About', 'What is this group for?', controller: about, maxLines: 2),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Private group'),
              subtitle: const Text('Only members see posts', style: TextStyle(color: C.muted, fontSize: 12)),
              value: private,
              onChanged: (v) => set(() => private = v),
            ),
            const SizedBox(height: 8),
            PrimaryButton('Create group', onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final social = c.read<SocialState>();
              final nav = Navigator.of(c);
              final g = await social.createGroup(name.text.trim(), about.text.trim().isEmpty ? 'A new travel group.' : about.text.trim(), private);
              nav.pop();
              if (g != null && context.mounted) go(context, GroupDetailScreen(group: g));
            }),
          ]),
        ),
      ),
    );
  }
}

class GroupCard extends StatelessWidget {
  final TravelGroup g;
  const GroupCard(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialState>();
    final joined = social.joined.contains(g.id);
    final pending = social.pending.contains(g.id);
    return Panel(
      padding: EdgeInsets.zero,
      onTap: () => go(context, GroupDetailScreen(group: g)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppImage(g.coverSeed, height: 110, width: double.infinity, radius: 0),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            const SizedBox(height: 2),
            Text('${g.private ? 'Private' : 'Public'} group · ${compact(g.members)} members', style: const TextStyle(color: C.muted, fontSize: 12)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: joined
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: C.ink, side: const BorderSide(color: C.line)),
                      onPressed: () => go(context, GroupDetailScreen(group: g)),
                      child: const Text('View group'))
                  : FilledButton(
                      onPressed: () => social.toggleJoin(g),
                      child: Text(pending
                          ? 'Requested'
                          : g.private
                              ? 'Request to join'
                              : 'Join group')),
            ),
          ]),
        ),
      ]),
    );
  }
}

class GroupDetailScreen extends StatefulWidget {
  final TravelGroup group;
  const GroupDetailScreen({super.key, required this.group});
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    context.read<SocialState>().loadGroupPosts(widget.group);
  }

  void _post() {
    final ctl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Post in ${widget.group.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(controller: ctl, maxLines: 4, decoration: const InputDecoration(hintText: 'Ask a question or share an update...')),
          const SizedBox(height: 12),
          PrimaryButton('Post', icon: Icons.send_rounded, onPressed: () {
            if (ctl.text.trim().isEmpty) return;
            final s = context.read<AppState>();
            context.read<SocialState>().postToGroup(
                  widget.group,
                  // text-only post: no photo (an empty media URL shows as a text card)
                  Post(id: 'gp${DateTime.now().millisecondsSinceEpoch}', userName: s.name, userSeed: s.avatarSeed, userId: Backend.uid, caption: ctl.text.trim(), imageSeed: '', time: 'now'),
                );
            Navigator.pop(c);
          }),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialState>();
    final g = widget.group;
    final joined = social.joined.contains(g.id);
    final pending = social.pending.contains(g.id);
    final canSee = joined || !g.private;
    final members = travelers.take(6).toList();
    return Scaffold(
      body: PullRefresh(
          child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 220,
          leading: const BackCircle(),
          leadingWidth: 56,
          title: Text(g.name),
          flexibleSpace: FlexibleSpaceBar(background: AppImage(g.coverSeed, radius: 0)),
        ),
        SliverToBoxAdapter(
          child: Constrained(
            maxWidth: 720,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(g.private ? Icons.lock_rounded : Icons.public_rounded, size: 15, color: C.muted),
                  const SizedBox(width: 4),
                  Text('${g.private ? 'Private' : 'Public'} group · ${compact(g.members)} members', style: const TextStyle(color: C.muted, fontSize: 13)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  AvatarStack(members, radius: 14),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Ayesha, Mei and 12 buddies are members', overflow: TextOverflow.ellipsis, style: TextStyle(color: C.muted, fontSize: 12.5))),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: joined
                        ? FilledButton.icon(onPressed: _post, icon: const Icon(Icons.edit_rounded, size: 18), label: const Text('Write post'))
                        : FilledButton.icon(
                            onPressed: () => social.toggleJoin(g),
                            icon: Icon(pending ? Icons.schedule_rounded : Icons.group_add_rounded, size: 18),
                            label: Text(pending
                                ? 'Requested'
                                : g.private
                                    ? 'Request to join'
                                    : 'Join group')),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: C.ink, side: const BorderSide(color: C.line)),
                    onPressed: () => toast(context, 'Invite link copied'),
                    icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                    label: const Text('Invite'),
                  ),
                  if (joined) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (_) => social.toggleJoin(g),
                      itemBuilder: (_) => const [PopupMenuItem(value: 'leave', child: Text('Leave group'))],
                    ),
                  ],
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Discussion')),
                      ButtonSegment(value: 1, label: Text('About')),
                      ButtonSegment(value: 2, label: Text('Members')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (v) => setState(() => _tab = v.first),
                  ),
                ),
                const SizedBox(height: 14),
                if (_tab == 1) ...[
                  Text(g.about, style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 16),
                  if (g.rules.isNotEmpty) ...[
                    const Text('Group rules', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 8),
                    for (var i = 0; i < g.rules.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(radius: 14, backgroundColor: C.tint, child: Text('${i + 1}', style: const TextStyle(color: C.primary, fontSize: 12, fontWeight: FontWeight.w700))),
                        title: Text(g.rules[i], style: const TextStyle(fontSize: 14)),
                      ),
                  ],
                ],
                if (_tab == 2)
                  for (final t in members)
                    ListTile(contentPadding: EdgeInsets.zero, leading: PersonAvatar(t, showOnline: true), title: VerifiedName(t), subtitle: Text(t.home), trailing: BuddyButton(t, dense: true)),
              ]),
            ),
          ),
        ),
        if (_tab == 0)
          SliverToBoxAdapter(
            child: Constrained(
              maxWidth: 720,
              child: !canSee
                  ? const EmptyState(Icons.lock_outline_rounded, 'This group is private', 'Join to see posts and members.')
                  : g.posts.isEmpty
                      ? const EmptyState(Icons.forum_outlined, 'No posts yet', 'Be the first to start a discussion.')
                      : Column(children: [for (final p in g.posts) PostCard(p, groupName: g.name)]),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ])),
    );
  }
}
