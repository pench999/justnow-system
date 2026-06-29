# -*- coding: utf-8 -*-

require 'sinatra/base'

require 'haml'

class Yabitz::Application < Sinatra::Base
  IPSEGMENT_USAGE_CACHE_TTL = 60 unless const_defined?(:IPSEGMENT_USAGE_CACHE_TTL)
  @@used_ip_values_cache = nil

  def used_ip_values_by_version
    now = Time.now.to_f
    if @@used_ip_values_cache and now - @@used_ip_values_cache[:built_at] < IPSEGMENT_USAGE_CACHE_TTL
      return @@used_ip_values_cache[:values]
    end

    values_by_version = Hash.new{|hash, key| hash[key] = []}
    seen = {}
    host_sql = <<~SQL
      SELECT address, version
      FROM #{Yabitz::Model::IPAddress.tablename}
      WHERE head=? AND removed=?
        AND hosts > ''
    SQL
    holder_sql = <<~SQL
      SELECT address, version
      FROM #{Yabitz::Model::IPAddress.tablename}
      WHERE head=? AND removed=?
        AND holder=?
    SQL

    Stratum.conn do |conn|
      [conn.query(host_sql, Stratum::Model::BOOL_TRUE, Stratum::Model::BOOL_FALSE),
       conn.query(holder_sql, Stratum::Model::BOOL_TRUE, Stratum::Model::BOOL_FALSE, Stratum::Model::BOOL_TRUE)].each do |rows|
        rows.each do |row|
          key = row['version'].to_s + ':' + row['address'].to_s
          next if seen[key]

          begin
            values_by_version[row['version']].push(IPAddr.new(row['address']).to_i)
            seen[key] = true
          rescue ArgumentError
            next
          end
        end
      end
    end
    values_by_version.each_value(&:sort!)
    @@used_ip_values_cache = {:built_at => now, :values => values_by_version}
    values_by_version
  end

  def sort_ipsegments(ipsegments)
    ipsegments.sort_by!{|seg| [seg.version, seg.to_addr.to_i, seg.netmask.to_i]}
  end

  def lower_bound(values, target)
    left = 0
    right = values.length
    while left < right
      mid = (left + right) / 2
      if values[mid] < target
        left = mid + 1
      else
        right = mid
      end
    end
    left
  end

  def upper_bound(values, target)
    left = 0
    right = values.length
    while left < right
      mid = (left + right) / 2
      if values[mid] <= target
        left = mid + 1
      else
        right = mid
      end
    end
    left
  end

  def used_ip_count_in_network(values, network)
    return 0 if values.empty?

    range = network.to_range
    upper_bound(values, range.last.to_i) - lower_bound(values, range.first.to_i)
  end

  def build_segment_used_ip_count_map(ipsegments)
    values_by_version = used_ip_values_by_version
    ipsegments.each_with_object({}) do |seg, result|
      network = seg.to_addr
      result[seg.to_s] = used_ip_count_in_network(values_by_version[seg.version], network)
    end
  end

  get %r!/ybz/ipsegment/list/(local|global)(\.json)?! do |net, ctype|
    authorized?
    area = (net == 'local' ? Yabitz::Model::IPSegment::AREA_LOCAL : Yabitz::Model::IPSegment::AREA_GLOBAL)
    @ipsegments = Yabitz::Model::IPSegment.query(:area => area)
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @ipsegments.to_json
    else
      @segment_used_ip_count_map = build_segment_used_ip_count_map(@ipsegments)
      @page_title = "IPセグメントリスト(#{net} network)"
      sort_ipsegments(@ipsegments)
      haml :ipsegment_list
    end
  end

  get %r!/ybz/ipsegment/list/network/([:.0-9]+\d/\d+)(\.json)?! do |network_str, ctype|
    authorized?
    network = IPAddr.new(network_str)
    @ipsegments = Yabitz::Model::IPSegment.choose(:address){|v| network.include?(IPAddr.new(v))}
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @ipsegments.to_json
    else
      @segment_used_ip_count_map = build_segment_used_ip_count_map(@ipsegments)
      @page_title = "IPセグメント (範囲: #{network_str})"
      sort_ipsegments(@ipsegments)
      haml :ipsegment_list
    end
  end

  get %r!/ybz/ipsegment/(\d+)(\.tr\.ajax|\.ajax|\.json)?! do |oid, ctype|
    authorized?
    @ipseg = Yabitz::Model::IPSegment.get(oid.to_i)
    pass unless @ipseg
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @ipseg.to_json
    when '.tr.ajax'
      network = IPAddr.new(@ipseg.address + '/' + @ipseg.netmask)
      @ips = Yabitz::Model::IPAddress.choose(:hosts, :holder, :address, :lowlevel => true){|hosts,holder,address|
        ((not hosts.nil? and not hosts.empty?) or holder == Stratum::Model::BOOL_TRUE) and network.include?(IPAddr.new(address))
      }
      @segment_used_ip_count_map = {@ipseg.to_s => @ips.size}
      haml :ipsegment, :layout => false, :locals => {:ipsegment => @ipseg}
    when '.ajax'
      haml :ipsegment_parts, :layout => false
    else
      @network = @ipseg.to_addr
      @ips = Yabitz::Model::IPAddress.choose(:address){|v| @network.include?(IPAddr.new(v))}
      iptable = Hash[*(@ips.map{|ip| [ip.address, ip]}.flatten)]
      @network.to_range.each{|ip| @ips.push(Yabitz::Model::DummyIPAddress.new(ip.to_s)) unless iptable[ip.to_s]}
      
      @page_title = "IPセグメント: #{@ipseg.to_s}"
      @ips.sort!
      haml :ipaddress_list
    end
  end
  # get '/ybz/ipsegment/retrospect/:oid' #TODO

  post '/ybz/ipsegment/:oid' do
    admin_protected!

    Stratum.transaction do |conn|
      seg = Yabitz::Model::IPSegment.get(params[:oid].to_i)
      pass unless seg

      unless request.params['target_id'].to_i == seg.id
        raise Stratum::ConcurrentUpdateError
      end

      case request.params['field']
      when 'ongoing'
        unless request.params['operation'] == 'toggle'
          halt HTTP_STATUS_NOT_ACCEPTABLE, "not allowed operation"
        end
        seg.ongoing = (not seg.ongoing)
      when 'notes'
        unless request.params['operation'] = 'edit'
          halt HTTP_STATUS_NOT_ACCEPTABLE, "not allowed operation"
        end
        seg.notes = request.params['value']
      else
        halt HTTP_STATUS_NOT_ACCEPTABLE, "not allowed operation"
      end
      seg.save unless seg.saved?
    end
    
    "ok"
  end

  post '/ybz/ipsegment/create' do
    admin_protected!

    if Yabitz::Model::IPSegment.query(:address => request.params['address'].strip, :count => true) > 0
      raise Yabitz::DuplicationError
    end
    seg = Yabitz::Model::IPSegment.new
    seg.set(request.params['address'].strip, request.params['mask'].to_i.to_s)

    cls_a = IPAddr.new("10.0.0.0/8")
    cls_b = IPAddr.new("172.16.0.0/12")
    cls_c = IPAddr.new("192.168.0.0/16")
    addr = IPAddr.new(seg.address + '/' + seg.netmask)
    seg.area = if cls_a.include?(addr) or cls_b.include?(addr) or cls_c.include?(addr)
                 Yabitz::Model::IPSegment::AREA_LOCAL
               else
                 Yabitz::Model::IPSegment::AREA_GLOBAL
               end
    seg.ongoing = true
    seg.save
    
    "ok"
  end

  post '/ybz/ipsegment/alter-prepare/:ope/:oid' do
    admin_protected!
    segment = Yabitz::Model::IPSegment.get(params[:oid].to_i)
    unless segment
      halt HTTP_STATUS_CONFLICT, "指定されたIPセグメントが見付かりません<br />ページを更新してやりなおしてください"
    end

    case params[:ope]
    when 'delete_records'
      network = segment.to_addr
      if Yabitz::Model::IPAddress.choose(:address, :hosts, :holder, :lowlevel => true, :oidonly => true){|addr,hosts,holder| not addr.nil? and not addr.empty? and network.include?(IPAddr.new(addr)) and not hosts.nil? and not hosts.empty? and holder == Stratum::Model::BOOL_FALSE}.size > 0
        "セグメント #{segment} において使用中のIPアドレスがありますが、強行しますか？"
      else
        "選択されたセグメント #{segment} を削除して本当にいいですか？"
      end
    else
      pass
    end
  end

  post '/ybz/ipsegment/alter-execute/:ope/:oid' do
    admin_protected!
    segment = Yabitz::Model::IPSegment.get(params[:oid].to_i)
    unless segment
      halt HTTP_STATUS_CONFLICT, "指定されたIPセグメントが見付かりません<br />ページを更新してやりなおしてください"
    end

    case params[:ope]
    when 'delete_records'
      segment_str = segment.to_s
      segment.remove()
      "完了： セグメント #{segment_str} の削除"
    else
      pass
    end
  end
end
