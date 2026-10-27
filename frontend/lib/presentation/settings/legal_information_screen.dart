import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/env.dart';

enum LegalPage { privacy, terms, dataSources }

class LegalInformationScreen extends StatelessWidget {
  const LegalInformationScreen({super.key, required this.page});
  final LegalPage page;

  String get _title => switch (page) {
        LegalPage.privacy => 'Privacy Policy',
        LegalPage.terms => 'Terms of Use',
        LegalPage.dataSources => 'Data Sources',
      };

  String get _url => switch (page) {
        LegalPage.privacy => Env.privacyUrl,
        LegalPage.terms => Env.termsUrl,
        LegalPage.dataSources => 'https://world.openfoodfacts.org/',
      };

  List<(String, String)> get _sections => switch (page) {
        LegalPage.privacy => [
            (
              'Your account and profile',
              'Food Insight uses Firebase Authentication for your account. Profile details you enter, including food preferences, allergies, health goals and optional health information, are saved to your account to personalize food information.'
            ),
            (
              'Food and activity data',
              'Scans, diet logs, shopping lists, meal plans and daily activity totals are stored with your account and may be cached on this device. Health Connect is optional. When you choose to connect it, the app requests steps and active calories; distance and step-counter calories may be estimates.'
            ),
            (
              'Services',
              'Product barcodes are looked up through Open Food Facts. AI requests you make are processed by our authenticated backend on Supabase and Groq. Firebase and Supabase support account storage, and Firebase Crashlytics receives minimized crash reports when crash reporting is enabled. AI replies may be inaccurate.'
            ),
            (
              'Your choices',
              'You can turn off crash reporting in Settings. Optional Firebase usage analytics is off by default and sends feature events and app/device identifiers, without account IDs, food, health or chat content. Advertising identifiers and personalization are disabled. You can delete your account and associated data from Settings. For a deletion request without the app, use the public account deletion page or contact the address listed there.'
            ),
            (
              'Food safety',
              'Product data can be missing or incorrect. If you have a serious allergy, always verify the physical package label. Food Insight provides general nutrition information, not medical advice.'
            ),
          ],
        LegalPage.terms => [
            (
              'Using Food Insight',
              'Food Insight helps you inspect packaged food information and keep a personal diet record. Check product packaging before relying on any ingredient, allergen or nutrition information.'
            ),
            (
              'Health information',
              'Food Insight is not a medical device and does not provide diagnosis or treatment. AI explanations and meal suggestions can be wrong. Consult a qualified professional for medical or dietary care.'
            ),
            (
              'Your data',
              'You are responsible for the information you add. Do not submit another person’s sensitive information. You may delete your account in Settings.'
            ),
            (
              'Third-party information',
              'Open Food Facts data is community maintained. Brand names and product images belong to their respective owners. Service availability and product coverage can change.'
            ),
          ],
        LegalPage.dataSources => [
            (
              'Open Food Facts',
              'Food Insight retrieves community-contributed product facts and images from Open Food Facts. Product records may be incomplete or outdated. Verify the physical package, especially for allergies.'
            ),
            (
              'Source licenses',
              'The Open Food Facts database is available under the Open Database License; individual contents use the Database Contents License. Product images are available under Creative Commons Attribution ShareAlike, subject to other image rights. Visit the source for license details.'
            ),
            (
              'Personal Food Fit',
              'Food Fit uses explicit product facts, your saved preferences and daily context. Missing information lowers confidence or prevents a score. The score is general guidance, not a clinical safety assessment.'
            ),
            (
              'AI explanations',
              'AI can explain available facts and suggest meals, but it does not verify the package or replace medical advice. Your requests are sent through our backend to Groq.'
            ),
          ],
      };

  Future<void> _openOnline(BuildContext context) async {
    final uri = Uri.tryParse(_url);
    if (uri == null ||
        uri.scheme != 'https' ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The online page is unavailable.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (page != LegalPage.dataSources)
              const Text('Food Insight · Last updated 30 September 2026'),
            const SizedBox(height: 12),
            for (final (heading, body) in _sections) ...[
              Text(heading, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
            ],
            if (_url.isNotEmpty)
              TextButton.icon(
                onPressed: () => _openOnline(context),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(page == LegalPage.dataSources
                    ? 'Visit Open Food Facts'
                    : 'Read online'),
              ),
          ],
        ),
      );
}
