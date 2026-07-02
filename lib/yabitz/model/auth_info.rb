# -*- coding: utf-8 -*-

require 'stratum'

require_relative '../misc/init'
require_relative '../misc/logging'
require_relative '../plugin'

module Yabitz
  module Model
    class AuthInfo < Stratum::Model
      PRIV_ROOT = 'ROOT'
      PRIV_ADMIN = 'ADMIN'
      PRIV_LIST = [PRIV_ROOT, PRIV_ADMIN].freeze

      table :auth_info
      field :valid, :bool, :default => true
      field :name, :string, :length => 64
      field :fullname, :string, :length => 64
      field :priv, :string, :selector => PRIV_LIST, :empty => :allowed

      def to_s
        self.name
      end

      def <=>(other)
        self.name <=> other.name
      end

      def self.authenticate(username, password, sourceip='')
        fullname = nil
        Yabitz::Plugin.get(:auth).each do |handler|
          fullname = handler.authenticate(username, password, sourceip)
          break if fullname
        end

        user = nil
        Stratum.transaction do |conn|
          user = self.query(:name => username, :unique => true)
          if fullname and user.nil?
            pre_operator = begin
                             Stratum.current_operator()
                           rescue RuntimeError
                             # ignore
                             nil
                           end
            Stratum.current_operator(self.get_root)
            user = self.new
            user.name = username
            user.fullname = fullname
            user.priv = nil # TODO auto admin-nize to NSG user?
            user.save
            Stratum.current_operator(pre_operator) if pre_operator
            if self.query(:name => username).size != 1
              # new user registration executed twice concurrently
              raise "Transaction Error: login twice?" # rollback
            end
          end
        end

        result = if user and fullname
                   "success"
                 elsif not fullname
                   "failed"
                 else
                   "forbidden"
                 end
        Yabitz::Logging::log_auth(username, result, (user ? user.oid : nil), sourceip)

        return nil unless fullname and user.valid?

        Stratum.current_operator(user)
        user
      end

      def self.authenticate_trusted(username, fullname, sourceip='')
        return nil if username.nil? or username.to_s.empty?
        return nil if fullname.nil? or fullname.to_s.empty?

        user = nil
        Stratum.transaction do |conn|
          user = self.query(:name => username, :unique => true)
          if user.nil?
            pre_operator = begin
                             Stratum.current_operator()
                           rescue RuntimeError
                             nil
                           end
            Stratum.current_operator(self.get_root)
            user = self.new
            user.name = username
            user.fullname = fullname
            user.priv = nil
            user.save
            Stratum.current_operator(pre_operator) if pre_operator
            if self.query(:name => username).size != 1
              raise "Transaction Error: trusted login twice?"
            end
          elsif user.fullname.to_s.empty? and not fullname.to_s.empty?
            user.fullname = fullname
            user.save
          end
        end

        result = (user and user.valid?) ? "trusted" : "forbidden"
        Yabitz::Logging::log_auth(username, result, (user ? user.oid : nil), sourceip)

        return nil unless user and user.valid?

        Stratum.current_operator(user)
        user
      end

      def self.get_root
        self.query(:priv => PRIV_ROOT, :unique => true)
      end

      def self.has_administrator?
        self.query(:priv => PRIV_ADMIN).select{|x| x.name != 'batchmaker'}.size > 0
      end

      def set_admin
        self.priv = PRIV_ADMIN
      end

      def admin?
        self.priv == PRIV_ADMIN
      end

      def root?
        self.priv == PRIV_ROOT
      end
    end
  end
end
