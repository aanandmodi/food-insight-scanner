const { test } = require('node:test');
const assert = require('node:assert/strict');
const { requiresEmailVerification } = require('../lib/aiValidation');

test('requiresEmailVerification blocks only unverified password accounts', () => {
  assert.equal(
    requiresEmailVerification({
      email_verified: false,
      firebase: { sign_in_provider: 'password' },
    }),
    true,
  );
  assert.equal(
    requiresEmailVerification({
      firebase: { sign_in_provider: 'password' },
    }),
    true,
  );
  assert.equal(
    requiresEmailVerification({
      email_verified: true,
      firebase: { sign_in_provider: 'password' },
    }),
    false,
  );
  assert.equal(
    requiresEmailVerification({
      email_verified: false,
      firebase: { sign_in_provider: 'anonymous' },
    }),
    false,
  );
  assert.equal(
    requiresEmailVerification({
      email_verified: true,
      firebase: { sign_in_provider: 'google.com' },
    }),
    false,
  );
});
