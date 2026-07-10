# -*- coding: utf-8 -*-

require 'sinatra/base'
require 'json'
require 'time'
require 'ostruct'
require 'rack/utils'

class Yabitz::Application < Sinatra::Base
  API_V1_HTTP_STATUS_UNAUTHORIZED = 401
  API_V1_MAX_LIMIT = 1000
  API_V1_DEFAULT_LIMIT = 100

  helpers do
    def api_v1_json(payload, status = HTTP_STATUS_OK)
      content_type 'application/json', :charset => 'utf-8'
      status status
      JSON.generate(payload)
    end

    def api_v1_error(status, code, message)
      api_v1_json({:error => {:code => code, :message => message}}, status)
    end

    def api_v1_not_found(resource)
      api_v1_error(HTTP_STATUS_NOT_FOUND, 'not_found', "#{resource} not found")
    end

    def api_v1_configured_tokens
      values = [ENV['YABITZ_API_TOKEN'], ENV['YABITZ_API_TOKENS']].compact.join(',')
      values.split(',').map do |entry|
        name, token = entry.include?(':') ? entry.split(':', 2) : ['api-token', entry]
        [name.strip, token.to_s.strip]
      end.reject {|_, token| token.empty? }
    end

    def api_v1_request_token
      authorization = request.env['HTTP_AUTHORIZATION'].to_s
      bearer = authorization[/\ABearer\s+(.+)\z/i, 1]
      token = bearer || request.env['HTTP_X_JUSTNOW_API_TOKEN']
      token.to_s.strip
    end

    def api_v1_token_authorized?
      token = api_v1_request_token
      return false if token.empty?
      api_v1_configured_tokens.any? do |name, configured_token|
        next false unless token.bytesize == configured_token.bytesize
        if Rack::Utils.secure_compare(token, configured_token)
          @user = OpenStruct.new(:name => name, :fullname => name)
          def @user.admin?; false; end
          @isadmin = false
          true
        else
          false
        end
      end
    end

    def api_v1_protected!
      return if api_v1_token_authorized?
      return if authorized?

      response['WWW-Authenticate'] = %(Basic realm="JustNow System API")
      halt api_v1_error(API_V1_HTTP_STATUS_UNAUTHORIZED, 'unauthorized', 'API authentication required')
    end

    def api_v1_limit
      limit = (params[:limit] || Yabitz::Application::API_V1_DEFAULT_LIMIT).to_i
      limit = Yabitz::Application::API_V1_DEFAULT_LIMIT if limit <= 0
      [limit, Yabitz::Application::API_V1_MAX_LIMIT].min
    end

    def api_v1_offset
      offset = (params[:offset] || 0).to_i
      offset < 0 ? 0 : offset
    end

    def api_v1_collection(items, type, extra_meta = {}, &serializer)
      total = items.size
      offset = api_v1_offset
      limit = api_v1_limit
      data = items[offset, limit] || []
      api_v1_json({
        :data => data.map(&serializer),
        :meta => {
          :type => type,
          :count => data.size,
          :total => total,
          :limit => limit,
          :offset => offset
        }.merge(extra_meta)
      })
    end

    def api_v1_time_param(name, required = false)
      value = params[name]
      halt api_v1_error(HTTP_STATUS_NOT_ACCEPTABLE, 'missing_time', "#{name} is required") if required and (value.nil? or value.empty?)
      return nil if value.nil? or value.empty?
      Time.parse(value)
    rescue ArgumentError
      halt api_v1_error(HTTP_STATUS_NOT_ACCEPTABLE, 'invalid_time', "invalid #{name}")
    end

    def api_v1_since_param
      api_v1_time_param('updated_since') || api_v1_time_param('since')
    end

    def api_v1_until_param
      api_v1_time_param('updated_until') || api_v1_time_param('until')
    end

    def api_v1_include_removed?
      params[:include_removed].to_s == 'true'
    end

    def api_v1_changed_records(model, since_time, until_time = nil)
      histories = model.dig(since_time, until_time).compact
      oids = histories.map {|records| records.first.oid if records and records.first }.compact.uniq
      return [] if oids.empty?
      model.get(oids, :force_all => api_v1_include_removed?)
    end

    def api_v1_change_meta(type, since_time, until_time)
      {
        :changed_since => since_time.strftime('%Y-%m-%d %H:%M:%S'),
        :changed_until => until_time ? until_time.strftime('%Y-%m-%d %H:%M:%S') : nil,
        :include_removed => api_v1_include_removed?
      }
    end

    def api_v1_filter_changed(items, model)
      since_time = api_v1_since_param
      return [items, {}] unless since_time
      until_time = api_v1_until_param
      changed_oids = api_v1_changed_records(model, since_time, until_time).map(&:oid)
      [items.select {|item| changed_oids.include?(item.oid) }, api_v1_change_meta(model.name, since_time, until_time)]
    end

    def api_v1_filter_text(items, keyword, fields)
      return items unless keyword and not keyword.empty?
      words = keyword.split(/[\s　]+/).reject(&:empty?)
      return items if words.empty?
      items.select do |item|
        haystacks = fields.map {|field| field.call(item).to_s.downcase }
        words.all? do |word|
          haystacks.any? {|value| value.include?(word.downcase) }
        end
      end
    end

    def api_v1_ipaddresses_in_network(network)
      oids = []
      seen = {}
      queries = [
        ["SELECT oid,address FROM #{Yabitz::Model::IPAddress.tablename} WHERE head=? AND removed=? AND hosts > ''",
         [Stratum::Model::BOOL_TRUE, Stratum::Model::BOOL_FALSE]],
        ["SELECT oid,address FROM #{Yabitz::Model::IPAddress.tablename} WHERE head=? AND removed=? AND holder=?",
         [Stratum::Model::BOOL_TRUE, Stratum::Model::BOOL_FALSE, Stratum::Model::BOOL_TRUE]],
        ["SELECT oid,address FROM #{Yabitz::Model::IPAddress.tablename} WHERE head=? AND removed=? AND notes > ''",
         [Stratum::Model::BOOL_TRUE, Stratum::Model::BOOL_FALSE]]
      ]

      Stratum.conn do |conn|
        queries.each do |sql, args|
          conn.query(sql, args).each do |row|
            next if seen[row['oid']]

            begin
              next unless network.include?(IPAddr.new(row['address']))
            rescue ArgumentError
              next
            end
            seen[row['oid']] = true
            oids.push(row['oid'])
          end
        end
      end

      Yabitz::Model::IPAddress.get(oids)
    end

    def api_v1_search_words
      params[:q].to_s.split(/[\s　]+/).reject(&:empty?)
    end

    def api_v1_ref(obj, label_method = nil)
      return nil unless obj
      label = label_method ? obj.send(label_method) : obj.to_s
      {:oid => obj.oid, :label => label}
    end

    def api_v1_host(host)
      rackunit = api_v1_ref(host.rackunit, :rackunit)
      if rackunit and host.rackunit.respond_to?(:rack)
        rackunit[:rack] = api_v1_ref(host.rackunit.rack, :label)
      end
      {
        :oid => host.oid,
        :id => host.id,
        :last_modified => host.inserted_at ? host.inserted_at.to_s : nil,
        :removed => host.removed,
        :display_name => host.display_name,
        :status => host.status,
        :type => host.type,
        :service => api_v1_ref(host.service, :name),
        :content => host.service ? api_v1_ref(host.service.content, :name) : nil,
        :parent => api_v1_ref(host.parent),
        :children => host.children.map {|child| api_v1_ref(child) },
        :rackunit => rackunit,
        :hwid => host.hwid,
        :hwinfo => api_v1_ref(host.hwinfo, :name),
        :cpu => host.cpu,
        :memory => host.memory,
        :disk => host.disk,
        :os => host.os,
        :dnsnames => host.dnsnames.map(&:dnsname),
        :localips => host.localips.map(&:address),
        :globalips => host.globalips.map(&:address),
        :virtualips => host.virtualips.map(&:address),
        :alert => host.alert,
        :notes => host.notes
      }
    end

    def api_v1_service(service)
      {
        :oid => service.oid,
        :id => service.id,
        :last_modified => service.inserted_at ? service.inserted_at.to_s : nil,
        :removed => service.removed,
        :name => service.name,
        :content => api_v1_ref(service.content, :name),
        :mladdress => service.mladdress,
        :urls => service.urls.map(&:url),
        :contact => api_v1_ref(service.contact, :label),
        :hypervisors => service.hypervisors,
        :notes => service.notes
      }
    end

    def api_v1_rack(rack)
      {
        :oid => rack.oid,
        :id => rack.id,
        :last_modified => rack.inserted_at ? rack.inserted_at.to_s : nil,
        :removed => rack.removed,
        :label => rack.label,
        :type => rack.type,
        :datacenter => rack.datacenter,
        :ongoing => rack.ongoing,
        :notes => rack.notes
      }
    end

    def api_v1_ipsegment(segment)
      {
        :oid => segment.oid,
        :id => segment.id,
        :last_modified => segment.inserted_at ? segment.inserted_at.to_s : nil,
        :removed => segment.removed,
        :address => segment.address,
        :netmask => segment.netmask,
        :cidr => "#{segment.address}/#{segment.netmask}",
        :version => segment.version,
        :area => segment.area,
        :ongoing => segment.ongoing,
        :notes => segment.notes
      }
    end

    def api_v1_ipaddress(ip)
      {
        :oid => ip.oid,
        :id => ip.id,
        :last_modified => ip.inserted_at ? ip.inserted_at.to_s : nil,
        :removed => ip.removed,
        :address => ip.address,
        :version => ip.version,
        :holder => ip.holder,
        :hosts => ip.hosts.map {|host| api_v1_ref(host) },
        :host_oids => ip.hosts.map(&:oid),
        :notes => ip.notes
      }
    end
  end

  before do
    api_v1_protected! if request.path_info.start_with?('/ybz/api/v1')
  end

  get '/ybz/api/v1' do
    api_v1_json({
      :data => {
        :version => 'v1',
        :readonly => true,
        :resources => ['health', 'hosts', 'services', 'racks', 'ipsegments', 'ipaddresses'],
        :features => ['search', 'changes'],
        :authentication => ['session', 'basic', 'bearer_token']
      }
    })
  end

  get '/ybz/api/v1/health' do
    api_v1_json({
      :data => {
        :status => 'ok',
        :version => 'v1',
        :readonly => true,
        :time => Time.now.iso8601
      }
    })
  end

  get '/ybz/api/v1/hosts' do
    hosts = if params[:q]
              words = api_v1_search_words
              next_hosts = Yabitz::Model::Host.all if words.empty?
              oidset = []
              words.each do |word|
                escaped = Regexp.escape(word)
                result = Yabitz::DetailSearch.search('OR', [
                  ['service', escaped],
                  ['rackunit', escaped],
                  ['hwid', escaped],
                  ['dnsname', escaped],
                  ['ipaddress', escaped],
                  ['hwinfo', escaped],
                  ['os', escaped],
                  ['tag', escaped],
                  ['status', escaped]
                ], 'AND', [])
                word_oids = result.map(&:oid)
                oidset = oidset.empty? ? word_oids : (oidset & word_oids)
              end
              next_hosts || Yabitz::Model::Host.get(oidset)
            elsif params[:service_oid]
              service = Yabitz::Model::Service.get(params[:service_oid].to_i)
              halt api_v1_not_found('service') unless service
              Yabitz::Model::Host.query(:service => service)
            elsif params[:status]
              status_name = params[:status].upcase
              halt api_v1_error(HTTP_STATUS_NOT_ACCEPTABLE, 'invalid_status', 'invalid host status') unless Yabitz::Model::Host::STATUS_LIST.include?(status_name)
              Yabitz::Model::Host.query(:status => status_name)
            else
              Yabitz::Model::Host.all
            end
    Stratum.preload(hosts, Yabitz::Model::Host)
    hosts, change_meta = api_v1_filter_changed(hosts, Yabitz::Model::Host)
    api_v1_collection(hosts.sort, 'hosts', change_meta) {|host| api_v1_host(host) }
  end

  get '/ybz/api/v1/hosts/:oid' do |oid|
    host = Yabitz::Model::Host.get(oid.to_i)
    halt api_v1_not_found('host') unless host
    Stratum.preload([host], Yabitz::Model::Host)
    api_v1_json({:data => api_v1_host(host)})
  end

  get '/ybz/api/v1/services' do
    services = Yabitz::Model::Service.all
    Stratum.preload(services, Yabitz::Model::Service)
    services = api_v1_filter_text(services, params[:q], [
      Proc.new {|service| service.name },
      Proc.new {|service| service.content ? service.content.name : nil },
      Proc.new {|service| service.content ? service.content.charging : nil },
      Proc.new {|service| service.contact ? service.contact.label : nil },
      Proc.new {|service| service.mladdress },
      Proc.new {|service| service.urls.map(&:url).join(' ') },
      Proc.new {|service| service.notes }
    ])
    services, change_meta = api_v1_filter_changed(services, Yabitz::Model::Service)
    api_v1_collection(services.sort, 'services', change_meta) {|service| api_v1_service(service) }
  end

  get '/ybz/api/v1/services/:oid' do |oid|
    service = Yabitz::Model::Service.get(oid.to_i)
    halt api_v1_not_found('service') unless service
    Stratum.preload([service], Yabitz::Model::Service)
    api_v1_json({:data => api_v1_service(service)})
  end

  get '/ybz/api/v1/racks' do
    racks = Yabitz::Model::Rack.all
    racks = api_v1_filter_text(racks, params[:q], [
      Proc.new {|rack| rack.label },
      Proc.new {|rack| rack.type },
      Proc.new {|rack| rack.datacenter },
      Proc.new {|rack| rack.notes }
    ])
    racks, change_meta = api_v1_filter_changed(racks, Yabitz::Model::Rack)
    api_v1_collection(racks.sort, 'racks', change_meta) {|rack| api_v1_rack(rack) }
  end

  get '/ybz/api/v1/racks/:oid' do |oid|
    rack = Yabitz::Model::Rack.get(oid.to_i)
    halt api_v1_not_found('rack') unless rack
    api_v1_json({:data => api_v1_rack(rack)})
  end

  get '/ybz/api/v1/ipsegments' do
    segments = if params[:area]
                 halt api_v1_error(HTTP_STATUS_NOT_ACCEPTABLE, 'invalid_area', 'invalid ipsegment area') unless Yabitz::Model::IPSegment::IP_SEGMENT_AREAS.include?(params[:area])
                 Yabitz::Model::IPSegment.query(:area => params[:area])
               else
                 Yabitz::Model::IPSegment.all
               end
    segments = api_v1_filter_text(segments, params[:q], [
      Proc.new {|segment| segment.address },
      Proc.new {|segment| "#{segment.address}/#{segment.netmask}" },
      Proc.new {|segment| segment.version },
      Proc.new {|segment| segment.area },
      Proc.new {|segment| segment.notes }
    ])
    segments, change_meta = api_v1_filter_changed(segments, Yabitz::Model::IPSegment)
    api_v1_collection(segments.sort, 'ipsegments', change_meta) {|segment| api_v1_ipsegment(segment) }
  end

  get '/ybz/api/v1/ipsegments/:oid' do |oid|
    segment = Yabitz::Model::IPSegment.get(oid.to_i)
    halt api_v1_not_found('ipsegment') unless segment
    api_v1_json({:data => api_v1_ipsegment(segment)})
  end

  get '/ybz/api/v1/ipaddresses' do
    segment = nil
    ips = if params[:segment_oid]
            segment = Yabitz::Model::IPSegment.get(params[:segment_oid].to_i)
            halt api_v1_not_found('ipsegment') unless segment
            api_v1_ipaddresses_in_network(segment.to_addr)
          elsif params[:q] and not params[:q].to_s.strip.empty?
            like = '%' + params[:q].to_s.strip + '%'
            oids = []
            Stratum.conn do |conn|
              sql = <<~SQL
                SELECT oid
                FROM #{Yabitz::Model::IPAddress.tablename}
                WHERE head=? AND removed=?
                  AND (address LIKE ? OR notes LIKE ?)
                ORDER BY version, address
                LIMIT ?
              SQL
              conn.query(sql, Stratum::Model::BOOL_TRUE, Stratum::Model::BOOL_FALSE, like, like, API_V1_MAX_LIMIT).each do |row|
                oids.push(row['oid'])
              end
            end
            Yabitz::Model::IPAddress.get(oids)
          else
            []
          end
    unless params[:q] and not params[:q].to_s.strip.empty? and not params[:segment_oid]
      ips = api_v1_filter_text(ips, params[:q], [
        Proc.new {|ip| ip.address },
        Proc.new {|ip| ip.version },
        Proc.new {|ip| ip.hosts.map(&:display_name).join(' ') },
        Proc.new {|ip| ip.notes }
      ])
    end
    ips, change_meta = api_v1_filter_changed(ips, Yabitz::Model::IPAddress)
    extra_meta = segment ? {:segment => api_v1_ipsegment(segment)} : {}
    api_v1_collection(ips.sort, 'ipaddresses', change_meta.merge(extra_meta)) {|ip| api_v1_ipaddress(ip) }
  end

  get '/ybz/api/v1/ipaddresses/:address' do |address|
    ip = Yabitz::Model::IPAddress.query(:address => address, :unique => true)
    halt api_v1_not_found('ipaddress') unless ip
    api_v1_json({:data => api_v1_ipaddress(ip)})
  end

  get '/ybz/api/v1/changes/:resource' do |resource|
    since_time = api_v1_time_param('since', true)
    until_time = api_v1_until_param
    case resource
    when 'hosts'
      hosts = api_v1_changed_records(Yabitz::Model::Host, since_time, until_time)
      Stratum.preload(hosts, Yabitz::Model::Host)
      api_v1_collection(hosts.sort, 'hosts', api_v1_change_meta('hosts', since_time, until_time)) {|host| api_v1_host(host) }
    when 'services'
      services = api_v1_changed_records(Yabitz::Model::Service, since_time, until_time)
      Stratum.preload(services, Yabitz::Model::Service)
      api_v1_collection(services.sort, 'services', api_v1_change_meta('services', since_time, until_time)) {|service| api_v1_service(service) }
    when 'racks'
      racks = api_v1_changed_records(Yabitz::Model::Rack, since_time, until_time)
      api_v1_collection(racks.sort, 'racks', api_v1_change_meta('racks', since_time, until_time)) {|rack| api_v1_rack(rack) }
    when 'ipsegments'
      segments = api_v1_changed_records(Yabitz::Model::IPSegment, since_time, until_time)
      api_v1_collection(segments.sort, 'ipsegments', api_v1_change_meta('ipsegments', since_time, until_time)) {|segment| api_v1_ipsegment(segment) }
    when 'ipaddresses'
      ips = api_v1_changed_records(Yabitz::Model::IPAddress, since_time, until_time)
      api_v1_collection(ips.sort, 'ipaddresses', api_v1_change_meta('ipaddresses', since_time, until_time)) {|ip| api_v1_ipaddress(ip) }
    else
      halt api_v1_error(HTTP_STATUS_NOT_FOUND, 'not_found', 'resource not found')
    end
  end
end
