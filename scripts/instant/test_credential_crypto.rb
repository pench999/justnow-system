require 'minitest/autorun'
require 'tmpdir'
require_relative '../../lib/yabitz/misc/credential_store'

class CredentialCryptoTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir
    @path = File.join(@directory, 'keys.json')
    @old_path = ENV['YABITZ_CREDENTIAL_KEY_FILE']
    ENV['YABITZ_CREDENTIAL_KEY_FILE'] = @path
    @keyring = {'active' => 'test-key', 'keys' => {'test-key' => Base64.strict_encode64(SecureRandom.random_bytes(32))}}
    File.write(@path, JSON.generate(@keyring))
  end

  def teardown
    ENV['YABITZ_CREDENTIAL_KEY_FILE'] = @old_path
    FileUtils.remove_entry(@directory)
  end

  def row
    key, nonce, tag, encrypted = Yabitz::CredentialStore.encrypt('test-secret?', 123, 'abc')
    {'host' => 123, 'credential_id' => 'abc', 'key_id' => key, 'nonce' => nonce, 'auth_tag' => tag, 'ciphertext' => encrypted}
  end

  def test_roundtrip_and_random_nonce
    first, second = row, row
    assert_equal 'test-secret?', Yabitz::CredentialStore.decrypt(first)
    refute_equal first['ciphertext'], second['ciphertext']
    refute_includes first['ciphertext'], 'test-secret'
  end

  def test_tamper_and_other_host_fail
    damaged = row.merge('auth_tag' => Base64.strict_encode64("\0" * 16))
    assert_raises(OpenSSL::Cipher::CipherError) {Yabitz::CredentialStore.decrypt(damaged)}
    assert_raises(OpenSSL::Cipher::CipherError) {Yabitz::CredentialStore.decrypt(row.merge('host' => 124))}
  end

  def test_missing_or_unknown_key_fails
    stored = row
    File.delete(@path)
    refute Yabitz::CredentialStore.available?
    assert_raises(Yabitz::CredentialStore::KeyUnavailable) {Yabitz::CredentialStore.decrypt(stored)}
    File.write(@path, JSON.generate(@keyring))
    assert_raises(Yabitz::CredentialStore::KeyUnavailable) {Yabitz::CredentialStore.decrypt(stored.merge('key_id' => 'missing'))}
  end

  def test_key_rotation_and_restored_keyring
    stored = row
    backup = File.read(@path)
    @keyring['keys']['new-key'] = Base64.strict_encode64(SecureRandom.random_bytes(32))
    @keyring['active'] = 'new-key'
    File.write(@path, JSON.generate(@keyring))
    assert_equal 'test-secret?', Yabitz::CredentialStore.decrypt(stored)
    key, = Yabitz::CredentialStore.encrypt('new-secret', 123, 'abc')
    assert_equal 'new-key', key
    File.delete(@path)
    File.write(@path, backup)
    assert_equal 'test-secret?', Yabitz::CredentialStore.decrypt(stored)
  end
end
