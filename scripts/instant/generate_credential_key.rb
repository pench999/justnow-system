require 'json'
require 'securerandom'
require 'base64'

path = ARGV.fetch(0)
id = Time.now.utc.strftime('key-%Y%m%d')
data = {'active' => id, 'keys' => {id => Base64.strict_encode64(SecureRandom.random_bytes(32))}}
File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0600) {|f| f.write(JSON.pretty_generate(data) + "\n") }
puts 'Key file created. Store a separate protected backup before using real credentials.'
