import 'dart:convert';
import '../core/currency.dart';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/i18n.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../core/theme.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../screens/place_detail.dart';
import 'common.dart';
import 'globe_layers.dart';

const _deg = math.pi / 180;
const _maxZoom = 60.0; // close enough to read upazila names

/// Country outlines (Natural Earth 1:110m, public domain), loaded once.
class _Country {
  final String name;
  final double lon, lat; // degrees, label point
  final int rank; // 2 = largest countries ... 7 = smallest
  final double area; // square degrees, to label big countries first
  const _Country(this.name, this.lon, this.lat, this.rank, this.area);
}

class _World {
  final List<Float32List> lonSin, lonCos, latSin, latCos; // per ring, per point
  final List<_Country> countries;
  _World(this.lonSin, this.lonCos, this.latSin, this.latCos, this.countries);

  static _World? _cache;
  static Future<_World> load() async {
    if (_cache != null) return _cache!;
    final data = jsonDecode(await rootBundle.loadString('assets/world.json')) as List;
    final ls = <Float32List>[], lc = <Float32List>[], ps = <Float32List>[], pc = <Float32List>[];
    final countries = <_Country>[];
    for (final c in data) {
      var area = 0.0;
      for (final r in (c['r'] as List)) {
        final f = (r as List).cast<num>();
        for (var i = 0; i + 3 < f.length; i += 2) {
          area += f[i] * f[i + 3] - f[i + 2] * f[i + 1];
        }
      }
      countries.add(_Country(c['n'] as String, (c['x'] as num).toDouble(), (c['y'] as num).toDouble(), (c['k'] as num).toInt(), area.abs() / 2));
      for (final r in (c['r'] as List)) {
        final flat = (r as List).cast<num>();
        final n = flat.length ~/ 2;
        final a = Float32List(n), b = Float32List(n), s = Float32List(n), d = Float32List(n);
        for (var i = 0; i < n; i++) {
          final lon = flat[i * 2] * _deg, lat = flat[i * 2 + 1] * _deg;
          a[i] = math.sin(lon);
          b[i] = math.cos(lon);
          s[i] = math.sin(lat);
          d[i] = math.cos(lat);
        }
        ls.add(a);
        lc.add(b);
        ps.add(s);
        pc.add(d);
      }
    }
    return _cache = _World(ls, lc, ps, pc, countries..sort((a, b) => a.rank != b.rank ? a.rank.compareTo(b.rank) : b.area.compareTo(a.area)));
  }
}

/// Interactive 3D globe: drag to spin, pinch to zoom, tap a place to fly there.
class ExploreGlobe extends StatefulWidget {
  final double height;
  final bool fullscreen;
  const ExploreGlobe({super.key, this.height = 380, this.fullscreen = false});
  @override
  State<ExploreGlobe> createState() => _ExploreGlobeState();
}

class _ExploreGlobeState extends State<ExploreGlobe> with TickerProviderStateMixin {
  _World? _world;
  double _lon = 90, _lat = 20, _zoom = 1; // view centre and zoom
  double _vLon = 0, _vLat = 0; // fling velocity, degrees per second
  double _startZoom = 1;
  Offset? _lastFocal;
  DateTime _lastTouch = DateTime.fromMillisecondsSinceEpoch(0);
  late final Ticker _ticker;
  Duration _prev = Duration.zero;

  late final AnimationController _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  late final AnimationController _pin = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  double _fLon0 = 0, _fLat0 = 0, _fZ0 = 1, _fLon1 = 0, _fLat1 = 0, _fZ1 = 1;
  Place? _sel;
  bool _panel = false;
  final List<(Place, Offset)> _hits = [];

  @override
  void initState() {
    super.initState();
    _World.load().then((w) {
      if (mounted) setState(() => _world = w);
    });
    _ticker = createTicker(_tick)..start();
    _fly.addListener(() {
      final t = Curves.easeInOutCubic.transform(_fly.value);
      final zt = math.sin(t * math.pi); // pull back a little mid-flight
      setState(() {
        _lon = _fLon0 + (_fLon1 - _fLon0) * t;
        _lat = _fLat0 + (_fLat1 - _fLat0) * t;
        _zoom = (_fZ0 + (_fZ1 - _fZ0) * t) * (1 - .18 * zt);
      });
    });
    _fly.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _pin.forward(from: 0);
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) setState(() => _panel = true);
        });
      }
    });
    _pin.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _fly.dispose();
    _pin.dispose();
    super.dispose();
  }

  bool _onScreen = true;
  final _visKey = UniqueKey();

  void _tick(Duration now) {
    final dt = ((now - _prev).inMicroseconds / 1e6).clamp(0.0, .05);
    _prev = now;
    if (!_onScreen || _fly.isAnimating || _lastFocal != null) return;
    var changed = false;
    if (_vLon.abs() > .5 || _vLat.abs() > .5) {
      _lon += _vLon * dt;
      _lat = (_lat + _vLat * dt).clamp(-80.0, 80.0);
      final k = math.pow(.04, dt).toDouble(); // decay
      _vLon *= k;
      _vLat *= k;
      changed = true;
    } else if (_sel == null && _zoom < 2 && DateTime.now().difference(_lastTouch).inSeconds > 3) {
      _lon += 6 * dt / _zoom; // idle spin
      changed = true;
    }
    if (changed) setState(() {});
  }

  double get _radiusFactor => .42;

  void _flyTo(Place p) => _flyToPoint(p.lng!, p.lat!, math.max(_zoom, 2.4), p);

  void _flyToPoint(double lng, double lat, double zoom, Place? p) {
    _fLon0 = _lon;
    _fLat0 = _lat;
    _fZ0 = _zoom;
    var d = (lng - _lon) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    _fLon1 = _lon + d;
    _fLat1 = lat.clamp(-75.0, 75.0);
    _fZ1 = zoom;
    _vLon = _vLat = 0;
    _lastTouch = DateTime.now();
    setState(() {
      _sel = p;
      _panel = false;
    });
    _pin.value = 0;
    _fly.forward(from: 0);
  }

  bool _searching = false;

  Widget _searchBox(List<Place> pts) {
    final countries = _world?.countries ?? const <_Country>[];
    return Material(
      color: C.card,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Autocomplete<Object>(
        displayStringForOption: (o) => o is Place ? o.name : (o as _Country).name,
        optionsBuilder: (v) {
          final q = v.text.trim().toLowerCase();
          if (q.length < 2) return const <Object>[];
          final cs = countries.where((c) => c.name.toLowerCase().startsWith(q)).take(3);
          final ps = pts.where((p) => p.name.toLowerCase().contains(q) || p.location.toLowerCase().contains(q) || p.country.toLowerCase().startsWith(q)).take(12);
          return [...cs, ...ps];
        },
        optionsViewBuilder: (context, select, opts) => Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: C.card,
              elevation: 8,
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340, maxWidth: 520),
                child: ListView(padding: EdgeInsets.zero, shrinkWrap: true, children: [
                  for (final o in opts)
                    ListTile(
                      dense: true,
                      leading: Icon(o is Place ? Icons.place_rounded : Icons.flag_rounded, color: C.primary),
                      title: Text(o is Place ? o.name : (o as _Country).name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(o is Place ? o.where : tr('Country'), style: const TextStyle(fontSize: 11.5)),
                      onTap: () => select(o),
                    ),
                ]),
              ),
            ),
          ),
        ),
        onSelected: (o) {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() => _searching = false);
          if (o is Place) {
            _flyTo(o);
          } else if (o is _Country) {
            _flyToPoint(o.lon, o.lat, o.rank <= 3 ? 1.9 : 2.8, null);
          }
        },
        fieldViewBuilder: (context, ctl, focus, submit) => TextField(
          controller: ctl,
          focusNode: focus,
          autofocus: true,
          decoration: InputDecoration(
            hintText: tr('Search a place or country'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _searching = false)),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
      ),
    );
  }

  void _tap(Offset pos) {
    _lastTouch = DateTime.now();
    Place? best;
    var bd = 26.0 * 26.0;
    for (final (p, o) in _hits) {
      final d = (o - pos).distanceSquared;
      if (d < bd) {
        bd = d;
        best = p;
      }
    }
    if (best != null) {
      _flyTo(best);
    } else if (_sel != null) {
      setState(() {
        _sel = null;
        _panel = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pts = places.where((p) => p.lat != null && p.lng != null).toList();
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(builder: (context, box) {
        final size = Size(box.maxWidth, widget.height);
        final r = math.min(size.width, size.height) * _radiusFactor * _zoom;
        if (_zoom > 1.6 && GeoDetail.cache == null) {
          GeoDetail.load().then((_) {
            if (mounted) setState(() {});
          });
        }
        return Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _tap(d.localPosition),
              onScaleStart: (d) {
                _fly.stop();
                _lastFocal = d.localFocalPoint;
                _startZoom = _zoom;
                _vLon = _vLat = 0;
                _lastTouch = DateTime.now();
              },
              onScaleUpdate: (d) {
                final last = _lastFocal ?? d.localFocalPoint;
                final delta = d.localFocalPoint - last;
                _lastFocal = d.localFocalPoint;
                setState(() {
                  _lon -= delta.dx / r / _deg;
                  _lat = (_lat + delta.dy / r / _deg).clamp(-80.0, 80.0);
                  if (d.pointerCount > 1) _zoom = (_startZoom * d.scale).clamp(.8, _maxZoom);
                });
                _lastTouch = DateTime.now();
              },
              onScaleEnd: (d) {
                _lastFocal = null;
                final v = d.velocity.pixelsPerSecond;
                _vLon = -v.dx / r / _deg * .6;
                _vLat = v.dy / r / _deg * .6;
                _lastTouch = DateTime.now();
              },
              child: Listener(
                onPointerSignal: (e) {
                  if (widget.fullscreen && e is PointerScrollEvent) {
                    setState(() => _zoom = (_zoom * (e.scrollDelta.dy > 0 ? .9 : 1.1)).clamp(.8, _maxZoom));
                  }
                },
                child: RepaintBoundary(
                  child: VisibilityDetector(
                    key: _visKey,
                    onVisibilityChanged: (v) => _onScreen = v.visibleFraction > 0.05,
                    child: CustomPaint(
                      size: size,
                      painter: _GlobePainter(
                        world: _world,
                        geo: GeoDetail.cache,
                        places: pts,
                        lon: _lon,
                        lat: _lat,
                        radius: r,
                        zoom: _zoom,
                        selected: _sel,
                        pin: _sel != null && !_fly.isAnimating ? _pin.value : 0,
                        hits: _hits,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.fullscreen && !_searching) Positioned(right: 10, top: 10, child: _roundBtn(Icons.search_rounded, () => setState(() => _searching = true))),
          if (widget.fullscreen && _searching) Positioned(left: 60, right: 10, top: 6, child: _searchBox(pts)),
          Positioned(
            right: 10,
            top: widget.fullscreen ? 70 : 10,
            child: Column(children: [
              _roundBtn(Icons.add_rounded, () => setState(() => _zoom = (_zoom * 1.6).clamp(.8, _maxZoom))),
              const SizedBox(height: 8),
              _roundBtn(Icons.remove_rounded, () => setState(() => _zoom = (_zoom / 1.6).clamp(.8, _maxZoom))),
              const SizedBox(height: 8),
              if (!widget.fullscreen) _roundBtn(Icons.fullscreen_rounded, () => go(context, const GlobeScreen())),
            ]),
          ),
          if (GeoDetail.cache != null && _zoom > 3)
            Positioned(
              right: 12,
              bottom: _sel != null && _panel ? 150 : 12,
              child: IgnorePointer(
                child: Text('Map data: Natural Earth · geoBoundaries.org', style: TextStyle(color: C.muted.withValues(alpha: .8), fontSize: 9)),
              ),
            ),
          if (_sel == null && !(GeoDetail.cache != null && _zoom > 3))
            Positioned(
              left: 14,
              bottom: 12,
              child: IgnorePointer(
                child: Row(children: [
                  Icon(Icons.touch_app_rounded, size: 15, color: C.muted),
                  SizedBox(width: 5),
                  Text(tr('Spin the globe and tap a place'), style: TextStyle(color: C.muted, fontSize: 12)),
                ]),
              ),
            ),
          if (_sel != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              left: 12,
              right: 12,
              bottom: _panel ? 12 : -180,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _panel ? 1 : 0,
                child: _PlacePanel(_sel!,
                    onClose: () => setState(() {
                          _sel = null;
                          _panel = false;
                        })),
              ),
            ),
        ]);
      }),
    );
  }

  Widget _roundBtn(IconData i, VoidCallback on) => Material(
        color: C.card.withValues(alpha: .85),
        shape: const CircleBorder(side: BorderSide(color: C.line)),
        child: InkWell(customBorder: const CircleBorder(), onTap: on, child: Padding(padding: const EdgeInsets.all(8), child: Icon(i, size: 20, color: Colors.white))),
      );
}

class _PlacePanel extends StatelessWidget {
  final Place p;
  final VoidCallback onClose;
  const _PlacePanel(this.p, {required this.onClose});
  @override
  Widget build(BuildContext context) => Material(
        color: C.card,
        elevation: 10,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => go(context, PlaceDetailScreen(place: p)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              AppImage(p.photo, width: 92, height: 92, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: C.primary),
                    const SizedBox(width: 3),
                    Expanded(child: Text(p.where, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 12))),
                  ]),
                  const SizedBox(height: 6),
                  Wrap(spacing: 10, children: [
                    if (p.rating > 0) RatingText(p.rating),
                    Text(p.category, style: const TextStyle(fontSize: 12)),
                    if (p.dailyBudget > 0) Text('from ${moneyApprox(p.dailyBudget)}/day', style: const TextStyle(fontSize: 12, color: C.primary, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 6),
                  Text(tr('Tap for photos, budget, weather and how to get there'), style: TextStyle(color: C.muted, fontSize: 11)),
                ]),
              ),
              Column(children: [
                IconButton(visualDensity: VisualDensity.compact, onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 20, color: C.muted)),
                const Icon(Icons.chevron_right_rounded, color: C.primary),
              ]),
            ]),
          ),
        ),
      );
}

class _GlobePainter extends CustomPainter {
  final _World? world;
  final GeoDetail? geo;
  final List<Place> places;
  final double lon, lat, radius, zoom, pin;
  final Place? selected;
  final List<(Place, Offset)> hits;
  _GlobePainter({
    required this.world,
    required this.geo,
    required this.places,
    required this.lon,
    required this.lat,
    required this.radius,
    required this.zoom,
    required this.selected,
    required this.pin,
    required this.hits,
  });


  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = radius;
    final sl = math.sin(lon * _deg), cl = math.cos(lon * _deg);
    final sp = math.sin(lat * _deg), cp = math.cos(lat * _deg);

    // atmosphere glow + ocean
    canvas.drawCircle(c, r * 1.08,
        Paint()..shader = RadialGradient(colors: [C.primary.withValues(alpha: .22), C.primary.withValues(alpha: 0)], stops: const [.86, 1]).createShader(Rect.fromCircle(center: c, radius: r * 1.08)));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(center: const Alignment(-.35, -.4), radius: 1.1, colors: const [Color(0xFF2F6E73), Color(0xFF16393C), Color(0xFF0C2224)], stops: const [0, .6, 1])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));

    // graticule
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6
      ..color = Colors.white.withValues(alpha: .06);
    for (var g = -150; g <= 180; g += 30) {
      _line(canvas, c, r, sl, cl, sp, cp, [for (var la = -90; la <= 90; la += 5) (g * _deg, la * _deg)], grid);
    }
    for (var g = -60; g <= 60; g += 30) {
      _line(canvas, c, r, sl, cl, sp, cp, [for (var lo = -180; lo <= 180; lo += 5) (lo * _deg, g * _deg)], grid);
    }

    final view = GeoView(c, r, sl, cl, sp, cp, size);
    final ppd = view.ppd; // pixels per degree: how far in we are
    final g = geo;
    final hiLand = g != null && ppd >= 9;

    // land
    final w = world;
    if (hiLand) {
      // sharper coastlines and borders when zoomed in
      canvas.drawPath(view.path(g.land, closed: true), Paint()..color = const Color(0xFF3F7A64));
      canvas.drawPath(
          view.path(g.land),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFFA9D6BC).withValues(alpha: .7));
    } else if (w != null) {
      final fill = Paint()..color = const Color(0xFF3F7A64);
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = const Color(0xFF8CC3A5).withValues(alpha: .55);
      final land = Path(), edges = Path();
      for (var k = 0; k < w.lonSin.length; k++) {
        final a = w.lonSin[k], b = w.lonCos[k], s = w.latSin[k], d = w.latCos[k];
        final ring = Path();
        final line = Path();
        var anyVisible = false, pen = false;
        for (var i = 0; i < a.length; i++) {
          final cosdl = b[i] * cl + a[i] * sl; // cos(lon - lon0)
          final sindl = a[i] * cl - b[i] * sl; // sin(lon - lon0)
          final x = d[i] * sindl;
          final y = cp * s[i] - sp * d[i] * cosdl;
          final vis = sp * s[i] + cp * d[i] * cosdl > 0;
          var px = x, py = y;
          if (!vis) {
            final m = math.sqrt(x * x + y * y);
            if (m > 0) {
              px = x / m;
              py = y / m;
            }
          } else {
            anyVisible = true;
          }
          final o = Offset(c.dx + px * r, c.dy - py * r);
          i == 0 ? ring.moveTo(o.dx, o.dy) : ring.lineTo(o.dx, o.dy);
          if (vis) {
            pen ? line.lineTo(o.dx, o.dy) : line.moveTo(o.dx, o.dy);
            pen = true;
          } else {
            pen = false;
          }
        }
        if (!anyVisible) continue;
        ring.close();
        land.addPath(ring, Offset.zero);
        edges.addPath(line, Offset.zero);
      }
      canvas.drawPath(land, fill);
      canvas.drawPath(edges, border);
    }

    // states and provinces, then Bangladesh's upazilas, districts and divisions
    if (g != null) {
      Paint stroke(double width, Color color, double a) => Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: a);
      final aA = ((ppd - 8) / 6).clamp(0.0, 1.0);
      if (aA > 0) canvas.drawPath(view.path(g.admin1), stroke(.8, const Color(0xFFD4EADD), .30 * aA));
      final uA = ((ppd - 70) / 30).clamp(0.0, 1.0);
      if (uA > 0) canvas.drawPath(view.path(g.bdUpa), stroke(.6, const Color(0xFFD4EADD), .22 * uA));
      final tA = ((ppd - 14) / 8).clamp(0.0, 1.0);
      if (tA > 0) canvas.drawPath(view.path(g.bdDist), stroke(.9, const Color(0xFFD4EADD), .42 * tA));
      final vA = ((ppd - 6) / 4).clamp(0.0, 1.0);
      if (vA > 0) canvas.drawPath(view.path(g.bdDiv), stroke(1.4, const Color(0xFFE9D9B8), .55 * vA));
    }

    // shading: light from the top-left, dark limb
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
            center: const Alignment(-.3, -.35),
            radius: 1.05,
            colors: [Colors.white.withValues(alpha: .10), Colors.transparent, Colors.black.withValues(alpha: .45)],
            stops: const [0, .55, 1]).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // places
    hits.clear();
    final dot = Paint()..color = C.primary;
    final halo = Paint()..color = C.primary.withValues(alpha: .25);
    final visible = <(Place, Offset, double)>[];
    for (final p in places) {
      final la = p.lat! * _deg, lo = p.lng! * _deg;
      final sla = math.sin(la), cla = math.cos(la);
      final dl = lo - lon * _deg;
      final cosc = sp * sla + cp * cla * math.cos(dl);
      if (cosc < .08) continue;
      final o = Offset(c.dx + r * cla * math.sin(dl), c.dy - r * (cp * sla - sp * cla * math.cos(dl)));
      visible.add((p, o, cosc));
      hits.add((p, o));
    }
    final dr = (1.6 + zoom * .35).clamp(1.8, 4.0);
    for (final (_, o, cosc) in visible) {
      canvas.drawCircle(o, dr * 2.2 * cosc, halo);
      canvas.drawCircle(o, dr * cosc + .4, dot);
    }
    canvas.restore();

    final taken = <Rect>[];
    bool room(Rect rect) {
      if (rect.left < 2 || rect.top < 2 || rect.right > size.width - 2 || rect.bottom > size.height - 2) return false;
      if (taken.any((t) => t.overlaps(rect))) return false;
      taken.add(rect);
      return true;
    }

    TextStyle font(double size, FontWeight weight, Color color, {double spacing = 0}) =>
        GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing, height: 1.15);

    /// A centred map label (countries, divisions, districts, states).
    void area(String text, Offset o, TextStyle st, String kind, {double halo = 3}) {
      final t = MapText.of(text, st, kind: kind, haloWidth: halo);
      final rect = Rect.fromCenter(center: o, width: t.$2.width, height: t.$2.height).inflate(2);
      if (room(rect)) MapText.paint(canvas, t, rect.topLeft + const Offset(2, 2));
    }

    // country names: lie on the globe's surface (they curve and foreshorten with it, like a real globe),
    // in a light, letter-spaced face with a soft halo; they fade out once cities take over
    final cAlpha = (1 - (ppd - 22) / 18).clamp(0.0, 1.0);
    if (w != null && cAlpha > 0) {
      final maxRank = ppd < 3.3 ? 3 : (ppd < 4.6 ? 4 : (ppd < 7 ? 5 : 7));
      final grow = 1 + (ppd - 2.8).clamp(0.0, 12.0) * .035;
      canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: cAlpha));
      for (final ct in w.countries) {
        if (ct.rank > maxRank) continue;
        final la = ct.lat * _deg, dl = ct.lon * _deg - lon * _deg;
        final sla = math.sin(la), cla = math.cos(la), sdl = math.sin(dl), cdl = math.cos(dl);
        final cosc = sp * sla + cp * cla * cdl;
        if (cosc < .28) continue;
        final o = Offset(c.dx + r * cla * sdl, c.dy - r * (cp * sla - sp * cla * cdl));
        final fs = ((ct.rank <= 2 ? 11.0 : ct.rank == 3 ? 10.0 : 9.0) * grow * 2).round() / 2;
        final t = MapText.of(ct.name.toUpperCase(), font(fs, FontWeight.w600, const Color(0xFFF7EFE2), spacing: ct.rank <= 3 ? 2.0 : 1.4), kind: 'country3d', halo: const Color(0xA60B1F21), haloWidth: 2.6);
        // the surface's east and south directions on screen at this point
        final ex = cdl, ey = -sp * sdl;
        final sx = sla * sdl, sy = cp * cla + sp * sla * cdl;
        final tw = t.$2.width, th = t.$2.height;
        // room check with the label's projected footprint
        final hw = (tw / 2 * ex.abs() + th / 2 * sx.abs()), hh = (tw / 2 * ey.abs() + th / 2 * sy.abs());
        final rect = Rect.fromCenter(center: o, width: hw * 2, height: hh * 2).inflate(2);
        if (!room(rect)) continue;
        canvas.save();
        canvas.transform(Float64List.fromList([ex, ey, 0, 0, sx, sy, 0, 0, 0, 0, 1, 0, o.dx, o.dy, 0, 1]));
        MapText.paint(canvas, t, Offset(-tw / 2, -th / 2));
        canvas.restore();
      }
      canvas.restore();
    }

    // place names: fade in as you zoom in, most popular first, skip overlaps
    final pAlpha = ((zoom - 1.4) / .7).clamp(0.0, 1.0);
    if (pAlpha > 0) {
      final budget = (6 + zoom * zoom * 5).round().clamp(6, 30);
      visible.sort((x, y) => (y.$1.popularity ?? (y.$1.rating * 1000).round()).compareTo(x.$1.popularity ?? (x.$1.rating * 1000).round()));
      canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: pAlpha));
      var shown = 0;
      for (final (p, o, cosc) in visible) {
        if (shown >= budget || cosc < .35) continue;
        if (selected?.id == p.id) continue;
        final t = MapText.of(p.name.length > 22 ? '${p.name.substring(0, 21)}…' : p.name, font(10.5, FontWeight.w700, const Color(0xFFFFC98B)), kind: 'place');
        var rect = Rect.fromLTWH(o.dx + 6, o.dy - t.$2.height / 2, t.$2.width, t.$2.height).inflate(2);
        if (!room(rect)) {
          rect = Rect.fromLTWH(o.dx - 6 - t.$2.width, o.dy - t.$2.height / 2, t.$2.width, t.$2.height).inflate(2);
          if (!room(rect)) continue;
        }
        MapText.paint(canvas, t, rect.topLeft + const Offset(2, 2));
        shown++;
      }
      canvas.restore();
    }

    // cities and towns: a dot and the name beside it, bigger places first, more as you zoom in
    if (g != null) {
      final cityMax = ppd < 4 ? -1 : ppd < 6 ? 1 : ppd < 9 ? 2 : ppd < 13 ? 3 : ppd < 20 ? 5 : ppd < 32 ? 7 : ppd < 55 ? 9 : 11;
      var shown = 0;
      final dotFill = Paint()..color = const Color(0xFFFDF8F0);
      final dotEdge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF0B1F21);
      for (final ct in g.cities) {
        if (ct.rank > cityMax || shown >= 45) break;
        final o = view.label(ct, minCos: .2);
        if (o == null) continue;
        final big = ct.rank <= 2 || ct.national;
        final st = font(big ? 12.5 : (ct.rank <= 5 ? 11.5 : 10.5), ct.national ? FontWeight.w800 : (big ? FontWeight.w700 : FontWeight.w600), Colors.white);
        final t = MapText.of(ct.name, st, kind: 'city');
        final w2 = t.$2.width, h2 = t.$2.height;
        var rect = Rect.fromLTWH(o.dx + 6, o.dy - h2 / 2, w2, h2).inflate(1.5);
        final dotRect = Rect.fromCircle(center: o, radius: 4);
        if (taken.any((x) => x.overlaps(dotRect))) continue;
        if (!room(rect)) {
          rect = Rect.fromLTWH(o.dx - 6 - w2, o.dy - h2 / 2, w2, h2).inflate(1.5);
          if (!room(rect)) continue;
        }
        taken.add(dotRect);
        if (ct.national) {
          canvas.drawCircle(o, 4.2, dotFill);
          canvas.drawCircle(o, 4.2, dotEdge);
          canvas.drawCircle(o, 1.6, Paint()..color = const Color(0xFF0B1F21));
        } else {
          canvas.drawCircle(o, ct.capital ? 3 : 2.4, dotFill);
          canvas.drawCircle(o, ct.capital ? 3 : 2.4, dotEdge);
        }
        MapText.paint(canvas, t, rect.topLeft + const Offset(1.5, 1.5));
        shown++;
      }
    }

    if (g != null) {
      // Bangladesh: divisions, then districts, then upazilas
      if (ppd >= 7 && ppd < 30) {
        for (final l in g.bdDivLabels) {
          final o = view.label(l);
          if (o != null) area('${l.name.toUpperCase()} DIVISION', o.translate(0, 14), font(9.5, FontWeight.w700, const Color(0xFFEAD9B6), spacing: 1.8), 'div');
        }
      }
      if (ppd >= 16) {
        for (final l in g.bdDistLabels) {
          final o = view.label(l);
          if (o != null) area(l.name, o, font(ppd >= 40 ? 11.5 : 10.5, FontWeight.w600, const Color(0xFFE8F1EC), spacing: .3), 'dist');
        }
      }
      // states and provinces elsewhere
      if (ppd >= 10) {
        final maxK = ppd < 16 ? 3 : ppd < 28 ? 5 : ppd < 45 ? 7 : 10;
        for (final l in g.admin1Labels) {
          if (l.rank > maxK) continue;
          final o = view.label(l);
          if (o != null) area(l.name.toUpperCase(), o, font(9.5, FontWeight.w600, const Color(0xFFBCD6C8), spacing: 1.5), 'adm1');
        }
      }
      if (ppd >= 70) {
        for (final l in g.bdUpaLabels) {
          final o = view.label(l);
          if (o != null) area(l.name, o, font(9.5, FontWeight.w500, const Color(0xFFC9DDD2)), 'upa', halo: 2.5);
        }
      }
    }

    // selected place: ripple + dropping pin
    final s = selected;
    if (s != null && pin > 0) {
      final la = s.lat! * _deg, dl = s.lng! * _deg - lon * _deg;
      final cosc = sp * math.sin(la) + cp * math.cos(la) * math.cos(dl);
      if (cosc > 0) {
        final o = Offset(c.dx + r * math.cos(la) * math.sin(dl), c.dy - r * (cp * math.sin(la) - sp * math.cos(la) * math.cos(dl)));
        final drop = Curves.bounceOut.transform((pin * 1.4).clamp(0.0, 1.0));
        final rip = ((pin - .45) / .55).clamp(0.0, 1.0);
        if (rip > 0) {
          canvas.drawOval(
            Rect.fromCenter(center: o, width: 70 * rip, height: 26 * rip),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = C.primary.withValues(alpha: 1 - rip),
          );
        }
        canvas.drawOval(Rect.fromCenter(center: o, width: 16 * drop, height: 6 * drop), Paint()..color = Colors.black.withValues(alpha: .45 * drop));
        final tip = Offset(o.dx, o.dy - (1 - drop) * 120);
        _pinShape(canvas, tip, 34);
        final label = TextPainter(
          text: TextSpan(text: s.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 220);
        if (drop > .95) label.paint(canvas, Offset(tip.dx - label.width / 2, tip.dy - 34 * 1.45 - label.height - 2));
      }
    }
  }

  void _pinShape(Canvas canvas, Offset tip, double h) {
    final w = h * .72;
    final top = tip.dy - h * 1.35;
    final p = Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(tip.dx - w * .25, tip.dy - h * .45, tip.dx - w / 2, top + w * .75, tip.dx - w / 2, top + w / 2)
      ..arcToPoint(Offset(tip.dx + w / 2, top + w / 2), radius: Radius.circular(w / 2))
      ..cubicTo(tip.dx + w / 2, top + w * .75, tip.dx + w * .25, tip.dy - h * .45, tip.dx, tip.dy)
      ..close();
    canvas.drawShadow(p, Colors.black, 4, false);
    canvas.drawPath(
      p,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF6B5E), Color(0xFFD7352B)])
            .createShader(Rect.fromLTRB(tip.dx - w / 2, top, tip.dx + w / 2, tip.dy)),
    );
    canvas.drawCircle(Offset(tip.dx, top + w / 2), w * .2, Paint()..color = Colors.white);
  }

  void _line(Canvas canvas, Offset c, double r, double sl, double cl, double sp, double cp, List<(double, double)> pts, Paint paint) {
    final path = Path();
    var pen = false;
    for (final (lo, la) in pts) {
      final a = math.sin(lo), b = math.cos(lo), s = math.sin(la), d = math.cos(la);
      final cosdl = b * cl + a * sl, sindl = a * cl - b * sl;
      if (sp * s + cp * d * cosdl <= 0) {
        pen = false;
        continue;
      }
      final o = Offset(c.dx + r * d * sindl, c.dy - r * (cp * s - sp * d * cosdl));
      pen ? path.lineTo(o.dx, o.dy) : path.moveTo(o.dx, o.dy);
      pen = true;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GlobePainter o) => true;
}

/// Full-screen globe.
class GlobeScreen extends StatelessWidget {
  const GlobeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => Stack(children: [
              ExploreGlobe(height: box.maxHeight, fullscreen: true),
              const Positioned(left: 8, top: 8, child: BackCircle()),
            ]),
          ),
        ),
      );
}
