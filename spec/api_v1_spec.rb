# -*- coding: utf-8 -*-

require 'json'
require 'rack/mock'

require_relative '../lib/yabitz/app'

describe 'API v1 readonly' do
  before(:all) do
    @old_api_token = ENV['YABITZ_API_TOKEN']
    @old_api_tokens = ENV['YABITZ_API_TOKENS']
    ENV['YABITZ_API_TOKEN'] = nil
    ENV['YABITZ_API_TOKENS'] = 'rspec:spec-token'

    Yabitz::Application.set :raise_errors, true
    Yabitz::Application.set :show_exceptions, false

    class Yabitz::Application
      alias_method :api_v1_spec_authorized?, :authorized?

      def authorized?
        false
      end
    end

    class << Stratum
      alias_method :api_v1_spec_preload, :preload

      def preload(*args)
        nil
      end
    end

    class << Yabitz::Model::Host
      alias_method :api_v1_spec_all, :all
      alias_method :api_v1_spec_dig, :dig

      def all(*args)
        []
      end

      def dig(*args)
        []
      end
    end
  end

  after(:all) do
    class Yabitz::Application
      alias_method :authorized?, :api_v1_spec_authorized?
      remove_method :api_v1_spec_authorized?
    end

    class << Yabitz::Model::Host
      alias_method :all, :api_v1_spec_all
      alias_method :dig, :api_v1_spec_dig
      remove_method :api_v1_spec_all
      remove_method :api_v1_spec_dig
    end

    class << Stratum
      alias_method :preload, :api_v1_spec_preload
      remove_method :api_v1_spec_preload
    end

    ENV['YABITZ_API_TOKEN'] = @old_api_token
    ENV['YABITZ_API_TOKENS'] = @old_api_tokens
  end

  before do
    @request = Rack::MockRequest.new(Yabitz::Application)
  end

  def json_response(response)
    JSON.parse(response.body)
  end

  def bearer_header
    {'HTTP_AUTHORIZATION' => 'Bearer spec-token'}
  end

  def token_header
    {'HTTP_X_JUSTNOW_API_TOKEN' => 'spec-token'}
  end

  it 'returns JSON 401 when API authentication is missing' do
    response = @request.get('/ybz/api/v1/health')

    expect(response.status).to eq(401)
    expect(response.content_type).to include('application/json')
    expect(json_response(response)['error']['code']).to eq('unauthorized')
  end

  it 'returns health information with bearer token authentication' do
    response = @request.get('/ybz/api/v1/health', bearer_header)
    body = json_response(response)

    expect(response.status).to eq(200)
    expect(body['data']['status']).to eq('ok')
    expect(body['data']['version']).to eq('v1')
    expect(body['data']['readonly']).to be true
  end

  it 'lists API metadata with token header authentication' do
    response = @request.get('/ybz/api/v1', token_header)
    data = json_response(response)['data']

    expect(response.status).to eq(200)
    expect(data['resources']).to include('health')
    expect(data['authentication']).to include('bearer_token')
  end

  it 'honors limit for host list responses' do
    response = @request.get('/ybz/api/v1/hosts?limit=1', bearer_header)
    body = json_response(response)

    expect(response.status).to eq(200)
    expect(body['meta']['type']).to eq('hosts')
    expect(body['meta']['limit']).to eq(1)
    expect(body['data'].size).to be <= 1
  end

  it 'returns changed hosts with since parameter' do
    response = @request.get('/ybz/api/v1/changes/hosts?since=2000-01-01T00:00:00&limit=1', bearer_header)
    body = json_response(response)

    expect(response.status).to eq(200)
    expect(body['meta']['type']).to eq('hosts')
    expect(body['meta']['changed_since']).to eq('2000-01-01 00:00:00')
  end
end
