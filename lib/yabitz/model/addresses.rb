# -*- coding: utf-8 -*-

require_relative '../misc/init'

require 'stratum'
require_relative '../misc/validator'
require_relative '../misc/racktype'

require 'ipaddr'
require 'cgi'

module Yabitz
  module Model
    class ServiceURL < Stratum::Model
      table :serviceurls
      field :url, :string, :validator => 'check_url', :normalizer => 'normalize_url'
      fieldex :url, "httpもしくはhttpsではじまる、正常なドメイン名のURLを入力してください"
      field :services, :reflist, :model => 'Yabitz::Model::Service', :empty => :ok, :serialize => :oid

      def <=>(other)
        self.url <=> other.url
      end

      def to_s
        self.url
      end

      def check_url(url)
        url =~ /\Ahttps?:\/\/[a-z0-9][-a-z0-9]*\.[a-z0-9][-.a-z0-9]*(:[0-9]+)?.*/ and url.size < 1024
      end

      def self.normalize_url(url)
        parts = url.split('/')
        unless parts[0].downcase == 'http:' or parts[0].downcase == 'https:'
          parts.unshift('') unless parts[0] == ''
          parts.unshift('http:')
        end
        parts[0].downcase!
        parts[2].downcase!
        parts.join('/')
      end
    end

    class DNSName < Stratum::Model
      table :dnsnames
      field :dnsname, :string, :validator => 'check_hostname'
      fieldex :dnsname, "DNS名は少なくともひとつのドットを含み、アンダースコアは使えません"
      field :hosts, :reflist, :model => 'Yabitz::Model::Host', :empty => :ok, :serialize => :oid

      def <=>(other)
        selfparts = self.dnsname.split('.').reverse
        if selfparts[0] == 'xen'
          selfparts.push(selfparts.shift)
        end
        otherparts = other.dnsname.split('.').reverse
        if otherparts[0] == 'xen'
          otherparts.push(otherparts.shift)
        end

        (0...selfparts.size).each do |i|
          return 1 if otherparts[i].nil?
          val = selfparts[i] <=> otherparts[i]
          return val if val != 0
        end
        if selfparts.size < otherparts.size
          return -1
        end
        0
      end

      def to_s
        self.dnsname
      end

      def check_hostname(str)
        Yabitz::Validator.hostname(str)
      end
    end
    
    class DummyIPAddress
      DEFAULT_SCOPE = 'default'
      attr_reader :address, :version, :scope
      def oid ; nil; end
      def id ; nil; end
      def hosts ; []; end
      def hosts_by_id ; []; end
      def holder ; false ; end
      def holder? ; false ; end
      def notes ; "" ; end
      def scope ; @scope || DEFAULT_SCOPE ; end
      def <=>(other)
        if self.version != other.version
          return self.version <=> other.version
        end
        scope_cmp = self.scope.to_s <=> other.scope.to_s
        return scope_cmp unless scope_cmp == 0
        IPAddr.new(self.address) <=> IPAddr.new(other.address)
      end
      def to_s ; scope == DEFAULT_SCOPE ? self.address : scope + ':' + self.address ; end
      def to_addr ; IPAddr.new(self.address) ; end

      def set(str)
        result = Yabitz::Validator.ipaddress(str)
        case result
        when "v4"
          @address = str
          @version = ::Yabitz::Model::IPAddress::IPv4
        when "v6"
          @address = str
          @version = ::Yabitz::Model::IPAddress::IPv6
        else
          raise Stratum::FieldValidationError.new("invalid ipaddress #{str}", ::Yabitz::Model::IPAddress.class, :address)
        end
      end

      def initialize(addr, scope=DEFAULT_SCOPE)
        @scope = scope.to_s.empty? ? DEFAULT_SCOPE : scope.to_s
        self.set(addr)
      end

      def quoted_address ; ::Yabitz::Model::IPAddress.quote_key(self.address, self.scope) ; end
    end

    class IPAddress < Stratum::Model
      IPv4 = 'IPv4'
      IPv6 = 'IPv6'
      IP_VERSIONS = [IPv4, IPv6].freeze
      
      table :ipaddresses
      DEFAULT_SCOPE = 'default'

      field :address, :string, :validator => 'check_ipaddress'
      field :scope, :string, :length => 64, :default => DEFAULT_SCOPE
      field :version, :string, :selector => IP_VERSIONS, :default => IPv4
      field :hosts, :reflist, :model => 'Yabitz::Model::Host', :empty => :ok, :serialize => :oid
      field :holder, :bool, :default => false
      field :notes, :string, :length => 1024, :empty => :ok

      def <=>(other)
        if self.version != other.version
          return self.version <=> other.version
        end
        scope_cmp = self.scope.to_s <=> other.scope.to_s
        return scope_cmp unless scope_cmp == 0
        IPAddr.new(self.address) <=> IPAddr.new(other.address)
      end

      def to_s
        self.class.display_address(self.address, self.scope)
      end

      def to_addr
        IPAddr.new(self.address)
      end

      def quoted_address
        self.class.quote_key(self.address, self.scope)
      end

      def self.dequote(str)
        str.tr('_', '.')
      end

      def self.normalize_scope(scope)
        value = scope.to_s.strip
        value.empty? ? DEFAULT_SCOPE : value
      end

      def self.parse_scoped_address(value, fallback_scope=DEFAULT_SCOPE)
        raw = value.to_s.strip
        if raw =~ /\A([A-Za-z0-9_.-]+):(.+)\Z/ and Yabitz::Validator.ipaddress($2)
          [normalize_scope($1), $2]
        else
          [normalize_scope(fallback_scope), raw]
        end
      end

      def self.display_address(address, scope=DEFAULT_SCOPE)
        normalized_scope = normalize_scope(scope)
        normalized_scope == DEFAULT_SCOPE ? address.to_s : normalized_scope + ':' + address.to_s
      end

      def self.quote_key(address, scope=DEFAULT_SCOPE)
        normalized_scope = normalize_scope(scope)
        quoted_address = address.to_s.tr('.', '_')
        return quoted_address if normalized_scope == DEFAULT_SCOPE

        's_' + CGI.escape(normalized_scope) + '__' + quoted_address
      end

      def self.dequote_key(key, fallback_scope=DEFAULT_SCOPE)
        if key.to_s =~ /\As_(.+)__([0-9_]+)\Z/
          [normalize_scope(CGI.unescape($1)), dequote($2)]
        else
          [normalize_scope(fallback_scope), dequote(key)]
        end
      end

      def self.query_or_create(*args)
        attrs = args.first
        if attrs.kind_of?(Hash) and attrs[:address]
          attrs = attrs.dup
          scope, address = parse_scoped_address(attrs[:address], attrs[:scope])
          attrs[:address] = address
          attrs[:scope] = scope
          args[0] = attrs
        end
        super
      end

      def set(str)
        result = Yabitz::Validator.ipaddress(str)
        case result
        when "v4"
          self.scope = self.class.normalize_scope(self.scope)
          self.address = str
          self.version = IPv4
        when "v6"
          self.scope = self.class.normalize_scope(self.scope)
          self.address = str
          self.version = IPv6
        else
          raise Stratum::FieldValidationError.new("invalid ipaddress #{str}", self.class, :address)
        end
      end

      def check_ipaddress(str)
        Yabitz::Validator.ipaddress(str)
      end
    end
    
    class IPSegment < Stratum::Model
      AREA_LOCAL = 'local'
      AREA_GLOBAL = 'global'
      IP_SEGMENT_AREAS = [AREA_LOCAL, AREA_GLOBAL].freeze

      table :ipsegments
      field :address, :string, :validator => 'check_ipaddress'
      field :scope, :string, :length => 64, :default => IPAddress::DEFAULT_SCOPE
      field :netmask, :string, :validator => 'check_netmask'
      field :version, :string, :selector => IPAddress::IP_VERSIONS, :default => IPAddress::IPv4
      field :area, :string, :selector => IP_SEGMENT_AREAS, :default => AREA_LOCAL
      field :ongoing, :bool, :default => true
      field :notes, :string, :length => 1024, :empty => :ok

      def <=>(other)
        if self.version != other.version
          return self.version <=> other.version
        end
        scope_cmp = self.scope.to_s <=> other.scope.to_s
        return scope_cmp unless scope_cmp == 0
        IPAddr.new(self.address) <=> IPAddr.new(other.address)
      end

      def to_s
        IPAddress.display_address(self.address, self.scope) + '/' + self.netmask
      end

      def to_addr
        IPAddr.new(self.address + '/' + self.netmask)
      end

      def set(addr, mask)
        result = Yabitz::Validator.ipaddress(addr)
        case result
        when "v4"
          self.scope = IPAddress.normalize_scope(self.scope)
          self.address = addr
          self.netmask = mask
          self.version = IPAddress::IPv4
          if self.netmask.to_i > 32
            raise Stratum::FieldValidationError.new("invalid ipaddress #{addr}/#{mask}", self.class, :address)
          end
        when "v6"
          self.scope = IPAddress.normalize_scope(self.scope)
          self.address = addr
          self.netmask = mask
          self.version = IPAddress::IPv6
        else
          raise Stratum::FieldValidationError.new("invalid ipaddress #{addr}/#{mask}", self.class, :address)
        end
      end

      def check_ipaddress(str)
        Yabitz::Validator.ipaddress(str)
      end

      def check_netmask(str)
        str =~ /\A\d{1,3}\Z/ and (str.to_i.to_s == str) and str.to_i >= 0 and str.to_i <= 128 # for IPv6
      end
    end
    
    class RackUnit < Stratum::Model
      table :rackunits
      field :rackunit, :string, :validator => 'check_rackunit'
      fieldex :rackunit, "次のような形式が定義されています: " + Yabitz::RackTypes.list.map(&:rackunit_label_example).join(", ")
      field :dividing, :string, :selector => Yabitz::RackTypes::DIVIDINGS, :default => Yabitz::RackTypes::DIVIDING_FULL
      field :rack, :ref, :model => 'Yabitz::Model::Rack'
      field :hosts, :reflist, :model => 'Yabitz::Model::Host', :empty => :ok, :serialize => :oid
      field :holder, :bool, :default => false
      field :notes, :string, :length => 1024, :empty => :ok

      def self.query_or_create(*args)
        attrs = args.first
        if attrs.kind_of?(Hash) and attrs[:rackunit] and !attrs[:rack]
          racktype = Yabitz::RackTypes.search_by_unit(attrs[:rackunit])
          if racktype
            attrs = attrs.dup
            attrs[:rack] = Yabitz::Model::Rack.query_or_create(
              :label => racktype.rack_label(attrs[:rackunit]),
              :type => racktype.name,
              :datacenter => racktype.datacenter
            )
            args[0] = attrs
          end
        end

        obj = super

        unless obj.rack
          if Stratum.current_operator
            if obj.saved?
              obj.rack_set and obj.save
            else
              obj.rack_set
            end
          end
        end
        obj
      end

      def <=>(other)
        self.rackunit <=> other.rackunit
      end

      def to_s
        self.rackunit
      end

      def rack_set
        racktype = Yabitz::RackTypes.search_by_unit(self.rackunit)
        rack = Yabitz::Model::Rack.query_or_create(:label => racktype.rack_label(self.rackunit), :type => racktype.name, :datacenter => racktype.datacenter)
        unless rack.type and rack.datacenter
          rack.type = racktype.name
          rack.datacenter = racktype.datacenter
          rack.save
        end
        self.rack = rack
      end

      def check_rackunit(str)
        Yabitz::RackTypes.search_by_unit(str)
      end
    end
    

    class RackGroupLabel < Stratum::Model
      table :rack_group_labels
      field :prefix, :string, :length => 16
      field :display_name, :string, :length => 64, :empty => :ok

      def self.label_map
        self.all.inject({}){|map, label| map.update(label.prefix => label.display_name)}
      end

      def self.display_name_for(prefix, labels=nil)
        labels ||= self.label_map
        value = labels[prefix]
        value.to_s.empty? ? prefix : value
      end
    end

    class Rack < Stratum::Model
      table :racks
      field :label, :string, :validator => 'check_racklabel'
      fieldex :label, "次のような形式が定義されています: " + Yabitz::RackTypes.list.map(&:rack_label_example).join(", ")
      field :type, :string, :selector => Yabitz::RackTypes.list.map(&:name), :default => Yabitz::RackTypes.default.name
      field :datacenter, :string, :selector => Yabitz::RackTypes.list.map(&:datacenter), :default => Yabitz::RackTypes.default.datacenter
      field :ongoing, :bool, :default => true
      field :notes, :string, :length => 1024, :empty => :ok

      def <=>(other)
        if (self.datacenter <=> other.datacenter) != 0
          self.datacenter <=> other.datacenter
        elsif (self.type <=> other.type) != 0
          self.type <=> other.type
        else
          self.label <=> other.label
        end
      end

      def to_s
        self.label
      end

      def check_racklabel(str)
        Yabitz::RackTypes.search(str)
      end
    end
  end
end
