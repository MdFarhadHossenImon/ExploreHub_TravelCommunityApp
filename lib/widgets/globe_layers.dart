import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Map detail for the globe when you zoom in: sharper coastlines, state / division and
/// district borders, and city, district and upazila names, like a map app.
/// Data: Natural Earth (public domain) for the world, geoBoundaries (BBS / OCHA, CC BY 3.0 IGO)
/// for Bangladesh's divisions, districts and upazilas. Loaded only when you first zoom in.
const _deg = math.pi / 180;

/// Many lines (or rings) packed together, with each point's sin/cos ready for projection
/// and each line's centre and angular radius for skipping what is off screen.
class GeoLines {
  final Float32List lonSin, lonCos, latSin, latCos;
  final Int32List start; // start[i]..start[i+1] are line i's points
  final Float32List cx, cy, cz, rad; // centre unit vector and radius (radians) per line
  GeoLines(this.lonSin, this.lonCos, this.latSin, this.latCos, this.start, this.cx, this.cy, this.cz, this.rad);

  int get length => start.length - 1;

  factory GeoLines.from(List lines) {
    var n = 0;
    for (final l in lines) {
      n += (l as List).length ~/ 2;
    }
    final a = Float32List(n), b = Float32List(n), s = Float32List(n), d = Float32List(n);
    final st = Int32List(lines.length + 1);
    final cx = Float32List(lines.length), cy = Float32List(lines.length), cz = Float32List(lines.length), rad = Float32List(lines.length);
    var k = 0;
    for (var i = 0; i < lines.length; i++) {
      final flat = (lines[i] as List).cast<num>();
      st[i] = k;
      var sx = 0.0, sy = 0.0, sz = 0.0;
      final from = k;
      for (var j = 0; j + 1 < flat.length; j += 2) {
        final lo = flat[j] * _deg, la = flat[j + 1] * _deg;
        a[k] = math.sin(lo);
        b[k] = math.cos(lo);
        s[k] = math.sin(la);
        d[k] = math.cos(la);
        sx += d[k] * b[k];
        sy += d[k] * a[k];
        sz += s[k];
        k++;
      }
      final m = math.sqrt(sx * sx + sy * sy + sz * sz);
      if (m > 0) {
        sx /= m;
        sy /= m;
        sz /= m;
      }
      var maxA = 0.0;
      for (var j = from; j < k; j++) {
        final dot = (d[j] * b[j] * sx + d[j] * a[j] * sy + s[j] * sz).clamp(-1.0, 1.0);
        maxA = math.max(maxA, math.acos(dot));
      }
      cx[i] = sx;
      cy[i] = sy;
      cz[i] = sz;
      rad[i] = maxA;
    }
    st[lines.length] = k;
    return GeoLines(a, b, s, d, st, cx, cy, cz, rad);
  }
}

class GeoLabel {
  final String name;
  final double lon, lat;
  final int rank; // lower shows first
  final bool capital, national;
  final double sl, cl, sp, cp;
  GeoLabel(this.name, this.lon, this.lat, this.rank, {this.capital = false, this.national = false})
      : sl = math.sin(lon * _deg),
        cl = math.cos(lon * _deg),
        sp = math.sin(lat * _deg),
        cp = math.cos(lat * _deg);
}

class GeoDetail {
  final GeoLines land, admin1, bdDiv, bdDist, bdUpa;
  final List<GeoLabel> admin1Labels, cities, bdDivLabels, bdDistLabels, bdUpaLabels;
  GeoDetail(this.land, this.admin1, this.bdDiv, this.bdDist, this.bdUpa, this.admin1Labels, this.cities, this.bdDivLabels, this.bdDistLabels, this.bdUpaLabels);

  static GeoDetail? cache;
  static Future<GeoDetail>? _loading;
  static Future<GeoDetail> load() => _loading ??= _load();

  static Future<GeoDetail> _load() async {
    Future<dynamic> j(String f) async => jsonDecode(await rootBundle.loadString('assets/$f'));
    final r = await Future.wait([j('geo_land50.json'), j('geo_admin1.json'), j('geo_cities.json'), j('geo_bd.json')]);
    final adm = r[1] as Map, bd = r[3] as Map;
    List<GeoLabel> bdLabels(List l) => [for (var i = 0; i < l.length; i++) GeoLabel(l[i]['n'], (l[i]['x'] as num).toDouble(), (l[i]['y'] as num).toDouble(), i)];
    return cache = GeoDetail(
      GeoLines.from(r[0] as List),
      GeoLines.from(adm['lines'] as List),
      GeoLines.from(bd['div'] as List),
      GeoLines.from(bd['dist'] as List),
      GeoLines.from(bd['upa'] as List),
      [for (final l in adm['labels'] as List) GeoLabel(l['n'], (l['x'] as num).toDouble(), (l['y'] as num).toDouble(), (l['k'] as num).toInt())],
      [
        for (final c in r[2] as List)
          GeoLabel(c['n'], (c['x'] as num).toDouble(), (c['y'] as num).toDouble(), (c['k'] as num).toInt(), capital: (c['c'] as num) > 0, national: (c['c'] as num) == 2)
      ],
      bdLabels(bd['divLabels'] as List),
      bdLabels(bd['distLabels'] as List),
      bdLabels(bd['upaLabels'] as List),
    );
  }
}

/// The current view, for projecting points onto the screen.
class GeoView {
  final Offset c;
  final double r, sl, cl, sp, cp;
  final Size size;
  final double vx, vy, vz, viewAng; // view centre unit vector; the angle (radians) that still reaches the screen corners
  GeoView(this.c, this.r, this.sl, this.cl, this.sp, this.cp, this.size)
      : vx = cp * cl,
        vy = cp * sl,
        vz = sp,
        viewAng = math.min(math.pi / 2, math.asin(math.min(1.0, math.sqrt(size.width * size.width + size.height * size.height) / 2 / r)) + .02);

  /// Pixels per degree at the centre: how far in we are, whatever the widget size.
  double get ppd => r * _deg;

  bool lineMaybeVisible(GeoLines g, int i) {
    final dot = g.cx[i] * vx + g.cy[i] * vy + g.cz[i] * vz;
    final ang = math.acos(dot.clamp(-1.0, 1.0));
    return ang - g.rad[i] < viewAng;
  }

  /// Screen point of a label, or null when it is behind the globe or too close to the edge.
  Offset? label(GeoLabel l, {double minCos = .25}) {
    final cosdl = l.cl * cl + l.sl * sl, sindl = l.sl * cl - l.cl * sl;
    final vis = sp * l.sp + cp * l.cp * cosdl;
    if (vis < minCos) return null;
    final o = Offset(c.dx + r * l.cp * sindl, c.dy - r * (cp * l.sp - sp * l.cp * cosdl));
    if (o.dx < -40 || o.dy < -20 || o.dx > size.width + 40 || o.dy > size.height + 20) return null;
    return o;
  }

  /// Stroke (or fill) the lines that can be seen.
  Path path(GeoLines g, {bool closed = false}) {
    final p = Path();
    for (var i = 0; i < g.length; i++) {
      if (!lineMaybeVisible(g, i)) continue;
      var pen = false;
      var any = false;
      final ring = Path();
      for (var k = g.start[i]; k < g.start[i + 1]; k++) {
        final a = g.lonSin[k], b = g.lonCos[k], s = g.latSin[k], d = g.latCos[k];
        final cosdl = b * cl + a * sl, sindl = a * cl - b * sl;
        final x = d * sindl, y = cp * s - sp * d * cosdl;
        final vis = sp * s + cp * d * cosdl > 0;
        if (closed) {
          var px = x, py = y;
          if (!vis) {
            final m = math.sqrt(x * x + y * y);
            if (m > 0) {
              px = x / m;
              py = y / m;
            }
          } else {
            any = true;
          }
          final o = Offset(c.dx + px * r, c.dy - py * r);
          pen ? ring.lineTo(o.dx, o.dy) : ring.moveTo(o.dx, o.dy);
          pen = true;
        } else {
          if (!vis) {
            pen = false;
            continue;
          }
          final o = Offset(c.dx + x * r, c.dy - y * r);
          pen ? p.lineTo(o.dx, o.dy) : p.moveTo(o.dx, o.dy);
          pen = true;
        }
      }
      if (closed && any) {
        ring.close();
        p.addPath(ring, Offset.zero);
      }
    }
    return p;
  }
}

/// Map-style text: a fill with a soft dark halo, cached by text and style.
class MapText {
  static final Map<String, (TextPainter, TextPainter)> _cache = {};

  static (TextPainter, TextPainter) of(String text, TextStyle style, {Color halo = const Color(0xE60B1F21), double haloWidth = 3, String kind = ''}) {
    return _cache.putIfAbsent('$kind|${style.fontSize}|$text', () {
      TextPainter tp(TextStyle s) => TextPainter(text: TextSpan(text: text, style: s), textDirection: TextDirection.ltr, maxLines: 2, textAlign: TextAlign.center)..layout(maxWidth: 170);
      final stroke = tp(style.copyWith(
          color: null,
          shadows: const [],
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = haloWidth
            ..strokeJoin = StrokeJoin.round
            ..color = halo));
      return (stroke, tp(style));
    });
  }

  static void paint(Canvas canvas, (TextPainter, TextPainter) t, Offset topLeft) {
    t.$1.paint(canvas, topLeft);
    t.$2.paint(canvas, topLeft);
  }
}
