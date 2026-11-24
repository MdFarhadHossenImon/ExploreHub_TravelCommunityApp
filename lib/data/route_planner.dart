import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import 'models.dart';
import 'offline.dart';

/// A city a trip starts from.
class Origin {
  final String name, country;
  final double lat, lng;
  const Origin(this.name, this.country, this.lat, this.lng);
  String get key => '${name.toLowerCase()}@${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';
  static const dhaka = Origin('Dhaka', 'Bangladesh', 23.725, 90.407);
}

/// One item of the step-by-step route: either a stop (a place you pass) or a leg (how you travel to the next stop).
/// Stored as plain maps so a plan can be cached in Supabase and shared.
///   stop: {t: 'stop', name, sub, kind: start|town|airport|end}
///   leg:  {t: 'leg', mode: bus|flight|drive|local, km, min, car, roads: [..]}
typedef PlanItem = Map<String, dynamic>;

class RoutePlanner {
  static SupabaseClient get _c => Supabase.instance.client;

  static double km(double a, double b, double c, double d) {
    const r = math.pi / 180;
    final x = math.pow(math.sin((c - a) * r / 2), 2) + math.cos(a * r) * math.cos(c * r) * math.pow(math.sin((d - b) * r / 2), 2);
    return 12742 * math.asin(math.sqrt(x));
  }

  static Future<List<Origin>> searchCities(String q) async {
    final t = q.trim().replaceAll(RegExp(r'[,()%]'), ' ').trim();
    if (t.length < 2) return const [];
    final rows = await _c.from('cities').select('name, country, lat, lng').ilike('name', '$t%').order('pop', ascending: false).limit(12);
    return [for (final r in rows) Origin(r['name'] as String, r['country'] as String? ?? '', (r['lat'] as num).toDouble(), (r['lng'] as num).toDouble())];
  }

  /// The traveler's home city from their profile text ("Dhaka, Bangladesh"), else Dhaka.
  static Future<Origin> homeOrigin(String home) async {
    final first = home.split(',').first.trim();
    if (first.length >= 2) {
      try {
        final r = await searchCities(first);
        if (r.isNotEmpty) return r.first;
      } catch (_) {}
    }
    return Origin.dhaka;
  }

  /// Returns a cached plan or builds one from real road routing (OSRM) and the towns along the road (OpenStreetMap).
  static Future<List<PlanItem>> plan(Origin o, Place p) async {
    final k = 'route:${p.id}:${o.key}';
    List<PlanItem>? saved() {
      final c = Offline.read(k);
      return c is List ? [for (final e in c) Map<String, dynamic>.from(e as Map)] : null;
    }

    if (!Offline.online.value) {
      final c = saved();
      if (c != null) return c;
    }
    try {
      final items = await _plan(o, p);
      if (items.length > 2) Offline.write(k, items);
      return items;
    } catch (_) {
      final c = saved();
      if (c != null) return c;
      rethrow;
    }
  }

  static Future<List<PlanItem>> _plan(Origin o, Place p) async {
    if (Env.configured) {
      try {
        final r = await _c.from('place_routes').select('data').eq('place_id', p.id).eq('origin', o.key).maybeSingle();
        if (r != null) return List<PlanItem>.from((r['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    }
    final items = await _build(o, p);
    if (Env.configured && _c.auth.currentUser != null && items.length > 2) {
      try {
        await _c.rpc('cache_route', params: {'p_place': p.id, 'p_origin': o.key, 'p_data': items});
      } catch (_) {}
    }
    return items;
  }

  static Future<List<PlanItem>> _build(Origin o, Place p) async {
    final plat = p.lat!, plng = p.lng!;
    final direct = km(o.lat, o.lng, plat, plng);
    final items = <PlanItem>[
      {'t': 'stop', 'name': o.name, 'sub': o.country, 'kind': 'start'},
    ];
    if (direct < 15) {
      items.add({'t': 'leg', 'mode': 'local', 'km': direct.round(), 'min': (direct * 4).round() + 10, 'roads': <String>[]});
    } else if (direct <= 900) {
      final ok = await _ground(items, o.lat, o.lng, plat, plng);
      if (!ok) await _viaAir(items, o, plat, plng, direct);
    } else {
      await _viaAir(items, o, plat, plng, direct);
    }
    items.add({'t': 'stop', 'name': p.name, 'sub': p.where, 'kind': 'end'});
    return items;
  }

  static Future<void> _viaAir(List<PlanItem> items, Origin o, double plat, double plng, double direct) async {
    final a1 = await _airport(o.lat, o.lng), a2 = await _airport(plat, plng);
    if (a1 == null || a2 == null || a1.iata == a2.iata) {
      items.add({'t': 'leg', 'mode': 'drive', 'km': direct.round(), 'min': (direct / 60 * 60).round(), 'roads': <String>[]});
      return;
    }
    final toAirport = km(o.lat, o.lng, a1.lat, a1.lng);
    if (toAirport > 15) {
      items.add({'t': 'leg', 'mode': 'drive', 'km': toAirport.round(), 'min': (toAirport / 40 * 60).round() + 10, 'roads': <String>[]});
    }
    items.add({'t': 'stop', 'name': '${a1.city.isEmpty ? a1.name : a1.city} (${a1.iata})', 'sub': a1.name, 'kind': 'airport', 'iata': a1.iata});
    final fly = km(a1.lat, a1.lng, a2.lat, a2.lng);
    items.add({'t': 'leg', 'mode': 'flight', 'km': fly.round(), 'min': (fly / 780 * 60 + 35).round(), 'roads': <String>[], 'from': a1.iata, 'to': a2.iata});
    items.add({'t': 'stop', 'name': '${a2.city.isEmpty ? a2.name : a2.city} (${a2.iata})', 'sub': a2.name, 'kind': 'airport', 'iata': a2.iata});
    final last = km(a2.lat, a2.lng, plat, plng);
    if (last > 15) {
      final ok = await _ground(items, a2.lat, a2.lng, plat, plng);
      if (!ok) items.add({'t': 'leg', 'mode': 'local', 'km': last.round(), 'min': (last / 35 * 60).round() + 20, 'roads': <String>[]});
    } else {
      items.add({'t': 'leg', 'mode': 'local', 'km': last.round(), 'min': (last / 30 * 60).round() + 10, 'roads': <String>[]});
    }
  }

  static Future<Airport?> _airport(double lat, double lng) async {
    if (!Env.configured) return null;
    try {
      final r = await _c.rpc('nearest_airport', params: {'p_lat': lat, 'p_lng': lng});
      final l = r as List;
      return l.isEmpty ? null : Airport.fromRow(Map<String, dynamic>.from(l.first as Map));
    } catch (_) {
      return null;
    }
  }

  /// Adds road legs (split at the towns on the way). False when no road route exists.
  static Future<bool> _ground(List<PlanItem> items, double lat1, double lng1, double lat2, double lng2) async {
    Map<String, dynamic>? route;
    try {
      final u = Uri.parse('https://router.project-osrm.org/route/v1/driving/$lng1,$lat1;$lng2,$lat2?overview=full&geometries=geojson&steps=true');
      final r = await http.get(u).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map;
        if (j['code'] == 'Ok' && (j['routes'] as List).isNotEmpty) route = Map<String, dynamic>.from(j['routes'][0] as Map);
      }
    } catch (_) {}
    if (route == null) return false;
    final totalKm = (route['distance'] as num) / 1000;
    final totalMin = (route['duration'] as num) / 60;
    // A road far longer than the straight line usually means a ferry or a detour across a border: still fine, keep it.
    final coords = [for (final c in (route['geometry']['coordinates'] as List)) (lat: (c[1] as num).toDouble(), lng: (c[0] as num).toDouble())];
    // cumulative distance along the road
    final cum = <double>[0];
    for (var i = 1; i < coords.length; i++) {
      cum.add(cum.last + km(coords[i - 1].lat, coords[i - 1].lng, coords[i].lat, coords[i].lng));
    }
    final geoTotal = cum.last == 0 ? 1.0 : cum.last;

    // main roads by distance
    final roadKm = <String, double>{};
    for (final leg in route['legs'] as List) {
      for (final s in leg['steps'] as List) {
        final name = ((s['ref'] as String?)?.isNotEmpty ?? false) ? (s['ref'] as String).split(';').first : (s['name'] as String? ?? '');
        if (name.isEmpty) continue;
        roadKm[name] = (roadKm[name] ?? 0) + (s['distance'] as num) / 1000;
      }
    }
    final roads = (roadKm.entries.where((e) => e.value > math.max(5, totalKm * .08)).toList()..sort((a, b) => b.value.compareTo(a.value))).take(3).map((e) => e.key).toList();

    // towns on the way
    final stops = await _towns(coords, cum, geoTotal, totalKm);

    var prevKm = 0.0;
    void addLeg(double atKm, List<String> r) {
      final seg = (atKm - prevKm).clamp(0.0, totalKm);
      final car = totalMin * (seg / totalKm);
      items.add({'t': 'leg', 'mode': 'bus', 'km': seg.round(), 'car': car.round(), 'min': (car * 1.35 + (seg > 60 ? 15 : 5)).round(), 'roads': r});
      prevKm = atKm;
    }

    for (final s in stops) {
      addLeg(s.km, roads);
      items.add({'t': 'stop', 'name': s.name, 'sub': '${s.km.round()} km from start', 'kind': 'town'});
    }
    addLeg(totalKm, roads);
    return true;
  }

  static Future<List<({String name, double km})>> _towns(List<({double lat, double lng})> coords, List<double> cum, double geoTotal, double totalKm) async {
    if (totalKm < 40 || coords.length < 2) return const [];
    // sample points every ~8 km (at most 70)
    final step = math.max(8.0, geoTotal / 70);
    final samples = <({double lat, double lng, double at})>[];
    var next = 0.0;
    for (var i = 0; i < coords.length; i++) {
      if (cum[i] >= next) {
        samples.add((lat: coords[i].lat, lng: coords[i].lng, at: cum[i] / geoTotal * totalKm));
        next = cum[i] + step;
      }
    }
    final found = <String, ({String name, double km, int pop, bool city})>{};
    void consider(String name, double lat, double lng, int pop, bool city) {
      var best = 1e9, at = 0.0;
      for (final s in samples) {
        final d = km(s.lat, s.lng, lat, lng);
        if (d < best) {
          best = d;
          at = s.at;
        }
      }
      if (best > 6 || at < 15 || at > totalKm - 15) return;
      final k = name.toLowerCase();
      if (!found.containsKey(k)) found[k] = (name: name, km: at, pop: pop, city: city);
    }

    // OpenStreetMap towns along the road
    var ok = false;
    try {
      final pts = samples.map((s) => '${s.lat.toStringAsFixed(4)},${s.lng.toStringAsFixed(4)}').join(',');
      final q = '[out:json][timeout:20];node(around:4000,$pts)["place"~"^(city|town)\$"]["name"];out tags center 200;';
      for (final m in ['https://overpass-api.de/api/interpreter', 'https://overpass.private.coffee/api/interpreter']) {
        try {
          final r = await http.post(Uri.parse(m), body: {'data': q}).timeout(const Duration(seconds: 25));
          if (r.statusCode != 200) continue;
          for (final e in (jsonDecode(r.body) as Map)['elements'] as List) {
            final t = (e['tags'] as Map?) ?? const {};
            final name = (t['name:en'] ?? t['name']) as String?;
            if (name == null) continue;
            final pop = int.tryParse('${t['population'] ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            consider(name, (e['lat'] as num).toDouble(), (e['lon'] as num).toDouble(), pop, t['place'] == 'city');
          }
          ok = true;
          break;
        } catch (_) {}
      }
    } catch (_) {}
    // Fallback: bigger cities from Natural Earth stored in Supabase
    if (!ok && Env.configured) {
      try {
        final rows = await _c.rpc('cities_near', params: {
          'p_points': [
            for (final s in samples) [s.lat, s.lng]
          ],
          'p_km': 8,
        }) as List;
        for (final r in rows) {
          consider(r['name'] as String, (r['lat'] as num).toDouble(), (r['lng'] as num).toDouble(), (r['pop'] as num?)?.toInt() ?? 0, true);
        }
      } catch (_) {}
    }
    // keep the important ones, spread along the way
    final all = found.values.toList()..sort((a, b) => (b.city ? 1 : 0).compareTo(a.city ? 1 : 0) != 0 ? (b.city ? 1 : 0).compareTo(a.city ? 1 : 0) : b.pop.compareTo(a.pop));
    final maxStops = totalKm < 150 ? 3 : (totalKm < 400 ? 5 : 7);
    final gap = totalKm / (maxStops + 2);
    final chosen = <({String name, double km})>[];
    for (final t in all) {
      if (chosen.length >= maxStops) break;
      if (chosen.any((c) => (c.km - t.km).abs() < gap)) continue;
      chosen.add((name: t.name, km: t.km));
    }
    chosen.sort((a, b) => a.km.compareTo(b.km));
    return chosen;
  }

  // ---------- history from Wikipedia ----------
  static Future<String?> history(Place p) async {
    final k = 'history:${p.id}';
    final h = await _history(p);
    if (h != null && h.isNotEmpty) {
      Offline.write(k, h);
      return h;
    }
    final c = Offline.read(k);
    return c is String ? c : h;
  }

  static Future<String?> _history(Place p) async {
    if (p.wikiTitle == null || p.wikiTitle!.isEmpty) return null;
    try {
      final u = Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'prop': 'extracts',
        'explaintext': '1',
        'titles': p.wikiTitle!,
        'format': 'json',
        'origin': '*',
        'redirects': '1',
      });
      final r = await http.get(u).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final pages = ((jsonDecode(r.body) as Map)['query']['pages'] as Map).values;
      if (pages.isEmpty) return null;
      final text = (pages.first['extract'] as String?) ?? '';
      final h = RegExp(r'^==\s*(History|Historical background|Etymology and history|Background)\s*==\s*$', multiLine: true, caseSensitive: false).firstMatch(text);
      if (h == null) return '';
      final rest = text.substring(h.end);
      final end = RegExp(r'^==\s*[^=].*?==\s*$', multiLine: true).firstMatch(rest);
      var body = (end == null ? rest : rest.substring(0, end.start)).trim();
      body = body.replaceAllMapped(RegExp(r'^===+\s*(.*?)\s*===+\s*$', multiLine: true), (m) => '${m[1]}:').replaceAll(RegExp(r'\n{3,}'), '\n\n');
      if (body.length > 5000) {
        final cut = body.lastIndexOf('.', 5000);
        body = body.substring(0, cut > 0 ? cut + 1 : 5000);
      }
      if (_c.auth.currentUser != null && body.isNotEmpty) {
        try {
          await _c.rpc('cache_history', params: {'p_place': p.id, 'p_text': body});
        } catch (_) {}
      }
      return body;
    } catch (_) {
      return null;
    }
  }
}
