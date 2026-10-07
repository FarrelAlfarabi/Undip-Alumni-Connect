import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/apply_job_screen.dart';

/// The Done step used to promise "You can check its status any time from this
/// job". There is no status: the job only shows a disabled "Applied" button.
void main() {
  final job = {'title': 'Staff Akuntansi', 'company': 'PT Contoh'};

  test('the confirmation names the job and the company', () {
    final text = applicationSubmittedMessage(job);
    expect(text, contains('Staff Akuntansi'));
    expect(text, contains('PT Contoh'));
  });

  test('it does not promise a status that does not exist', () {
    final text = applicationSubmittedMessage(job).toLowerCase();
    expect(text, isNot(contains('status')));
    expect(text, isNot(contains('reviewed')));
  });

  test('it says what really happens next', () {
    final text = applicationSubmittedMessage(job);
    expect(text, contains('email'));
    expect(text, contains('Applied'));
  });

  test('a job without a title or company does not print null', () {
    final text = applicationSubmittedMessage(<String, dynamic>{});
    expect(text, isNot(contains('null')));
  });
}
