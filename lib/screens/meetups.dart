import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/env.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
import '../widgets/social_widgets.dart';
import 'place_detail.dart';

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String meetupWhen(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${_wd[d.weekday - 1]}, ${d.day} ${_mo[d.month - 1]} · $h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// Travel meetups: real-world hangouts, treks and city walks that travelers host and join.
class MeetupsScreen extends StatefulWidget {
  const MeetupsScreen({super.key});
  @override
  State<MeetupsScreen> createState() => _MeetupsScreenState();
}

class _MeetupsScreenState extends State<MeetupsScreen> {
  String _filter = 'Upcoming';

  @override
  void initState() {
    super.initState();
    context.read<SocialState>().loadMeetups().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialState>();
    var list = social.meetups.where((m) => !m.isPast).toList();
    if (_filter == 'Going') list = list.where((m) => social.rsvps[m.id] == 'going').toList();
    if (_filter == 'Hosting') list = list.where((m) => m.hostId == Backend.uid).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Travel meetups')),
      floatingActionButton: Backend.on
          ? FloatingActionButton.extended(
              onPressed: () => go(context, const CreateMeetupScreen()),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Host a meetup'),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: social.loadMeetups,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
              const Text('Meet travelers in real life: sunrise hikes, food walks, shared boats and city meetups.',
                  style: TextStyle(color: C.muted, fontSize: 13.5, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final f in const ['Upcoming', 'Going', 'Hosting'])
                  ChoiceChip(label: Text(f), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
              ]),
              const SizedBox(height: 14),
              if (!Backend.on)
                const EmptyState(Icons.event_rounded, 'Meetups need an account', 'Sign in to the live app to host and join meetups.')
              else if (list.isEmpty)
                EmptyState(Icons.event_available_rounded, _filter == 'Upcoming' ? 'No meetups yet' : 'Nothing here yet',
                    _filter == 'Upcoming' ? 'Be the first to host one. Tap "Host a meetup".' : 'Meetups you join or host show up here.')
              else
                for (final m in list) Padding(padding: const EdgeInsets.only(bottom: 14), child: MeetupCard(m)),
            ]),
          ),
        ),
      ),
    );
  }
}

class MeetupCard extends StatelessWidget {
  final Meetup m;
  final double? width;
  const MeetupCard(this.m, {super.key, this.width});

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialState>();
    final mine = social.rsvps[m.id];
    final place = m.placeId == null ? null : places.where((p) => p.id == m.placeId).firstOrNull;
    final cover = m.coverUrl ?? place?.photo;
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => go(context, MeetupDetailScreen(meetup: m)),
        child: Container(
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.line)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: width == null ? 150 : 110,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                AppImage(cover ?? 'meetup-${m.id}', radius: 0),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xCC101E1D), borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      Text(_mo[m.startsAt.month - 1].toUpperCase(), style: const TextStyle(color: C.primary, fontSize: 10.5, fontWeight: FontWeight.w800)),
                      Text('${m.startsAt.day}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1)),
                    ]),
                  ),
                ),
                if (mine != null)
                  Positioned(right: 10, top: 10, child: Pill(mine == 'going' ? 'Going' : 'Interested', icon: Icons.check_rounded)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                const SizedBox(height: 4),
                Text(meetupWhen(m.startsAt), style: const TextStyle(color: C.primary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(m.location.isNotEmpty ? m.location : (place?.name ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: C.muted, fontSize: 12.5)),
                const SizedBox(height: 8),
                Row(children: [
                  Avatar(m.hostAvatar, name: m.hostName, radius: 10),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Hosted by ${m.hostName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  Text('${m.going} going', style: const TextStyle(color: C.muted, fontSize: 12)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class MeetupDetailScreen extends StatefulWidget {
  final Meetup meetup;
  const MeetupDetailScreen({super.key, required this.meetup});
  @override
  State<MeetupDetailScreen> createState() => _MeetupDetailScreenState();
}

class _MeetupDetailScreenState extends State<MeetupDetailScreen> {
  List<Map<String, dynamic>> _people = [];

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    if (!Backend.on) return;
    try {
      final p = await Backend.meetupGoing(widget.meetup.id);
      if (mounted) setState(() => _people = p);
    } catch (_) {}
  }

  Future<void> _rsvp(String? status) async {
    await context.read<SocialState>().setRsvp(widget.meetup, status);
    _loadPeople();
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialState>();
    final m = widget.meetup;
    final mine = social.rsvps[m.id];
    final isHost = m.hostId == Backend.uid;
    final place = m.placeId == null ? null : places.where((p) => p.id == m.placeId).firstOrNull;
    final going = _people.where((r) => r['status'] == 'going').toList();
    final interested = _people.where((r) => r['status'] == 'interested').toList();

    Widget person(Map<String, dynamic> r) {
      final pr = r['profiles'] is Map ? r['profiles'] as Map : const {};
      final name = pr['name'] as String? ?? 'Traveler';
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(children: [
          Avatar(pr['avatar_url'] as String? ?? '', name: name, radius: 22),
          const SizedBox(height: 4),
          SizedBox(width: 60, child: Text(name.split(' ').first, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5))),
        ]),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meetup'), actions: [
        if (isHost)
          IconButton(
            tooltip: 'Cancel meetup',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Cancel this meetup?'),
                  content: const Text('It will be removed for everyone who joined.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: C.danger), onPressed: () => Navigator.pop(c, true), child: const Text('Cancel meetup')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await context.read<SocialState>().deleteMeetup(m);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
      ]),
      bottomNavigationBar: isHost || m.isPast
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size.fromHeight(48)),
                      onPressed: m.isFull && mine != 'going' ? null : () => _rsvp(mine == 'going' ? null : 'going'),
                      icon: Icon(mine == 'going' ? Icons.check_circle_rounded : Icons.event_available_rounded),
                      label: Text(mine == 'going' ? 'You\'re going' : (m.isFull ? 'Full' : 'Going')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size.fromHeight(48), foregroundColor: C.ink, side: const BorderSide(color: C.line)),
                      onPressed: () => _rsvp(mine == 'interested' ? null : 'interested'),
                      icon: Icon(mine == 'interested' ? Icons.star_rounded : Icons.star_border_rounded),
                      label: const Text('Interested'),
                    ),
                  ),
                ]),
              ),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(height: 210, child: AppImage(m.coverUrl ?? place?.photo ?? 'meetup-${m.id}', radius: 0)),
            ),
            const SizedBox(height: 16),
            Text(m.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 12),
            _row(Icons.schedule_rounded, meetupWhen(m.startsAt)),
            _row(Icons.location_on_rounded, m.location.isNotEmpty ? m.location : (place?.name ?? 'Location shared after you join')),
            _row(Icons.groups_rounded, '${m.going} going · ${m.interested} interested${m.capacity != null ? ' · ${m.capacity} spots' : ''}'),
            if (place != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => go(context, PlaceDetailScreen(place: place)),
                    icon: const Icon(Icons.travel_explore_rounded, size: 18),
                    label: Text('About ${place.name}'),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(children: [
              Avatar(m.hostAvatar, name: m.hostName, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Hosted by', style: TextStyle(color: C.muted, fontSize: 11.5)),
                  Text(m.hostName, style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
            if (m.about.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('About this meetup', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 6),
              Text(m.about, style: const TextStyle(fontSize: 14, height: 1.5)),
            ],
            const SizedBox(height: 18),
            Text('Going (${going.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            if (going.isEmpty)
              const Text('No one yet.', style: TextStyle(color: C.muted))
            else
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final r in going) person(r)])),
            if (interested.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Interested (${interested.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 10),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final r in interested) person(r)])),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(shape: const StadiumBorder(), foregroundColor: C.ink, side: const BorderSide(color: C.line)),
              onPressed: () => _invite(context, m),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Invite a buddy'),
            ),
          ]),
        ),
      ),
    );
  }

  void _invite(BuildContext context, Meetup m) {
    final social = context.read<SocialState>();
    if (social.buddyList.isEmpty) return toast(context, 'Add travel buddies first to invite them.');
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 12), children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('Invite a buddy', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        for (final t in social.buddyList)
          ListTile(
            leading: PersonAvatar(t, radius: 18),
            title: Text(t.name),
            trailing: const Icon(Icons.send_rounded, color: C.primary),
            onTap: () {
              social.send(social.chatWith(t), 'Join me at "${m.title}" on ${meetupWhen(m.startsAt)}. Open Meetups in ExploreHub: ${Env.webUrl}');
              Navigator.pop(c);
              toast(context, 'Invite sent to ${t.name.split(' ').first}');
            },
          ),
      ]),
    );
  }

  Widget _row(IconData i, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(i, size: 18, color: C.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 14))),
        ]),
      );
}

class CreateMeetupScreen extends StatefulWidget {
  const CreateMeetupScreen({super.key});
  @override
  State<CreateMeetupScreen> createState() => _CreateMeetupScreenState();
}

class _CreateMeetupScreenState extends State<CreateMeetupScreen> {
  final _title = TextEditingController();
  final _about = TextEditingController();
  final _location = TextEditingController();
  final _capacity = TextEditingController();
  String? _placeId;
  DateTime _when = DateTime.now().add(const Duration(days: 3)).copyWith(hour: 9, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  Uint8List? _cover;
  bool _busy = false;

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _when, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    setState(() => _when = DateTime(d.year, d.month, d.day, t?.hour ?? _when.hour, t?.minute ?? _when.minute));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.length < 3) return toast(context, 'Give your meetup a title');
    if (_placeId == null && _location.text.trim().isEmpty) return toast(context, 'Choose a place or write where to meet');
    if (_when.isBefore(DateTime.now())) return toast(context, 'Pick a time in the future');
    final cap = int.tryParse(_capacity.text.trim());
    if (_capacity.text.trim().isNotEmpty && (cap == null || cap < 2 || cap > 500)) return toast(context, 'Spots must be between 2 and 500');
    setState(() => _busy = true);
    final ok = await context.read<SocialState>().createMeetup(
          title: title,
          about: _about.text.trim(),
          location: _location.text.trim(),
          startsAt: _when,
          placeId: _placeId,
          capacity: cap,
          cover: _cover,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context);
      toast(context, 'Meetup published');
    }
  }

  @override
  Widget build(BuildContext context) => ScreenScaffold(
        title: 'Host a meetup',
        bottom: PrimaryButton(_busy ? 'Publishing...' : 'Publish meetup', icon: Icons.event_available_rounded, onPressed: _busy ? null : _save),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          GestureDetector(
            onTap: () async {
              final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
              if (f != null) {
                final b = await f.readAsBytes();
                setState(() => _cover = b);
              }
            },
            child: Container(
              height: 160,
              decoration: BoxDecoration(color: C.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(18)),
              clipBehavior: Clip.antiAlias,
              child: _cover != null
                  ? Image.memory(_cover!, fit: BoxFit.cover)
                  : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 36, color: C.primary),
                      SizedBox(height: 6),
                      Text('Add a cover photo (optional)', style: TextStyle(color: C.primary)),
                    ]),
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: _title, maxLength: 120, decoration: const InputDecoration(labelText: 'Title', hintText: 'Sunrise hike at Sajek')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _placeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Destination (optional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('No specific destination')),
              for (final p in places) DropdownMenuItem(value: p.id, child: Text('${p.name}, ${p.country}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _placeId = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: _location, decoration: const InputDecoration(labelText: 'Where to meet', hintText: 'e.g. Hotel lobby, Gate 2, bus stand', prefixIcon: Icon(Icons.location_on_outlined))),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_rounded, color: C.primary),
            title: Text(meetupWhen(_when)),
            subtitle: const Text('Tap to change date and time'),
            onTap: _pickDate,
          ),
          TextField(controller: _capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Spots (optional)', hintText: 'Leave empty for no limit')),
          const SizedBox(height: 12),
          TextField(controller: _about, maxLines: 5, minLines: 3, maxLength: 2000, decoration: const InputDecoration(labelText: 'Details', hintText: 'Plan, what to bring, costs to share, contact on the day')),
          const SizedBox(height: 6),
          const Text('Meet in public places and share your plans with someone you trust.', style: TextStyle(color: C.muted, fontSize: 12)),
        ]),
      );
}
