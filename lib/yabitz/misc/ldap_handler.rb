# -*- coding: utf-8 -*-

require 'net/ldap'
module Yabitz; end

module Yabitz::LDAPHandler
  def self.nodes(dn)
    dn.split(',').map{|ent| ent.split('=')}
  end

  def self.connection(server, port)
    Net::LDAP.new(:host => server, :port => port.to_i)
  end

  def self.try_auth(dn, pass)
    server, port, sys_username, sys_password = Yabitz.config.ldapparams()
    conn = Net::LDAP.new(
      :host => server,
      :port => port.to_i,
      :auth => {:method => :simple, :username => dn, :password => pass}
    )
    conn.bind
  end

  def self.search(search_path_list, filter, &block)
    server, port, username, password = Yabitz.config.ldapparams()
    conn = Net::LDAP.new(
      :host => server,
      :port => port.to_i,
      :auth => {:method => :simple, :username => username, :password => password}
    )
    return [] unless conn.bind

    results = []
    search_path_list.each do |search_path|
      result_set = conn.search(:base => search_path, :filter => Net::LDAP::Filter.construct(filter))
      result_set.each do |raw_ent|
        ent = self.entry_to_hash(raw_ent)
        if not block_given? or yield ent
          results.push(ent)
        end
      end
    end
    results
  end

  def self.get_child_nodes(conn, search_dn)
    now_top_ou = self.nodes(search_dn).first.last
    ou_list = self.search_onelevel(conn, search_dn, '(ou=*)').select{|ent| ent['name'].first != now_top_ou}
    cn_list = self.search_onelevel(conn, search_dn, '(cn=*)')
    [ou_list, cn_list]
  end

  def self.find_cn_recursive(conn, path_dn, get_multi=false, lambda=Proc.new)
    oulist, cnlist = self.get_child_nodes(conn, path_dn)
    hit_set = []
    cnlist.each do |ent|
      if lambda.call(ent)
        return ent unless get_multi
        hit_set.push(ent)
      end
    end
    oulist.each do |ent|
      result = self.find_cn_recursive(conn, "ou=#{ent['name'].first.force_encoding('utf-8')}," + path_dn, get_multi, lambda)
      if not get_multi and result
        return result
      end
      hit_set.push(*result)
    end
    return nil unless get_multi
    hit_set
  end

  def self.find_by(search_paths, lambda=Proc.new)
    server, port, checker_name, checker_pass = Yabitz.config.ldapparams()
    conn = Net::LDAP.new(
      :host => server,
      :port => port.to_i,
      :auth => {:method => :simple, :username => checker_name, :password => checker_pass}
    )
    return [] unless conn.bind

    entries = []
    search_paths.each do |path_dn|
      ents = self.find_cn_recursive(conn, path_dn, true, lambda)
      entries.push(*ents) if ents.size > 0
    end
    entries
  end

  def self.find_all_entries(search_paths)
    self.find_by(search_paths){|ent| ent}
  end

  def self.find_serial_by(search_paths, list, lambda=Proc.new)
    entries = self.find_all_entries(search_paths)
    list.map{|i| entries.select{|ent| lambda.call(i,ent)}.first}.compact
  end

  def self.search_onelevel(conn, search_dn, filter)
    conn.search(
      :base => search_dn,
      :scope => Net::LDAP::SearchScope_SingleLevel,
      :filter => Net::LDAP::Filter.construct(filter)
    ).map{|ent| self.entry_to_hash(ent)}
  end

  def self.entry_to_hash(entry)
    result = {'dn' => [entry.dn]}
    entry.each do |attr, values|
      normalized = values.map{|v| v.to_s.force_encoding('utf-8')}
      key = attr.to_s
      result[key] = normalized
      result[key.downcase] = normalized
      result[key.upcase] = normalized
    end
    result
  end
end
