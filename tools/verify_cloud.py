"""Live regression check with disposable Firebase accounts, cleaned in finally.
No user data is read. Requires the additive Supabase migration/integration.
Run: python tools/verify_cloud.py --run-live
"""
import argparse
import base64
import json
from pathlib import Path
import secrets
from urllib.request import Request, urlopen
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[1]
cfg = json.loads((ROOT / 'frontend/android/app/google-services.json').read_text())
API_KEY = cfg['client'][0]['api_key'][0]['current_key']
URL = 'https://tslcgavpkujkfexzmisk.supabase.co'
PUBLIC_KEY = 'sb_publishable_qazTUN379u3XfEcjHxq2zA_4N1rrqNr'

def request(url, method='GET', data=None, headers=None):
    payload = data if isinstance(data, bytes) else json.dumps(data).encode() if data is not None else None
    req = Request(url, data=payload, method=method, headers={'Content-Type':'application/json', **(headers or {})})
    try:
        with urlopen(req, timeout=30) as res:
            body = res.read()
            return res.status, json.loads(body) if body else None
    except HTTPError as error:
        return error.code, json.loads(error.read())

def auth(action, data):
    status, result = request(f'https://identitytoolkit.googleapis.com/v1/accounts:{action}?key={API_KEY}', 'POST', data)
    if status != 200:
        raise RuntimeError(f'Firebase {action}: {status} {result.get("error",{}).get("message")}')
    return result

def db(table, account=None, method='GET', data=None, query=''):
    headers = {'apikey':PUBLIC_KEY,'Prefer':'return=representation,resolution=merge-duplicates'}
    if account: headers['Authorization'] = 'Bearer ' + account['idToken']
    return request(f'{URL}/rest/v1/{table}{query}',method,data,headers)

def main():
    accounts = []
    try:
        for _ in range(2):
            email = f'codex-qa-{secrets.token_hex(8)}@example.com'
            password = secrets.token_urlsafe(32)
            account = auth('signUp', {'email':email,'password':password,'returnSecureToken':True})
            accounts.append(account)
            again = auth('signInWithPassword', {'email':email,'password':password,'returnSecureToken':True})
            assert again['localId'] == account['localId']
        a,b = accounts
        assert a['localId'] != b['localId']
        print('PASS Firebase signup and repeated email login preserve unique UIDs')
        for table in ['profiles','scans','diet_entries','shopping_items','meal_plans','chat_messages','activity_logs']:
            record_id = 'profile' if table == 'profiles' else 'qa-record'
            for account in accounts:
                status, result = db(table,account,'POST',{'user_id':account['localId'],'id':record_id,'data':{'name':'QA fixture','calories':321}})
                assert status in (200,201), (table,status,result)
            status, rows = db(table,a,query='?id=eq.' + record_id)
            assert status == 200 and len(rows) == 1 and rows[0]['user_id'] == a['localId'], (table,status,rows)
            status, rows = db(table,a,query='?user_id=eq.' + b['localId'])
            assert status == 200 and rows == []
            status, _ = db(table,a,'POST',{'user_id':b['localId'],'id':record_id,'data':{'name':'forbidden'}})
            assert status in (401,403), (table,status)
            status, rows = db(table,None,query='?id=eq.' + record_id)
            assert status == 200 and rows == []
            print(f'PASS {table}: owner read/write, cross-user denied, public denied')
        # A crafted update/delete filter must not modify the other account.
        status, rows = db('diet_entries',a,'DELETE',query='?user_id=eq.'+b['localId'])
        assert status == 200 and rows == []
        status, rows = db('diet_entries',b,query='?id=eq.qa-record')
        assert rows[0]['data']['calories'] == 321
        print('PASS cross-user delete denied and other account record preserved')
        image = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aV1cAAAAASUVORK5CYII=')
        object_path = 'users/' + a['localId'] + '/qa.png'
        storage_headers = {'apikey':PUBLIC_KEY,'Authorization':'Bearer '+a['idToken']}
        status,result = request(URL+'/storage/v1/object/food-insight-private/'+object_path,'POST',image,{**storage_headers,'Content-Type':'image/png'})
        assert status == 200, (status,result)
        try:
            status,_ = request(URL+'/storage/v1/object/sign/food-insight-private/'+object_path,'POST',{'expiresIn':60},storage_headers)
            assert status == 200
            status,_ = request(URL+'/storage/v1/object/sign/food-insight-private/'+object_path,'POST',{'expiresIn':60},{'apikey':PUBLIC_KEY,'Authorization':'Bearer '+b['idToken']})
            assert status in (400,401,403,404)
            print('PASS private storage upload and owner URL signing; cross-user access denied')
        finally:
            request(URL+'/storage/v1/object/food-insight-private','DELETE',{'prefixes':[object_path]},storage_headers)
    finally:
        for account in accounts:
            for table in ['profiles','scans','diet_entries','shopping_items','meal_plans','chat_messages','activity_logs']:
                status,_ = db(table,account,'DELETE',query='?user_id=eq.'+account['localId'])
                if status not in (200,204): print(f'Cleanup pending for QA {table}: HTTP {status}')
            auth('delete',{'idToken':account['idToken']})
        if accounts: print('Cleaned disposable test accounts and records')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--run-live',action='store_true')
    if parser.parse_args().run_live: main()
