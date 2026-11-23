import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../core/theme.dart';
import 'common.dart';

/// Inline video for feeds: starts muted when most of it is on screen and pauses when it scrolls away.
/// Tap to pause or play; the speaker button turns sound on.
class FeedVideo extends StatefulWidget {
  final String url;
  final BoxFit fit;
  /// Start playing as soon as it is visible (feed, Watch). Off: wait for a tap.
  final bool autoplay;
  const FeedVideo(this.url, {super.key, this.fit = BoxFit.cover, this.autoplay = true});

  @override
  State<FeedVideo> createState() => _FeedVideoState();
}

class _FeedVideoState extends State<FeedVideo> {
  VideoPlayerController? _c;
  bool _failed = false;
  bool _visible = false;
  bool _muted = true;
  bool _userPaused = false;

  Future<void> _ensure() async {
    if (_c != null || _failed) return;
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _c = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      c.addListener(_tick);
      if (!mounted) return;
      setState(() {});
      if (_visible && widget.autoplay && !_userPaused) await c.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  void _onVisibility(VisibilityInfo info) {
    if (!mounted) return;
    final now = info.visibleFraction > 0.6;
    if (now == _visible) return;
    _visible = now;
    if (now) {
      if (widget.autoplay) _ensure();
      if (_c?.value.isInitialized == true && widget.autoplay && !_userPaused) _c!.play();
    } else {
      _c?.pause();
    }
  }

  Future<void> _togglePlay() async {
    await _ensure();
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      _userPaused = true;
      await c.pause();
    } else {
      _userPaused = false;
      await c.play();
    }
  }

  Future<void> _toggleSound() async {
    final c = _c;
    if (c == null) return;
    _muted = !_muted;
    await c.setVolume(_muted ? 0 : 1);
    if (!c.value.isPlaying) await c.play();
    setState(() {});
  }

  @override
  void dispose() {
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    return VisibilityDetector(
      key: ValueKey('vid-${widget.url}'),
      onVisibilityChanged: _onVisibility,
      child: GestureDetector(
        onTap: _togglePlay,
        child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: Colors.black),
          if (ready)
            FittedBox(
              fit: widget.fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
            ),
          if (_failed)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('This video format can\'t play here. MP4 videos work everywhere.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            )
          else if (!ready)
            Center(
              child: _visible || !widget.autoplay
                  ? (c == null
                      ? const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64)
                      : const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)))
                  : const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64),
            )
          else if (!c.value.isPlaying)
            const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64)),
          if (ready) ...[
            Positioned(
              right: 10,
              bottom: 56,
              child: Material(
                color: const Color(0x99000000),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: _muted ? 'Sound on' : 'Mute',
                  onPressed: _toggleSound,
                  icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(c, allowScrubbing: true, padding: EdgeInsets.zero,
                  colors: const VideoProgressColors(playedColor: C.primary, bufferedColor: Colors.white24, backgroundColor: Colors.white10)),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Picks a video player for http video links, or a photo otherwise.
Widget mediaView(String seed, {required bool isVideo, double radius = 0, bool autoplay = true}) {
  if (isVideo && seed.startsWith('http')) {
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: FeedVideo(seed, autoplay: autoplay));
  }
  return AppImage(seed, radius: radius);
}
