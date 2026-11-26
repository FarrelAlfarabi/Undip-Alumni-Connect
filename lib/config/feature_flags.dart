/// Chat (direct messages and city group chat) is hidden for the closed beta.
/// "Request to contact" replaces it. Flip this to true to bring every chat
/// entry point back. The chat tables and their data are never touched.
const bool chatEnabled = false;

/// Web only. Flutter web draws on a canvas, so a screen reader sees nothing
/// until the page builds its accessibility tree. Keeping that tree on all the
/// time (true) is what the legal audit was run against, but it costs about 35
/// to 45% of the main-thread time while scrolling and loading (measured 26 Nov
/// 2026 with the CPU slowed 4x).
///
/// Off for now by Farrel's decision. It is NOT gone: Flutter still adds its
/// hidden "Enable accessibility" button, and a screen reader (or Tab to the button, then Enter)
/// switches the tree on for that visit. TEMPORARY, and a legal accessibility
/// risk to re-check before launch (automated audit tools that do not press
/// that button see an empty page).
///
/// Turn it back on without touching code: build with
/// `--dart-define=ALWAYS_ON_SEMANTICS=true` (Vercel: set the environment
/// variable ALWAYS_ON_SEMANTICS to `true`, see scripts/vercel-build.sh).
const bool kAlwaysOnSemantics = bool.fromEnvironment(
  'ALWAYS_ON_SEMANTICS',
  defaultValue: false,
);
