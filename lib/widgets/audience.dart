import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

/// Who can see a post: everyone, your travel buddies, or only you.
const audiences = ['public', 'buddies', 'private'];

String audienceLabel(String a) => switch (a) {
      'buddies' => tr('Buddies'),
      'private' => tr('Only me'),
      _ => tr('Public'),
    };

String audienceHint(String a) => switch (a) {
      'buddies' => tr('Only your travel buddies can see it'),
      'private' => tr('Only you can see it'),
      _ => tr('Anyone on ExploreHub can see it'),
    };

IconData audienceIcon(String a) => switch (a) {
      'buddies' => Icons.group_rounded,
      'private' => Icons.lock_rounded,
      _ => Icons.public_rounded,
    };

/// A small pill ("🌐 Public ▾") that opens a sheet to pick the audience.
class AudienceButton extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const AudienceButton({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Material(
        color: C.primary.withOpacity(.10),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () async {
            final v = await pickAudience(context, value);
            if (v != null) onChanged(v);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(audienceIcon(value), size: 16, color: C.primary),
              const SizedBox(width: 6),
              Text(audienceLabel(value), style: const TextStyle(color: C.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              const Icon(Icons.arrow_drop_down_rounded, size: 20, color: C.primary),
            ]),
          ),
        ),
      );
}

Future<String?> pickAudience(BuildContext context, String current) => showModalBottomSheet<String>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(tr('Who can see this post?'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          for (final a in audiences)
            ListTile(
              leading: CircleAvatar(backgroundColor: C.primary.withOpacity(.12), child: Icon(audienceIcon(a), color: C.primary, size: 20)),
              title: Text(audienceLabel(a), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(audienceHint(a), style: const TextStyle(color: C.muted, fontSize: 12)),
              trailing: a == current ? const Icon(Icons.check_circle_rounded, color: C.primary) : const Icon(Icons.circle_outlined, color: C.line),
              onTap: () => Navigator.pop(c, a),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
