import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../backend/models/app_models.dart';
import '../theme/app_theme.dart';

class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.value,
    required this.builder,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Something went wrong: $error'),
        ),
      ),
    );
  }
}

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(height: 28),
              ],
              Text(title, style: theme.textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 10),
                Text(subtitle!, style: theme.textTheme.bodyLarge),
              ],
              const SizedBox(height: 28),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class ExploreHeader extends StatelessWidget {
  const ExploreHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(subtitle, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class MetricChip extends StatelessWidget {
  const MetricChip({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto({
    super.key,
    required this.url,
    this.height = 220,
    this.fit = BoxFit.cover,
    this.borderRadius = 24,
  });

  final String url;
  final double height;
  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: '$url?auto=format&fit=crop&w=1200&q=80',
        height: height,
        width: double.infinity,
        fit: fit,
        placeholder: (context, _) => Container(
          color: const Color(0xFFE5EEF5),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
        errorWidget: (context, _, __) => Container(
          color: const Color(0xFFE5EEF5),
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_outlined),
        ),
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
  });

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFDCEEFF),
                child: Text(post.author.substring(0, 1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.author, style: theme.textTheme.titleMedium),
                    Text(post.location, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz),
            ],
          ),
          const SizedBox(height: 14),
          Text(post.caption, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 14),
          NetworkPhoto(url: post.imageUrl),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: post.tags.map((tag) => Chip(label: Text(tag))).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              MetricChip(icon: Icons.favorite_rounded, label: '${post.likes}'),
              const SizedBox(width: 10),
              MetricChip(icon: Icons.chat_bubble_rounded, label: '${post.comments}'),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.bookmark_border_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DealCard extends StatelessWidget {
  const DealCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.priceLabel,
    required this.metrics,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final String priceLabel;
  final List<Widget> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFE),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              NetworkPhoto(url: imageUrl, height: 180),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    priceLabel,
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: metrics),
        ],
      ),
    );
  }
}
