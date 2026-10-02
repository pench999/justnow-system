require 'net/http'
require 'cgi'
require 'json'
require_relative '../../lib/yabitz/misc/init'
require_relative '../../lib/yabitz/misc/credential_store'

def check(value, message)
  raise message unless value
end

cookie = nil
request = lambda do |path, fields=nil, user='batchmaker'|
  uri = URI("http://127.0.0.1:9292#{path}")
  req = fields ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
  req['X-Remote-User'] = user
  req['X-Remote-Name'] = user
  req['Cookie'] = cookie if cookie && user == 'batchmaker'
  req.set_form_data(fields) if fields
  response = Net::HTTP.start(uri.host, uri.port) {|http| http.request(req)}
  cookie = response['set-cookie'].split(';').first if response['set-cookie'] && user == 'batchmaker'
  response
end

host_ids = Stratum.conn {|c| c.query("SELECT oid FROM hosts WHERE head='1' AND removed='0' LIMIT 2").to_a}
host = Yabitz::Model::Host.get(host_ids.fetch(0)['oid'])
raise 'No host available for test' unless host
base = "/ybz/host/#{host.oid}"
detail = request.call("#{base}.ajax")
check(detail.code == '200', 'detail failed')
token = detail.body[/name=['"]csrf['"][^>]*value=['"]([^'"]+)/, 1]
check(token, 'CSRF token missing')
id = SecureRandom.hex(16)
label = "credential-http-test-#{id}?"
password = "test-only-#{SecureRandom.hex(12)}?"

begin
  fields = {'csrf'=>token, 'label'=>label, 'username'=>'test?user', 'password'=>password}
  check(request.call("#{base}/credential/save", fields.merge('csrf'=>'wrong')).code == '403', 'CSRF failed')
  check(request.call("#{base}/credential/save", fields).code == '200', 'create failed')
  row = Stratum.conn {|c| Yabitz::CredentialStore::SafeConnection.new(c).query('SELECT * FROM host_credentials WHERE host=? AND label=?', host.oid, label).first}
  check(row, 'row missing')
  id = row['credential_id']
  check(!row['ciphertext'].include?(password), 'plaintext stored')
  check(Yabitz::CredentialStore.decrypt(row) == password, 'decryption failed')
  detail = request.call("#{base}.ajax")
  check(!detail.body.include?(password), 'detail contains password')
  check(request.call("#{base}/credential/#{id}/reveal", {'csrf'=>token}, 'credential-audit-test-user').code == '403', 'non-admin allowed')
  revealed = request.call("#{base}/credential/#{id}/reveal", {'csrf'=>token})
  check(revealed.code == '200' && JSON.parse(revealed.body)['password'] == password, 'reveal failed')
  check(revealed['cache-control'] == 'no-store', 'secret response cached')
  check(request.call("#{base}/credential/#{id}/reveal", {'csrf'=>token,'operation'=>'copy'}).code == '200', 'copy retrieval failed')
  check(request.call("#{base}/credential/save", fields.merge('credential_id'=>id,'password'=>'','username'=>'updated-user')).code == '200', 'update failed')
  check(JSON.parse(request.call("#{base}/credential/#{id}/reveal", {'csrf'=>token}).body)['password'] == password, 'empty update changed password')
  other = host_ids[1] && Yabitz::Model::Host.get(host_ids[1]['oid'])
  if other
    check(request.call("/ybz/host/#{other.oid}/credential/#{id}/reveal", {'csrf'=>token}).code == '404', 'cross-host retrieval allowed')
  end
  check(request.call("#{base}/credential-log").code == '200', 'audit page failed')
  check(request.call("#{base}/credential/#{id}/delete", {'csrf'=>token}).code == '200', 'delete failed')
  check(request.call("#{base}/credential/#{id}/reveal", {'csrf'=>token}).code == '404', 'deleted secret accessible')
  logs = Stratum.conn {|c| Yabitz::CredentialStore::SafeConnection.new(c).query('SELECT action,result FROM credential_access_log WHERE credential_id=?', id)}
  %w[create reveal copy update delete].each {|action| check(logs.any? {|entry| entry['action']==action && entry['result']=='success'}, "missing #{action} audit")}
  check(logs.any? {|entry| entry['result']=='denied'}, 'denial not audited')
  puts 'HTTP credential checks passed: CSRF, encryption, no plaintext HTML, admin access, host isolation, update/delete, audit.'
ensure
  Stratum.conn do |c|
    safe = Yabitz::CredentialStore::SafeConnection.new(c)
    safe.query('DELETE FROM host_credentials WHERE host=? AND label=?', host.oid, label)
  end
end
