import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/policy_config.dart';

enum PolicyLanguage { id, en }

/// Loads one of the two policy files and puts in the version, date, operator
/// name and contact email from `policy_config.dart`.
Future<String> loadPolicyText(
  PolicyLanguage language, {
  AssetBundle? bundle,
}) async {
  final raw = await (bundle ?? rootBundle).loadString(
    language == PolicyLanguage.id ? kPolicyAssetId : kPolicyAssetEn,
  );
  return fillPolicyTokens(raw, language);
}

String fillPolicyTokens(String raw, PolicyLanguage language) => raw
    .replaceAll('{{VERSION}}', kPolicyVersion)
    .replaceAll(
      '{{UPDATED}}',
      language == PolicyLanguage.id ? kPolicyUpdatedId : kPolicyUpdatedEn,
    )
    .replaceAll('{{OPERATOR}}', kOperatorName)
    .replaceAll('{{CONTACT_EMAIL}}', kContactEmail);

/// Shows the simple markdown in the policy files: `# ` title, `## ` heading,
/// `- ` bullet, anything else a paragraph.
class PolicyBody extends StatelessWidget {
  const PolicyBody({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    for (final line in text.split('\n')) {
      final l = line.trimRight();
      if (l.isEmpty) continue;
      if (l.startsWith('## ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 6),
            child: Text(
              l.substring(3),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      } else if (l.startsWith('# ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l.substring(2), style: theme.textTheme.headlineSmall),
          ),
        );
      } else if (l.startsWith('- ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(
                  child: Text(
                    l.substring(2),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              l,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// "Draft for the beta. The text may change."
class PolicyDraftBanner extends StatelessWidget {
  const PolicyDraftBanner({super.key, this.language = PolicyLanguage.id});

  final PolicyLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('policy-draft-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.secondaryContainer,
      child: Text(
        language == PolicyLanguage.id
            ? 'Draft for the beta. The text may change. (Draf untuk beta. Teks dapat berubah.)'
            : 'Draft for the beta. The text may change.',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Language switch (Indonesian first) plus the text. Used on the policy
/// screen and on the consent screen.
class PolicyReader extends StatefulWidget {
  const PolicyReader({super.key, this.bundle});

  final AssetBundle? bundle;

  @override
  State<PolicyReader> createState() => _PolicyReaderState();
}

class _PolicyReaderState extends State<PolicyReader> {
  PolicyLanguage _language = PolicyLanguage.id;
  Future<String>? _text;

  AssetBundle get _bundle => widget.bundle ?? DefaultAssetBundle.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _text ??= loadPolicyText(_language, bundle: _bundle);
  }

  void _set(PolicyLanguage l) {
    setState(() {
      _language = l;
      _text = loadPolicyText(l, bundle: _bundle);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PolicyDraftBanner(language: _language),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<PolicyLanguage>(
            segments: const [
              ButtonSegment(
                value: PolicyLanguage.id,
                label: Text('Bahasa Indonesia'),
              ),
              ButtonSegment(value: PolicyLanguage.en, label: Text('English')),
            ],
            selected: {_language},
            onSelectionChanged: (s) => _set(s.first),
          ),
        ),
        Expanded(
          child: FutureBuilder<String>(
            future: _text!,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      "Couldn't load the text. Please try again later.",
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                key: const Key('policy-scroll'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: PolicyBody(text: snap.data ?? ''),
              );
            },
          ),
        ),
      ],
    );
  }
}
