import 'package:flutter/material.dart';
import '../core/i18n.dart';
import 'passport.dart';
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
import 'guides.dart';
import '../widgets/pull_refresh.dart';
import '../widgets/social_widgets.dart';
import 'community.dart';
import 'edit_profile.dart';
import 'messages.dart';
import 'trips.dart';

const _flags = {
  'Bangladesh': '🇧🇩',
  'Nepal': '🇳🇵',
  'India': '🇮🇳',
  'Bhutan': '🇧🇹',
  'Thailand': '🇹🇭',
  'Japan': '🇯🇵',
  'Korea': '🇰🇷',
  'Vietnam': '🇻🇳',
  'Peru': '🇵🇪',
  'Greece': '🇬🇷',
  'Morocco': '🇲🇦',
  'Chile': '🇨🇱',
  'Bolivia': '🇧🇴',
  'Malaysia': '🇲🇾',
  'Jordan': '🇯🇴',
  'Egypt': '🇪🇬',
  'Turkey': '🇹🇷',
  'Indonesia': '🇮🇩',
  'Philippines': '🇵🇭',
  'Maldives': '🇲🇻',
  'Italy': '🇮🇹',
  'Cyprus': '🇨🇾',
  'Germany': '🇩🇪',
  'Taiwan': '🇹🇼',
};

/// Public traveler profile (also used for "me").
class TravelerProfileScreen extends StatefulWidget {
  final Traveler traveler;
  const TravelerProfileScreen({super.key, required this.traveler});
  @override
  State<TravelerProfileScreen> createState() => _TravelerProfileScreenState();
}

class _TravelerProfileScreenState extends State<TravelerProfileScreen> {
  int _tab = 0;

  /// Live mode: this traveler's own posts, fetched from the database.
  List<Post>? _theirPosts;

  @override
  void initState() {
    super.initState();
    final t = widget.traveler;
    if (Backend.on && t.id != meId) {
      Backend.postsBy(t.id).then((p) {
        if (mounted) setState(() => _theirPosts = p);
      }).catchError((_) {
        if (mounted) setState(() => _theirPosts = []);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final social = context.watch<SocialState>();
    final t = widget.traveler;
    final isMe = t.id == meId;
    final posts = Backend.on ? (isMe ? s.myPosts : (_theirPosts ?? const <Post>[])) : s.posts.where((p) => isMe ? p.userName == s.name : p.userName == t.name).toList();
    final trips = isMe ? social.trips : social.trips.where((x) => x.buddies.contains(t.id)).toList();
    final wide = Bp.isWide(context);
    final w = MediaQuery.sizeOf(context).width;

    final outline = OutlinedButton.styleFrom(foregroundColor: C.ink, side: const BorderSide(color: C.line), shape: const StadiumBorder());
    // "Travel passport" header: rounded cover card, centred identity, stamp-style countries.
    final header = Padding(
      padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 0, wide ? 24 : 12, 0),
      child: Column(children: [
        SafeArea(
          bottom: false,
          child: SizedBox(
            width: double.infinity,
            height: wide ? 300 : 250,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
              Positioned.fill(bottom: 54, top: 8, child: AppImage(t.cover ?? 'cover-${t.seed.isEmpty ? 'me' : t.seed}', radius: 30)),
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [C.primary, Color(0xFFE5806F)]),
                    boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 18)],
                  ),
                  child: CircleAvatar(radius: wide ? 58 : 50, backgroundColor: C.bg, child: Avatar(t.seed, name: t.name, radius: wide ? 54 : 46)),
                ),
              ),
              const Positioned(left: 4, top: 12, child: BackCircle()),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        VerifiedName(t, size: 23),
        const SizedBox(height: 6),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
          LevelBadge(t),
          if (guideFor(t.id) != null) GuideBadge(guideFor(t.id)!),
        ]),
        if (isMe && guideFor(t.id) == null && Backend.on)
          TextButton.icon(
            onPressed: () => go(context, const GuideSignupScreen()),
            icon: const Icon(Icons.hiking_rounded, size: 18),
            label: Text(tr('Become a guide')),
          )
        else if (isMe && guideFor(t.id) != null && !guideFor(t.id)!.verified)
          TextButton.icon(
            onPressed: () => go(context, const GuideVerifyScreen()),
            icon: const Icon(Icons.verified_rounded, size: 18),
            label: Text(tr('Get the Verified guide badge')),
          ),
        const SizedBox(height: 6),
        Text('@${t.handle}  ·  ${t.home}', textAlign: TextAlign.center, style: const TextStyle(color: C.muted, fontSize: 13)),
        if (t.bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(t.bio, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, height: 1.45)),
            ),
          ),
        if (t.nextTrip != null) ...[
          const SizedBox(height: 10),
          Pill('Next stop: ${placeById(t.nextTrip!).name}', icon: Icons.flight_takeoff_rounded),
        ],
        const SizedBox(height: 16),
        Row(children: [
          _stat(compact(t.followers), 'Followers'),
          _stat(compact(t.following), 'Following'),
          _stat('${t.placesVisited}', 'Places'),
          _stat('${t.trips}', 'Trips'),
        ]),
        const SizedBox(height: 12),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: LevelCard(t, isMe: isMe)),
        const SizedBox(height: 14),
        if (isMe)
          Row(children: [
            Expanded(
                child: FilledButton.icon(
                    style: FilledButton.styleFrom(shape: const StadiumBorder()),
                    onPressed: () => go(context, const CreatePostScreen()),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(tr('Share a moment')))),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: outline,
                onPressed: () => go(context, const EditProfileScreen()),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: Text(tr('Edit profile')),
              ),
            ),
          ])
        else
          Row(children: [
            Expanded(child: BuddyButton(t)),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: outline,
                onPressed: () => go(context, ChatScreen(conversation: social.chatWith(t))),
                icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                label: Text(tr('Message')),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: outline,
              onPressed: () => s.toggleFollow(t.id),
              child: Text(s.following.contains(t.id) ? tr('Following') : tr('Follow')),
            ),
          ]),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.menu_book_rounded, size: 18, color: C.primary),
              SizedBox(width: 6),
              Expanded(child: Text(tr('Passport stamps'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              TextButton.icon(
                onPressed: () => go(context, PassportScreen(userId: isMe ? null : t.id, name: t.name, saidCountries: t.countries)),
                icon: const Icon(Icons.public_rounded, size: 17),
                label: Text(tr('Open passport')),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (var i = 0; i < t.countries.length; i++)
                Transform.rotate(
                  angle: (i % 3 - 1) * 0.06,
                  child: Container(
                    width: 74,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: [C.primary, const Color(0xFF8FB3AC), const Color(0xFFE5806F)][i % 3], width: 1.5),
                    ),
                    child: Column(children: [
                      Text(_flags[t.countries[i]] ?? '🏳️', style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 2),
                      Text(t.countries[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 0, label: Text(tr('Journeys')), icon: Icon(Icons.dynamic_feed_rounded, size: 17)),
              ButtonSegment(value: 1, label: Text(tr('Photos')), icon: Icon(Icons.grid_on_rounded, size: 17)),
              ButtonSegment(value: 2, label: Text(tr('Trips')), icon: Icon(Icons.map_rounded, size: 17)),
            ],
            selected: {_tab},
            onSelectionChanged: (v) => setState(() => _tab = v.first),
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );

    // Photo grid: media from this traveler's posts (demo mode adds a few sample shots).
    final photos = <String>[
      ...posts.where((p) => p.imageSeed.isNotEmpty && !p.isVideo).map((p) => p.imageSeed),
      if (!Backend.on)
        for (var i = 1; i <= 9; i++) '${t.seed}-trip-$i',
    ];
    final cols = w >= 900 ? 4 : 3;

    Widget content;
    if (_tab == 0) {
      content = posts.isEmpty ? const EmptyState(Icons.photo_camera_outlined, 'No posts yet', 'Trips shared will show up here.') : Column(children: [for (final p in posts) PostCard(p)]);
    } else if (_tab == 1) {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (final p in photos) AppImage(p, radius: 8)],
        ),
      );
      if (photos.isEmpty) content = const EmptyState(Icons.photo_library_outlined, 'No photos yet', 'Photos from shared journeys show up here.');
    } else {
      content = trips.isEmpty
          ? const EmptyState(Icons.map_outlined, 'No shared trips', 'Trips planned together show up here.')
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(children: [
                for (final tr in trips) Padding(padding: const EdgeInsets.only(bottom: 12), child: TripCard(tr)),
              ]),
            );
    }

    return Scaffold(
      body: Constrained(
        maxWidth: 940,
        child: PullRefresh(child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: EdgeInsets.zero, children: [header, content, const SizedBox(height: 40)])),
      ),
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
          child: Column(children: [
            Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            Text(tr(l), style: const TextStyle(color: C.muted, fontSize: 11.5)),
          ]),
        ),
      );
}
