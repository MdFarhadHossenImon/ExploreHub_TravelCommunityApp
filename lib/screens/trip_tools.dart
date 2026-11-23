import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/backend.dart';
import '../data/social.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/social_widgets.dart';

/// Everyone on the trip: you plus invited buddies, as (id, name).
List<(String, String)> _members(BuildContext context, TripPlan t) {
  final me = Backend.uid ?? meId;
  final out = <(String, String)>[(me, 'You')];
  for (final id in t.buddies) {
    if (id == me) continue;
    out.add((id, travelerById(id).name));
  }
  return out;
}

String _name(List<(String, String)> m, String id) => m.firstWhere((x) => x.$1 == id, orElse: () => (id, 'A traveler')).$2;

// ---------------------------------------------------------------- expenses

class _Expense {
  final String id, title, paidBy;
  final double amount;
  final List<String> split;
  final DateTime at;
  _Expense(this.id, this.title, this.amount, this.paidBy, this.split, this.at);
  factory _Expense.fromRow(Map<String, dynamic> r) => _Expense(
        r['id'] as String,
        r['title'] as String,
        (r['amount'] as num).toDouble(),
        r['paid_by'] as String,
        List<String>.from(r['split_with'] as List? ?? const []),
        DateTime.parse(r['created_at'] as String).toLocal(),
      );
}

/// Splitwise-style shared costs for a trip: who paid what, and who owes whom.
class TripExpensesScreen extends StatefulWidget {
  final TripPlan trip;
  const TripExpensesScreen({super.key, required this.trip});
  @override
  State<TripExpensesScreen> createState() => _TripExpensesScreenState();
}

class _TripExpensesScreenState extends State<TripExpensesScreen> {
  final List<_Expense> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Backend.on) return setState(() => _loading = false);
    try {
      final rows = await Backend.tripExpenses(widget.trip.id);
      _items
        ..clear()
        ..addAll(rows.map(_Expense.fromRow));
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Net balance per member: positive means others owe them.
  Map<String, double> _balances(List<(String, String)> members) {
    final b = {for (final m in members) m.$1: 0.0};
    for (final e in _items) {
      final split = e.split.isEmpty ? members.map((m) => m.$1).toList() : e.split;
      b[e.paidBy] = (b[e.paidBy] ?? 0) + e.amount;
      for (final id in split) {
        b[id] = (b[id] ?? 0) - e.amount / split.length;
      }
    }
    return b;
  }

  /// Fewest payments that settle everyone up.
  List<(String, String, double)> _settle(Map<String, double> bal) {
    final debt = bal.entries.where((e) => e.value < -0.01).map((e) => [e.key, -e.value]).toList();
    final cred = bal.entries.where((e) => e.value > 0.01).map((e) => [e.key, e.value]).toList();
    debt.sort((a, b) => (b[1] as double).compareTo(a[1] as double));
    cred.sort((a, b) => (b[1] as double).compareTo(a[1] as double));
    final out = <(String, String, double)>[];
    var i = 0, j = 0;
    while (i < debt.length && j < cred.length) {
      final pay = (debt[i][1] as double) < (cred[j][1] as double) ? debt[i][1] as double : cred[j][1] as double;
      out.add((debt[i][0] as String, cred[j][0] as String, pay));
      debt[i][1] = (debt[i][1] as double) - pay;
      cred[j][1] = (cred[j][1] as double) - pay;
      if ((debt[i][1] as double) < 0.01) i++;
      if ((cred[j][1] as double) < 0.01) j++;
    }
    return out;
  }

  Future<void> _add(List<(String, String)> members) async {
    final title = TextEditingController();
    final amount = TextEditingController();
    var paidBy = members.first.$1;
    final split = members.map((m) => m.$1).toSet();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, MediaQuery.of(c).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Add an expense', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              LabeledField('What for', 'e.g. Boat hire, dinner, hostel', controller: title),
              LabeledField('Amount (USD)', 'e.g. 45', controller: amount, keyboard: const TextInputType.numberWithOptions(decimal: true)),
              const Text('Paid by', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in members)
                  ChoiceChip(label: Text(m.$2), selected: paidBy == m.$1, onSelected: (_) => set(() => paidBy = m.$1)),
              ]),
              const SizedBox(height: 12),
              const Text('Split between', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in members)
                  FilterChip(
                    label: Text(m.$2),
                    selected: split.contains(m.$1),
                    onSelected: (v) => set(() => v ? split.add(m.$1) : (split.length > 1 ? split.remove(m.$1) : null)),
                  ),
              ]),
              const SizedBox(height: 16),
              PrimaryButton('Add expense', onPressed: () => Navigator.pop(c, true)),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    final value = double.tryParse(amount.text.trim().replaceAll(',', ''));
    if (title.text.trim().isEmpty || value == null || value <= 0) {
      if (mounted) toast(context, 'Add a name and an amount above 0');
      return;
    }
    final splitList = split.length == members.length ? <String>[] : split.toList();
    if (Backend.on) {
      try {
        await Backend.addTripExpense(widget.trip.id, title.text.trim(), value, paidBy, splitList);
        await _load();
      } catch (e) {
        if (mounted) toast(context, errText(e));
      }
    } else {
      setState(() => _items.insert(0, _Expense('${DateTime.now().millisecondsSinceEpoch}', title.text.trim(), value, paidBy, splitList, DateTime.now())));
    }
  }

  Future<void> _remove(_Expense e) async {
    setState(() => _items.remove(e));
    if (Backend.on) {
      try {
        await Backend.deleteTripExpense(e.id);
      } catch (err) {
        if (mounted) toast(context, errText(err));
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _members(context, widget.trip);
    final bal = _balances(members);
    final settle = _settle(bal);
    final total = _items.fold<double>(0, (a, e) => a + e.amount);
    final me = Backend.uid ?? meId;
    return ScreenScaffold(
      title: 'Trip expenses',
      bottom: PrimaryButton('Add expense', icon: Icons.add_rounded, onPressed: () => _add(members)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
                Panel(
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Total spent', style: TextStyle(color: C.muted, fontSize: 12.5)),
                        Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('Your balance', style: TextStyle(color: C.muted, fontSize: 12.5)),
                      Text(
                        (bal[me] ?? 0) >= 0 ? '+\$${(bal[me] ?? 0).toStringAsFixed(2)}' : '-\$${(-(bal[me] ?? 0)).toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: (bal[me] ?? 0) >= 0 ? const Color(0xFF30A46C) : C.danger),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),
                const Text('Settle up', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (settle.isEmpty)
                  const Text('Everyone is even.', style: TextStyle(color: C.muted))
                else
                  for (final s in settle)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(backgroundColor: C.card, child: Icon(Icons.swap_horiz_rounded, color: C.primary)),
                      title: Text('${_name(members, s.$1)} pays ${_name(members, s.$2)}'),
                      trailing: Text('\$${s.$3.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                const SizedBox(height: 14),
                const Text('Expenses', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: EmptyState(Icons.receipt_long_outlined, 'No expenses yet', 'Log shared costs and ExploreHub works out who owes whom.'),
                  ),
                for (final e in _items)
                  Dismissible(
                    key: ValueKey(e.id),
                    direction: DismissDirection.endToStart,
                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: C.danger, child: const Icon(Icons.delete_rounded, color: Colors.white)),
                    onDismissed: (_) => _remove(e),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(backgroundColor: C.card, child: Icon(Icons.receipt_long_rounded, color: C.primary)),
                      title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${_name(members, e.paidBy)} paid · split ${e.split.isEmpty ? 'with everyone' : 'between ${e.split.length}'} · ${fmtDate(e.at)}',
                          style: const TextStyle(fontSize: 12, color: C.muted)),
                      trailing: Text('\$${e.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                if (_items.isNotEmpty) const Text('Swipe left on an expense to delete it.', style: TextStyle(fontSize: 11.5, color: C.muted)),
              ]),
            ),
    );
  }
}

// ---------------------------------------------------------------- packing list

const _essentials = <(String, String)>[
  ('Passport or national ID', 'Documents'),
  ('Visa and travel insurance copies', 'Documents'),
  ('Tickets and hotel bookings', 'Documents'),
  ('Cash and cards', 'Documents'),
  ('Phone charger', 'Electronics'),
  ('Power bank', 'Electronics'),
  ('Universal travel adapter', 'Electronics'),
  ('Earphones', 'Electronics'),
  ('Personal medicines', 'Health'),
  ('First-aid kit', 'Health'),
  ('Sunscreen', 'Health'),
  ('Insect repellent', 'Health'),
  ('Toiletries', 'Health'),
  ('Comfortable walking shoes', 'Clothes'),
  ('Rain jacket', 'Clothes'),
  ('Warm layer', 'Clothes'),
  ('Sunglasses and hat', 'Clothes'),
  ('Reusable water bottle', 'Other'),
  ('Daypack', 'Other'),
  ('Padlock', 'Other'),
];

class _Item {
  final String id, title, category;
  bool done;
  _Item(this.id, this.title, this.category, this.done);
}

/// Shared packing checklist for everyone on the trip.
class TripPackingScreen extends StatefulWidget {
  final TripPlan trip;
  const TripPackingScreen({super.key, required this.trip});
  @override
  State<TripPackingScreen> createState() => _TripPackingScreenState();
}

class _TripPackingScreenState extends State<TripPackingScreen> {
  final List<_Item> _items = [];
  bool _loading = true;
  final _new = TextEditingController();
  String _cat = 'Other';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Backend.on) return setState(() => _loading = false);
    try {
      final rows = await Backend.tripItems(widget.trip.id);
      _items
        ..clear()
        ..addAll(rows.map((r) => _Item(r['id'] as String, r['title'] as String, r['category'] as String? ?? 'Other', r['done'] as bool? ?? false)));
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addMany(List<(String, String)> items) async {
    final have = _items.map((i) => i.title.toLowerCase()).toSet();
    final fresh = items.where((i) => !have.contains(i.$1.toLowerCase())).toList();
    if (fresh.isEmpty) return;
    if (Backend.on) {
      try {
        await Backend.addTripItems(widget.trip.id, fresh);
        await _load();
      } catch (e) {
        if (mounted) toast(context, errText(e));
      }
    } else {
      setState(() => _items.addAll(fresh.map((f) => _Item('${f.$1}${DateTime.now().microsecondsSinceEpoch}', f.$1, f.$2, false))));
    }
  }

  Future<void> _toggle(_Item i) async {
    setState(() => i.done = !i.done);
    if (Backend.on) {
      try {
        await Backend.setTripItemDone(i.id, i.done);
      } catch (_) {
        setState(() => i.done = !i.done);
      }
    }
  }

  Future<void> _remove(_Item i) async {
    setState(() => _items.remove(i));
    if (Backend.on) {
      try {
        await Backend.deleteTripItem(i.id);
      } catch (_) {
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final cats = <String>['Documents', 'Electronics', 'Health', 'Clothes', 'Other'];
    final packed = _items.where((i) => i.done).length;
    return ScreenScaffold(
      title: 'Packing list',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$packed of ${_items.length} packed', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: _items.isEmpty ? 0 : packed / _items.length, minHeight: 8, color: C.primary, backgroundColor: C.line),
                    ),
                    const SizedBox(height: 6),
                    const Text('Shared with everyone on this trip.', style: TextStyle(fontSize: 12, color: C.muted)),
                  ]),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _new,
                      decoration: const InputDecoration(hintText: 'Add an item'),
                      onSubmitted: (_) => _addOne(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _cat,
                    underline: const SizedBox(),
                    items: [for (final c in cats) DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))],
                    onChanged: (v) => setState(() => _cat = v ?? 'Other'),
                  ),
                  IconButton(onPressed: _addOne, icon: const Icon(Icons.add_circle_rounded, color: C.primary)),
                ]),
                if (_items.length < 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _addMany(_essentials),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Add travel essentials'),
                    ),
                  ),
                for (final c in cats)
                  if (_items.any((i) => i.category == c)) ...[
                    Padding(padding: const EdgeInsets.only(top: 16, bottom: 4), child: Text(c, style: const TextStyle(fontWeight: FontWeight.w700, color: C.muted))),
                    for (final i in _items.where((i) => i.category == c))
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: i.done,
                        onChanged: (_) => _toggle(i),
                        title: Text(i.title, style: TextStyle(decoration: i.done ? TextDecoration.lineThrough : null, color: i.done ? C.muted : C.ink)),
                        secondary: IconButton(tooltip: 'Remove', onPressed: () => _remove(i), icon: const Icon(Icons.close_rounded, size: 18, color: C.muted)),
                      ),
                  ],
              ]),
            ),
    );
  }

  void _addOne() {
    final t = _new.text.trim();
    if (t.isEmpty) return;
    _new.clear();
    _addMany([(t, _cat)]);
  }
}
