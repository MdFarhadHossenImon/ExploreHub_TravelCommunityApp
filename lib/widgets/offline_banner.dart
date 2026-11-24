import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/offline.dart';

/// Thin strip at the top of every screen while the device is offline.
class OfflineBanner extends StatelessWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Offline.online,
      builder: (context, on, _) => Column(children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: on
              ? const SizedBox(width: double.infinity)
              : Material(
                  color: C.primary,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      child: Row(children: [
                        const Icon(Icons.cloud_off_rounded, size: 17, color: C.on),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(tr('Offline: showing your saved places, trips and tickets'),
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.on, fontWeight: FontWeight.w700, fontSize: 12.5)),
                        ),
                      ]),
                    ),
                  ),
                ),
        ),
        Expanded(
          child: on ? child : MediaQuery.removePadding(context: context, removeTop: true, child: child),
        ),
      ]),
    );
  }
}
