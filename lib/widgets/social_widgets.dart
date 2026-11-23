import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/social.dart';
import '../state/app_state.dart';
import '../state/social_state.dart';
import 'common.dart';

/// Compact number: 12400 -> 12.4K
String compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 100000 || n % 1000 == 0 ? 0 : 1)}K';
  return '$n';
}

IconData stopIcon(String k) {
  switch (k) {
    case 'hotel':
      return Icons.hotel_rounded;
    case 'food':
      return Icons.restaurant_rounded;
    case 'sight':
      return Icons.photo_camera_rounded;
    default:
      return modeIcon(k);
  }
}

/// Rounded surface used for every card / panel.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.margin = EdgeInsets.zero, this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: margin,
        child: Material(
          color: C.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: C.line)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      );
}

/// Round icon button with an optional red count badge (top bar actions).
class CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badge;
  final String tooltip;
  final bool active;
  const CircleAction(this.icon, this.onTap, {super.key, this.badge = 0, this.tooltip = '', this.active = false});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Stack(clipBehavior: Clip.none, children: [
          Material(
            color: active ? C.primary : C.card,
            shape: const CircleBorder(side: BorderSide(color: C.line)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 21, color: active ? C.on : C.ink)),
            ),
          ),
          if (badge > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: C.danger, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.bg, width: 2)),
                child: Text('$badge', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      );
}

/// Brand word-mark.
class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 22});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size * 1.4,
          height: size * 1.4,
          decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(size * .42)),
          child: Icon(Icons.travel_explore_rounded, color: C.on, size: size * .95),
        ),
        SizedBox(width: size * .4),
        Text('ExploreHub', style: TextStyle(color: C.primary, fontWeight: FontWeight.w800, fontSize: size, letterSpacing: -.5)),
      ]);
}

/// Avatar with an optional green "online" dot and story ring.
class PersonAvatar extends StatelessWidget {
  final Traveler t;
  final double radius;
  final bool showOnline;
  const PersonAvatar(this.t, {super.key, this.radius = 20, this.showOnline = false});

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        Avatar(t.seed, name: t.name, radius: radius),
        if (showOnline && context.watch<SocialState>().isOnline(t))
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: radius * .6,
              height: radius * .6,
              decoration: BoxDecoration(color: const Color(0xFF4CD964), shape: BoxShape.circle, border: Border.all(color: C.card, width: 2)),
            ),
          ),
      ]);
}

class VerifiedName extends StatelessWidget {
  final Traveler t;
  final double size;
  const VerifiedName(this.t, {super.key, this.size = 14});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(t.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: size))),
        if (t.verified) ...[const SizedBox(width: 4), Icon(Icons.verified_rounded, size: size + 1, color: C.primary)],
      ]);
}

/// "Add buddy" / "Requested" / "Buddies" button used across screens.
class BuddyButton extends StatelessWidget {
  final Traveler t;
  final bool dense;
  const BuddyButton(this.t, {super.key, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SocialState>();
    final isBuddy = s.buddies.contains(t.id);
    final sent = s.sent.contains(t.id);
    final incoming = s.incoming.contains(t.id);
    final label = isBuddy ? 'Buddies' : incoming ? 'Accept' : sent ? 'Requested' : 'Add buddy';
    final icon = isBuddy ? Icons.how_to_reg_rounded : sent ? Icons.schedule_rounded : Icons.person_add_alt_1_rounded;
    final filled = !isBuddy && !sent;
    void tap() {
      if (incoming) return s.acceptRequest(t.id);
      if (!isBuddy) return s.toggleRequest(t.id);
    }

    final style = ButtonStyle(
      visualDensity: dense ? VisualDensity.compact : null,
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: dense ? 10 : 16)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    );
    return filled
        ? FilledButton.icon(style: style, onPressed: tap, icon: Icon(icon, size: 17), label: Text(label))
        : OutlinedButton.icon(
            style: style.copyWith(foregroundColor: const WidgetStatePropertyAll(C.ink), side: const WidgetStatePropertyAll(BorderSide(color: C.line))),
            onPressed: tap,
            icon: Icon(icon, size: 17),
            label: Text(label));
  }
}

/// "What's on your mind" style composer shown at the top of feeds.
class ComposerCard extends StatelessWidget {
  final VoidCallback onCompose;
  final VoidCallback? onPhoto, onCheckIn, onTrip;
  final String hint;
  const ComposerCard({super.key, required this.onCompose, this.onPhoto, this.onCheckIn, this.onTrip, this.hint = 'Where did you go today?'});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    Widget action(IconData i, String l, Color c, VoidCallback? on) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: on ?? onCompose,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(i, color: c, size: 20),
                const SizedBox(width: 6),
                Flexible(child: Text(l, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600))),
              ]),
            ),
          ),
        );
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(children: [
        Row(children: [
          Avatar(s.avatarSeed, name: s.name, radius: 20),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onCompose,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.line)),
                child: Text(hint, style: const TextStyle(color: C.muted, fontSize: 13.5)),
              ),
            ),
          ),
        ]),
        const Divider(height: 18),
        Row(children: [
          action(Icons.photo_library_rounded, 'Photo', const Color(0xFF7CC08D), onPhoto),
          action(Icons.location_on_rounded, 'Check in', C.danger, onCheckIn),
          action(Icons.map_rounded, 'Trip plan', C.primary, onTrip),
        ]),
      ]),
    );
  }
}

/// Left-column shortcut row on desktop and in the mobile menu list.
class ShortcutTile extends StatelessWidget {
  final Widget leading;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  const ShortcutTile({super.key, required this.leading, required this.label, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(children: [
            leading,
            const SizedBox(width: 12),
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            if (trailing != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: C.danger, borderRadius: BorderRadius.circular(10)),
                child: Text(trailing!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
      );
}

class IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBubble(this.icon, this.color, {super.key, this.size = 36});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withOpacity(.16), borderRadius: BorderRadius.circular(size * .32)),
        child: Icon(icon, color: color, size: size * .55),
      );
}

/// Small pill label.
class Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  const Pill(this.text, {super.key, this.icon, this.color = C.primary});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Overlapping avatars ("Ayesha, Tanvir and 3 others").
class AvatarStack extends StatelessWidget {
  final List<Traveler> people;
  final double radius;
  const AvatarStack(this.people, {super.key, this.radius = 13});
  @override
  Widget build(BuildContext context) {
    final shown = people.take(4).toList();
    return SizedBox(
      height: radius * 2 + 4,
      width: shown.isEmpty ? 0 : radius * 2 + 4 + (shown.length - 1) * radius * 1.3,
      child: Stack(children: [
        for (var i = 0; i < shown.length; i++)
          Positioned(
            left: i * radius * 1.3,
            child: CircleAvatar(radius: radius + 2, backgroundColor: C.card, child: Avatar(shown[i].seed, name: shown[i].name, radius: radius)),
          ),
      ]),
    );
  }
}
