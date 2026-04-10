import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/widgets/app_widgets.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotels = ref.watch(hotelsProvider);
    return AsyncSection(
      value: hotels,
      builder: (data) => Column(
        children: [
          const ExploreHeader(
            title: 'Saved',
            subtitle: 'Your shortlist for stays and trip planning.',
          ),
          const SizedBox(height: 20),
          for (final hotel in data.take(2))
            DealCard(
              title: hotel.name,
              subtitle: '${hotel.city} • Saved from community',
              imageUrl: hotel.imageUrl,
              priceLabel: '\$${hotel.pricePerNight}',
              metrics: hotel.features
                  .map((feature) => MetricChip(
                        icon: Icons.bookmark_added_outlined,
                        label: feature,
                      ))
                  .toList(),
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
    return AsyncSection(
      value: user,
      builder: (data) => Column(
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
                  '${data.handle} • ${data.homeCity}',
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.shield_moon_outlined),
            title: const Text('Travel preferences'),
            subtitle: const Text('Budget stays, local food, and scenic train routes'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.card_travel_outlined),
            title: const Text('Upcoming bookings'),
            subtitle: const Text('1 hotel, 2 flights waiting for confirmation'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
