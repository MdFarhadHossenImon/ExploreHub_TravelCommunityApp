import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/feed_video.dart';
import 'community.dart';
import 'place_detail.dart';

/// Vertical short-video discovery. Real uploads play inline (muted until you tap the speaker).
class WatchScreen extends StatelessWidget {
  const WatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reels = context.watch<AppState>().posts.where((p) => p.isVideo).toList();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: reels.isEmpty
              ? const EmptyState(Icons.videocam_outlined, 'No videos yet', 'Share a trip video from Community.')
              : PageView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: reels.length,
                  itemBuilder: (c, i) => _Reel(reels[i]),
                ),
        ),
      ),
    );
  }
}

class _Reel extends StatefulWidget {
  final Post post;
  const _Reel(this.post);
  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel> {
  bool _playing = true;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = widget.post;
    final liked = s.likedPosts.contains(p.id);
    final place = p.placeId == null ? null : placeById(p.placeId as String);
    Widget action(IconData icon, String label, VoidCallback on, {Color color = Colors.white}) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(children: [
            IconButton(onPressed: on, icon: Icon(icon, color: color, size: 30)),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ]),
        );
    final real = p.imageSeed.startsWith('http');
    return GestureDetector(
      onTap: real ? null : () => setState(() => _playing = !_playing),
      child: Stack(fit: StackFit.expand, children: [
        real ? FeedVideo(p.imageSeed) : AppImage(p.imageSeed, radius: 0),
        const IgnorePointer(child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0x80102826), Colors.transparent, Color(0xCC0A1A19)], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, 0.5, 1]),
          ),
        )),
        const Positioned(
          top: 0,
          left: 16,
          child: SafeArea(child: Padding(padding: EdgeInsets.only(top: 12), child: Text('Watch & explore', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)))),
        ),
        if (p.isVideo && !real)
          Positioned(
            left: 18,
            right: 18,
            bottom: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: _playing
                  ? TweenAnimationBuilder<double>(
                      key: ValueKey(p.id),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(seconds: 8),
                      onEnd: () {},
                      builder: (c, v, _) => LinearProgressIndicator(value: v, minHeight: 3, color: C.primary, backgroundColor: Colors.white30),
                    )
                  : const LinearProgressIndicator(value: 0.4, minHeight: 3, color: C.primary, backgroundColor: Colors.white30),
            ),
          ),
        if (!_playing && !real) const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 84)),
        Positioned(
          right: 4,
          bottom: 30,
          child: Column(children: [
            action(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, '${p.likes}', () => s.toggleLike(p), color: liked ? C.danger : Colors.white),
            action(Icons.mode_comment_outlined, '${p.commentCount}', () => go(context, Scaffold(appBar: AppBar(title: const Text('Post')), body: SingleChildScrollView(child: PostCard(p))))),
            action(s.savedPosts.contains(p.id) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, 'Save', () => s.toggleSavePost(p)),
          ]),
        ),
        Positioned(
          left: 16,
          right: 76,
          bottom: 28,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Avatar(p.userSeed as String, name: p.userName as String, radius: 16),
              const SizedBox(width: 8),
              Flexible(child: Text(p.userName as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 10),
            Text((p.videoTitle ?? '') as String, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(p.caption as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            if (place != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: C.primary, foregroundColor: C.on, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () => go(context, PlaceDetailScreen(place: place, initialTab: 1)),
                icon: const Icon(Icons.alt_route_rounded, size: 18),
                label: Text('How to go to ${place.name}', overflow: TextOverflow.ellipsis),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
