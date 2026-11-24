import 'package:flutter/material.dart';
import '../core/i18n.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/backend.dart';

// ---------- formatting & navigation helpers ----------

String money(num v) => '\$${v == v.roundToDouble() ? v.toInt() : v.toStringAsFixed(2)}';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Quick page transition: a short fade with a slight upward slide (200 ms in, 150 ms back).
class FastRoute<T> extends PageRouteBuilder<T> {
  FastRoute(Widget page)
      : super(
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 150),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, a, __, child) {
            final t = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: t,
              child: SlideTransition(position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(t), child: child),
            );
          },
        );
}

Future<T?> go<T>(BuildContext c, Widget w) => Navigator.of(c).push<T>(FastRoute<T>(w));

void goRoot(BuildContext c, Widget w) => Navigator.of(c).pushAndRemoveUntil(FastRoute(w), (r) => false);

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(tr(m)), behavior: SnackBarBehavior.floating));

IconData modeIcon(String m) {
  switch (m) {
    case 'flight':
      return Icons.flight_rounded;
    case 'train':
      return Icons.train_rounded;
    case 'bus':
      return Icons.directions_bus_rounded;
    case 'boat':
      return Icons.directions_boat_rounded;
    case 'jeep':
      return Icons.directions_car_rounded;
    case 'trek':
      return Icons.hiking_rounded;
    case 'hotel':
    case 'tour':
      return Icons.apartment_rounded;
    case 'guide':
      return Icons.badge_rounded;
    default:
      return Icons.info_outline_rounded;
  }
}

// ---------- images ----------

/// Offline preview build (`--dart-define=PREVIEW=true`): images come from bundled
/// illustrations so the app can run where remote images are blocked.
const kPreview = bool.fromEnvironment('PREVIEW');

int _hash(String s) {
  var h = 5381;
  for (final c in s.codeUnits) {
    h = ((h << 5) + h + c) & 0x7fffffff;
  }
  return h;
}

/// Picks a bundled scene that matches the seed's theme (beach, lake, desert, city, mountains).
String previewImage(String seed) {
  final k = seed.toLowerCase();
  bool has(List<String> w) => w.any(k.contains);
  int kind;
  if (has(['reef', 'beach', 'coxs', 'raja', 'santorini', 'island', 'coral', 'manta', 'oia', 'dive'])) {
    kind = 1;
  } else if (has(['lake', 'kaptai', 'haor', 'boat', 'ghat', 'river'])) {
    kind = 2;
  } else if (has(['sahara', 'dune', 'desert', 'merzouga', 'marrakech', 'riad', 'camp'])) {
    kind = 3;
  } else if (has(['kyoto', 'city', 'night', 'street', 'market', 'osaka', 'lantern', 'gion', 'food', 'hostel', 'bus'])) {
    kind = 5;
  } else if (has(['sajek', 'himalaya', 'annapurna', 'machu', 'trek', 'hill', 'cloud', 'kanchen', 'everest', 'mountain'])) {
    kind = _hash(k).isEven ? 0 : 4;
  } else {
    kind = _hash(k) % 6;
  }
  return 'assets/demo/p${kind + 6 * (_hash(k) % 6)}.jpg';
}

const _women = ['me', 'ayesha', 'meilin', 'nora', 'eleni', 'lena', 'hana', 'lucia', 'yuki', 'mei lin'];
const _men = ['carlos', 'tanvir', 'sam', 'arjun', 'rahim', 'pema', 'andi', 'youssef', 'marco'];

/// Stable, distinct illustrated avatars for the demo travelers.
String previewAvatar(String seed) {
  final k = seed.toLowerCase();
  final w = _women.indexOf(k), m = _men.indexOf(k);
  final i = w >= 0
      ? (w * 2) % 24
      : m >= 0
          ? (m * 2 + 1) % 24
          : _hash(k) % 24;
  return 'assets/demo/a$i.jpg';
}

/// Network image with a branded gradient while loading or offline.
/// Swap the URL builder for your CDN / Firebase Storage later.
class AppImage extends StatelessWidget {
  final String seed;
  final double? width, height;
  final double radius;
  final BoxFit fit;
  const AppImage(this.seed, {super.key, this.width, this.height, this.radius = 16, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final fallback = SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF3A6D66), C.sky], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: const Icon(Icons.landscape_rounded, color: Colors.white54, size: 34),
      ),
    );
    if (kPreview && !seed.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(width: width, height: height, child: Image.asset(previewImage(seed), fit: fit, errorBuilder: (c, e, s) => fallback)),
      );
    }
    // Live mode shows only real photos; anything without a URL gets the branded placeholder.
    if (Backend.on && !seed.startsWith('http')) {
      return ClipRRect(borderRadius: BorderRadius.circular(radius), child: SizedBox(width: width, height: height, child: fallback));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Image.network(
          seed.startsWith('http') ? seed : 'https://picsum.photos/seed/$seed/800/600',
          fit: fit,
          loadingBuilder: (c, child, p) => p == null ? child : fallback,
          errorBuilder: (c, e, s) => fallback,
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String seed, name;
  final double radius;
  const Avatar(this.seed, {super.key, this.name = '?', this.radius = 20});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: C.sky,
        foregroundImage: seed.isEmpty || (Backend.on && !seed.startsWith('http'))
            ? null
            : kPreview && !seed.startsWith('http')
                ? AssetImage(previewAvatar(seed)) as ImageProvider
                : NetworkImage(seed.startsWith('http') ? seed : 'https://i.pravatar.cc/150?u=$seed'),
        onForegroundImageError: seed.isEmpty ? null : (_, __) {},
        child: Text(name.isEmpty ? '?' : name[0], style: const TextStyle(color: C.on, fontWeight: FontWeight.w700)),
      );
}

// ---------- buttons & fields ----------

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final IconData? icon;
  const PrimaryButton(this.label, {super.key, this.onPressed, this.outlined = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final text = Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
      Flexible(child: Text(tr(label), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500))),
    ]);
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: outlined
          ? OutlinedButton(onPressed: onPressed, style: OutlinedButton.styleFrom(foregroundColor: C.primary, side: const BorderSide(color: C.primary), shape: shape), child: text)
          : FilledButton(onPressed: onPressed, style: FilledButton.styleFrom(backgroundColor: C.primary, foregroundColor: C.on, shape: shape), child: text),
    );
  }
}

class LabeledField extends StatelessWidget {
  final String label, hint;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  final int maxLines;
  const LabeledField(this.label, this.hint, {super.key, this.controller, this.obscure = false, this.keyboard, this.validator, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(label), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            validator: validator,
            maxLines: maxLines,
            decoration: InputDecoration(hintText: hint),
          ),
        ]),
      );
}

class QtyStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;
  const QtyStepper(this.label, this.value, this.onChanged, {super.key, this.min = 0});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr(label), style: const TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove_rounded)),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w600)),
            IconButton(onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add_rounded)),
          ]),
        ),
      ]);
}

// ---------- layout ----------

class BackCircle extends StatelessWidget {
  final VoidCallback? onTap;
  const BackCircle({super.key, this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap ?? () => Navigator.of(context).maybePop(),
          child: const DecoratedBox(
            decoration: BoxDecoration(color: C.card, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: C.line))),
            child: Icon(Icons.chevron_left_rounded, size: 26),
          ),
        ),
      );
}

/// Standard inner-screen scaffold: back button, centered title,
/// content limited to [maxWidth], optional sticky bottom action.
class ScreenScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? bottom;
  final List<Widget>? actions;
  final double maxWidth;
  final VoidCallback? onBack;
  const ScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottom,
    this.actions,
    this.maxWidth = 640,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(leading: BackCircle(onTap: onBack), leadingWidth: 56, title: Text(tr(title)), actions: actions),
        body: Constrained(maxWidth: maxWidth, child: body),
        bottomNavigationBar: bottom == null
            ? null
            : Material(
                color: C.card,
                elevation: 0,
                child: SafeArea(
                  top: false,
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: bottom),
                    ),
                  ),
                ),
              ),
      );
}

class StepBar extends StatelessWidget {
  final int step; // 0..2
  const StepBar(this.step, {super.key});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < 3; i++) {
      items.add(Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: i <= step ? C.primary : C.card),
        child: Text('${i + 1}', style: TextStyle(color: i <= step ? C.on : C.muted, fontWeight: FontWeight.w700, fontSize: 13)),
      ));
      if (i < 2) {
        items.add(Expanded(child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 6), color: i < step ? C.primary : C.line)));
      }
    }
    return Row(children: items);
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const SectionHeader(this.title, {super.key, this.onSeeAll});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(tr(title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if (onSeeAll != null) GestureDetector(onTap: onSeeAll, child: Text(tr('See All'), style: TextStyle(color: C.primary, fontSize: 13))),
        ]),
      );
}

class RatingText extends StatelessWidget {
  final double rating;
  final int? reviews;
  final Color? color;
  const RatingText(this.rating, {super.key, this.reviews, this.color});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, color: C.star, size: 16),
        const SizedBox(width: 3),
        Text(rating == 0 ? tr('New on ExploreHub') : (reviews == null ? '$rating' : '$rating ($reviews ${tr('Reviews')})'), style: TextStyle(fontSize: 12, color: color ?? C.muted)),
      ]);
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, hint;
  const EmptyState(this.icon, this.title, this.hint, {super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: C.sky),
            const SizedBox(height: 12),
            Text(tr(title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(tr(hint), textAlign: TextAlign.center, style: const TextStyle(color: C.muted, fontSize: 13)),
          ]),
        ),
      );
}

/// Bookmark button shared by place cards.
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;
  const RoundIconButton(this.icon, this.onTap, {super.key, this.color = C.primary, this.size = 32});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: Color(0x99132625), shape: BoxShape.circle),
          child: Icon(icon, size: size * 0.55, color: color),
        ),
      );
}
