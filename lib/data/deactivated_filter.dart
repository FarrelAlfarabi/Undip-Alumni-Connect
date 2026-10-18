/// Leaves out profile rows of people who deactivated their account
/// (Directory, Nearby). The database already hides them once real login is
/// on; this keeps them hidden before that too.
List<Map<String, dynamic>> withoutDeactivatedProfiles(
  List<Map<String, dynamic>> rows,
) => rows.where((p) => p['deactivated_at'] == null).toList();
