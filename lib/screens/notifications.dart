import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/pull_refresh.dart';

IconData _icon(String k) {
  switch (k) {
    case 'hotel':
      return Icons.apartment_rounded;
    case 'flight':
      return Icons.flight_rounded;
    case 'community':
      return Icons.favorite_rounded;
    case 'buddy':
      return Icons.person_add_alt_1_rounded;
    case 'group':
      return Icons.groups_rounded;
    case 'trip':
      return Icons.map_rounded;
    default:
      return Icons.place_rounded;
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final days = <String>[];
    for (final n in s.notifications) {
      if (!days.contains(n.day)) days.add(n.day);
    }
    return ScreenScaffold(
      title: 'Notifications',
      actions: [TextButton(onPressed: s.unread == 0 ? null : s.markAllRead, child: const Text('Read all'))],
      body: s.notifications.isEmpty
          ? const EmptyState(Icons.notifications_none_rounded, 'All caught up', 'Booking updates and community activity show up here.')
          : PullRefresh(
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
              for (final d in days) ...[
                Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: Text(d, style: const TextStyle(color: C.muted, fontSize: 12.5))),
                for (final n in s.notifications.where((x) => x.day == d))
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => s.markRead(n),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 14, right: 10),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: n.read ? C.line : C.primary),
                        ),
                        Icon(_icon(n.kind), color: C.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(n.body, style: const TextStyle(fontSize: 12, color: C.muted, height: 1.4)),
                            const SizedBox(height: 6),
                            Text(n.time, style: const TextStyle(fontSize: 11, color: C.muted)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
              ],
            ])),
    );
  }
}
