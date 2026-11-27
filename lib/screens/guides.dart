import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../core/i18n.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../data/backend.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
import 'booking_flow.dart';
import 'messages.dart';

/// The approved guide profile for a traveler, if they signed up as a guide.
Guide? guideFor(String userId) {
  for (final g in guides) {
    if (g.userId == userId) return g;
  }
  return null;
}

/// "Guide" / "Verified guide" pill shown on profiles.
class GuideBadge extends StatelessWidget {
  final Guide g;
  final bool compact;
  const GuideBadge(this.g, {super.key, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final col = g.verified ? const Color(0xFF2EB67D) : C.primary;
    if (compact) return Tooltip(message: g.verified ? tr('Verified guide') : tr('Guide'), child: Icon(g.verified ? Icons.workspace_premium_rounded : Icons.badge_rounded, size: 15, color: col));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: col.withValues(alpha: .15), borderRadius: BorderRadius.circular(20), border: Border.all(color: col.withValues(alpha: .6))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(g.verified ? Icons.workspace_premium_rounded : Icons.badge_rounded, size: 15, color: col),
        const SizedBox(width: 5),
        Text(g.verified ? tr('Verified guide') : tr('Guide'), style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

class GuidesScreen extends StatefulWidget {
  final String? country;
  const GuidesScreen({super.key, this.country});
  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen> {
  Guide? _mine;
  bool _admin = false;
  int _pending = 0;
  bool _verifiedOnly = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!Backend.on || Backend.uid == null) return;
    try {
      final g = await Backend.guides();
      guides
        ..clear()
        ..addAll(g);
      _mine = await Backend.myGuide();
      _admin = await Backend.isAdmin();
      if (_admin) _pending = (await Backend.guideApplications()).length;
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _message(Guide g) async {
    if (g.userId == null) return toast(context, tr('This guide has no chat yet'));
    final t = await Backend.fetchTraveler(g.userId!);
    if (!mounted || t == null) return;
    go(context, ChatScreen(conversation: context.read<SocialState>().chatWith(t)));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.country;
    var list = guides.where((g) => !_verifiedOnly || g.verified).toList()..sort((a, b) => (b.verified ? 1 : 0).compareTo(a.verified ? 1 : 0));
    final local = c == null ? list : list.where((g) => g.base == c).toList();
    final shown = local.isEmpty ? list : local;
    return ScreenScaffold(
      title: tr('Travel guides'),
      body: RefreshIndicator(
        color: C.primary,
        onRefresh: _refresh,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
          if (_admin)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await go(context, const GuideReviewScreen());
                  _refresh();
                },
                icon: const Icon(Icons.admin_panel_settings_rounded),
                label: Text('Review verification requests ($_pending)'),
              ),
            ),
          _BecomeGuideCard(mine: _mine, onChanged: _refresh),
          const SizedBox(height: 14),
          Row(children: [
            Text('${shown.length} guide${shown.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const Spacer(),
            FilterChip(label: Text(tr('Verified only')), selected: _verifiedOnly, onSelected: (v) => setState(() => _verifiedOnly = v)),
          ]),
          const SizedBox(height: 8),
          if (c != null && local.isEmpty && list.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('No guides listed in $c yet. Showing guides in other countries.', style: const TextStyle(color: C.muted, fontSize: 12.5)),
            ),
          if (shown.isEmpty)
            const EmptyState(Icons.badge_rounded, 'No guides yet', 'Local guides who sign up appear here. Know your area well? Become the first guide.')
          else
            for (final g in shown) _GuideCard(g, onMessage: () => _message(g)),
        ]),
      ),
    );
  }
}

class _BecomeGuideCard extends StatelessWidget {
  final Guide? mine;
  final VoidCallback onChanged;
  const _BecomeGuideCard({required this.mine, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final g = mine;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [C.primary.withValues(alpha: .22), C.primary.withValues(alpha: .06)]),
        border: Border.all(color: C.primary.withValues(alpha: .45)),
      ),
      child: Row(children: [
        Icon(g == null ? Icons.hiking_rounded : Icons.badge_rounded, color: C.primary, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g == null ? tr('Become a guide') : (g.verified ? tr('You are a verified guide') : tr('You are listed as a guide')), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text(
              g == null
                  ? 'Sign up with a few details. Add documents later to get verified.'
                  : (g.verified ? 'Travelers see the Verified guide badge.' : 'Submit your documents to get the Verified badge.'),
              style: const TextStyle(color: C.muted, fontSize: 12),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Column(children: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.primary, visualDensity: VisualDensity.compact),
            onPressed: () async {
              if (!Backend.on || Backend.uid == null) return toast(context, tr('Sign in to become a guide'));
              await go(context, GuideSignupScreen(existing: g));
              onChanged();
            },
            child: Text(g == null ? tr('Sign up') : tr('Edit')),
          ),
          if (g != null && !g.verified)
            TextButton(
              onPressed: () async {
                await go(context, const GuideVerifyScreen());
                onChanged();
              },
              child: Text(tr('Get verified')),
            ),
        ]),
      ]),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final Guide g;
  final VoidCallback onMessage;
  const _GuideCard(this.g, {required this.onMessage});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(g.avatarUrl ?? g.seed, name: g.name, radius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${g.base}${g.years > 0 ? '  ·  ${g.years} years' : ''}', style: const TextStyle(fontSize: 12, color: C.muted)),
                const SizedBox(height: 4),
                Row(children: [
                  GuideBadge(g),
                  if (g.rating > 0) ...[const SizedBox(width: 8), RatingText(g.rating)],
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(money(g.pricePerDay), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: C.primary)),
              Text(tr('per day'), style: TextStyle(fontSize: 10.5, color: C.muted)),
            ]),
          ]),
          if (g.areas != null && g.areas!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(trf('Guides in {0}', [g.areas]), style: const TextStyle(fontSize: 12.5)),
          ],
          if (g.bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(g.bio, style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.5)),
          ],
          const SizedBox(height: 10),
          Text(trf('Speaks {0}', [g.languages.join(', ')]), style: const TextStyle(fontSize: 11.5)),
          const SizedBox(height: 10),
          Row(children: [
            if (g.userId != null && g.userId != Backend.uid)
              Expanded(child: OutlinedButton.icon(onPressed: onMessage, icon: const Icon(Icons.chat_bubble_rounded, size: 16), label: Text(tr('Message')))),
            if (g.phone != null && g.phone!.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton.outlined(onPressed: () => launchUrl(Uri.parse('tel:${g.phone}')), icon: const Icon(Icons.call_rounded, size: 18)),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.primary),
                onPressed: g.userId == Backend.uid && g.userId != null
                    ? null
                    : () => go(context, BookingFlowScreen(draft: BookingDraft(title: 'Guide: ${g.name}', location: g.base, type: 'guide', seed: g.seed, unitPrice: g.pricePerDay))),
                child: Text(tr('Hire')),
              ),
            ),
          ]),
        ]),
      );
}

// ---------------------------------------------------------------- basic signup

class GuideSignupScreen extends StatefulWidget {
  final Guide? existing;
  const GuideSignupScreen({super.key, this.existing});
  @override
  State<GuideSignupScreen> createState() => _GuideSignupScreenState();
}

class _GuideSignupScreenState extends State<GuideSignupScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? context.read<AppState>().name);
  late final _country = TextEditingController(text: widget.existing?.base ?? '');
  late final _areas = TextEditingController(text: widget.existing?.areas ?? '');
  late final _langs = TextEditingController(text: widget.existing?.languages.join(', ') ?? '');
  late final _years = TextEditingController(text: widget.existing == null ? '' : '${widget.existing!.years}');
  late final _price = TextEditingController(text: widget.existing == null ? '' : fromUsd(widget.existing!.pricePerDay).toStringAsFixed(0));
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _bio = TextEditingController(text: widget.existing?.bio ?? '');
  bool _busy = false;

  Future<void> _save() async {
    final langs = _langs.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (_name.text.trim().isEmpty || _country.text.trim().isEmpty || _areas.text.trim().isEmpty || langs.isEmpty || _phone.text.trim().isEmpty) {
      return toast(context, tr('Please fill in all fields marked *'));
    }
    setState(() => _busy = true);
    try {
      await Backend.saveGuide({
        'name': _name.text.trim(),
        'base': _country.text.trim(),
        'areas': _areas.text.trim(),
        'languages': langs,
        'years': int.tryParse(_years.text.trim()) ?? 0,
        'price_per_day': toUsd(double.tryParse(_price.text.trim().replaceAll(',', '')) ?? 0),
        'phone': _phone.text.trim(),
        'bio': _bio.text.trim(),
      });
      if (!mounted) return;
      context.read<AppState>().pullRefresh();
      toast(context, widget.existing == null ? tr('You are now listed as a guide') : tr('Guide profile updated'));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Stop being a guide?')),
        content: Text(tr('Your guide profile and badge will be removed and you will be a traveler again. Any pending verification request is withdrawn. You can sign up again later.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(c, true), child: Text(tr('Remove'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await Backend.leaveGuide();
      if (!mounted) return;
      await context.read<AppState>().pullRefresh();
      if (!mounted) return;
      toast(context, tr('You are a traveler again'));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _f(TextEditingController c, String label, {String? hint, TextInputType? kb, int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, keyboardType: kb, maxLines: lines, decoration: InputDecoration(labelText: label, hintText: hint)),
      );

  @override
  Widget build(BuildContext context) => ScreenScaffold(
        title: widget.existing == null ? tr('Become a guide') : tr('Edit guide profile'),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(tr('Step 1 of 2: basic details'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(tr('You will be listed as a Guide right away. Submit your ID and proof of experience later to get the Verified guide badge.'), style: TextStyle(color: C.muted, fontSize: 12.5)),
          const SizedBox(height: 16),
          _f(_name, 'Full name *'),
          _f(_country, 'Country you guide in *', hint: 'e.g. Bangladesh'),
          _f(_areas, 'Areas you cover *', hint: "e.g. Cox's Bazar, Bandarban, Sajek"),
          _f(_langs, 'Languages *', hint: 'e.g. Bangla, English, Hindi'),
          Row(children: [
            Expanded(child: _f(_years, 'Years of experience', kb: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _f(_price, 'Price per day ($currencyCode)', kb: TextInputType.number)),
          ]),
          _f(_phone, 'Phone / WhatsApp *', kb: TextInputType.phone),
          _f(_bio, 'About you and your tours', hint: 'What do you show travelers? Any special skills?', lines: 4),
          const SizedBox(height: 6),
          PrimaryButton(_busy ? 'Saving...' : (widget.existing == null ? 'Sign up as a guide' : 'Save changes'), icon: Icons.check_rounded, onPressed: _busy ? null : _save),
          if (widget.existing != null) ...[
            const SizedBox(height: 22),
            const Divider(),
            const SizedBox(height: 8),
            if (widget.existing!.verified)
              Text(tr('Verified guides cannot remove the guide role. Contact support if you need to stop guiding.'), style: TextStyle(color: C.muted, fontSize: 12.5))
            else
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: _busy ? null : _leave,
                icon: const Icon(Icons.logout_rounded),
                label: Text(tr('Stop being a guide')),
              ),
          ],
        ]),
      );
}

// ---------------------------------------------------------------- verification (documents)

class GuideVerifyScreen extends StatefulWidget {
  const GuideVerifyScreen({super.key});
  @override
  State<GuideVerifyScreen> createState() => _GuideVerifyScreenState();
}

class _Doc {
  final Uint8List bytes;
  final String name;
  _Doc(this.bytes, this.name);
}

class _GuideVerifyScreenState extends State<GuideVerifyScreen> {
  GuideApplication? _last;
  Guide? _guide;
  bool _loading = true, _busy = false, _agree = false;
  String _idType = 'nid';
  DateTime? _dob;
  final _fullName = TextEditingController(), _idNo = TextEditingController(), _address = TextEditingController(), _experience = TextEditingController();
  _Doc? _front, _back, _photo, _noc;
  final List<_Doc> _proofs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _last = await Backend.myGuideApplication();
      _guide = await Backend.myGuide();
      _fullName.text = _guide?.name ?? '';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<_Doc?> _pickImg() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
    if (f == null) return null;
    final b = await f.readAsBytes();
    if (b.length > 10 * 1024 * 1024) {
      if (mounted) toast(context, tr('Each file must be under 10 MB'));
      return null;
    }
    return _Doc(b, f.name);
  }

  Widget _slot(String label, _Doc? d, ValueChanged<_Doc> on, {bool required = true, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final x = await _pickImg();
            if (x != null) setState(() => on(x));
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: d == null ? C.line : const Color(0xFF2EB67D))),
            child: Row(children: [
              d == null
                  ? const Icon(Icons.upload_file_rounded, color: C.muted)
                  : ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.memory(d.bytes, width: 40, height: 40, fit: BoxFit.cover)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$label${required ? ' *' : ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  Text(d?.name ?? hint ?? tr('Tap to add a clear photo or scan'), style: const TextStyle(color: C.muted, fontSize: 11.5), overflow: TextOverflow.ellipsis),
                ]),
              ),
              Icon(d == null ? Icons.add_rounded : Icons.check_circle_rounded, color: d == null ? C.muted : const Color(0xFF2EB67D)),
            ]),
          ),
        ),
      );

  Future<String> _up(_Doc d) => Backend.uploadPrivateDoc(d.bytes, 'jpg', 'image/jpeg');

  Future<void> _submit() async {
    if (_fullName.text.trim().isEmpty || _idNo.text.trim().isEmpty || _address.text.trim().isEmpty || _experience.text.trim().length < 30 || _dob == null) {
      return toast(context, tr('Fill in every field marked *. Describe your experience in at least 30 characters.'));
    }
    if (_front == null || _photo == null || (_idType == 'nid' && _back == null)) return toast(context, tr('Add your ID photos and a clear photo of yourself'));
    if (_proofs.isEmpty) return toast(context, tr('Add at least one proof of experience'));
    if (!_agree) return toast(context, tr('Please accept the guide agreement'));
    setState(() => _busy = true);
    try {
      final g = _guide!;
      final front = await _up(_front!);
      final back = _back == null ? null : await _up(_back!);
      final photo = await _up(_photo!);
      final noc = _noc == null ? null : await _up(_noc!);
      final proofs = [for (final p in _proofs) await _up(p)];
      await Backend.applyGuide({
        'full_name': _fullName.text.trim(),
        'phone': g.phone ?? '',
        'date_of_birth': _dob!.toIso8601String().substring(0, 10),
        'address': _address.text.trim(),
        'id_type': _idType,
        'id_number': _idNo.text.trim(),
        'base_country': g.base,
        'areas': g.areas ?? '',
        'languages': g.languages,
        'years': g.years,
        'price_per_day': g.pricePerDay,
        'experience': _experience.text.trim(),
        'bio': g.bio,
        'id_front_path': front,
        'id_back_path': back,
        'photo_path': photo,
        'proof_paths': proofs,
        'noc_path': noc,
        'agreed_terms': true,
      });
      if (!mounted) return;
      toast(context, tr('Submitted. We will review your documents soon.'));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return ScreenScaffold(title: tr('Get verified'), body: Center(child: CircularProgressIndicator(color: C.primary)));
    if (_guide == null) {
      return ScreenScaffold(title: tr('Get verified'), body: EmptyState(Icons.badge_rounded, 'Sign up as a guide first', 'Complete step 1 (basic details), then come back to submit documents.'));
    }
    if (_guide!.verified) {
      return ScreenScaffold(title: tr('Get verified'), body: EmptyState(Icons.workspace_premium_rounded, 'You are verified', 'Travelers see the Verified guide badge on your profile.'));
    }
    if (_last?.status == 'pending') {
      return ScreenScaffold(
          title: tr('Get verified'), body: EmptyState(Icons.hourglass_top_rounded, 'Under review', 'Your documents were received. You will get a notification when the review is done.'));
    }
    return ScreenScaffold(
      title: tr('Get verified'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_last?.status == 'rejected')
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
            child: Text('Your last request was not approved. ${_last!.row['review_note'] ?? ''}', style: const TextStyle(fontSize: 12.5)),
          ),
        Text(tr('Step 2 of 2: verification'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 4),
        Text(tr('Your documents are stored privately. Only you and the ExploreHub review team can see them.'), style: TextStyle(color: C.muted, fontSize: 12.5)),
        const SizedBox(height: 16),
        Text(tr('Personal details'), style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(controller: _fullName, decoration: InputDecoration(labelText: tr('Full name as on ID *'))),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final r = await showDatePicker(context: context, initialDate: DateTime(1995), firstDate: DateTime(1940), lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)));
            if (r != null) setState(() => _dob = r);
          },
          child: InputDecorator(decoration: InputDecoration(labelText: tr('Date of birth *')), child: Text(_dob == null ? tr('Select') : fmtDate(_dob!))),
        ),
        const SizedBox(height: 10),
        TextField(controller: _address, maxLines: 2, decoration: InputDecoration(labelText: tr('Present address *'))),
        const SizedBox(height: 18),
        Text(tr('Identity document'), style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [ButtonSegment(value: 'nid', label: Text(tr('National ID'))), ButtonSegment(value: 'passport', label: Text(tr('Passport')))],
          selected: {_idType},
          onSelectionChanged: (s) => setState(() => _idType = s.first),
        ),
        const SizedBox(height: 10),
        TextField(controller: _idNo, decoration: InputDecoration(labelText: _idType == 'nid' ? 'NID number *' : 'Passport number *')),
        const SizedBox(height: 10),
        _slot(_idType == 'nid' ? 'NID front' : 'Passport photo page', _front, (d) => _front = d),
        if (_idType == 'nid') _slot('NID back', _back, (d) => _back = d),
        _slot('Your photo (selfie)', _photo, (d) => _photo = d, hint: 'A clear photo of your face, no sunglasses'),
        const SizedBox(height: 8),
        Text(tr('Experience'), style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _experience,
          maxLines: 5,
          decoration: InputDecoration(labelText: tr('Experience details *'), hintText: tr('Where have you guided, for how long, for which agencies, what tours you lead...')),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _proofs.length; i++) _slot('Proof ${i + 1}', _proofs[i], (d) => _proofs[i] = d),
        OutlinedButton.icon(
          onPressed: _proofs.length >= 6
              ? null
              : () async {
                  final x = await _pickImg();
                  if (x != null) setState(() => _proofs.add(x));
                },
          icon: const Icon(Icons.add_rounded),
          label: Text(_proofs.isEmpty ? tr('Add proof of experience * (license, certificate, agency letter)') : tr('Add another proof')),
        ),
        const SizedBox(height: 14),
        _slot('NOC (No Objection Certificate)', _noc, (d) => _noc = d, required: false, hint: 'From your employer or tourism authority, if you have one'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
          child: const Text(
            'Guide agreement\n'
            '1. The information and documents I submit are true and belong to me.\n'
            '2. I hold any license my country requires for guiding, and I will follow local laws.\n'
            '3. I will treat travelers safely and respectfully, and I will not ask for payment outside what we agreed.\n'
            '4. ExploreHub may remove my guide profile or verification if I break these rules or a report against me is confirmed.\n'
            '5. My documents are used only for verification and are not shown to other users.',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
        ),
        CheckboxListTile(
          value: _agree,
          onChanged: (v) => setState(() => _agree = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(tr('I have read and agree to the guide agreement *'), style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(height: 8),
        PrimaryButton(_busy ? 'Uploading...' : 'Submit for verification', icon: Icons.verified_rounded, onPressed: _busy ? null : _submit),
      ]),
    );
  }
}

// ---------------------------------------------------------------- admin review

class GuideReviewScreen extends StatefulWidget {
  const GuideReviewScreen({super.key});
  @override
  State<GuideReviewScreen> createState() => _GuideReviewScreenState();
}

class _GuideReviewScreenState extends State<GuideReviewScreen> {
  List<GuideApplication>? _apps;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await Backend.guideApplications();
      if (mounted) setState(() => _apps = a);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) => ScreenScaffold(
        title: tr('Guide verification'),
        body: _apps == null
            ? const Center(child: CircularProgressIndicator(color: C.primary))
            : _apps!.isEmpty
                ? const EmptyState(Icons.inbox_rounded, 'No pending requests', 'New guide verification requests show up here.')
                : ListView(padding: const EdgeInsets.all(16), children: [
                    for (final a in _apps!)
                      Card(
                        color: C.card,
                        child: ListTile(
                          title: Text(a.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${a.row['base_country']}  ·  ${a.row['id_type'] == 'nid' ? 'NID' : tr('Passport')}  ·  ${fmtDate(DateTime.parse(a.row['created_at'] as String).toLocal())}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            await go(context, _ReviewDetail(a));
                            _load();
                          },
                        ),
                      ),
                  ]),
      );
}

class _ReviewDetail extends StatefulWidget {
  final GuideApplication a;
  const _ReviewDetail(this.a);
  @override
  State<_ReviewDetail> createState() => _ReviewDetailState();
}

class _ReviewDetailState extends State<_ReviewDetail> {
  final Map<String, String> _urls = {};
  final _note = TextEditingController();
  bool _busy = false;

  List<(String, String)> get _docs {
    final r = widget.a.row;
    return [
      ('ID front', r['id_front_path'] as String),
      if (r['id_back_path'] != null) ('ID back', r['id_back_path'] as String),
      ('Photo', r['photo_path'] as String),
      for (final (i, p) in List<String>.from(r['proof_paths'] as List? ?? const []).indexed) ('Proof ${i + 1}', p),
      if (r['noc_path'] != null) ('NOC', r['noc_path'] as String),
    ];
  }

  @override
  void initState() {
    super.initState();
    for (final d in _docs) {
      Backend.signedDocUrl(d.$2).then((u) {
        if (mounted) setState(() => _urls[d.$2] = u);
      }).catchError((_) {});
    }
  }

  Future<void> _decide(bool ok) async {
    if (!ok && _note.text.trim().isEmpty) return toast(context, tr('Write a short reason so the guide knows what to fix'));
    setState(() => _busy = true);
    try {
      await Backend.reviewGuide(widget.a.id, ok, _note.text.trim().isEmpty ? null : _note.text.trim());
      if (!mounted) return;
      toast(context, ok ? tr('Approved. The guide is now verified.') : tr('Request declined'));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.a.row;
    Widget kv(String k, Object? v) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(tr(k), style: const TextStyle(color: C.muted, fontSize: 12.5))),
            Expanded(child: Text('${v ?? '-'}', style: const TextStyle(fontSize: 13))),
          ]),
        );
    return ScreenScaffold(
      title: widget.a.fullName,
      body: ListView(padding: const EdgeInsets.all(16), children: [
        kv('ID type', r['id_type'] == 'nid' ? 'National ID' : 'Passport'),
        kv('ID number', r['id_number']),
        kv('Date of birth', r['date_of_birth']),
        kv('Phone', r['phone']),
        kv('Address', r['address']),
        kv('Country', r['base_country']),
        kv('Areas', r['areas']),
        kv('Languages', (r['languages'] as List?)?.join(', ')),
        kv('Experience', '${r['years']} years'),
        const SizedBox(height: 6),
        Text(tr('Experience details'), style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${r['experience']}', style: const TextStyle(fontSize: 13, height: 1.5)),
        const SizedBox(height: 14),
        Text(tr('Documents'), style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final d in _docs)
            InkWell(
              onTap: _urls[d.$2] == null ? null : () => launchUrl(Uri.parse(_urls[d.$2]!), mode: LaunchMode.externalApplication),
              child: Column(children: [
                Container(
                  width: 140,
                  height: 100,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
                  clipBehavior: Clip.antiAlias,
                  child: _urls[d.$2] == null ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) : Image.network(_urls[d.$2]!, fit: BoxFit.cover),
                ),
                const SizedBox(height: 4),
                Text(tr(d.$1), style: const TextStyle(fontSize: 11.5)),
              ]),
            ),
        ]),
        const SizedBox(height: 16),
        TextField(controller: _note, maxLines: 2, decoration: InputDecoration(labelText: tr('Note to the guide (required to decline)'))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _decide(false), child: Text(tr('Decline')))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2EB67D)), onPressed: _busy ? null : () => _decide(true), child: Text(tr('Approve')))),
        ]),
      ]),
    );
  }
}
