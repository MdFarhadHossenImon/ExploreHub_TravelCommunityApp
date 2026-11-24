import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../data/live_share.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
import '../widgets/social_widgets.dart';

String _ago(DateTime t) {
  final m = DateTime.now().difference(t).inMinutes;
  if (m < 1) return tr('just now');
  if (m < 60) return trf('{0} min ago', [m]);
  return trf('{0} h ago', [m ~/ 60]);
}

class _Pin {
  final String id, name;
  final String? avatar;
  final LatLng at;
  final DateTime updated;
  final bool me;
  const _Pin(this.id, this.name, this.avatar, this.at, this.updated, {this.me = false});
}

/// Map of buddies who are sharing their live location, plus your own sharing controls.
class LiveMapScreen extends StatefulWidget {
  final String? focusUserId;
  const LiveMapScreen({super.key, this.focusUserId});
  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final _map = MapController();
  List<_Pin> _pins = [];
  Timer? _poll;
  bool _loading = true, _focused = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _load());
    LiveShare.locate().then((_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final pins = <_Pin>[];
    final mine = LiveShare.me.value;
    if (mine != null) pins.add(_Pin('me', tr('You'), null, LatLng(mine.latitude, mine.longitude), mine.timestamp, me: true));
    if (Backend.on && Backend.uid != null) {
      try {
        for (final r in await Backend.liveLocations()) {
          if (r['user_id'] == Backend.uid) continue;
          final who = r['who'] as Map? ?? const {};
          pins.add(_Pin(r['user_id'] as String, (who['name'] as String?) ?? tr('Traveler'), who['avatar_url'] as String?,
              LatLng((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble()), DateTime.parse(r['updated_at'] as String).toLocal()));
        }
      } catch (_) {}
    } else {
      // Demo: two buddies near Dhaka.
      pins.add(_Pin('ayesha', 'Ayesha', null, const LatLng(23.7465, 90.3760), DateTime.now().subtract(const Duration(minutes: 2))));
      pins.add(_Pin('tanvir', 'Tanvir', null, const LatLng(23.8103, 90.4125), DateTime.now().subtract(const Duration(minutes: 9))));
    }
    if (!mounted) return;
    setState(() {
      _pins = pins;
      _loading = false;
    });
    if (!_focused && pins.isNotEmpty) {
      final target = pins.firstWhere((p) => p.id == widget.focusUserId, orElse: () => pins.firstWhere((p) => !p.me, orElse: () => pins.first));
      _focused = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _map.move(target.at, 13);
        } catch (_) {}
      });
    }
  }

  Future<void> _share() async {
    final d = await showModalBottomSheet<Duration>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(tr('Share live location for'), style: const TextStyle(fontWeight: FontWeight.w800))),
          for (final o in [(const Duration(hours: 1), '1 hour'), (const Duration(hours: 8), '8 hours'), (const Duration(hours: 24), '24 hours')])
            ListTile(leading: const Icon(Icons.timer_outlined, color: C.primary), title: Text(tr(o.$2)), onTap: () => Navigator.pop(c, o.$1)),
        ]),
      ),
    );
    if (d == null) return;
    final ok = await LiveShare.start(d);
    if (!mounted) return;
    if (!ok) return toast(context, tr('Allow location access in your browser or phone settings to share.'));
    toast(context, tr('Your buddies can now see where you are'));
    _load();
  }

  Widget _pinWidget(_Pin p) {
    final col = p.me ? const Color(0xFF3E63DD) : C.primary;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(10)),
        child: Text(p.name.split(' ').first, maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 2),
      Container(
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: col, width: 3)),
        child: p.avatar != null && p.avatar!.isNotEmpty
            ? CircleAvatar(radius: 15, backgroundImage: NetworkImage(p.avatar!))
            : CircleAvatar(radius: 15, backgroundColor: C.card, child: Text(p.name.isEmpty ? '?' : p.name[0], style: TextStyle(color: col, fontWeight: FontWeight.w800))),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final others = _pins.where((p) => !p.me).toList();
    return ScreenScaffold(
      title: tr('Live location'),
      maxWidth: 1100,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: C.danger, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
            onPressed: () => go(context, const SosScreen()),
            icon: const Icon(Icons.sos_rounded, size: 18),
            label: Text(tr('SOS')),
          ),
        ),
      ],
      body: Column(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(children: [
              FlutterMap(
                mapController: _map,
                options: const MapOptions(initialCenter: LatLng(23.8103, 90.4125), initialZoom: 6, minZoom: 2, maxZoom: 18),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.explorehub.app'),
                  MarkerLayer(markers: [for (final p in _pins) Marker(point: p.at, width: 90, height: 60, alignment: Alignment.topCenter, child: _pinWidget(p))]),
                  const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
                ],
              ),
              if (_loading) const Positioned(top: 12, right: 12, child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<DateTime?>(
          valueListenable: LiveShare.until,
          builder: (context, until, _) {
            final on = LiveShare.sharing;
            return Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(on ? Icons.share_location_rounded : Icons.location_off_rounded, color: on ? C.primary : C.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(on ? tr('You are sharing your live location') : tr('Share your live location with buddies'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        on
                            ? trf('Until {0}. It updates while the app is open.', ['${until!.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}'])
                            : tr('Only your travel buddies can see it, and only for the time you choose.'),
                        style: const TextStyle(color: C.muted, fontSize: 12),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  on
                      ? OutlinedButton(onPressed: () => LiveShare.stop(), child: Text(tr('Stop')))
                      : FilledButton(onPressed: _share, child: Text(tr('Share'))),
                ]),
                if (others.isNotEmpty) ...[
                  const Divider(height: 22),
                  for (final p in others)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_pin_circle_rounded, color: C.primary),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(trf('Updated {0}', [_ago(p.updated)]), style: const TextStyle(color: C.muted, fontSize: 11.5)),
                      trailing: IconButton(
                        tooltip: tr('Open in Maps'),
                        icon: const Icon(Icons.directions_rounded, color: C.primary),
                        onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.at.latitude},${p.at.longitude}'), mode: LaunchMode.externalApplication),
                      ),
                      onTap: () => _map.move(p.at, 15),
                    ),
                ] else if (!_loading)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(tr('No buddies are sharing right now.'), style: const TextStyle(color: C.muted, fontSize: 12.5)),
                  ),
              ]),
            );
          },
        ),
      ]),
    );
  }
}

/// Hold the button to alert every buddy with your location, then call local emergency services.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  late final _hold = AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _send();
    });
  final _msg = TextEditingController();
  bool _sending = false, _sent = false;
  double? _lat, _lng;
  String? _country, _numbers;

  @override
  void initState() {
    super.initState();
    _where();
  }

  @override
  void dispose() {
    _hold.dispose();
    _msg.dispose();
    super.dispose();
  }

  Future<void> _where() async {
    final p = await LiveShare.locate();
    if (p == null || !mounted) return;
    setState(() {
      _lat = p.latitude;
      _lng = p.longitude;
    });
    if (!Backend.on) return setState(() {
      _country = 'Bangladesh';
      _numbers = '999';
    });
    try {
      final e = await Backend.emergencyAt(p.latitude, p.longitude);
      if (mounted && e != null) {
        setState(() {
          _country = e['country'] as String?;
          _numbers = e['emergency'] as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    if (_sending || _sent) return;
    setState(() => _sending = true);
    if (_lat == null) await _where();
    try {
      if (Backend.on) await Backend.sendSos(_lat, _lng, _msg.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
    if (mounted) setState(() => _sending = false);
    _hold.reset();
  }

  Future<void> _safe() async {
    try {
      if (Backend.on) await Backend.resolveSos();
      if (!mounted) return;
      toast(context, tr('Your buddies were told you are safe'));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  String get _mapLink => _lat == null ? '' : 'https://maps.google.com/?q=${_lat!.toStringAsFixed(5)},${_lng!.toStringAsFixed(5)}';

  void _sms() {
    final text = '${tr('SOS: I need help.')} ${_msg.text.trim()} $_mapLink'.trim();
    launchUrl(Uri.parse('sms:?body=${Uri.encodeComponent(text)}'));
  }

  void _whatsapp() {
    final text = '${tr('SOS: I need help.')} ${_msg.text.trim()} $_mapLink'.trim();
    launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final buddies = context.watch<SocialState>().buddies.length;
    final nums = (_numbers ?? '').split(RegExp(r'[,/]')).map((e) => e.trim()).where((e) => RegExp(r'\d').hasMatch(e)).take(3).toList();
    return ScreenScaffold(
      title: tr('SOS'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: GestureDetector(
            onTapDown: (_) => _hold.forward(),
            onTapUp: (_) => _hold.isCompleted ? null : _hold.reverse(),
            onTapCancel: () => _hold.isCompleted ? null : _hold.reverse(),
            child: AnimatedBuilder(
              animation: _hold,
              builder: (_, __) => SizedBox(
                width: 210,
                height: 210,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(width: 210, height: 210, child: CircularProgressIndicator(value: _sent ? 1 : _hold.value, strokeWidth: 8, color: Colors.white, backgroundColor: C.danger.withValues(alpha: .25))),
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _sent ? const Color(0xFF2F9E6B) : C.danger, boxShadow: [BoxShadow(color: C.danger.withValues(alpha: .45), blurRadius: 30)]),
                    alignment: Alignment.center,
                    child: _sending
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_sent ? Icons.check_rounded : Icons.sos_rounded, color: Colors.white, size: 54),
                            const SizedBox(height: 4),
                            Text(_sent ? tr('Alert sent') : tr('Hold for 2 seconds'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _sent
              ? tr('Your buddies got an alert with your location. Your live location is shared with them for 2 hours.')
              : trf('Sends an alert with your location to your {0} travel buddies and shares your live location with them.', [buddies]),
          textAlign: TextAlign.center,
          style: const TextStyle(color: C.muted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        if (!_sent)
          TextField(
            controller: _msg,
            maxLength: 200,
            decoration: InputDecoration(labelText: tr('What is happening? (optional)'), hintText: tr('e.g. Injured on the trail, need a doctor')),
          ),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.local_phone_rounded, color: C.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_country == null ? tr('Emergency numbers') : trf('Emergency numbers in {0}', [_country]),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 8),
            if (nums.isEmpty)
              Text(_lat == null ? tr('Allow location access to find the local emergency number.') : tr('Finding the local number...'),
                  style: const TextStyle(color: C.muted, fontSize: 12.5))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final n in nums)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: C.danger, foregroundColor: Colors.white),
                    onPressed: () => launchUrl(Uri.parse('tel:${n.replaceAll(RegExp(r'[^0-9+]'), '')}')),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text(trf('Call {0}', [n])),
                  ),
              ]),
            if (_lat != null) ...[
              const SizedBox(height: 10),
              Text(trf('Your location: {0}, {1}', [_lat!.toStringAsFixed(5), _lng!.toStringAsFixed(5)]), style: const TextStyle(color: C.muted, fontSize: 12)),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _sms, icon: const Icon(Icons.sms_rounded, size: 18), label: Text(tr('Send by SMS')))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: _whatsapp, icon: const Icon(Icons.chat_rounded, size: 18), label: const Text('WhatsApp'))),
        ]),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => go(context, const LiveMapScreen()), icon: const Icon(Icons.map_rounded, size: 18), label: Text(tr('See buddies on the map'))),
        if (_sent) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2F9E6B), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
            onPressed: _safe,
            icon: const Icon(Icons.verified_user_rounded),
            label: Text(tr("I'm safe now")),
          ),
        ],
      ]),
    );
  }
}

/// Opens the right screen for an SOS notification.
Future<void> openSos(BuildContext context, String? alertId, String? actorId) async {
  String? focus = actorId;
  if (alertId != null && Backend.on) {
    try {
      final a = await Backend.sosAlert(alertId);
      focus = a?['user_id'] as String? ?? focus;
    } catch (_) {}
  }
  if (context.mounted) go(context, LiveMapScreen(focusUserId: focus));
}
