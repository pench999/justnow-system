require_relative '../misc/credential_store'

class Yabitz::Application
  helpers do
    def credential_csrf_token
      session[:credential_csrf] ||= SecureRandom.hex(32)
    end

    def credential_request!(oid, id, action)
      protected!
      response['Cache-Control'] = 'no-store'
      host = Yabitz::Model::Host.get(oid.to_i)
      halt 404 unless host
      unless @isadmin
        Stratum.conn {|c| Yabitz::CredentialStore.audit(c, @user, host.oid, id, action, request.ip, 'denied') }
        halt 403, 'Forbidden'
      end
      token = params['csrf'].to_s
      expected = session[:credential_csrf].to_s
      halt 403, 'Forbidden' unless expected.size == 64 && token.size == 64 && Rack::Utils.secure_compare(token, expected)
      unless Yabitz::CredentialStore.available?
        Stratum.conn {|c| Yabitz::CredentialStore.audit(c, @user, host.oid, id, action, request.ip, 'failed') }
        halt 503, '認証情報の暗号鍵を利用できません。管理者へ連絡してください。'
      end
      host
    end
  end

  post '/ybz/host/:oid/credential/save' do |oid|
    id = params['credential_id'].to_s
    id = SecureRandom.hex(16) if id.empty?
    halt 400 unless id.match?(/\A[0-9a-f]{32}\z/)
    host = credential_request!(oid, id, 'save')
    label = params['label'].to_s.strip
    username = params['username'].to_s.strip
    password = params['password'].to_s
    halt 400, '用途とユーザー名を入力してください。' if label.empty? || username.empty?
    halt 400, '入力が長すぎます。' if label.size > 128 || username.size > 255 || password.bytesize > 4096
    Stratum.transaction do |c|
      c = Yabitz::CredentialStore::SafeConnection.new(c)
      row = c.query('SELECT * FROM host_credentials WHERE credential_id=? AND host=? FOR UPDATE', id, host.oid).first
      halt 404 if !params['credential_id'].to_s.empty? && !row
      halt 400, 'パスワードを入力してください。' if !row && password.empty?
      if row
        c.query('UPDATE host_credentials SET label=?, username=? WHERE credential_id=? AND host=?', label, username, id, host.oid)
        unless password.empty?
          key_id, nonce, tag, ciphertext = Yabitz::CredentialStore.encrypt(password, host.oid, id)
          c.query('UPDATE host_credentials SET key_id=?,nonce=?,auth_tag=?,ciphertext=? WHERE credential_id=? AND host=?', key_id, nonce, tag, ciphertext, id, host.oid)
        end
      else
        key_id, nonce, tag, ciphertext = Yabitz::CredentialStore.encrypt(password, host.oid, id)
        c.query('INSERT INTO host_credentials (credential_id,host,label,username,key_id,nonce,auth_tag,ciphertext) VALUES (?,?,?,?,?,?,?,?)', id, host.oid, label, username, key_id, nonce, tag, ciphertext)
      end
      Yabitz::CredentialStore.audit(c, @user, host.oid, id, row ? 'update' : 'create', request.ip)
    end
    'ok'
  end

  post '/ybz/host/:oid/credential/:id/reveal' do |oid, id|
    action = params['operation'] == 'copy' ? 'copy' : 'reveal'
    host = credential_request!(oid, id, action)
    password = nil
    Stratum.transaction do |c|
      c = Yabitz::CredentialStore::SafeConnection.new(c)
      row = c.query('SELECT * FROM host_credentials WHERE credential_id=? AND host=? FOR UPDATE', id, host.oid).first
      halt 404 unless row
      begin
        password = Yabitz::CredentialStore.decrypt(row)
      rescue Yabitz::CredentialStore::KeyUnavailable, OpenSSL::Cipher::CipherError, ArgumentError
        Yabitz::CredentialStore.audit(c, @user, host.oid, id, action, request.ip, 'failed')
      else
        Yabitz::CredentialStore.audit(c, @user, host.oid, id, action, request.ip)
      end
    end
    halt 503, '認証情報を復号できません。管理者へ連絡してください。' unless password
    content_type :json
    JSON.generate(:password => password)
  end

  post '/ybz/host/:oid/credential/:id/delete' do |oid, id|
    host = credential_request!(oid, id, 'delete')
    Stratum.transaction do |c|
      c = Yabitz::CredentialStore::SafeConnection.new(c)
      row = c.query('SELECT credential_id FROM host_credentials WHERE credential_id=? AND host=? FOR UPDATE', id, host.oid).first
      halt 404 unless row
      c.query('DELETE FROM host_credentials WHERE credential_id=? AND host=?', id, host.oid)
      Yabitz::CredentialStore.audit(c, @user, host.oid, id, 'delete', request.ip)
    end
    'ok'
  end

  get '/ybz/host/:oid/credential-log' do |oid|
    admin_protected!
    response['Cache-Control'] = 'no-store'
    @host = Yabitz::Model::Host.get(oid.to_i)
    halt 404 unless @host
    @credential_logs = Stratum.conn do |c|
      c = Yabitz::CredentialStore::SafeConnection.new(c)
      c.query('SELECT occurred_at, username, fullname, credential_id, action, sourceip, result FROM credential_access_log WHERE host=? ORDER BY id DESC LIMIT 200', @host.oid).to_a
    end
    haml :credential_log
  end
end
