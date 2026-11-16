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

/// From this width the desktop column grows to [wideContentWidth].
const double wideMinWidth = 1440;
const double wideContentWidth = 1200;

/// Width of the app shell's content column for a window [width] wide.
double shellContentWidth(double width) => width >= wideMinWidth
    ? wideContentWidth
    : maxContentWidth(stepForWidth(width));
