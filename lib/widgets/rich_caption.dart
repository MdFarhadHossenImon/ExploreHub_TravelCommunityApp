import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../data/social.dart';
import '../screens/community.dart' show PostCard;
import '../screens/traveler_profile.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Mentions are stored in text as `@[Name](user id)`; hashtags are plain `#words`.
final mentionRe = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');
final hashtagRe = RegExp(r'#[\p{L}\p{M}\p{N}_]{2,40}', unicode: true);
final _token = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)|#[\p{L}\p{M}\p{N}_]{2,40}', unicode: true);

/// The text people see: `@[Ayesha Rahman](id)` becomes `@Ayesha Rahman`.
String plainText(String s) => s.replaceAllMapped(mentionRe, (m) => '@${m[1]}');

/// Mentions in a stored text, name -> id (to keep them when the text is edited).
Map<String, String> mentionsIn(String s) => {for (final m in mentionRe.allMatches(s)) m[1]!: m[2]!};

/// Turns `@Name` back into stored mentions for the people picked from suggestions.
String encodeMentions(String text, Map<String, String> picked) {
  final names = picked.keys.toList()..sort((a, b) => b.length.compareTo(a.length)); // longest first
  for (final n in names) {
    text = text.replaceAll('@$n', '@[$n](${picked[n]})');
  }
  return text;
}

void openMention(BuildContext context, String id, String name) {
  final known = travelers.where((t) => t.id == id || t.name == name);
  if (known.isNotEmpty) {
    go(context, TravelerProfileScreen(traveler: known.first));
  } else if (Backend.on) {
    Backend.fetchTraveler(id).then((t) {
      if (t != null && context.mounted) go(context, TravelerProfileScreen(traveler: t));
    });
  }
}

/// Text with tappable @mentions (open the profile) and #hashtags (open the tag's posts).
class RichCaption extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  const RichCaption(this.text, {super.key, this.style, this.maxLines, this.overflow = TextOverflow.clip});
  @override
  State<RichCaption> createState() => _RichCaptionState();
}

class _RichCaptionState extends State<RichCaption> {
  final List<TapGestureRecognizer> _taps = [];

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final link = TextStyle(color: C.primary, fontWeight: FontWeight.w700);
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in _token.allMatches(widget.text)) {
      if (m.start > at) spans.add(TextSpan(text: widget.text.substring(at, m.start)));
      final tap = TapGestureRecognizer();
      _taps.add(tap);
      if (m[1] != null) {
        final name = m[1]!, id = m[2]!;
        tap.onTap = () => openMention(context, id, name);
        spans.add(TextSpan(text: name, style: link, recognizer: tap));
      } else {
        final tag = m[0]!;
        tap.onTap = () => go(context, HashtagScreen(tag));
        spans.add(TextSpan(text: tag, style: link, recognizer: tap));
      }
      at = m.end;
    }
    if (at < widget.text.length) spans.add(TextSpan(text: widget.text.substring(at)));
    return Text.rich(TextSpan(children: spans), style: widget.style, maxLines: widget.maxLines, overflow: widget.overflow);
  }
}

/// Suggestions while typing `@name` in a text field; picking one inserts the name and remembers who it is.
class MentionBar extends StatefulWidget {
  final TextEditingController controller;
  final Map<String, String> picked; // filled in as people are picked: name -> id
  const MentionBar({super.key, required this.controller, required this.picked});
  @override
  State<MentionBar> createState() => _MentionBarState();
}

class _MentionBarState extends State<MentionBar> {
  String? _query;
  int _start = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scan);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scan);
    super.dispose();
  }

  void _scan() {
    final v = widget.controller.value;
    final cur = v.selection.baseOffset;
    String? q;
    if (cur >= 0 && cur <= v.text.length) {
      final before = v.text.substring(0, cur);
      final m = RegExp(r'(^|\s)@([\p{L}\p{M}\p{N}_.]{0,20})$', unicode: true).firstMatch(before);
      if (m != null) {
        q = m[2]!;
        _start = cur - q.length - 1;
      }
    }
    if (q != _query) setState(() => _query = q);
  }

  void _pick(String id, String name) {
    final v = widget.controller.value;
    final cur = v.selection.baseOffset;
    final text = '${v.text.substring(0, _start)}@$name ${v.text.substring(cur)}';
    widget.picked[name] = id;
    widget.controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: _start + name.length + 2));
  }

  @override
  Widget build(BuildContext context) {
    final q = _query?.toLowerCase();
    if (q == null) return const SizedBox.shrink();
    final s = context.read<AppState>();
    final people = travelers
        .where((t) => t.id != Backend.uid && (q.isEmpty || t.name.toLowerCase().split(' ').any((w) => w.startsWith(q)) || t.name.toLowerCase().startsWith(q)))
        .toList()
      ..sort((a, b) => (s.following.contains(b.id) ? 1 : 0).compareTo(s.following.contains(a.id) ? 1 : 0));
    if (people.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 46,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), children: [
        for (final t in people.take(12))
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: Avatar(t.seed, name: t.name, radius: 11),
              label: Text(t.name),
              onPressed: () => _pick(t.id, t.name),
            ),
          ),
      ]),
    );
  }
}

/// Every post with a hashtag, newest first.
class HashtagScreen extends StatefulWidget {
  final String tag;
  const HashtagScreen(this.tag, {super.key});
  @override
  State<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends State<HashtagScreen> {
  List<Post>? _posts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tag = widget.tag.toLowerCase();
    bool has(Post p) => hashtagRe.allMatches(p.caption).any((m) => m[0]!.toLowerCase() == tag);
    if (!Backend.on) {
      setState(() => _posts = context.read<AppState>().posts.where(has).toList());
      return;
    }
    try {
      final list = await Backend.postsWithTag(widget.tag);
      if (mounted) setState(() => _posts = list.where(has).toList());
    } catch (e) {
      if (mounted) {
        setState(() => _posts = const []);
        toast(context, errText(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    return ScreenScaffold(
      title: widget.tag,
      maxWidth: 680,
      body: posts == null
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
              ? EmptyState(Icons.tag_rounded, tr('No posts yet'), tr('Be the first to post with {tag}.').replaceAll('{tag}', widget.tag))
              : ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(tr('{n} posts').replaceAll('{n}', '${posts.length}'), style: TextStyle(color: C.muted)),
                  ),
                  for (final p in posts) PostCard(p),
                ]),
    );
  }
}
