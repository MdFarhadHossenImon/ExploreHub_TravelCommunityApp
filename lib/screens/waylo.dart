import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'ai_planner.dart';
import 'bookings.dart';
import 'community.dart';
import 'feedback.dart';
import 'festivals.dart';
import 'friends.dart';
import 'global_search.dart';
import 'groups.dart';
import 'guides.dart';
import 'live_sos.dart';
import 'meetups.dart';
import 'messages.dart';
import 'notifications.dart';
import 'passport.dart';
import 'phrasebook.dart';
import 'place_detail.dart';
import 'profile.dart';
import 'safety.dart';
import 'shell.dart';

const wayloColor = Color(0xFF7BC4C4);

/// Opens a screen named by one of Waylo's action ids.
void wayloOpen(BuildContext context, String id) {
  void tab(int i) {
    shellTab.value = i;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  switch (id) {
    case 'new_post':
      go(context, const CreatePostScreen());
    case 'watch':
      tab(2);
    case 'trips':
      tab(3);
    case 'search':
      go(context, const GlobalSearchScreen());
    case 'bookings':
      go(context, const Scaffold(body: BookingsScreen()));
    case 'planner':
      go(context, const AiPlannerScreen());
    case 'buddies':
      go(context, const FriendsScreen());
    case 'messages':
      go(context, const MessagesScreen());
    case 'groups':
      go(context, const GroupsScreen());
    case 'meetups':
      go(context, const MeetupsScreen());
    case 'guides':
      go(context, const GuidesScreen());
    case 'sos':
      go(context, const LiveMapScreen());
    case 'passport':
      go(context, const PassportScreen());
    case 'phrasebook':
      go(context, const PhrasebookScreen());
    case 'festivals':
      go(context, const FestivalsScreen());
    case 'saved':
      go(context, const SavedPlacesScreen());
    case 'profile':
      go(context, const ProfileScreen(standalone: true));
    case 'notifications':
      go(context, const NotificationsScreen());
    case 'safety':
      go(context, const SafetyCenterScreen());
    case 'feedback':
      go(context, const FeedbackScreen());
  }
}

class _Msg {
  final bool me;
  final String text;
  _Msg(this.me, this.text);
  Map<String, dynamic> toJson() => {'me': me, 'text': text};
  static _Msg fromJson(Map<String, dynamic> j) => _Msg(j['me'] == true, '${j['text'] ?? ''}');
}

/// The built-in guide: answers app questions for free, offline, and when the AI is off.
class _Guide {
  final List<Map<String, dynamic>> sections;
  final Map<String, String> actions;
  _Guide(this.sections, this.actions);

  static _Guide? _cache;
  static Future<_Guide> load() async {
    if (_cache != null) return _cache!;
    final j = jsonDecode(await rootBundle.loadString('assets/waylo_guide.json')) as Map<String, dynamic>;
    return _cache = _Guide(
      (j['sections'] as List).cast<Map<String, dynamic>>(),
      Map<String, String>.from(j['actions'] as Map),
    );
  }

  static const _stop = {
    'how', 'do', 'does', 'did', 'can', 'could', 'should', 'would', 'what', 'where', 'when', 'which', 'who', 'why', 'is', 'are', 'am', 'the', 'to',
    'in', 'on', 'of', 'for', 'and', 'or', 'my', 'me', 'it', 'an', 'at', 'with', 'from', 'this', 'that', 'there', 'get', 'use', 'using', 'app',
    'best', 'time', 'visit', 'please', 'want', 'need', 'about', 'any', 'some', 'you', 'your', 'go', 'be',
    'কী', 'কি', 'কীভাবে', 'কিভাবে', 'কেমনে', 'করব', 'করবো', 'করে', 'করতে', 'আমি', 'আমার', 'কোথায়', 'কখন', 'কোন', 'এর', 'যে', 'আর', 'একটা', 'চাই', 'হবে', 'যাব', 'যাবো',
  };

  static List<String> _words(String s) =>
      s.toLowerCase().split(RegExp(r'[\s,.?!।:;()"\x27/-]+')).where((w) => w.length > 1 && !_stop.contains(w)).toList();

  /// True when [a] is [b] with a small typo: 1 edit for short words, 2 for words of 7+ letters (a swap counts as 1).
  static bool _typo(String a, String b) {
    final max = a.length >= 7 ? 2 : 1;
    if ((a.length - b.length).abs() > max) return false;
    final d = List.generate(a.length + 1, (i) => List<int>.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final c = a[i - 1] == b[j - 1] ? 0 : 1;
        var v = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + c].reduce((x, y) => x < y ? x : y);
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1] && d[i - 2][j - 2] + 1 < v) v = d[i - 2][j - 2] + 1;
        d[i][j] = v;
      }
    }
    return d[a.length][b.length] <= max;
  }

  /// The best guide section for these words and its score; words that appear in fewer sections count more.
  (double, Map<String, dynamic>?) _match(List<String> words) {
    final kws = [for (final s in sections) _words(s['kw'] as String)];
    double weight(String w) {
      final n = kws.where((k) => k.contains(w)).length;
      return n == 0 ? 0.5 : 1 / n;
    }

    var best = 0.0;
    Map<String, dynamic>? hit;
    for (var i = 0; i < sections.length; i++) {
      final kw = kws[i];
      var score = 0.0;
      for (final w in words) {
        if (kw.contains(w)) {
          score += weight(w);
        } else if (w.length > 3) {
          // Typos: "feather" finds "feature", "bookign" finds "booking".
          final near = kw.where((k) => k.length > 3 && _typo(w, k)).toList();
          if (near.isNotEmpty) {
            score += 0.8 * weight(near.first);
          } else if (kw.any((k) => k.length > 3 && (k.startsWith(w) || w.startsWith(k)))) {
            score += 0.3;
          }
        }
      }
      if (score > best) {
        best = score;
        hit = sections[i];
      }
    }
    return (best, hit);
  }

  /// True when the question is clearly about using ExploreHub, so the guide answers it on the phone.
  bool isAppQuestion(String q) => _match(_words(q)).$1 >= 1;

  /// Best guide answer, a place answer, or a friendly "don't know".
  String answer(String q) {
    final words = _words(q);
    final lower = q.toLowerCase();
    final bn = isBangla || RegExp('[\u0980-\u09FF]').hasMatch(q); // answer Bangla questions in Bangla

    // A place the app knows about.
    Place? place;
    for (final p in places) {
      final n = p.name.toLowerCase();
      if (lower.contains(n) || words.any((w) => w.length > 3 && n.split(' ').contains(w))) {
        place = p;
        break;
      }
    }

    final (best, hit) = _match(words);

    if (place != null && best < 1) {
      final p = place;
      return bn
          ? '${p.name}, ${p.where}\n${p.about}\n\nঘোরার সেরা সময়: ${p.season}\nকীভাবে যাবেন: ${p.hub} থেকে, ${p.lastDetail} (${p.lastDuration})${p.budgetLow != null ? '\nদৈনিক খরচ: প্রায় \$${p.budgetLow}–${p.budgetHigh}' : ''}\n[[place:${p.id}]]\n[[open:planner]]'
          : '${p.name}, ${p.where}\n${p.about}\n\nBest season: ${p.season}\nGetting there: from ${p.hub}, ${p.lastDetail} (${p.lastDuration})${p.budgetLow != null ? '\nDaily budget: about \$${p.budgetLow}–${p.budgetHigh}' : ''}\n[[place:${p.id}]]\n[[open:planner]]';
    }
    if (hit != null && best >= 0.3) {
      final a = hit['action'] as String?;
      return '${bn ? hit['bn'] : hit['en']}${a == null ? '' : '\n[[open:$a]]'}';
    }
    return tr("I'm not sure about that one yet. Ask me how to use ExploreHub (posting, trips, bookings, SOS…), name a place, like \"Sajek Valley\", or ask about the weather or today's dollar rate.");
  }
}

/// Waylo: ExploreHub's assistant for app help and travel questions.
class WayloScreen extends StatefulWidget {
  final String? ask;
  const WayloScreen({super.key, this.ask});
  @override
  State<WayloScreen> createState() => _WayloScreenState();
}

class _WayloScreenState extends State<WayloScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _busy = false;
  static bool? _ai; // null until the server answers: true with the AI, false in free mode

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('waylo_chat');
      if (raw != null) _msgs.addAll((jsonDecode(raw) as List).map((e) => _Msg.fromJson(Map<String, dynamic>.from(e as Map))));
    } catch (_) {}
    if (mounted) setState(() {});
    _toEnd();
    if (widget.ask != null) _send(widget.ask!);
  }

  Future<void> _persist() async {
    try {
      final keep = _msgs.length > 40 ? _msgs.sublist(_msgs.length - 40) : _msgs;
      await (await SharedPreferences.getInstance()).setString('waylo_chat', jsonEncode(keep.map((m) => m.toJson()).toList()));
    } catch (_) {}
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg(true, text));
      _busy = true;
    });
    _toEnd();
    String reply;
    try {
      final guide = await _Guide.load();
      // App questions are answered here unless the AI is on; everything else goes to the server,
      // which uses the AI or, without it, the free live search (weather, rates, Wikivoyage / Wikipedia).
      if (Backend.on && !(_ai != true && guide.isAppQuestion(text))) {
        final history = [
          for (final m in _msgs.length > 12 ? _msgs.sublist(_msgs.length - 12) : _msgs) {'role': m.me ? 'user' : 'assistant', 'content': m.text}
        ];
        final res = await Backend.waylo(history, lang: isBangla ? 'bn' : 'en');
        _ai = res['mode'] == 'ai';
        reply = '${res['reply'] ?? ''}';
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        reply = (await _Guide.load()).answer(text);
      }
    } on PlannerError catch (e) {
      if (e.code == 'not_configured' || e.code == 'server') {
        if (e.code == 'not_configured') _ai = false;
        reply = (await _Guide.load()).answer(text);
      } else {
        reply = tr(e.message);
      }
    } catch (_) {
      // Offline or network trouble: the guide still works.
      reply = (await _Guide.load()).answer(text);
    }
    if (!mounted) return;
    setState(() {
      _msgs.add(_Msg(false, reply));
      _busy = false;
    });
    _persist();
    _toEnd();
  }

  void _clear() {
    setState(_msgs.clear);
    _persist();
  }

  static final _marker = RegExp(r'\[\[(open|place):([a-z0-9_\-]+)\]\]');

  Widget _bubble(_Msg m, _Guide? guide) {
    final buttons = <Widget>[];
    var text = m.text;
    if (!m.me) {
      for (final x in _marker.allMatches(text)) {
        final kind = x.group(1)!, id = x.group(2)!;
        if (kind == 'open') {
          final label = guide?.actions[id];
          if (label == null) continue;
          buttons.add(ActionChip(avatar: const Icon(Icons.arrow_forward_rounded, size: 16), label: Text(tr(label)), onPressed: () => wayloOpen(context, id)));
        } else {
          final p = places.where((p) => p.id == id).firstOrNull;
          if (p == null) continue;
          buttons.add(ActionChip(avatar: const Icon(Icons.place_rounded, size: 16), label: Text(p.name), onPressed: () => go(context, PlaceDetailScreen(place: p))));
        }
      }
      text = text.replaceAll(_marker, '').replaceAll('**', '').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    }
    return Align(
      alignment: m.me ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(crossAxisAlignment: m.me ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: m.me ? C.primary : C.card,
                border: m.me ? null : Border.all(color: C.line),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(m.me ? 18 : 4),
                  bottomRight: Radius.circular(m.me ? 4 : 18),
                ),
              ),
              child: SelectableText(text, style: TextStyle(color: m.me ? C.on : null, height: 1.4, fontSize: 14.5)),
            ),
            if (buttons.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, runSpacing: 6, children: buttons)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final starters = [
      'How do I plan a trip?',
      'How do I share a video?',
      'How does SOS work?',
      'Best time to visit Sajek Valley?',
      'Weather in Sylhet this week?',
      '100 dollars in taka today?',
      'How do I find a travel buddy?',
      'How do I book a hotel?',
    ];
    return FutureBuilder<_Guide>(
      future: _Guide.load(),
      builder: (context, g) => ScreenScaffold(
        title: 'Waylo',
        maxWidth: 760,
        actions: [if (_msgs.isNotEmpty) IconButton(tooltip: tr('New chat'), onPressed: _clear, icon: const Icon(Icons.refresh_rounded))],
        body: Column(children: [
          Expanded(
            child: ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const WayloAvatar(radius: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Waylo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(tr('Hi! I\'m Waylo, your travel buddy in ExploreHub. Ask me how to use the app, or anything about a trip: places, routes, seasons, budgets.'),
                        style: const TextStyle(color: C.muted, height: 1.4)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              if (_msgs.isEmpty)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in starters) ActionChip(label: Text(tr(s)), onPressed: () => _send(tr(s))),
                ]),
              for (final m in _msgs) _bubble(m, g.data),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Waylo…', style: TextStyle(color: C.muted)),
                  ]),
                ),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(hintText: tr('Ask Waylo anything…')),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _busy ? null : () => _send(_input.text), icon: const Icon(Icons.send_rounded)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Waylo's round badge.
class WayloAvatar extends StatelessWidget {
  final double radius;
  const WayloAvatar({super.key, this.radius = 16});
  @override
  Widget build(BuildContext context) => Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF7BC4C4), Color(0xFFE9B872)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Icon(Icons.explore_rounded, color: Colors.white, size: radius * 1.15),
      );
}
