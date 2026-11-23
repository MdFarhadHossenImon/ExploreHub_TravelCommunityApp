import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'community.dart';
import 'search.dart';
import 'shell.dart';
import '../data/backend.dart';
import '../data/mock_data.dart';

/// Settings & privacy (opened from Menu and from "Edit profile").
class ProfileScreen extends StatelessWidget {
  final bool standalone;
  const ProfileScreen({super.key, this.standalone = false});

  Widget _tile(IconData icon, String title, VoidCallback? onTap, {String? trailing, Color? color}) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: color ?? C.muted),
        title: Text(title, style: TextStyle(fontSize: 14, color: color)),
        trailing: trailing == null ? null : Text(trailing, style: const TextStyle(color: C.muted, fontSize: 12.5)),
        onTap: onTap,
      );

  Widget _h(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 4),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      );

  Widget _stat(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          Text(l, style: const TextStyle(color: C.muted, fontSize: 12)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final mine = s.myPosts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & privacy'),
        automaticallyImplyLeading: false,
        leading: standalone ? const BackCircle() : null,
        leadingWidth: standalone ? 56 : null,
      ),
      body: Constrained(
        maxWidth: 640,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          Center(child: Avatar(s.avatarSeed, name: s.name, radius: 46)),
          const SizedBox(height: 10),
          Center(child: Text(s.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
          Center(child: Text(s.email, style: const TextStyle(color: C.muted, fontSize: 13))),
          const SizedBox(height: 16),
          Row(children: [
            _stat('${mine.length}', 'Posts'),
            _stat('1.2k', 'Followers'),
            _stat('${s.bookings.where((b) => b.status != 'Cancelled').length}', 'Trips'),
          ]),
          if (mine.isNotEmpty) ...[
            _h('My posts'),
            const SizedBox(height: 8),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mine.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (c, i) => GestureDetector(
                  onTap: () => go(context, Scaffold(appBar: AppBar(title: const Text('My post')), body: SingleChildScrollView(child: PostCard(mine[i])))),
                  child: AppImage(mine[i].imageSeed, width: 90, height: 90, radius: 12),
                ),
              ),
            ),
          ],
          _h('My Account'),
          _tile(Icons.person_outline_rounded, 'Personal information', () {
            final ctl = TextEditingController(text: s.name);
            showDialog(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Edit name'),
                content: TextField(controller: ctl),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () {
                      if (ctl.text.trim().isNotEmpty) s.updateName(ctl.text.trim());
                      Navigator.pop(c);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
          }),
          _tile(Icons.language_rounded, 'Language', () {
            showModalBottomSheet(
              context: context,
              builder: (c) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final l in ['English (US)', 'Bangla', 'Hindi', 'Spanish', 'Japanese'])
                    ListTile(
                      title: Text(l),
                      trailing: l == s.language ? const Icon(Icons.check_rounded, color: C.primary) : null,
                      onTap: () {
                        s.setLanguage(l);
                        Navigator.pop(c);
                      },
                    ),
                ]),
              ),
            );
          }, trailing: s.language),
          _tile(Icons.bookmark_border_rounded, 'Saved places', () => go(context, const SavedPlacesScreen())),
          _tile(Icons.shield_outlined, 'Privacy Policy', () => go(context, const _InfoScreen('Privacy Policy', [
                ('What we collect', 'Your profile, bookings and the posts you share. We never sell personal data.'),
                ('Your choices', 'You can edit or delete posts and bookings, and turn notifications off at any time.'),
              ]))),
          _h('Notifications'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_none_rounded, color: C.muted),
            title: const Text('Push Notifications', style: TextStyle(fontSize: 14)),
            value: s.push,
            activeColor: C.ok,
            onChanged: s.setPush,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.local_offer_outlined, color: C.muted),
            title: const Text('Promotional Notifications', style: TextStyle(fontSize: 14)),
            value: s.promo,
            activeColor: C.ok,
            onChanged: s.setPromo,
          ),
          _h('More'),
          _tile(Icons.help_outline_rounded, 'Help Center', () => go(context, const _InfoScreen('Help Center', [
                ('How do I book a trip?', 'Open a place, tap Book a Trip, then follow the three steps. You can also book flights, trains, buses and guides from Explore.'),
                ('Can I cancel?', 'Open Trips, choose See detail, then Cancel booking. Refunds follow each operator policy.'),
                ('How do I share photos?', 'Go to Community and tap Share trip.'),
              ]))),
          _tile(Icons.logout_rounded, 'Log Out', () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Log out of ExploreHub?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Stay')),
                  FilledButton(style: FilledButton.styleFrom(backgroundColor: C.danger), onPressed: () => Navigator.pop(c, true), child: const Text('Log out')),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              await s.logout();
              shellTab.value = 0;
              if (context.mounted) goRoot(context, const WelcomeScreen());
            }
          }, color: C.danger),
          _tile(Icons.delete_forever_outlined, 'Delete account', () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Delete your account?'),
                content: const Text('This permanently deletes your profile, posts, comments, saved items and bookings. It cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep account')),
                  FilledButton(style: FilledButton.styleFrom(backgroundColor: C.danger), onPressed: () => Navigator.pop(c, true), child: const Text('Delete forever')),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              try {
                await s.deleteAccount();
                shellTab.value = 0;
                if (context.mounted) goRoot(context, const WelcomeScreen());
              } catch (e) {
                if (context.mounted) toast(context, errText(e));
              }
            }
          }, color: C.danger),
        ]),
      ),
    );
  }
}

class SavedPlacesScreen extends StatelessWidget {
  const SavedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ids = context.watch<AppState>().savedPlaces;
    final list = places.where((p) => ids.contains(p.id)).toList();
    return ScreenScaffold(
      title: 'Saved places',
      body: list.isEmpty
          ? const EmptyState(Icons.bookmark_border_rounded, 'Nothing saved yet', 'Tap the bookmark on any place to keep it for later.')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (c, i) => SizedBox(height: 116, child: PlaceCard(list[i])),
            ),
    );
  }
}

class _InfoScreen extends StatelessWidget {
  final String title;
  final List<(String, String)> sections;
  const _InfoScreen(this.title, this.sections);

  @override
  Widget build(BuildContext context) => ScreenScaffold(
        title: title,
        body: ListView(padding: const EdgeInsets.all(20), children: [
          for (final s in sections) ...[
            Text(s.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(s.$2, style: const TextStyle(color: C.muted, height: 1.6)),
            const SizedBox(height: 18),
          ],
        ]),
      );
}
