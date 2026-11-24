import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../data/social.dart';
import '../screens/messages.dart';
import '../screens/traveler_profile.dart';
import '../state/social_state.dart';
import 'common.dart';
import 'social_widgets.dart';

const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _d(DateTime d) => '${d.day} ${tr(_mo[d.month - 1])}';

/// "Who's going": travelers headed to [place] on dates that overlap yours.
/// With a [trip], its dates are used; otherwise your next trip there, or the next 90 days.
class SameTimeTravelers extends StatefulWidget {
  final Place place;
  final TripPlan? trip;
  const SameTimeTravelers({super.key, required this.place, this.trip});

  @override
  State<SameTimeTravelers> createState() => _SameTimeTravelersState();
}

class _SameTimeTravelersState extends State<SameTimeTravelers> {
  List<SameTimeMatch>? _list;
  bool _failed = false;
  late DateTime _from, _to;
  TripPlan? _trip;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip ?? context.read<SocialState>().myTripTo(widget.place.id);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_trip != null) {
      _from = _trip!.start.isBefore(today) ? today : _trip!.start;
      _to = _trip!.end;
    } else {
      _from = today;
      _to = today.add(const Duration(days: 90));
    }
    _load();
  }

  Future<void> _load() async {
    if (!Backend.on) {
      // Demo: a few sample travelers heading the same way.
      final demo = travelers.take(3).toList();
      setState(() => _list = [
            for (var i = 0; i < demo.length; i++)
              SameTimeMatch(
                userId: demo[i].id,
                name: demo[i].name,
                home: demo[i].home,
                start: _from.subtract(Duration(days: i)),
                end: _to.subtract(Duration(days: i)),
                overlapDays: _to.difference(_from).inDays + 1 - i,
              ),
          ]);
      return;
    }
    if (Backend.user == null) return setState(() => _list = []);
    try {
      final l = await Backend.sameTimeTravelers(widget.place.id, _from, _to);
      if (mounted) setState(() => _list = l);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<Traveler?> _traveler(SameTimeMatch m) async {
    for (final t in travelers) {
      if (t.id == m.userId) return t;
    }
    if (!Backend.on) return null;
    try {
      return await Backend.fetchTraveler(m.userId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _open(SameTimeMatch m, {bool chat = false}) async {
    final t = await _traveler(m);
    if (!mounted) return;
    if (t == null) return toast(context, tr('This traveler is no longer on ExploreHub'));
    chat ? go(context, ChatScreen(conversation: context.read<SocialState>().chatWith(t))) : go(context, TravelerProfileScreen(traveler: t));
  }

  Widget _action(SocialState social, SameTimeMatch m) {
    final id = m.userId;
    if (social.buddies.contains(id)) {
      return IconButton(
        tooltip: tr('Message'),
        onPressed: () => _open(m, chat: true),
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19, color: C.primary),
      );
    }
    if (social.incoming.contains(id)) {
      return FilledButton(
        style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 12)),
        onPressed: () => social.acceptRequest(id),
        child: Text(tr('Accept')),
      );
    }
    final sent = social.sent.contains(id);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10)),
      onPressed: () => social.toggleRequest(id),
      icon: Icon(sent ? Icons.check_rounded : Icons.person_add_alt_1_rounded, size: 16),
      label: Text(sent ? tr('Requested') : tr('Add buddy'), style: const TextStyle(fontSize: 12.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialState>();
    final list = _list;
    final title = _trip != null ? tr('Travelers there at the same time') : tr('Travelers going here soon');
    final sub = _trip != null
        ? trf('Going to {0} between {1} and {2}', [widget.place.name, _d(_from), _d(_to)])
        : tr('Trips planned here in the next 3 months');

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.groups_rounded, color: C.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(sub, style: const TextStyle(color: C.muted, fontSize: 12)),
            ]),
          ),
          if (list != null && list.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(20)),
              child: Text('${list.length}', style: const TextStyle(color: C.on, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
        ]),
        const SizedBox(height: 8),
        if (list == null && !_failed)
          const Padding(padding: EdgeInsets.all(14), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))))
        else if (_failed)
          Text(tr('Could not load travelers right now.'), style: const TextStyle(color: C.muted, fontSize: 12.5))
        else if (list!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              _trip != null ? tr('No one else has planned these dates yet. We will show them here when they do.') : tr('No trips planned here yet. Plan yours and travelers going at the same time will find you.'),
              style: const TextStyle(color: C.muted, fontSize: 12.5),
            ),
          )
        else
          for (final m in list.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => _open(m),
              leading: _MatchAvatar(m),
              title: Row(children: [
                Flexible(child: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                if (m.verified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, size: 15, color: C.primary)),
              ]),
              subtitle: Text(
                '${_d(m.start)} – ${_d(m.end)}  ·  ${_trip != null ? (m.overlapDays == 1 ? tr('1 day together') : trf('{0} days together', [m.overlapDays])) : (m.home.isEmpty ? '' : trf('From {0}', [m.home]))}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: C.muted, fontSize: 12),
              ),
              trailing: _action(social, m),
            ),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.shield_outlined, size: 14, color: C.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(tr('Only your name and dates are shown. Meet new buddies in public places first.'),
                style: const TextStyle(color: C.muted, fontSize: 11)),
          ),
        ]),
      ]),
    );
  }
}

class _MatchAvatar extends StatelessWidget {
  final SameTimeMatch m;
  const _MatchAvatar(this.m);
  @override
  Widget build(BuildContext context) {
    for (final t in travelers) {
      if (t.id == m.userId) return PersonAvatar(t, radius: 20, showOnline: true);
    }
    if (m.avatarUrl != null && m.avatarUrl!.isNotEmpty) {
      return CircleAvatar(radius: 20, backgroundImage: NetworkImage(m.avatarUrl!));
    }
    return Avatar(m.userId, name: m.name, radius: 20);
  }
}
