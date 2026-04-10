import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../core/widgets/app_widgets.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  Future<void> _toggleLike(
    BuildContext context,
    WidgetRef ref,
    String postId,
  ) async {
    try {
      await ref.read(communityRepositoryProvider).toggleLike(postId);
      ref.invalidate(postsProvider);
      ref.invalidate(savedPostsProvider);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update like: $error')),
      );
    }
  }

  Future<void> _toggleSave(
    BuildContext context,
    WidgetRef ref,
    String postId,
  ) async {
    try {
      await ref.read(communityRepositoryProvider).toggleSavePost(postId);
      ref.invalidate(postsProvider);
      ref.invalidate(savedPostsProvider);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save post: $error')),
      );
    }
  }

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
          for (final post in data)
            PostCard(
              post: post,
              onLike: () => _toggleLike(context, ref, post.id),
              onSave: () => _toggleSave(context, ref, post.id),
            ),
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

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionController = TextEditingController();
  final _locationController = TextEditingController(text: 'Dhaka to Bali');
  final _imageController = TextEditingController(
    text: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
  );
  bool _publishing = false;

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      await ref.read(communityRepositoryProvider).createPost(
            location: _locationController.text.trim(),
            caption: _captionController.text.trim(),
            imageUrl: _imageController.text.trim(),
          );
      ref.invalidate(postsProvider);
      ref.invalidate(savedPostsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post published successfully.')),
      );
      context.go('/app/feed');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish post: $error')),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
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
          TextField(
            controller: _imageController,
            decoration: const InputDecoration(
              hintText: 'Image URL',
              prefixIcon: Icon(Icons.image_outlined),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _publishing ? null : _publish,
            child: Text(_publishing ? 'Publishing...' : 'Publish'),
          ),
        ],
      ),
    );
  }
}
