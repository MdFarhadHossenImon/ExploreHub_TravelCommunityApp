import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/i18n.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/env.dart';
import '../core/levels.dart';
import '../core/media_compress.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../data/social.dart';
import '../state/app_state.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
import '../widgets/pull_refresh.dart';
import '../widgets/feed_video.dart';
import '../widgets/rich_caption.dart';
import '../widgets/audience.dart';
import '../widgets/social_widgets.dart';
import 'feed_sidebars.dart';
import 'place_detail.dart';
import 'shell.dart';
import 'stories.dart';
import 'traveler_profile.dart';

/// Home feed in a travel-journal style: greeting, moments, filters, journey cards.
/// Desktop (>= 1180): two-column journal of cards with a trip panel.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _filter = 'For you';

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? 'Good morning'
        : h < 18
            ? 'Good afternoon'
            : 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final social = context.watch<SocialState>();
    final wide = Bp.isWide(context);
    final desktop = Bp.isDesktop(context);
    final first = s.name.trim().isEmpty ? 'traveler' : s.name.split(' ').first;

    var posts = s.posts;
    if (_filter == 'Buddies') {
      posts = posts.where((p) {
        final t = travelerForPost(p);
        return t != null && social.buddies.contains(t.id);
      }).toList();
    } else if (_filter == 'Videos') {
      posts = posts.where((p) => p.isVideo).toList();
    } else if (_filter == 'Bangladesh') {
      posts = posts.where((p) => p.placeId != null && placeById(p.placeId!).country == 'Bangladesh').toList();
    }

    final header = Padding(
      padding: EdgeInsets.fromLTRB(wide ? 28 : 18, wide ? 28 : 6, wide ? 28 : 14, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!wide) ...[
          Row(children: [
            const Logo(size: 20),
            const Spacer(),
            ...headerActions(context),
          ]),
          const SizedBox(height: 14),
        ],
        Text('${tr(_greeting())}, $first', style: const TextStyle(color: C.muted, fontSize: 13.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(tr('Your travel circle'), style: TextStyle(fontSize: wide ? 30 : 25, fontWeight: FontWeight.w800, letterSpacing: isBangla ? 0 : -.6, height: 1.1)),
      ]),
    );

    final chips = SizedBox(
      height: 40,
      child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 16), children: [
        for (final f in const ['For you', 'Buddies', 'Videos', 'Bangladesh'])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _filter == f ? C.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _filter == f ? C.ink : C.line),
                ),
                child: Text(tr(f), style: TextStyle(color: _filter == f ? C.bg : C.muted, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ),
      ]),
    );

    final empty = Padding(
      padding: const EdgeInsets.all(24),
      child: EmptyState(Icons.dynamic_feed_rounded, _filter == 'For you' ? 'Your feed is quiet' : 'Nothing here yet', 'Add travel buddies or join groups to see their journeys.'),
    );

    if (!desktop) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Constrained(
            maxWidth: 640,
            child: PullRefresh(
                child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 110), children: [
              header,
              const SizedBox(height: 14),
              const StoryRow(),
              const SizedBox(height: 16),
              chips,
              const SizedBox(height: 16),
              if (posts.isEmpty) empty,
              for (var i = 0; i < posts.length; i++) ...[
                PostCard(posts[i]),
                if (i == 1 && _filter == 'For you') const PeopleStrip(),
              ],
            ])),
          ),
        ),
      );
    }

    // Desktop: two-column "journal" of journey cards + a trip panel.
    final left = <Post>[], right = <Post>[];
    for (var i = 0; i < posts.length; i++) {
      (i.isEven ? left : right).add(posts[i]);
    }
    return Scaffold(
      body: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: PullRefresh(
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 40), children: [
            header,
            const SizedBox(height: 16),
            const StoryRow(padding: 28),
            const SizedBox(height: 18),
            chips,
            const SizedBox(height: 18),
            if (posts.isEmpty) empty,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [for (final p in left) PostCard(p)])),
                Expanded(child: Column(children: [for (final p in right) PostCard(p)])),
              ]),
            ),
          ])),
        ),
        Container(
          width: 340,
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: C.line))),
          child: const RightSidebar(),
        ),
      ]),
    );
  }
}

const reactionSet = [
  ('❤️', 'Love'),
  ('😍', 'Wow'),
  ('🧭', 'Want to go'),
  ('👏', 'Bravo'),
  ('😂', 'Haha'),
];

class PostCard extends StatelessWidget {
  final Post post;
  final String? groupName;
  const PostCard(this.post, {super.key, this.groupName});

  void _comments(BuildContext context) {
    context.read<AppState>().loadComments(post);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (c) => CommentsSheet(post),
    );
  }

  Future<void> _menu(BuildContext context, String v) async {
    final s = context.read<AppState>();
    if (v == 'report') {
      final reason = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(title: Text(tr('Report this post')), children: [
          for (final r in const ['Spam or scam', 'Nudity or sexual content', 'Hate or harassment', 'Violence', 'False travel information', 'Something else'])
            SimpleDialogOption(onPressed: () => Navigator.pop(c, r), child: Text(tr(r))),
        ]),
      );
      if (reason != null) await s.reportPost(post, reason);
    } else if (v == 'block') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Block ${post.userName}?'),
          content: Text(tr('You will no longer see their posts.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Block'))),
          ],
        ),
      );
      if (ok == true) await s.blockUser(post);
    } else if (v == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(tr('Delete this post?')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: C.danger), onPressed: () => Navigator.pop(c, true), child: Text(tr('Delete'))),
          ],
        ),
      );
      if (ok == true) await s.deletePost(post);
    } else if (v == 'save') {
      s.toggleSavePost(post);
    } else if (v == 'edit') {
      await _edit(context);
    }
  }

  /// Share sheet: re-post to your feed, send to a buddy in chat, or copy a link.
  void _share(BuildContext context) {
    if (post.audience != 'public') return toast(context, tr('Only public posts can be shared'));
    final s = context.read<AppState>();
    final social = context.read<SocialState>();
    final original = post.shared ?? post;
    final note = TextEditingController();
    final snippet = original.caption.length > 80 ? '${original.caption.substring(0, 80)}...' : original.caption;
    final linkText = '${original.userName} on ExploreHub: "$snippet" ${Env.webUrl}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Share'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 12),
          Row(children: [
            Avatar(s.avatarSeed, name: s.name, radius: 18),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: note, maxLines: 2, minLines: 1, decoration: InputDecoration(hintText: tr('Say something about this (optional)')))),
          ]),
          const SizedBox(height: 10),
          PrimaryButton('Share to my feed', icon: Icons.repeat_rounded, onPressed: () async {
            Navigator.pop(c);
            final ok = await s.sharePost(original, note.text.trim());
            if (ok && context.mounted) toast(context, tr('Shared to your feed'));
          }),
          if (social.buddyList.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(tr('Send to a buddy'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            SizedBox(
              height: 86,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final t in social.buddyList)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      social.send(social.chatWith(t), linkText);
                      Navigator.pop(c);
                      toast(context, 'Sent to ${t.name.split(' ').first}');
                    },
                    child: SizedBox(
                      width: 70,
                      child: Column(children: [
                        PersonAvatar(t, radius: 24),
                        const SizedBox(height: 6),
                        Text(t.name.split(' ').first, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link_rounded),
            title: Text(tr('Copy link')),
            onTap: () {
              Clipboard.setData(ClipboardData(text: linkText));
              Navigator.pop(c);
              toast(context, tr('Link copied'));
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final ctl = TextEditingController(text: plainText(post.caption));
    final picked = mentionsIn(post.caption);
    var aud = post.audience;
    final raw = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Edit post')),
        content: SizedBox(
          width: 420,
          child: StatefulBuilder(
            builder: (c, setD) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (post.groupId == null) ...[
                AudienceButton(value: aud, onChanged: (v) => setD(() => aud = v)),
                const SizedBox(height: 10),
              ],
              TextField(controller: ctl, maxLines: 6, minLines: 2, maxLength: 2000),
              MentionBar(controller: ctl, picked: picked),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: Text(tr('Save'))),
        ],
      ),
    );
    final text = raw == null ? null : encodeMentions(raw, picked);
    if (text != null && text.isNotEmpty && (text != post.caption || aud != post.audience) && context.mounted) {
      final ok = await context.read<AppState>().editPost(post, text, audience: aud != post.audience ? aud : null);
      if (ok && context.mounted) toast(context, tr('Post updated'));
    }
  }

  /// The original post inside a re-share.
  Widget _sharedBox(BuildContext context, Post o) => Container(
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(color: const Color(0x22000000), borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (o.imageSeed.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(fit: StackFit.expand, children: [
                mediaView(o.imageSeed, isVideo: o.isVideo, autoplay: false),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Avatar(o.userSeed, name: o.userName, radius: 12),
                const SizedBox(width: 8),
                Expanded(child: Text(o.userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
              ]),
              const SizedBox(height: 6),
              RichCaption(o.caption, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, height: 1.4)),
            ]),
          ),
        ]),
      );

  void _openAuthor(BuildContext context) => openPostAuthor(context, post);

  Future<void> _pickReaction(BuildContext context, Offset at) async {
    final s = context.read<AppState>();
    final social = context.read<SocialState>();
    final size = MediaQuery.sizeOf(context);
    final pick = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Reactions',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (c, _, __) => Stack(children: [
        Positioned(
          left: (at.dx - 30).clamp(8.0, size.width - 268),
          top: (at.dy - 74).clamp(8.0, size.height - 70),
          child: Material(
            color: C.card,
            elevation: 10,
            shape: const StadiumBorder(side: BorderSide(color: C.line)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final r in reactionSet)
                  Tooltip(
                    message: r.$2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(c).pop(r.$1),
                      child: Padding(padding: const EdgeInsets.all(6), child: Text(tr(r.$1), style: const TextStyle(fontSize: 28))),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ]),
    );
    if (pick == null) return;
    social.react(post.id, pick);
    if (!s.likedPosts.contains(post.id)) s.toggleLike(post);
  }

  void _tapLike(BuildContext context) {
    final s = context.read<AppState>();
    final social = context.read<SocialState>();
    if (s.likedPosts.contains(post.id)) social.react(post.id, null);
    s.toggleLike(post);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final social = context.watch<SocialState>();
    final liked = s.likedPosts.contains(post.id);
    final saved = s.savedPosts.contains(post.id);
    final reaction = social.reactions[post.id] ?? (liked ? '❤️' : null);
    final place = post.placeId == null ? null : placeById(post.placeId!);
    final mine = Backend.on ? post.userId == Backend.uid : post.userName == s.name;
    final traveler = travelerForPost(post);

    Widget glass(Widget child, {EdgeInsets padding = const EdgeInsets.fromLTRB(4, 4, 12, 4)}) => Container(
          padding: padding,
          decoration: BoxDecoration(color: const Color(0xB3101E1D), borderRadius: BorderRadius.circular(30)),
          child: child,
        );

    Widget stat(Widget icon, String? count, VoidCallback onTap, {String tip = '', GestureLongPressStartCallback? onLong, VoidCallback? onCount}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onLongPressStart: onLong,
              child: Tooltip(
                message: tip,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onTap,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(8, 8, onCount == null ? 8 : 2, 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      icon,
                      if (count != null && onCount == null) ...[const SizedBox(width: 5), Text(count, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))],
                    ]),
                  ),
                ),
              ),
            ),
            if (count != null && onCount != null)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onCount,
                child: Tooltip(
                  message: tr('See who reacted'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                    child: Text(count, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ),
          ],
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (post.imageSeed.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(colors: [Color(0xFF2A4A47), Color(0xFF223D3C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: C.line),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                GestureDetector(onTap: () => _openAuthor(context), child: Avatar(post.userSeed, name: post.userName, radius: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(post.userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    Row(children: [
                      Flexible(
                        child: Text([groupName ?? post.time, if (post.edited) 'edited', if (place != null) place.name else if (post.locationLabel != null) post.locationLabel!].join(' · '),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 11.5)),
                      ),
                      if (groupName == null)
                        Tooltip(
                          message: audienceLabel(post.audience),
                          child: Padding(padding: const EdgeInsets.only(left: 5), child: Icon(audienceIcon(post.audience), size: 12.5, color: C.muted)),
                        ),
                    ]),
                  ]),
                ),
                PopupMenuButton<String>(
                  tooltip: tr('More'),
                  icon: const Icon(Icons.more_horiz_rounded, color: C.muted),
                  onSelected: (v) => _menu(context, v),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'save', child: Text(saved ? tr('Remove from saved') : tr('Save post'))),
                    if (mine) ...[
                      PopupMenuItem(value: 'edit', child: Text(tr('Edit post'))),
                      PopupMenuItem(value: 'delete', child: Text(tr('Delete post'))),
                    ] else ...[
                      PopupMenuItem(value: 'report', child: Text(tr('Report post'))),
                      PopupMenuItem(value: 'block', child: Text(tr('Block user'))),
                    ],
                  ],
                ),
              ]),
              const SizedBox(height: 12),
              RichCaption(post.caption, style: TextStyle(fontSize: post.shared == null ? 17 : 14.5, height: 1.45, fontWeight: post.shared == null ? FontWeight.w600 : FontWeight.w500)),
              if (post.shared != null) _sharedBox(context, post.shared!),
            ]),
          )
        else
          GestureDetector(
            onDoubleTap: () {
              if (!liked) s.toggleLike(post);
            },
            child: ValueListenableBuilder<Map<String, double>>(
              valueListenable: videoAspects,
              builder: (context, aspects, child) {
                // Videos keep their real shape like Facebook: 16:9 stays wide, reels (9:16) stay tall.
                var ar = post.isVideo ? (aspects[post.imageSeed] ?? 16 / 9) : 1.0;
                ar = ar.clamp(9 / 16, 16 / 9);
                return LayoutBuilder(builder: (context, box) {
                  final maxH = MediaQuery.sizeOf(context).height * .78;
                  final h = box.maxWidth / ar;
                  return h > maxH ? SizedBox(height: maxH, width: box.maxWidth, child: child) : AspectRatio(aspectRatio: ar, child: child);
                });
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Stack(fit: StackFit.expand, children: [
                  mediaView(post.imageSeed, isVideo: post.isVideo),
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0x80000000), Colors.transparent, Colors.transparent, Color(0x99000000)],
                          stops: [0, .25, .65, 1],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  if (post.isVideo && !post.imageSeed.startsWith('http')) const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64)),
                  Positioned(
                    left: 12,
                    top: 12,
                    right: 56,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => _openAuthor(context),
                        child: glass(Row(mainAxisSize: MainAxisSize.min, children: [
                          Avatar(post.userSeed, name: post.userName, radius: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Flexible(child: Text(post.userName, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                                if (traveler?.verified ?? false) const Padding(padding: EdgeInsets.only(left: 3), child: Icon(Icons.verified_rounded, size: 13, color: C.primary)),
                              ]),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Flexible(child: Text(groupName ?? (post.edited ? '${post.time} · edited' : post.time), overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                                if (groupName == null) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(audienceIcon(post.audience), size: 11.5, color: Colors.white70)),
                              ]),
                            ]),
                          ),
                          if (!mine && traveler != null && !social.buddies.contains(traveler.id)) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => social.toggleRequest(traveler.id),
                              child: Icon(social.sent.contains(traveler.id) ? Icons.schedule_rounded : Icons.person_add_alt_1_rounded, size: 18, color: C.primary),
                            ),
                          ],
                        ])),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 10,
                    child: Material(
                      color: const Color(0xB3101E1D),
                      shape: const CircleBorder(),
                      child: PopupMenuButton<String>(
                        tooltip: tr('More'),
                        icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                        onSelected: (v) => _menu(context, v),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'save', child: Text(saved ? tr('Remove from saved') : tr('Save post'))),
                          if (mine) ...[
                            PopupMenuItem(value: 'edit', child: Text(tr('Edit post'))),
                            PopupMenuItem(value: 'delete', child: Text(tr('Delete post'))),
                          ] else ...[
                            PopupMenuItem(value: 'report', child: Text(tr('Report post'))),
                            PopupMenuItem(value: 'block', child: Text(tr('Block user'))),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (place == null && post.locationLabel != null)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      right: 12,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: glass(
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.location_on_rounded, size: 16, color: C.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(post.locationLabel!, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ),
                          ]),
                          padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
                        ),
                      ),
                    ),
                  if (place != null)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      right: 12,
                      child: Row(children: [
                        Flexible(
                          child: InkWell(
                            onTap: () => go(context, PlaceDetailScreen(place: place)),
                            child: glass(
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.location_on_rounded, size: 16, color: C.primary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text('${place.name}, ${place.country}',
                                      overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                                ),
                              ]),
                              padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => go(context, PlaceDetailScreen(place: place, initialTab: 1)),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
                            decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(30)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.directions_rounded, size: 16, color: C.on),
                              SizedBox(width: 4),
                              Text(tr('Route'), style: TextStyle(color: C.on, fontWeight: FontWeight.w800, fontSize: 12.5)),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                ]),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
          child: Row(children: [
            stat(
              reaction == null ? const Icon(Icons.favorite_border_rounded, size: 22) : Text(reaction, style: const TextStyle(fontSize: 19)),
              compact(post.likes),
              () => _tapLike(context),
              tip: 'Like (hold to react)',
              onLong: (d) => _pickReaction(context, d.globalPosition),
              onCount: post.likes > 0 ? () => showReactions(context, post) : null,
            ),
            stat(const Icon(Icons.chat_bubble_outline_rounded, size: 21), '${post.commentCount}', () => _comments(context), tip: 'Comments'),
            stat(const Icon(Icons.near_me_outlined, size: 21), post.shareCount > 0 ? '${post.shareCount}' : null, () => _share(context), tip: 'Share'),
            const Spacer(),
            stat(Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 22, color: saved ? C.primary : C.ink), null, () => s.toggleSavePost(post), tip: 'Save'),
          ]),
        ),
        if (post.imageSeed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${post.userName.split(' ').first}  ', style: const TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w800)),
              Expanded(child: RichCaption(post.caption, style: const TextStyle(fontSize: 14, height: 1.45))),
            ]),
          ),
        if (post.commentCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            child: GestureDetector(
              onTap: () => _comments(context),
              child: Text(isBangla ? '${post.commentCount}টি কমেন্ট দেখুন' : 'View ${post.commentCount} comment${post.commentCount == 1 ? '' : 's'}', style: const TextStyle(color: C.muted, fontSize: 13)),
            ),
          ),
      ]),
    );
  }
}

class CreatePostScreen extends StatefulWidget {
  final bool checkIn;
  const CreatePostScreen({super.key, this.checkIn = false});
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _caption = TextEditingController();
  String _audience = 'public';
  final _mentions = <String, String>{}; // @mentions picked while writing
  final _gallery = const ['gallery-1', 'gallery-2', 'gallery-3', 'gallery-4', 'gallery-5', 'gallery-6'];
  late String _picked = _gallery.first;
  bool _video = false;
  late String? _placeId = widget.checkIn ? places.first.id : null;
  static const _otherPlace = '__other__';
  final _otherName = TextEditingController();
  String _otherCountry = '';
  Uint8List? _bytes;
  String _ext = 'jpg';
  String _mime = 'image/jpeg';
  bool _busy = false;
  bool _compressing = false;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final XFile? f =
        _video ? await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 10)) : await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (f == null) return;
    var bytes = await f.readAsBytes();
    var compressed = false;
    if (_video && bytes.length > maxPickVideoBytes) {
      if (mounted) toast(context, tr('Video is too large. Pick one up to 250 MB.'));
      return;
    }
    if (bytes.length > maxUploadBytes) {
      if (!_video || kIsWeb) {
        if (mounted) toast(context, _video ? tr('On the web, videos can be up to 50 MB. Use the app for bigger videos (up to 250 MB).') : tr('Photo is too large (max 50 MB).'));
        return;
      }
      setState(() => _compressing = true);
      final small = await compressVideo(f.path);
      if (mounted) setState(() => _compressing = false);
      if (small == null) {
        if (mounted) toast(context, tr("Couldn't shrink this video under 50 MB. Try a shorter clip."));
        return;
      }
      bytes = small;
      compressed = true;
    }
    final name = f.name.toLowerCase();
    final ext = compressed ? 'mp4' : (name.contains('.') ? name.split('.').last : (_video ? 'mp4' : 'jpg'));
    setState(() {
      _bytes = bytes;
      _ext = ext;
      _mime = _video ? (ext == 'mov' ? 'video/quicktime' : 'video/mp4') : (ext == 'png' ? 'image/png' : 'image/jpeg');
    });
  }

  Future<void> _post() async {
    final s = context.read<AppState>();
    final caption = encodeMentions(_caption.text.trim(), _mentions);
    if (caption.isEmpty) return toast(context, tr('Write a short caption'));
    if (!Backend.on) {
      s.addPost(imageSeed: _picked, caption: caption, placeId: _placeId == _otherPlace ? null : _placeId, isVideo: _video, audience: _audience);
    } else {
      setState(() => _busy = true);
      final other = _placeId == _otherPlace;
      if (other && (_otherName.text.trim().length < 2 || _otherCountry.length < 2)) {
        setState(() => _busy = false);
        return toast(context, tr('Type the place name and country'));
      }
      final ok = await s.publishPost(
          bytes: _bytes,
          ext: _ext,
          mime: _mime,
          caption: caption,
          placeId: other ? null : _placeId,
          isVideo: _video,
          locationName: other ? _otherName.text.trim() : null,
          locationCountry: other ? _otherCountry : null,
          audience: _audience);
      if (!mounted) return;
      setState(() => _busy = false);
      if (!ok) return;
    }
    Navigator.pop(context);
    toast(context, tr('Posted to the community'));
  }

  @override
  Widget build(BuildContext context) => ScreenScaffold(
        title: widget.checkIn ? tr('Check in') : tr('Create post'),
        bottom: PrimaryButton(_busy ? 'Posting...' : 'Post', icon: Icons.send_rounded, onPressed: _busy || _compressing ? null : _post),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Backend.on
                ? GestureDetector(
                    onTap: _compressing ? null : _pick,
                    child: Container(
                      decoration: BoxDecoration(color: C.primary.withOpacity(.08), borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: _compressing
                          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              CircularProgressIndicator(color: C.primary),
                              SizedBox(height: 12),
                              Text(tr('Compressing video...'), style: TextStyle(color: C.primary)),
                            ])
                          : _bytes == null
                              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(_video ? Icons.video_library_outlined : Icons.add_photo_alternate_outlined, size: 42, color: C.primary),
                                  const SizedBox(height: 8),
                                  Text('Tap to add a ${_video ? 'video' : 'photo'} (optional)', style: const TextStyle(color: C.primary)),
                                  if (_video) Padding(padding: EdgeInsets.only(top: 4), child: Text(tr('Up to 250 MB in the app, 50 MB on the web'), style: TextStyle(color: C.muted, fontSize: 12))),
                                ])
                              : (_video ? const Center(child: Icon(Icons.check_circle_rounded, size: 52, color: C.primary)) : Image.memory(_bytes!, fit: BoxFit.cover)),
                    ),
                  )
                : AppImage(_picked),
          ),
          const SizedBox(height: 12),
          if (!Backend.on) ...[
            const Text('Choose media (demo gallery. Add Supabase keys to upload real photos)', style: TextStyle(color: C.muted, fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _gallery.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (c, i) => GestureDetector(
                  onTap: () => setState(() => _picked = _gallery[i]),
                  child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _picked == _gallery[i] ? C.primary : Colors.transparent, width: 3)),
                    child: AppImage(_gallery[i], width: 70, height: 64, radius: 9),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(tr('Photo')), icon: Icon(Icons.image_outlined)),
              ButtonSegment(value: true, label: Text(tr('Video')), icon: Icon(Icons.videocam_outlined)),
            ],
            selected: {_video},
            onSelectionChanged: (v) => setState(() {
              _video = v.first;
              _bytes = null;
            }),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text(tr('Audience'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(width: 10),
            AudienceButton(value: _audience, onChanged: (v) => setState(() => _audience = v)),
          ]),
          const SizedBox(height: 12),
          LabeledField('Caption', 'Tell travelers what to know', controller: _caption, maxLines: 3),
          MentionBar(controller: _caption, picked: _mentions),
          Text(tr('Tag a place'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _placeId,
            isExpanded: true,
            hint: Text(tr('Optional')),
            items: [
              for (final p in places) DropdownMenuItem(value: p.id, child: Text('${p.name}, ${p.country}', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: _otherPlace, child: Text(tr('Another place (type it in)'))),
            ],
            onChanged: (v) => setState(() => _placeId = v),
          ),
          if (_placeId == _otherPlace) ...[
            const SizedBox(height: 10),
            TextField(controller: _otherName, decoration: InputDecoration(labelText: tr('Place name'), hintText: tr('e.g. Bichanakandi, Sylhet'))),
            const SizedBox(height: 10),
            Autocomplete<String>(
              optionsBuilder: (v) => v.text.isEmpty ? const Iterable<String>.empty() : knownCountries.where((c) => c.toLowerCase().startsWith(v.text.toLowerCase())),
              onSelected: (c) => _otherCountry = c,
              fieldViewBuilder: (context, ctl, focus, submit) => TextField(
                controller: ctl,
                focusNode: focus,
                onChanged: (v) => _otherCountry = v.trim(),
                decoration: InputDecoration(labelText: tr('Country'), hintText: tr('Start typing, e.g. Bangladesh')),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(tr('Posts tagged with a place count toward your traveler level.'), style: TextStyle(color: C.muted, fontSize: 12)),
        ]),
      );
}

/// Facebook-style "who reacted" sheet: tabs per reaction, then the people.
Future<void> showReactions(BuildContext context, Post post) async {
  List<(String, String, String, String)> rows; // user id, name, avatar, emoji
  try {
    if (Backend.on) {
      rows = await Backend.postReactions(post.id);
    } else {
      const em = ['❤️', '😍', '🧭', '❤️', '😂', '❤️'];
      rows = [for (var i = 0; i < travelers.length && i < 6; i++) (travelers[i].id, travelers[i].name, travelers[i].seed, em[i])];
    }
  } catch (e) {
    if (context.mounted) toast(context, errText(e));
    return;
  }
  if (!context.mounted) return;
  final counts = <String, int>{};
  for (final r in rows) {
    counts[r.$4] = (counts[r.$4] ?? 0) + 1;
  }
  final tabs = ['All', ...(counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!)))];
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (c) => DefaultTabController(
      length: tabs.length,
      child: SizedBox(
        height: MediaQuery.sizeOf(c).height * .6,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(2))),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in tabs) Tab(text: t == 'All' ? 'All ${rows.length}' : '$t ${counts[t]}')],
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const EmptyState(Icons.favorite_border_rounded, 'No reactions yet', 'Be the first to react.')
                : TabBarView(children: [
                    for (final t in tabs)
                      ListView(children: [
                        for (final r in rows.where((r) => t == 'All' || r.$4 == t))
                          ListTile(
                            leading: Stack(clipBehavior: Clip.none, children: [
                              Avatar(r.$3, name: r.$2, radius: 20),
                              Positioned(right: -4, bottom: -4, child: Text(tr(r.$4), style: const TextStyle(fontSize: 15))),
                            ]),
                            title: Text(r.$1 == Backend.uid ? '${r.$2} (you)' : r.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                            onTap: r.$1 == Backend.uid
                                ? null
                                : () {
                                    final known = travelers.where((x) => x.id == r.$1);
                                    Navigator.pop(c);
                                    if (known.isNotEmpty) {
                                      go(context, TravelerProfileScreen(traveler: known.first));
                                    } else if (Backend.on) {
                                      Backend.fetchTraveler(r.$1).then((tr) {
                                        if (tr != null && context.mounted) go(context, TravelerProfileScreen(traveler: tr));
                                      });
                                    }
                                  },
                          ),
                      ]),
                  ]),
          ),
        ]),
      ),
    ),
  );
}


/// Comments with one level of replies, likes on comments, and delete for your own.
class CommentsSheet extends StatefulWidget {
  final Post post;
  const CommentsSheet(this.post, {super.key});
  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _ctl = TextEditingController();
  final _focus = FocusNode();
  final _picked = <String, String>{};
  Comment? _replyTo;

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _reply(Comment c) {
    setState(() => _replyTo = c);
    if (c.userId != null) _picked[c.user] = c.userId!;
    final tag = c.userId != null ? '@${c.user} ' : '@${c.user.split(' ').first} ';
    if (!_ctl.text.startsWith(tag)) _ctl.text = tag + _ctl.text;
    _ctl.selection = TextSelection.collapsed(offset: _ctl.text.length);
    _focus.requestFocus();
  }

  void _send(AppState s) {
    final t = _ctl.text.trim();
    if (t.isEmpty) return;
    s.addComment(widget.post, encodeMentions(t, _picked), replyTo: _replyTo);
    _ctl.clear();
    _picked.clear();
    setState(() => _replyTo = null);
  }

  bool _mine(AppState s, Comment c) => Backend.on ? (c.userId != null && c.userId == Backend.uid) : c.id?.startsWith('local-') == true && c.user == s.name.split(' ').first;

  Widget _bubble(AppState s, Comment c, {bool reply = false}) {
    final mine = _mine(s, c);
    final small = TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w600);
    return Padding(
      padding: EdgeInsets.fromLTRB(reply ? 58 : 16, 6, 16, 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Avatar(c.avatar ?? c.user.toLowerCase(), name: c.user, radius: reply ? 13 : 16),
        const SizedBox(width: 10),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.user, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  RichCaption(c.text, style: const TextStyle(fontSize: 13.5, height: 1.35)),
                ]),
              ),
              if (c.likes > 0)
                Positioned(
                  right: -6,
                  bottom: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
                    child: Text('❤️ ${c.likes}', style: const TextStyle(fontSize: 11)),
                  ),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 0, 2),
              child: Wrap(spacing: 14, children: [
                if (c.at != null) Text(ago(c.at!), style: small),
                InkWell(
                  onTap: () => s.toggleCommentLike(c),
                  child: Text(tr('Like'), style: small.copyWith(color: c.liked ? C.danger : C.muted, fontWeight: FontWeight.w800)),
                ),
                InkWell(onTap: () => _reply(c), child: Text(tr('Reply'), style: small)),
                if (mine) InkWell(onTap: () => s.deleteComment(widget.post, c), child: Text(tr('Delete'), style: small)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final all = widget.post.comments;
    final ids = {for (final c in all) if (c.id != null) c.id};
    final top = all.where((c) => c.parentId == null || !ids.contains(c.parentId)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(14), child: Text(tr('Comments'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          const Divider(height: 1),
          Expanded(
            child: all.isEmpty
                ? const EmptyState(Icons.chat_bubble_outline_rounded, 'No comments yet', 'Start the conversation.')
                : ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
                    for (final c in top) ...[
                      _bubble(s, c),
                      for (final r in all.where((x) => x.parentId != null && x.parentId == c.id)) _bubble(s, r, reply: true),
                    ],
                  ]),
          ),
          if (_replyTo != null)
            Container(
              color: C.bg,
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
              child: Row(children: [
                Icon(Icons.reply_rounded, size: 16, color: C.muted),
                const SizedBox(width: 6),
                Expanded(child: Text(tr('Replying to {name}').replaceAll('{name}', _replyTo!.user), style: TextStyle(fontSize: 12.5, color: C.muted))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() {
                    _replyTo = null;
                    _ctl.clear();
                  }),
                ),
              ]),
            ),
          MentionBar(controller: _ctl, picked: _picked),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(children: [
                Avatar(s.avatarSeed, name: s.name, radius: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    focusNode: _focus,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(s),
                    decoration: InputDecoration(hintText: tr(_replyTo == null ? 'Write a comment...' : 'Write a reply...'), isDense: true),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send_rounded, color: C.primary), onPressed: () => _send(s)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Opens the profile of whoever wrote a post.
void openPostAuthor(BuildContext context, Post post) {
  final s = context.read<AppState>();
  final mine = Backend.on ? post.userId == Backend.uid : post.userName == s.name;
  final t = mine
      ? me(s)
      : (travelerForPost(post) ??
          Traveler(
              id: post.userId ?? post.userName, name: post.userName, seed: post.userSeed, handle: post.userName.toLowerCase().replaceAll(' ', '.'), home: 'Traveler', bio: '', countries: const []));
  go(context, TravelerProfileScreen(traveler: t));
}
