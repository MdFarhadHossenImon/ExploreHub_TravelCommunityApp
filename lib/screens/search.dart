import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/pull_refresh.dart';
import 'place_detail.dart';

class SearchScreen extends StatefulWidget {
  final String? category;
  final bool focus;
  const SearchScreen({super.key, this.category, this.focus = false});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  String? _cat;
  int _sort = 0; // 0 popular, 1 budget low-high, 2 rating
  String? _region;
  int _guests = 2;
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().add(const Duration(days: 14)),
    end: DateTime.now().add(const Duration(days: 17)),
  );

  static const _sorts = ['Most popular', 'Budget (Low to High)', 'Top rated'];
  static const _regions = ['Asia', 'Europe', 'Africa', 'North America', 'South America', 'Oceania'];

  @override
  void initState() {
    super.initState();
    _cat = widget.category;
  }

  List<Place> get _results {
    final q = _q.text.trim().toLowerCase();
    final list = places.where((p) {
      final okCat = _cat == null || p.category == _cat;
      final okRegion = _region == null || p.continent == _region;
      final okQ = q.isEmpty || '${p.name} ${p.location} ${p.country}'.toLowerCase().contains(q);
      return okCat && okRegion && okQ;
    }).toList();
    if (_sort == 1) {
      list.sort((a, b) => (a.dailyBudget == 0 ? 1 << 20 : a.dailyBudget).compareTo(b.dailyBudget == 0 ? 1 << 20 : b.dailyBudget));
    } else if (_sort == 2) {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return list;
  }

  Future<void> _edit() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    final res = _results;
    final wide = MediaQuery.sizeOf(context).width >= 760;
    return Scaffold(
      appBar: AppBar(
        leading: const BackCircle(),
        leadingWidth: 56,
        titleSpacing: 0,
        title: TextField(
          controller: _q,
          autofocus: widget.focus,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search here',
            prefixIcon: const Icon(Icons.search_rounded, color: C.muted),
            suffixIcon: _q.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _q.clear())),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
        actions: const [SizedBox(width: 16)],
      ),
      body: Constrained(
        child: Column(children: [
          // Trip summary card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
            child: Row(children: [
              const Icon(Icons.location_on, color: C.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Dhaka, Bangladesh', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('${fmtDate(_range.start)} to ${fmtDate(_range.end)}  ·  $_guests guests', style: const TextStyle(fontSize: 11.5, color: C.muted)),
                ]),
              ),
              TextButton.icon(onPressed: _edit, icon: const Icon(Icons.edit_calendar_rounded, size: 18), label: const Text('Edit')),
              IconButton(tooltip: 'Fewer guests', onPressed: _guests > 1 ? () => setState(() => _guests--) : null, icon: const Icon(Icons.remove_circle_outline_rounded, size: 20)),
              IconButton(tooltip: 'More guests', onPressed: () => setState(() => _guests++), icon: const Icon(Icons.add_circle_outline_rounded, size: 20)),
            ]),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final c in [null, ...categories])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c ?? 'All'),
                      selected: _cat == c,
                      selectedColor: C.primary,
                      labelStyle: TextStyle(color: _cat == c ? C.on : C.ink, fontSize: 12.5),
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _cat = c),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(children: [
              const Icon(Icons.sort_rounded, size: 20),
              const SizedBox(width: 8),
              Text('${res.length} places', style: const TextStyle(fontSize: 13)),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (v) => setState(() => _region = v.isEmpty ? null : v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: '', child: Text('Anywhere')),
                  for (final r in _regions) PopupMenuItem(value: r, child: Text(r)),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.public_rounded, size: 16, color: C.primary),
                    const SizedBox(width: 4),
                    Text(_region ?? 'Anywhere', style: const TextStyle(color: C.primary, fontSize: 13)),
                  ]),
                ),
              ),
              PopupMenuButton<int>(
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => [for (var i = 0; i < _sorts.length; i++) PopupMenuItem(value: i, child: Text(_sorts[i]))],
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_sorts[_sort], style: const TextStyle(color: C.primary, fontSize: 13)),
                ),
              ),
            ]),
          ),
          Expanded(
            child: res.isEmpty
                ? const EmptyState(Icons.travel_explore_rounded, 'No places found', 'Try another name or clear the category filter.')
                : PullRefresh(child: wide
                    ? GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 116, crossAxisSpacing: 14, mainAxisSpacing: 14),
                        itemCount: res.length,
                        itemBuilder: (c, i) => PlaceCard(res[i]),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: res.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (c, i) => SizedBox(height: 116, child: PlaceCard(res[i])),
                      )),
          ),
        ]),
      ),
    );
  }
}

/// Horizontal result card from the Figma "Search" screen.
class PlaceCard extends StatelessWidget {
  final Place p;
  const PlaceCard(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<AppState>().savedPlaces.contains(p.id);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => go(context, PlaceDetailScreen(place: p)),
      child: Container(
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
        child: Row(children: [
          AppImage(p.photo, width: 104, height: double.infinity, radius: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                  InkWell(
                    onTap: () => context.read<AppState>().toggleSavePlace(p.id),
                    child: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: C.primary, size: 22),
                  ),
                ]),
                RatingText(p.rating),
                Row(children: [
                  const Icon(Icons.location_on, color: C.primary, size: 13),
                  const SizedBox(width: 2),
                  Expanded(child: Text(p.where, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: C.muted))),
                ]),
                const Spacer(),
                Row(children: [
                  if (p.price > 0) ...[
                    Text(money(p.price), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const Text(' /person', style: TextStyle(fontSize: 11, color: C.muted)),
                  ] else if (p.dailyBudget > 0) ...[
                    Text('from \$${p.dailyBudget}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const Text(' /day', style: TextStyle(fontSize: 11, color: C.muted)),
                  ] else
                    Text(p.category, style: const TextStyle(fontSize: 12, color: C.muted)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Show More', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
