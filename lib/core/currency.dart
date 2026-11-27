/// Money display. All amounts are stored in US dollars; the app shows them in
/// [appCurrency]. Set it to 'USD' when the app goes international.
const appCurrency = 'BDT';

/// Taka per US dollar used for display and for converting what people type.
const bdtPerUsd = 120;

bool get _bdt => appCurrency == 'BDT';

/// Currency code for input labels, e.g. "Amount (BDT)".
String get currencyCode => appCurrency;

String _group(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// An exact amount (prices, expenses), e.g. "৳5,400" or "$45.50".
String money(num usd) {
  if (_bdt) {
    final t = (usd * bdtPerUsd).round();
    return '${t < 0 ? '-' : ''}৳${_group(t.abs())}';
  }
  return '\$${usd == usd.roundToDouble() ? usd.toInt() : usd.toStringAsFixed(2)}';
}

/// A rough estimate (daily budgets), rounded to a friendly number, e.g. "৳2,400".
String moneyApprox(num usd) {
  if (!_bdt) return '\$${usd.round()}';
  var t = (usd * bdtPerUsd).round();
  t = t >= 1000 ? (t / 100).round() * 100 : (t / 10).round() * 10;
  return '৳${_group(t)}';
}

/// Converts an amount typed in [appCurrency] to stored US dollars.
double toUsd(double local) => _bdt ? local / bdtPerUsd : local;

/// Converts stored US dollars to [appCurrency] for an input field.
double fromUsd(num usd) => _bdt ? usd * bdtPerUsd.toDouble() : usd.toDouble();
