import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/util/cv_upload.dart';

/// SA-11: the app side of the CV upload limits. The database side is in
/// supabase/migrations/20260930100000_security_hardening.sql and is checked
/// by supabase/tests/security_audit/run_audit.sh post.
void main() {
  test('only pdf, doc and docx are accepted, case-insensitively', () {
    expect(cvContentType('cv.pdf'), 'application/pdf');
    expect(cvContentType('CV.PDF'), 'application/pdf');
    expect(cvContentType('cv.doc'), 'application/msword');
    expect(
      cvContentType('my.cv.docx'),
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    for (final bad in ['cv.html', 'cv.exe', 'cv', 'cv.pdf.html', '', 'pdf']) {
      expect(cvContentType(bad), isNull, reason: bad);
    }
  });

  test('size limit is 5 MB and matches the database bucket limit', () {
    expect(kMaxCvBytes, 5 * 1024 * 1024);
    final sql = File(
      'supabase/migrations/20260930100000_security_hardening.sql',
    ).readAsStringSync();
    expect(sql, contains('file_size_limit = $kMaxCvBytes'));
  });

  test('the mime types the app sends are the ones the bucket allows', () {
    final sql = File(
      'supabase/migrations/20260930100000_security_hardening.sql',
    ).readAsStringSync();
    for (final ext in ['pdf', 'doc', 'docx']) {
      expect(sql, contains("'${cvContentType('x.$ext')}'"));
    }
  });

  test('error text for an oversized CV is friendly', () {
    expect(kCvTooBigMessage, contains('5 MB'));
  });
}
