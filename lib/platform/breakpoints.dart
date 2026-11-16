/// Width steps shared by every screen. Phone under 600, tablet 600 to 1023,
/// desktop 1024 and up.
enum ScreenStep { phone, tablet, desktop }

const double tabletMinWidth = 600;
const double desktopMinWidth = 1024;

ScreenStep stepForWidth(double width) {
  if (width >= desktopMinWidth) return ScreenStep.desktop;
  if (width >= tabletMinWidth) return ScreenStep.tablet;
  return ScreenStep.phone;
}

double maxContentWidth(ScreenStep step) => switch (step) {
      ScreenStep.phone => double.infinity,
      ScreenStep.tablet => 720,
      ScreenStep.desktop => 960,
    };
