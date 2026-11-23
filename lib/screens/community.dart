import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../data/social.dart';
import '../state/app_state.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
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
    return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
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
        Text('${_greeting()}, $first', style: const TextStyle(color: C.muted, fontSize: 13.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('Your travel circle', style: TextStyle(fontSize: wide ? 30 : 25, fontWeight: FontWeight.w800, letterSpacing: -.6, height: 1.1)),
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
                child: Text(f, style: TextStyle(color: _filter == f ? C.bg : C.muted, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ),
      ]),
    );

    final empty = Padding(
      padding: const EdgeInsets.all(24),
      child: EmptyState(Icons.dynamic_feed_rounded, _filter == 'For you' ? 'Your feed is quiet' : 'Nothing here yet',
          'Add travel buddies or join groups to see their journeys.'),
    );

    if (!desktop) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Constrained(
            maxWidth: 640,
            child: ListView(padding: const EdgeInsets.only(bottom: 110), children: [
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
            ]),
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
          child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
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
          ]),
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
    final ctl = TextEditingController();
    context.read<AppState>().loadComments(post);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (c) => Consumer<AppState>(
        builder: (c, s, _) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(c).size.height * 0.7,
            child: Column(children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(2))),
              const Padding(padding: EdgeInsets.all(14), child: Text('Comments', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              const Divider(height: 1),
              Expanded(
                child: post.comments.isEmpty
                    ? const EmptyState(Icons.chat_bubble_outline_rounded, 'No comments yet', 'Start the conversation.')
                    : ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
                        for (final cm in post.comments)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Avatar(cm.user.toLowerCase(), name: cm.user, radius: 16),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(16)),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(cm.user, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(cm.text, style: const TextStyle(fontSize: 13.5, height: 1.35)),
                                  ]),
                                ),
                              ),
                            ]),
                          ),
                      ]),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(children: [
                    Avatar(s.avatarSeed, name: s.name, radius: 16),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: ctl, decoration: const InputDecoration(hintText: 'Write a comment...', isDense: true))),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: C.primary),
                      onPressed: () {
                        if (ctl.text.trim().isEmpty) return;
                        s.addComment(post, ctl.text.trim());
                        ctl.clear();
                      },
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context, String v) async {
    final s = context.read<AppState>();
    if (v == 'report') {
      final reason = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(title: const Text('Report this post'), children: [
          for (final r in const ['Spam or scam', 'Nudity or sexual content', 'Hate or harassment', 'Violence', 'False travel information', 'Something else'])
            SimpleDialogOption(onPressed: () => Navigator.pop(c, r), child: Text(r)),
        ]),
      );
      if (reason != null) await s.reportPost(post, reason);
    } else if (v == 'block') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Block ${post.userName}?'),
          content: const Text('You will no longer see their posts.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Block')),
          ],
        ),
      );
      if (ok == true) await s.blockUser(post);
    } else if (v == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete this post?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: C.danger), onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
          ],
        ),
      );
      if (ok == true) await s.deletePost(post);
    } else if (v == 'save') {
      s.toggleSavePost(post);
    }
  }

  void _share(BuildContext context) {
    Clipboard.setData(ClipboardData(text: 'https://explorehub.app/post/${post.id}'));
    toast(context, 'Link copied. Paste it anywhere to share.');
  }

  void _openAuthor(BuildContext context) {
    final s = context.read<AppState>();
    final mine = Backend.on ? post.userId == Backend.uid : post.userName == s.name;
    final t = mine ? me(s) : (travelerForPost(post) ??
        Traveler(id: post.userId ?? post.userName, name: post.userName, seed: post.userSeed, handle: post.userName.toLowerCase().replaceAll(' ', '.'),
            home: 'Traveler', bio: '', countries: const []));
    go(context, TravelerProfileScreen(traveler: t));
  }

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
                      child: Padding(padding: const EdgeInsets.all(6), child: Text(r.$1, style: const TextStyle(fontSize: 28))),
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

    Widget stat(Widget icon, String? count, VoidCallback onTap, {String tip = '', GestureLongPressStartCallback? onLong}) => GestureDetector(
          onLongPressStart: onLong,
          child: Tooltip(
            message: tip,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  icon,
                  if (count != null) ...[const SizedBox(width: 5), Text(count, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))],
                ]),
              ),
            ),
          ),
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
                    Text(groupName ?? post.time, style: const TextStyle(color: C.muted, fontSize: 11.5)),
                  ]),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_horiz_rounded, color: C.muted),
                  onSelected: (v) => _menu(context, v),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'save', child: Text(saved ? 'Remove from saved' : 'Save post')),
                    if (mine) const PopupMenuItem(value: 'delete', child: Text('Delete post')) else const PopupMenuItem(value: 'report', child: Text('Report post')),
                  ],
                ),
              ]),
              const SizedBox(height: 12),
              Text(post.caption, style: const TextStyle(fontSize: 17, height: 1.45, fontWeight: FontWeight.w600)),
            ]),
          )
        else
        GestureDetector(
          onDoubleTap: () {
            if (!liked) s.toggleLike(post);
          },
          child: AspectRatio(
            aspectRatio: post.isVideo ? 4 / 5 : 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(fit: StackFit.expand, children: [
                AppImage(post.imageSeed, radius: 0),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x80000000), Colors.transparent, Colors.transparent, Color(0x99000000)],
                      stops: [0, .25, .65, 1],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                if (post.isVideo) const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64)),
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
                            Text(groupName ?? post.time, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
                      tooltip: 'More',
                      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                      onSelected: (v) => _menu(context, v),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'save', child: Text(saved ? 'Remove from saved' : 'Save post')),
                        if (mine)
                          const PopupMenuItem(value: 'delete', child: Text('Delete post'))
                        else ...const [
                          PopupMenuItem(value: 'report', child: Text('Report post')),
                          PopupMenuItem(value: 'block', child: Text('Block user')),
                        ],
                      ],
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
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.directions_rounded, size: 16, color: C.on),
                            SizedBox(width: 4),
                            Text('Route', style: TextStyle(color: C.on, fontWeight: FontWeight.w800, fontSize: 12.5)),
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
            ),
            stat(const Icon(Icons.chat_bubble_outline_rounded, size: 21), '${post.commentCount}', () => _comments(context), tip: 'Comments'),
            stat(const Icon(Icons.near_me_outlined, size: 21), null, () => _share(context), tip: 'Share'),
            const Spacer(),
            stat(Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 22, color: saved ? C.primary : C.ink), null,
                () => s.toggleSavePost(post), tip: 'Save'),
          ]),
        ),
        if (post.imageSeed.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '${post.userName.split(' ').first}  ', style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: post.caption),
            ]),
            style: const TextStyle(fontSize: 14, height: 1.45),
          ),
        ),
        if (post.commentCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            child: GestureDetector(
              onTap: () => _comments(context),
              child: Text('View ${post.commentCount} comment${post.commentCount == 1 ? '' : 's'}', style: const TextStyle(color: C.muted, fontSize: 13)),
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
  final _gallery = const ['gallery-1', 'gallery-2', 'gallery-3', 'gallery-4', 'gallery-5', 'gallery-6'];
  late String _picked = _gallery.first;
  bool _video = false;
  late String? _placeId = widget.checkIn ? places.first.id : null;
  Uint8List? _bytes;
  String _ext = 'jpg';
  String _mime = 'image/jpeg';
  bool _busy = false;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final XFile? f = _video
        ? await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2))
        : await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (bytes.length > 45 * 1024 * 1024) {
      if (mounted) toast(context, 'File is too large (max 45 MB)');
      return;
    }
    final name = f.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : (_video ? 'mp4' : 'jpg');
    setState(() {
      _bytes = bytes;
      _ext = ext;
      _mime = _video ? (ext == 'mov' ? 'video/quicktime' : 'video/mp4') : (ext == 'png' ? 'image/png' : 'image/jpeg');
    });
  }

  Future<void> _post() async {
    final s = context.read<AppState>();
    final caption = _caption.text.trim();
    if (caption.isEmpty) return toast(context, 'Write a short caption');
    if (!Backend.on) {
      s.addPost(imageSeed: _picked, caption: caption, placeId: _placeId, isVideo: _video);
    } else {
      if (_bytes == null) return toast(context, 'Choose a ${_video ? 'video' : 'photo'} first');
      setState(() => _busy = true);
      final ok = await s.publishPost(bytes: _bytes!, ext: _ext, mime: _mime, caption: caption, placeId: _placeId, isVideo: _video);
      if (!mounted) return;
      setState(() => _busy = false);
      if (!ok) return;
    }
    Navigator.pop(context);
    toast(context, 'Posted to the community');
  }

  @override
  Widget build(BuildContext context) => ScreenScaffold(
        title: widget.checkIn ? 'Check in' : 'Create post',
        bottom: PrimaryButton(_busy ? 'Posting...' : 'Post', icon: Icons.send_rounded, onPressed: _busy ? null : _post),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Backend.on
                ? GestureDetector(
                    onTap: _pick,
                    child: Container(
                      decoration: BoxDecoration(color: C.primary.withOpacity(.08), borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: _bytes == null
                          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(_video ? Icons.video_library_outlined : Icons.add_photo_alternate_outlined, size: 42, color: C.primary),
                              const SizedBox(height: 8),
                              Text('Tap to choose a ${_video ? 'video' : 'photo'}', style: const TextStyle(color: C.primary)),
                            ])
                          : (_video
                              ? const Center(child: Icon(Icons.check_circle_rounded, size: 52, color: C.primary))
                              : Image.memory(_bytes!, fit: BoxFit.cover)),
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
            segments: const [
              ButtonSegment(value: false, label: Text('Photo'), icon: Icon(Icons.image_outlined)),
              ButtonSegment(value: true, label: Text('Video'), icon: Icon(Icons.videocam_outlined)),
            ],
            selected: {_video},
            onSelectionChanged: (v) => setState(() {
              _video = v.first;
              _bytes = null;
            }),
          ),
          const SizedBox(height: 16),
          LabeledField('Caption', 'Tell travelers what to know', controller: _caption, maxLines: 3),
          const Text('Tag a place', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _placeId,
            hint: const Text('Optional'),
            items: [for (final p in places) DropdownMenuItem(value: p.id, child: Text('${p.name}, ${p.country}'))],
            onChanged: (v) => setState(() => _placeId = v),
          ),
        ]),
      );
}
