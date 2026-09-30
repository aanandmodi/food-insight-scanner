"""Live AI smoke check for the authenticated shared backend, not the retired proxy.
Requires APP_CHECK_TOKEN in this process environment and explicit --run-live.
A disposable account is cleaned through the full backend deletion path.
"""
import argparse
import os
import secrets
from verify_cloud import auth, request, URL, PUBLIC_KEY

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run-live', action='store_true')
    args = parser.parse_args()
    token = os.environ.get('APP_CHECK_TOKEN')
    if not args.run_live or not token:
        raise SystemExit('Requires --run-live and a privately configured APP_CHECK_TOKEN. Do not paste tokens in chat.')
    account = auth('signUp', {'email': f'food-insight-qa-{secrets.token_hex(8)}@example.com',
        'password': secrets.token_urlsafe(32), 'returnSecureToken': True})
    def call(operation, data):
        return request(URL + '/functions/v1/food-insight-api', 'POST',
            {'operation': operation, 'data': data}, {'apikey': PUBLIC_KEY,
             'Authorization': 'Bearer ' + account['idToken'], 'X-Firebase-AppCheck': token})
    try:
        status, result = call('aiTask', {'task': 'meal', 'content': 'One plain chapati',
            'profile': {'country': 'India'}})
        assert status == 200, f'AI check returned HTTP {status}; verify deployment, flags, quota and key.'
        data = result['data']
        assert isinstance(data['calories'], (int, float)) and 0 <= data['calories'] <= 5000
        print('PASS live backend AI schema')
    finally:
        status, result = call('requestAccountDeletion', {})
        if status != 200 or result.get('data', {}).get('deleted') is not True:
            # Preserve identity for a retry rather than orphaning account records.
            raise RuntimeError('Fixture cleanup requires retry for UID ' + account['localId'])
        print('PASS full backend fixture deletion')

if __name__ == '__main__':
    main()
