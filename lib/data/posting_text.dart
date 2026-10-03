import '../models/business.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "5 Nov 2026".
String formatDay(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Whole days from [today] to [until] (both taken as plain dates).
int daysLeft(DateTime until, DateTime today) {
  final a = DateTime(until.year, until.month, until.day);
  final b = DateTime(today.year, today.month, today.day);
  return a.difference(b).inDays;
}

/// One plain line about product posting for the owner. No prices and no
/// payment instructions.
String postingSummary(
  Business business,
  BusinessUsage? usage, {
  DateTime? today,
}) {
  if (usage == null) return '';
  if (usage.unlimitedActive && business.unlimitedUntil != null) {
    final left = daysLeft(business.unlimitedUntil!, today ?? DateTime.now());
    final days = left <= 0
        ? 'last day'
        : (left == 1 ? '1 day left' : '$left days left');
    return 'Products: ${usage.used}, unlimited posting until '
        '${formatDay(business.unlimitedUntil!)} ($days)';
  }
  if (usage.overLimit) {
    return 'Products: ${usage.used} of ${usage.freeLimit} free. You are over '
        'the free limit. Your products stay visible, but new ones are '
        'blocked.';
  }
  return 'Products: ${usage.used} of ${usage.freeLimit} free';
}
