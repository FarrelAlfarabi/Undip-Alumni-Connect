import 'package:flutter/material.dart';

import '../widgets/feedback_sheet.dart';
import '../widgets/menu_list.dart';
import 'about_screen.dart';
import 'contact_admin_screen.dart';

/// Profile > Help: reach the admin team, report a problem, see the version.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MenuList(
              items: [
                MenuItem(
                  key: const Key('profile-contact-admin'),
                  icon: Icons.support_agent_outlined,
                  title: 'Contact admin',
                  subtitle: 'Email the admin team',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ContactAdminScreen(),
                    ),
                  ),
                ),
                MenuItem(
                  key: const Key('profile-feedback'),
                  icon: Icons.feedback_outlined,
                  title: 'Send feedback',
                  subtitle: 'Something broken or confusing?',
                  onTap: () =>
                      showFeedbackSheet(context, error: null, screen: 'Help'),
                ),
                MenuItem(
                  key: const Key('profile-about'),
                  icon: Icons.info_outline,
                  title: 'About',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
