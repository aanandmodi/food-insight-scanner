/// Public legal page URLs. Set these after publishing the pages in /legal.
class Env {
  Env._();
  static const privacyUrl = String.fromEnvironment('PRIVACY_URL', defaultValue: 'https://food-insight-scanner-app.web.app/privacy.html');
  static const termsUrl = String.fromEnvironment('TERMS_URL', defaultValue: 'https://food-insight-scanner-app.web.app/terms.html');
  static const deletionUrl = String.fromEnvironment('DELETION_URL', defaultValue: 'https://food-insight-scanner-app.web.app/delete-account.html');
}
