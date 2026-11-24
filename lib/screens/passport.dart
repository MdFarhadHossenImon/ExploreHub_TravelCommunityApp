import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../widgets/common.dart';
import '../widgets/social_widgets.dart';

/// Country names in the map file that differ from the names used in the app.
const _alias = {
  'United States': 'United States of America',
  'USA': 'United States of America',
  'UK': 'United Kingdom',
  'Bosnia and Herzegovina': 'Bosnia and Herz.',
  'Central African Republic': 'Central African Rep.',
  'Democratic Republic of the Congo': 'Dem. Rep. Congo',
  'Dominican Republic': 'Dominican Rep.',
  'Equatorial Guinea': 'Eq. Guinea',
  'South Sudan': 'S. Sudan',
  'Czech Republic': 'Czechia',
  'Ivory Coast': "Côte d'Ivoire",
  'Eswatini': 'eSwatini',
  'Swaziland': 'eSwatini',
  'East Timor': 'Timor-Leste',
  'Western Sahara': 'W. Sahara',
  'Solomon Islands': 'Solomon Is.',
  'Republic of the Congo': 'Congo',
  'Türkiye': 'Turkey',
  'Korea': 'South Korea',
  'Burma': 'Myanmar',
};

String _mapName(String c) => _alias[c] ?? c;

class _Shape {
  final String name;
  final List<List<Offset>> rings; // lon, lat
  _Shape(this.name, this.rings);
}

List<_Shape>? _shapes;
Future<List<_Shape>> _loadShapes() async {
  if (_shapes != null) return _shapes!;
  final data = jsonDecode(await rootBundle.loadString('assets/world.json')) as List;
  return _shapes = [
    for (final c in data)
      if (c['n'] != 'Antarctica' && c['n'] != 'Fr. S. Antarctic Lands')
        _Shape(c['n'] as String, [
          for (final r in c['r'] as List)
            [
              for (var i = 0; i + 1 < (r as List).length; i += 2) Offset((r[i] as num).toDouble(), (r[i + 1] as num).toDouble()),
            ],
        ]),
  ];
}

/// Flat world map with the visited countries filled in.
class _MapPainter extends CustomPainter {
  final List<_Shape> shapes;
  final Set<String> visited, said;
  final List<Offset> points;
  _MapPainter(this.shapes, this.visited, this.said, this.points);

  static const _top = 84.0, _bottom = -58.0;
  Offset _p(Offset ll, Size s) => Offset((ll.dx + 180) / 360 * s.width, (_top - ll.dy) / (_top - _bottom) * s.height);

  @override
  void paint(Canvas canvas, Size size) {
    final land = Paint()..color = const Color(0xFF2C4441);
    final been = Paint()..color = C.primary;
    final said = Paint()..color = C.primary.withValues(alpha: .45);
    final edge = Paint()
      ..color = const Color(0xFF1B2D2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6;
    for (final sh in shapes) {
      final path = Path();
      for (final r in sh.rings) {
        if (r.isEmpty) continue;
        path.moveTo(_p(r.first, size).dx, _p(r.first, size).dy);
        for (final o in r.skip(1)) {
          final q = _p(o, size);
          path.lineTo(q.dx, q.dy);
        }
        path.close();
      }
      canvas.drawPath(path, visited.contains(sh.name) ? been : (this.said.contains(sh.name) ? said : land));
      canvas.drawPath(path, edge);
    }
    final dot = Paint()..color = Colors.white;
    final ring = Paint()
      ..color = const Color(0xFFE5484D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final ll in points) {
      final q = _p(ll, size);
      canvas.drawCircle(q, 3.2, dot);
      canvas.drawCircle(q, 3.2, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter o) => o.visited != visited || o.points != points;
}

class _Badge {
  final IconData icon;
  final String title, how;
  final bool got;
  const _Badge(this.icon, this.title, this.how, this.got);
}

/// Travel passport: map of visited countries, stamps, badges and "Year in travel".
class PassportScreen extends StatefulWidget {
  final String? userId; // null = you
  final String name;
  final List<String> saidCountries; // countries the traveler listed on their profile
  const PassportScreen({super.key, this.userId, this.name = '', this.saidCountries = const []});
  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  Map<String, dynamic>? _all, _year;
  List<_Shape>? _world;
  int _y = DateTime.now().year;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadShapes().then((w) => mounted ? setState(() => _world = w) : null);
    _load();
  }

  static Map<String, dynamic> _demo(bool year) => {
        'posts': year ? 14 : 38,
        'videos': 6,
        'places': year ? 7 : 19,
        'countries': [
          {'country': 'Bangladesh', 'first': '2024-01-12', 'places': 11},
          {'country': 'Nepal', 'first': '2024-10-03', 'places': 3},
          {'country': 'Thailand', 'first': '2025-02-14', 'places': 3},
          if (!year) {'country': 'India', 'first': '2025-06-20', 'places': 2},
        ],
        'continents': ['Asia'],
        'months': {'1': 2, '2': 3, '4': 1, '6': 2, '10': 4, '12': 2},
        'top_place': "Cox's Bazar",
        'first_place': 'Sajek Valley',
        'last_place': 'Pokhara',
        'points': [
          {'lat': 21.43, 'lng': 92.0, 'name': "Cox's Bazar"},
          {'lat': 23.38, 'lng': 92.29, 'name': 'Sajek Valley'},
          {'lat': 28.21, 'lng': 83.99, 'name': 'Pokhara'},
          {'lat': 7.88, 'lng': 98.39, 'name': 'Phuket'},
        ],
        'trips': year ? 3 : 7,
        'trip_days': year ? 12 : 31,
        'meetups': 2,
        'hosted': 1,
        'buddies': 5,
        'new_buddies': 3,
        'groups': 3,
        'reviews': 4,
        'likes_got': 212,
        'since': '2024-01-01',
      };

  Future<void> _load() async {
    if (!Backend.on) {
      setState(() {
        _all = _demo(false);
        _year = _demo(true);
      });
      return;
    }
    try {
      final r = await Future.wait([Backend.passport(widget.userId, null), Backend.passport(widget.userId, _y)]);
      if (mounted) {
        setState(() {
          _all = r[0];
          _year = r[1];
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _pickYear(int y) async {
    setState(() {
      _y = y;
      _year = null;
    });
    if (!Backend.on) return setState(() => _year = _demo(true));
    try {
      final r = await Backend.passport(widget.userId, y);
      if (mounted) setState(() => _year = r);
    } catch (_) {}
  }

  int _n(Map<String, dynamic>? m, String k) => (m?[k] as num?)?.toInt() ?? 0;

  List<_Badge> _badges(Map<String, dynamic> a) {
    final countries = (a['countries'] as List).length;
    final continents = (a['continents'] as List).length;
    final bdPlaces = ((a['countries'] as List).cast<Map>().where((c) => c['country'] == 'Bangladesh').map((c) => (c['places'] as num).toInt()).fold(0, (x, y) => x + y));
    return [
      _Badge(Icons.flag_rounded, 'First stamp', 'Post from a tagged place', countries >= 1),
      _Badge(Icons.travel_explore_rounded, 'Explorer', 'Visit 5 countries', countries >= 5),
      _Badge(Icons.public_rounded, 'Globetrotter', 'Visit 15 countries', countries >= 15),
      _Badge(Icons.language_rounded, 'Continent hopper', 'Visit 3 continents', continents >= 3),
      _Badge(Icons.landscape_rounded, 'Desh explorer', 'See 10 places in Bangladesh', bdPlaces >= 10),
      _Badge(Icons.photo_camera_rounded, 'Storyteller', 'Share 25 posts', _n(a, 'posts') >= 25),
      _Badge(Icons.videocam_rounded, 'Filmmaker', 'Share 5 videos', _n(a, 'videos') >= 5),
      _Badge(Icons.map_rounded, 'Planner', 'Plan 3 trips', _n(a, 'trips') >= 3),
      _Badge(Icons.handshake_rounded, 'Travel circle', 'Have 5 travel buddies', _n(a, 'buddies') >= 5),
      _Badge(Icons.event_available_rounded, 'Host', 'Host a meetup', _n(a, 'hosted') >= 1),
      _Badge(Icons.rate_review_rounded, 'Helpful reviewer', 'Write 5 reviews', _n(a, 'reviews') >= 5),
      _Badge(Icons.favorite_rounded, 'Loved', 'Get 100 likes', _n(a, 'likes_got') >= 100),
    ];
  }

  void _shareYear() {
    final y = _year;
    if (y == null) return;
    final countries = (y['countries'] as List).map((c) => c['country']).join(', ');
    final text = isBangla
        ? 'ExploreHub-এ আমার $_y সালের ভ্রমণ: ${_n(y, 'places')}টি জায়গা, ${(y['countries'] as List).length}টি দেশ ($countries), ${_n(y, 'trips')}টি ট্রিপ, ${_n(y, 'trip_days')} দিন পথে।'
        : 'My $_y in travel on ExploreHub: ${_n(y, 'places')} places, ${(y['countries'] as List).length} countries ($countries), ${_n(y, 'trips')} trips, ${_n(y, 'trip_days')} days on the road.';
    Clipboard.setData(ClipboardData(text: text));
    toast(context, tr('Copied. Paste it in a post, story or chat.'));
  }

  Widget _stat(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: C.primary)),
          Text(tr(l), textAlign: TextAlign.center, style: const TextStyle(color: C.muted, fontSize: 11.5)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final a = _all;
    final title = widget.userId == null ? tr('My travel passport') : trf("{0}'s travel passport", [widget.name]);
    if (a == null) {
      return ScreenScaffold(
        title: title,
        body: Center(child: _failed ? Text(tr('Could not open this right now')) : const CircularProgressIndicator()),
      );
    }
    final countries = (a['countries'] as List).cast<Map>();
    final visited = {for (final c in countries) _mapName(c['country'] as String)};
    final said = {for (final c in widget.saidCountries) _mapName(c)}..removeAll(visited);
    final pts = [for (final p in (a['points'] as List).cast<Map>()) Offset((p['lng'] as num).toDouble(), (p['lat'] as num).toDouble())];
    final badges = _badges(a);
    final got = badges.where((b) => b.got).length;
    final pct = (visited.length / 195 * 100);

    return ScreenScaffold(
      title: title,
      maxWidth: 900,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ---- map ----
        Panel(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 2.05,
              child: _world == null
                  ? const Center(child: CircularProgressIndicator())
                  : RepaintBoundary(child: CustomPaint(painter: _MapPainter(_world!, visited, said, pts))),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _stat('${visited.length}', 'countries'),
              _stat('${_n(a, 'places')}', 'places'),
              _stat('${(a['continents'] as List).length}', 'continents'),
              _stat('${pct.toStringAsFixed(pct < 1 ? 1 : 0)}%', 'of the world'),
            ]),
            if (said.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text(tr('Posted from there'), style: const TextStyle(fontSize: 11.5, color: C.muted)),
                const SizedBox(width: 14),
                Container(width: 12, height: 12, decoration: BoxDecoration(color: C.primary.withValues(alpha: .45), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text(tr('Listed on profile'), style: const TextStyle(fontSize: 11.5, color: C.muted)),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        // ---- year in travel ----
        _YearCard(
          year: _y,
          data: _year,
          since: DateTime.tryParse('${a['since'] ?? ''}')?.year ?? DateTime.now().year,
          onYear: _pickYear,
          onShare: widget.userId == null ? _shareYear : null,
        ),
        const SizedBox(height: 16),
        // ---- stamps ----
        Text(tr('Passport stamps'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 10),
        if (countries.isEmpty)
          Text(tr('Tag a place when you post and you get a stamp for its country.'), style: const TextStyle(color: C.muted))
        else
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (var i = 0; i < countries.length; i++) _Stamp(countries[i], i),
          ]),
        const SizedBox(height: 20),
        // ---- badges ----
        Row(children: [
          Expanded(child: Text(tr('Badges'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          Text(trf('{0} of {1}', [got, badges.length]), style: const TextStyle(color: C.muted)),
        ]),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 600 ? 4 : 3;
          final w = (c.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final b in badges)
              SizedBox(
                width: w,
                child: Opacity(
                  opacity: b.got ? 1 : .42,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: b.got ? C.primary : C.line)),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: b.got ? C.primary : C.tint),
                        child: Icon(b.got ? b.icon : Icons.lock_rounded, color: b.got ? C.on : C.muted, size: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(tr(b.title), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                      Text(tr(b.how), textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(color: C.muted, fontSize: 10.5)),
                    ]),
                  ),
                ),
              ),
          ]);
        }),
      ]),
    );
  }
}

class _Stamp extends StatelessWidget {
  final Map c;
  final int i;
  const _Stamp(this.c, this.i);
  @override
  Widget build(BuildContext context) {
    final col = [C.primary, const Color(0xFF8FB3AC), const Color(0xFFE5806F), const Color(0xFF9DB4F0)][i % 4];
    final d = DateTime.tryParse('${c['first']}');
    return Transform.rotate(
      angle: (i % 3 - 1) * 0.08,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: col, width: 2.5)),
        padding: const EdgeInsets.all(5),
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: col.withValues(alpha: .6), width: 1)),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.flight_land_rounded, size: 15, color: col),
            Text((c['country'] as String).toUpperCase(),
                textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: col, fontWeight: FontWeight.w900, fontSize: 9.5, letterSpacing: .5)),
            if (d != null) Text(fmtDate(d), style: TextStyle(color: col, fontSize: 8.5)),
          ]),
        ),
      ),
    );
  }
}

class _YearCard extends StatelessWidget {
  final int year, since;
  final Map<String, dynamic>? data;
  final ValueChanged<int> onYear;
  final VoidCallback? onShare;
  const _YearCard({required this.year, required this.since, required this.data, required this.onYear, this.onShare});

  int _n(String k) => (data?[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().year;
    final years = [for (var y = now; y >= math.min(since, now); y--) y];
    final months = (data?['months'] as Map?) ?? const {};
    final maxM = months.values.fold<int>(1, (m, v) => math.max(m, (v as num).toInt()));
    const mo = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFF2E5B55), Color(0xFF1C3532)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: C.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: C.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(trf('Your {0} in travel', [year]), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
          if (years.length > 1)
            DropdownButton<int>(
              value: year,
              underline: const SizedBox(),
              items: [for (final y in years) DropdownMenuItem(value: y, child: Text('$y'))],
              onChanged: (y) => y == null ? null : onYear(y),
            ),
        ]),
        const SizedBox(height: 12),
        if (data == null)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
        else ...[
          Wrap(spacing: 10, runSpacing: 10, children: [
            _tile(Icons.place_rounded, '${_n('places')}', 'places'),
            _tile(Icons.public_rounded, '${(data!['countries'] as List).length}', 'countries'),
            _tile(Icons.map_rounded, '${_n('trips')}', 'trips'),
            _tile(Icons.wb_sunny_rounded, '${_n('trip_days')}', 'days on the road'),
            _tile(Icons.photo_library_rounded, '${_n('posts')}', 'posts'),
            _tile(Icons.handshake_rounded, '${_n('new_buddies')}', 'new buddies'),
            _tile(Icons.event_available_rounded, '${_n('meetups')}', 'meetups'),
            _tile(Icons.favorite_rounded, '${_n('likes_got')}', 'likes'),
          ]),
          const SizedBox(height: 14),
          Text(tr('Posts by month'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 6),
          SizedBox(
            height: 64,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var m = 1; m <= 12; m++)
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Container(
                      height: 4 + 40 * (((months['$m'] as num?) ?? 0) / maxM),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(color: (months['$m'] ?? 0) == 0 ? C.line : C.primary, borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: 4),
                    Text(mo[m - 1], style: const TextStyle(fontSize: 10, color: C.muted)),
                  ]),
                ),
            ]),
          ),
          if (data!['top_place'] != null) ...[
            const SizedBox(height: 12),
            _line(Icons.emoji_events_rounded, trf('Favorite place: {0}', [data!['top_place']])),
            if (data!['first_place'] != null) _line(Icons.flag_rounded, trf('First stop: {0}', [data!['first_place']])),
            if (data!['last_place'] != null && data!['last_place'] != data!['first_place']) _line(Icons.where_to_vote_rounded, trf('Latest stop: {0}', [data!['last_place']])),
          ],
          if (_n('posts') == 0 && _n('trips') == 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(tr('Nothing logged for this year yet. Tag places in your posts and plan trips to fill it in.'), style: const TextStyle(color: C.muted, fontSize: 12.5)),
            ),
          if (onShare != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: onShare, icon: const Icon(Icons.ios_share_rounded, size: 18), label: Text(tr('Share my year'))),
          ],
        ],
      ]),
    );
  }

  Widget _tile(IconData i, String v, String l) => Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Icon(i, size: 18, color: C.primary),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          Text(tr(l), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 10.5)),
        ]),
      );

  Widget _line(IconData i, String t) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(i, size: 16, color: C.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
        ]),
      );
}
