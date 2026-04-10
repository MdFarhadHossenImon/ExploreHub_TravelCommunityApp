import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../booking/presentation/booking_screens.dart';
import '../../community/presentation/community_screens.dart';
import '../../profile/presentation/profile_screens.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.currentTab,
  });

  final String currentTab;

  static const _tabs = ['feed', 'discover', 'hotels', 'tickets', 'saved', 'profile'];

  int get _index {
    final index = _tabs.indexOf(currentTab);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const FeedScreen(),
      const DiscoverScreen(),
      const HotelsScreen(),
      const TicketsScreen(),
      const SavedScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF7FBFF), Colors.white],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            child: pages[_index],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => context.go('/app/${_tabs[index]}'),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.hotel_outlined), label: 'Hotels'),
          NavigationDestination(icon: Icon(Icons.flight_outlined), label: 'Tickets'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), label: 'Saved'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
