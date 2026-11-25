# Upload-key exposure — 30 September 2026

Commit `ceb81d6` added `frontend/android/key.properties` and
`frontend/android/keystore/upload-keystore.jks`. Treat that upload identity as
compromised, even in a private repository. Removing tracked files does not revoke
the key or remove copies from earlier commits, clones, caches, or downloaded artifacts.

The files are now removed from the index and ignored. Local files are preserved
to avoid destroying the owner's only copy. They must not sign a new distribution.
CI checks tracked paths before generating its own two-day compile-only identity.

## Rotation and history rewrite completed

The owner confirmed the key was not registered with Google Play. A fresh RSA
3072-bit key was generated on 30 September 2026. Local Gradle signing now points
to owner-only storage outside the checkout:
`C:/Users/aanan/.food-insight-signing/2026-09-30-rotation/`.
That directory contains the new keystore, private credentials, public PEM
certificate, and quarantined copies of the compromised files. Back it up securely.

New SHA-256: `0EAFA364987E6B403EC626362771DB0B6A225ECC660A0D37FC0267BC3701A35F`.
The new SHA-1 and SHA-256 were registered in Firebase. The compromised release
fingerprints were removed. The separate existing debug identity was retained.
No Play reset is needed before the first upload. Do not use older APK/AAB files.

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

Git history cleanup completed on 25 November 2026 using `git-filter-repo`
(`2.47.0`) against an isolated bare mirror after saving pre-filter remote refs
and `pre-filter-backup.bundle` in
`C:/Users/aanan/.food-insight-signing/history-backup-2026-11-25/`:

- Removed `frontend/android/key.properties` and
  `frontend/android/keystore/upload-keystore.jks` from commit history across
  all reachable commits (21 of 71 commits rewritten from `ceb81d6c`; 1
  now-empty deletion commit pruned).
- Verified zero remaining `.jks`, `.keystore`, or `key.properties` objects in
  `git rev-list --objects --all` and confirmed identical post-rewrite tree hashes
  on `main` (`1e964048001a7510f994a2f0fdfcdf6c525465db`),
  `v1.0.2-beta.2004` (`34131765dafe7debfaf31d577b8e8b83b487a672`), and
  `fix/audit-batch2-release-build` (`5fe05bbfa5c3a41ffe872cba37650761d447297a`).
- Published rewritten `main` (`a9f748ca` -> `47cdd9b3`) and tag
  `v1.0.2-beta.2004` (`bf1e55d6` -> `b9c6866e`) using `--force-with-lease`;
  verified `fix/audit-batch2-release-build` and `refs/pull/1/head` branched prior
  to `ceb81d6c` (`36aecadb`) and were unaffected.
- Local checkout was resynced onto rewritten `origin/main` and pruned
  (`git reflog expire --expire=now --all` and `git gc --prune=now`) while
  preserving local ignored signing files on disk.

Remaining external note: request GitHub Support cached-view garbage collection
for historical URLs referencing commit `ceb81d6c2409d2449685d9e36dc1e5cb9a0a49f4`,
and require any collaborator with an older local clone to re-clone fresh.
