import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../screens/place_detail.dart';
import 'common.dart';

const _deg = math.pi / 180;

/// Country outlines (Natural Earth 1:110m, public domain), loaded once.
class _World {
  final List<Float32List> lonSin, lonCos, latSin, latCos; // per ring, per point
  _World(this.lonSin, this.lonCos, this.latSin, this.latCos);

  static _World? _cache;
  static Future<_World> load() async {
    if (_cache != null) return _cache!;
    final data = jsonDecode(await rootBundle.loadString('assets/world.json')) as List;
    final ls = <Float32List>[], lc = <Float32List>[], ps = <Float32List>[], pc = <Float32List>[];
    for (final c in data) {
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
    return _cache = _World(ls, lc, ps, pc);
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

  void _tick(Duration now) {
    final dt = ((now - _prev).inMicroseconds / 1e6).clamp(0.0, .05);
    _prev = now;
    if (_fly.isAnimating || _lastFocal != null) return;
    var changed = false;
    if (_vLon.abs() > .5 || _vLat.abs() > .5) {
      _lon += _vLon * dt;
      _lat = (_lat + _vLat * dt).clamp(-80.0, 80.0);
      final k = math.pow(.04, dt).toDouble(); // decay
      _vLon *= k;
      _vLat *= k;
      changed = true;
    } else if (_sel == null && DateTime.now().difference(_lastTouch).inSeconds > 3) {
      _lon += 6 * dt / _zoom; // idle spin
      changed = true;
    }
    if (changed) setState(() {});
  }

  double get _radiusFactor => .42;

  void _flyTo(Place p) {
    _fLon0 = _lon;
    _fLat0 = _lat;
    _fZ0 = _zoom;
    var d = (p.lng! - _lon) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    _fLon1 = _lon + d;
    _fLat1 = p.lat!.clamp(-75.0, 75.0);
    _fZ1 = math.max(_zoom, 2.4);
    _vLon = _vLat = 0;
    setState(() {
      _sel = p;
      _panel = false;
    });
    _pin.value = 0;
    _fly.forward(from: 0);
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
                  if (d.pointerCount > 1) _zoom = (_startZoom * d.scale).clamp(.8, 9.0);
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
                    setState(() => _zoom = (_zoom * (e.scrollDelta.dy > 0 ? .9 : 1.1)).clamp(.8, 9.0));
                  }
                },
                child: CustomPaint(
                  size: size,
                  painter: _GlobePainter(
                    world: _world,
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
          Positioned(
            right: 10,
            top: 10,
            child: Column(children: [
              _roundBtn(Icons.add_rounded, () => setState(() => _zoom = (_zoom * 1.4).clamp(.8, 9.0))),
              const SizedBox(height: 8),
              _roundBtn(Icons.remove_rounded, () => setState(() => _zoom = (_zoom / 1.4).clamp(.8, 9.0))),
              const SizedBox(height: 8),
              if (!widget.fullscreen) _roundBtn(Icons.fullscreen_rounded, () => go(context, const GlobeScreen())),
            ]),
          ),
          if (_sel == null)
            const Positioned(
              left: 14,
              bottom: 12,
              child: IgnorePointer(
                child: Row(children: [
                  Icon(Icons.touch_app_rounded, size: 15, color: C.muted),
                  SizedBox(width: 5),
                  Text('Spin the globe and tap a place', style: TextStyle(color: C.muted, fontSize: 12)),
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
                child: _PlacePanel(_sel!, onClose: () => setState(() {
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
                    if (p.dailyBudget > 0) Text('from \$${p.dailyBudget}/day', style: const TextStyle(fontSize: 12, color: C.primary, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 6),
                  const Text('Tap for photos, budget, weather and how to get there', style: TextStyle(color: C.muted, fontSize: 11)),
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
  final List<Place> places;
  final double lon, lat, radius, zoom, pin;
  final Place? selected;
  final List<(Place, Offset)> hits;
  _GlobePainter({
    required this.world,
    required this.places,
    required this.lon,
    required this.lat,
    required this.radius,
    required this.zoom,
    required this.selected,
    required this.pin,
    required this.hits,
  });

  static final Map<String, TextPainter> _labels = {};

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = radius;
    final sl = math.sin(lon * _deg), cl = math.cos(lon * _deg);
    final sp = math.sin(lat * _deg), cp = math.cos(lat * _deg);

    // atmosphere glow + ocean
    canvas.drawCircle(c, r * 1.08, Paint()..shader = RadialGradient(colors: [C.primary.withValues(alpha: .22), C.primary.withValues(alpha: 0)], stops: const [.86, 1]).createShader(Rect.fromCircle(center: c, radius: r * 1.08)));
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

    // land
    final w = world;
    if (w != null) {
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

    // shading: light from the top-left, dark limb
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(center: const Alignment(-.3, -.35), radius: 1.05, colors: [Colors.white.withValues(alpha: .10), Colors.transparent, Colors.black.withValues(alpha: .45)], stops: const [0, .55, 1])
            .createShader(Rect.fromCircle(center: c, radius: r)),
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

    // labels: most popular first, skip overlaps
    final budget = (8 + zoom * zoom * 6).round().clamp(8, 70);
    visible.sort((x, y) => (y.$1.popularity ?? (y.$1.rating * 1000).round()).compareTo(x.$1.popularity ?? (x.$1.rating * 1000).round()));
    final taken = <Rect>[];
    var shown = 0;
    for (final (p, o, cosc) in visible) {
      if (shown >= budget || cosc < .35) continue;
      if (selected?.id == p.id) continue;
      final tp = _labels.putIfAbsent(
        p.id,
        () => TextPainter(
          text: TextSpan(text: p.name.length > 22 ? '${p.name.substring(0, 21)}…' : p.name, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 3, color: Colors.black)])),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
      final rect = Rect.fromLTWH(o.dx + 5, o.dy - tp.height / 2, tp.width, tp.height).inflate(2);
      if (rect.right > size.width || rect.left < 0 || taken.any((t) => t.overlaps(rect))) continue;
      taken.add(rect);
      tp.paint(canvas, Offset(o.dx + 6, o.dy - tp.height / 2));
      shown++;
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
              Positioned(
                left: 0,
                right: 0,
                top: 16,
                child: IgnorePointer(
                  child: Text('${places.length} places', textAlign: TextAlign.center, style: const TextStyle(color: C.muted, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ),
      );
}
