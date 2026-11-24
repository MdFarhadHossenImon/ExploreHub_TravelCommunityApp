import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../data/mock_data.dart';
import '../widgets/common.dart';
import 'place_detail.dart';
import 'search.dart';

class Festival {
  final int id;
  final String name, country, category, about;
  final String? nameBn, city, placeId, wiki;
  final DateTime starts, ends;
  final bool approx;
  const Festival({
    required this.id,
    required this.name,
    required this.country,
    required this.category,
    required this.about,
    this.nameBn,
    this.city,
    this.placeId,
    this.wiki,
    required this.starts,
    required this.ends,
    this.approx = false,
  });
  factory Festival.fromRow(Map<String, dynamic> r) => Festival(
        id: (r['id'] as num).toInt(),
        name: r['name'] as String,
        nameBn: r['name_bn'] as String?,
        country: r['country'] as String,
        city: r['city'] as String?,
        placeId: r['place_id'] as String?,
        starts: DateTime.parse(r['starts'] as String),
        ends: DateTime.parse(r['ends'] as String),
        approx: r['approx'] as bool? ?? false,
        category: r['category'] as String? ?? 'festival',
        about: r['about'] as String? ?? '',
        wiki: r['wiki'] as String?,
      );
  String get title => isBangla && (nameBn ?? '').isNotEmpty ? nameBn! : name;
}

const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _day(DateTime d) => '${d.day} ${tr(_mo[d.month - 1])}';
String festivalDates(Festival f) => f.starts == f.ends ? _day(f.starts) : '${_day(f.starts)} – ${_day(f.ends)}';

/// Demo list when the app runs without the live database.
final _demo = [
  Festival(id: 1, name: 'Pohela Boishakh (Bengali New Year)', nameBn: 'পহেলা বৈশাখ', country: 'Bangladesh', city: 'Dhaka', category: 'culture', about: 'Mangal Shobhajatra parade and fairs across the country.', starts: DateTime(DateTime.now().year + 1, 4, 14), ends: DateTime(DateTime.now().year + 1, 4, 14)),
  Festival(id: 2, name: 'Victory Day', nameBn: 'বিজয় দিবস', country: 'Bangladesh', city: 'Dhaka', category: 'national', about: 'Parade, fireworks and lit-up buildings.', starts: DateTime(DateTime.now().year, 12, 16), ends: DateTime(DateTime.now().year, 12, 16)),
  Festival(id: 3, name: 'Songkran (Thai New Year)', nameBn: 'সংক্রান', country: 'Thailand', city: 'Bangkok', category: 'culture', about: 'The nationwide water fight.', starts: DateTime(DateTime.now().year + 1, 4, 13), ends: DateTime(DateTime.now().year + 1, 4, 15)),
];

Future<List<Festival>> loadFestivals({String? country, int months = 12}) async {
  if (!Backend.on) return _demo.where((f) => country == null || f.country == country).toList()..sort((a, b) => a.starts.compareTo(b.starts));
  final rows = await Backend.festivals(country: country, months: months);
  return rows.map(Festival.fromRow).toList();
}

/// Festivals and events around the world, month by month.
class FestivalsScreen extends StatefulWidget {
  final String? country;
  const FestivalsScreen({super.key, this.country});
  @override
  State<FestivalsScreen> createState() => _FestivalsScreenState();
}

class _FestivalsScreenState extends State<FestivalsScreen> {
  List<Festival>? _all;
  bool _failed = false;
  String _where = 'all'; // all | bd | world
  int? _month; // 0..11 offset from this month
  late String? _country = widget.country;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await loadFestivals(months: 13);
      if (mounted) setState(() => _all = l);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStarts = [for (var i = 0; i < 12; i++) DateTime(now.year, now.month + i, 1)];
    var list = _all ?? const <Festival>[];
    if (_country != null) list = list.where((f) => f.country == _country).toList();
    if (_where == 'bd') list = list.where((f) => f.country == 'Bangladesh').toList();
    if (_where == 'world') list = list.where((f) => f.country != 'Bangladesh').toList();
    if (_month != null) {
      final m = monthStarts[_month!], next = DateTime(m.year, m.month + 1, 1);
      list = list.where((f) => !f.ends.isBefore(m) && f.starts.isBefore(next)).toList();
    }

    // Group by the month each festival starts in (ongoing ones go under this month).
    final groups = <DateTime, List<Festival>>{};
    for (final f in list) {
      final s = f.starts.isBefore(DateTime(now.year, now.month, 1)) ? DateTime(now.year, now.month, 1) : DateTime(f.starts.year, f.starts.month, 1);
      groups.putIfAbsent(s, () => []).add(f);
    }
    final keys = groups.keys.toList()..sort();

    return ScreenScaffold(
      title: tr('Festivals & events'),
      maxWidth: 900,
      body: _all == null
          ? Center(child: _failed ? Text(tr('Could not open this right now')) : const CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (_country != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InputChip(label: Text(_country!), onDeleted: () => setState(() => _country = null)),
                  )
                else
                  Wrap(spacing: 8, children: [
                    for (final w in [('all', 'All'), ('bd', 'Bangladesh'), ('world', 'Worldwide')])
                      ChoiceChip(label: Text(tr(w.$2)), selected: _where == w.$1, onSelected: (_) => setState(() => _where = w.$1)),
                  ]),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(label: Text(tr('Next 12 months')), selected: _month == null, onSelected: (_) => setState(() => _month = null)),
                    ),
                    for (var i = 0; i < 12; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('${tr(_mo[monthStarts[i].month - 1])} ${monthStarts[i].year % 100}'),
                          selected: _month == i,
                          onSelected: (_) => setState(() => _month = i),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                if (keys.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(30),
                    child: Text(tr('No festivals in this period yet.'), textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
                  ),
                for (final k in keys) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: Text('${tr(_mo[k.month - 1])} ${k.year}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  ),
                  for (final f in groups[k]!) FestivalCard(f),
                ],
                const SizedBox(height: 8),
                Text(tr('Dates marked "about" follow the moon or local calendars and can move by a day or two. Check locally before you book.'),
                    style: const TextStyle(color: C.muted, fontSize: 11.5)),
              ]),
            ),
    );
  }
}

class FestivalCard extends StatelessWidget {
  final Festival f;
  const FestivalCard(this.f, {super.key});

  IconData get _icon => switch (f.category) {
        'religious' => Icons.temple_hindu_rounded,
        'national' => Icons.flag_rounded,
        'heritage' => Icons.account_balance_rounded,
        'nature' => Icons.local_florist_rounded,
        'arts' => Icons.theater_comedy_rounded,
        'culture' => Icons.celebration_rounded,
        _ => Icons.festival_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final on = !f.starts.isAfter(today) && !f.ends.isBefore(today);
    final inDays = f.starts.difference(today).inDays;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: on ? C.primary : C.line)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text('${f.starts.day}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: C.primary)),
            Text(tr(_mo[f.starts.month - 1]), style: const TextStyle(fontSize: 11.5, color: C.muted)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_icon, size: 16, color: C.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(f.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
            ]),
            const SizedBox(height: 3),
            Text(
              [f.city, f.country].whereType<String>().join(', '),
              style: const TextStyle(color: C.muted, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _pill(f.approx ? '${tr('about')} ${festivalDates(f)}' : festivalDates(f)),
              if (on) _pill(tr('Happening now'), hot: true) else if (inDays > 0 && inDays <= 60) _pill(trf('in {0} days', [inDays])),
            ]),
            if (f.about.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(f.about, style: const TextStyle(fontSize: 12.5)),
            ],
            const SizedBox(height: 4),
            Wrap(spacing: 4, children: [
              TextButton.icon(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
                onPressed: () => _plan(context),
                icon: const Icon(Icons.map_rounded, size: 16),
                label: Text(tr('Plan a trip')),
              ),
              if (f.wiki != null)
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
                  onPressed: () => launchUrl(Uri.parse('https://en.wikipedia.org/wiki/${f.wiki}'), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(tr('Read more')),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }

  void _plan(BuildContext context) {
    final p = places.where((x) => x.id == f.placeId).toList();
    if (p.isNotEmpty) {
      go(context, PlaceDetailScreen(place: p.first));
    } else {
      go(context, SearchScreen(query: f.city ?? f.country));
    }
  }

  Widget _pill(String t, {bool hot = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: hot ? C.primary : const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(10)),
        child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: hot ? C.on : C.ink)),
      );
}

/// Small strip of upcoming festivals (used on Explore and on place pages).
class FestivalStrip extends StatefulWidget {
  final String? country;
  const FestivalStrip({super.key, this.country});
  @override
  State<FestivalStrip> createState() => _FestivalStripState();
}

class _FestivalStripState extends State<FestivalStrip> {
  List<Festival>? _list;

  @override
  void initState() {
    super.initState();
    loadFestivals(country: widget.country).then((l) => mounted ? setState(() => _list = l) : null).catchError((_) => mounted ? setState(() => _list = []) : null);
  }

  @override
  Widget build(BuildContext context) {
    final l = _list;
    if (l == null || l.isEmpty) return const SizedBox.shrink();
    if (widget.country != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(trf('Festivals in {0}', [tr(widget.country!)]), style: const TextStyle(fontWeight: FontWeight.w600))),
          TextButton(onPressed: () => go(context, FestivalsScreen(country: widget.country)), child: Text(tr('See all'))),
        ]),
        for (final f in l.take(3)) FestivalCard(f),
      ]);
    }
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: l.length.clamp(0, 12),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (c, i) {
          final f = l[i];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => go(context, const FestivalsScreen()),
            child: Container(
              width: 190,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.celebration_rounded, size: 16, color: C.primary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f.approx ? '${tr('about')} ${festivalDates(f)}' : festivalDates(f), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.primary, fontSize: 11.5, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 6),
                Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                const Spacer(),
                Text([f.city, f.country].whereType<String>().join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 11.5)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
