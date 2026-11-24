import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/env.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/route_planner.dart';
import '../screens/transport.dart';
import '../state/app_state.dart';
import 'common.dart';

String _dur(num min) {
  final m = min.round();
  if (m < 60) return '$m min';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '${h}h' : '${h}h ${r}m';
}

String _km(num k) => k >= 1000 ? '${(k / 1000).toStringAsFixed(1)}k km' : '$k km';

/// Step-by-step route from the traveler's city to a place, drawn as a linked list:
/// stop → leg → stop → leg → ... → destination.
class RoutePlanView extends StatefulWidget {
  final Place place;
  const RoutePlanView({super.key, required this.place});
  @override
  State<RoutePlanView> createState() => _RoutePlanViewState();
}

class _RoutePlanViewState extends State<RoutePlanView> {
  Origin? _origin;
  List<PlanItem>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final home = context.read<AppState>().home;
    final o = Env.configured ? await RoutePlanner.homeOrigin(home) : Origin.dhaka;
    await _load(o);
  }

  Future<void> _load(Origin o) async {
    setState(() {
      _origin = o;
      _items = null;
      _failed = false;
    });
    try {
      final items = Env.configured ? await RoutePlanner.plan(o, widget.place) : _demo(o);
      if (mounted && _origin == o) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  List<PlanItem> _demo(Origin o) => [
        {'t': 'stop', 'name': 'Chattogram', 'sub': 'Bangladesh', 'kind': 'start'},
        {
          't': 'leg',
          'mode': 'bus',
          'km': 92,
          'min': 140,
          'car': 98,
          'roads': ['N1']
        },
        {'t': 'stop', 'name': 'Feni', 'sub': '92 km from start', 'kind': 'town'},
        {
          't': 'leg',
          'mode': 'bus',
          'km': 58,
          'min': 85,
          'car': 58,
          'roads': ['N1']
        },
        {'t': 'stop', 'name': 'Cumilla', 'sub': '150 km from start', 'kind': 'town'},
        {
          't': 'leg',
          'mode': 'bus',
          'km': 90,
          'min': 135,
          'car': 92,
          'roads': ['N1']
        },
        {'t': 'stop', 'name': widget.place.name, 'sub': widget.place.where, 'kind': 'end'},
      ];

  Future<void> _pickOrigin() async {
    final o = await showModalBottomSheet<Origin>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: const _OriginPicker(),
      ),
    );
    if (o != null) _load(o);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
        child: Row(children: [
          const Icon(Icons.trip_origin_rounded, color: Color(0xFF2EB67D), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(TextSpan(children: [
              const TextSpan(text: 'Starting from  ', style: TextStyle(color: C.muted, fontSize: 12.5)),
              TextSpan(text: _origin?.name ?? '...', style: const TextStyle(fontWeight: FontWeight.w700)),
            ])),
          ),
          TextButton.icon(onPressed: _pickOrigin, icon: const Icon(Icons.edit_location_alt_rounded, size: 18), label: const Text('Change')),
        ]),
      ),
      const SizedBox(height: 14),
      if (_failed)
        const Text('Could not build the route right now. Pull down to try again later.', style: TextStyle(color: C.muted))
      else if (items == null)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(children: [
              CircularProgressIndicator(color: C.primary),
              SizedBox(height: 10),
              Text('Finding the road and the towns on the way...', style: TextStyle(color: C.muted, fontSize: 12)),
            ]),
          ),
        )
      else ...[
        _Summary(items),
        const SizedBox(height: 14),
        for (var i = 0; i < items.length; i++) items[i]['t'] == 'stop'
              ? _StopNode(items[i], first: i == 0, last: i == items.length - 1)
              : _LegEdge(items[i], place: widget.place, showTickets: items.indexWhere((e) => e['t'] == 'leg' && e['mode'] == items[i]['mode']) == i),
        const SizedBox(height: 10),
        const Text('Road distances and driving times: OpenStreetMap (OSRM). Bus time is an estimate with stops; flight time is from the distance.', style: TextStyle(color: C.muted, fontSize: 10.5)),
      ],
    ]);
  }
}

class _Summary extends StatelessWidget {
  final List<PlanItem> items;
  const _Summary(this.items);
  @override
  Widget build(BuildContext context) {
    final legs = items.where((e) => e['t'] == 'leg');
    final km = legs.fold<num>(0, (a, e) => a + (e['km'] as num));
    final min = legs.fold<num>(0, (a, e) => a + (e['min'] as num));
    final flight = legs.any((e) => e['mode'] == 'flight');
    final stops = items.where((e) => e['t'] == 'stop' && e['kind'] == 'town').length;
    Widget tile(IconData i, String big, String small) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(color: C.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(14), border: Border.all(color: C.primary.withValues(alpha: .35))),
            child: Column(children: [
              Icon(i, color: C.primary, size: 20),
              const SizedBox(height: 4),
              Text(big, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(small, style: const TextStyle(color: C.muted, fontSize: 11)),
            ]),
          ),
        );
    return Row(children: [
      tile(Icons.schedule_rounded, _dur(min), flight ? 'total travel' : 'by bus'),
      const SizedBox(width: 8),
      tile(Icons.straighten_rounded, _km(km.round()), 'distance'),
      const SizedBox(width: 8),
      tile(flight ? Icons.flight_rounded : Icons.location_city_rounded, flight ? 'Flight' : '$stops', flight ? 'needed' : 'towns on the way'),
    ]);
  }
}

class _StopNode extends StatelessWidget {
  final PlanItem s;
  final bool first, last;
  const _StopNode(this.s, {required this.first, required this.last});
  @override
  Widget build(BuildContext context) {
    final kind = s['kind'] as String;
    final big = kind != 'town';
    final Widget dot = switch (kind) {
      'start' => Container(width: 22, height: 22, decoration: BoxDecoration(color: const Color(0xFF2EB67D), shape: BoxShape.circle, border: Border.all(color: C.bg, width: 3))),
      'end' => const Icon(Icons.location_on_rounded, color: Color(0xFFE5534B), size: 28),
      'airport' => Container(
          width: 26, height: 26, decoration: const BoxDecoration(color: Color(0xFF5B8DEF), shape: BoxShape.circle), child: const Icon(Icons.local_airport_rounded, size: 15, color: Colors.white)),
      _ => Container(width: 14, height: 14, decoration: BoxDecoration(color: C.bg, shape: BoxShape.circle, border: Border.all(color: C.primary, width: 3))),
    };
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 40,
          child: Column(children: [
            Expanded(child: first ? const SizedBox() : Center(child: Container(width: 3, color: C.primary.withValues(alpha: .5)))),
            dot,
            Expanded(child: last ? const SizedBox() : Center(child: Container(width: 3, color: C.primary.withValues(alpha: .5)))),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: big ? 8 : 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(s['name'] as String, style: TextStyle(fontWeight: big ? FontWeight.w800 : FontWeight.w600, fontSize: big ? 15 : 13.5)),
              if ((s['sub'] as String? ?? '').isNotEmpty) Text(s['sub'] as String, style: const TextStyle(color: C.muted, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _LegEdge extends StatelessWidget {
  final PlanItem l;
  final Place place;
  final bool showTickets;
  const _LegEdge(this.l, {required this.place, this.showTickets = true});
  @override
  Widget build(BuildContext context) {
    final mode = l['mode'] as String;
    final roads = List<String>.from(l['roads'] as List? ?? const []);
    final (IconData icon, String label) = switch (mode) {
      'flight' => (Icons.flight_rounded, 'Flight'),
      'drive' => (Icons.directions_car_rounded, 'Taxi or car'),
      'local' => (Icons.directions_walk_rounded, 'Local transfer'),
      _ => (Icons.directions_bus_rounded, 'Bus'),
    };
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 40,
          child: Center(
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: mode == 'flight' ? const Color(0xFF5B8DEF) : C.primary.withValues(alpha: .5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 18, color: mode == 'flight' ? const Color(0xFF5B8DEF) : C.primary),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('≈ ${_dur(l['min'] as num)}', style: const TextStyle(fontWeight: FontWeight.w800, color: C.primary)),
              ]),
              const SizedBox(height: 4),
              Text(
                [
                  _km(l['km'] as num),
                  if (roads.isNotEmpty) 'via ${roads.join(', ')}',
                  if (l['car'] != null) 'by car ≈ ${_dur(l['car'] as num)}',
                ].join('  ·  '),
                style: const TextStyle(color: C.muted, fontSize: 11.5),
              ),
              if (showTickets && (mode == 'flight' || mode == 'bus')) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10)),
                    onPressed: () => go(context, TransportScreen(type: mode == 'flight' ? 'flight' : 'bus', to: mode == 'flight' ? (l['to'] as String?) : place.hub)),
                    icon: Icon(mode == 'flight' ? Icons.flight_rounded : Icons.confirmation_number_rounded, size: 15),
                    label: Text(mode == 'flight' ? 'Find flights' : 'Buses & trains', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _OriginPicker extends StatefulWidget {
  const _OriginPicker();
  @override
  State<_OriginPicker> createState() => _OriginPickerState();
}

class _OriginPickerState extends State<_OriginPicker> {
  List<Origin> _res = const [];
  String _q = '';

  Future<void> _search(String q) async {
    _q = q;
    if (!Env.configured) {
      const demo = [Origin('Dhaka', 'Bangladesh', 23.725, 90.407), Origin('Chattogram', 'Bangladesh', 22.332, 91.798), Origin('Sylhet', 'Bangladesh', 24.904, 91.874)];
      setState(() => _res = demo.where((o) => o.name.toLowerCase().startsWith(q.toLowerCase())).toList());
      return;
    }
    final r = await RoutePlanner.searchCities(q);
    if (mounted && _q == q) setState(() => _res = r);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SizedBox(
          height: 460,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Where do you start from?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(autofocus: true, onChanged: _search, decoration: const InputDecoration(hintText: 'Type a city, e.g. Chattogram', prefixIcon: Icon(Icons.search_rounded))),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(children: [
                  for (final o in _res)
                    ListTile(
                      leading: const Icon(Icons.location_city_rounded, color: C.primary),
                      title: Text(o.name),
                      subtitle: Text(o.country),
                      onTap: () => Navigator.pop(context, o),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      );
}
