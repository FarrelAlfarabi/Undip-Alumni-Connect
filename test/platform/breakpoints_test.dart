import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/platform/breakpoints.dart';

void main() {
  test('width steps change at 600 and 1024', () {
    expect(stepForWidth(389), ScreenStep.phone);
    expect(stepForWidth(599), ScreenStep.phone);
    expect(stepForWidth(600), ScreenStep.tablet);
    expect(stepForWidth(1023), ScreenStep.tablet);
    expect(stepForWidth(1024), ScreenStep.desktop);
    expect(stepForWidth(1920), ScreenStep.desktop);
  });

  test('content max width: phone unlimited, tablet 720, desktop 960', () {
    expect(maxContentWidth(ScreenStep.phone), double.infinity);
    expect(maxContentWidth(ScreenStep.tablet), 720);
    expect(maxContentWidth(ScreenStep.desktop), 960);
  });
}
