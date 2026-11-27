import 'package:flutter/material.dart';
import '../core/currency.dart';
import 'package:provider/provider.dart';
import '../core/env.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../data/mock_data.dart';
import '../data/social.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
import '../widgets/social_widgets.dart';
import 'trips.dart';

/// AI trip planner: pick a place, days and budget, get a day-by-day plan, save it as a trip.
class AiPlannerScreen extends StatefulWidget {
  final String? placeId;
  const AiPlannerScreen({super.key, this.placeId});
  @override
  State<AiPlannerScreen> createState() => _AiPlannerScreenState();
}

class _AiPlannerScreenState extends State<AiPlannerScreen> {
  late String _place = widget.placeId ?? places.first.id;
  int _days = 3;
  String _currency = appCurrency;
  final _budget = TextEditingController(text: '15000');
  final Set<String> _interests = {};
  DateTime _start = DateTime.now().add(const Duration(days: 7));
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _plan;

  Future<void> _make() async {
    final p = placeById(_place);
    setState(() {
      _busy = true;
      _error = null;
      _plan = null;
    });
    try {
      final Map<String, dynamic> r;
      if (!Backend.on) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        r = {'plan': _demoPlan(p.name, _days, _currency)};
      } else {
        r = await Backend.freePlan(
          placeId: p.id,
          days: _days,
          budget: double.tryParse(_budget.text.trim()) ?? 0,
          currency: _currency,
          start: _start,
          interests: _interests.toList(),
        );
      }
      if (!mounted) return;
      setState(() {
        _plan = Map<String, dynamic>.from(r['plan'] as Map);
      });
    } on PlannerError catch (e) {
      if (mounted) setState(() => _error = tr(e.message));
    } catch (e) {
      if (mounted) setState(() => _error = errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _kind(String s) {
    final t = s.toLowerCase();
    bool has(List<String> w) => w.any(t.contains);
    if (has(['breakfast', 'lunch', 'dinner', 'food', 'eat', 'restaurant', 'tea', 'নাস্তা', 'দুপুরের', 'রাতের', 'খাবার'])) return 'food';
    if (has(['hotel', 'check in', 'check-in', 'resort', 'stay', 'হোটেল', 'রিসোর্ট'])) return 'hotel';
    if (has(['flight', 'airport', 'ফ্লাইট', 'বিমান'])) return 'flight';
    if (has(['train', 'ট্রেন'])) return 'train';
    if (has(['boat', 'ferry', 'launch', 'নৌকা', 'লঞ্চ', 'ফেরি'])) return 'boat';
    if (has(['bus', 'jeep', 'cng', 'বাস', 'জিপ'])) return 'bus';
    if (has(['trek', 'hike', 'ট্রেক', 'হাইক'])) return 'trek';
    return 'sight';
  }

  void _save() {
    final plan = _plan!;
    final days = (plan['days'] as List).cast<Map>();
    final total = (plan['total_estimate'] as num?)?.toDouble() ?? 0;
    // Trip budgets are kept in USD.
    final usd = _currency == 'USD' ? total : (total / bdtPerUsd).roundToDouble();
    final t = context.read<SocialState>().createTrip(
          title: (plan['title'] as String?)?.trim().isNotEmpty == true ? plan['title'] as String : '${placeById(_place).name} trip',
          placeId: _place,
          start: _start,
          days: days.length,
          budget: usd,
        );
    for (var d = 0; d < days.length && d < t.days.length; d++) {
      for (final it in (days[d]['items'] as List).cast<Map>()) {
        final a = '${it['activity'] ?? ''}';
        t.days[d].stops.add(TripStop('${it['time'] ?? ''}', a, '${it['note'] ?? ''}', _kind(a)));
      }
    }
    say(tr('Saved to your trips'));
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TripDetailScreen(trip: t)));
  }

  @override
  Widget build(BuildContext context) {
    final p = placeById(_place);
    return ScreenScaffold(
      title: tr('Smart trip planner'),
      maxWidth: 760,
      bottom: _plan != null
          ? PrimaryButton('Save as my trip', icon: Icons.bookmark_add_rounded, onPressed: _save)
          : PrimaryButton(_busy ? 'Planning your trip…' : 'Make my plan', icon: Icons.auto_awesome_rounded, onPressed: _busy ? null : _make),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Panel(
          child: Row(children: [
            const Icon(Icons.auto_awesome_rounded, color: C.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(tr('Tell us where, when and your budget. We build a free day-by-day plan with nearby sights, weather and costs. Save it as a trip and edit.'), style: const TextStyle(fontSize: 13, color: C.muted))),
          ]),
        ),
        const SizedBox(height: 14),
        Text(tr('Destination'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _place,
          isExpanded: true,
          items: [for (final x in places) DropdownMenuItem(value: x.id, child: Text('${x.name}, ${x.country}', overflow: TextOverflow.ellipsis))],
          onChanged: _busy ? null : (v) => setState(() => _place = v ?? _place),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Text(tr('Days'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          IconButton(onPressed: _busy || _days <= 1 ? null : () => setState(() => _days--), icon: const Icon(Icons.remove_circle_outline_rounded)),
          Text(tr('$_days days'), style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(onPressed: _busy || _days >= 14 ? null : () => setState(() => _days++), icon: const Icon(Icons.add_circle_outline_rounded)),
        ]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: LabeledField('Budget per person', 'e.g. 15000', controller: _budget, keyboard: TextInputType.number)),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'BDT', label: Text('৳ BDT')), ButtonSegment(value: 'USD', label: Text('\$ USD'))],
              selected: {_currency},
              onSelectionChanged: _busy ? null : (s) => setState(() => _currency = s.first),
            ),
          ),
        ]),
        Panel(
          onTap: _busy
              ? null
              : () async {
                  final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)), initialDate: _start);
                  if (d != null) setState(() => _start = d);
                },
          child: Row(children: [
            const Icon(Icons.event_rounded, color: C.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(tr('Start date'))),
            Text(fmtDate(_start), style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 14),
        Text(tr('What do you like? (optional)'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final i in const [('nature', 'Nature'), ('history', 'History'), ('faith', 'Religious sites'), ('sight', 'Landmarks')])
            FilterChip(
              label: Text(tr(i.$2)),
              selected: _interests.contains(i.$1),
              onSelected: _busy ? null : (v) => setState(() => v ? _interests.add(i.$1) : _interests.remove(i.$1)),
            ),
        ]),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Panel(child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: Colors.orange),
              const SizedBox(width: 10),
              Expanded(child: Text(_error!)),
            ])),
          ),
        if (_busy)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Column(children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(tr('This can take up to a minute.'), style: const TextStyle(color: C.muted)),
            ]),
          ),
        if (_plan != null) ..._planView(_plan!, p.name),
      ]),
    );
  }

  List<Widget> _planView(Map<String, dynamic> plan, String place) {
    final cur = (plan['currency'] as String?) ?? _currency;
    String amt(num? v) => v == null ? '' : '${v.round()} $cur';
    final days = (plan['days'] as List).cast<Map>();
    final tips = ((plan['tips'] as List?) ?? const []).cast<Object>();
    return [
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: Text('${plan['title'] ?? place}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
        TextButton.icon(onPressed: _busy ? null : _make, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(tr('Try again'))),
      ]),
      const SizedBox(height: 4),
      Text('${plan['summary'] ?? ''}', style: const TextStyle(color: C.muted, height: 1.4)),
      const SizedBox(height: 8),
      Text(trf('Estimated total: {0}', [amt(plan['total_estimate'] as num?)]), style: const TextStyle(color: C.primary, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      for (final d in days)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(radius: 14, backgroundColor: C.primary, child: Text('${d['day']}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                const SizedBox(width: 10),
                Expanded(child: Text('${d['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800))),
                Text(amt(d['cost'] as num?), style: const TextStyle(color: C.muted, fontSize: 12)),
              ]),
              if ('${d['weather'] ?? ''}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 38),
                  child: Row(children: [
                    const Icon(Icons.wb_cloudy_outlined, size: 14, color: C.muted),
                    const SizedBox(width: 4),
                    Expanded(child: Text('${d['weather']}', style: const TextStyle(fontSize: 12, color: C.muted))),
                  ]),
                ),
              const SizedBox(height: 8),
              for (final it in (d['items'] as List).cast<Map>())
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 62, child: Text('${it['time'] ?? ''}', style: const TextStyle(fontSize: 12, color: C.primary, fontWeight: FontWeight.w700))),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${it['activity'] ?? ''}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        if ('${it['note'] ?? ''}'.isNotEmpty) Text('${it['note']}', style: const TextStyle(fontSize: 12, color: C.muted)),
                      ]),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
      if (tips.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(tr('Tips'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final t in tips)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('•  ', style: TextStyle(color: C.primary)),
              Expanded(child: Text('$t', style: const TextStyle(fontSize: 13))),
            ]),
          ),
      ],
      const SizedBox(height: 8),
      Text(trf('Built from {0}. Costs are estimates; check prices and opening times before you go.', [((plan['sources'] as List?) ?? const ['Wikidata', 'OpenStreetMap']).join(', ')]), style: const TextStyle(fontSize: 11.5, color: C.muted)),
      const SizedBox(height: 20),
    ];
  }
}

/// Sample plan for the preview build (no live database).
Map<String, dynamic> _demoPlan(String place, int days, String cur) => {
      'title': '$days days in $place',
      'summary': 'A relaxed plan with the main sights, local food and time to rest.',
      'currency': cur,
      'total_estimate': cur == 'USD' ? 40 * days : 4500 * days,
      'tips': ['Carry cash for small shops.', 'Start early to beat the crowds.'],
      'days': [
        for (var d = 1; d <= days; d++)
          {
            'day': d,
            'title': d == 1 ? 'Arrive and explore' : 'Day $d sights',
            'cost': cur == 'USD' ? 40 : 4500,
            'items': [
              {'time': '08:00', 'activity': 'Breakfast at a local tea stall', 'note': 'Try paratha and tea.'},
              {'time': '10:00', 'activity': 'Visit the main viewpoint', 'note': 'Shared jeep from town.'},
              {'time': '19:00', 'activity': 'Dinner and rest at the hotel', 'note': ''},
            ],
          }
      ],
    };
