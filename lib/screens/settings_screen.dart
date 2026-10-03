import 'package:flutter/material.dart';

import '../lock/biometrics.dart';
import '../lock/confirm_pin_screen.dart';
import '../lock/lock_config.dart';
import '../lock/lock_service.dart';
import '../lock/pin_setup_screen.dart';
import '../lock/session.dart';
import '../settings/app_settings.dart';
import 'subscribe_screen.dart';
import 'verification_screen.dart';

/// Settings for the signed-in person: account, subscription, appearance,
/// device lock and sign out. Opened from the Profile tab.
///
/// Everything here is local to this device except subscribing, which goes
/// through the same [SubscribeScreen] as every other gate. [currentUser] is
/// the session-wide notifier, so subscribing here unlocks the other screens
/// too.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.currentUser,
    this.settings,
    this.lock,
    this.signOutDestination = _verification,
  });

  final ValueNotifier<Map<String, dynamic>> currentUser;

  /// Default to the app-wide instances; tests pass their own.
  final AppSettings? settings;
  final LockService? lock;

  /// Where sign out leads. Injectable for tests.
  final Widget Function() signOutDestination;

  static Widget _verification() => const VerificationScreen();

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AppSettings _settings = widget.settings ?? AppSettings.shared;
  late final LockService _lock = widget.lock ?? LockService.shared;

  bool _hasPin = false;
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _lock.changes.addListener(_loadLock);
    _loadLock();
  }

  @override
  void dispose() {
    _lock.changes.removeListener(_loadLock);
    super.dispose();
  }

  Future<void> _loadLock() async {
    if (!_lock.enabled) return;
    try {
      final hasPin = await _lock.hasPin();
      final available = await _lock.biometricsAvailable();
      final enabled = hasPin && await _lock.biometricsEnabled();
      if (!mounted) return;
      setState(() {
        _hasPin = hasPin;
        _bioAvailable = available;
        _bioEnabled = enabled;
      });
    } catch (_) {
      // Unreadable secure storage: the lock section stays in its default
      // "no PIN" state.
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _subscribe() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => SubscribeScreen(profile: widget.currentUser.value),
      ),
    );
    if (updated != null) widget.currentUser.value = updated;
  }

  Future<void> _setOrChangePin() async {
    final navigator = Navigator.of(context);
    if (_hasPin) {
      // Changing an existing PIN needs the current one first.
      final ok = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => ConfirmPinScreen(
            lock: _lock,
            onLockedOut: (ctx) =>
                signOutTo(ctx, widget.signOutDestination(), lock: _lock),
          ),
        ),
      );
      if (ok != true || !mounted) return;
    }
    final changing = _hasPin;
    final done = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => PinSetupScreen(
          lock: _lock,
          title: changing ? 'Change PIN' : 'Set a PIN',
          skipLabel: 'Cancel',
          offerBiometrics: !_bioEnabled,
          onDone: (ctx) async => Navigator.of(ctx).pop(true),
        ),
      ),
    );
    if (done == true && mounted) {
      await _loadLock();
      if (mounted) _snack(changing ? 'PIN changed.' : 'PIN set.');
    }
  }

  Future<void> _toggleBiometrics(bool on) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (on) {
        final r = await _lock.authenticateBiometric(
          'Confirm to turn on unlock with fingerprint or face',
        );
        if (r != BiometricResult.success) {
          if (mounted) _snack("That didn't work. Your PIN still works.");
          return;
        }
      }
      await _lock.setBiometricsEnabled(on);
      await _loadLock();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'This forgets you and your PIN on this device. You will need to '
          'verify your email again. Nothing is deleted from your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-sign-out'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await signOutTo(context, widget.signOutDestination(), lock: _lock);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _SectionCard(
                  title: 'Account',
                  child: ValueListenableBuilder<Map<String, dynamic>>(
                    valueListenable: widget.currentUser,
                    builder: (context, user, _) => _AccountSection(user: user),
                  ),
                ),
                _SectionCard(
                  title: 'Subscription',
                  child: ValueListenableBuilder<Map<String, dynamic>>(
                    valueListenable: widget.currentUser,
                    builder: (context, user, _) => _SubscriptionSection(
                      subscribed: user['subscription_status'] == 'subscribed',
                      onSubscribe: _subscribe,
                    ),
                  ),
                ),
                _SectionCard(
                  title: 'Appearance',
                  child: ListenableBuilder(
                    listenable: _settings,
                    builder: (context, _) => _AppearanceSection(
                      mode: _settings.themeMode,
                      onChanged: _settings.setThemeMode,
                    ),
                  ),
                ),
                if (_lock.enabled)
                  _SectionCard(
                    title: 'Security',
                    child: _SecuritySection(
                      hasPin: _hasPin,
                      bioAvailable: _bioAvailable,
                      bioEnabled: _bioEnabled,
                      busy: _busy,
                      onPin: _setOrChangePin,
                      onBiometrics: _toggleBiometrics,
                    ),
                  ),
                _SectionCard(title: 'About', child: const _AboutSection()),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('sign-out'),
                  onPressed: _confirmSignOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (user['name'] as String?)?.trim() ?? '';
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();
    final verified = user['verification_status'] == 'verified';
    final details = [
      user['nim'],
      user['faculty'],
    ].whereType<String>().where((v) => v.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Alumni' : name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((user['email'] as String?)?.isNotEmpty ?? false)
                  Text(
                    user['email'] as String,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 8),
                _StatusChip(
                  key: const Key('verification-chip'),
                  icon: verified ? Icons.verified : Icons.error_outline,
                  label: verified ? 'Verified alumni' : 'Not verified',
                  highlighted: verified,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.highlighted,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = highlighted
        ? scheme.secondaryContainer
        : scheme.surfaceContainerHigh;
    final fg = highlighted
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    return Chip(
      avatar: Icon(icon, size: 16, color: fg),
      label: Text(label),
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SubscriptionSection extends StatelessWidget {
  const _SubscriptionSection({
    required this.subscribed,
    required this.onSubscribe,
  });

  final bool subscribed;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    Widget perk(IconData icon, String text, {required bool included}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 18,
              color: included ? theme.colorScheme.primary : muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: included ? null : muted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscribed ? 'Annual plan' : 'Free plan',
                      key: const Key('plan-name'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subscribed
                          ? kAnnualPriceLabel
                          : 'Upgrade for $kAnnualPriceLabel',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              _StatusChip(
                key: const Key('subscription-chip'),
                icon: subscribed
                    ? Icons.workspace_premium_outlined
                    : Icons.lock_outline,
                label: subscribed ? 'Subscribed' : 'Free',
                highlighted: subscribed,
              ),
            ],
          ),
          const SizedBox(height: 12),
          perk(
            Icons.check_circle_outline,
            'Browse the directory and job board',
            included: true,
          ),
          perk(Icons.check_circle_outline, 'Apply to jobs', included: true),
          perk(
            subscribed ? Icons.check_circle_outline : Icons.lock_outline,
            'Message alumni directly',
            included: subscribed,
          ),
          perk(
            subscribed ? Icons.check_circle_outline : Icons.lock_outline,
            'Post jobs and marketplace listings',
            included: subscribed,
          ),
          const SizedBox(height: 12),
          if (subscribed)
            Text(
              'Your subscription is active. Renewing or cancelling is not '
              'available in this demo.',
              key: const Key('subscription-note'),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('subscribe-button'),
                onPressed: onSubscribe,
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Subscribe'),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Theme', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'System follows your phone\'s light or dark setting.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              key: const Key('theme-selector'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecuritySection extends StatelessWidget {
  const _SecuritySection({
    required this.hasPin,
    required this.bioAvailable,
    required this.bioEnabled,
    required this.busy,
    required this.onPin,
    required this.onBiometrics,
  });

  final bool hasPin;
  final bool bioAvailable;
  final bool bioEnabled;
  final bool busy;
  final VoidCallback onPin;
  final ValueChanged<bool> onBiometrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          key: const Key('pin-tile'),
          leading: const Icon(Icons.pin_outlined),
          title: Text(hasPin ? 'Change PIN' : 'Set a PIN'),
          subtitle: Text(
            hasPin
                ? 'Locks the app after ${kLockAfterBackground.inMinutes} '
                      'minutes in the background.'
                : 'Not set. You will verify your email on every launch.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onPin,
        ),
        if (hasPin && bioAvailable) ...[
          const Divider(height: 1),
          SwitchListTile(
            key: const Key('biometrics-switch'),
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Unlock with fingerprint or face'),
            subtitle: const Text('Your PIN always works as well.'),
            value: bioEnabled,
            onChanged: busy ? null : onBiometrics,
          ),
        ],
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'This is a convenience lock on this device, not extra protection '
            'for your account.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lingkaran',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'A demo of a verified alumni directory, job board and '
            'marketplace. Not official UNDIP or Ikafe branding. No real '
            'payments are processed.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
