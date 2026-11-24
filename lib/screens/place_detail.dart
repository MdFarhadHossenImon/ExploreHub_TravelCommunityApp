import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../widgets/same_time.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/env.dart';
import '../data/backend.dart';
import '../data/offline.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/pull_refresh.dart';
import '../widgets/feed_video.dart';
import '../widgets/place_extras.dart';
import '../widgets/route_plan.dart';
import '../data/route_planner.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'booking_flow.dart';
import 'shell.dart';
import 'stays.dart';
import 'transport.dart';
import 'trips.dart';

const _tabs = ['About', 'How to go', 'Reviews', 'Photos', 'Videos'];

class PlaceDetailScreen extends StatefulWidget {
  final Place place;
  final int initialTab;
  const PlaceDetailScreen({super.key, required this.place, this.initialTab = 0});
  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late int _tab = widget.initialTab;
  int _page = 0;
  bool _more = false;
  late final List<Review> _reviews = Backend.on ? <Review>[] : List.of(reviewsSeed);
  late String _aboutText = widget.place.about;
  String? _history;
  bool _historyMore = false;

  Future<void> _loadHistory() async {
    String? h;
    try {
      final r = await Offline.row('hist:${widget.place.id}', () => Supabase.instance.client.from('places').select('history').eq('id', widget.place.id).maybeSingle());
      h = r?['history'] as String?;
    } catch (_) {}
    h ??= await RoutePlanner.history(widget.place);
    if (mounted && h != null && h.isNotEmpty) setState(() => _history = h);
  }

  @override
  void initState() {
    super.initState();
    if (Backend.on) _loadReviews();
    if (Backend.on) _loadHistory();
    if (Backend.on && _aboutText.isEmpty) {
      Backend.placeAbout(widget.place.id).then((t) {
        if (mounted && t != null) setState(() => _aboutText = t);
      }).catchError((_) {});
    }
  }

  Future<void> _loadReviews() async {
    try {
      final r = await Backend.reviews(p.id);
      if (!mounted) return;
      setState(() => _reviews
        ..clear()
        ..addAll(r));
    } catch (e) {
      say(errText(e));
    }
  }

  Future<void> _openMap() async {
    final url = p.mapsUrl ?? (p.lat != null ? 'https://www.google.com/maps/search/?api=1&query=${p.lat},${p.lng}' : null);
    if (url == null) return;
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) say('Could not open maps');
  }

  Place get p => widget.place;

  void _addReview() {
    final ctl = TextEditingController();
    double stars = 5;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Write a review'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => set(() => stars = i.toDouble()),
                  icon: Icon(i <= stars ? Icons.star_rounded : Icons.star_border_rounded, color: C.star, size: 30),
                ),
            ]),
            TextField(controller: ctl, maxLines: 3, decoration: InputDecoration(hintText: tr('What should other travelers know?'))),
            const SizedBox(height: 14),
            PrimaryButton('Post review', onPressed: () async {
              final text = ctl.text.trim();
              if (text.isEmpty) return;
              final who = context.read<AppState>().name.split(' ').first;
              Navigator.pop(c);
              try {
                if (Backend.on) await Backend.addReview(p.id, stars, text);
                if (mounted) setState(() => _reviews.insert(0, Review(who, stars, text, 'just now')));
              } catch (e) {
                say(errText(e));
              }
            }),
          ]),
        ),
      ),
    );
  }

  /// The place's own photo first, then photos travelers posted from here (real data when live).
  List<String> _gallery() => [
        p.photo,
        for (final post in context.read<AppState>().posts)
          if (post.placeId == p.id && !post.isVideo) post.imageSeed,
      ];

  Widget _content() {
    switch (_tab) {
      case 1:
        return _howToGo();
      case 2:
        return _reviewsTab();
      case 3:
        final shots = _gallery();
        if (shots.length <= 1) {
          return const EmptyState(Icons.photo_camera_outlined, 'No traveler photos yet', 'Check in here and share the first photo.');
        }
        return GridView.count(
          crossAxisCount: Bp.isWide(context) ? 4 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [for (final g in shots) AppImage(g, radius: 10)],
        );
      case 4:
        final vids = context.watch<AppState>().posts.where((v) => v.isVideo && v.placeId == p.id).toList();
        if (vids.isEmpty) {
          return const EmptyState(Icons.videocam_off_outlined, 'No videos yet', 'Be the first to share a video from here.');
        }
        return Column(children: [
          for (final v in vids)
            GestureDetector(
              onTap: () => openTab(context, 2),
              child: Container(
                height: 180,
                margin: const EdgeInsets.only(bottom: 12),
                child: Stack(fit: StackFit.expand, children: [
                  if (v.imageSeed.startsWith('http'))
                    mediaView(v.imageSeed, isVideo: true, radius: 16, autoplay: false)
                  else ...[
                    AppImage(v.imageSeed),
                    const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 54)),
                  ],
                  Positioned(left: 12, bottom: 10, child: Text(v.videoTitle ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
                ]),
              ),
            ),
        ]);
      default:
        return _about();
    }
  }

  Widget _about() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('About'), style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(_aboutText.isEmpty ? tr('Loading details...') : _aboutText,
            maxLines: _more ? null : 4, overflow: _more ? TextOverflow.visible : TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 13, height: 1.6)),
        GestureDetector(
          onTap: () => setState(() => _more = !_more),
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_more ? tr('Show less') : tr('Read more'), style: const TextStyle(color: C.danger, fontSize: 13)),
          ),
        ),
        if (_history != null) ...[
          const SizedBox(height: 18),
          Row(children: [
            Icon(Icons.history_edu_rounded, size: 18, color: C.primary),
            SizedBox(width: 6),
            Text(tr('History'), style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          Text(_history!, maxLines: _historyMore ? null : 6, overflow: _historyMore ? TextOverflow.visible : TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 13, height: 1.6)),
          GestureDetector(
            onTap: () => setState(() => _historyMore = !_historyMore),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_historyMore ? tr('Show less') : tr('Read the full history'), style: const TextStyle(color: C.danger, fontSize: 13)),
            ),
          ),
        ],
        if ((p.imageUrl ?? '').contains('wikimedia.org'))
          Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(tr('Cover photo: Wikimedia Commons contributors, free license (Creative Commons or public domain).'), style: TextStyle(color: C.muted, fontSize: 11)),
          ),
        if (p.wikiTitle != null && p.popularity != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              onTap: () => launchUrl(Uri.parse('https://en.wikipedia.org/wiki/${Uri.encodeComponent(p.wikiTitle!)}'), mode: LaunchMode.externalApplication),
              child: Text(tr('Text: Wikipedia (CC BY-SA). Read the full article'), style: TextStyle(color: C.primary, fontSize: 11, decoration: TextDecoration.underline)),
            ),
          ),
        if (p.dailyBudget > 0) ...[
          const SizedBox(height: 18),
          _BudgetCard(p),
        ],
        if (p.lat != null && p.lng != null) ...[
          const SizedBox(height: 18),
          Text(tr('Weather'), style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          WeatherCard(p.lat!, p.lng!),
        ],
        EssentialsCard(p.country),
        NearbyStrip(p, onOpen: (o) => go(context, PlaceDetailScreen(place: o))),
        if (p.videoUrl != null) ...[
          const SizedBox(height: 18),
          Text(tr('Watch'), style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(borderRadius: BorderRadius.circular(14), child: FeedVideo(p.videoUrl!, autoplay: false, fit: BoxFit.contain)),
          ),
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(tr('Video: Wikimedia Commons contributors, free license.'), style: TextStyle(color: C.muted, fontSize: 11)),
          ),
        ],
        const SizedBox(height: 18),
        Row(children: [
          const Icon(Icons.wb_sunny_outlined, size: 18, color: C.primary),
          const SizedBox(width: 8),
          Text(trf('Best time: {0}', [p.season]), style: const TextStyle(fontSize: 13)),
        ]),
        if (p.address != null || p.hours != null) ...[
          const SizedBox(height: 18),
          Text(tr('Location'), style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (p.address != null)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.place_outlined, size: 18, color: C.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.address!, style: const TextStyle(fontSize: 13))),
                ]),
              if (p.hours != null) ...[
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.schedule_rounded, size: 18, color: C.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.hours!, style: const TextStyle(fontSize: 13))),
                ]),
              ],
              if (p.mapsUrl != null || p.lat != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(onPressed: _openMap, icon: const Icon(Icons.map_outlined, size: 18), label: Text(tr('Open in Maps'))),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 18),
        Text(tr('Facilities'), style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in p.facilities)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded, size: 15, color: C.ok),
                const SizedBox(width: 6),
                Text(tr(f), style: const TextStyle(fontSize: 12)),
              ]),
            ),
        ]),
        const SizedBox(height: 18),
        SameTimeTravelers(place: p),
        const SizedBox(height: 18),
        Text(tr('Where to stay'), style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => go(context, StaysScreen(place: p)),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
            child: Row(children: [
              Icon(Icons.hotel_rounded, color: C.primary),
              SizedBox(width: 12),
              Expanded(child: Text(tr('Hotels, hostels and guest houses nearby'), style: TextStyle(fontSize: 13))),
              Icon(Icons.chevron_right_rounded, color: C.muted),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        Text(tr('Tour guide'), style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => go(context, GuidesScreen(country: p.country)),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
            child: Row(children: [
              Icon(Icons.badge_rounded, color: C.primary),
              SizedBox(width: 12),
              Expanded(child: Text(tr('Hire a local guide for this trip'), style: TextStyle(fontSize: 13))),
              Icon(Icons.chevron_right_rounded, color: C.muted),
            ]),
          ),
        ),
        const SizedBox(height: 24),
      ]);

  Widget _howToGo() {
    final local = p.lastDetail.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(trf('How to get to {0}', [p.name]), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      const SizedBox(height: 4),
      Text(tr('Real road route with the main towns on the way. Change the start city any time.'), style: TextStyle(color: C.muted, fontSize: 12.5)),
      const SizedBox(height: 14),
      if (p.lat != null && p.lng != null) RoutePlanView(place: p) else Text(tr('Route not available for this place yet.'), style: TextStyle(color: C.muted)),
      if (local) ...[
        const SizedBox(height: 18),
        Text(tr('Local tip for the last stretch'), style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(modeIcon(p.lastMode), color: C.primary),
            const SizedBox(width: 10),
            Expanded(child: Text('${p.lastDetail}${p.lastDuration.isNotEmpty ? '  (${p.lastDuration})' : ''}', style: const TextStyle(color: C.muted, fontSize: 12.5, height: 1.5))),
          ]),
        ),
      ],
      if (p.season.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(trf('Best time to visit: {0}', [p.season]), style: const TextStyle(color: C.muted, fontSize: 12.5)),
      ],
    ]);
  }

  Widget _reviewsTab() {
    final avg = _reviews.isEmpty ? 0.0 : _reviews.fold<double>(0, (a, r) => a + r.rating) / _reviews.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        Text(trf('{0} recent reviews', [_reviews.length]), style: const TextStyle(color: C.muted)),
        const Spacer(),
        TextButton(onPressed: _addReview, child: Text(tr('Write a review'))),
      ]),
      for (final r in _reviews)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(r.name, name: r.name, radius: 14),
              const SizedBox(width: 8),
              Text(r.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const Spacer(),
              RatingText(r.rating),
            ]),
            const SizedBox(height: 8),
            Text(r.text, style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.5)),
            const SizedBox(height: 6),
            Text(r.when, style: const TextStyle(fontSize: 11, color: C.muted)),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<AppState>().savedPlaces.contains(p.id);
    final wide = Bp.isWide(context);
    return Scaffold(
      bottomNavigationBar: Material(
        color: C.card,
        elevation: 0,
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: p.price == 0
                    ? PrimaryButton('Plan a trip here', icon: Icons.map_rounded, onPressed: () => go(context, const CreateTripScreen()))
                    : PrimaryButton(trf('Book a Trip  ·  {0}/person', [money(p.price)]),
                        onPressed: () => go(context, BookingFlowScreen(draft: BookingDraft(title: p.name, location: p.where, type: 'tour', seed: p.id, unitPrice: p.price)))),
              ),
            ),
          ),
        ),
      ),
      body: PullRefresh(
          child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: wide ? 380 : 320,
          backgroundColor: C.bg,
          leading: const BackCircle(),
          leadingWidth: 56,
          actions: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: RoundIconButton(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, () => context.read<AppState>().toggleSavePlace(p.id), size: 38),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(24),
            child: Container(
              height: 24,
              decoration: const BoxDecoration(color: C.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Stack(fit: StackFit.expand, children: [
              PageView.builder(
                itemCount: _gallery().take(6).length,
                onPageChanged: (v) => setState(() => _page = v),
                itemBuilder: (c, i) => AppImage(_gallery()[i], radius: 0),
              ),
              Positioned(
                right: 16,
                bottom: 42,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0x99132625), borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.photo_library_outlined, size: 13, color: Colors.white),
                    const SizedBox(width: 5),
                    Text('${_page + 1}/${_gallery().take(6).length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              Positioned(
                bottom: 36,
                left: 0,
                right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 4; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(color: i == _page ? C.primary : Colors.white54, borderRadius: BorderRadius.circular(3)),
                    ),
                ]),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Constrained(
            maxWidth: 760,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(p.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600))),
                  if (p.price > 0)
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(p.price), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                      Text(tr('per person'), style: TextStyle(fontSize: 11, color: C.muted)),
                    ]),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on, color: C.primary, size: 16),
                  const SizedBox(width: 3),
                  Text(p.where, style: const TextStyle(color: C.muted, fontSize: 12.5)),
                ]),
                const SizedBox(height: 6),
                RatingText(p.rating, reviews: p.reviews),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (var i = 0; i < _tabs.length; i++)
                      InkWell(
                        onTap: () => setState(() => _tab = i),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                          margin: const EdgeInsets.only(right: 22),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == _tab ? C.primary : Colors.transparent, width: 2))),
                          child: Text(tr(_tabs[i]), style: TextStyle(fontWeight: i == _tab ? FontWeight.w600 : FontWeight.w400, color: i == _tab ? C.primary : C.muted)),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 16),
                _content(),
                const SizedBox(height: 12),
              ]),
            ),
          ),
        ),
      ])),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Place p;
  const _BudgetCard(this.p);

  @override
  Widget build(BuildContext context) {
    final low = p.budgetLow ?? p.dailyBudget;
    final high = p.budgetHigh ?? (low * 3);
    final mid = ((low + high) / 2).round();
    Widget tier(String name, IconData icon, int v, String what) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 20, color: C.primary),
              const SizedBox(height: 6),
              Text(tr(name), style: const TextStyle(fontSize: 12, color: C.muted)),
              Text('\$$v', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text(tr(what), style: const TextStyle(fontSize: 10.5, color: C.muted, height: 1.3)),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('Daily budget per person'), style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: [
        tier('Backpacker', Icons.backpack_outlined, low, 'Hostel, street food, buses'),
        const SizedBox(width: 8),
        tier('Mid-range', Icons.hotel_outlined, mid, 'Hotel, restaurants, taxis'),
        const SizedBox(width: 8),
        tier('Comfort', Icons.diamond_outlined, high, 'Upscale stay, tours, car'),
      ]),
      const SizedBox(height: 6),
      Text(trf('Estimated in US dollars from typical costs in {0}. Entry tickets and flights are extra.', [p.country]), style: const TextStyle(fontSize: 11, color: C.muted)),
    ]);
  }
}
