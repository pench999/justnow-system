# Run with bundle exec after mounting a keyring containing both old and new keys.
require_relative '../../lib/yabitz/misc/init'
require_relative '../../lib/yabitz/misc/credential_store'

active, = Yabitz::CredentialStore.keys
count = 0
Stratum.transaction do |c|
  c = Yabitz::CredentialStore::SafeConnection.new(c)
  c.query('SELECT * FROM host_credentials FOR UPDATE').to_a.each do |row|
    next if row['key_id'] == active
    password = Yabitz::CredentialStore.decrypt(row)
    key, nonce, tag, ciphertext = Yabitz::CredentialStore.encrypt(password, row['host'], row['credential_id'])
    c.query('UPDATE host_credentials SET key_id=?,nonce=?,auth_tag=?,ciphertext=? WHERE credential_id=?', key, nonce, tag, ciphertext, row['credential_id'])
    count += 1
  end
end
puts "Re-encrypted #{count} credentials. Keep old keys for retained database backups."
