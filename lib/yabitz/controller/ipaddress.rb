# -*- coding: utf-8 -*-

require 'sinatra/base'

require 'haml'

class Yabitz::Application < Sinatra::Base
  get %r!/ybz/ipaddress/list/network/([:._0-9]+\d/\d+)(\.json|\.csv)?! do |network_str, ctype|
    authorized?
    @network = IPAddr.new(Yabitz::Model::IPAddress.dequote(network_str))
    @scope = Yabitz::Model::IPAddress.normalize_scope(request.params['scope'])
    @ips = Yabitz::Model::IPAddress.choose(:address, :scope){|v, scope| scope == @scope and @network.include?(IPAddr.new(v))}
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @ips.to_json
    when '.csv'
      csv_attachment('justnow-ipaddresses-network.csv')
      @ips.sort!
      build_csv([
        ['ADDRESS',  Proc.new{|ip| ip.address }],
        ['SCOPE',    Proc.new{|ip| ip.scope }],
        ['VERSION',  Proc.new{|ip| ip.version }],
        ['HOSTS',    Proc.new{|ip| ip.hosts }],
        ['HOLDER',   Proc.new{|ip| ip.holder }],
        ['NOTES',    Proc.new{|ip| ip.notes }]
      ], @ips)
    else
      iptable = Hash[*(@ips.map{|ip| [ip.address, ip]}.flatten)]
      @network.to_range.each{|ip| @ips.push(Yabitz::Model::DummyIPAddress.new(ip.to_s, @scope)) unless iptable[ip.to_s]}

      @page_title = "ネットワーク内のIPアドレス: #{Yabitz::Model::IPAddress.display_address(network_str, @scope)}"
      @ips.sort!
      haml :ipaddress_list
    end
  end

  get %r!/ybz/ipaddress/((?:s_[^/]+__)?\d+[._]\d+[._]\d+[._]\d+)(\.tr\.ajax|\.ajax|\.json|\.txt)?! do |ipaddr, ctype|
    authorized?
    scope, address = Yabitz::Model::IPAddress.dequote_key(ipaddr, request.params['scope'])
    @ip = Yabitz::Model::IPAddress.query(:address => address, :scope => scope, :unique => true)
    unless @ip
      @ip = Yabitz::Model::DummyIPAddress.new(address, scope)
    end

    case ctype
    when '.json'
      pass unless @ip.oid

      response['Content-Type'] = 'application/json'
      @ip.to_json
    when '.txt'
      pass unless @ip.oid
      pass unless @ip.hosts.first
      response['Content-Type'] = 'text/plain'
      @ip.hosts.first.display_name
    when '.tr.ajax'
      haml :ipaddress, :layout => false, :locals => {:ipaddress => @ip}
    when '.ajax'
      haml :ipaddress_parts, :layout => false
    else
      @page_title = "IPアドレス: #{@ip.to_s}"
      require 'ipaddr'
      @ips = [@ip]
      haml :ipaddress_list
    end
  end

  get %r!/ybz/ipaddress/holder(\.json|\.csv)?! do |ctype|
    authorized?
    @ips = Yabitz::Model::IPAddress.query(:holder => true)
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @ips.to_json
    when '.csv'
      csv_attachment('justnow-ipaddresses-holder.csv')
      @ips.sort!
      build_csv([
        ['ADDRESS',  Proc.new{|ip| ip.address }],
        ['SCOPE',    Proc.new{|ip| ip.scope }],
        ['VERSION',  Proc.new{|ip| ip.version }],
        ['HOSTS',    Proc.new{|ip| ip.hosts }],
        ['HOLDER',   Proc.new{|ip| ip.holder }],
        ['NOTES',    Proc.new{|ip| ip.notes }]
      ], @ips)
    else
      @page_title = "予約済みIPアドレス一覧"
      @ips.sort!
      haml :ipaddress_list
    end
  end

  get %r!/ybz/ipaddress/global(\.json|\.csv)?! do |ctype|
    authorized?
    cls_a = IPAddr.new("10.0.0.0/8")
    cls_b = IPAddr.new("172.16.0.0/12")
    cls_c = IPAddr.new("192.168.0.0/16")
    @ips = Yabitz::Model::IPAddress.choose(:address){|v| ip = IPAddr.new(v); not cls_a.include?(ip) and not cls_b.include?(ip) and not cls_c.include?(ip)}
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @ips.to_json
    when '.csv'
      csv_attachment('justnow-ipaddresses-global.csv')
      @ips.sort!
      build_csv([
        ['ADDRESS',  Proc.new{|ip| ip.address }],
        ['SCOPE',    Proc.new{|ip| ip.scope }],
        ['VERSION',  Proc.new{|ip| ip.version }],
        ['HOSTS',    Proc.new{|ip| ip.hosts }],
        ['HOLDER',   Proc.new{|ip| ip.holder }],
        ['NOTES',    Proc.new{|ip| ip.notes }]
      ], @ips)
    else
      @page_title = "グローバルIPアドレス一覧"
      @ips.sort!
      haml :ipaddress_list
    end
  end

  get %r!/ybz/ipaddress/list(\.json|\.csv)?! do |ctype|
    authorized?
    @ips = Yabitz::Model::IPAddress.all
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @ips.to_json
    when '.csv'
      csv_attachment('justnow-ipaddresses.csv')
      @ips.sort!
      build_csv([
        ['ADDRESS',  Proc.new{|ip| ip.address }],
        ['SCOPE',    Proc.new{|ip| ip.scope }],
        ['VERSION',  Proc.new{|ip| ip.version }],
        ['HOSTS',    Proc.new{|ip| ip.hosts }],
        ['HOLDER',   Proc.new{|ip| ip.holder }],
        ['NOTES',    Proc.new{|ip| ip.notes }]
      ], @ips)
    else
      raise NotImplementedError
    end
  end

  post %r!/ybz/ipaddress/((?:s_[^/]+__)?\d+_\d+_\d+_\d+)! do |ipaddr|
    admin_protected!

    Stratum.transaction do |conn|
      scope, address = Yabitz::Model::IPAddress.dequote_key(ipaddr, request.params['scope'])
      ip = Yabitz::Model::IPAddress.query_or_create(:address => address, :scope => scope)
      if request.params['target_id'] and (not request.params['target_id'].empty?) and request.params['target_id'].to_i != ip.id
        raise Stratum::ConcurrentUpdateError
      end

      case request.params['field']
      when 'holder'
        unless request.params['operation'] == 'toggle'
          halt HTTP_STATUS_NOT_ACCEPTABLE, "not allowed operation"
        end
        ip.holder = (not ip.holder)
      when 'notes'
        unless request.params['operation'] = 'edit'
          halt HTTP_STATUS_NOT_ACCEPTABLE, "not allowed operation"
        end
        ip.notes = request.params['value']
      else
        halt HTTP_STATUS_NOT_ACCEPTABLE, "not allowed operation"
      end
      ip.save unless ip.saved?
    end
    "ok"
  end

  get '/ybz/ipaddress/suggest.json' do
    authorized?
    scope, raw_ip = Yabitz::Model::IPAddress.parse_scoped_address(request.params['ip'], request.params['scope'])
    ip = raw_ip ? IPAddr.new(raw_ip) : nil
    pass unless ip # object not found -> HTTP 404

    exclude = request.params['ex']
    ipsuggest = Yabitz::Suggest::IPAddress.new(ip)
    localip = ipsuggest.suggest(exclude)

    response['Content-Type'] = 'application/json'
    { :localip => localip }.to_json
  end
end
