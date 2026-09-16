import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Simulated email log (added 18 Sep 2026). Real email needs a
/// transactional provider (Resend etc.) with its own account/API key —
/// a real external decision, not something to wire silently. Until
/// that's set up, every email that WOULD be sent when someone applies
/// to a job is recorded in email_log (see notify_poster_on_application
/// in 20260918110000_add_email_log.sql) and shown here, so the "poster
/// gets emailed" behavior is demonstrable rather than invisible.
class EmailLogScreen extends StatefulWidget {
  const EmailLogScreen({super.key, required this.recipientEmail});

  final String recipientEmail;

  @override
  State<EmailLogScreen> createState() => _EmailLogScreenState();
}

class _EmailLogScreenState extends State<EmailLogScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchEmailLog();
  }

  Future<List<Map<String, dynamic>>> _fetchEmailLog() async {
    final rows = await Supabase.instance.client
        .from('email_log')
        .select()
        .eq('recipient_email', widget.recipientEmail)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Emails (Simulated)')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load emails: ${snapshot.error}'),
              ),
            );
          }

          final emails = snapshot.data ?? [];

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.surfaceContainerHigh,
                child: Text(
                  'This demo doesn\'t send real email yet — these are the '
                  'exact emails that would have been sent to '
                  '${widget.recipientEmail}.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: emails.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No emails yet.'),
                        ),
                      )
                    : ListView.separated(
                        itemCount: emails.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final e = emails[i];
                          return ListTile(
                            leading: const Icon(Icons.mail_outline),
                            title: Text(
                              e['subject'] as String? ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(e['body'] as String? ?? ''),
                            isThreeLine: true,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
