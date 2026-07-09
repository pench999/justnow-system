# -*- coding: utf-8 -*-

module Yabitz::Plugin
  module ProxyHeaderAuthenticate
    def self.plugin_type
      :trusted_auth
    end

    def self.plugin_priority
      ENV['YABITZ_TRUSTED_PROXY_AUTH'].to_s.downcase == 'true' ? 100 : 0
    end

    def self.authenticate(env)
      username = env[username_header]
      return nil unless username and username_checker(username)

      fullname = env[fullname_header]
      fullname = username if fullname.nil? or fullname.empty?
      [username, fullname]
    end

    def self.username_header
      rack_header_name(ENV['YABITZ_TRUSTED_PROXY_AUTH_HEADER'] || 'X-Remote-User')
    end

    def self.fullname_header
      rack_header_name(ENV['YABITZ_TRUSTED_PROXY_AUTH_FULLNAME_HEADER'] || 'X-Remote-Name')
    end

    def self.rack_header_name(header)
      name = header.to_s.tr('-', '_').upcase
      return name if name.start_with?('HTTP_') or name == 'REMOTE_USER'
      'HTTP_' + name
    end

    def self.username_checker(name)
      name =~ /\A[-.a-zA-Z0-9_@]+\Z/
    end
  end
end
