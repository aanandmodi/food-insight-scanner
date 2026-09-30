const { before, after, test } = require('node:test');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, deleteDoc } = require('firebase/firestore');
const { ref, uploadBytes, getBytes, deleteObject } = require('firebase/storage');
let environment;
before(async () => {
  environment = await initializeTestEnvironment({ projectId:'demo-food-insight',
    firestore:{host:'127.0.0.1',port:8088,rules:readFileSync('../firestore.rules','utf8')},
    storage:{host:'127.0.0.1',port:9198,rules:readFileSync('../storage.rules','utf8')} });
  await environment.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(),'users/alice'),{name:'Alice'});
    await setDoc(doc(context.firestore(),'users/bob'),{name:'Bob'});
    await setDoc(doc(context.firestore(),'products/12345678'),{name:'Catalog'});
    await uploadBytes(ref(context.storage(),'products/12345678.jpg'),new Uint8Array([1]),{contentType:'image/jpeg'});
  });
});
after(async () => { await environment?.cleanup(); });
test('profiles are owner-only; anonymous callers have no access',async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const guest = environment.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(alice,'users/alice')));
  await assertSucceeds(setDoc(doc(alice,'users/alice'),{name:'Updated'}));
  await assertFails(getDoc(doc(alice,'users/bob')));
  await assertFails(setDoc(doc(alice,'users/bob'),{name:'Attack'}));
  await assertFails(getDoc(doc(guest,'users/alice')));
});
test('canonical products are authenticated read-only',async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(alice,'products/12345678')));
  await assertFails(setDoc(doc(alice,'products/12345678'),{sodium:0}));
  await assertFails(deleteDoc(doc(alice,'products/12345678')));
  await assertFails(getDoc(doc(environment.unauthenticatedContext().firestore(),'products/12345678')));
});
test('logs remain isolated across canonical and legacy paths',async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  for (const root of ['users/alice/dietEntries','diet_log/alice/entries','scan_history/alice/scans','shopping_list/alice/items','activity_logs/alice/logs']) {
    await assertSucceeds(setDoc(doc(alice,`${root}/sample`),{calories:100}));
    await assertFails(setDoc(doc(alice,`${root.replace('/alice/','/bob/')}/sample`),{calories:100}));
    await assertFails(getDoc(doc(alice,`${root.replace('/alice/','/bob/')}/sample`)));
  }
});
test('clients cannot reset quotas or turn AI back on',async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(alice,'users/alice/aiUsage/2026-09-29'),{chat:0}));
  await assertFails(deleteDoc(doc(alice,'users/alice/aiUsage/2026-09-29')));
  await assertFails(setDoc(doc(alice,'config/featureFlags'),{aiEnabled:true}));
});
test('deletion guards prevent stale-token recreation and cannot be removed by clients',async () => {
  await environment.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(),'accountDeletionGuards/deleted'),{deleting:true});
  });
  const deleted = environment.authenticatedContext('deleted').firestore();
  for (const path of ['users/deleted','users/deleted/dietEntries/new','diet_log/deleted/entries/new',
    'scan_history/deleted/scans/new','shopping_list/deleted/items/new','activity_logs/deleted/logs/new']) {
    await assertFails(setDoc(doc(deleted,path),{name:'stale token'}));
  }
  await assertFails(deleteDoc(doc(deleted,'accountDeletionGuards/deleted')));
});
test('private storage enforces owner, type, size and deletion; canonical assets are protected',async () => {
  const alice = environment.authenticatedContext('alice').storage();
  const bob = environment.authenticatedContext('bob').storage();
  const avatar = ref(alice,'users/alice/avatar.jpg');
  await assertSucceeds(uploadBytes(avatar,new Uint8Array([1,2,3]),{contentType:'image/jpeg'}));
  await assertFails(getBytes(ref(bob,'users/alice/avatar.jpg')));
  await assertFails(uploadBytes(ref(bob,'users/alice/avatar.jpg'),new Uint8Array([1]),{contentType:'image/jpeg'}));
  await assertFails(deleteObject(ref(bob,'users/alice/avatar.jpg')));
  await assertFails(uploadBytes(ref(alice,'users/alice/script.html'),new Uint8Array([1]),{contentType:'text/html'}));
  await assertFails(uploadBytes(ref(alice,'users/alice/large.jpg'),new Uint8Array(10*1024*1024+1),{contentType:'image/jpeg'}));
  await assertSucceeds(getBytes(ref(alice,'products/12345678.jpg')));
  await assertFails(uploadBytes(ref(alice,'products/12345678.jpg'),new Uint8Array([1]),{contentType:'image/jpeg'}));
  await assertSucceeds(deleteObject(avatar));
});
