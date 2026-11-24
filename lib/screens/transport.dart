import 'dart:math';

import 'package:flutter/material.dart';
import '../core/i18n.dart';

import '../core/theme.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'stays.dart' show openLink;

export 'guides.dart';

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _slug(String s) => s.trim().replaceAll("'", '').replaceAll(RegExp(r'\s+'), '-');

double _km(double a, double b, double c, double d) {
  const r = pi / 180;
  final x = pow(sin((c - a) * r / 2), 2) + cos(a * r) * cos(c * r) * pow(sin((d - b) * r / 2), 2);
  return 12742 * asin(sqrt(x));
}

// Small offline sets so the preview build (no backend) still shows the screens.
const _demoAirports = [
  Airport('DAC', 'Hazrat Shahjalal International Airport', 'Dhaka', 'BD', 23.8433, 90.3978),
  Airport('CXB', "Cox's Bazar Airport", "Cox's Bazar", 'BD', 21.4522, 91.9639),
  Airport('CGP', 'Shah Amanat International Airport', 'Chattogram', 'BD', 22.2496, 91.8133),
  Airport('ZYL', 'Osmani International Airport', 'Sylhet', 'BD', 24.9632, 91.8668),
  Airport('KTM', 'Tribhuvan International Airport', 'Kathmandu', 'NP', 27.6966, 85.3591),
  Airport('BKK', 'Suvarnabhumi Airport', 'Bangkok', 'TH', 13.6811, 100.7473),
  Airport('DXB', 'Dubai International Airport', 'Dubai', 'AE', 25.2528, 55.3644),
];
const _demoTrains = [
  Train('701/702', 'Suborno Express', 'Dhaka', 'Chattogram', [], 'Non-stop intercity'),
  Train('703/704', 'Mohanagar Godhuli / Provati', 'Dhaka', 'Chattogram', ['Bhairab Bazar', 'Brahmanbaria', 'Akhaura', 'Cumilla', 'Feni'], null),
  Train('813/814', "Cox's Bazar Express", 'Dhaka', "Cox's Bazar", ['Chattogram'], null),
  Train('815/816', 'Parjatak Express', 'Dhaka', "Cox's Bazar", ['Chattogram'], null),
  Train('709/710', 'Parabat Express', 'Dhaka', 'Sylhet', ['Bhairab Bazar', 'Brahmanbaria', 'Srimangal'], null),
];
const _demoBuses = [
  BusOperator('Green Line Paribahan', ['Dhaka', 'Chattogram', "Cox's Bazar", 'Sylhet', 'Khulna'], true, 'https://greenlinebd.com'),
  BusOperator('Hanif Enterprise', ['Dhaka', 'Chattogram', "Cox's Bazar", 'Sylhet', 'Rajshahi', 'Rangpur'], false, null),
  BusOperator('Shyamoli Paribahan', ['Dhaka', 'Chattogram', "Cox's Bazar", 'Sylhet', 'Kolkata'], false, null),
];

class TransportScreen extends StatelessWidget {
  final String type;
  final String? to;
  const TransportScreen({super.key, required this.type, this.to});

  @override
  Widget build(BuildContext context) => ScreenScaffold(
        title: type == 'flight'
            ? 'Flights'
            : type == 'train'
                ? 'Train tickets'
                : 'Bus tickets',
        body: type == 'flight' ? _FlightSearch(to: to) : _GroundSearch(type: type, to: to),
      );
}

Widget _card({required Widget child, EdgeInsets margin = EdgeInsets.zero}) => Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
      child: child,
    );

Widget _linkButton(BuildContext context, String label, String url, {bool primary = false, IconData icon = Icons.open_in_new_rounded}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: primary
            ? FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: C.primary), onPressed: () => openLink(context, url), icon: Icon(icon, size: 18), label: Text(tr(label)))
            : OutlinedButton.icon(style: OutlinedButton.styleFrom(side: const BorderSide(color: C.line)), onPressed: () => openLink(context, url), icon: Icon(icon, size: 18), label: Text(tr(label))),
      ),
    );

Widget _dateField(BuildContext context, DateTime d, ValueChanged<DateTime> on) => InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final r = await showDatePicker(context: context, initialDate: d, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
        if (r != null) on(r);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
        child: Row(children: [
          const Icon(Icons.calendar_month_rounded, color: C.muted, size: 20),
          const SizedBox(width: 10),
          Text(fmtDate(d)),
        ]),
      ),
    );

// ---------------------------------------------------------------- flights

class _FlightSearch extends StatefulWidget {
  final String? to;
  const _FlightSearch({this.to});
  @override
  State<_FlightSearch> createState() => _FlightSearchState();
}

class _FlightSearchState extends State<_FlightSearch> {
  Airport? _from, _to;
  DateTime _date = DateTime.now().add(const Duration(days: 14));
  int _pax = 1;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final home = await _find('DAC');
    final dest = widget.to == null ? null : await _find(widget.to!);
    if (!mounted) return;
    setState(() {
      _from = home;
      _to = dest?.iata == home?.iata ? null : dest;
    });
  }

  Future<Airport?> _find(String q) async {
    final r = await _search(q);
    return r.isEmpty ? null : r.first;
  }

  Future<List<Airport>> _search(String q) async {
    if (!Backend.on) {
      final t = q.toLowerCase();
      return _demoAirports.where((a) => a.iata.toLowerCase() == t || a.city.toLowerCase().startsWith(t) || a.name.toLowerCase().contains(t)).toList();
    }
    try {
      return await Backend.airports(q);
    } catch (_) {
      return const [];
    }
  }

  Widget _airportField(String label, Airport? v, ValueChanged<Airport> on) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr(label), style: const TextStyle(fontSize: 12, color: C.muted)),
        const SizedBox(height: 4),
        Autocomplete<Airport>(
          key: ValueKey('$label-${v?.iata}'),
          initialValue: TextEditingValue(text: v?.label ?? ''),
          displayStringForOption: (a) => a.label,
          optionsBuilder: (t) async => t.text.trim().length < 2 ? const <Airport>[] : await _search(t.text),
          optionsViewBuilder: (context, select, opts) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: C.card,
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300, maxWidth: 420),
                child: ListView(padding: EdgeInsets.zero, shrinkWrap: true, children: [
                  for (final a in opts)
                    ListTile(
                      dense: true,
                      leading: Text(a.iata, style: const TextStyle(fontWeight: FontWeight.w800, color: C.primary)),
                      title: Text(a.city.isEmpty ? a.name : a.city),
                      subtitle: Text('${a.name} · ${a.country}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                      onTap: () => select(a),
                    ),
                ]),
              ),
            ),
          ),
          onSelected: (a) => setState(() {
            on(a);
            _searched = false;
          }),
          fieldViewBuilder: (context, ctl, focus, submit) => TextField(
            controller: ctl,
            focusNode: focus,
            decoration: InputDecoration(hintText: tr('City or airport code'), prefixIcon: Icon(Icons.local_airport_rounded), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final ok = _from != null && _to != null && _from!.iata != _to!.iata;
    final dist = ok ? _km(_from!.lat, _from!.lng, _to!.lat, _to!.lng) : 0.0;
    final mins = (dist / 780 * 60 + 35).round();
    final d = _ymd(_date);
    final yymmdd = d.substring(2).replaceAll('-', '');
    return ListView(padding: const EdgeInsets.all(16), children: [
      _card(
        child: Column(children: [
          _airportField('From', _from, (a) => _from = a),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: tr('Swap'),
              onPressed: () => setState(() {
                final x = _from;
                _from = _to;
                _to = x;
              }),
              icon: const Icon(Icons.swap_vert_rounded, color: C.primary),
            ),
          ),
          _airportField('To', _to, (a) => _to = a),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _dateField(context, _date, (x) => setState(() => _date = x))),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
              child: Row(children: [
                IconButton(visualDensity: VisualDensity.compact, onPressed: _pax > 1 ? () => setState(() => _pax--) : null, icon: const Icon(Icons.remove_rounded, size: 18)),
                Text('$_pax', style: const TextStyle(fontWeight: FontWeight.w700)),
                const Icon(Icons.person_rounded, size: 16, color: C.muted),
                IconButton(visualDensity: VisualDensity.compact, onPressed: _pax < 9 ? () => setState(() => _pax++) : null, icon: const Icon(Icons.add_rounded, size: 18)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          PrimaryButton('Search flights', icon: Icons.flight_rounded, onPressed: () {
            if (!ok) return toast(context, tr('Pick two different airports'));
            setState(() => _searched = true);
          }),
        ]),
      ),
      const SizedBox(height: 16),
      if (!_searched || !ok)
        const EmptyState(Icons.flight_takeoff_rounded, 'Find your flight', 'Search 3,000+ airports worldwide, then compare live fares from every airline.')
      else ...[
        _card(
          margin: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(_from!.iata, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
              const Icon(Icons.flight_rounded, color: C.primary),
              Expanded(child: Text(_to!.iata, textAlign: TextAlign.right, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
            ]),
            Row(children: [
              Expanded(child: Text(_from!.name, style: const TextStyle(color: C.muted, fontSize: 11.5))),
              const SizedBox(width: 12),
              Expanded(child: Text(_to!.name, textAlign: TextAlign.right, style: const TextStyle(color: C.muted, fontSize: 11.5))),
            ]),
            const Divider(height: 24),
            Wrap(spacing: 18, runSpacing: 6, children: [
              _fact(Icons.straighten_rounded, '${dist.round()} km'),
              _fact(Icons.schedule_rounded, '≈ ${mins ~/ 60}h ${mins % 60}m non-stop'),
              _fact(Icons.event_rounded, fmtDate(_date)),
              _fact(Icons.person_rounded, '$_pax traveler${_pax == 1 ? '' : 's'}'),
            ]),
          ]),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(tr('Live fares and seats'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        _linkButton(context, 'Google Flights', 'https://www.google.com/travel/flights?q=${Uri.encodeComponent('Flights from ${_from!.iata} to ${_to!.iata} on $d one way $_pax adults')}',
            primary: true),
        _linkButton(context, 'Skyscanner', 'https://www.skyscanner.net/transport/flights/${_from!.iata.toLowerCase()}/${_to!.iata.toLowerCase()}/$yymmdd/?adultsv2=$_pax'),
        _linkButton(context, 'Kayak', 'https://www.kayak.com/flights/${_from!.iata}-${_to!.iata}/$d?sort=bestflight_a${_pax > 1 ? '&adults=$_pax' : ''}'),
        Text(tr('Flight time is an estimate from the distance. Fares come from the booking site.'), style: TextStyle(color: C.muted, fontSize: 11)),
      ],
    ]);
  }
}

Widget _fact(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(i, size: 16, color: C.muted),
      const SizedBox(width: 5),
      Text(tr(t), style: const TextStyle(fontSize: 12.5)),
    ]);

// ---------------------------------------------------------------- trains and buses

class _GroundSearch extends StatefulWidget {
  final String type;
  final String? to;
  const _GroundSearch({required this.type, this.to});
  @override
  State<_GroundSearch> createState() => _GroundSearchState();
}

class _GroundSearchState extends State<_GroundSearch> {
  List<Train> _trains = const [];
  List<BusOperator> _buses = const [];
  bool _loading = true;
  String _from = 'Dhaka', _to = '';
  DateTime _date = DateTime.now().add(const Duration(days: 3));
  bool _searched = false;
  final _wFrom = TextEditingController(), _wTo = TextEditingController();

  bool get _train => widget.type == 'train';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _wFrom.dispose();
    _wTo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (_train) {
        _trains = Backend.on ? await Backend.trains() : _demoTrains;
      } else {
        _buses = Backend.on ? await Backend.busOperators() : _demoBuses;
      }
    } catch (_) {}
    if (!mounted) return;
    final st = _stations;
    setState(() {
      _loading = false;
      _to = st.contains(widget.to) && widget.to != _from ? widget.to! : (st.contains('Chattogram') ? 'Chattogram' : (st.length > 1 ? st[1] : ''));
      if (widget.to != null && !st.contains(widget.to)) _wTo.text = widget.to!;
    });
  }

  List<String> get _stations {
    final s = <String>{
      if (_train)
        for (final t in _trains) ...t.line
      else
        for (final b in _buses) ...b.routes,
    }.toList()
      ..sort();
    return s;
  }

  Widget _drop(String label, String v, ValueChanged<String> on) {
    final st = _stations;
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr(label), style: const TextStyle(fontSize: 12, color: C.muted)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: st.contains(v) ? v : null,
          isExpanded: true,
          menuMaxHeight: 420,
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          items: [for (final c in st) DropdownMenuItem(value: c, child: Text(tr(c), overflow: TextOverflow.ellipsis))],
          onChanged: (x) => setState(() {
            on(x!);
            _searched = false;
          }),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: C.primary));
    final trains = _trains.where((t) => t.line.contains(_from) && t.line.contains(_to)).toList();
    final buses = _buses.where((b) => b.routes.contains(_from) && b.routes.contains(_to)).toList();
    final hits = _train ? trains.length : buses.length;
    final r2r = 'https://www.rome2rio.com/map/${_slug(_from)}/${_slug(_to)}';
    return ListView(padding: const EdgeInsets.all(16), children: [
      _card(
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _drop('From', _from, (v) => _from = v),
            IconButton(
              tooltip: tr('Swap'),
              onPressed: () => setState(() {
                final x = _from;
                _from = _to;
                _to = x;
              }),
              icon: const Icon(Icons.swap_horiz_rounded, color: C.primary),
            ),
            _drop('To', _to, (v) => _to = v),
          ]),
          const SizedBox(height: 12),
          _dateField(context, _date, (x) => setState(() => _date = x)),
          const SizedBox(height: 14),
          PrimaryButton(_train ? 'Find trains' : 'Find buses', icon: modeIcon(widget.type), onPressed: () {
            if (_from == _to || _to.isEmpty) return toast(context, tr('Pick two different places'));
            setState(() => _searched = true);
          }),
        ]),
      ),
      const SizedBox(height: 16),
      if (!_searched)
        EmptyState(_train ? Icons.train_rounded : Icons.directions_bus_rounded, _train ? 'Bangladesh Railway intercity trains' : 'Intercity bus operators',
            _train ? '${_trains.length} intercity trains. Pick a route to see which trains run on it.' : '${_buses.length} major operators. Pick a route to see who runs it.')
      else ...[
        Text(hits == 0 ? 'No direct ${_train ? 'train' : 'bus operator'} listed' : '$hits ${_train ? 'train' : 'operator'}${hits == 1 ? '' : 's'} from $_from to $_to',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 10),
        if (_train)
          for (final t in trains) _TrainCard(t, from: _from, to: _to)
        else
          for (final b in buses) _BusCard(b),
        const SizedBox(height: 4),
        if (_train) ...[
          _linkButton(context, 'Check times & buy on Rail Sheba', 'https://eticket.railway.gov.bd/', primary: true, icon: Icons.confirmation_number_rounded),
          Text(tr('Tickets for Bangladesh Railway are sold only on the official Rail Sheba site and app. Times change with each season, so check the live schedule there.'),
              style: TextStyle(color: C.muted, fontSize: 11.5)),
        ] else ...[
          _linkButton(context, 'See seats & fares on Shohoz', 'https://www.shohoz.com/bus-tickets', primary: true, icon: Icons.confirmation_number_rounded),
          _linkButton(context, 'BusBD', 'https://www.busbd.com.bd/'),
        ],
        _linkButton(context, 'All ways to get there (Rome2rio)', r2r, icon: Icons.alt_route_rounded),
      ],
      const SizedBox(height: 18),
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Traveling outside Bangladesh?'), style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _wFrom, decoration: InputDecoration(hintText: tr('From, e.g. Bangkok')))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _wTo, decoration: InputDecoration(hintText: tr('To, e.g. Chiang Mai')))),
          ]),
          const SizedBox(height: 10),
          OutlinedButtonTheme(
            data: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), textStyle: const TextStyle(fontSize: 12.5))),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _world('https://12go.asia/en/travel/${_slug(_wFrom.text).toLowerCase()}/${_slug(_wTo.text).toLowerCase()}?date=${_ymd(_date)}'),
                  child: const Text('12Go'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _world(_train ? 'https://www.thetrainline.com/en/search/${_slug(_wFrom.text).toLowerCase()}/${_slug(_wTo.text).toLowerCase()}' : 'https://global.flixbus.com/'),
                  child: Text(_train ? 'Trainline' : 'FlixBus'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => _world('https://www.rome2rio.com/map/${_slug(_wFrom.text)}/${_slug(_wTo.text)}'), child: const Text('Rome2rio'))),
            ]),
          ),
        ]),
      ),
    ]);
  }

  void _world(String url) {
    if (_wFrom.text.trim().isEmpty || _wTo.text.trim().isEmpty) return toast(context, tr('Type where you are going from and to'));
    openLink(context, url);
  }
}

class _TrainCard extends StatelessWidget {
  final Train t;
  final String from, to;
  const _TrainCard(this.t, {required this.from, required this.to});
  @override
  Widget build(BuildContext context) {
    var line = t.line;
    if (line.indexOf(from) > line.indexOf(to)) line = line.reversed.toList();
    final seg = line.sublist(line.indexOf(from), line.indexOf(to) + 1);
    final between = seg.length - 2;
    return _card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.train_rounded, color: C.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: C.primary.withValues(alpha: .15), borderRadius: BorderRadius.circular(8)),
            child: Text('No. ${t.number}', style: const TextStyle(color: C.primary, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(seg.join('  →  '), style: const TextStyle(fontSize: 12.5)),
        const SizedBox(height: 4),
        Text(
          [
            'Runs ${t.origin} – ${t.destination}',
            if (between == 0) 'no listed stops in between' else '$between main stop${between == 1 ? '' : 's'} on the way',
            if (t.note != null) t.note!,
          ].join('  ·  '),
          style: const TextStyle(color: C.muted, fontSize: 11.5),
        ),
      ]),
    );
  }
}

class _BusCard extends StatelessWidget {
  final BusOperator b;
  const _BusCard(this.b);
  @override
  Widget build(BuildContext context) => _card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          const Icon(Icons.directions_bus_rounded, color: C.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 3),
              Text('${b.ac ? 'AC coaches  ·  ' : ''}Also runs to ${b.routes.take(6).join(', ')}', style: const TextStyle(color: C.muted, fontSize: 11.5), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (b.website != null) IconButton(tooltip: tr('Website'), onPressed: () => openLink(context, b.website!), icon: const Icon(Icons.language_rounded, color: C.primary)),
        ]),
      );
}
