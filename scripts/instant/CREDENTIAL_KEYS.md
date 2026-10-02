# Host credential operations

Credentials are AES-256-GCM encrypted. The keyring is a JSON file, outside the
repository, read from YABITZ_CREDENTIAL_KEY_FILE. Host and credential IDs are
authenticated along with the ciphertext. Missing keys disable credential
operations; keys are never automatically regenerated.

## Initial setup (Debian / Docker Compose)

Create /etc/justnow-system/secrets with mode 0700 and generate the keyring with:

```sh
sudo ruby scripts/instant/generate_credential_key.rb /etc/justnow-system/secrets/credential_keys.json
```

If Ruby is only available in Docker, run the script in the existing app container
with the directory mounted read/write for setup only. The production app mount
must remain read-only. The current container runs as root; if changed to another
UID, adjust file ownership to that UID and keep mode 0600.

Apply scripts/instant/create_host_credentials_tables.sql before starting the new
app. Back up the keyring to a separate protected location, not the database backup
directory. Do not print key values, commit them, or include them in support logs.
Configure HTTPS before entering real passwords.

## Restore

Restore the database and the matching keyring, set file permissions, and start
the app. Test a known non-production credential. A database backup without its
matching keys cannot be decrypted. Keep old keys for as long as old DB backups
are retained. Test restore on an isolated environment.

## Rotation

1. Back up the database and current keyring separately.
2. Add a new random 32-byte Base64 key with a new key ID to `keys` and make it
   `active`; retain all previous keys. Use an administrative script or editor
   that does not print secret values. Replace the JSON file atomically.
3. Run `docker compose exec -T app bundle exec ruby scripts/instant/rotate_credential_keys.rb`.
   All records are re-encrypted in one transaction; errors roll back the batch.
4. Verify retrieval and back up the new keyring separately.

On suspected leakage, rotate affected device passwords as well as the encryption
key. Re-encryption cannot undo disclosure of old DB backups and keys.

## Audit

Admins can open the per-host operation history (latest 200 records).
credential_access_log contains user ID, name snapshots, UTC timestamp, host ID,
credential ID, action, client IP and result. It never contains passwords.
Reveal/copy records mean the server delivered the password, not proof that a
human read it or clipboard writing succeeded. Application/DB administrators can
modify local logs; stronger audit protection requires an external log collector.

Existing notes are not migrated. Deleting a credential removes the current
encrypted record; encrypted database backups follow the backup retention policy.
