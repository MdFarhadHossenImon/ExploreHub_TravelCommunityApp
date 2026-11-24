import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/i18n.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../core/theme.dart';
import 'common.dart';

/// Inline video for feeds: starts muted when most of it is on screen and pauses when it scrolls away.
/// Tap to pause or play; the speaker button turns sound on.
/// Width / height of each video once it has loaded, so feeds can size posts like the real video (16:9, 9:16, ...).
final videoAspects = ValueNotifier<Map<String, double>>({});

/// Sound for every video, like Facebook: on by default; once you mute, videos stay muted until you turn it back on.
final videoSound = ValueNotifier<bool>(true);

/// Watch: jump to the next video when one ends.
final watchAutoScroll = ValueNotifier<bool>(false);

/// Browsers only allow sound after the person has tapped the page once.
bool _gestured = !kIsWeb;
void markUserGesture() => _gestured = true;

Future<void> loadVideoPrefs() async {
  try {
    final p = await SharedPreferences.getInstance();
    videoSound.value = p.getBool('video_sound') ?? true;
    watchAutoScroll.value = p.getBool('watch_autoscroll') ?? false;
  } catch (_) {}
}

Future<void> setVideoSound(bool on) async {
  videoSound.value = on;
  try { await (await SharedPreferences.getInstance()).setBool('video_sound', on); } catch (_) {}
}

Future<void> setWatchAutoScroll(bool on) async {
  watchAutoScroll.value = on;
  try { await (await SharedPreferences.getInstance()).setBool('watch_autoscroll', on); } catch (_) {}
}

class FeedVideo extends StatefulWidget {
  final String url;
  final BoxFit fit;

  /// Start playing as soon as it is visible (feed, Watch). Off: wait for a tap.
  final bool autoplay;

  /// Put the sound button in the top-right corner (Watch, where the right edge holds like / comment / save).
  final bool muteTop;

  /// Fill the frame with tall videos, letterbox wide ones (reels).
  final bool smartFit;

  /// Called once when the video reaches its end; the video then stops looping (Watch auto scroll).
  final VoidCallback? onEnded;
  const FeedVideo(this.url, {super.key, this.fit = BoxFit.cover, this.autoplay = true, this.muteTop = false, this.smartFit = false, this.onEnded});

  @override
  State<FeedVideo> createState() => _FeedVideoState();
}

class _FeedVideoState extends State<FeedVideo> {
  VideoPlayerController? _c;
  bool _failed = false;
  bool _visible = false;
  bool _userPaused = false;
  bool _ended = false;
  bool _retried = false;
  int _seekFlash = 0; // -1 back, 1 forward
  Timer? _flashTimer;

  /// Muted when the person muted, or (on the web) before their first tap, when browsers block sound.
  bool get _muted => !videoSound.value || !_gestured;

  @override
  void initState() {
    super.initState();
    videoSound.addListener(_applySound);
  }

  @override
  void didUpdateWidget(FeedVideo old) {
    super.didUpdateWidget(old);
    if ((old.onEnded == null) != (widget.onEnded == null)) _c?.setLooping(widget.onEnded == null);
  }

  void _applySound() {
    final c = _c;
    if (c != null && c.value.isInitialized) c.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  Future<void> _ensure() async {
    if (_c != null || _failed) return;
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _c = c;
    try {
      await c.initialize();
      final sz = c.value.size;
      if (sz.width > 0 && sz.height > 0 && videoAspects.value[widget.url] == null) {
        videoAspects.value = {...videoAspects.value, widget.url: sz.width / sz.height};
      }
      await c.setLooping(widget.onEnded == null);
      await c.setVolume(_muted ? 0 : 1);
      c.addListener(_tick);
      if (!mounted) return;
      setState(() {});
      if (_visible && widget.autoplay && !_userPaused) await c.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _tick() {
    final c = _c;
    if (c == null) return;
    // The browser refused to start with sound: start again muted.
    if (c.value.hasError && !_retried) {
      _retried = true;
      _gestured = false;
      c.removeListener(_tick);
      _c = null;
      c.dispose();
      _ensure();
      return;
    }
    final v = c.value;
    if (widget.onEnded != null && v.isInitialized && v.duration > Duration.zero && !v.isPlaying && v.position >= v.duration - const Duration(milliseconds: 300)) {
      if (!_ended) {
        _ended = true;
        widget.onEnded!();
      }
    } else if (v.isPlaying) {
      _ended = false;
    }
    if (mounted) setState(() {});
  }

  void _onVisibility(VisibilityInfo info) {
    if (!mounted) return;
    if (info.visibleFraction > 0 && widget.autoplay) _ensure(); // load early so the post gets its real shape
    final now = info.visibleFraction > 0.6;
    if (now == _visible) return;
    _visible = now;
    if (now) {
      if (widget.autoplay) _ensure();
      if (_c?.value.isInitialized == true && widget.autoplay && !_userPaused) {
        _c!.setVolume(_muted ? 0 : 1);
        _c!.play();
      }
    } else {
      _c?.pause();
    }
  }

  Future<void> _togglePlay() async {
    markUserGesture();
    await _ensure();
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      _userPaused = true;
      await c.pause();
    } else {
      _userPaused = false;
      await c.setVolume(_muted ? 0 : 1);
      await c.play();
    }
  }

  /// Jump [seconds] forward (or back when negative).
  Future<void> _seek(int seconds) async {
    markUserGesture();
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    var to = c.value.position + Duration(seconds: seconds);
    if (to < Duration.zero) to = Duration.zero;
    if (to > c.value.duration) to = c.value.duration;
    await c.seekTo(to);
    _flashTimer?.cancel();
    setState(() => _seekFlash = seconds < 0 ? -1 : 1);
    _flashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _seekFlash = 0);
    });
  }

  Future<void> _toggleSound() async {
    final wasMuted = _muted;
    markUserGesture();
    await setVideoSound(wasMuted); // muted -> sound on, and the other way round
    _applySound();
    final c = _c;
    if (c != null && c.value.isInitialized && !c.value.isPlaying && !_userPaused) await c.play();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    videoSound.removeListener(_applySound);
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    Widget seekButton(IconData icon, int secs) => Material(
          color: const Color(0x66000000),
          shape: const CircleBorder(),
          child: IconButton(iconSize: 30, onPressed: () => _seek(secs), icon: Icon(icon, color: Colors.white), tooltip: secs < 0 ? tr('Back 10 seconds') : tr('Forward 10 seconds')),
        );
    return VisibilityDetector(
      key: ValueKey('vid-${widget.url}'),
      onVisibilityChanged: _onVisibility,
      child: LayoutBuilder(builder: (context, box) {
        return Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: Colors.black),
          if (ready)
            FittedBox(
              fit: widget.smartFit ? (c.value.aspectRatio > 1 ? BoxFit.contain : BoxFit.cover) : widget.fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
            ),
          // Tap layer on top of the video: tap = pause / play, double tap left / right = back / forward 10 s.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
              onDoubleTapDown: ready ? (d) => _seek(d.localPosition.dx < box.maxWidth / 2 ? -10 : 10) : null,
              onDoubleTap: ready ? () {} : null,
              child: const SizedBox.expand(),
            ),
          ),
          if (_failed)
            Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(tr('This video format can\'t play here. MP4 videos work everywhere.'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            )
          else if (!ready)
            IgnorePointer(
              child: Center(
                child: _visible || !widget.autoplay
                    ? (c == null
                        ? const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64)
                        : const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)))
                    : const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64),
              ),
            )
          else if (!c.value.isPlaying)
            Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                seekButton(Icons.replay_10_rounded, -10),
                const SizedBox(width: 18),
                GestureDetector(onTap: _togglePlay, child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64)),
                const SizedBox(width: 18),
                seekButton(Icons.forward_10_rounded, 10),
              ]),
            ),
          if (_seekFlash != 0)
            IgnorePointer(
              child: Align(
                alignment: _seekFlash < 0 ? const Alignment(-0.6, 0) : const Alignment(0.6, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0x88000000), borderRadius: BorderRadius.circular(30)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_seekFlash < 0 ? Icons.fast_rewind_rounded : Icons.fast_forward_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 6),
                    Text(tr('10 sec'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          if (ready) ...[
            Positioned(
              right: 10,
              top: widget.muteTop ? 52 : null,
              bottom: widget.muteTop ? null : 56,
              child: Material(
                color: const Color(0x99000000),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: _muted ? tr('Sound on') : tr('Mute'),
                  onPressed: _toggleSound,
                  icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 14,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: VideoProgressIndicator(c,
                      allowScrubbing: true, padding: const EdgeInsets.only(top: 10), colors: const VideoProgressColors(playedColor: C.primary, bufferedColor: Colors.white24, backgroundColor: Colors.white10)),
                ),
              ),
            ),
          ],
        ]);
      }),
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
