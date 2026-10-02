require 'openssl'
require 'base64'
require 'json'
require 'securerandom'

module Yabitz
  module CredentialStore
    class KeyUnavailable < StandardError; end

    # Use prepared statements; the legacy binder replaces question marks in values.
    class SafeConnection
      def initialize(connection)
        @connection = connection
      end

      def query(sql, *values)
        statement = @connection.prepare(sql)
        result = statement.execute(*values)
        result ? result.to_a : nil
      ensure
        statement.close if statement
      end
    end

    def self.keys
      path = ENV['YABITZ_CREDENTIAL_KEY_FILE']
      raise KeyUnavailable unless path && File.file?(path)
      data = JSON.parse(File.read(path))
      raise KeyUnavailable unless data.is_a?(Hash) && data['keys'].is_a?(Hash)
      active = data.fetch('active')
      raise KeyUnavailable unless active.is_a?(String) && active.match?(/\A[a-zA-Z0-9_-]{1,64}\z/)
      keys = data.fetch('keys').transform_values do |encoded|
        raise KeyUnavailable unless encoded.is_a?(String)
        key = Base64.strict_decode64(encoded)
        raise KeyUnavailable unless key.bytesize == 32
        key
      end
      raise KeyUnavailable unless keys.key?(active)
      [active, keys]
    rescue JSON::ParserError, KeyError, ArgumentError, SystemCallError
      raise KeyUnavailable
    end

    def self.available?
      keys
      true
    rescue KeyUnavailable
      false
    end

    def self.encrypt(password, host, id)
      active, keyring = keys
      cipher = OpenSSL::Cipher.new('aes-256-gcm').encrypt
      cipher.key = keyring.fetch(active)
      nonce = SecureRandom.random_bytes(12)
      cipher.iv = nonce
      cipher.auth_data = "host-credential:#{host}:#{id}"
      ciphertext = cipher.update(password) + cipher.final
      [active, Base64.strict_encode64(nonce), Base64.strict_encode64(cipher.auth_tag), Base64.strict_encode64(ciphertext)]
    end

    def self.decrypt(row)
      _, keyring = keys
      key = keyring[row['key_id']]
      raise KeyUnavailable unless key
      cipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
      cipher.key = key
      cipher.iv = Base64.strict_decode64(row['nonce'])
      cipher.auth_tag = Base64.strict_decode64(row['auth_tag'])
      cipher.auth_data = "host-credential:#{row['host']}:#{row['credential_id']}"
      (cipher.update(Base64.strict_decode64(row['ciphertext'])) + cipher.final).force_encoding('UTF-8')
    end

    def self.list(host)
      Stratum.conn do |c|
        c = SafeConnection.new(c)
        c.query('SELECT credential_id, label, username FROM host_credentials WHERE host=? ORDER BY created_at, credential_id', host).to_a
      end
    end

    def self.audit(c, user, host, id, action, ip, result='success')
      c = SafeConnection.new(c) unless c.is_a?(SafeConnection)
      c.query('INSERT INTO credential_access_log (user_oid, username, fullname, host, credential_id, action, sourceip, result) VALUES (?,?,?,?,?,?,?,?)',
              user.oid, user.name, user.fullname.to_s, host, id, action, ip, result)
    end
  end
end
