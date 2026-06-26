source "https://rubygems.org"

ruby '~> 3.3'

gem 'stratum', :path => 'vendor/stratum'
gem 'mysql2', '~> 0.5.6'
gem 'sinatra', '~> 3.2'
gem 'rack', '~> 2.2'
gem 'haml', '~> 5.2'
gem 'sass', '~> 3.7'
gem 'net-ldap', '~> 0.19'
gem 'csv', '~> 3.3'

group :development, :test do
  gem 'rspec', '~> 3.13'
end

group :production do
  gem 'passenger', '~> 6.0'
  gem 'unicorn', '~> 6.1'
end
