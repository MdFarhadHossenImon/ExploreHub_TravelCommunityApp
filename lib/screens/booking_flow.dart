import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'shell.dart';

List<BookingOption> optionsFor(BookingDraft d) {
  final u = d.unitPrice;
  switch (d.type) {
    case 'flight':
      return [
        BookingOption('Economy', ['23 kg baggage', 'Standard seat', 'Meal on board'], u),
        BookingOption('Premium Economy', ['30 kg baggage', 'Extra legroom', 'Priority boarding'], u * 1.4),
        BookingOption('Business', ['40 kg baggage', 'Lie-flat seat', 'Lounge access'], u * 2.2),
      ];
    case 'train':
    case 'bus':
      return [
        BookingOption('Standard seat', ['Window or aisle', 'Free cancellation 24 h'], u),
        BookingOption('AC comfort', ['Air-conditioned', 'Snack and water', 'Charging port'], u * 1.5),
        BookingOption('Sleeper / First class', ['Reclining berth', 'Blanket and pillow', 'Priority boarding'], u * 2.1),
      ];
    case 'guide':
      return [
        BookingOption('Half day', ['4 hours', 'Local tips', 'Photo help'], u * 0.6),
        BookingOption('Full day', ['8 hours', 'Transport planning', 'Lunch spot picks'], u),
        BookingOption('3-day trip', ['Itinerary design', 'Bookings on your behalf', '24/7 contact'], u * 2.7),
      ];
    default:
      return [
        BookingOption('Standard stay', ['Shared facilities', 'Breakfast included', 'Non-smoking'], u),
        BookingOption('Deluxe with balcony', ['Private room', '2 guests', 'Breakfast included'], u * 1.3),
        BookingOption('Premium package', ['Private room', 'Guided tour', 'All transfers'], u * 1.8),
      ];
  }
}

class BookingFlowScreen extends StatefulWidget {
  final BookingDraft draft;
  const BookingFlowScreen({super.key, required this.draft});
  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  int _step = 0;
  int _adults = 1, _children = 0;
  DateTime? _start, _end;
  String _payment = 'Mastercard';
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _promo = TextEditingController();
  BookingOption? _option;
  double _discount = 0;
  String? _promoMsg;
  Booking? _done;

  BookingDraft get d => widget.draft;
  bool get _single => d.type == 'flight' || d.type == 'train' || d.type == 'bus';

  @override
  void initState() {
    super.initState();
    _name.text = context.read<AppState>().name;
  }

  double get _pax => _adults + _children * 0.5;
  double get _subtotal => (_option?.price ?? d.unitPrice) * _pax;
  double get _fee => _subtotal * 0.05;
  double get _total => _subtotal + _fee - _subtotal * _discount;

  String get _title => _step == 0 ? 'Reservation' : _step == 1 ? (d.type == 'tour' || d.type == 'hotel' ? 'Select Room' : d.type == 'guide' ? 'Choose Package' : 'Select Class') : 'Order Detail';

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final r = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? (_start ?? now).add(Duration(days: isStart ? 7 : 3)),
      firstDate: isStart ? now : (_start ?? now),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (r == null) return;
    setState(() {
      if (isStart) {
        _start = r;
        if (_end != null && _end!.isBefore(r)) _end = null;
      } else {
        _end = r;
      }
    });
  }

  void _next() {
    if (_step == 0) {
      if (_name.text.trim().isEmpty || _phone.text.trim().length < 6) return toast(context, 'Add a name and a valid phone number');
      if (_start == null) return toast(context, 'Pick your ${_single ? 'travel' : 'check-in'} date');
      if (!_single && _end == null) return toast(context, 'Pick your check-out date');
    }
    if (_step == 1 && _option == null) return toast(context, 'Select an option to continue');
    setState(() => _step++);
  }

  Future<void> _confirm() async {
    try {
      final b = await context.read<AppState>().createBooking(draft: d, total: _total, start: _start!, end: _end ?? _start!);
      if (mounted) setState(() => _done = b);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  void _applyPromo() {
    final code = _promo.text.trim().toUpperCase();
    setState(() {
      if (code == 'EXPLORE10') {
        _discount = 0.10;
        _promoMsg = '10% off applied';
      } else {
        _discount = 0;
        _promoMsg = 'Code not valid. Try EXPLORE10';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_done != null) return _success(_done!);
    return ScreenScaffold(
      title: _title,
      onBack: () => _step == 0 ? Navigator.pop(context) : setState(() => _step--),
      bottom: PrimaryButton(_step == 2 ? 'Confirm and pay ${money(_total)}' : 'Next', onPressed: _step == 2 ? _confirm : _next),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        StepBar(_step),
        const SizedBox(height: 18),
        _summary(),
        const SizedBox(height: 16),
        if (_step == 0) ..._stepOne(),
        if (_step == 1) ..._stepTwo(),
        if (_step == 2) ..._stepThree(),
      ]),
    );
  }

  Widget _summary() => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
        child: Row(children: [
          AppImage(d.seed, width: 84, height: 70, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Row(children: [
                Icon(modeIcon(d.type), size: 13, color: C.primary),
                const SizedBox(width: 4),
                Expanded(child: Text(d.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.muted))),
              ]),
              const SizedBox(height: 3),
              Text('${money(_option?.price ?? d.unitPrice)}/person', style: const TextStyle(color: C.primary, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );

  List<Widget> _stepOne() => [
        const Text('Traveler information', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 12),
        LabeledField('Full name', 'As on your ID', controller: _name),
        LabeledField('Phone number', '+880 1XXX XXXXXX', controller: _phone, keyboard: TextInputType.phone),
        Row(children: [
          Expanded(child: QtyStepper('Adult ticket', _adults, (v) => setState(() => _adults = v), min: 1)),
          const SizedBox(width: 12),
          Expanded(child: QtyStepper('Child ticket', _children, (v) => setState(() => _children = v))),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _dateBox(_single ? 'Travel date' : 'Check-in date', _start, () => _pickDate(true))),
          if (!_single) ...[
            const SizedBox(width: 12),
            Expanded(child: _dateBox('Check-out date', _end, () => _pickDate(false))),
          ],
        ]),
        const SizedBox(height: 14),
        const Text('Payment method', style: TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showModalBottomSheet(
            context: context,
            builder: (c) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final m in ['Mastercard', 'Visa', 'bKash', 'Nagad', 'Pay at arrival'])
                  ListTile(
                    leading: Icon(m == 'Pay at arrival' ? Icons.payments_outlined : Icons.credit_card_rounded),
                    title: Text(m),
                    trailing: m == _payment ? const Icon(Icons.check_rounded, color: C.primary) : null,
                    onTap: () {
                      setState(() => _payment = m);
                      Navigator.pop(c);
                    },
                  ),
              ]),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
            child: Row(children: [
              const Icon(Icons.credit_card_rounded, color: C.muted),
              const SizedBox(width: 10),
              Expanded(child: Text(_payment)),
              const Icon(Icons.chevron_right_rounded, color: C.muted),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        const Text('Note', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('- Free for children under 3 years old\n- Free date change up to 48 hours before departure',
            style: TextStyle(color: C.muted, fontSize: 12.5, height: 1.6)),
      ];

  Widget _dateBox(String label, DateTime? v, VoidCallback onTap) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
            child: Text(v == null ? 'DD/MM/YYYY' : fmtDate(v), style: TextStyle(fontSize: 13, color: v == null ? C.muted : C.ink)),
          ),
        ),
      ]);

  List<Widget> _stepTwo() => [
        for (final o in optionsFor(d))
          GestureDetector(
            onTap: () => setState(() => _option = o),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _option == o ? C.tint : C.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _option == o ? C.primary : C.line, width: 1.5),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    for (final line in o.details)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          const Icon(Icons.check_rounded, size: 14, color: C.ok),
                          const SizedBox(width: 6),
                          Text(line, style: const TextStyle(fontSize: 12, color: C.muted)),
                        ]),
                      ),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(money(o.price), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const Text('per person', style: TextStyle(fontSize: 10.5, color: C.muted)),
                  const SizedBox(height: 8),
                  Icon(_option == o ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: C.primary),
                ]),
              ]),
            ),
          ),
      ];

  Widget _row(String l, String v, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l, style: TextStyle(color: bold ? C.ink : C.muted, fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color, fontSize: bold ? 16 : 13)),
        ]),
      );

  List<Widget> _stepThree() => [
        const Text('Book ticket', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
          child: Column(children: [
            _row(_single ? 'Travel date' : 'Check in', _start == null ? '-' : fmtDate(_start!)),
            if (!_single) _row('Check out', _end == null ? '-' : fmtDate(_end!)),
            _row('Option', _option?.name ?? '-'),
            _row('Traveler', _name.text),
            _row('Passengers', '$_adults adult${_adults > 1 ? 's' : ''}${_children > 0 ? ', $_children child' : ''}'),
            _row('Payment', _payment),
            const Divider(height: 24),
            _row('Price', '${money(_option?.price ?? d.unitPrice)} x ${_pax % 1 == 0 ? _pax.toInt() : _pax}'),
            _row('Apps fee', '5%'),
            if (_discount > 0) _row('Promo', '-${money(_subtotal * _discount)}', color: C.ok),
            Row(children: [
              Expanded(child: TextField(controller: _promo, decoration: const InputDecoration(hintText: 'Promo code', isDense: true))),
              const SizedBox(width: 8),
              TextButton(onPressed: _applyPromo, child: const Text('Apply')),
            ]),
            if (_promoMsg != null)
              Align(alignment: Alignment.centerLeft, child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_promoMsg!, style: TextStyle(fontSize: 11.5, color: _discount > 0 ? C.ok : C.danger)),
              )),
            const Divider(height: 24),
            _row('Total price', money(_total), bold: true, color: C.primary),
          ]),
        ),
      ];

  Widget _success(Booking b) => ScreenScaffold(
        title: 'Booking confirmed',
        onBack: () => openTab(context, 3),
        bottom: Row(children: [
          Expanded(child: PrimaryButton('Download Ticket', onPressed: () => toast(context, 'Ticket saved (demo)'))),
          const SizedBox(width: 12),
          Expanded(child: PrimaryButton('Back Home', outlined: true, onPressed: () => openTab(context, 1))),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const StepBar(2),
          const SizedBox(height: 20),
          const Icon(Icons.check_circle_rounded, color: C.ok, size: 64),
          const SizedBox(height: 8),
          const Center(child: Text('You are all set!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
          const SizedBox(height: 4),
          Center(child: Text('Reference ${b.ref}', style: const TextStyle(color: C.muted))),
          const SizedBox(height: 18),
          TicketCard(booking: b),
        ]),
      );
}

/// Ticket with a pseudo-QR block. Replace FakeQr with the `qr_flutter` package for real codes.
class TicketCard extends StatelessWidget {
  final Booking booking;
  const TicketCard({super.key, required this.booking});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
        child: Column(children: [
          Row(children: [
            Icon(modeIcon(booking.type), color: C.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(booking.title, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(money(booking.amount), style: const TextStyle(color: C.primary, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: Text(booking.location, style: const TextStyle(color: C.muted, fontSize: 12.5))),
          const Divider(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Start', style: TextStyle(color: C.muted, fontSize: 11)),
              Text(fmtDate(booking.start), style: const TextStyle(fontWeight: FontWeight.w500)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('End', style: TextStyle(color: C.muted, fontSize: 11)),
              Text(fmtDate(booking.end), style: const TextStyle(fontWeight: FontWeight.w500)),
            ]),
          ]),
          const SizedBox(height: 16),
          FakeQr(booking.ref),
          const SizedBox(height: 6),
          Text(booking.ref, style: const TextStyle(letterSpacing: 2, color: C.muted, fontSize: 12)),
        ]),
      );
}

class FakeQr extends StatelessWidget {
  final String data;
  const FakeQr(this.data, {super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(120, 120), painter: _QrPainter(data));
}

class _QrPainter extends CustomPainter {
  final String data;
  _QrPainter(this.data);
  @override
  void paint(Canvas canvas, Size size) {
    const n = 21;
    final cell = size.width / n;
    final rnd = Random(data.hashCode);
    final paint = Paint()..color = C.ink;
    bool finder(int x, int y) => (x < 7 && y < 7) || (x > n - 8 && y < 7) || (x < 7 && y > n - 8);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final on = finder(x, y)
            ? (x % (n - 7) == 0 || y % (n - 7) == 0 || x % (n - 7) == 6 || y % (n - 7) == 6 || ((x % (n - 7)) >= 2 && (x % (n - 7)) <= 4 && (y % (n - 7)) >= 2 && (y % (n - 7)) <= 4))
            : rnd.nextBool();
        if (on) canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter old) => old.data != data;
}
