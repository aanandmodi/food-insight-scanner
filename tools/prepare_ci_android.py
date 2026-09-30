"""Prepare build-only Android fixtures. Never creates a distributable identity."""
import json
import os
from pathlib import Path
import secrets
import subprocess

root = Path(__file__).resolve().parents[1]
android = root / 'frontend/android'
if os.environ.get('CI') != 'true':
    raise SystemExit('This fixture is restricted to CI.')
if (android / 'key.properties').exists():
    raise SystemExit('Refusing to overwrite existing signing configuration.')
password = secrets.token_urlsafe(24)
subprocess.run(['keytool', '-genkeypair', '-noprompt', '-keystore', str(android / 'ci-signing.jks'),
    '-alias', 'ci-only', '-keyalg', 'RSA', '-keysize', '2048', '-validity', '2',
    '-dname', 'CN=CI build only - not for distribution', '-storepass', password,
    '-keypass', password], check=True, capture_output=True)
(android / 'key.properties').write_text(f'storeFile=ci-signing.jks\nstorePassword={password}\nkeyAlias=ci-only\nkeyPassword={password}\n')
config = android / 'app/google-services.json'
if not config.exists():
    config.write_text(json.dumps({'project_info': {'project_number': '123456789', 'project_id': 'demo-food-insight'},
      'client': [{'client_info': {'mobilesdk_app_id': '1:123456789:android:1234567890123456',
        'android_client_info': {'package_name': 'com.food_insight_scanner.app'}},
        'api_key': [{'current_key': 'CI_CONFIG_NOT_A_PRODUCTION_KEY'}]}], 'configuration_version': '1'}))
print('Prepared ephemeral CI signing and Firebase build fixtures; do not distribute this AAB.')
