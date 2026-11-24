import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/i18n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../data/backend.dart';
import '../widgets/common.dart';

/// Feedback form for people using the app. Answers go to the `app_feedback` table,
/// which feeds the owner's Google Sheet.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _rating = 0;
  String? _ease, _found, _recommend, _bug;
  final Set<String> _features = {};
  final _improve = TextEditingController();
  final _wish = TextEditingController();
  bool _busy = false;

  static const _easeOpts = ['Very easy', 'Easy', 'Okay', 'Hard to use'];
  static const _featureOpts = ['Feed & posts', 'Stories', 'Explore places', 'Trip planner', 'Messages', 'Meetups', 'Groups', 'Bookings', 'Watch videos'];
  static const _foundOpts = ['A friend', 'Facebook', 'Google search', 'Play Store', 'Other'];
  static const _recommendOpts = ['Yes, definitely', 'Maybe', 'Not yet'];
  static const _bugOpts = ['No problems', 'Yes, small issues', 'Yes, something broke'];

  Widget _q(String title, {String? hint}) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(title), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          if (hint != null) Text(tr(hint), style: const TextStyle(color: C.muted, fontSize: 12)),
        ]),
      );

  Widget _single(List<String> opts, String? value, void Function(String) set) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in opts)
          ChoiceChip(
            label: Text(tr(o)),
            selected: value == o,
            showCheckmark: false,
            selectedColor: C.primary,
            labelStyle: TextStyle(color: value == o ? C.on : C.ink, fontSize: 13),
            onSelected: (_) => setState(() => set(o)),
          ),
      ]);

  Future<void> _submit() async {
    if (_rating == 0) return toast(context, tr('Please give a star rating'));
    if (_improve.text.trim().length < 3) return toast(context, tr('Tell us at least one thing to improve'));
    if (!Backend.on) {
      toast(context, tr('Thanks! Feedback is saved in the live app.'));
      Navigator.pop(context);
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.from('app_feedback').insert({
        'rating': _rating,
        'ease': _ease,
        'features': _features.toList(),
        'found_via': _found,
        'recommend': _recommend,
        'had_bug': _bug,
        'improve': _improve.text.trim(),
        'wish': _wish.text.trim().isEmpty ? null : _wish.text.trim(),
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      });
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.favorite_rounded, color: C.primary, size: 40),
          title: Text(tr('Thank you!')),
          content: Text(tr('Your feedback helps make ExploreHub better for every traveler.')),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(tr('Done')))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ScreenScaffold(
        title: tr('Give feedback'),
        bottom: PrimaryButton(_busy ? 'Sending...' : 'Send feedback', icon: Icons.send_rounded, onPressed: _busy ? null : _submit),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          Text(tr('Help us build the best app for travelers. It takes about a minute.'), style: TextStyle(color: C.muted, height: 1.4)),
          _q('How do you rate ExploreHub overall?'),
          Row(children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                iconSize: 36,
                onPressed: () => setState(() => _rating = i),
                icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: C.primary),
              ),
          ]),
          _q('How easy is the app to use?'),
          _single(_easeOpts, _ease, (v) => _ease = v),
          _q('Which features do you use most?', hint: 'Pick all that apply'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in _featureOpts)
              FilterChip(
                label: Text(tr(f)),
                selected: _features.contains(f),
                onSelected: (v) => setState(() => v ? _features.add(f) : _features.remove(f)),
              ),
          ]),
          _q('How did you find ExploreHub?'),
          _single(_foundOpts, _found, (v) => _found = v),
          _q('Would you recommend it to a traveler friend?'),
          _single(_recommendOpts, _recommend, (v) => _recommend = v),
          _q('Did anything break or feel buggy?'),
          _single(_bugOpts, _bug, (v) => _bug = v),
          _q('Things to improve *', hint: 'Describe what should be better, what confused you, or what went wrong.'),
          TextField(controller: _improve, maxLines: 6, maxLength: 4000, decoration: InputDecoration(hintText: tr('e.g. The trip planner should let me add hotel links...'))),
          _q('Anything you wish the app had?', hint: 'Optional'),
          TextField(controller: _wish, maxLines: 3, maxLength: 1000, decoration: InputDecoration(hintText: tr('Your dream travel feature'))),
        ]),
      );
}
