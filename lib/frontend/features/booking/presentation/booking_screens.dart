import 'package:explorehub_flutter/backend/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../core/widgets/app_widgets.dart';

class HotelsScreen extends ConsumerWidget {
  const HotelsScreen({super.key});

  Future<void> _bookHotel(
    BuildContext context,
    WidgetRef ref,
    HotelDeal hotel,
  ) async {
    try {
      await ref.read(bookingRepositoryProvider).createBooking(
            type: 'hotel',
            itemId: hotel.id,
            title: hotel.name,
            subtitle: hotel.city,
            price: hotel.pricePerNight,
          );
      ref.invalidate(bookingsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${hotel.name} booked.')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not book hotel: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotels = ref.watch(hotelsProvider);
    return AsyncSection(
      value: hotels,
      builder: (data) => Column(
        children: [
          const ExploreHeader(
            title: 'Hotels',
            subtitle: 'Community-loved stays with flexible booking options.',
          ),
          const SizedBox(height: 20),
          for (final hotel in data)
            DealCard(
              title: hotel.name,
              subtitle: hotel.city,
              imageUrl: hotel.imageUrl,
              priceLabel: '\$${hotel.pricePerNight}/night',
              metrics: [
                MetricChip(
                  icon: Icons.star_rounded,
                  label: hotel.rating.toStringAsFixed(1),
                ),
                for (final feature in hotel.features)
                  MetricChip(icon: Icons.check_circle_outline, label: feature),
              ],
              action: () => _bookHotel(context, ref, hotel),
              actionLabel: 'Book Hotel',
            ),
        ],
      ),
    );
  }
}

class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  Future<void> _bookTicket(
    BuildContext context,
    WidgetRef ref,
    TicketDeal ticket,
  ) async {
    try {
      await ref.read(bookingRepositoryProvider).createBooking(
            type: 'ticket',
            itemId: ticket.id,
            title: '${ticket.from} to ${ticket.to}',
            subtitle: ticket.carrier,
            price: ticket.price,
          );
      ref.invalidate(bookingsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ticket.from} to ${ticket.to} booked.')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not book ticket: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(ticketsProvider);
    final formatter = DateFormat('dd MMM, hh:mm a');
    return AsyncSection(
      value: tickets,
      builder: (data) => Column(
        children: [
          const ExploreHeader(
            title: 'Tickets',
            subtitle: 'Flight picks with traveler-friendly schedules.',
          ),
          const SizedBox(height: 20),
          for (final ticket in data)
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFE),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${ticket.from}  ->  ${ticket.to}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      MetricChip(
                        icon: Icons.sell_outlined,
                        label: '\$${ticket.price}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ticket.carrier,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      MetricChip(
                        icon: Icons.schedule_rounded,
                        label: formatter.format(ticket.departure),
                      ),
                      MetricChip(
                        icon: Icons.flight_takeoff_rounded,
                        label: ticket.duration,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _bookTicket(context, ref, ticket),
                    child: const Text('Book Ticket'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
