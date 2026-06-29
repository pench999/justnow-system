# -*- coding: utf-8 -*-

require 'sinatra/base'
require 'json'

class Yabitz::Application < Sinatra::Base
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

    def api_v1_limit
      limit = (params[:limit] || Yabitz::Application::API_V1_DEFAULT_LIMIT).to_i
      limit = Yabitz::Application::API_V1_DEFAULT_LIMIT if limit <= 0
      [limit, Yabitz::Application::API_V1_MAX_LIMIT].min
    end

    def api_v1_offset
      offset = (params[:offset] || 0).to_i
      offset < 0 ? 0 : offset
    end

    def api_v1_collection(items, type, &serializer)
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
        }
      })
    end

    def api_v1_ref(obj, label_method = nil)
      return nil unless obj
      label = label_method ? obj.send(label_method) : obj.to_s
      {:oid => obj.oid, :label => label}
    end

    def api_v1_host(host)
      {
        :oid => host.oid,
        :id => host.id,
        :display_name => host.display_name,
        :status => host.status,
        :type => host.type,
        :service => api_v1_ref(host.service, :name),
        :content => host.service ? api_v1_ref(host.service.content, :name) : nil,
        :parent => api_v1_ref(host.parent),
        :children => host.children.map {|child| api_v1_ref(child) },
        :rackunit => api_v1_ref(host.rackunit, :rackunit),
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
        :address => ip.address,
        :version => ip.version,
        :holder => ip.holder,
        :host_oids => ip.hosts.map(&:oid),
        :notes => ip.notes
      }
    end
  end

  before do
    protected! if request.path_info.start_with?('/ybz/api/v1')
  end

  get '/ybz/api/v1' do
    api_v1_json({
      :data => {
        :version => 'v1',
        :readonly => true,
        :resources => ['hosts', 'services', 'racks', 'ipsegments', 'ipaddresses']
      }
    })
  end

  get '/ybz/api/v1/hosts' do
    hosts = if params[:service_oid]
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
    api_v1_collection(hosts.sort, 'hosts') {|host| api_v1_host(host) }
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
    api_v1_collection(services.sort, 'services') {|service| api_v1_service(service) }
  end

  get '/ybz/api/v1/services/:oid' do |oid|
    service = Yabitz::Model::Service.get(oid.to_i)
    halt api_v1_not_found('service') unless service
    Stratum.preload([service], Yabitz::Model::Service)
    api_v1_json({:data => api_v1_service(service)})
  end

  get '/ybz/api/v1/racks' do
    racks = Yabitz::Model::Rack.all
    api_v1_collection(racks.sort, 'racks') {|rack| api_v1_rack(rack) }
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
    api_v1_collection(segments.sort, 'ipsegments') {|segment| api_v1_ipsegment(segment) }
  end

  get '/ybz/api/v1/ipsegments/:oid' do |oid|
    segment = Yabitz::Model::IPSegment.get(oid.to_i)
    halt api_v1_not_found('ipsegment') unless segment
    api_v1_json({:data => api_v1_ipsegment(segment)})
  end

  get '/ybz/api/v1/ipaddresses' do
    ips = Yabitz::Model::IPAddress.all
    api_v1_collection(ips.sort, 'ipaddresses') {|ip| api_v1_ipaddress(ip) }
  end

  get '/ybz/api/v1/ipaddresses/:address' do |address|
    ip = Yabitz::Model::IPAddress.query(:address => address, :unique => true)
    halt api_v1_not_found('ipaddress') unless ip
    api_v1_json({:data => api_v1_ipaddress(ip)})
  end
end
