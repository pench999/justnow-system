# -*- coding: utf-8 -*-

module Yabitz::Plugin
  module DockerConfig
    def self.plugin_type
      :config
    end

    def self.plugin_priority
      ENV['YABITZ_DOCKER_CONFIG'] == '1' ? 100 : 0
    end

    DB_PARAMS = [:server, :user, :pass, :name, :port, :sock]
    LDAP_PARAMS = [:server, :port, :dn, :pass]

    def self.extra_load_path(env)
      []
    end

    def self.dbparams(env)
      values = {
        :server => ENV.fetch('YABITZ_DB_HOST', 'db'),
        :user => ENV.fetch('YABITZ_DB_USER', 'yabitz'),
        :pass => ENV['YABITZ_DB_PASSWORD'],
        :name => ENV.fetch('YABITZ_DB_NAME', 'yabitz'),
        :port => ENV.fetch('YABITZ_DB_PORT', '3306').to_i,
        :sock => nil,
      }
      DB_PARAMS.map{|sym| values[sym]}
    end

    def self.ldapparams(env)
      return [] unless ENV['YABITZ_LDAP_HOST'] && ENV['YABITZ_LDAP_DN']

      values = {
        :server => ENV['YABITZ_LDAP_HOST'],
        :port => ENV.fetch('YABITZ_LDAP_PORT', '389').to_i,
        :dn => ENV['YABITZ_LDAP_DN'],
        :pass => ENV['YABITZ_LDAP_PASSWORD'],
      }
      LDAP_PARAMS.map{|sym| values[sym]}
    end
  end
end
