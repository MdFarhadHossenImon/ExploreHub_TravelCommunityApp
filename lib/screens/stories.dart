import 'dart:async';

import 'package:flutter/material.dart';
import '../core/i18n.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/backend.dart';
import '../data/mock_data.dart';
import '../data/social.dart';
import '../state/app_state.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
import 'place_detail.dart';

/// Horizontal row of tall story cards (first card creates a story).
class StoryRow extends StatelessWidget {
  final double padding;
  const StoryRow({super.key, this.padding = 16});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final social = context.watch<SocialState>();
    final list = social.storyQueue;
    Widget tile({required Widget image, required Widget avatar, required String label, required bool ring, VoidCallback? onTap}) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: SizedBox(
              width: 76,
              child: Column(children: [
                Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
                  Container(
                    width: 76,
                    height: 96,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: ring ? const LinearGradient(colors: [C.primary, Color(0xFFE5806F)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                      color: ring ? null : C.line,
                    ),
                    child: ClipRRect(borderRadius: BorderRadius.circular(21.5), child: image),
                  ),
                  Positioned(bottom: -12, child: CircleAvatar(radius: 15, backgroundColor: C.bg, child: avatar)),
                ]),
                const SizedBox(height: 16),
                Text(tr(label), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );
    return SizedBox(
      height: 132,
      child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: padding), children: [
        tile(
          onTap: () => _createStory(context),
          ring: false,
          image: Container(color: C.card, child: const Icon(Icons.add_a_photo_rounded, color: C.primary, size: 26)),
          avatar: Avatar(s.avatarSeed, name: s.name, radius: 13),
          label: tr('Add moment'),
        ),
        for (var i = 0; i < list.length; i++)
          if (i == 0 || list[i - 1].travelerId != list[i].travelerId)
            Builder(builder: (context) {
              final who = list[i].travelerId;
              final group = [for (var k = i; k < list.length && list[k].travelerId == who; k++) k];
              final firstUnseen = group.firstWhere((k) => !social.seenStories.contains(list[k].id), orElse: () => group.first);
              final latest = list[group.last];
              return tile(
                onTap: () => Navigator.of(context).push(PageRouteBuilder(
                  opaque: true,
                  pageBuilder: (_, __, ___) => StoryViewer(start: firstUnseen),
                  transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
                )),
                ring: group.any((k) => !social.seenStories.contains(list[k].id)),
                image: AppImage(latest.imageSeed, radius: 0),
                avatar: _storyAvatar(latest, s, 13),
                label: group.length > 1 ? '${_storyName(latest, s).split(' ').first} · ${group.length}' : _storyName(latest, s).split(' ').first,
              );
            }),
      ]),
    );
  }

  static String _storyName(Story st, AppState s) => st.travelerId == meId ? 'You' : travelerById(st.travelerId).name;

  static Widget _storyAvatar(Story st, AppState s, [double r = 15]) =>
      st.travelerId == meId ? Avatar(s.avatarSeed, name: s.name, radius: r) : Avatar(travelerById(st.travelerId).seed, name: travelerById(st.travelerId).name, radius: r);

  void _createStory(BuildContext context) {
    if (Backend.on) {
      _createLiveStory(context);
      return;
    }
    final ctl = TextEditingController();
    var picked = 'story-new-1';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Create a story'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 4),
            Text(tr('Stories disappear after 24 hours.'), style: TextStyle(color: C.muted, fontSize: 12.5)),
            const SizedBox(height: 14),
            SizedBox(
              height: 120,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final g in const ['story-new-1', 'story-new-2', 'story-new-3', 'story-new-4', 'story-new-5'])
                  GestureDetector(
                    onTap: () => set(() => picked = g),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: picked == g ? C.primary : Colors.transparent, width: 3)),
                      child: AppImage(g, width: 76, height: 114, radius: 11),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(controller: ctl, decoration: InputDecoration(hintText: tr('Add a caption'))),
            const SizedBox(height: 14),
            PrimaryButton('Share to story', icon: Icons.auto_awesome_rounded, onPressed: () {
              c.read<SocialState>().addStory(picked, ctl.text.trim().isEmpty ? 'New story' : ctl.text.trim());
              Navigator.pop(c);
              toast(context, tr('Your story is live'));
            }),
          ]),
        ),
      ),
    );
  }

  /// Live mode: pick a real photo from the gallery/camera and upload it.
  Future<void> _createLiveStory(BuildContext context) async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1440, imageQuality: 85);
    if (f == null || !context.mounted) return;
    final bytes = await f.readAsBytes();
    final name = f.name.toLowerCase();
    final ext = name.endsWith('.png') ? 'png' : 'jpg';
    if (!context.mounted) return;
    final ctl = TextEditingController();
    var busy = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Share a moment'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 4),
            Text(tr('Moments disappear after 24 hours.'), style: TextStyle(color: C.muted, fontSize: 12.5)),
            const SizedBox(height: 14),
            Center(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(bytes, height: 260, fit: BoxFit.cover))),
            const SizedBox(height: 12),
            TextField(controller: ctl, decoration: InputDecoration(hintText: tr('Add a caption'))),
            const SizedBox(height: 14),
            PrimaryButton(busy ? 'Uploading...' : 'Share moment', icon: Icons.auto_awesome_rounded, onPressed: busy
                ? null
                : () async {
                    set(() => busy = true);
                    final ok = await c.read<SocialState>().publishStory(bytes, ext, ext == 'png' ? 'image/png' : 'image/jpeg', ctl.text.trim());
                    if (c.mounted) Navigator.pop(c);
                    if (context.mounted) toast(context, ok ? tr('Your moment is live') : tr('Upload failed, please try again'));
                  }),
          ]),
        ),
      ),
    );
  }
}

/// Full-screen story player with progress bars, tap left/right, auto-advance.
class StoryViewer extends StatefulWidget {
  final int start;
  const StoryViewer({super.key, required this.start});
  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late int _i = widget.start;
  late final AnimationController _ac = AnimationController(vsync: this, duration: const Duration(seconds: 5))
    ..addStatusListener((st) {
      if (st == AnimationStatus.completed) _next();
    });
  final _reply = TextEditingController();

  @override
  void initState() {
    super.initState();
    _show();
  }

  void _show() {
    final list = context.read<SocialState>().storyQueue;
    if (_i >= list.length) return;
    scheduleMicrotask(() => context.read<SocialState>().markSeen(list[_i].id));
    _ac.forward(from: 0);
  }

  void _next() {
    final n = context.read<SocialState>().storyQueue.length;
    if (_i + 1 >= n) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _i++);
    _show();
  }

  void _prev() {
    if (_i == 0) {
      _ac.forward(from: 0);
      return;
    }
    setState(() => _i--);
    _show();
  }

  @override
  void dispose() {
    _ac.dispose();
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final list = context.watch<SocialState>().storyQueue;
    if (list.isEmpty) return const Scaffold(backgroundColor: Colors.black);
    if (_i >= list.length) _i = list.length - 1;
    final st = list[_i];
    // Progress bars cover only this traveler's stories.
    var gStart = _i, gEnd = _i;
    while (gStart > 0 && list[gStart - 1].travelerId == st.travelerId) {
      gStart--;
    }
    while (gEnd < list.length - 1 && list[gEnd + 1].travelerId == st.travelerId) {
      gEnd++;
    }
    final mine = st.travelerId == meId;
    final t = mine ? null : travelerById(st.travelerId);
    final place = st.placeId == null ? null : placeById(st.placeId!);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: MediaQuery.sizeOf(context).width < 600 ? MediaQuery.sizeOf(context).aspectRatio : 9 / 16,
          child: GestureDetector(
            onTapUp: (d) {
              final w = context.size?.width ?? 400;
              d.globalPosition.dx < w / 3 ? _prev() : _next();
            },
            onLongPressStart: (_) => _ac.stop(),
            onLongPressEnd: (_) => _ac.forward(),
            child: Stack(fit: StackFit.expand, children: [
              AppImage(st.imageSeed, radius: 0),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0x99000000), Colors.transparent, Colors.transparent, Color(0xCC000000)], stops: [0, .2, .65, 1], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      for (var k = gStart; k <= gEnd; k++)
                        Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
                            child: k < _i
                                ? const ColoredBox(color: Colors.white)
                                : k == _i
                                    ? AnimatedBuilder(
                                        animation: _ac,
                                        builder: (_, __) => FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: _ac.value,
                                          child: const ColoredBox(color: Colors.white),
                                        ),
                                      )
                                    : null,
                          ),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      mine ? Avatar(s.avatarSeed, name: s.name, radius: 18) : Avatar(t!.seed, name: t.name, radius: 18),
                      const SizedBox(width: 10),
                      Text(mine ? tr('Your story') : t!.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Text(st.time, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const Spacer(),
                      if (mine)
                        IconButton(
                          tooltip: tr('Delete story'),
                          onPressed: () async {
                            _ac.stop();
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text(tr('Delete this story?')),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
                                  FilledButton(style: FilledButton.styleFrom(backgroundColor: C.danger), onPressed: () => Navigator.pop(c, true), child: Text(tr('Delete'))),
                                ],
                              ),
                            );
                            if (!context.mounted) return;
                            if (ok == true) {
                              await context.read<SocialState>().deleteStory(st);
                              if (context.mounted) Navigator.of(context).maybePop();
                            } else {
                              _ac.forward();
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                        ),
                      IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close_rounded, color: Colors.white)),
                    ]),
                    const Spacer(),
                    Text(st.caption, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.25)),
                    if (place != null) ...[
                      const SizedBox(height: 10),
                      ActionChip(
                        backgroundColor: Colors.white,
                        avatar: const Icon(Icons.location_on_rounded, color: C.on, size: 16),
                        label: Text(place.name, style: const TextStyle(color: C.on, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          _ac.stop();
                          go(context, PlaceDetailScreen(place: place)).then((_) => _ac.forward());
                        },
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (mine) _ViewersPill(key: ValueKey(st.id), storyId: st.id, pause: _ac.stop, resume: _ac.forward),
                    if (!mine)
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _reply,
                            onTap: _ac.stop,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Reply to ${t!.first}...',
                              hintStyle: const TextStyle(color: Colors.white70),
                              fillColor: Colors.white12,
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.white38)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.white)),
                            ),
                            onSubmitted: (v) => _send(t, v),
                          ),
                        ),
                        const SizedBox(width: 6),
                        for (final e in const ['❤️', '😍', '🧭'])
                          InkWell(onTap: () => _send(t, e), child: Padding(padding: const EdgeInsets.all(4), child: Text(tr(e), style: const TextStyle(fontSize: 24)))),
                      ]),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _send(Traveler t, String v) {
    if (v.trim().isEmpty) return;
    final social = context.read<SocialState>();
    social.send(social.chatWith(t), v.trim());
    _reply.clear();
    toast(context, 'Sent to ${t.first}');
    FocusScope.of(context).unfocus();
    _ac.forward();
  }
}


/// "N viewers" pill on your own story; tap to see who watched it, Facebook style.
class _ViewersPill extends StatefulWidget {
  final String storyId;
  final VoidCallback pause;
  final TickerFuture Function({double? from}) resume;
  const _ViewersPill({super.key, required this.storyId, required this.pause, required this.resume});
  @override
  State<_ViewersPill> createState() => _ViewersPillState();
}

class _ViewersPillState extends State<_ViewersPill> {
  List<(String, String, String, DateTime)>? _viewers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Backend.on) {
      // Demo: a few sample travelers.
      final now = DateTime.now();
      setState(() => _viewers = [
            for (var i = 0; i < travelers.length && i < 4; i++)
              (travelers[i].id, travelers[i].name, travelers[i].seed, now.subtract(Duration(minutes: 7 * (i + 1))))
          ]);
      return;
    }
    try {
      final v = await Backend.storyViewers(widget.storyId);
      if (mounted) setState(() => _viewers = v);
    } catch (_) {
      if (mounted) setState(() => _viewers = const []);
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  Future<void> _open() async {
    widget.pause();
    await _load();
    if (!mounted) return;
    final v = _viewers ?? const [];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .5,
        minChildSize: .3,
        maxChildSize: .9,
        builder: (c, scroll) => Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(children: [
              const Icon(Icons.visibility_rounded, color: C.primary, size: 20),
              const SizedBox(width: 8),
              Text('${v.length} ${v.length == 1 ? 'viewer' : 'viewers'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: v.isEmpty
                ? const EmptyState(Icons.visibility_off_outlined, 'No views yet', 'When travelers watch your story, they show up here.')
                : ListView.builder(
                    controller: scroll,
                    itemCount: v.length,
                    itemBuilder: (c, i) => ListTile(
                      leading: Avatar(v[i].$3, name: v[i].$2, radius: 20),
                      title: Text(v[i].$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(_ago(v[i].$4), style: const TextStyle(fontSize: 12, color: C.muted)),
                    ),
                  ),
          ),
        ]),
      ),
    );
    if (mounted) widget.resume();
  }

  @override
  Widget build(BuildContext context) {
    final v = _viewers;
    final shown = (v ?? const []).take(3).toList();
    return GestureDetector(
      onTap: _open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.visibility_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(v == null ? '...' : '${v.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          if (shown.isNotEmpty) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 16.0 * shown.length + 8,
              height: 24,
              child: Stack(children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(left: 16.0 * i, child: CircleAvatar(radius: 12, backgroundColor: Colors.black, child: Avatar(shown[i].$3, name: shown[i].$2, radius: 11))),
              ]),
            ),
          ],
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 18),
        ]),
      ),
    );
  }
}
