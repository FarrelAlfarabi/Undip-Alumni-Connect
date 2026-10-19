/// The time-period choices for the admin Reports and Feedback filters.
const String kAllTime = 'All time';
const List<String> kPeriodOptions = [
  kAllTime,
  'Today',
  'Last 7 days',
  'Last 30 days',
  'Last 90 days',
];

/// Whether [when] falls inside [period] (one of [kPeriodOptions]). "Today"
/// means since local midnight; the others count back from [now]. A missing
/// date only matches [kAllTime].
bool inPeriod(DateTime? when, String period, {DateTime? now}) {
  if (period == kAllTime) return true;
  if (when == null) return false;
  final n = now ?? DateTime.now();
  final t = when.toLocal();
  final since = switch (period) {
    'Today' => DateTime(n.year, n.month, n.day),
    'Last 7 days' => n.subtract(const Duration(days: 7)),
    'Last 30 days' => n.subtract(const Duration(days: 30)),
    'Last 90 days' => n.subtract(const Duration(days: 90)),
    _ => null,
  };
  return since == null || !t.isBefore(since);
}
