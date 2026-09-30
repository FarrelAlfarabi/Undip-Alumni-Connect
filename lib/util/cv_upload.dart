/// CV upload rules. Kept equal to the `cvs` bucket settings in
/// supabase/migrations/20260930100000_security_hardening.sql.
const int kMaxCvBytes = 5 * 1024 * 1024;

const String kCvTooBigMessage =
    'That file is too large. A CV must be 5 MB or smaller.';

const Map<String, String> _types = {
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
};

/// The MIME type for a CV file name, or null if it is not pdf, doc or docx.
String? cvContentType(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return null;
  return _types[fileName.substring(dot + 1).toLowerCase()];
}
