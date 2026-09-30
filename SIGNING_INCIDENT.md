# Upload-key exposure — 30 September 2026

Commit `ceb81d6` added `frontend/android/key.properties` and
`frontend/android/keystore/upload-keystore.jks`. Treat that upload identity as
compromised, even in a private repository. Removing tracked files does not revoke
the key or remove copies from earlier commits, clones, caches, or downloaded artifacts.

The files are now removed from the index and ignored. Local files are preserved
to avoid destroying the owner's only copy. They must not sign a new distribution.
CI checks tracked paths before generating its own two-day compile-only identity.

## Rotation decision pending owner confirmation

- If no Google Play app has registered the key: generate a new upload identity,
  store its passwords outside Git, and use it for the first Play upload.
- If Play has registered it: request an upload-key reset in Play Console and
  register the replacement certificate. Wait for reset activation before upload.
- If it is also the app-signing key (not just an upload key), follow Play's
  app-signing-key upgrade process; an upload-key reset alone is insufficient.
- A locally installed APK signed with the old key cannot receive an in-place
  update signed with a different key. Preserve user data and agree on a migration
  or separate test application before uninstalling anything.

## Repository history cleanup

Rotate first. Coordinate a temporary push freeze with all collaborators. In a
separate secured backup clone, save all current refs and a private bundle. Use
`git filter-repo --sensitive-data-removal --invert-paths --path
frontend/android/key.properties --path frontend/android/keystore/upload-keystore.jks`.
Inspect every branch and tag for alternate secret paths and verify the resulting
trees. Coordinate GitHub cached-view/PR-ref cleanup where applicable. Publish only
the reviewed branch/tag rewrites with leases against captured remote refs, then
require collaborators to re-clone. Do not blindly force-push `--mirror`.

History has **not** been rewritten for this incident. Rotation, Play status, and
coordinated cleanup are outstanding; beta readiness is not claimed.
