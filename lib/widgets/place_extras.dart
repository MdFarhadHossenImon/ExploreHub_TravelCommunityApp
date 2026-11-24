import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/i18n.dart';
import 'package:http/http.dart' as http;

import '../core/theme.dart';
import '../data/backend.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import 'common.dart';

// ---------------------------------------------------------------- weather

String _wmo(int c) {
  if (c == 0) return 'Clear sky';
  if (c <= 2) return 'Partly cloudy';
  if (c == 3) return 'Overcast';
  if (c <= 48) return 'Fog';
  if (c <= 57) return 'Drizzle';
  if (c <= 67) return 'Rain';
  if (c <= 77) return 'Snow';
  if (c <= 82) return 'Showers';
  if (c <= 86) return 'Snow showers';
  return 'Thunderstorm';
}

IconData _wmoIcon(int c) {
  if (c == 0) return Icons.wb_sunny_rounded;
  if (c <= 2) return Icons.wb_cloudy_outlined;
  if (c == 3) return Icons.cloud_rounded;
  if (c <= 48) return Icons.foggy;
  if (c <= 67 || (c >= 80 && c <= 82)) return Icons.water_drop_rounded;
  if (c <= 77 || c <= 86) return Icons.ac_unit_rounded;
  return Icons.thunderstorm_rounded;
}

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Live weather and a 5-day forecast from Open-Meteo (free, no key).
class WeatherCard extends StatefulWidget {
  final double lat, lng;
  const WeatherCard(this.lat, this.lng, {super.key});
  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  Map<String, dynamic>? _data;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uri = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=${widget.lat}&longitude=${widget.lng}'
          '&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m'
          '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=5');
      final r = await http.get(uri).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) throw Exception();
      if (mounted) setState(() => _data = jsonDecode(r.body) as Map<String, dynamic>);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final d = _data;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
      child: d == null
          ? const SizedBox(height: 70, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          : Builder(builder: (context) {
              final cur = d['current'] as Map<String, dynamic>;
              final daily = d['daily'] as Map<String, dynamic>;
              final code = (cur['weather_code'] as num).toInt();
              final days = (daily['time'] as List).length;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(_wmoIcon(code), size: 34, color: C.primary),
                  const SizedBox(width: 10),
                  Text('${(cur['temperature_2m'] as num).round()}°C', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(trf('{0} right now', [_wmo(code)]), style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(trf('Wind {0} km/h · Humidity {1}%', [(cur['wind_speed_10m'] as num).round(), (cur['relative_humidity_2m'] as num).round()]),
                          style: const TextStyle(fontSize: 12, color: C.muted)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  for (var i = 0; i < days; i++)
                    Expanded(
                      child: Column(children: [
                        Text(i == 0 ? tr('Today') : _wd[DateTime.parse(daily['time'][i] as String).weekday - 1], style: const TextStyle(fontSize: 11.5, color: C.muted)),
                        const SizedBox(height: 4),
                        Icon(_wmoIcon((daily['weather_code'][i] as num).toInt()), size: 20, color: C.primary),
                        const SizedBox(height: 4),
                        Text('${(daily['temperature_2m_max'][i] as num).round()}° / ${(daily['temperature_2m_min'][i] as num).round()}°', style: const TextStyle(fontSize: 11.5)),
                        if (daily['precipitation_probability_max'][i] != null)
                          Text('${daily['precipitation_probability_max'][i]}% rain', style: const TextStyle(fontSize: 10, color: C.muted)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 6),
                Text(tr('Weather data: Open-Meteo.com'), style: TextStyle(fontSize: 10, color: C.muted)),
              ]);
            }),
    );
  }
}

// ---------------------------------------------------------------- country essentials

String flagEmoji(String? iso2) {
  if (iso2 == null || iso2.length != 2) return '';
  final u = iso2.toUpperCase().codeUnits;
  return String.fromCharCodes([0x1F1E6 + u[0] - 65, 0x1F1E6 + u[1] - 65]);
}

Map<String, dynamic>? _rates;

/// Emergency number, money, plugs, driving side and language for the place's country.
class EssentialsCard extends StatefulWidget {
  final String country;
  const EssentialsCard(this.country, {super.key});
  @override
  State<EssentialsCard> createState() => _EssentialsCardState();
}

class _EssentialsCardState extends State<EssentialsCard> {
  Map<String, dynamic>? _info;
  double? _rate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Backend.on) return;
    try {
      final info = await Backend.countryInfo(widget.country);
      if (!mounted || info == null) return;
      setState(() => _info = info);
      final code = info['currency_code'] as String?;
      if (code == null || code == 'USD') return;
      if (_rates == null) {
        final r = await http.get(Uri.parse('https://open.er-api.com/v6/latest/USD')).timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) _rates = (jsonDecode(r.body) as Map<String, dynamic>)['rates'] as Map<String, dynamic>?;
      }
      final v = _rates?[code];
      if (mounted && v != null) setState(() => _rate = (v as num).toDouble());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final i = _info;
    if (i == null) return const SizedBox.shrink();
    Widget row(IconData icon, String label, String? value) => (value == null || value.isEmpty)
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 18, color: C.primary),
              const SizedBox(width: 10),
              SizedBox(width: 92, child: Text(tr(label), style: const TextStyle(fontSize: 12.5, color: C.muted))),
              Expanded(child: Text(tr(value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            ]),
          );
    final code = i['currency_code'] as String?;
    final money = [
      if (i['currency'] != null) i['currency'] as String,
      if (code != null) '($code)',
      if (_rate != null) '· 1 USD ≈ ${_rate! >= 100 ? _rate!.round() : _rate!.toStringAsFixed(2)} $code',
    ].join(' ');
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${flagEmoji(i['flag'] as String?)}  ${widget.country} essentials', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        row(Icons.emergency_rounded, 'Emergency', i['emergency'] as String?),
        row(Icons.payments_outlined, 'Money', money),
        row(Icons.power_outlined, 'Plugs', i['plugs'] as String?),
        row(Icons.directions_car_outlined, 'Driving', i['drives'] == null ? null : 'Drive on the ${(i['drives'] as String).toLowerCase().contains('left') ? 'left' : 'right'}'),
        row(Icons.translate_rounded, 'Language', i['languages'] as String?),
        row(Icons.account_balance_outlined, 'Capital', i['capital'] as String?),
        Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(tr('Sources: Wikidata, exchange rates by open.er-api.com. Always double-check before you travel.'), style: TextStyle(fontSize: 10, color: C.muted)),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- nearby

double _km(double la1, double lo1, double la2, double lo2) {
  const r = 6371.0;
  final dLa = (la2 - la1) * math.pi / 180, dLo = (lo2 - lo1) * math.pi / 180;
  final a = math.pow(math.sin(dLa / 2), 2) + math.cos(la1 * math.pi / 180) * math.cos(la2 * math.pi / 180) * math.pow(math.sin(dLo / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Other places in the catalog within a few hours of this one.
List<(Place, double)> nearbyPlaces(Place p, {int max = 10, double withinKm = 400}) {
  if (p.lat == null || p.lng == null) return const [];
  final out = <(Place, double)>[];
  for (final o in places) {
    if (o.id == p.id || o.lat == null || o.lng == null) continue;
    final d = _km(p.lat!, p.lng!, o.lat!, o.lng!);
    if (d <= withinKm) out.add((o, d));
  }
  out.sort((a, b) => a.$2.compareTo(b.$2));
  return out.take(max).toList();
}

class NearbyStrip extends StatelessWidget {
  final Place place;
  final void Function(Place) onOpen;
  const NearbyStrip(this.place, {super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final list = nearbyPlaces(place);
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 18),
      Text(tr('Nearby places'), style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (c, i) {
            final (o, d) = list[i];
            return GestureDetector(
              onTap: () => onOpen(o),
              child: SizedBox(
                width: 140,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(height: 96, width: 140, child: AppImage(o.photo, radius: 12)),
                  const SizedBox(height: 6),
                  Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                  Text('${d < 1 ? '<1' : d.round()} km away', style: const TextStyle(fontSize: 11, color: C.muted)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
