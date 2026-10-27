// widgets/money_text.dart — Amount text that scales down instead of overflowing.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _moneyFmt = NumberFormat('#,##0', 'en_KE');
final _moneyFmt2 = NumberFormat('#,##0.00', 'en_KE');

/// Workspace currency with a trailing space, e.g. `Ksh ` or `KES `.
String currencyPrefix(String currency) {
  final trimmed = currency.trim().isEmpty ? 'Ksh' : currency.trim();
  return trimmed.endsWith(' ') ? trimmed : '$trimmed ';
}

/// Grouped amount for card labels, e.g. `1,245,000`. Money strings have no soft
/// break points, so ungrouped digits read as noise on narrow screens.
String formatMoney(num value, {int decimalDigits = 0}) =>
    (decimalDigits > 0 ? _moneyFmt2 : _moneyFmt).format(value);

/// [formatMoney] with the workspace's configured currency prefix.
String formatAmount(num value, String currency, {int decimalDigits = 0}) =>
    '${currencyPrefix(currency)}${formatMoney(value, decimalDigits: decimalDigits)}'.trimRight();

/// Compact KPI label: `Ksh 1.2M`, `Ksh 45K`, or a full grouped amount.
String formatCompactAmount(num value, String currency) {
  final prefix = currencyPrefix(currency);
  final v = value.abs();
  final sign = value < 0 ? '-' : '';
  if (v >= 1000000) return '$sign$prefix${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '$sign$prefix${(v / 1000).toStringAsFixed(0)}K';
  return formatAmount(value, currency);
}

/// NumberFormat using the workspace currency and grouping commas.
NumberFormat currencyFormat(String currency, {int decimalDigits = 0}) =>
    NumberFormat.currency(
      symbol: currencyPrefix(currency),
      decimalDigits: decimalDigits,
      locale: 'en_KE',
    );

/// Strips currency letters, spaces, and grouping commas so `Ksh 1,250,000`
/// and `1250000` both parse.
double? parseMoney(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') return null;
  return double.tryParse(cleaned);
}

double parseMoneyOr(String raw, [double fallback = 0.0]) =>
    parseMoney(raw) ?? fallback;

/// Live grouping commas while the user types a money amount.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  ThousandsSeparatorInputFormatter({this.decimalDigits = 0});

  final int decimalDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final raw = newValue.text.replaceAll(',', '');
    if (raw == '-' || raw == '.' || raw == '-.') return newValue;
    final parsed = double.tryParse(raw);
    if (parsed == null) return oldValue;

    String formatted;
    if (decimalDigits > 0 && raw.contains('.')) {
      final parts = raw.split('.');
      final intPart = formatMoney(int.tryParse(parts[0].replaceAll('-', '')) ?? 0);
      final signed = parts[0].startsWith('-') ? '-' : '';
      final frac = parts.length > 1 ? parts[1] : '';
      final clipped = frac.length > decimalDigits ? frac.substring(0, decimalDigits) : frac;
      formatted = clipped.isEmpty ? '$signed$intPart.' : '$signed$intPart.$clipped';
    } else {
      formatted = formatMoney(parsed.round());
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

List<TextInputFormatter> moneyInputFormatters({int decimalDigits = 0}) => [
      FilteringTextInputFormatter.allow(
        decimalDigits > 0 ? RegExp(r'[0-9.,\-]') : RegExp(r'[0-9,\-]'),
      ),
      ThousandsSeparatorInputFormatter(decimalDigits: decimalDigits),
    ];

/// Single-line money label safe for narrow (360dp) screens and large text
/// scales: money strings have no soft break points, so this shrinks the glyph
/// to fit [maxWidth] rather than throwing a RenderFlex overflow.
class MoneyText extends StatelessWidget {
  final String value;
  final TextStyle? style;
  final double maxWidth;
  final Alignment alignment;

  const MoneyText(
    this.value, {
    super.key,
    this.style,
    this.maxWidth = 150,
    this.alignment = Alignment.centerRight,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(value, maxLines: 1, style: style),
      ),
    );
  }
}
