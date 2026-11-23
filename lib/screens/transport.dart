import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'booking_flow.dart';

const _titles = {'flight': 'Flights', 'train': 'Train tickets', 'bus': 'Bus tickets'};

const _operators = {
  'flight': ['Biman Bangladesh', 'US-Bangla', 'Novoair', 'Emirates', 'Qatar Airways'],
  'train': ['Suborno Express', 'Mohanagar Provati', 'Parjatak Express', 'Turna Nishita', 'Ekota Express'],
  'bus': ['Hanif Enterprise', 'Shyamoli Paribahan', 'Green Line', 'Ena Transport', 'Soudia'],
};

String _hhmm(int minutes) {
  final m = minutes % (24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

/// Deterministic demo offers. Replace with your airline / railway / bus aggregator API.
List<TransportOffer> buildOffers(String type, String from, String to) {
  final seed = (from + to).codeUnits.fold<int>(0, (a, b) => a + b);
  final base = type == 'flight' ? 90 + seed % 120 : type == 'train' ? 8 + seed % 20 : 7 + seed % 18;
  final dur = type == 'flight' ? 60 + seed % 240 : type == 'train' ? 240 + seed % 300 : 300 + seed % 360;
  return [
    for (var i = 0; i < 5; i++)
      TransportOffer(
        type: type,
        operator: _operators[type]![i],
        from: from,
        to: to,
        depart: _hhmm(300 + i * 190 + (seed % 4) * 15),
        arrive: _hhmm(300 + i * 190 + (seed % 4) * 15 + dur + i * 5),
        duration: '${(dur + i * 5) ~/ 60}h ${(dur + i * 5) % 60}m',
        extra: type == 'flight' ? (i % 2 == 0 ? 'Non-stop' : '1 stop') : type == 'train' ? 'AC and non-AC' : (i % 2 == 0 ? 'AC' : 'Non-AC'),
        price: (base + i * (type == 'flight' ? 14 : 2)).toDouble(),
      ),
  ];
}

class TransportScreen extends StatefulWidget {
  final String type;
  final String? to;
  const TransportScreen({super.key, required this.type, this.to});
  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  late String _from = 'Dhaka';
  late String _to;
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  List<TransportOffer>? _offers;

  @override
  void initState() {
    super.initState();
    _to = widget.to ?? 'Chattogram';
    if (_to == _from) _from = 'Chattogram';
  }

  Widget _drop(String label, String v, ValueChanged<String> on) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: v,
            isExpanded: true,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: [for (final c in cities) DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))],
            onChanged: (x) => setState(() => on(x!)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final t = widget.type;
    return ScreenScaffold(
      title: _titles[t] ?? 'Tickets',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _drop('From', _from, (v) => _from = v),
              IconButton(
                tooltip: 'Swap',
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
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final r = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (r != null) setState(() => _date = r);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
                child: Row(children: [
                  const Icon(Icons.calendar_month_rounded, color: C.muted, size: 20),
                  const SizedBox(width: 10),
                  Text(fmtDate(_date)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton('Search ${t == 'flight' ? 'flights' : t == 'train' ? 'trains' : 'buses'}', icon: modeIcon(t), onPressed: () {
              if (_from == _to) return toast(context, 'Pick two different cities');
              setState(() => _offers = buildOffers(t, _from, _to));
            }),
          ]),
        ),
        const SizedBox(height: 16),
        if (_offers == null)
          const EmptyState(Icons.confirmation_number_outlined, 'Find your ticket', 'Choose where you are going and compare fares from several operators.')
        else
          for (final o in _offers!)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
              child: Column(children: [
                Row(children: [
                  Icon(modeIcon(t), color: C.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(o.operator, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(money(o.price), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: C.primary)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Text(o.depart, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  Expanded(
                    child: Column(children: [
                      Text(o.duration, style: const TextStyle(fontSize: 11, color: C.muted)),
                      const Divider(indent: 8, endIndent: 8),
                      Text(o.extra, style: const TextStyle(fontSize: 11, color: C.muted)),
                    ]),
                  ),
                  Text(o.arrive, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Text('${o.from} to ${o.to}', style: const TextStyle(fontSize: 12, color: C.muted)),
                  const Spacer(),
                  SizedBox(
                    height: 36,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: C.primary),
                      onPressed: () => go(
                        context,
                        BookingFlowScreen(
                          draft: BookingDraft(
                            title: '${o.from} to ${o.to}',
                            location: '${o.operator}  ·  ${o.depart}',
                            type: t,
                            seed: '${o.to}-travel',
                            unitPrice: o.price,
                          ),
                        ),
                      ),
                      child: const Text('Select'),
                    ),
                  ),
                ]),
              ]),
            ),
      ]),
    );
  }
}

class GuidesScreen extends StatelessWidget {
  final String? country;
  const GuidesScreen({super.key, this.country});

  @override
  Widget build(BuildContext context) {
    final list = country == null ? guides : guides.where((g) => g.base == country).toList();
    final shown = list.isEmpty ? guides : list;
    return ScreenScaffold(
      title: 'Travel guides',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (country != null && list.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('No guides listed for this country yet. Showing top guides worldwide.', style: TextStyle(color: C.muted, fontSize: 12.5)),
          ),
        for (final g in shown)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Avatar(g.seed, name: g.name, radius: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${g.base}  ·  ${g.years} years', style: const TextStyle(fontSize: 12, color: C.muted)),
                    RatingText(g.rating),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(money(g.pricePerDay), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: C.primary)),
                  const Text('per day', style: TextStyle(fontSize: 10.5, color: C.muted)),
                ]),
              ]),
              const SizedBox(height: 10),
              Text(g.bio, style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.5)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Text('Speaks ${g.languages.join(', ')}', style: const TextStyle(fontSize: 11.5))),
                SizedBox(
                  height: 36,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: C.primary),
                    onPressed: () => go(
                      context,
                      BookingFlowScreen(
                        draft: BookingDraft(title: 'Guide: ${g.name}', location: g.base, type: 'guide', seed: g.seed, unitPrice: g.pricePerDay),
                      ),
                    ),
                    child: const Text('Hire'),
                  ),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }
}
