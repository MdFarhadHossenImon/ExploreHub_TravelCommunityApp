import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'notifications.dart';
import 'place_detail.dart';
import 'search.dart';
import 'shell.dart';
import 'transport.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _cat = 'All';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final wide = Bp.isWide(context);
    final videos = s.posts.where((p) => p.isVideo).toList();
    final chips = ['All', 'Bangladesh', ...categories];
    final list = places.where((p) {
      if (_cat == 'All') return true;
      if (_cat == 'Bangladesh') return p.country == 'Bangladesh';
      return p.category == _cat;
    }).toList();

    return Scaffold(
      body: SingleChildScrollView(
        child: Constrained(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Header(unread: s.unread, name: s.name, wide: wide),

            // Services marketplace
            const SectionHeader('Book everything for your trip'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                _Service(Icons.apartment_rounded, 'Hotel', () => go(context, const SearchScreen())),
                _Service(Icons.flight_rounded, 'Flight', () => go(context, const TransportScreen(type: 'flight'))),
                _Service(Icons.train_rounded, 'Train', () => go(context, const TransportScreen(type: 'train'))),
                _Service(Icons.directions_bus_rounded, 'Bus', () => go(context, const TransportScreen(type: 'bus'))),
                _Service(Icons.badge_rounded, 'Guide', () => go(context, const GuidesScreen())),
              ]),
            ),

            // Explore places: filter chips + big photo cards
            SectionHeader('Explore places', onSeeAll: () => go(context, const SearchScreen())),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: chips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (c, i) {
                  final on = chips[i] == _cat;
                  return GestureDetector(
                    onTap: () => setState(() => _cat = chips[i]),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: on ? C.primary : C.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: on ? C.primary : C.line),
                      ),
                      child: Text(chips[i], style: TextStyle(color: on ? C.on : C.muted, fontWeight: on ? FontWeight.w700 : FontWeight.w500, fontSize: 12.5)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            if (list.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: EmptyState(Icons.search_off_rounded, 'No places here yet', 'Try another category.'))
            else
              for (final p in list) _PlaceCard(p),

            // Watch to explore
            SectionHeader('Watch & explore', onSeeAll: () => shellTab.value = 2),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: videos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (c, i) {
                  final v = videos[i];
                  return GestureDetector(
                    onTap: () => shellTab.value = 2,
                    child: SizedBox(
                      width: 240,
                      child: Stack(fit: StackFit.expand, children: [
                        AppImage(v.imageSeed, radius: 20),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            gradient: LinearGradient(colors: [Colors.transparent, Color(0xCC0A1A19)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                          ),
                        ),
                        const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 44)),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 10,
                          child: Text(v.videoTitle ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),

            // Events
            if (!Backend.on) SectionHeader('Top Events', onSeeAll: () => go(context, const SearchScreen())),
            if (!Backend.on)
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (c, i) {
                  final e = events[i];
                  final p = placeById(e.placeId);
                  return GestureDetector(
                    onTap: () => go(context, PlaceDetailScreen(place: p)),
                    child: SizedBox(
                      width: 140,
                      child: Stack(fit: StackFit.expand, children: [
                        AppImage(p.photo, radius: 20),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            gradient: LinearGradient(colors: [Colors.transparent, Color(0xCC0A1A19)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 8,
                          child: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),

            // Share CTA
            Padding(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => shellTab.value = 0,
                child: Ink(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: C.primary),
                  child: const Row(children: [
                    Icon(Icons.camera_alt_rounded, color: C.on, size: 30),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text('Back from a trip? Share your photos and videos with the community.',
                          style: TextStyle(color: C.on, fontWeight: FontWeight.w700, height: 1.4)),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int unread;
  final String name;
  final bool wide;
  const _Header({required this.unread, required this.name, required this.wide});

  @override
  Widget build(BuildContext context) {
    final first = name.trim().isEmpty ? 'Traveler' : name.split(' ').first;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: C.primary, width: 2))),
              child: Avatar(context.read<AppState>().avatarSeed, name: name, radius: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Welcome', style: TextStyle(color: C.muted, fontSize: 11.5)),
                Text(first, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ]),
            ),
            Stack(clipBehavior: Clip.none, children: [
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => go(context, const NotificationsScreen()),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
                  child: const Icon(Icons.notifications_none_rounded, size: 20),
                ),
              ),
              if (unread > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: C.danger, shape: BoxShape.circle),
                    child: Text('$unread', style: const TextStyle(color: C.on, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ]),
          const SizedBox(height: 22),
          const Text('Where to next?', style: TextStyle(color: C.primary, fontSize: 25, fontWeight: FontWeight.w800, height: 1.15)),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => go(context, const SearchScreen(focus: true)),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
              child: Row(children: [
                const Icon(Icons.search_rounded, color: C.muted, size: 18),
                const SizedBox(width: 10),
                const Expanded(child: Text('Search places, hotels, guides', style: TextStyle(color: C.muted, fontSize: 13))),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.search_rounded, color: C.on, size: 20),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Service extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Service(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(13)),
                  child: Icon(icon, color: C.primary, size: 22),
                ),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 11.5)),
              ]),
            ),
          ),
        ),
      );
}

class _PlaceCard extends StatelessWidget {
  final Place p;
  const _PlaceCard(this.p);

  Widget _tag(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: const Color(0x99132625), borderRadius: BorderRadius.circular(12)),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<AppState>().savedPlaces.contains(p.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: GestureDetector(
        onTap: () => go(context, PlaceDetailScreen(place: p)),
        child: SizedBox(
          height: 218,
          child: Stack(fit: StackFit.expand, children: [
            AppImage(p.photo, radius: 26),
            const DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(26)),
                gradient: LinearGradient(
                  colors: [Color(0x40102826), Color(0x1A102826), Color(0xE00A1A19)],
                  stops: [0, .35, 1],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 14,
              child: Row(children: [
                _tag(Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded, color: C.star, size: 13),
                  const SizedBox(width: 4),
                  Text('${p.rating}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ])),
                const SizedBox(width: 6),
                _tag(Text(p.category, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500))),
              ]),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: RoundIconButton(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  () => context.read<AppState>().toggleSavePlace(p.id), size: 34),
            ),
            Positioned(
              left: 16,
              right: 64,
              bottom: 16,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                _tag(Text(money(p.price), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
                const SizedBox(height: 8),
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on, color: Colors.white70, size: 13),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text('${p.location}, ${p.country}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                ]),
              ]),
            ),
            Positioned(
              right: 14,
              bottom: 16,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.arrow_outward_rounded, color: C.on, size: 20),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
