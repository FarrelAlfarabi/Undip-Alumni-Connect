import 'package:supabase_flutter/supabase_flutter.dart';

import '../util/app_info.dart';
import '../util/error_report.dart';

/// Longest "What were you doing?" text (also enforced in the database).
const int kFeedbackMessageMax = 500;

/// Who is using the app right now, so a feedback report can name them.
/// Null before verification (errors can happen there too).
class FeedbackSession {
  FeedbackSession._();
  static String? profileId;
}

/// One feedback report. [errorText] is ALWAYS cleaned (see error_report.dart).
class FeedbackReport {
  const FeedbackReport({
    required this.errorText,
    required this.screen,
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    this.profileId,
    this.message,
  });

  final String? profileId;
  final String? message;
  final String errorText;
  final String screen;
  final String appVersion;
  final String buildNumber;
  final String platform;

  Map<String, dynamic> toRow() => {
    'profile_id': profileId,
    'message': (message == null || message!.trim().isEmpty)
        ? null
        : message!.trim(),
    'error_text': errorText.isEmpty ? null : errorText,
    'screen': screen.length > 60 ? screen.substring(0, 60) : screen,
    'app_version': appVersion,
    'build_number': buildNumber,
    'platform': platform,
  };

  /// What a person can paste into WhatsApp if sending fails.
  String get copyText => [
    'Lingkaran feedback',
    'Screen: $screen',
    'App: v$appVersion (build $buildNumber), $platform',
    if (errorText.isNotEmpty) 'Error: $errorText',
    if (message != null && message!.trim().isNotEmpty)
      'What I was doing: ${message!.trim()}',
  ].join('\n');
}

/// Thin seam over the Supabase client. The app can only INSERT feedback.
abstract class FeedbackApi {
  Future<void> insert(Map<String, dynamic> row);
}

class SupabaseFeedbackApi implements FeedbackApi {
  SupabaseFeedbackApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<void> insert(Map<String, dynamic> row) async {
    // No select / returning: the app has no right to read this table.
    await _client.from('feedback_reports').insert(row);
  }
}

class FeedbackRepository {
  FeedbackRepository([FeedbackApi? api]) : _api = api ?? SupabaseFeedbackApi();
  final FeedbackApi _api;

  /// Builds a report from a raw [error] (cleaned here), the screen name, and
  /// the optional message.
  static Future<FeedbackReport> build({
    required Object? error,
    required String screen,
    String? message,
    AppInfo? appInfo,
    String? profileId,
  }) async {
    final info = appInfo ?? await AppInfo.load();
    return FeedbackReport(
      profileId: profileId ?? FeedbackSession.profileId,
      message: message,
      errorText: cleanErrorText(error),
      screen: screen,
      appVersion: info.version,
      buildNumber: info.buildNumber,
      platform: AppInfo.platform,
    );
  }

  Future<void> send(FeedbackReport report) => _api.insert(report.toRow());
}
