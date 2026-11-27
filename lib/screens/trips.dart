import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../widgets/same_time.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/mock_data.dart';
import '../data/social.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
import 'trip_tools.dart';
import 'ai_planner.dart';
import '../widgets/pull_refresh.dart';
import '../widgets/social_widgets.dart';
import 'bookings.dart';
import 'messages.dart';
import 'place_detail.dart';

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _short(DateTime d) => '${d.day} ${_mo[d.month - 1]}';

/// Trips tab: trip plans (itineraries) + bookings.
class TripsHubScreen extends StatelessWidget {
  const TripsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = Bp.isWide(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: !wide,
          title: Text(tr('Trips')),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight),
            child: Align(
              alignment: wide ? Alignment.centerLeft : Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TabBar(
                  indicatorColor: C.primary,
                  labelColor: C.primary,
                  unselectedLabelColor: C.muted,
                  dividerColor: Colors.transparent,
                  tabs: [Tab(text: tr('Trip plans')), Tab(text: tr('Bookings'))],
                ),
              ),
            ),
          ),
        ),
        body: const TabBarView(children: [_PlansTab(), BookingsScreen(embedded: true)]),
      ),
    );
  }
}

class _PlansTab extends StatelessWidget {
  const _PlansTab();

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialState>();
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 1100
        ? 3
        : w >= 700
            ? 2
            : 1;
    return Constrained(
      maxWidth: 1100,
      child: PullRefresh(
          child: ListView(padding: const EdgeInsets.all(16), children: [
        Panel(
          onTap: () => go(context, const CreateTripScreen()),
          child: Row(children: [
            IconBubble(Icons.add_location_alt_rounded, C.primary, size: 46),
            SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Plan a new trip'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                SizedBox(height: 2),
                Text(tr('Build a day-by-day itinerary and invite your travel buddies.'), style: TextStyle(color: C.muted, fontSize: 12.5)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: C.muted),
          ]),
        ),
        const SizedBox(height: 10),
        Panel(
          onTap: () => go(context, const AiPlannerScreen()),
          child: Row(children: [
            IconBubble(Icons.auto_awesome_rounded, const Color(0xFF9B7BE0), size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Smart trip planner'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(tr('Days and budget in, a free day-by-day plan out.'), style: const TextStyle(color: C.muted, fontSize: 12.5)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: C.muted),
          ]),
        ),
        const SizedBox(height: 16),
        if (social.trips.isEmpty)
          const EmptyState(Icons.map_outlined, 'No trip plans yet', 'Create one to start planning.')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisExtent: 252, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemCount: social.trips.length,
            itemBuilder: (c, i) => TripCard(social.trips[i]),
          ),
      ])),
    );
  }
}

class TripCard extends StatelessWidget {
  final TripPlan trip;
  final bool compact;
  const TripCard(this.trip, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final p = placeById(trip.placeId);
    final days = trip.start.difference(DateTime.now()).inDays + 1;
    final buddies = trip.buddies.map(travelerById).toList();
    return Panel(
      padding: EdgeInsets.zero,
      onTap: () => go(context, TripDetailScreen(trip: trip)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: compact ? 110 : 140,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            AppImage(p.photo, radius: 0),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Color(0xCC0A1A19)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(10)),
                child: Text(days > 0 ? (isBangla ? '$days দিন পরে' : 'In $days days') : tr('Now'), style: const TextStyle(color: C.on, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
            ),
            if (!trip.public) const Positioned(right: 10, top: 10, child: Icon(Icons.lock_rounded, color: Colors.white, size: 18)),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Text(trip.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 14, color: C.primary),
              const SizedBox(width: 4),
              Expanded(child: Text('${p.name}, ${p.country}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5))),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_month_rounded, size: 14, color: C.primary),
              const SizedBox(width: 4),
              Text('${_short(trip.start)} - ${_short(trip.end)}  ·  ${tr('${trip.days.length} days')}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
            ]),
            if (!compact) ...[
              const SizedBox(height: 10),
              Row(children: [
                if (buddies.isNotEmpty) AvatarStack(buddies, radius: 12),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(buddies.isEmpty ? tr('Solo trip') : '${isBangla ? 'সাথে' : 'With'} ${buddies.map((b) => b.first).join(', ')}', overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 12)),
                ),
                if (trip.budget > 0) Text(money(trip.budget), style: const TextStyle(color: C.primary, fontWeight: FontWeight.w800)),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});
  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _title = TextEditingController();
  final _budget = TextEditingController();
  String _place = places.first.id;
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().add(const Duration(days: 14)),
    end: DateTime.now().add(const Duration(days: 17)),
  );

  @override
  Widget build(BuildContext context) => ScreenScaffold(
        title: tr('Plan a trip'),
        bottom: PrimaryButton('Create trip plan', icon: Icons.check_rounded, onPressed: () {
          final p = placeById(_place);
          final t = context.read<SocialState>().createTrip(
                title: _title.text.trim().isEmpty ? '${p.name} trip' : _title.text.trim(),
                placeId: _place,
                start: _range.start,
                days: _range.duration.inDays + 1,
                budget: toUsd(double.tryParse(_budget.text.trim().replaceAll(',', '')) ?? 0),
              );
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TripDetailScreen(trip: t)));
        }),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          AspectRatio(aspectRatio: 16 / 7, child: AppImage(placeById(_place).photo, radius: 18)),
          const SizedBox(height: 16),
          LabeledField('Trip name', 'e.g. Winter in the hills', controller: _title),
          Text(tr('Destination'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _place,
            items: [for (final p in places) DropdownMenuItem(value: p.id, child: Text('${p.name}, ${p.country}'))],
            onChanged: (v) => setState(() => _place = v ?? _place),
          ),
          const SizedBox(height: 14),
          Text(tr('Dates'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Panel(
            onTap: () async {
              final r = await showDateRangePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 730)),
                initialDateRange: _range,
              );
              if (r != null) setState(() => _range = r);
            },
            child: Row(children: [
              const Icon(Icons.date_range_rounded, color: C.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('${fmtDate(_range.start)}  to  ${fmtDate(_range.end)}')),
              Text(tr('${_range.duration.inDays + 1} days'), style: const TextStyle(color: C.muted)),
            ]),
          ),
          const SizedBox(height: 14),
          LabeledField('Budget per person ($currencyCode)', 'Optional', controller: _budget, keyboard: TextInputType.number),
        ]),
      );
}

class TripDetailScreen extends StatefulWidget {
  final TripPlan trip;
  const TripDetailScreen({super.key, required this.trip});
  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  int _day = 0;

  void _addStop() {
    final title = TextEditingController();
    final note = TextEditingController();
    var time = const TimeOfDay(hour: 9, minute: 0);
    var kind = 'sight';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, MediaQuery.of(c).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trf('Add to day {0}', [_day + 1]), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in const ['sight', 'food', 'hotel', 'flight', 'bus', 'train', 'boat', 'trek'])
                ChoiceChip(
                  avatar: Icon(stopIcon(k), size: 16, color: kind == k ? C.on : C.primary),
                  label: Text(k[0].toUpperCase() + k.substring(1)),
                  selected: kind == k,
                  showCheckmark: false,
                  selectedColor: C.primary,
                  labelStyle: TextStyle(color: kind == k ? C.on : C.ink),
                  onSelected: (_) => set(() => kind = k),
                ),
            ]),
            const SizedBox(height: 14),
            LabeledField('What', 'e.g. Sunset boat ride', controller: title),
            LabeledField('Notes', 'Tickets, address, who booked it...', controller: note),
            Row(children: [
              Text(tr('Time'), style: TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final t = await showTimePicker(context: c, initialTime: time);
                  if (t != null) set(() => time = t);
                },
                icon: const Icon(Icons.schedule_rounded),
                label: Text(time.format(c)),
              ),
            ]),
            const SizedBox(height: 8),
            PrimaryButton('Add to itinerary', onPressed: () {
              if (title.text.trim().isEmpty) return;
              context.read<SocialState>().addStop(widget.trip, _day, TripStop(time.format(c), title.text.trim(), note.text.trim(), kind));
              Navigator.pop(c);
            }),
          ]),
        ),
      ),
    );
  }

  void _invite() {
    final social = context.read<SocialState>();
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: EdgeInsets.all(16), child: Text(tr('Invite buddies'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          for (final t in social.buddyList)
            ListTile(
              leading: PersonAvatar(t, showOnline: true),
              title: Text(t.name),
              trailing: widget.trip.buddies.contains(t.id) ? const Icon(Icons.check_circle_rounded, color: C.primary) : const Icon(Icons.add_circle_outline_rounded, color: C.muted),
              onTap: () {
                social.inviteBuddy(widget.trip, t.id);
                Navigator.pop(c);
                toast(context, '${t.first} was invited');
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialState>();
    final t = social.currentTrip(widget.trip);
    final p = placeById(t.placeId);
    final buddies = t.buddies.map(travelerById).toList();
    final wide = Bp.isWide(context);
    final day = t.days.isEmpty ? null : t.days[_day.clamp(0, t.days.length - 1)];

    final dayStrip = SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: t.days.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          if (i == t.days.length) {
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => social.addDay(t),
              child: Container(
                width: 60,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
                child: const Icon(Icons.add_rounded, color: C.primary),
              ),
            );
          }
          final d = t.start.add(Duration(days: i));
          final on = i == _day;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _day = i),
            child: Container(
              width: 64,
              decoration: BoxDecoration(color: on ? C.primary : C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? C.primary : C.line)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Day ${i + 1}', style: TextStyle(fontSize: 11, color: on ? C.on : C.muted, fontWeight: FontWeight.w600)),
                Text('${d.day}', style: TextStyle(fontSize: 18, color: on ? C.on : C.ink, fontWeight: FontWeight.w800)),
                Text(_wd[d.weekday - 1], style: TextStyle(fontSize: 10.5, color: on ? C.on : C.muted)),
              ]),
            ),
          );
        },
      ),
    );

    final timeline = day == null || day.stops.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: EmptyState(Icons.event_note_rounded, 'Nothing planned yet', 'Add places, meals, transport and stays for this day.'),
          )
        : Column(children: [
            for (var i = 0; i < day.stops.length; i++)
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    width: 66,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(day.stops[i].time, style: const TextStyle(color: C.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  Column(children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(color: C.tint, shape: BoxShape.circle),
                      child: Icon(stopIcon(day.stops[i].kind), size: 15, color: C.primary),
                    ),
                    if (i < day.stops.length - 1) Expanded(child: Container(width: 2, color: C.line)),
                  ]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Panel(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(day.stops[i].title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            if (day.stops[i].note.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(day.stops[i].note, style: const TextStyle(color: C.muted, fontSize: 12.5, height: 1.35)),
                            ],
                          ]),
                        ),
                        IconButton(
                          tooltip: tr('Remove'),
                          onPressed: () => social.removeStop(t, _day, day.stops[i]),
                          icon: const Icon(Icons.close_rounded, size: 18, color: C.muted),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
          ]);

    final side = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Travel buddies'), style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (buddies.isEmpty) Text(tr('Solo for now'), style: TextStyle(color: C.muted)),
          for (final b in buddies)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: PersonAvatar(b, radius: 16, showOnline: true),
              title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: IconButton(
                tooltip: tr('Message'),
                onPressed: () => go(context, ChatScreen(conversation: social.chatWith(b))),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: C.primary),
              ),
            ),
          const SizedBox(height: 6),
          OutlinedButton.icon(onPressed: _invite, icon: const Icon(Icons.person_add_alt_rounded, size: 18), label: Text(tr('Invite'))),
        ]),
      ),
      const SizedBox(height: 12),
      SameTimeTravelers(place: p, trip: t),
      const SizedBox(height: 12),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Trip tools'), style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.receipt_long_rounded, color: C.primary),
            title: Text(tr('Shared expenses')),
            subtitle: Text(tr('Log costs, see who owes whom'), style: TextStyle(fontSize: 12, color: C.muted)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => go(context, TripExpensesScreen(trip: t)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.luggage_rounded, color: C.primary),
            title: Text(tr('Packing list')),
            subtitle: Text(tr('Shared checklist for the group'), style: TextStyle(fontSize: 12, color: C.muted)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => go(context, TripPackingScreen(trip: t)),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Trip details'), style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _row(Icons.calendar_month_rounded, '${fmtDate(t.start)} - ${fmtDate(t.end)}'),
          _row(Icons.payments_rounded, t.budget > 0 ? '${money(t.budget)} per person' : 'No budget set'),
          _row(t.public ? Icons.public_rounded : Icons.lock_rounded, t.public ? 'Visible to buddies' : 'Only you and invited buddies'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: t.discoverable,
            onChanged: (v) => social.setTripDiscoverable(t, v),
            title: Text(tr('Show me to travelers going at the same time'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            subtitle: Text(tr('Others going to this place on your dates can find you and send a buddy request.'), style: const TextStyle(fontSize: 11.5, color: C.muted)),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => go(context, PlaceDetailScreen(place: p, initialTab: 1)), child: Text(tr('How to go')))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: () => go(context, PlaceDetailScreen(place: p)), child: Text(tr('Book stays')))),
          ]),
        ]),
      ),
    ]);

    return Scaffold(
      body: PullRefresh(
          child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 230,
          leading: const BackCircle(),
          leadingWidth: 56,
          title: Text(t.title),
          actions: [
            IconButton(tooltip: tr('Share trip'), onPressed: () => toast(context, tr('Trip link copied')), icon: const Icon(Icons.ios_share_rounded)),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'privacy') {
                  social.setTripPublic(t, !t.public);
                } else if (v == 'delete') {
                  social.deleteTrip(t);
                  Navigator.pop(context);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'privacy', child: Text(t.public ? tr('Make private') : tr('Make visible to buddies'))),
                PopupMenuItem(value: 'delete', child: Text(tr('Delete trip'))),
              ],
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              AppImage(p.photo, radius: 0),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0x66000000), Colors.transparent, Color(0xDD0A1A19)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              ),
              Positioned(
                left: 16,
                bottom: 16,
                right: 16,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p.name}, ${p.country}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text(trf('{0}-day itinerary', [t.days.length]), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Constrained(
            maxWidth: 1060,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [dayStrip, const SizedBox(height: 16), timeline])),
                      const SizedBox(width: 20),
                      SizedBox(width: 320, child: side),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [dayStrip, const SizedBox(height: 16), timeline, const SizedBox(height: 12), side]),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ])),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addStop, icon: const Icon(Icons.add_rounded), label: Text(tr('Add stop'))),
    );
  }

  Widget _row(IconData i, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(i, size: 16, color: C.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(tr(t), style: const TextStyle(fontSize: 13))),
        ]),
      );
}
