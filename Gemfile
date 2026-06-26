source "https://rubygems.org"

ruby '3.3.0'

gem 'stratum', :path => 'vendor/stratum'
gem 'mysql2', '~> 0.5.6'
gem 'sinatra', '~> 3.2'
gem 'rackup', '~> 2.1'
gem 'haml', '~> 5.2'
gem 'sass', '~> 3.7'
gem 'net-ldap', '~> 0.19'

group :development, :test do
  gem 'rspec', '~> 3.13'
end

group :production do
  gem 'passenger', '~> 6.0'
  gem 'unicorn', '~> 6.1'
end
