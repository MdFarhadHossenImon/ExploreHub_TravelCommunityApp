import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../core/widgets/app_widgets.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(postsProvider);
    return AsyncSection(
      value: posts,
      builder: (data) => Column(
        children: [
          ExploreHeader(
            title: 'Traveler Feed',
            subtitle: 'Stories, tips, and itineraries from the community.',
            trailing: FilledButton.tonalIcon(
              onPressed: () => context.go('/app/create-post'),
              icon: const Icon(Icons.add),
              label: const Text('Post'),
            ),
          ),
          const SizedBox(height: 20),
          for (final post in data) PostCard(post: post),
        ],
      ),
    );
  }
}

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = ref.watch(destinationsProvider);
    return AsyncSection(
      value: destinations,
      builder: (data) => Column(
        children: [
          const ExploreHeader(
            title: 'Discover Trips',
            subtitle: 'Trending destinations with active traveler circles.',
          ),
          const SizedBox(height: 20),
          for (final item in data)
            DealCard(
              title: '${item.name}, ${item.country}',
              subtitle: item.description,
              imageUrl: item.imageUrl,
              priceLabel: item.bestTime,
              metrics: [
                MetricChip(
                  icon: Icons.people_alt_rounded,
                  label: '${item.communityCount} members',
                ),
                const MetricChip(
                  icon: Icons.map_outlined,
                  label: 'Guides available',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionController = TextEditingController();
  final _locationController = TextEditingController(text: 'Dhaka to Bali');

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Create Post',
      subtitle: 'Share a destination tip, booking hack, or trip moment.',
      leading: IconButton(
        onPressed: () => context.go('/app/feed'),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      child: Column(
        children: [
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(
              hintText: 'Location',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _captionController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Tell travelers what made this place worth it...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F9FC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD0D5DD)),
            ),
            child: const Column(
              children: [
                Icon(Icons.add_photo_alternate_outlined, size: 34),
                SizedBox(height: 8),
                Text('Add trip photo or short reel preview'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/app/feed'),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }
}
