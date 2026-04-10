import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../backend/models/app_models.dart';
import '../../../core/widgets/app_widgets.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedPosts = ref.watch(savedPostsProvider);
    return AsyncSection(
      value: savedPosts,
      builder: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExploreHeader(
            title: 'Saved',
            subtitle: 'Posts you bookmarked from the traveler community.',
          ),
          const SizedBox(height: 20),
          if (data.isEmpty)
            const Text('No saved posts yet. Save items from the feed to see them here.'),
          for (final post in data)
            PostCard(
              post: post,
              onLike: () async {
                await ref.read(communityRepositoryProvider).toggleLike(post.id);
                ref.invalidate(postsProvider);
                ref.invalidate(savedPostsProvider);
              },
              onSave: () async {
                await ref.read(communityRepositoryProvider).toggleSavePost(post.id);
                ref.invalidate(postsProvider);
                ref.invalidate(savedPostsProvider);
              },
            ),
        ],
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final bookings = ref.watch(bookingsProvider);
    return AsyncSection(
      value: user,
      builder: (data) {
        if (data == null) {
          return const Text('Log in to view your profile.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExploreHeader(
              title: 'Profile',
              subtitle: 'Your traveler identity, saved plans, and booking footprint.',
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2681CA), Color(0xFF69AEE4)],
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 34,
                    child: Text(data.name.substring(0, 1)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium!
                        .copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${data.handle} - ${data.homeCity}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    data.bio,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      MetricChip(
                        icon: Icons.people_alt_outlined,
                        label: '${data.stats.followers} followers',
                      ),
                      MetricChip(
                        icon: Icons.luggage_outlined,
                        label: '${data.stats.trips} trips',
                      ),
                      MetricChip(
                        icon: Icons.receipt_long_outlined,
                        label: '${data.stats.bookings} bookings',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            bookings.when(
              data: (items) => _BookingsList(items: items),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => Text('Could not load bookings: $error'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign out'),
              subtitle: const Text('Close your session on this device'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await ref.read(authRepositoryProvider).signOut();
                ref.invalidate(currentUserProvider);
                ref.invalidate(bookingsProvider);
                ref.invalidate(postsProvider);
                ref.invalidate(savedPostsProvider);
                if (context.mounted) {
                  context.go('/auth');
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _BookingsList extends StatelessWidget {
  const _BookingsList({required this.items});

  final List<BookingRecord> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.card_travel_outlined),
        title: Text('No bookings yet'),
        subtitle: Text('Use the Hotels and Tickets tabs to create bookings.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent bookings',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final booking in items.take(4))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              booking.type == 'hotel'
                  ? Icons.hotel_outlined
                  : Icons.flight_outlined,
            ),
            title: Text(booking.title),
            subtitle: Text('${booking.subtitle} - ${booking.status}'),
            trailing: Text('\$${booking.price}'),
          ),
      ],
    );
  }
}
