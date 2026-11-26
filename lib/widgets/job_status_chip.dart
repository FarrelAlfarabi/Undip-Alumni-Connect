import 'package:flutter/material.dart';

/// Small "Dibuka" / "Ditutup" mark for a job. A job is closed when its poster
/// closed it (`closed_at` is set). There is no expiry date.
bool jobIsClosed(Map<String, dynamic> job) => job['closed_at'] != null;

class JobStatusChip extends StatelessWidget {
  const JobStatusChip({super.key, required this.job});

  final Map<String, dynamic> job;

  @override
  Widget build(BuildContext context) {
    final closed = jobIsClosed(job);
    final scheme = Theme.of(context).colorScheme;
    final color = closed ? scheme.onSurfaceVariant : Colors.green.shade800;
    return Container(
      key: Key(closed ? 'job-status-closed' : 'job-status-open'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        closed ? 'Ditutup' : 'Dibuka',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
