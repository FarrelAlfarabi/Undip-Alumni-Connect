import 'package:flutter/material.dart';

/// Status of a job application, stored in job_applications.status (see
/// 20261002090000_add_application_status.sql). The poster moves an
/// application through these from the applicant list; the applicant sees
/// the result on the job and under "My Applications".
class ApplicationStatus {
  ApplicationStatus._();

  static const pending = 'pending';
  static const reviewed = 'reviewed';
  static const accepted = 'accepted';
  static const rejected = 'rejected';

  /// In the order a poster would pick them.
  static const all = [pending, reviewed, accepted, rejected];

  static String label(String? status) => switch (status) {
    reviewed => 'Reviewed',
    accepted => 'Accepted',
    rejected => 'Not selected',
    _ => 'Pending',
  };

  static IconData icon(String? status) => switch (status) {
    reviewed => Icons.visibility_outlined,
    accepted => Icons.check_circle_outline,
    rejected => Icons.cancel_outlined,
    _ => Icons.schedule,
  };

  static Color color(BuildContext context, String? status) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      accepted => Colors.green.shade700,
      rejected => scheme.error,
      reviewed => scheme.primary,
      _ => scheme.onSurfaceVariant,
    };
  }
}

/// Small pill showing an application's status.
class ApplicationStatusChip extends StatelessWidget {
  const ApplicationStatusChip({super.key, required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final color = ApplicationStatus.color(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ApplicationStatus.icon(status), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            ApplicationStatus.label(status),
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
