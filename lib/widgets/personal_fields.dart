import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../state/app_state.dart';
import 'common.dart';

const genders = [('male', 'Male'), ('female', 'Female'), ('other', 'Other'), ('unsaid', 'Prefer not to say')];

String? validPhone(String? v) {
  final d = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
  if (d.isEmpty) return tr('Enter your phone number');
  if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(d)) return tr('Enter a valid phone number');
  return null;
}

/// A Bangladeshi number typed as 01XXXXXXXXX becomes +8801XXXXXXXXX; anything else is kept as typed.
String normalPhone(String v) {
  final d = v.replaceAll(RegExp(r'[\s-]'), '');
  if (RegExp(r'^01[3-9][0-9]{8}$').hasMatch(d)) return '+88$d';
  return d;
}

String fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Gender, phone and date of birth fields, shared by sign-up and Personal information.
class PersonalFields extends StatelessWidget {
  final String? gender;
  final ValueChanged<String?> onGender;
  final TextEditingController phone;
  final DateTime? birth;
  final ValueChanged<DateTime> onBirth;
  final bool showErrors;
  const PersonalFields({super.key, required this.gender, required this.onGender, required this.phone, required this.birth, required this.onBirth, this.showErrors = false});

  static DateTime get latestBirth {
    final n = DateTime.now();
    return DateTime(n.year - 13, n.month, n.day);
  }

  @override
  Widget build(BuildContext context) {
    final err = TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('Gender'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final g in genders) ChoiceChip(label: Text(tr(g.$2)), selected: gender == g.$1, onSelected: (_) => onGender(g.$1)),
      ]),
      if (showErrors && gender == null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr('Choose one'), style: err)),
      const SizedBox(height: 14),
      Text(tr('Phone number'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextFormField(
        controller: phone,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))],
        validator: validPhone,
        decoration: const InputDecoration(hintText: '01XXXXXXXXX', prefixIcon: Icon(Icons.phone_outlined)),
      ),
      const SizedBox(height: 14),
      Text(tr('Date of birth'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: birth ?? DateTime(latestBirth.year - 12, 1, 1),
            firstDate: DateTime(1920),
            lastDate: latestBirth,
            initialEntryMode: DatePickerEntryMode.calendarOnly,
            helpText: tr('Date of birth'),
          );
          if (d != null) onBirth(d);
        },
        child: InputDecorator(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.cake_outlined)),
          child: Text(birth == null ? tr('Pick a date') : fmtDate(birth!), style: TextStyle(color: birth == null ? C.muted : C.ink)),
        ),
      ),
      if (showErrors && birth == null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr('Pick your date of birth'), style: err)),
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 14),
        child: Text(tr('Only you can see your gender, phone number and date of birth. You must be 13 or older.'), style: TextStyle(color: C.muted, fontSize: 11.5)),
      ),
    ]);
  }
}

/// Settings > Personal information: name (public) and the private details.
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});
  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: context.read<AppState>().name);
  final _phone = TextEditingController();
  String? _gender;
  DateTime? _birth;
  bool _loading = Backend.on, _busy = false, _tried = false;

  @override
  void initState() {
    super.initState();
    if (Backend.on) {
      Backend.privateDetails().then((r) {
        if (!mounted) return;
        setState(() {
          _gender = r?['gender'] as String?;
          _phone.text = (r?['phone'] as String?) ?? '';
          _birth = DateTime.tryParse('${r?['birth_date']}');
          _loading = false;
        });
      }).catchError((_) {
        if (mounted) setState(() => _loading = false);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _tried = true);
    if (!_form.currentState!.validate() || _gender == null || _birth == null) return;
    final s = context.read<AppState>();
    setState(() => _busy = true);
    try {
      if (_name.text.trim() != s.name) s.updateName(_name.text.trim());
      if (Backend.on) await Backend.savePrivateDetails(gender: _gender, phone: normalPhone(_phone.text), birthDate: _birth);
      if (mounted) {
        toast(context, tr('Saved'));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ScreenScaffold(
        title: tr('Personal information'),
        maxWidth: 480,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _form,
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  LabeledField('Full name', 'Your name', controller: _name, validator: (v) => (v ?? '').trim().length < 2 ? tr('Enter your name') : null),
                  PersonalFields(
                    gender: _gender,
                    onGender: (g) => setState(() => _gender = g),
                    phone: _phone,
                    birth: _birth,
                    onBirth: (d) => setState(() => _birth = d),
                    showErrors: _tried,
                  ),
                  PrimaryButton(_busy ? 'Please wait...' : 'Save', onPressed: _busy ? null : _save),
                ]),
              ),
      );
}
