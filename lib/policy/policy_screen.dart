import 'package:flutter/material.dart';

import 'policy_text.dart';

/// "Privacy policy and community rules", reached from Profile and from the
/// consent screen.
class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key, this.bundle});

  final AssetBundle? bundle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy and rules')),
      body: SafeArea(child: PolicyReader(bundle: bundle)),
    );
  }
}
