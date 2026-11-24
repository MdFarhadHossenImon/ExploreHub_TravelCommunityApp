import 'package:flutter/material.dart';
import '../core/i18n.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../data/backend.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../widgets/common.dart';

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<void> openLink(BuildContext context, String url) async {
  if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) && context.mounted) toast(context, tr('Could not open the link'));
}

/// Real hotels, hostels and guest houses near a destination (OpenStreetMap data),
/// with call / website / map actions and a price check on Booking.com.
class StaysScreen extends StatefulWidget {
  final Place? place;
  const StaysScreen({super.key, this.place});
  @override
  State<StaysScreen> createState() => _StaysScreenState();
}

class _StaysScreenState extends State<StaysScreen> {
  Place? _place;
  List<Stay>? _stays;
  String? _error;
  String _kind = '';
  DateTime _in = DateTime.now().add(const Duration(days: 7));
  DateTime _out = DateTime.now().add(const Duration(days: 9));
  int _guests = 2;

  @override
  void initState() {
    super.initState();
    if (widget.place != null) _pick(widget.place!);
  }

  Future<void> _pick(Place p) async {
    setState(() {
      _place = p;
      _stays = null;
      _error = null;
      _kind = '';
    });
    try {
      final list = Backend.on ? await Backend.stays(p) : _demo(p);
      if (mounted && _place?.id == p.id) setState(() => _stays = list);
    } catch (e) {
      if (mounted) setState(() => _error = 'The map service is busy right now. Pull to retry in a moment.');
    }
  }

  List<Stay> _demo(Place p) => [
        Stay(
            id: 'd1',
            name: 'Seagull Hotel',
            kind: 'hotel',
            stars: 4,
            distanceKm: .6,
            lat: p.lat ?? 0,
            lng: p.lng ?? 0,
            address: 'Hotel Motel Zone',
            phone: '+880 1234 567890',
            website: 'https://example.com'),
        Stay(id: 'd2', name: 'Backpackers Hostel', kind: 'hostel', distanceKm: 1.2, lat: p.lat ?? 0, lng: p.lng ?? 0),
        Stay(id: 'd3', name: 'Ocean View Guest House', kind: 'guest_house', distanceKm: 2.4, lat: p.lat ?? 0, lng: p.lng ?? 0, phone: '+880 1555 000000'),
        Stay(id: 'd4', name: 'Sea Pearl Resort', kind: 'resort', stars: 5, distanceKm: 8.9, lat: p.lat ?? 0, lng: p.lng ?? 0, website: 'https://example.com'),
      ];

  String _bookingUrl(String query) => Uri.https('www.booking.com', '/searchresults.html', {
        'ss': query,
        'checkin': _ymd(_in),
        'checkout': _ymd(_out),
        'group_adults': '$_guests',
        'no_rooms': '1',
      }).toString();

  Future<void> _dates() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 500)),
      initialDateRange: DateTimeRange(start: _in, end: _out),
    );
    if (r != null) {
      setState(() {
        _in = r.start;
        _out = r.end.isAfter(r.start) ? r.end : r.start.add(const Duration(days: 1));
      });
    }
  }

  Widget _destination() => Autocomplete<Place>(
        displayStringForOption: (p) => '${p.name}, ${p.country}',
        optionsBuilder: (v) {
          final q = v.text.trim().toLowerCase();
          if (q.length < 2) return const Iterable<Place>.empty();
          return places.where((p) => p.name.toLowerCase().contains(q) || p.location.toLowerCase().contains(q) || p.country.toLowerCase().startsWith(q)).take(12);
        },
        onSelected: (p) {
          FocusScope.of(context).unfocus();
          _pick(p);
        },
        fieldViewBuilder: (context, ctl, focus, submit) => TextField(
          controller: ctl,
          focusNode: focus,
          decoration: InputDecoration(
            hintText: _place == null ? tr('Where are you staying? e.g. Cox\'s Bazar') : '${_place!.name}, ${_place!.country}',
            prefixIcon: const Icon(Icons.place_outlined),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final kinds = <String>{for (final s in _stays ?? const <Stay>[]) s.kind};
    final shown = (_stays ?? const <Stay>[]).where((s) => _kind.isEmpty || s.kind == _kind).toList();
    final nights = _out.difference(_in).inDays;
    return ScreenScaffold(
      title: tr('Hotels & stays'),
      body: RefreshIndicator(
        color: C.primary,
        onRefresh: () async {
          if (_place != null) await _pick(_place!);
        },
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
            child: Column(children: [
              _destination(),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _dates,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
                      child: Row(children: [
                        const Icon(Icons.date_range_rounded, color: C.muted, size: 19),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${fmtDate(_in)} – ${fmtDate(_out)}  ·  $nights night${nights == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
                  child: Row(children: [
                    IconButton(visualDensity: VisualDensity.compact, onPressed: _guests > 1 ? () => setState(() => _guests--) : null, icon: const Icon(Icons.remove_rounded, size: 18)),
                    Text('$_guests', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Icon(Icons.person_rounded, size: 16, color: C.muted),
                    IconButton(visualDensity: VisualDensity.compact, onPressed: _guests < 12 ? () => setState(() => _guests++) : null, icon: const Icon(Icons.add_rounded, size: 18)),
                  ]),
                ),
              ]),
              if (_place != null) ...[
                const SizedBox(height: 12),
                PrimaryButton('Compare prices on Booking.com',
                    icon: Icons.open_in_new_rounded, onPressed: () => openLink(context, _bookingUrl('${_place!.location.isEmpty ? _place!.name : _place!.location}, ${_place!.country}'))),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          if (_place == null)
            const EmptyState(Icons.hotel_rounded, 'Find a place to stay', 'Pick a destination to see real hotels, hostels and guest houses nearby, with phone numbers and websites.')
          else if (_error != null)
            EmptyState(Icons.cloud_off_rounded, 'Could not load stays', _error!)
          else if (_stays == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: C.primary)))
          else if (_stays!.isEmpty)
            const EmptyState(Icons.hotel_rounded, 'No listed stays nearby', 'Nothing is mapped near this spot yet. Use "Compare prices" above to search hotels in the area.')
          else ...[
            Row(children: [
              Text(trf('{0} places to stay', [_stays!.length]), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              Text(tr('near the destination'), style: TextStyle(color: C.muted, fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            if (kinds.length > 1)
              SizedBox(
                height: 38,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final k in ['', ...kinds])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(k.isEmpty ? tr('All') : Stay(id: '', name: '', kind: k, lat: 0, lng: 0).kindLabel),
                        selected: _kind == k,
                        onSelected: (_) => setState(() => _kind = k),
                      ),
                    ),
                ]),
              ),
            const SizedBox(height: 10),
            for (final s in shown) _StayCard(s, bookingUrl: _bookingUrl('${s.name}, ${_place!.location.isEmpty ? _place!.country : _place!.location}')),
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(tr('Listings © OpenStreetMap contributors. Prices and availability come from the booking site.'), style: TextStyle(color: C.muted, fontSize: 11)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _StayCard extends StatelessWidget {
  final Stay s;
  final String bookingUrl;
  const _StayCard(this.s, {required this.bookingUrl});

  IconData get _icon => switch (s.kind) {
        'hostel' => Icons.bed_rounded,
        'guest_house' => Icons.house_rounded,
        'resort' => Icons.pool_rounded,
        'camp_site' => Icons.cabin_rounded,
        'apartment' => Icons.apartment_rounded,
        _ => Icons.hotel_rounded,
      };

  @override
  Widget build(BuildContext context) {
    Widget act(IconData i, String label, String url) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10), side: const BorderSide(color: C.line)),
            onPressed: () => openLink(context, url),
            icon: Icon(i, size: 16),
            label: Text(tr(label), style: const TextStyle(fontSize: 12.5)),
          ),
        );
    final web = s.website == null ? null : (s.website!.startsWith('http') ? s.website! : 'https://${s.website}');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: C.primary.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
            child: Icon(_icon, color: C.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 3),
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(s.kindLabel, style: const TextStyle(color: C.muted, fontSize: 12)),
                if (s.stars != null) Text('★' * s.stars!.round(), style: const TextStyle(color: Color(0xFFFFC107), fontSize: 12)),
                if (s.distanceKm != null) Text('${s.distanceKm! < 1 ? '${(s.distanceKm! * 1000).round()} m' : '${s.distanceKm} km'} away', style: const TextStyle(color: C.muted, fontSize: 12)),
              ]),
              if (s.address != null) ...[
                const SizedBox(height: 3),
                Text(s.address!, style: const TextStyle(color: C.muted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            SizedBox(
              height: 34,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.primary, padding: const EdgeInsets.symmetric(horizontal: 14)),
                onPressed: () => openLink(context, bookingUrl),
                child: Text(tr('Check price'), style: TextStyle(fontSize: 12.5)),
              ),
            ),
            const SizedBox(width: 8),
            if (s.phone != null) act(Icons.call_rounded, tr('Call'), 'tel:${s.phone!.split(';').first.replaceAll(' ', '')}'),
            if (web != null) act(Icons.language_rounded, tr('Website'), web),
            act(Icons.map_rounded, tr('Map'), 'https://www.google.com/maps/search/?api=1&query=${s.lat},${s.lng}'),
          ]),
        ),
      ]),
    );
  }
}
