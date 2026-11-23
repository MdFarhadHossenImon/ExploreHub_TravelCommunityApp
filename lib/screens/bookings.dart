import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'booking_flow.dart';
import 'shell.dart';

class BookingsScreen extends StatefulWidget {
  final bool embedded;
  const BookingsScreen({super.key, this.embedded = false});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  bool _upcoming = true;

  @override
  Widget build(BuildContext context) {
    final all = context.watch<AppState>().bookings;
    final list = all.where((b) => _upcoming ? b.status == 'Upcoming' : b.status != 'Upcoming').toList();
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Bookings'),
              automaticallyImplyLeading: false,
              leading: Navigator.canPop(context) ? const BackCircle() : null,
              leadingWidth: 56,
            ),
      body: Constrained(
        maxWidth: 700,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<bool>(
              style: SegmentedButton.styleFrom(selectedBackgroundColor: C.primary, selectedForegroundColor: C.on),
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: true, label: Text('Upcoming')), ButtonSegment(value: false, label: Text('History'))],
              selected: {_upcoming},
              onSelectionChanged: (v) => setState(() => _upcoming = v.first),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(Icons.luggage_outlined, _upcoming ? 'No upcoming trips' : 'No past trips', 'Book a hotel, ticket or guide from Explore and it will show up here.')
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (c, i) {
                      final b = list[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
                        child: Column(children: [
                          Row(children: [
                            AppImage(b.seed, width: 96, height: 84, radius: 10),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(modeIcon(b.type), size: 13, color: C.primary),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(b.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.muted))),
                                ]),
                                const SizedBox(height: 4),
                                Text(money(b.amount), style: const TextStyle(color: C.primary, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ]),
                          const Divider(height: 22),
                          Row(children: [
                            Text(fmtDate(b.start), style: const TextStyle(fontSize: 12)),
                            const Spacer(),
                            TextButton(onPressed: () => go(context, BookingDetailScreen(booking: b)), child: const Text('See detail')),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: b.status == 'Cancelled' ? C.danger : b.status == 'Completed' ? C.muted : C.primary, borderRadius: BorderRadius.circular(8)),
                              child: Text(b.status, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ]),
                        ]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

class BookingDetailScreen extends StatelessWidget {
  final Booking booking;
  const BookingDetailScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = context.watch<AppState>().bookings.firstWhere((x) => x.id == booking.id);
    return ScreenScaffold(
      title: 'Order Detail',
      bottom: b.status == 'Upcoming'
          ? PrimaryButton('Cancel booking', outlined: true, onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Cancel this booking?'),
                  content: const Text('Refunds follow the operator policy. This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep booking')),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: C.danger), onPressed: () => Navigator.pop(c, true), child: const Text('Cancel booking')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                try {
                  await context.read<AppState>().cancelBooking(b);
                  if (context.mounted) toast(context, 'Booking cancelled');
                } catch (e) {
                  if (context.mounted) toast(context, errText(e));
                }
              }
            })
          : PrimaryButton('Back to trips', onPressed: () => openTab(context, 3)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TicketCard(booking: b),
        const SizedBox(height: 12),
        Center(child: Text('Status: ${b.status}', style: const TextStyle(color: C.muted))),
      ]),
    );
  }
}
