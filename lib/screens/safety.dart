import 'package:flutter/material.dart';
import '../core/i18n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../data/backend.dart';
import '../widgets/common.dart';
import '../widgets/place_extras.dart';

/// Emergency numbers by country, travel safety basics and how to report someone.
class SafetyCenterScreen extends StatefulWidget {
  const SafetyCenterScreen({super.key});
  @override
  State<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends State<SafetyCenterScreen> {
  List<String> _countries = const [];
  String _country = 'Bangladesh';

  @override
  void initState() {
    super.initState();
    if (Backend.on) {
      Supabase.instance.client.from('country_info').select('country').order('country').then((rows) {
        if (mounted) setState(() => _countries = [for (final r in rows) r['country'] as String]);
      }).catchError((_) {});
    }
  }

  static const _tips = [
    (Icons.share_location_rounded, 'Share your plan', 'Send your trip plan and live location to a buddy or family member before you go remote.'),
    (Icons.content_copy_rounded, 'Keep copies', 'Save photos of your passport, visa and insurance in your phone and email.'),
    (Icons.payments_rounded, 'Split your money', 'Carry two cards and some cash in different bags.'),
    (Icons.local_taxi_rounded, 'Use known transport', 'Prefer official taxis or ride-hailing apps, especially at night.'),
    (Icons.groups_rounded, 'Meet in public', 'Meet new buddies from the app in busy public places first.'),
    (Icons.health_and_safety_rounded, 'Get travel insurance', 'Check it covers medical evacuation and the activities you plan.'),
  ];

  @override
  Widget build(BuildContext context) => ScreenScaffold(
        title: tr('Safety center'),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(tr('Emergency numbers'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          if (Backend.on)
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _country),
              optionsBuilder: (v) => v.text.isEmpty ? _countries : _countries.where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (c) => setState(() => _country = c),
              fieldViewBuilder: (c, ctrl, focus, submit) => TextField(
                controller: ctrl,
                focusNode: focus,
                decoration: InputDecoration(hintText: tr('Type a country'), prefixIcon: Icon(Icons.public_rounded)),
              ),
            ),
          EssentialsCard(_country, key: ValueKey(_country)),
          if (!Backend.on)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(tr('Bangladesh: 999 for police, fire and ambulance. Most of Europe: 112. USA and Canada: 911.'), style: TextStyle(height: 1.4)),
            ),
          const SizedBox(height: 22),
          Text(tr('Travel smart'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          for (final t in _tips)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: C.card, child: Icon(t.$1, color: C.primary)),
              title: Text(tr(t.$2), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(tr(t.$3), style: const TextStyle(fontSize: 12.5, color: C.muted)),
            ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.flag_rounded, color: C.danger),
              SizedBox(width: 12),
              Expanded(
                child: Text(tr('Report someone: tap the ••• menu on their post and choose Report or Block. We review every report.'),
                    style: TextStyle(fontSize: 13, height: 1.4)),
              ),
            ]),
          ),
        ]),
      );
}
